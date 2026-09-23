extends TestCase

## Promise tracking (#17).

const SEED: int = 1215

var log: EventLog = null
var book: PromiseBook = null
var contacts: Dictionary = {}
var marshal: Contact = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	log = EventLog.new()
	book = PromiseBook.new()
	marshal = Contact.from_data({"id": "marshal", "name": "Vane", "loyalty": 50})
	contacts = {"marshal": marshal}


func after_each() -> void:
	reset_world()


func _gold(amount: int, month: int = 0) -> Promise:
	return book.make(Promise.new(&"marshal", &"gold", {"amount": amount}, month, 0), marshal, log, month)


# --- Making ----------------------------------------------------------------

func test_a_promise_is_recorded_against_the_relationship() -> void:
	var promise := _gold(500)
	assert_eq(book.outstanding().size(), 1)
	assert_true(marshal.relationship.outstanding_promises.has(String(promise.id)))
	assert_eq(log.of_type(PromiseBook.EVENT_MADE).size(), 1)


func test_a_promise_comes_from_an_effects_order() -> void:
	# Created by an effect (#11), which produced an Order and never a write.
	var context := LetterContext.new(WorldState.new(2, {}), marshal, Tone.DUTIFUL)
	var order := ContentRegistry.run_effect("promise_gold", {"to": "marshal", "amount": 500}, context)
	var promise := PromiseBook.from_order(order, 2)
	assert_true(promise != null)
	assert_eq(promise.kind, &"gold")
	assert_eq(promise.amount(), 500.0)


func test_an_order_that_promises_nothing_makes_no_promise() -> void:
	var context := LetterContext.new(WorldState.new(2, {}), marshal, Tone.DUTIFUL)
	var order := ContentRegistry.run_effect("refuse", {"to": "marshal"}, context)
	assert_true(PromiseBook.from_order(order, 2) == null)


# --- Keeping ---------------------------------------------------------------

func test_a_promise_is_honoured_the_following_month_without_input() -> void:
	var promise := _gold(500, 0)
	assert_eq(promise.due_month, 1)

	book.settle_due(contacts, log, 0)
	assert_true(promise.is_outstanding(), "not yet due")

	book.settle_due(contacts, log, 1)
	assert_eq(promise.status, Promise.KEPT)
	assert_eq(log.of_type(PromiseBook.EVENT_KEPT).size(), 1)


func test_keeping_a_promise_raises_loyalty_and_clears_it() -> void:
	var before := marshal.loyalty()
	_gold(500, 0)
	book.settle_due(contacts, log, 1)
	assert_true(marshal.loyalty() > before)
	assert_empty(marshal.relationship.outstanding_promises)


# --- Breaking --------------------------------------------------------------

func test_a_promise_that_cannot_be_kept_breaks_and_costs_loyalty() -> void:
	var promise := _gold(500, 0)
	var before := marshal.loyalty()

	book.settle_due(contacts, log, 1, false)

	assert_eq(promise.status, Promise.BROKEN)
	assert_true(marshal.loyalty() < before)
	assert_eq(log.of_type(PromiseBook.EVENT_BROKEN).size(), 1)


func test_breaking_emits_an_event_next_months_letters_can_reference() -> void:
	_gold(500, 0)
	book.settle_due(contacts, log, 1, false)
	var event := log.of_type(PromiseBook.EVENT_BROKEN)[0]
	assert_eq(event.subject, &"marshal")
	assert_eq(event.phase, WorldPhase.CROWNS_MONTH)
	assert_not_empty(String(event.payload["reason"]))
	assert_eq(book.broken_in(1).size(), 1)


func test_a_colony_promise_is_not_the_crowns_to_refuse() -> void:
	# Promises the colony fulfils from its own stockpiles continue normally.
	var promise := Promise.new(&"marshal", &"resource", {"amount": 40, "resource": "iron"}, 0, 0)
	promise.payer = Promise.PAYER_COLONY
	book.make(promise, marshal, log, 0)

	book.settle_due(contacts, log, 1, false)
	assert_eq(promise.status, Promise.KEPT, "the Crown cannot refuse what the colony sends")


func test_a_resource_promise_from_an_order_is_the_colonys() -> void:
	var order := Order.new(M1Registrations.ORDER_PROMISE_RESOURCE, &"marshal", {
		"to": "marshal", "resource": "iron", "amount": 40,
	}, 0)
	assert_eq(PromiseBook.from_order(order, 0).payer, Promise.PAYER_COLONY)


func test_a_promise_can_be_broken_for_another_reason() -> void:
	var promise := _gold(500, 0)
	book.break_promise(promise, marshal, log, 1, "the ship went down")
	assert_eq(promise.status, Promise.BROKEN)
	assert_eq(promise.broken_reason, "the ship went down")


# --- Across months ---------------------------------------------------------

func test_promises_persist_across_months() -> void:
	var promise := Promise.new(&"marshal", &"gold", {"amount": 500}, 0, 6)
	book.make(promise, marshal, log, 0)
	for month in range(1, 6):
		book.settle_due(contacts, log, month)
		assert_true(promise.is_outstanding(), "settled early in month %d" % month)
	book.settle_due(contacts, log, 6)
	assert_eq(promise.status, Promise.KEPT)


func test_outstanding_promises_are_visible_per_contact() -> void:
	_gold(500)
	_gold(250)
	assert_eq(book.outstanding_to(&"marshal").size(), 2)
	assert_empty(book.outstanding_to(&"steward"))


func test_promises_survive_save_and_reload() -> void:
	var promise := _gold(500, 2)
	var restored := PromiseBook.from_dict(book.to_dict())
	assert_eq(restored.to_dict(), book.to_dict())
	assert_eq(restored.by_id(promise.id).amount(), 500.0)
	assert_eq(restored.outstanding().size(), 1)


func test_nothing_here_assumes_a_crown_standing_formula() -> void:
	# Crown standing is M3. This ticket only leaves the seam where the refusal
	# path plugs in, and `can_crown_pay` is the whole of it.
	_gold(500, 0)
	book.settle_due(contacts, log, 1, true)
	assert_eq(book.outstanding().size(), 0, "for M1 the Crown always pays")
