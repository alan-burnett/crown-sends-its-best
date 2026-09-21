extends TestCase

## 🔒 An unskippable letter always wins selection (#254, #257; SPEC §10.3;
## `docs/mechanics/the-director.md` §2, `crown-standing.md` §3).
##
## **A precedence rule, not a ladder.** §10.3 locks that the player always gets
## the standing warning, and `crown-standing.md` §3 makes it a gate: refusal
## cannot fire until it has been delivered. A month in which a routine question
## crowded it out is a month in which either the player is never told or the
## Crown never refuses.
##
## The property holds three times over — the cull keeps must-sends before it
## counts the budget, pressure exempts them, and the one-letter-per-contact rule
## does not apply to them. **None of that was written down**, and #257 is about
## to rank letters within a contact. This file is what stops that ranking
## reaching a letter that was never a candidate for ranking.

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	content.free()


## A run in which the Chancellor has everything to say at once.
func _clamouring() -> Dictionary:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# The returns are dreadful, which makes his routine question true and gives
	# him real pressure to ask it.
	run.world.values["colony_revenue"] = 4.0
	run.world.values[WorldValues.REVENUE_BASELINE] = 60.0
	return {"run": run, "machine": machine}


func _post(playing: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for inbound in playing["machine"].director.compose_inbox(playing["run"]):
		ids.append(inbound.letter_id)
	return ids


func _is_must_send(letter_id: String) -> bool:
	return not bool(content.record("letters", letter_id).get("skippable", true))


# --- 🔒 It is delivered ------------------------------------------------------

func test_a_must_send_is_not_crowded_out_by_a_routine_question() -> void:
	# The case that matters: `chancellor.warning_standing` is unskippable and
	# sorts *after* `chancellor.how_to_answer`, so any rule that took the first
	# true letter a contact had would lose the warning the spec guarantees.
	var playing := _clamouring()
	var ids := _post(playing)

	assert_true(ids.has("chancellor.how_to_answer"),
		"the fixture did not give him a routine question to ask: %s" % ids)
	assert_true(ids.has("chancellor.warning_standing"),
		"the standing warning lost selection to a routine question: %s" % ids)


func test_a_must_send_does_not_spend_his_one_letter() -> void:
	# §2: a must-send bypasses pressure. It must also bypass the one-letter rule,
	# or the natives attacking would silence everything else the man had to say
	# — and the player would learn to read a crisis as *and nothing else
	# happened*.
	var ids := _post(_clamouring())
	var from_him: PackedStringArray = PackedStringArray()
	for id in ids:
		if String(id).begins_with("chancellor."):
			from_him.append(String(id))

	assert_true(from_him.size() >= 2,
		"a must-send used up the one letter he had this month: %s" % from_him)
	var must_sends := 0
	for id in from_him:
		if _is_must_send(String(id)):
			must_sends += 1
	assert_true(must_sends >= 1, "the fixture produced no must-send at all")


func test_a_must_send_outranks_everything_in_the_post() -> void:
	# 🔒 **Precedence, not a ladder.** Every must-send comes before every
	# skippable letter, so a desk trimmed from the bottom can never trim one.
	var ids := _post(_clamouring())
	var seen_skippable := false
	for id in ids:
		if _is_must_send(String(id)):
			assert_false(seen_skippable,
				"%s is a must-send and sits behind a letter that is not: %s" % [id, ids])
		else:
			seen_skippable = true


# --- 🔒 And it survives a full desk -----------------------------------------

func test_a_must_send_survives_a_budget_that_has_run_out() -> void:
	# 🔒 The cull keeps must-sends **before** it counts the budget. A run wide
	# enough to exceed its volume target is exactly the run in which the Crown is
	# most likely to be about to refuse.
	#
	# Put to the cull directly with a desk far past its budget, because a
	# fixture that merely fills the desk proves nothing: it has to *overflow*.
	var playing := _clamouring()
	var run: RunState = playing["run"]
	var director: Director = playing["machine"].director
	var budget := Director.budget_for_year(run.world.year_index())

	var fired: Array[InboundLetter] = []
	for index in budget * 3:
		fired.append(InboundLetter.new("chancellor.how_to_answer", &"chancellor", &"dutiful"))
	var warning := InboundLetter.new(
		"chancellor.warning_standing", &"chancellor", &"dutiful")
	# Last in the queue, which is where the alphabet would put it and where a
	# budget counted honestly would cut it.
	fired.append(warning)

	var kept := director._cull(fired, [] as Array[InboundLetter], run)
	var survived := false
	for inbound in kept:
		if inbound.letter_id == "chancellor.warning_standing":
			survived = true
	assert_true(survived,
		"the standing warning was culled to fit a budget of %d" % budget)
	assert_true(kept.size() < fired.size(),
		"the fixture did not overflow the desk, so nothing was culled at all")
	assert_true(kept.size() <= budget + 1,
		"the budget of %d was not being enforced on the rest" % budget)


func test_every_must_send_that_was_true_arrived() -> void:
	# The general form, and the one a later ticket would break: **a letter that
	# is not skippable and whose conditions hold is in the post.** Nothing about
	# pressure, ranking or budget may stand between the two.
	var playing := _clamouring()
	var run: RunState = playing["run"]
	var machine: TurnMachine = playing["machine"]

	var ids := _post(playing)
	var arrived: Dictionary = {}
	for id in ids:
		arrived[String(id)] = true

	for trigger_id in content.ids("triggers"):
		var trigger: Dictionary = content.record("triggers", String(trigger_id))
		var letter_id := String(trigger.get("letter", ""))
		if letter_id.is_empty() or not content.has_record("letters", letter_id):
			continue
		if trigger.has("acknowledges") or bool(trigger.get(Composer.OFFERS_KEY, false)):
			continue
		if not _is_must_send(letter_id):
			continue

		var letter := Letter.from_record(content.record("letters", letter_id))
		var contact := run.contact(StringName(letter.sender))
		if contact == null:
			continue
		var context := machine.director._context(run, contact)
		if not machine.director._conditions_hold(trigger, context):
			continue
		assert_true(arrived.has(letter_id),
			"%s was true, unskippable, and did not arrive" % letter_id)
