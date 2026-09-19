extends TestCase

## The Steward's revenue target, and the bet accepting it makes (#69,
## `docs/mechanics/crown-demands.md` §4).
##
## 🔒 **A revenue target is not a bill.** SPEC §10.2 locks that the PC's gold is
## not a wallet, so the Crown is not asking for coins — it is stating what the
## colony is expected to return through taxed trade.
##
## The decision the letter puts in front of the player is an asymmetry:
##
## - Undertake it and reach it, and the promise is kept.
## - Undertake it and fall short, and the promise **breaks**, costing loyalty on
##   top of the standing.
## - Decline, and it costs standing and the Steward's regard, but nothing breaks
##   and nobody is surprised.
##
## An honest refusal is cheaper than a broken promise, and the player has to
## judge his own colony to know which he is making. Every test here exists to
## keep one of those three outcomes distinguishable from the others.

const SEED: int = 3319

var content: ContentDatabase = null
var log: EventLog = null
var book: PromiseBook = null
var steward: Contact = null


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
	steward = Contact.new(&"steward")


func after_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _driver() -> PromiseDriver:
	var driver := PromiseDriver.new(book)
	driver.contacts = {"steward": steward}
	return driver


## A revenue target undertaken in `made`, running for `months`.
func _undertake(amount: float, made: int, months: int) -> Promise:
	var order := Order.new()
	order.kind = M1Registrations.ORDER_PROMISE_REVENUE
	order.addressed_to = &"steward"
	order.params = {"amount": amount, "months": months}
	var promise := PromiseBook.from_order(order, made)
	return book.make(promise, steward, log, made)


## Put duty on the books, the way a month of trade would.
func _trade(month: int, tax: float) -> void:
	log.emit(Trade.EVENT_BOUGHT, &"ashmere", month, {
		"town": "ashmere", "resource": "food", "luxury": false,
		"wanted": 1.0, "quantity": 1.0, "unit_price": 1.0, "rate": 0.1,
		"gross": 1.0, "tax": tax, "spent": 1.0,
	}, WorldPhase.COLONY_MONTH)


func _settle(month: int) -> void:
	_driver().on_phase(WorldPhase.CROWNS_MONTH, _state(month), log, RngStreams.new(SEED))


func _state(month: int) -> WorldState:
	var state := WorldValues.initial_state()
	state.month = month
	return state


# --- 🔒 The bet is settled on what the colony earned ------------------------

func test_a_target_the_colony_reaches_is_kept() -> void:
	var promise := _undertake(300.0, 1, 6)
	for month in range(2, 8):
		_trade(month, 60.0)  # 360 over the term
	_settle(7)
	assert_eq(String(promise.status), String(Promise.KEPT),
		"the colony returned 360 against a figure of 300 and the promise broke")


func test_a_target_the_colony_misses_breaks() -> void:
	# **The bet the PC lost.** Nobody refused him anything; he was wrong about
	# his own colony.
	var promise := _undertake(300.0, 1, 6)
	for month in range(2, 8):
		_trade(month, 10.0)  # 60 over the term
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"the colony returned 60 against a figure of 300 and the promise held")
	assert_true(promise.broken_reason.contains("fell short"),
		"it broke for the wrong reason: %s" % promise.broken_reason)


func test_missing_it_costs_the_stewards_regard() -> void:
	# The asymmetry only exists if breaking actually costs more than refusing.
	var before: float = steward.relationship.loyalty
	_undertake(300.0, 1, 6)
	_trade(2, 5.0)
	_settle(7)
	assert_true(steward.relationship.loyalty < before,
		"the promise broke and the Steward thought no worse of him")


func test_the_month_it_was_undertaken_does_not_count() -> void:
	# A target accepted in March for six months is judged on April through
	# September. March was already spent when he agreed to it, and counting it
	# would hand him a month of trade he had no chance to change.
	var promise := _undertake(300.0, 1, 6)
	_trade(1, 500.0)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"the month before the undertaking was counted towards it")


func test_trade_after_the_term_does_not_count_either() -> void:
	var promise := _undertake(300.0, 1, 6)
	for month in range(8, 14):
		_trade(month, 100.0)
	_settle(7)
	assert_eq(String(promise.status), String(Promise.BROKEN),
		"trade from after the term was counted towards it")


func test_it_is_not_settled_before_the_term_is_up() -> void:
	var promise := _undertake(300.0, 1, 6)
	for month in range(2, 5):
		_trade(month, 10.0)
	_settle(4)
	assert_true(promise.is_outstanding(),
		"the Treasury closed the book three months early")


