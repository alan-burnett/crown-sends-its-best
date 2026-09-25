extends TestCase

## A patron asks for his need, and a shipment delivered is the deed that banks
## (#441, `patrons.md` §4, §10; `crown-demands.md` §5).
##
## 🔒 **Agreeing is a promise of goods to him**, made good only through a
## governor (`pc.request_shipment`), exactly as the Marshal's requisition is.
##
## 🔒 **Delivering it banks with the court; agreeing alone does not**, and goods
## promised and never sent cost what a refusal would.

const SEED: int = 441
const NEED := "trigger.patron.his_need"

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

## A patron who wants wood.
func _patron() -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, 60.0)
	patron.need = "resources"
	patron.need_kind = "wood"
	run.add_contact(patron)
	return patron


func _context(patron: Contact) -> LetterContext:
	return machine.director._context(run, patron)


## The params his letter carries, as the director fills them.
func _params(patron: Contact) -> Dictionary:
	var director := machine.director
	var letter := Letter.from_record(content.record("letters", "patron.his_need"))
	var context := _context(patron)
	return director._inbound(content.collection("triggers")[NEED], letter, patron, context, run).params


## The Order the PC's answer produces.
func _answer(patron: Contact, option_id: String) -> Order:
	var context := _context(patron)
	context.params = _params(patron)
	context.tone = Tone.DUTIFUL
	for option in content.record("letters", "patron.his_need")["reply"]["steps"][0]["options"]:
		if String(option["id"]) != option_id:
			continue
		var effect: Dictionary = option["effect"]
		var id: String = effect.keys()[0]
		return ContentRegistry.run_effect(id, effect[id], context)
	return null


## His reply read, the month's compliance run over it, and the promise recorded.
func _read(order: Order, month: int = 1) -> void:
	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	order.issued_month = month
	orders.carry(order)
	orders.on_phase(WorldPhase.RECKONING, _state(month), run.log, run.streams)


func _state(month: int) -> WorldState:
	run.world.month = month
	return run.world


func _shipped(month: int, resource: String, quantity: float) -> void:
	run.log.emit(ShipmentExecutor.EVENT_SENT, &"ashmere", month, {
		"town": "ashmere", "resource": resource, "quantity": quantity,
		"shipped": quantity, "of": quantity, "tier": "need",
	}, WorldPhase.MOVEMENT)


func _settle(month: int) -> void:
	var driver := PromiseDriver.new(run.promises)
	driver.contacts = run.contacts
	driver.on_phase(WorldPhase.CROWNS_MONTH, _state(month), run.log, run.streams)


func _credit() -> float:
	return float(Prestige.of(run.log)["patron_credit"])


# --- 🔒 He asks ---------------------------------------------------------------------------

func test_he_asks_for_his_need_by_its_kind() -> void:
	var patron := _patron()
	assert_true(machine.director._conditions_hold(content.collection("triggers")[NEED], _context(patron)),
		"a patron with a need never asks for it")
	var params := _params(patron)
	assert_eq(String(params.get("resource", "")), "wood", "his letter does not name his need")
	assert_true(int(params.get("amount", 0)) > 0, "he asked for none of it")
	assert_true(int(params.get("months", 0)) > 0, "he gave no term")


func test_he_does_not_ask_again_while_a_promise_to_him_stands() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	assert_false(machine.director._conditions_hold(content.collection("triggers")[NEED], _context(patron)),
		"he wrote for more while the last shipment was still owed him")


# --- 🔒 Agreeing is a promise of goods --------------------------------------------------------

func test_agreeing_promises_him_a_shipment_of_his_kind() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	var promises := run.promises.outstanding()
	assert_eq(promises.size(), 1, "agreeing promised nothing")
	var promise: Promise = promises[0]
	assert_eq(promise.to, patron.id)
	assert_eq(String(promise.kind), String(Promise.KIND_SHIPMENT))
	assert_eq(String(promise.payer), String(Promise.PAYER_COLONY), "the Crown was made to pay for goods")
	assert_eq(String(promise.terms.get("resource", "")), "wood")


func test_agreeing_alone_banks_nothing() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	assert_almost_eq(_credit(), 0.0, 0.0001, "the court heard of goods that had not left the colony")


func test_declining_is_a_refusal_the_court_hears_of() -> void:
	var patron := _patron()
	_read(_answer(patron, "decline"))
	assert_true(_credit() < 0.0)


# --- 🔒 Delivering it banks --------------------------------------------------------------------

func test_delivering_it_banks() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	var promise: Promise = run.promises.outstanding()[0]
	_shipped(promise.made_month + 1, "wood", promise.amount())
	_settle(promise.due_month)
	assert_eq(String(promise.status), String(Promise.KEPT), "the goods arrived and the promise was not kept")
	assert_true(_credit() > 0.0, "his need was met and the court heard nothing of it")


func test_goods_promised_and_never_sent_cost_at_court() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	var promise: Promise = run.promises.outstanding()[0]
	_settle(promise.due_month)
	assert_eq(String(promise.status), String(Promise.BROKEN))
	assert_true(_credit() < 0.0, "promising a patron goods and never sending them cost nothing at court")


func test_the_wrong_goods_do_not_meet_it() -> void:
	var patron := _patron()
	_read(_answer(patron, "agree"))
	var promise: Promise = run.promises.outstanding()[0]
	_shipped(promise.made_month + 1, "iron", promise.amount())
	_settle(promise.due_month)
	assert_eq(String(promise.status), String(Promise.BROKEN))


# --- 🔒 The Marshal's demand is his own ---------------------------------------------------------

func test_undertaking_his_need_leaves_the_marshals_demand_standing() -> void:
	var patron := _patron()
	var demands := DemandBook.new()
	demands.asker = &"marshal"
	var to_him := Order.new(M1Registrations.ORDER_PROMISE_SHIPMENT, patron.id, {"resource": "wood"})
	var to_the_marshal := Order.new(M1Registrations.ORDER_PROMISE_SHIPMENT, &"marshal", {"resource": "iron"})
	assert_false(TurnMachine.answers_the_demand(to_him, demands),
		"a promise to a patron answered the Marshal's requisition")
	assert_true(TurnMachine.answers_the_demand(to_the_marshal, demands))
	assert_true(TurnMachine.answers_the_demand(
		Order.new(M1Registrations.ORDER_DECLINE_DEMAND, &"marshal", {}), demands))
