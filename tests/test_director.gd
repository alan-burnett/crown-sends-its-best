extends TestCase

## The director (#14) and not replying (#18).

const SEED: int = 1649

var run: RunState = null
var machine: TurnMachine = null
var content: ContentDatabase = null


func before_each() -> void:
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	ResourceCatalogue.reset()
	Terrain.reset()
	M1Registrations.register_all()

	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false


func after_each() -> void:
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	content.free()


## A run of its own, because the director's cooldown makes a second
## `compose_inbox` in the same month deliberately different from the first.
func _fresh_run(world_values: Dictionary = {}) -> RunState:
	var fresh := RunState.new_run(SEED)
	ContactRoster.load_into(fresh, content)
	for key in world_values:
		fresh.world.values[key] = world_values[key]
	return fresh


func _letter_of(inbound: InboundLetter) -> Letter:
	return Letter.from_record(content.record("letters", inbound.letter_id))


# --- Triggers --------------------------------------------------------------

func test_triggers_live_entirely_outside_letter_files() -> void:
	# A letter file contains no firing condition, which also keeps the triggers
	# free of localisation.
	for id in content.ids("letters"):
		var record: Dictionary = content.collection("letters")[id]
		assert_false(record.has("conditions"), "%s carries a firing condition" % id)
		assert_false(record.has("trigger"), "%s carries a trigger" % id)


func test_a_trigger_whose_conditions_fail_does_not_fire() -> void:
	run.world.values["colony_revenue"] = 1_900.0
	var letters := machine.director.compose_inbox(run)
	for inbound in letters:
		assert_ne(inbound.letter_id, "chancellor.how_to_answer",
			"the Chancellor wrote although revenue was high")


func test_a_trigger_whose_conditions_hold_and_whose_sender_minds_fires() -> void:
	# 🔒 **Conditions are no longer enough** (#254). They say whether a letter is
	# *true*; pressure says whether he bothers. This test used to assert that a
	# true letter fires, which is the gate this milestone replaced with a want.
	run.world.values["colony_revenue"] = 4.0
	run.world.values[WorldValues.REVENUE_BASELINE] = 60.0
	var ids: PackedStringArray = PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		ids.append(inbound.letter_id)
	assert_true(ids.has("chancellor.how_to_answer"), "got %s" % ids)


func test_a_true_letter_from_a_contented_man_does_not_fire() -> void:
	# The other half, and the point of the ticket. The arrears letter is *true*
	# whenever the returns are under the bar — but a Chancellor whose colony is
	# returning handsomely has nothing he wants to say about the returns.
	run.world.values["colony_revenue"] = 300.0
	run.world.values[WorldValues.REVENUE_BASELINE] = 60.0

	var context := LetterContext.new(run.world, run.contact(&"chancellor"))
	context.measures = ColonyMeasures.for_contact(run, run.contact(&"chancellor"))
	assert_true(ContentRegistry.test_condition(
		"world_value_below", {"key": "colony_revenue", "value": 1400}, context),
		"the fixture did not leave the letter true")

	for inbound in machine.director.compose_inbox(run):
		assert_ne(inbound.letter_id, "chancellor.how_to_answer",
			"a contented Chancellor wrote to complain about the returns")


func test_selection_is_deterministic() -> void:
	var first: PackedStringArray = PackedStringArray()
	for inbound in machine.director.compose_inbox(_fresh_run()):
		first.append(inbound.letter_id)
	var second: PackedStringArray = PackedStringArray()
	for inbound in machine.director.compose_inbox(_fresh_run()):
		second.append(inbound.letter_id)
	assert_eq(first, second)
	assert_not_empty(first)


# --- The params contract ---------------------------------------------------

func test_every_declared_param_is_supplied_at_the_right_type() -> void:
	for inbound in machine.director.compose_inbox(run):
		var letter := _letter_of(inbound)
		for name in letter.params:
			assert_true(inbound.params.has(name), "%s: no value for '%s'" % [letter.id, name])
			if LetterSchema.NUMERIC_PARAM_TYPES.has(StringName(letter.params[name])):
				assert_eq(typeof(inbound.params[name]), TYPE_INT,
					"%s.%s must be a whole number, or it renders as 200.0" % [letter.id, name])


func test_the_director_supplies_values_the_letter_never_decides() -> void:
	# The letter declares; the director supplies. Change the world and the same
	# letter arrives carrying different values.
	var low := _find(
		machine.director.compose_inbox(_fresh_run({"crown_war_intensity": 40.0})),
		"marshal.request_supplies",
	)
	var high := _find(
		machine.director.compose_inbox(_fresh_run({"crown_war_intensity": 90.0})),
		"marshal.request_supplies",
	)

	assert_true(low != null and high != null, "the Marshal did not write in both months")
	assert_true(int(high.params["amount"]) > int(low.params["amount"]),
		"a fiercer war should ask for more")