# --- 🔒 Declining breaks nothing --------------------------------------------

func test_declining_leaves_nothing_to_break() -> void:
	# The player who says no honestly has no promise outstanding, so there is
	# nothing for a thin season to break. That is the whole of why refusal is the
	# cheaper mistake.
	var order := Order.new()
	order.kind = M1Registrations.ORDER_REFUSE
	order.addressed_to = &"steward"
	assert_true(PromiseBook.from_order(order, 1) == null,
		"declining the figure created a promise anyway")
	assert_empty(book.outstanding(), "declining put something in the book")


func test_the_crown_closing_its_purse_does_not_excuse_the_figure() -> void:
	# **It is the colony's trade, not the Crown's money.** The Treasury refusing
	# to honour what the PC pledged is a different matter entirely, and it must
	# not quietly discharge a target he undertook — that would make a collapse in
	# standing into a way out of a bad bet.
	var promise := _undertake(300.0, 1, 6)
	book.repudiate({"steward": steward}, log, 3)
	assert_true(promise.is_outstanding(),
		"a Crown repudiation cancelled a revenue target the PC had undertaken")


# --- 🔒 The Crown asks on a schedule ----------------------------------------

## **A book with no dice asks only for gold.** `_wants_goods` needs a stream to
## throw, so passing none keeps these fixtures on the Steward's figure — which is
## what they are about. Resource demands have their own file.
func _book_and_growth() -> Array:
	return [DemandBook.new(), DemandGrowth.new()]


func test_the_crown_waits_before_asking_for_anything() -> void:
	# A demand in the founding month is a bet made blind: the player has not yet
	# seen what he is governing.
	var pair := _book_and_growth()
	var demands: DemandBook = pair[0]
	for month in DemandBook.FIRST_DEMAND_MONTH:
		assert_false(demands.advance(month, pair[1], null, null),
			"the Treasury wrote in month %d, before the colony had a first harvest" % month)


func test_demands_arrive_on_the_interval() -> void:
	var pair := _book_and_growth()
	var demands: DemandBook = pair[0]
	var growth: DemandGrowth = pair[1]
	var gap := DemandSchedule.months_between(growth)

	var asked: PackedInt32Array = PackedInt32Array()
	for month in 40:
		if demands.advance(month, growth, null, null):
			asked.append(month)
	assert_true(asked.size() > 1, "the Treasury asked once in forty months")
	for at in range(1, asked.size()):
		assert_almost_eq(float(asked[at] - asked[at - 1]), gap, 1.01,
			"two demands came %d months apart against an interval of %.1f" % [
				asked[at] - asked[at - 1], gap])


func test_frequency_growth_brings_them_closer() -> void:
	# The dimension reaching the thing it is supposed to reach. Without this the
	# axis grows a number nobody consults.
	var steady := DemandGrowth.new()
	var pressed := DemandGrowth.new()
	pressed.levels[String(DemandGrowth.FREQUENCY)] = 4

	var slow := DemandBook.new()
	var quick := DemandBook.new()
	var slow_count := 0
	var quick_count := 0
	for month in 60:
		if slow.advance(month, steady, null, null):
			slow_count += 1
		if quick.advance(month, pressed, null, null):
			quick_count += 1
	assert_true(quick_count > slow_count,
		"four years of frequency growth produced %d demands against %d" % [
			quick_count, slow_count])


func test_the_figure_is_the_schedules_figure_and_grows_with_size() -> void:
	var demands := DemandBook.new()
	var growth := DemandGrowth.new()
	demands.advance(DemandBook.FIRST_DEMAND_MONTH, growth, null, null)
	assert_almost_eq(demands.amount, DemandSchedule.gold_target(growth), 0.001,
		"the Steward asked for something the schedule never set")

	var bigger := DemandGrowth.new()
	bigger.levels[String(DemandGrowth.SIZE)] = 3
	var later := DemandBook.new()
	later.advance(DemandBook.FIRST_DEMAND_MONTH, bigger, null, null)
	assert_true(later.amount > demands.amount,
		"three years of size growth did not change what was asked")


func test_what_the_crown_asked_survives_a_round_trip() -> void:
	var demands := DemandBook.new()
	demands.advance(DemandBook.FIRST_DEMAND_MONTH, DemandGrowth.new(), null, null)
	var restored := DemandBook.from_dict(demands.to_dict())
	assert_eq(restored.last_issued_month, demands.last_issued_month)
	assert_eq(restored.issued_month, demands.issued_month)
	assert_almost_eq(restored.amount, demands.amount, 0.001)
	assert_eq(restored.term_months, demands.term_months)
	assert_eq(String(restored.kind), String(demands.kind))


