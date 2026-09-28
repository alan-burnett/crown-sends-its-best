extends TestCase

## Retrench is a promise, encouraging immigration is the Provost's, and no
## choice does nothing (#451, `crown-standing.md` §3, `immigration.md` §4,
## `reply-vocabulary.md` §4, SPEC §9.2).

const SEED: int = 451

## The seven letters whose choices did nothing, now tone-only replies.
const TONE_ONLY: Array = [
	"chancellor.colony_dwindling", "chancellor.last_chance", "chancellor.squeeze_desperation",
	"chancellor.squeeze_frequency", "chancellor.squeeze_reach", "chancellor.squeeze_size",
	"governor.we_are_coming_back",
]

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.world.month = 20


func after_each() -> void:
	reset_world()
	content.free()


# --- 🔒 Retrench is a promise ---------------------------------------------------

## The retrench option of a Chancellor's warning, as the Order it makes.
func _retrench(letter_id: String) -> Order:
	var record: Dictionary = content.record("letters", letter_id)
	var context := LetterContext.new(run.world, run.contact(&"chancellor"), Tone.DUTIFUL)
	context.month = run.world.month
	for step in record["reply"]["steps"]:
		for option in step["options"]:
			if String(option["id"]) == "retrench":
				var effect: Dictionary = option["effect"]
				var id: String = effect.keys()[0]
				return ContentRegistry.run_effect(id, effect[id], context)
	return null


## The Crown's books for the promise's six months: `took` in duty and `paid` out
## on the PC's word, each month.
func _months_of(took: float, paid: float) -> void:
	for month in range(run.world.month + 1, run.world.month + 7):
		run.log.emit(Trade.EVENT_SOLD, &"ashmere", month, {"tax": took}, WorldPhase.COLONY_MONTH)
		run.log.emit(PromiseBook.EVENT_KEPT, &"steward", month, {
			"payer": Promise.PAYER_CROWN, "kind": "gold", "terms": {"amount": paid},
		}, WorldPhase.CROWNS_MONTH)


func _settle(took: float, paid: float) -> Promise:
	var order := _retrench("chancellor.warning_standing")
	var promise := PromiseBook.from_order(order, run.world.month)
	run.promises.make(promise, run.contact(&"chancellor"), run.log, run.world.month)
	_months_of(took, paid)
	var driver := PromiseDriver.new(run.promises)
	driver.contacts = run.contacts
	var due := run.world.month + 6
	run.promises.settle_due(run.contacts, run.log, due, true, driver._wagers_won(run.log, due))
	return promise


func test_both_warnings_offer_retrenching_as_a_six_month_promise() -> void:
	for letter_id in ["chancellor.warning_standing", "chancellor.final_warning"]:
		var order := _retrench(letter_id)
		assert_eq(String(order.kind), String(M1Registrations.ORDER_PROMISE_TO_RETRENCH), letter_id)
		var promise := PromiseBook.from_order(order, run.world.month)
		assert_eq(String(promise.kind), String(Promise.KIND_RETRENCH))
		assert_eq(promise.due_month, run.world.month + 6, "%s is not six months" % letter_id)
		assert_eq(String(promise.payer), String(Promise.PAYER_COLONY),
			"a Crown that refuses payments could break a promise that is not its money")


func test_spending_no_more_than_the_colony_brings_in_keeps_it() -> void:
	var chancellor := run.contact(&"chancellor")
	var before := chancellor.loyalty()
	var promise := _settle(100.0, 60.0)
	assert_eq(String(promise.status), String(Promise.KEPT), "he spent less than the colony returned and broke his word")
	assert_true(chancellor.loyalty() > before, "a kept promise did not warm the Chancellor")


func test_spending_more_than_it_brings_in_breaks_it() -> void:
	var promise := _settle(60.0, 100.0)
	assert_eq(String(promise.status), String(Promise.BROKEN), "he spent more than the colony returned and kept his word")
	var remembered := false
	for memory in run.contact(&"chancellor").relationship.history:
		if String(memory.kind) == String(Relationship.PROMISE_BROKEN):
			remembered = true
	assert_true(remembered, "the Chancellor forgot the promise broken")


# --- 🔒 Encouraging immigration -----------------------------------------------------

func _recipients(letter_id: String) -> Variant:
	for purpose in Composer.new(content).purposes(run):
		if String(purpose["letter_id"]) == letter_id:
			return purpose["recipients"]
	return null


func test_the_provosts_policy_moves_the_immigration_he_governs() -> void:
	assert_eq(_recipients("pc.ask_for_a_policy"), [&"provost"], "somebody other than the Provost was asked")
	var book := PolicyBook.new()
	book.enact(Policy.new(&"provost", PolicyEffects.IMMIGRATION, 100.0, Policy.ALL), run.log, run.world.month)
	var pressed := float(PolicyEffects.pressure(book).get(PolicyEffects.VOLUME_KEY, 0.0))
	assert_true(pressed > 0.0, "encouraging immigration presses on nothing Immigration reads")


func test_asked_of_a_governor_it_urges_go_tall() -> void:
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	assert_true((_recipients("pc.encourage_settlers") as Array).has(governor.id))
	var record: Dictionary = content.record("letters", "pc.encourage_settlers")
	var context := LetterContext.new(run.world, null, Tone.DUTIFUL)
	context.params = {"to": String(governor.id)}
	var option: Dictionary = record["reply"]["steps"][0]["options"][0]
	var order := ContentRegistry.run_effect("urge_intent", option["effect"]["urge_intent"], context)
	assert_eq(String(order.kind), String(M1Registrations.ORDER_URGE_INTENT))
	assert_eq(String(order.get_param("intent", "")), String(GovernorIntent.GO_TALL))


# --- 🔒 A choice with no effect is not a choice -------------------------------------

func test_the_seven_letters_offer_no_choice_and_an_apology_is_a_word() -> void:
	for letter_id in TONE_ONLY:
		var letter := Letter.from_record(content.record("letters", letter_id))
		assert_true(letter.steps().is_empty(), "%s still offers a choice that does nothing" % letter_id)
		assert_true(letter.has_tone_step(), "%s lost its tone-only reply" % letter_id)
	var draft: Dictionary = content.record("letters", "steward.draft_returned")
	var apology: Dictionary = {}
	for option in draft["reply"]["steps"][0]["options"]:
		if String(option["id"]) == "apologise":
			apology = option
	assert_eq(apology.get("effect", {}), {"apologise": {"to": "steward"}}, "'this is my doing' is not an apology")


func test_the_validator_refuses_a_step_whose_options_all_do_nothing() -> void:
	var record := {
		"id": "marshal.nothing_to_choose",
		"_source_file": "res://data/letters_en/marshal/nothing_to_choose.json",
		"sender": "marshal", "type": "request", "params": {},
		"body": [{"text": "A question."}],
		"reply": {"steps": [{"id": "answer", "prompt": "The answer", "options": [
			{"id": "yes", "label": "yes", "text": "Yes."},
			{"id": "no", "label": "no", "text": "No."},
		]}]},
	}
	var validator := ContentValidator.new()
	validator.validate_letter(record)
	assert_false(validator.ok(), "a choice that does nothing passed the validator")

	record["reply"]["steps"][0]["options"][0]["effect"] = {"refuse": {"to": "marshal"}}
	var passing := ContentValidator.new()
	passing.validate_letter(record)
	assert_true(passing.ok(), "a step with one option that does something was refused")
