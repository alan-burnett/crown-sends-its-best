extends TestCase

## Loyalty gates the kind, and over budget the skippable drop at random (#259,
## `docs/mechanics/the-director.md` §10, §11, §12, §13).
##
## 🔒 **A disliked PC's desk is not quieter. It is hollowed out.** The same stack
## of paper arrives and far fewer of them are decisions. He is still being asked
## for things; he has simply stopped being consulted.
##
## 🔒 **And no priority ordering, deliberately.** Importance is the player's
## judgement, and a director ranking a famine above a charity appeal would be
## doing the player's job with worse information. A seeded draw silences nobody
## systematically; a sort silences the same men in every run for ever.
##
## ## Why most of this is asked of the seam and not of a played run
##
## The corpus holds **three questions and one offer** against thirty-six reports
## and seventeen requests. The rule is real in the mechanism and very nearly
## invisible on the desk, and the cull never fires at all in ordinary play — no
## month of twenty-four eight-year runs went over budget. So a test written
## against a played desk would measure the corpus rather than the rule, and would
## go on passing when the rule broke. M8 authors the letter set.

const SEED: int = 7731

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	content.free()


func _run_at(loyalty: float) -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for id in run.contact_ids():
		run.contacts[id].relationship = Relationship.new(StringName(id), loyalty)
	return run


## The first letter of each type, so the fixtures use real content rather than
## records the validator has never seen.
func _a_letter_of(kind: StringName) -> String:
	for id in content.ids("letters"):
		if StringName(content.record("letters", id).get("type", "")) == kind:
			return String(id)
	return ""


func _post_from(sender: StringName, ids: Array) -> Array[InboundLetter]:
	var post: Array[InboundLetter] = []
	for index in ids.size():
		var inbound := InboundLetter.new(String(ids[index]), sender, &"")
		inbound.id = StringName("fixture_%d" % index)
		post.append(inbound)
	return post


# --- 🔒 Loyalty gates the kind, not the number ------------------------------

func test_the_curve_runs_from_always_to_a_floor_and_never_to_nothing() -> void:
	# 🔒 **It falls off at the low band and nowhere else.** §10's table says
	# *at low loyalty*, and `Relationship` already says where low begins (#258).
	# A boundary of its own here would be a second definition of the same word.
	assert_eq(Consultation.chance_at(100.0), 1.0)
	assert_eq(Consultation.chance_at(Relationship.MEDIUM_AT), 1.0,
		"a man of middling regard had stopped consulting the PC")
	assert_true(Consultation.chance_at(Relationship.MEDIUM_AT - 10.0) < 1.0,
		"a man whose regard has gone low consults as freely as a devoted one")
	assert_true(Consultation.chance_at(0.0) > 0.0,
		"a man at the bottom never consults at all, so the PC cannot reach him")
	assert_true(
		Consultation.chance_at(Relationship.MEDIUM_AT - 10.0)
			> Consultation.chance_at(Relationship.MEDIUM_AT - 25.0),
		"the curve does not fall as loyalty falls")


func test_a_request_is_a_request_however_he_feels_about_you() -> void:
	# 🔒 §10 leaves requests untouched. Being disliked must not spare the PC the
	# begging — that would be a reward for it.
	assert_false(Consultation.is_consultative(LetterSchema.TYPE_REQUEST))
	assert_false(Consultation.is_consultative(LetterSchema.TYPE_DEMAND))
	assert_false(Consultation.is_consultative(LetterSchema.TYPE_REPORT))
	assert_false(Consultation.is_consultative(LetterSchema.TYPE_NEWS))
	assert_false(Consultation.is_consultative(LetterSchema.TYPE_WARNING))
	assert_true(Consultation.is_consultative(LetterSchema.TYPE_QUESTION))
	assert_true(Consultation.is_consultative(LetterSchema.TYPE_OFFER))