# --- 🔒 The Crown forms an opinion, not only a balance ----------------------

func _standing_after(events: Callable) -> Dictionary:
	var standing := CrownStanding.new()
	var driver := CrownStandingDriver.new(standing, CrownRefusal.new())
	events.call()
	var before := standing.standing
	driver.on_phase(WorldPhase.RUN_END_CHECK, _state(7), log, RngStreams.new(SEED))
	return {"before": before, "after": standing.standing}


func test_reaching_a_target_is_worth_more_than_the_gold() -> void:
	# **Standing is the Crown's opinion**, and an opinion is formed by conduct as
	# well as by accounts. A governor who said what his colony would return and
	# was right has told the Treasury something the duty alone does not say.
	var earned := _standing_after(func() -> void:
		for month in range(2, 8):
			_trade(month, 60.0)
		_undertake(300.0, 1, 6)
		_settle(7))

	var quiet_log := log
	log = EventLog.new()
	book = PromiseBook.new()
	var plain := _standing_after(func() -> void:
		for month in range(2, 8):
			_trade(month, 60.0))
	log = quiet_log

	assert_true(float(earned["after"]) > float(plain["after"]),
		"the same trade with a target reached was worth no more than without one")


func test_missing_a_target_costs_more_than_declining_it() -> void:
	# **The asymmetry is the decision.** An honest refusal has to be the cheaper
	# mistake, or there is no judgement for the player to make and accepting is
	# always correct.
	var missed := _standing_after(func() -> void:
		_undertake(300.0, 1, 6)
		_trade(2, 5.0)
		_settle(7))

	log = EventLog.new()
	book = PromiseBook.new()
	var order := Order.new()
	order.kind = M1Registrations.ORDER_DECLINE_DEMAND
	order.addressed_to = &"steward"
	var declined := _standing_after(func() -> void:
		_trade(2, 5.0)
		log.emit(Compliance.OUTCOME_EVENTS[Compliance.COMPLY], &"steward", 7, {
			"order": order.to_dict(), "outcome": "comply",
		}, WorldPhase.RECKONING))

	var cost_of_missing := float(missed["before"]) - float(missed["after"])
	var cost_of_declining := float(declined["before"]) - float(declined["after"])
	assert_true(cost_of_missing > cost_of_declining,
		"missing a target cost %.2f and declining cost %.2f" % [
			cost_of_missing, cost_of_declining])
	assert_true(cost_of_declining > 0.0, "declining the Crown cost nothing at all")


func test_desperation_growth_raises_the_price_of_saying_no() -> void:
	# The axis reaching the one thing it moves. A player who grants everything
	# never feels this, which is exactly why it cannot be folded into `size`.
	var order := Order.new()
	order.kind = M1Registrations.ORDER_DECLINE_DEMAND
	order.addressed_to = &"steward"

	var costs: Array = []
	for level in [0, 4]:
		log = EventLog.new()
		var growth := DemandGrowth.new()
		growth.levels[String(DemandGrowth.DESPERATION)] = level
		var standing := CrownStanding.new()
		var driver := CrownStandingDriver.new(standing, CrownRefusal.new())
		driver.growth = growth
		_trade(2, 5.0)
		log.emit(Compliance.OUTCOME_EVENTS[Compliance.COMPLY], &"steward", 7, {
			"order": order.to_dict(), "outcome": "comply",
		}, WorldPhase.RECKONING)
		var before := standing.standing
		driver.on_phase(WorldPhase.RUN_END_CHECK, _state(7), log, RngStreams.new(SEED))
		costs.append(before - standing.standing)

	assert_true(float(costs[1]) > float(costs[0]),
		"four years of desperation made refusing cost %.2f against %.2f" % [
			float(costs[1]), float(costs[0])])


# --- 🔒 The letter says what will be settled --------------------------------

func test_the_demand_letter_cannot_be_ignored_and_offers_both_answers() -> void:
	var letter := Letter.from_record(content.record("letters", "steward.revenue_demand"))
	assert_true(letter != null, "the Steward has no revenue demand to send")
	assert_false(letter.skippable, "a demand can be left unread")
	assert_true(letter.has_reply(), "the demand gives the player nothing to say back")
