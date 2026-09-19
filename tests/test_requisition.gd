extends TestCase

## The Marshal's requisition, and the two ways it can fail (#69,
## `docs/mechanics/crown-demands.md` §5).
##
## 🔒 **A resource demand is a two-step, and both steps can fail.** The PC
## accepts — that is a promise. Then he writes to a governor asking him to ship
## the goods — that is an Order, and it goes through compliance like any other. A
## governor whose town needs its iron will refuse, send half, or delay.
##
## **The failure is doubled.** Promise the Marshal two hundred iron, have the
## governor refuse, and the promise breaks: the Marshal's regard falls because he
## was failed, and the governor's because he was asked something costly. One
## acceptance, two enemies.
##
## This is rule by correspondence at its sharpest — the PC's only power over the
## thing he has already promised is another letter.

const SEED: int = 5507

var content: ContentDatabase = null
var log: EventLog = null
var book: PromiseBook = null
var marshal: Contact = null


func before_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	log = EventLog.new()
	book = PromiseBook.new()
	marshal = Contact.new(&"marshal")


func after_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _state(month: int) -> WorldState:
	var state := WorldValues.initial_state()
	state.month = month
	return state


func _undertake(resource: String, amount: float, made: int, months: int) -> Promise:
	var order := Order.new()
	order.kind = M1Registrations.ORDER_PROMISE_SHIPMENT
	order.addressed_to = &"marshal"
	order.params = {"resource": resource, "amount": amount, "months": months}
	return book.make(PromiseBook.from_order(order, made), marshal, log, made)


## Record goods leaving a town, the way the shipment executor does.
func _shipped(month: int, resource: String, quantity: float) -> void:
	log.emit(ShipmentExecutor.EVENT_SENT, &"ashmere", month, {
		"town": "ashmere", "resource": resource, "quantity": quantity,
		"shipped": quantity, "of": quantity, "tier": "need",
	}, WorldPhase.MOVEMENT)


func _settle(month: int) -> void:
	var driver := PromiseDriver.new(book)
	driver.contacts = {"marshal": marshal}
	driver.on_phase(WorldPhase.CROWNS_MONTH, _state(month), log, RngStreams.new(SEED))


# --- 🔒 Kept by goods, not by good intentions -------------------------------

func test_goods_that_arrive_keep_the_promise() -> void:
	var promise := _undertake("iron", 120.0, 1, 6)
	for month in range(2, 8):
		_shipped(month, "iron", 20.0)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.KEPT),
		"a hundred and twenty iron arrived and the Marshal counted it as nothing")


func test_a_governor_who_will_not_ship_breaks_it() -> void:
	# **The second step failing breaks the first.** The PC said yes in good faith
	# and the goods did not move, and the Marshal is counting crates rather than
	# letters.
	var promise := _undertake("iron", 120.0, 1, 6)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"nothing at all was shipped and the promise held")


func test_half_a_shipment_is_still_a_broken_promise() -> void:
	var promise := _undertake("iron", 120.0, 1, 6)
	for month in range(2, 5):
		_shipped(month, "iron", 20.0)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"sixty of a hundred and twenty was treated as delivery")


func test_the_wrong_goods_do_not_count() -> void:
	# A town that shipped a great deal of timber has not sent the Marshal iron,
	# however willing its governor was.
	var promise := _undertake("iron", 120.0, 1, 6)
	for month in range(2, 8):
		_shipped(month, "wood", 200.0)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"timber was counted against a requisition of iron")


func test_goods_shipped_before_the_undertaking_do_not_count() -> void:
	var promise := _undertake("iron", 120.0, 4, 6)
	for month in range(1, 4):
		_shipped(month, "iron", 200.0)
	_settle(10)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"iron sent before the promise was made was counted towards it")


func test_failing_the_marshal_costs_his_regard() -> void:
	var before: float = marshal.relationship.loyalty
	_undertake("iron", 120.0, 1, 6)
	_settle(7)
	assert_true(marshal.relationship.loyalty < before,
		"the Marshal was failed and thought no worse of the man who failed him")


