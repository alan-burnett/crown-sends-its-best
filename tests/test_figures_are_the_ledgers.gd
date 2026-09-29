extends TestCase

## Five letters print figures the simulation produced (#407, SPEC §9.1).
##
## 🔒 *A `{param:}` is exact and truthful.* The Steward's duties, the Chancellor's
## returns, what the Crown has laid out on the PC's word and what the colony pays
## for its tea each used to be colony revenue scaled and floored, printed as
## though it were something else. Each is now the figure the Ledger — or, for
## tea, the trade record — shows for the same thing, and the letters that only
## make sense when that figure is real fire only then.

const SEED: int = 407

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
	run.world.month = 18


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _trigger(id: String) -> Dictionary:
	return content.collection("triggers")["trigger.%s" % id]


func _fires(id: String, sender: StringName) -> bool:
	var director := machine.director
	return director._conditions_hold(_trigger(id), director._context(run, run.contact(sender)))


func _amount(id: String, sender: StringName) -> int:
	var director := machine.director
	var contact := run.contact(sender)
	var context := director._context(run, contact)
	var letter := Letter.from_record(content.record("letters", id))
	return int(director._inbound(_trigger(id), letter, contact, context, run).params.get("amount", -1))


func _bought(resource: String, month: int, spent: float, tax: float) -> void:
	run.log.emit(Trade.EVENT_BOUGHT, &"ashmere", month, {
		"town": "ashmere", "resource": resource, "quantity": 1.0,
		"spent": spent, "tax": tax,
	}, WorldPhase.COLONY_MONTH)


func _honoured(month: int, amount: float) -> void:
	run.log.emit(PromiseBook.EVENT_KEPT, &"steward", month, {
		"payer": Promise.PAYER_CROWN, "kind": "gold", "terms": {"amount": amount},
	}, WorldPhase.CROWNS_MONTH)


# --- 🔒 The duty is the Ledger's -------------------------------------------------

func test_the_stewards_duties_and_the_chancellors_returns_are_the_ledgers() -> void:
	_bought("food", run.world.month - 1, 100.0, 40.0)   # the month before: not this one
	_bought("food", run.world.month, 60.0, 12.4)
	_bought("cloth", run.world.month, 30.0, 5.2)
	var page := Ledger.of(run.log).page(run.world.month)
	var duty := int(roundf(page.received()))
	assert_eq(duty, 18, "the fixture's month is not the figure it meant")

	assert_eq(_amount("steward.revenue_report", &"steward"), duty,
		"the Steward's duties are not the Ledger's for the month just run")
	assert_eq(_amount("chancellor.how_to_answer", &"chancellor"), duty,
		"the Chancellor's returns are not the Ledger's for the month just run")


func test_the_chancellor_no_longer_speaks_of_arrears() -> void:
	# Nothing in the simulation is ever in arrears.
	var prose := JSON.stringify(content.record("letters", "chancellor.how_to_answer"))
	assert_false(prose.contains("arrears"), "the Chancellor still names a debt the colony does not owe")


# --- 🔒 Laid out on the PC's word, and only when it was ----------------------------

func test_the_stewards_standing_letters_print_what_the_crown_paid_and_only_then() -> void:
	for id in ["steward.standing_concern", "steward.standing_alarm"]:
		var trigger := _trigger(id)
		var conditions := JSON.stringify(trigger.get("conditions", []))
		assert_true(conditions.contains("treasury_honoured_this_year"),
			"%s may be sent with nothing paid on the PC's word" % id)
	var director := machine.director
	var context := director._context(run, run.contact(&"steward"))
	assert_false(ColonyConditions.treasury_honoured_this_year({"at_least": 1}, context))

	_honoured(run.world.month - 2, 150.0)
	_honoured(run.world.month, 70.0)
	var paid := int(roundf(CrownAccounts.of(run.log).paid_in_year_of(run.world.month)))
	assert_eq(_amount("steward.standing_concern", &"steward"), paid)
	assert_eq(_amount("steward.standing_alarm", &"steward"), paid)


# --- 🔒 What the tea cost, and only when there was tea ---------------------------

func test_the_tea_letter_names_what_the_colony_paid_and_only_when_it_bought_any() -> void:
	assert_false(_fires("steward.question_tea", &"steward"), "the Steward wrote about tea nobody buys")

	_bought("tea", run.world.month - 3, 500.0, 50.0)   # four months ago: outside the season
	_bought("tea", run.world.month - 2, 40.0, 4.0)
	_bought("tea", run.world.month, 25.4, 2.5)
	_bought("food", run.world.month, 90.0, 9.0)       # not tea
	assert_true(_fires("steward.question_tea", &"steward"), "the colony bought tea and he said nothing")
	assert_eq(_amount("steward.question_tea", &"steward"), 65,
		"the season's tea is not what the colony paid the Crown for it")


# --- 🔒 The rule that would have caught all six ----------------------------------

func test_a_scaled_world_value_printed_as_a_fact_fails_validation() -> void:
	var validator := ContentValidator.new()
	validator.check_scaled_figures(content)
	assert_true(validator.ok(), "the shipped content prints a scaled figure as a fact")

	var trigger := _trigger("steward.revenue_report")
	trigger["params"]["amount"] = {
		"from": "scaled_world_value", "key": "colony_revenue",
		"factor": 0.2, "minimum": 10, "maximum": 4000,
	}
	var caught := ContentValidator.new()
	caught.check_scaled_figures(content)
	assert_false(caught.ok(), "the Steward's old figure passed the check that was written to catch it")
