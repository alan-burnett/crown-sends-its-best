extends TestCase

## A patron's policies (#440, `patrons.md` §4; `policy.md` §3, §4, §6, §8).
##
## 🔒 **A policy of his standing when he leaves outlives him.** The charge and
## the drain end and the effect stays for the run.
##
## 🔒 **Ended while he is here, it ends**, and nothing brings it back when he
## sails. The PC cancelling costs his regard.
##
## 🔒 **He warns before he lets an unpaid one go**, in his own letter.

const SEED: int = 440
const LAPSING := "trigger.patron.policy_lapsing"
const MARKET := "patron.his_barony_would_buy"

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

## A patron who will sail in month `leaves`.
func _patron(leaves: int = 40, loyalty: float = 60.0) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, loyalty)
	patron.leaves_month = leaves
	run.add_contact(patron)
	return patron


## His Barony buying sugar from the colony, the PC bearing `split` of it.
func _market(patron: Contact, split: StringName = Policy.HALF) -> Policy:
	return run.policies.enact(Policy.new(patron.id, PolicyEffects.FAVOUR_OUR_MARKET, 90.0,
		split, {"resource": "sugar"}), run.log, 3)


func _month(month: int) -> void:
	run.policies.bill(run.contacts, run.log, month)
	run.policies.take_stock(run.log, month)
	PatronTerm.advance(run, run.log, month)


func _price_is_lifted() -> bool:
	return PolicyEffects.pressure(run.policies).has(PolicyEffects.PRICE_PREFIX + "sugar")


func _true(trigger_id: String, patron: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[trigger_id], director._context(run, patron))


# --- 🔒 The PC's share --------------------------------------------------------------------

func test_his_market_can_be_answered_with_all_half_or_none_of_the_charge() -> void:
	var splits := PackedStringArray()
	for option in content.record("letters", MARKET)["reply"]["steps"][0]["options"]:
		var effect: Dictionary = option.get("effect", {})
		if effect.has("enact_policy_on"):
			splits.append(String(effect["enact_policy_on"]["split"]))
	splits.sort()
	assert_eq(splits, PackedStringArray(["all", "half", "none"]))


# --- 🔒 It outlives him ---------------------------------------------------------------------

func test_a_policy_standing_when_he_leaves_keeps_its_effect_with_no_charge() -> void:
	var patron := _patron(40)
	var policy := _market(patron, Policy.HALF)
	_month(40)
	assert_false(run.contacts.has(String(patron.id)), "he never sailed")
	assert_true(policy.permanent, "his policy did not outlive him")
	assert_true(run.policies.active().has(policy), "his policy went home with him")

	var billed := run.log.of_type(PolicyBook.EVENT_BILLED).size()
	for month in range(41, 60):
		assert_almost_eq(run.policies.bill(run.contacts, run.log, month), 0.0, 0.0001,
			"the Crown is still charged for a policy nobody holds")
		run.policies.take_stock(run.log, month)
	assert_eq(run.log.of_type(PolicyBook.EVENT_BILLED).size(), billed, "it went on being billed")
	assert_true(run.policies.active().has(policy), "a permanent policy lapsed")
	assert_true(_price_is_lifted(), "the Crown's price fell back when he sailed")


func test_a_bounced_draft_cannot_shake_a_policy_nobody_holds() -> void:
	var patron := _patron(40)
	var policy := _market(patron, Policy.ALL)
	_month(40)
	assert_true(run.policies.crown_stopped_paying(run.log, 41, run.contacts).is_empty(),
		"a permanent policy was put into renegotiation with a man who has gone")
	assert_true(policy.permanent)


func test_a_warning_he_gave_goes_with_him() -> void:
	var patron := _patron(40)
	var policy := _market(patron, Policy.NONE)
	policy.warned_month = 38
	policy.ends_month = 41
	_month(40)
	_month(41)
	assert_true(run.policies.active().has(policy), "a policy standing when he sailed lapsed on his warning")
	assert_false(policy.is_warning())


func test_only_his_policies_outlive_him() -> void:
	var patron := _patron(40)
	var steward_policy := run.policies.enact(
		Policy.new(&"steward", PolicyEffects.IMMIGRATION, 100.0, Policy.HALF), run.log, 3)
	_market(patron)
	_month(40)
	assert_false(steward_policy.permanent, "another man's policy outlived a patron")
	assert_true(run.policies.bill(run.contacts, run.log, 41) > 0.0)


# --- 🔒 Ended while he is here, it ends ------------------------------------------------------

func test_one_cancelled_before_he_leaves_ends_and_costs_his_regard() -> void:
	var patron := _patron(40, 60.0)
	var policy := _market(patron, Policy.ALL)
	var before := patron.loyalty()
	assert_true(run.policies.cancel(policy.id, run.contacts, run.log, 20))
	assert_true(patron.loyalty() < before, "cancelling his policy cost him nothing")
	_month(40)
	assert_false(run.policies.active().has(policy), "a cancelled policy came back when he sailed")
	assert_false(_price_is_lifted())


func test_one_that_lapsed_before_he_leaves_is_not_brought_back() -> void:
	var patron := _patron(40)
	var policy := _market(patron, Policy.NONE)
	run.policies.lapse(policy.id, run.log, 30)
	_month(40)
	assert_false(run.policies.active().has(policy))
	assert_true(run.log.of_type(PolicyBook.EVENT_MADE_PERMANENT).is_empty(),
		"a lapsed policy was made permanent")


# --- 🔒 He warns in his own letter ----------------------------------------------------------

func test_an_unpaid_policy_of_his_brings_his_renegotiation_letter() -> void:
	var patron := _patron(200)
	var policy := _market(patron, Policy.NONE)
	assert_false(_true(LAPSING, patron), "he wrote before he had carried anything")
	for month in range(4, 4 + PolicyBook.PATIENCE + 1):
		run.policies.bill(run.contacts, run.log, month)
		run.policies.take_stock(run.log, month)
	assert_true(policy.is_warning(), "he carried it past his patience and never warned")
	assert_true(_true(LAPSING, patron), "he will not carry it further and never wrote")


func test_a_patron_whose_policy_is_paid_for_writes_no_such_letter() -> void:
	var patron := _patron(200)
	_market(patron, Policy.ALL)
	for month in range(4, 4 + PolicyBook.PATIENCE + 1):
		run.policies.bill(run.contacts, run.log, month)
		run.policies.take_stock(run.log, month)
	assert_false(_true(LAPSING, patron))


func test_his_letter_names_the_charge_and_the_months_left() -> void:
	var patron := _patron(200)
	var policy := _market(patron, Policy.NONE)
	policy.warned_month = 10
	policy.ends_month = 13
	run.world.month = 10
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[LAPSING]
	var letter := Letter.from_record(content.record("letters", "patron.policy_lapsing"))
	var context := director._context(run, patron)
	var params: Dictionary = director._inbound(trigger, letter, patron, context, run).params
	assert_eq(int(params.get("cost", 0)), 90)
	assert_eq(int(params.get("months", 0)), 3)
	assert_eq(String(params.get("patron", "")), String(patron.id))


# --- 🔒 Saved ------------------------------------------------------------------------------

func test_a_permanent_policy_survives_a_save() -> void:
	var patron := _patron(40)
	_market(patron)
	_month(40)
	var restored := PolicyBook.from_dict(run.policies.to_dict())
	assert_true(restored.active()[0].permanent, "a reloaded run charges for a policy nobody holds")
