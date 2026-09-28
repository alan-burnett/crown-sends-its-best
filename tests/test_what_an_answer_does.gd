extends TestCase

## Two of compliance's outcomes, made to mean what they say (#449, `contacts.md`
## §3, `policy.md` §3, SPEC §8.5, §12.6).
##
## 🔒 **Full payment is a guaranteed yes** while the Crown can cover it — and a
## yes is compliance, not a part, a delay, a reading or a thing of his own. Once
## the Crown honours nothing, the payment is nothing and the guarantee goes.
##
## 🔒 **Whatever he agrees to, he enacts.** A policy works at full strength however
## it was agreed to; a delay enacts it when the delay is up; only a refusal
## enacts nothing.

const SEED: int = 449

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
	run.world.month = 14


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

## A shipment asked of him, paid `share` of what it costs him.
func _shipment(to: Contact, share: float) -> Order:
	var order := Order.new(M1Registrations.ORDER_SHIP_RESOURCE, to.id, {
		"to": String(to.id), "resource": "iron", "amount": 40, "payment": 0,
	}, run.world.month)
	order.params["payment"] = int(ceilf(Compliance.cost_of(order) * share))
	return order


func _filtered_by_full_payment(decision: Decision) -> int:
	var count := 0
	for entry in decision.entries:
		if String((entry as Dictionary).get("filtered_by", "")) == "full_payment_is_a_yes":
			count += 1
	return count


## A policy asked of the Marshal: his troops, at the PC's whole charge.
func _troops() -> Order:
	return Order.new(M1Registrations.ORDER_ENACT_POLICY, CrownTroops.MARSHAL, {
		"to": String(CrownTroops.MARSHAL), "effect": String(PolicyEffects.CROWN_TROOPS),
		"strength": String(CrownTroops.A_GARRISON), "posture": String(CrownTroops.HOLD_THE_TOWNS),
		"cost": 150, "split": String(Policy.ALL),
	}, run.world.month)


func _orders() -> OrderDriver:
	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.policies = run.policies
	return orders


func _his_troops() -> int:
	var count := 0
	for policy in run.policies.active():
		if policy.effect == PolicyEffects.CROWN_TROOPS and policy.enactor == CrownTroops.MARSHAL:
			count += 1
	return count


# --- 🔒 Full payment is a guaranteed yes -------------------------------------------

func test_paid_in_full_he_complies_however_little_he_thinks_of_the_pc() -> void:
	var asked := 0
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role != Contact.ROLE_GOVERNOR and contact.role != Contact.ROLE_CROWN_OFFICER:
			continue
		contact.relationship.loyalty = 2.0
		var order := _shipment(contact, 1.0)
		var result := Compliance.resolve(order, contact, run.intents, run.world, run.log, run.streams)
		assert_eq(String(result["outcome"]), String(Compliance.COMPLY),
			"%s, paid in full, answered %s" % [id, result["outcome"]])
		asked += 1
	assert_true(asked >= 3, "too few men asked to prove anything")


func test_short_of_full_payment_nothing_is_guaranteed() -> void:
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	var result := Compliance.resolve(_shipment(governor, 0.5), governor, run.intents, run.world, run.log, run.streams)
	assert_eq(_filtered_by_full_payment(result["decision"]), 0, "half the price was treated as the whole")


func test_once_the_crown_honours_nothing_the_guarantee_goes() -> void:
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	var paid := Compliance.resolve(_shipment(governor, 1.0), governor, run.intents, run.world, run.log, run.streams)
	assert_true(_filtered_by_full_payment(paid["decision"]) > 0, "full payment guaranteed nothing")

	var orders := _orders()
	orders.refusal = CrownRefusal.new()
	orders.refusal.state = CrownRefusal.REFUSING
	var order := _shipment(governor, 1.0)
	order.issued_month = run.world.month - 1
	orders.carry(order)
	orders.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_eq(orders.results.size(), 1)
	assert_eq(_filtered_by_full_payment(orders.results[0]["decision"]), 0,
		"a payment the Crown will not honour still guaranteed a yes")


# --- 🔒 Whatever he agrees to, he enacts ------------------------------------------