func test_the_hated_desk_is_the_same_size_with_the_decisions_taken_out() -> void:
	# The acceptance, asked of the seam: one man, one month, a question and a
	# request in hand, at two loyalties and over many draws.
	var question := _a_letter_of(LetterSchema.TYPE_QUESTION)
	var request := _a_letter_of(LetterSchema.TYPE_REQUEST)
	assert_false(question.is_empty() or request.is_empty(),
		"the corpus has no question or no request to tell apart")

	var counted: Dictionary = {}
	for loyalty in [85.0, 8.0]:
		var letters := 0
		var decisions := 0
		var asks := 0
		for round in 60:
			var run := RunState.new_run(SEED + round)
			ContactRoster.load_into(run, content)
			var sender := StringName(content.record("letters", question).get("sender", ""))
			run.contacts[String(sender)].relationship = Relationship.new(sender, float(loyalty))
			var director := Director.new(content)
			var post: Array = director.callv("_still_consulting",
				[_post_from(sender, [question, request]), run])
			letters += post.size()
			for inbound in post:
				if Consultation.is_consultative(
						StringName(content.record("letters", inbound.letter_id).get("type", ""))):
					decisions += 1
				else:
					asks += 1
		counted["%.0f" % loyalty] = {"letters": letters, "decisions": decisions, "asks": asks}

	var loved: Dictionary = counted["85"]
	var loathed: Dictionary = counted["8"]

	# 🔒 **Far fewer decisions.**
	assert_true(int(loathed["decisions"]) < int(loved["decisions"]),
		"a hated PC was consulted as often as a loved one: %s against %s"
			% [loathed, loved])

	# 🔒 **And the requests are untouched.**
	assert_eq(int(loathed["asks"]), int(loved["asks"]),
		"being disliked spared the PC some of the begging: %s against %s"
			% [loathed, loved])


func test_he_keeps_all_his_questions_or_none_of_them() -> void:
	# A man in two minds would ask one question and withhold another in the same
	# post. Whether he still consults the Crown is a fact about him this month.
	var question := _a_letter_of(LetterSchema.TYPE_QUESTION)
	assert_false(question.is_empty(), "the corpus has no question to withhold")

	# Two consultations in one man's hand, which the corpus never gives him: he
	# has three questions and one offer in all, spread across four senders.
	var sender := StringName(content.record("letters", question).get("sender", ""))
	var both := 0
	var neither := 0
	for round in 60:
		var run := RunState.new_run(SEED + round)
		ContactRoster.load_into(run, content)
		run.contacts[String(sender)].relationship = Relationship.new(sender, 8.0)
		var director := Director.new(content)
		var post: Array = director.callv("_still_consulting",
			[_post_from(sender, [question, question]), run])
		if post.size() == 2:
			both += 1
		elif post.is_empty():
			neither += 1
		else:
			assert_true(false, "he asked one question and withheld the other")
	assert_true(both > 0 and neither > 0,
		"the draw never came out both ways in sixty months: %d both, %d neither"
			% [both, neither])


func test_a_question_he_never_asked_costs_him_nothing() -> void:
	# 🔒 §12: **culled means he never consulted the PC and handled it himself, and
	# no loyalty is lost.** Ignored means he asked and was not answered, which
	# costs. The two look alike in the world and are opposite in the Relationship,
	# which is the whole reason the distinction is worth code.
	var question := _a_letter_of(LetterSchema.TYPE_QUESTION)
	var sender := StringName(content.record("letters", question).get("sender", ""))

	var withheld := 0
	for round in 60:
		var run := RunState.new_run(SEED + round)
		ContactRoster.load_into(run, content)
		run.contacts[String(sender)].relationship = Relationship.new(sender, 4.0)
		var before: float = run.contacts[String(sender)].loyalty()

		var director := Director.new(content)
		var post: Array = director.callv("_still_consulting",
			[_post_from(sender, [question]), run])
		if not post.is_empty():
			continue
		withheld += 1
		assert_eq(run.contacts[String(sender)].loyalty(), before,
			"a man lost loyalty for a question he never asked")
		assert_empty(run.log.of_type(Silence.EVENT_IGNORED),
			"withholding a question was recorded as the PC ignoring it")
		assert_not_empty(run.log.of_type(Silence.EVENT_DECIDED_ALONE),
			"he withheld the question and never settled it either")
	assert_true(withheld > 0, "nobody at rock bottom withheld anything in sixty months")


# --- 🔒 Over budget: a seeded draw, and no ordering -------------------------

func test_the_budget_is_a_ceiling_and_there_is_no_floor() -> void:
	# A thin desk is the correct reward for a colony running well, and nothing
	# manufactures post to fill it.
	assert_eq(Director.budget_for_year(1), Director.EARLY_BUDGET)
	assert_eq(Director.budget_for_year(4), Director.MID_BUDGET)
	assert_eq(Director.budget_for_year(9), Director.LATE_BUDGET)

	var run := _run_at(70.0)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var thinnest := 99
	for turn in 12:
		machine.begin_turn()
		thinnest = mini(thinnest, run.inbox.size())
		machine.send_post()
	assert_true(thinnest < Director.EARLY_BUDGET,
		"every month filled the budget exactly, which means something is padding it")


