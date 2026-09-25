extends TestCase

## A loyal governor asks the PC how to answer a tribe; a disloyal one tells him
## after; one at the floor says nothing (#436, `natives.md` §11).
##
## 🔒 **The PC's reply is an Order**, resolved by compliance into an urging on
## the letter he asked about. It moves which answer he gives, never gives it by
## itself, and never touches the tribe.

const SEED: int = 436

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
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
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


func _governor() -> Contact:
	return run.contact(_town().governor_id)


## A letter from the first tribe about a field of theirs, written last month.
func _written(loyalty: float) -> TribeGrievance:
	_governor().relationship.loyalty = loyalty
	var tribe: Tribe = run.tribes.in_order()[0]
	var grievance := run.tribes.grievances.write(tribe.id, _town(), TribeGrievance.LAND_WORKED,
		_town().at + Vector2i(2, 0), &"", run.log, run.world.month)
	run.world.month += 1
	return grievance


func _answer_phase() -> void:
	TribeGrievanceDriver.new(run).on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)


func _true(trigger_id: String) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[trigger_id], director._context(run, _governor()))


# --- 🔒 Whether he asks first ----------------------------------------------------------------

func test_at_or_above_neutral_he_asks_and_never_answers_in_the_month_it_arrives() -> void:
	var grievance := _written(Relationship.NEUTRAL_LOYALTY)
	_answer_phase()
	assert_false(grievance.is_answered(), "a loyal governor answered the month the letter arrived")
	_answer_phase()
	assert_false(grievance.is_answered(), "asked twice in one month, he answered the month he asked")
	assert_eq(grievance.asked_month, run.world.month, "he never asked the PC")
	assert_true(_true("trigger.governor.a_tribe_has_written"), "his question never reached the desk")
	run.world.month += 1
	_answer_phase()
	assert_true(grievance.is_answered(), "having waited a month, he still never answered")


func test_below_neutral_he_always_answers_at_once_and_tells_the_pc_after() -> void:
	var grievance := _written(Relationship.NEUTRAL_LOYALTY - 1.0)
	_answer_phase()
	assert_true(grievance.is_answered(), "a governor below neutral waited for the PC")
	assert_eq(grievance.asked_month, -1, "a governor below neutral asked the PC")
	assert_false(_true("trigger.governor.a_tribe_has_written"))
	assert_true(_true("trigger.governor.i_answered_the_tribe_%s" % grievance.answer),
		"he answered the tribe and never told the PC")


func test_at_the_floor_he_answers_and_says_nothing() -> void:
	var grievance := _written(IntentConsiderations.SEDITION_AT)
	_answer_phase()
	assert_true(grievance.is_answered())
	for answer in TribeGrievance.ANSWERS:
		assert_false(_true("trigger.governor.i_answered_the_tribe_%s" % answer),
			"a governor at the floor wrote to the PC about it")
	assert_false(_true("trigger.governor.a_tribe_has_written"))


# --- 🔒 The PC's reply moves the answer; it never gives it -----------------------------------

## The order the PC's reply produces, urging `answer`.
func _reply(answer: StringName) -> Order:
	var context := machine.director._context(run, _governor())
	context.params = {"governor": String(_governor().id)}
	context.tone = Tone.DUTIFUL
	return ContentRegistry.run_effect("answer_the_tribe", {"to": "{governor}", "answer": String(answer)}, context)


func _hears(order: Order, outcome: StringName) -> void:
	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.tribes = run.tribes
	orders._urge_the_answer_if_agreed(order, _governor(), {"outcome": String(outcome)}, run.world, run.log)


## What yield totals in his deliberation, as it stands.
func _yield_total(grievance: TribeGrievance) -> float:
	var deliberation := DeliberationContext.new(DecisionKind.TRIBE_GRIEVANCE, run.world, run.log)
	deliberation.data = {"town": _town(), "grievance": grievance, "gift": {}, "map": run.map}
	var candidates: Array = []
	for answer in TribeGrievance.ANSWERS:
		candidates.append(Candidate.new(answer))
	var decision := Deliberation.choose(_governor(), candidates, deliberation)
	for entry in decision.entries:
		if String(entry["id"]) == String(TribeGrievance.YIELD):
			return float(entry.get("total", 0.0))
	return 0.0


func test_a_reply_urging_yield_makes_yield_more_likely_than_no_reply() -> void:
	var grievance := _written(80.0)
	_answer_phase()
	var unurged := _yield_total(grievance)
	_hears(_reply(TribeGrievance.YIELD), Compliance.COMPLY)
	assert_eq(String(grievance.urged), String(TribeGrievance.YIELD), "his compliance took the reply and nothing was urged")
	assert_true(_yield_total(grievance) > unurged, "the PC urged yield and yield weighed no more")
	assert_false(grievance.is_answered(), "the reply gave the answer by itself")


func test_a_reply_his_compliance_refused_changes_nothing() -> void:
	var grievance := _written(80.0)
	_answer_phase()
	var unurged := _yield_total(grievance)
	_hears(_reply(TribeGrievance.YIELD), Compliance.REFUSE)
	assert_eq(String(grievance.urged), "", "a refused reply was urged all the same")
	assert_almost_eq(_yield_total(grievance), unurged, 0.0001)


func test_the_reply_never_touches_the_tribe() -> void:
	var grievance := _written(80.0)
	var tribe := run.tribes.find(grievance.tribe)
	_answer_phase()
	var standing := tribe.trust()
	_hears(_reply(TribeGrievance.YIELD), Compliance.COMPLY)
	assert_almost_eq(tribe.trust(), standing, 0.0001, "the PC's reply moved the tribe")


func test_the_validator_refuses_an_answer_there_is_not() -> void:
	var validator := ContentValidator.new()
	validator.check_tribe_answers(content)
	assert_true(validator.ok(), "the shipped letters do not validate")
	var letter: Dictionary = content.collection("letters")["governor.a_tribe_has_written"]
	letter["reply"]["steps"][0]["options"][0]["effect"]["answer_the_tribe"]["answer"] = "negotiate"
	validator = ContentValidator.new()
	validator.check_tribe_answers(content)
	assert_false(validator.ok(), "an answer a governor cannot give passed")


func test_what_he_asked_and_what_was_urged_survive_the_save() -> void:
	var grievance := _written(80.0)
	_answer_phase()
	_hears(_reply(TribeGrievance.GIFT), Compliance.COMPLY)
	var restored := TribeGrievances.from_dict(run.tribes.grievances.to_dict()).find(grievance.id)
	assert_eq(restored.asked_month, grievance.asked_month)
	assert_eq(String(restored.urged), String(TribeGrievance.GIFT))
	assert_eq(String(restored.urged_tone), String(Tone.DUTIFUL))


func test_the_turn_loop_hears_the_reply() -> void:
	assert_same(machine.orders.tribes, run.tribes, "the PC's reply about a tribe reaches no governor's letter")