func test_a_rendered_letter_has_no_slots_left_in_it() -> void:
	var renderer := LetterRenderer.new()
	for inbound in machine.director.compose_inbox(run):
		var letter := _letter_of(inbound)
		var context := LetterContext.new(run.world, run.contact(inbound.sender), inbound.tone)
		context.params = inbound.params
		context.measures = inbound.measures
		var text := renderer.render_body(letter, context)
		assert_false(text.contains("{"), "%s rendered with a slot left in it: %s" % [letter.id, text])
		assert_not_empty(text)


func _find(letters: Array, letter_id: String) -> InboundLetter:
	for inbound in letters:
		if inbound.letter_id == letter_id:
			return inbound
	return null


# --- Tone ------------------------------------------------------------------

func test_the_director_passes_exactly_one_tone() -> void:
	for inbound in machine.director.compose_inbox(run):
		assert_true(Tone.is_tone(inbound.tone), "'%s' is not one of the five" % inbound.tone)


func test_tone_comes_from_loyalty_and_urgency() -> void:
	var devoted := Contact.from_data({"id": "x", "loyalty": 90})
	var hostile := Contact.from_data({"id": "x", "loyalty": 5})
	assert_eq(Director.tone_for(devoted), Tone.PLEASED)
	assert_eq(Director.tone_for(hostile), Tone.HATEFUL)
	assert_ne(Director.tone_for(devoted), Director.tone_for(hostile))


func test_urgency_can_override_a_comfortable_loyalty() -> void:
	var middling := Contact.from_data({"id": "x", "loyalty": 50})
	assert_eq(Director.tone_for(middling, 0.0), Tone.DUTIFUL)
	assert_eq(Director.tone_for(middling, 0.9), Tone.DESPERATE)


# --- Volume ----------------------------------------------------------------

func test_the_budget_is_set_by_the_calendar_year_not_colony_size() -> void:
	# SPEC §9.6 locks this. The budget for a year is the same however big the
	# colony has become.
	assert_eq(Director.budget_for_year(1), Director.EARLY_BUDGET)
	assert_eq(Director.budget_for_year(2), Director.EARLY_BUDGET)
	assert_eq(Director.budget_for_year(4), Director.MID_BUDGET)
	assert_eq(Director.budget_for_year(9), Director.LATE_BUDGET)
	assert_true(Director.EARLY_BUDGET < Director.MID_BUDGET)
	assert_true(Director.MID_BUDGET < Director.LATE_BUDGET)


func test_volume_tracks_the_targets_across_a_run() -> void:
	# SPEC §9.6's early-game target is 4-6 letters per turn.
	for turn in 24:
		machine.begin_turn()
		var year := run.world.year_index()
		assert_true(run.inbox.size() <= Director.budget_for_year(year),
			"turn %d (year %d) delivered %d letters against a budget of %d" % [
				turn, year, run.inbox.size(), Director.budget_for_year(year),
			])
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()


# --- Cooldown --------------------------------------------------------------

func test_the_same_letter_does_not_arrive_every_month() -> void:
	# Without a cooldown the same three triggers fire every month and the Author
	# reads the same correspondence twelve times, which is the failure #20 warns
	# about — and it lands on the director, not on the world.
	var arrivals: Dictionary = {}
	for turn in 8:
		machine.begin_turn()
		for inbound in run.inbox:
			arrivals[inbound.letter_id] = int(arrivals.get(inbound.letter_id, 0)) + 1
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	for letter_id in arrivals:
		assert_true(int(arrivals[letter_id]) < 8,
			"'%s' arrived in all 8 months" % letter_id)


func test_a_trigger_may_set_its_own_cooldown() -> void:
	# A standing report comes round often; a crisis letter rarely.
	var steward: Dictionary = content.record("triggers", "trigger.steward.revenue_report")
	var chancellor: Dictionary = content.record("triggers", "trigger.chancellor.how_to_answer")
	assert_true(int(steward["cooldown"]) < int(chancellor["cooldown"]))


func test_the_cooldown_survives_a_reload() -> void:
	# A resumed run that forgot would start repeating itself.
	machine.begin_turn()
	assert_not_empty(run.letters_sent)
	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.letters_sent, run.letters_sent)


# --- Culling ---------------------------------------------------------------