func test_what_he_agrees_to_he_enacts_now_and_troops_in_part_are_one_strength_less() -> void:
	# 🔒 #449 (`contacts.md` §3): a policy agreed to, whole or in part, is enacted
	# whole — but troops granted in part, or as the Marshal's own decision, land
	# one strength less than asked.
	var marshal := run.contact(CrownTroops.MARSHAL)
	var force := _troops()
	force.params["strength"] = String(CrownTroops.A_FORCE)
	var landed := {
		Compliance.COMPLY: CrownTroops.A_FORCE,
		Compliance.PARTIAL: CrownTroops.A_GARRISON,
		Compliance.ACT_ALONE: CrownTroops.A_GARRISON,
	}
	for outcome in landed:
		run.policies = PolicyBook.new()
		_orders()._enact_if_agreed(force, marshal, {"outcome": String(outcome)}, run.world, run.log)
		assert_eq(_his_troops(), 1, "%s enacted nothing" % outcome)
		assert_eq(String(run.policies.active()[0].params.get("strength", "")), String(landed[outcome]),
			"%s landed the wrong strength" % outcome)
	run.policies = PolicyBook.new()
	_orders()._enact_if_agreed(_troops(), marshal, {"outcome": String(Compliance.PARTIAL)}, run.world, run.log)
	assert_eq(_his_troops(), 0, "a garrison granted in part landed a garrison")
	run.policies = PolicyBook.new()
	_orders()._enact_if_agreed(_troops(), marshal, {"outcome": String(Compliance.REFUSE)}, run.world, run.log)
	assert_eq(_his_troops(), 0, "a refusal enacted the policy")


func test_acting_alone_a_policy_is_not_enacted() -> void:
	# 🔒 #449: acting alone, he carries on as he was (c6fd0b5 enacted it).
	var provost := run.contact(&"provost")
	var policy := Order.new(M1Registrations.ORDER_ENACT_POLICY, &"provost", {
		"to": "provost", "effect": String(PolicyEffects.IMMIGRATION), "cost": 50, "split": String(Policy.ALL),
	}, run.world.month)
	run.policies = PolicyBook.new()
	_orders()._enact_if_agreed(policy, provost, {"outcome": String(Compliance.ACT_ALONE)}, run.world, run.log)
	assert_empty(run.policies.held_by(&"provost"), "a man acting alone enacted the PC's policy")


func test_a_delay_enacts_it_when_the_delay_is_up() -> void:
	var marshal := run.contact(CrownTroops.MARSHAL)
	var order := _troops()
	var intent := Compliance._intent_for(order, Compliance.DELAY, marshal)
	_orders()._enact_if_agreed(order, marshal, {"outcome": String(Compliance.DELAY), "intent": intent}, run.world, run.log)
	assert_eq(_his_troops(), 0, "a delay enacted the policy at once")

	var executor := PolicyEnactExecutor.new()
	executor.policies = run.policies
	var months := 0
	var resolution := Intent.IN_PROGRESS
	while resolution == Intent.IN_PROGRESS and months < 12:
		resolution = executor.execute(intent, run.world, run.log)
		months += 1
	assert_eq(String(resolution), String(Intent.COMPLETED))
	assert_eq(months, Compliance.MONTHS_FOR[Compliance.DELAY], "the delay was not the delay")
	assert_eq(_his_troops(), 1, "the delayed policy never came")


func test_a_policy_enacted_at_once_is_not_enacted_again() -> void:
	var marshal := run.contact(CrownTroops.MARSHAL)
	var order := _troops()
	var intent := Compliance._intent_for(order, Compliance.COMPLY, marshal)
	_orders()._enact_if_agreed(order, marshal, {"outcome": String(Compliance.COMPLY), "intent": intent}, run.world, run.log)
	var executor := PolicyEnactExecutor.new()
	executor.policies = run.policies
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.COMPLETED))
	assert_eq(_his_troops(), 1, "the policy was enacted twice")


func test_the_turn_loop_enacts_the_delayed() -> void:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	var found := false
	for executor in machine.month_runner.executors:
		if executor is PolicyEnactExecutor:
			found = true
			break
		assert_false(executor is WorldValueExecutor, "the table executor answers for policies before the enactor can")
	assert_true(found, "nothing in the month enacts a delayed policy")