func test_the_crown_closing_its_purse_does_not_excuse_the_goods() -> void:
	# The goods are the colony's, not the Crown's. A Treasury that has stopped
	# paying has not thereby cancelled what the PC said his colony would send.
	var promise := _undertake("iron", 120.0, 1, 6)
	book.repudiate({"marshal": marshal}, log, 3)
	assert_true(promise.is_outstanding(),
		"a Crown repudiation cancelled a requisition the PC had undertaken")


# --- 🔒 More than one turn to answer ----------------------------------------

## A run that has grown far enough for the Marshal to have a hand out.
##
## Only the Steward asks at the opening of a run; the Marshal is something
## `reach` adds (`crown-demands.md` §6), so every fixture here needs a run that
## has drawn that axis at least once.
func _grown() -> DemandGrowth:
	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.REACH)] = 1
	return growth


func test_only_the_steward_has_a_hand_out_at_first() -> void:
	# **The fourth dimension made real.** At the opening of a run one man is
	# asking; the rest are something the run grows into. Without this the axis
	# moves a number nobody consults.
	for seed_value in 40:
		var demands := DemandBook.new()
		var streams := RngStreams.new(seed_value)
		for month in 40:
			if demands.advance(month, DemandGrowth.new(), streams, null):
				assert_eq(String(demands.kind), String(DemandBook.KIND_GOLD),
					"the Marshal set a requisition before anyone had joined him")


func test_growing_reach_brings_the_marshal_in() -> void:
	var asked := false
	for seed_value in 40:
		var demands := DemandBook.new()
		var streams := RngStreams.new(seed_value)
		for month in 40:
			if demands.advance(month, _grown(), streams, null) 					and demands.kind == DemandBook.KIND_RESOURCE:
				asked = true
				demands.answer()
	assert_true(asked, "reach grew and the Marshal still never asked for anything")


func _requisition(month: int = DemandBook.FIRST_DEMAND_MONTH) -> DemandBook:
	# Walk the dice until the Crown asks for goods rather than gold. It is meant
	# to be the exception, so this may take several tries — which is itself the
	# thing `test_gold_is_the_routine` measures.
	for seed_value in 200:
		var demands := DemandBook.new()
		var streams := RngStreams.new(seed_value)
		var at := month
		for _try in 40:
			if demands.advance(at, _grown(), streams, null) \
					and demands.kind == DemandBook.KIND_RESOURCE:
				return demands
			at += 1
		continue
	return null


func test_a_requisition_stands_for_more_than_one_post() -> void:
	# **The decision the mechanic exists to create.** A careful player writes to
	# the governor first and learns whether the goods can be had. A demand
	# answered by return of post makes that impossible and reduces the whole
	# thing to a coin toss.
	var demands := _requisition()
	assert_true(demands != null, "the Crown never asked for goods in two hundred seeds")
	assert_true(demands.turns_left(demands.issued_month) >= 1,
		"the requisition had to be answered by return of post")
	assert_true(demands.is_pending(demands.issued_month + 1),
		"the requisition was gone from the desk the month after it arrived")


func test_it_lapses_when_the_deadline_passes() -> void:
	var demands := _requisition()
	assert_true(demands != null)
	var past := demands.expires_month + 1
	assert_true(demands.lapse(past, log), "the deadline passed and nothing happened")
	assert_false(demands.is_pending(past), "it was still on the desk after it lapsed")
	assert_eq(demands.expires_month, -1, "the Crown was still counting down after giving up")