func test_culling_never_drops_an_unskippable_letter() -> void:
	var kept := machine.director._cull([], [], run)
	assert_empty(kept)

	var unskippable: Array[InboundLetter] = []
	for i in Director.LATE_BUDGET + 5:
		var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
		inbound.id = StringName("forced_%d" % i)
		unskippable.append(inbound)

	# `marshal.request_supplies` is skippable, so force the check the other way:
	# everything acknowledging last month's post is kept regardless of budget.
	assert_eq(machine.director._cull([], unskippable, run).size(), unskippable.size())


func test_a_culled_request_costs_no_loyalty() -> void:
	# Culling means the contact never consulted the PC and handled it himself.
	var marshal := run.contact(&"marshal")
	var before := marshal.loyalty()

	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
	inbound.id = &"culled_1"
	machine.director._cull_one(inbound, run)

	assert_almost_eq(marshal.loyalty(), before, 0.001, "a culled request must not cost loyalty")
	assert_eq(run.log.of_type(Director.EVENT_CULLED).size(), 1)
	assert_eq(run.log.of_type(Director.EVENT_CULLED)[0].payload["outcome"], "polite_no")


func test_an_ignored_request_does_cost_loyalty() -> void:
	# He asked and was not answered, which is the whole difference.
	var marshal := run.contact(&"marshal")
	var before := marshal.loyalty()

	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
	inbound.id = &"ignored_1"
	var letter := Letter.from_record(content.record("letters", "marshal.request_supplies"))
	Silence.resolve_one(marshal, letter, inbound, run)

	assert_true(marshal.loyalty() < before, "an ignored request must cost loyalty")


func test_a_culled_question_is_decided_without_the_pc() -> void:
	var inbound := InboundLetter.new("chancellor.how_to_answer", &"chancellor", Tone.ANNOYED)
	inbound.id = &"culled_q"
	machine.director._cull_one(inbound, run)
	assert_eq(run.log.of_type(Director.EVENT_CULLED)[0].payload["outcome"], "decided_alone")
	assert_not_empty(run.log.of_type(Silence.EVENT_DECIDED_ALONE))


# --- Not replying ----------------------------------------------------------

func test_silence_on_a_report_costs_nothing() -> void:
	var steward := run.contact(&"steward")
	var before := steward.loyalty()
	var inbound := InboundLetter.new("steward.revenue_report", &"steward", Tone.DUTIFUL)
	inbound.id = &"r1"
	var letter := Letter.from_record(content.record("letters", "steward.revenue_report"))

	var result := Silence.resolve_one(steward, letter, inbound, run)
	assert_eq(result["outcome"], "no_penalty")
	assert_almost_eq(steward.loyalty(), before, 0.001)


func test_silence_on_a_request_is_a_rude_refusal() -> void:
	var marshal := run.contact(&"marshal")
	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
	inbound.id = &"r2"
	var letter := Letter.from_record(content.record("letters", "marshal.request_supplies"))

	var result := Silence.resolve_one(marshal, letter, inbound, run)
	assert_eq(result["outcome"], "rude_refusal")
	assert_true(float(result["loyalty_change"]) < 0.0)
	assert_not_empty(run.log.of_type(Silence.EVENT_IGNORED))


func test_silence_on_a_question_has_him_decide_for_himself() -> void:
	var chancellor := run.contact(&"chancellor")
	var before := chancellor.loyalty()
	var inbound := InboundLetter.new("chancellor.how_to_answer", &"chancellor", Tone.HATEFUL)
	inbound.id = &"r3"
	var letter := Letter.from_record(content.record("letters", "chancellor.how_to_answer"))

	var result := Silence.resolve_one(chancellor, letter, inbound, run)
	assert_eq(result["outcome"], "decided_alone")
	assert_true(chancellor.loyalty() < before, "being ignored when he asked costs loyalty")

	var decision: Decision = result["decision"]
	assert_true(decision != null)
	assert_true(decision.has_choice())


func test_deciding_for_himself_produces_a_trace() -> void:
	# Through the kernel, not a coin flip, so the reason is on the record.
	var chancellor := run.contact(&"chancellor")
	var inbound := InboundLetter.new("chancellor.how_to_answer", &"chancellor", Tone.HATEFUL)
	inbound.id = &"r4"
	var letter := Letter.from_record(content.record("letters", "chancellor.how_to_answer"))
	Silence.resolve_one(chancellor, letter, inbound, run)
	assert_not_empty(run.log.of_type(Deliberation.TRACE_EVENT))


