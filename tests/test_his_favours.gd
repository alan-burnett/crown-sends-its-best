extends TestCase

## A contact remembers what he did for the PC (#397, `contacts.md` §6, §7; the
## Author's ruling is on the ticket).
##
## 🔒 **His favours**: complying, in whole or part, with a costly PC order,
## worth what compliance prices it at; goods he shipped, when the shipment ends;
## a patron's expert, gold or men, when they arrive. Duty, refusal, and what the
## PC gave him are not favours of his.
##
## 🔒 **They fade**: a favour weighs half as much every `FAVOUR_HALF_LIFE`
## months, so an older favour weighs less than a recent one of the same size.
##
## 🔒 **He can ask on one**, naming what he sent, only when there is one to name.

const SEED: int = 397
const ASK := "trigger.governor.remember_what_i_sent"

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


func _favours(contact: Contact) -> Array[Recollection]:
	return contact.relationship.favours


func _remembered(order: Order, contact: Contact, outcome: StringName) -> void:
	Compliance._remember_his_favour(order, contact, outcome, run.world.month)


## A shipment of `amount` iron the governor ran on the PC's order, ended this
## month with all of it gone.
func _shipped(amount: float, origin: StringName = Intent.ORIGIN_ORDER) -> void:
	var intent := Intent.new(&"", Shipment.KIND, _governor().id, _governor().id, 6,
		{"resource": "iron", "amount": amount, "shipped": amount})
	intent.origin = origin
	run.intents.commit(intent, run.log, run.world.month)
	run.intents.resolve(intent, Intent.COMPLETED, run.log, run.world.month)


func _remember_the_month() -> void:
	FavourDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


func _patron(specialty: String) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.specialty = specialty
	run.add_contact(patron)
	return patron


# --- 🔒 What counts ------------------------------------------------------------------------

func test_complying_with_a_costly_order_is_remembered_at_its_price() -> void:
	var order := Order.new(M1Registrations.ORDER_REQUEST_TROOPS, &"marshal", {"to": "marshal", "amount": 500})
	var marshal := run.contact(&"marshal")
	_remembered(order, marshal, Compliance.COMPLY)
	assert_eq(_favours(marshal).size(), 1, "he complied with a costly order and it was forgotten")
	var favour: Recollection = _favours(marshal)[0]
	assert_eq(String(favour.kind), String(Relationship.FAVOUR_COMPLIED))
	assert_almost_eq(favour.worth, float(Compliance._priced(order)), 0.001)


func test_the_months_compliance_remembers_it() -> void:
	# Through `Compliance.resolve`, which is where every Order is read. An embargo
	# is always carried out, and it costs the governor dearly.
	var governor := _governor()
	var order := Order.new(M1Registrations.ORDER_EMBARGO, governor.id, {"to": String(governor.id), "months": 3})
	Compliance.resolve(order, governor, run.intents, run.world, run.log, run.streams)
	assert_eq(_favours(governor).size(), 1, "he carried out a costly order and forgot it")


func test_partial_compliance_is_remembered_at_the_share_he_did() -> void:
	var order := Order.new(M1Registrations.ORDER_REQUEST_TROOPS, &"marshal", {"to": "marshal", "amount": 500})
	var marshal := run.contact(&"marshal")
	_remembered(order, marshal, Compliance.PARTIAL)
	assert_almost_eq(_favours(marshal)[0].worth,
		float(Compliance._priced(order)) * Compliance.partial_share(order), 0.001)


func test_refusal_duty_and_the_pcs_own_gifts_are_not_favours_of_his() -> void:
	var marshal := run.contact(&"marshal")
	var costly := Order.new(M1Registrations.ORDER_REQUEST_TROOPS, &"marshal", {"to": "marshal", "amount": 500})
	_remembered(costly, marshal, Compliance.REFUSE)
	_remembered(costly, marshal, Compliance.DELAY)
	_remembered(Order.new(M1Registrations.ORDER_PROMISE_GOLD, &"marshal", {"to": "marshal", "amount": 500}),
		marshal, Compliance.COMPLY)
	_remembered(Order.new(M1Registrations.ORDER_URGE_INTENT, &"marshal", {"to": "marshal"}),
		marshal, Compliance.COMPLY)
	assert_empty(_favours(marshal), "something that was not his favour was remembered as one")


func test_a_shipment_is_not_a_favour_until_the_goods_leave() -> void:
	var governor := _governor()
	_remembered(Order.new(M1Registrations.ORDER_SHIP_RESOURCE, governor.id,
		{"to": String(governor.id), "resource": "iron", "amount": 120, "payment": 0}), governor, Compliance.COMPLY)
	assert_empty(_favours(governor), "agreeing to ship was remembered before anything was shipped")


func test_goods_he_shipped_are_remembered_when_the_shipment_ends() -> void:
	_shipped(120.0)
	_remember_the_month()
	var favours := _favours(_governor())
	assert_eq(favours.size(), 1, "the goods left his town and he forgot it")
	var favour: Recollection = favours[0]
	assert_eq(String(favour.kind), String(Relationship.FAVOUR_SHIPPED))
	assert_almost_eq(favour.magnitude, 120.0, 0.001)
	assert_eq(favour.subject, "iron")
	assert_almost_eq(favour.worth, 120.0 * ResourceCatalogue.price_of(&"iron"), 0.001)


func test_goods_he_sent_of_his_own_accord_are_not_the_pcs_to_be_thanked_for() -> void:
	_shipped(120.0, Intent.ORIGIN_WILL)
	_remember_the_month()
	assert_empty(_favours(_governor()))