func test_silence_costs_what_a_refusal_costs() -> void:
	# SPEC §9.3 lets the post pile up. It does not make it free — the Marshal was
	# not asking whether the PC had noticed him.
	var demands := _requisition()
	assert_true(demands != null)
	# Read the month *before* lapsing: lapsing clears the deadline, because the
	# Crown is no longer waiting on an answer once it has given up expecting one.
	var past := demands.expires_month + 1
	demands.lapse(past, log)

	var standing := CrownStanding.new()
	var driver := CrownStandingDriver.new(standing, CrownRefusal.new())
	var before := standing.standing
	driver.on_phase(WorldPhase.RUN_END_CHECK, _state(past), log, RngStreams.new(SEED))
	assert_true(standing.standing < before,
		"letting a requisition lapse cost the PC nothing at all")


func test_answering_takes_it_off_the_desk() -> void:
	var demands := _requisition()
	assert_true(demands != null)
	var at := demands.issued_month
	demands.answer()
	assert_false(demands.is_pending(at), "the Crown went on asking after it had been answered")


func test_the_crown_does_not_pile_one_demand_on_another() -> void:
	# While a requisition stands unanswered, nothing new is sent. Frequency
	# growth makes demands arrive more often; it does not make them overlap.
	var demands := _requisition()
	assert_true(demands != null)
	var streams := RngStreams.new(SEED)
	for month in range(demands.issued_month + 1, demands.expires_month + 1):
		assert_false(demands.advance(month, _grown(), streams, null),
			"a second demand arrived in month %d while the first still stood" % month)


# --- 🔒 Gold is the routine -------------------------------------------------

func test_gold_is_the_routine_and_goods_the_exception() -> void:
	# **Two letters, a payment decision and a tier of compliance is a great deal
	# of machinery for one demand.** At every demand the desk becomes a logistics
	# exercise and SPEC §9.6's promise that it will not become a chore breaks.
	var gold := 0
	var goods := 0
	for seed_value in 30:
		var demands := DemandBook.new()
		var streams := RngStreams.new(seed_value)
		for month in 60:
			if not demands.advance(month, _grown(), streams, null):
				continue
			if demands.kind == DemandBook.KIND_RESOURCE:
				goods += 1
				demands.answer()
			else:
				gold += 1

	assert_true(goods > 0, "the Crown never once asked for goods")
	assert_true(gold > goods,
		"the Crown asked for goods %d times against gold %d, which is the desk becoming logistics" % [
			goods, gold])


func test_the_marshal_never_requisitions_a_comfort() -> void:
	# His wars do not run on rum, and asking a colony for its beer reads as a
	# joke rather than a requisition.
	for seed_value in 60:
		var demands := DemandBook.new()
		var streams := RngStreams.new(seed_value)
		for month in 40:
			if demands.advance(month, _grown(), streams, null) \
					and demands.kind == DemandBook.KIND_RESOURCE:
				assert_false(ResourceCatalogue.is_luxury(demands.resource),
					"the Marshal requisitioned %s for his wars" % demands.resource)
				assert_almost_eq(ColonyNeeds.per_head(demands.resource), 0.0, 0.001,
					"the Marshal took %s out of a colony's mouth by post" % demands.resource)
				demands.answer()


func test_a_requisition_survives_a_round_trip() -> void:
	var demands := _requisition()
	assert_true(demands != null)
	var restored := DemandBook.from_dict(demands.to_dict())
	assert_eq(String(restored.resource), String(demands.resource))
	assert_eq(restored.expires_month, demands.expires_month)
	assert_eq(String(restored.kind), String(demands.kind))
	assert_almost_eq(restored.amount, demands.amount, 0.001)


# --- 🔒 The letter puts both steps in front of the player -------------------

func test_the_requisition_letter_can_wait_and_says_how_long() -> void:
	var letter := Letter.from_record(content.record("letters", "marshal.requisition"))
	assert_true(letter != null, "the Marshal has no requisition to send")
	assert_true(letter.skippable,
		"a requisition that cannot be set aside cannot be taken to a governor first")
	assert_true(letter.params.has("turns_left"),
		"the letter never tells the player how long he has")
	assert_true(letter.has_reply(), "the requisition gives the player nothing to say back")