func test_personality_changes_what_he_decides() -> void:
	# "At random or in their own interest, depending on personality" — and which
	# of those wins is a weight, not a branch.
	var letter := Letter.from_record(content.record("letters", "chancellor.how_to_answer"))
	var inbound := InboundLetter.new("chancellor.how_to_answer", &"chancellor", Tone.HATEFUL)
	inbound.id = &"r5"

	var grasping := Contact.from_data({"id": "chancellor", "loyalty": 20, "weights": {"self_interest": 2.0, "caprice": 0.0}})
	var whimsical := Contact.from_data({"id": "chancellor", "loyalty": 20, "weights": {"self_interest": 0.0, "caprice": 2.0}})

	var by_interest := Silence.decide_alone(grasping, letter, inbound, run, true)
	assert_eq(by_interest.chosen_id(), &"pay", "self-interest should take the money")

	var by_whim := Silence.decide_alone(whimsical, letter, inbound, run, true)
	assert_true(by_whim.has_choice())


func test_every_incoming_letter_can_be_set_aside() -> void:
	machine.begin_turn()
	assert_not_empty(run.inbox, "the director delivered nothing to set aside")
	assert_false(machine.can_send()["ok"])
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	assert_true(machine.can_send()["ok"], "setting every letter aside should clear the desk")


func test_the_post_cannot_be_sent_while_a_letter_is_unhandled() -> void:
	machine.begin_turn()
	assert_false(machine.send_post())


func test_set_aside_letters_are_read_as_silence_next_month() -> void:
	machine.begin_turn()
	var senders: Array[StringName] = []
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
		senders.append(inbound.sender)

	var before: Dictionary = {}
	for id in run.contact_ids():
		before[id] = run.contacts[id].loyalty()

	machine.send_post()

	var moved := false
	for id in run.contact_ids():
		if not is_equal_approx(before[id], run.contacts[id].loyalty()):
			moved = true
	assert_true(moved, "ignoring everybody left every relationship untouched")


# --- Acknowledgement -------------------------------------------------------

func _send_an_order() -> void:
	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	var outgoing := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	outgoing.tone = Tone.DUTIFUL
	outgoing.choose("grant", "full")
	outgoing.params = {"amount": 200, "resource": "iron"}
	run.post.add(outgoing)
	machine.send_post()


func test_an_outcome_is_acknowledged_the_following_month() -> void:
	# **Each month's letters acknowledge the decisions sent in last month's
	# post** (SPEC §9.1). The player always learns what became of what he wrote.
	_send_an_order()
	machine.begin_turn()

	var senders: Array[StringName] = []
	for inbound in run.inbox:
		senders.append(inbound.sender)
	assert_true(senders.has(&"marshal"), "the Marshal did not write back at all: %s" % [senders])
	assert_empty(machine.director.unacknowledged,
		"an outcome went unacknowledged: %s" % [machine.director.unacknowledged])


func test_an_acknowledgement_is_never_culled() -> void:
	# Whatever the budget. Being told what happened is not optional.
	_send_an_order()
	var acknowledging := machine.director._acknowledgements(run, machine.orders.results)
	assert_not_empty(acknowledging)
	var kept := machine.director._cull([], acknowledging, run)
	assert_eq(kept.size(), acknowledging.size())


func test_one_acknowledgement_per_letter_per_turn() -> void:
	# Two orders that came to the same end are one piece of news, and the same
	# paragraph twice on one desk reads as a bug because it is one.
	_send_an_order()
	var seen: Dictionary = {}
	for inbound in machine.director._acknowledgements(run, machine.orders.results):
		assert_false(seen.has(inbound.letter_id), "'%s' acknowledged twice" % inbound.letter_id)
		seen[inbound.letter_id] = true


func test_an_outcome_with_no_content_is_reported_not_swallowed() -> void:
	# Where the Author has not written the acknowledgement yet, the director
	# keeps the checklist rather than passing over it in silence.
	var stranger := Contact.from_data({"id": "provost", "name": "Marchmont", "role": "crown_officer"})
	run.add_contact(stranger)
	var order := Order.new(M1Registrations.ORDER_REFUSE, &"provost", {"to": "provost"}, run.world.month)
	order.id = &"order_1"

	machine.director._acknowledgements(run, [{"order": order, "outcome": Compliance.REFUSE}])
	assert_not_empty(machine.director.unacknowledged)


func test_an_acknowledgement_trigger_does_not_fire_on_its_own() -> void:
	# It answers an outcome. Left in the ordinary sweep it fires every month with
	# news of orders nobody gave — and being unskippable, crowds out every real
	# letter on the desk.
	machine.begin_turn()
	for inbound in run.inbox:
		var record: Dictionary = content.record("letters", inbound.letter_id)
		assert_false(String(record.get("id", "")).contains(".ack_"),
			"'%s' arrived before any order was given" % inbound.letter_id)


func test_a_composable_letter_does_not_arrive_on_its_own() -> void:
	machine.begin_turn()
	for inbound in run.inbox:
		assert_ne(inbound.letter_id, "pc.request_troops")