func test_trigger_id_no_longer_decides_who_is_heard() -> void:
	# 🔒 §11. Taking them in the order they fired meant taking them in trigger id
	# order, so the desk was culled alphabetically and a man whose letters sorted
	# late was quiet in **every run ever played.** That is the failure this
	# replaces.
	var skippable: Array = []
	for id in content.ids("letters"):
		if bool(content.record("letters", id).get("skippable", true)):
			skippable.append(String(id))
	skippable.sort()
	assert_true(skippable.size() > Director.EARLY_BUDGET * 2,
		"too few skippable letters to overfill a desk")

	var flood: Array = skippable.slice(0, Director.EARLY_BUDGET * 2)
	var survived: Dictionary = {}
	for id in flood:
		survived[id] = 0

	for round in 80:
		var run := RunState.new_run(SEED + round * 37)
		ContactRoster.load_into(run, content)
		var director := Director.new(content)
		var post := _post_from(&"governor_ashmere", flood)
		var kept: Array = director.callv("_cull", [post, [] as Array[InboundLetter], run])
		assert_eq(kept.size(), Director.EARLY_BUDGET,
			"the cull did not trim the desk to the budget")
		for inbound in kept:
			survived[inbound.letter_id] = int(survived[inbound.letter_id]) + 1

	# 🔒 **Everybody is heard sometimes.** Under the old rule the first six ids
	# survived every month and the rest survived none.
	var never := PackedStringArray()
	var always := PackedStringArray()
	for id in flood:
		if int(survived[id]) == 0:
			never.append(String(id))
		if int(survived[id]) == 80:
			always.append(String(id))
	assert_empty(never, "these letters were culled in every one of eighty months: %s"
		% ", ".join(never))
	assert_empty(always, "these letters survived every one of eighty months: %s"
		% ", ".join(always))

	# And the back half is heard about as often as the front half, which is the
	# alphabetical cull's fingerprint if it is still there.
	var front := 0
	var back := 0
	for index in flood.size():
		if index < flood.size() / 2:
			front += int(survived[flood[index]])
		else:
			back += int(survived[flood[index]])
	var tilt := absf(float(front - back)) / maxf(1.0, float(front + back))
	assert_true(tilt < 0.2,
		"the front half of the alphabet was heard %d times and the back half %d"
			% [front, back])


func test_the_draw_is_seeded_and_not_a_coin() -> void:
	# Same seed, same desk. A cull reaching for the global RNG would break the
	# save (SPEC §16.2) and the determinism gate with it.
	var skippable: Array = []
	for id in content.ids("letters"):
		if bool(content.record("letters", id).get("skippable", true)):
			skippable.append(String(id))
	skippable.sort()
	var flood: Array = skippable.slice(0, Director.EARLY_BUDGET * 2)

	var seen: Array = []
	for pass_index in 2:
		var run := RunState.new_run(SEED)
		ContactRoster.load_into(run, content)
		var director := Director.new(content)
		var kept: Array = director.callv("_cull",
			[_post_from(&"governor_ashmere", flood), [] as Array[InboundLetter], run])
		var ids: Array = []
		for inbound in kept:
			ids.append(String(inbound.letter_id))
		ids.sort()
		seen.append(ids)
	assert_eq(seen[0], seen[1], "the same seed culled two different desks")


func test_the_unskippable_play_out_over_budget() -> void:
	# 🔒 §13: **a flooded desk is information.** Ending a policy six churches cared
	# about brings six letters, and the PC answers all six or takes the loss with
	# each. Letters of that kind are `skippable: false` precisely because escaping
	# them through a cull would be escaping the decision.
	var must_send := ""
	for id in content.ids("letters"):
		if not bool(content.record("letters", id).get("skippable", true)):
			must_send = String(id)
			break
	assert_false(must_send.is_empty(), "there are no must-send letters")

	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var director := Director.new(content)

	var flood := Director.EARLY_BUDGET + 4
	var post: Array[InboundLetter] = []
	for index in flood:
		var inbound := InboundLetter.new(must_send, &"governor_ashmere", &"")
		inbound.id = StringName("flood_%d" % index)
		post.append(inbound)

	var kept: Array = director.callv("_cull", [post, [] as Array[InboundLetter], run])
	assert_eq(kept.size(), flood,
		"the budget culled a letter the PC was never meant to be able to escape")
	assert_empty(run.log.of_type(Director.EVENT_CULLED),
		"an unskippable letter was recorded as culled")