func test_a_patrons_gifts_are_remembered_when_they_arrive() -> void:
	var gold := _patron("gold")
	GoldGiftExecutor.new().execute(Intent.new(&"", GoldGiftExecutor.KIND, gold.id, gold.id, 1,
		{"amount": 300.0}), run.world, run.log)
	var experts := _patron("experts")
	_town().buildings.append("library")
	var landing := ExpertGiftExecutor.new()
	landing.colony = run.colony
	landing.execute(Intent.new(&"", ExpertGiftExecutor.KIND, experts.id, experts.id, 1,
		{"resource": "tobacco"}), run.world, run.log)
	_remember_the_month()
	assert_eq(_favours(gold).size(), 1, "his gold was forgotten")
	assert_eq(_favours(experts).size(), 1, "his expert was forgotten")
	if _favours(gold).size() == 1 and _favours(experts).size() == 1:
		assert_almost_eq(_favours(gold)[0].worth, 300.0, 0.001)
		assert_eq(_favours(experts)[0].subject, "tobacco")


func test_a_patrons_men_are_remembered_when_they_land_and_not_before() -> void:
	var patron := _patron("troops")
	var order := Order.new(M1Registrations.ORDER_ENACT_POLICY, patron.id, {"to": String(patron.id),
		"effect": String(PolicyEffects.CROWN_TROOPS), "strength": "a_garrison",
		"posture": "hold_the_towns", "cost": 150, "split": "none"})
	_remembered(order, patron, Compliance.COMPLY)
	assert_empty(_favours(patron), "his men were remembered before they landed")
	run.policies.enact(Policy.new(patron.id, PolicyEffects.CROWN_TROOPS, 150.0, Policy.NONE,
		{"strength": "a_garrison", "posture": "hold_the_towns"}), run.log, run.world.month)
	CrownTroops.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	_remember_the_month()
	assert_eq(_favours(patron).size(), 1, "his men landed and he forgot it")
	assert_almost_eq(_favours(patron)[0].worth, 150.0 * FavourDriver.TROOPS_WORTH_MONTHS, 0.001)


# --- 🔒 They fade ------------------------------------------------------------------------------

func test_an_older_favour_weighs_less_than_a_recent_one_of_the_same_size() -> void:
	var relationship := Relationship.new(&"someone")
	relationship.remember_favour(Relationship.FAVOUR_SHIPPED, 0, 100.0, "iron", 500.0)
	relationship.remember_favour(Relationship.FAVOUR_SHIPPED, 30, 100.0, "wood", 500.0)
	assert_eq(relationship.most_valuable_favour(36).subject, "wood")
	assert_almost_eq(Relationship.worth_now(relationship.favours[0], int(Relationship.FAVOUR_HALF_LIFE)),
		250.0, 0.001, "a favour did not weigh half as much after its half-life")


func test_a_much_greater_old_favour_can_still_outweigh_a_small_new_one() -> void:
	var relationship := Relationship.new(&"someone")
	relationship.remember_favour(Relationship.FAVOUR_SHIPPED, 0, 400.0, "iron", 2000.0)
	relationship.remember_favour(Relationship.FAVOUR_SHIPPED, 30, 10.0, "wood", 100.0)
	assert_eq(relationship.most_valuable_favour(36).subject, "iron")


func test_they_never_crowd_out_what_the_pc_did_to_him() -> void:
	var relationship := Relationship.new(&"someone")
	relationship.remember(Relationship.GRANTED, 1, 50.0, "food")
	for month in 30:
		relationship.remember_favour(Relationship.FAVOUR_SHIPPED, month, 10.0, "iron", 100.0 + month)
	assert_eq(relationship.history.size(), 1, "his favours pushed the PC's kindness out of his memory")
	assert_eq(relationship.favours.size(), Relationship.MEMORY_LIMIT)


func test_they_survive_a_save() -> void:
	var relationship := Relationship.new(&"someone")
	relationship.remember_favour(Relationship.FAVOUR_SHIPPED, 7, 120.0, "iron", 900.0)
	var restored := Relationship.from_dict(relationship.to_dict())
	assert_eq(restored.favours.size(), 1)
	assert_almost_eq(restored.favours[0].worth, 900.0, 0.001)
	assert_eq(restored.favours[0].subject, "iron")


# --- 🔒 He asks on one -----------------------------------------------------------------------

func test_a_governor_who_shipped_goods_can_ask_something_back_naming_them() -> void:
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[ASK]
	assert_false(director._conditions_hold(trigger, director._context(run, _governor())),
		"he asked on a favour he never did")
	_shipped(120.0)
	_remember_the_month()
	var context := director._context(run, _governor())
	assert_true(director._conditions_hold(trigger, context), "he shipped the goods and never asked")
	var letter := Letter.from_record(content.record("letters", "governor.remember_what_i_sent"))
	var params := director._inbound(trigger, letter, _governor(), context, run).params
	assert_eq(int(params.get("sent_amount", 0)), 120)
	assert_eq(String(params.get("sent_resource", "")), "iron")
	assert_true(int(params.get("ask", 0)) > 0, "he asked for nothing")
	assert_eq(String(params.get("town", "")), _town().display_name)


func test_he_cannot_ask_on_a_favour_he_cannot_name() -> void:
	_governor().relationship.remember_favour(Relationship.FAVOUR_COMPLIED, 0, 3.0, "", 2000.0)
	var director := machine.director
	assert_false(director._conditions_hold(content.collection("triggers")[ASK], director._context(run, _governor())),
		"he asked on a favour he could not describe")


func test_the_turn_loop_remembers() -> void:
	var found := false
	for driver in machine.month_runner.drivers:
		found = found or driver is FavourDriver
	assert_true(found, "nothing in the month remembers what a contact did for the PC")
