extends TestCase

## The Ledger (#51, SPEC §10.4).
##
## **No tests on the screen.** CLAUDE.md rules those out. What is worth locking
## is that the sheet is read off the event log and adds up — because crown
## standing is invisible and this is the only instrument the player has for
## working out where they stand.

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _context(month: int = 1) -> ColonyContext:
	var state := WorldValues.initial_state()
	state.month = month
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	return context


func _town(gold: float = 5000.0, stock: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 8
	town.receive_gold(gold)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


# --- Every transaction appears ----------------------------------------------

func test_buying_and_selling_both_reach_the_sheet() -> void:
	var context := _context()
	Trade.buy(_town(), &"food", 20.0, context)
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)

	var ledger := Ledger.of(context.log)
	var page := ledger.page(1)
	assert_eq(page.entries.size(), 2, "a transaction went missing from the Ledger")
	assert_true(page.received() > 0.0)


func test_the_monthly_total_is_the_sum_of_its_lines() -> void:
	var context := _context()
	for _each in 4:
		Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)

	var page := Ledger.of(context.log).page(1)
	var counted := 0.0
	for entry in page.entries:
		counted += entry.amount
	assert_almost_eq(page.received(), counted, 0.001, "the page does not add up")
	assert_almost_eq(page.net(), counted, 0.001)


func test_what_the_crown_took_is_what_the_sheet_says() -> void:
	# The Ledger and the sim must agree to the penny, because the player can add
	# the column up and the Crown's letters will quote a different figure.
	var context := _context()
	Trade.buy(_town(), &"food", 30.0, context)
	Trade.sell(_town(0.0, {"furs": 50.0}), &"furs", 50.0, context)

	assert_almost_eq(Ledger.of(context.log).net_position(), context.crown_tax, 0.001,
		"the sheet and the treasury disagree about the same month")


func test_a_transaction_of_nothing_is_not_a_line() -> void:
	# A sheet full of zeroes hides the lines that matter.
	var context := _context()
	Trade.buy(_town(0.0), &"food", 20.0, context)  # no gold, so nothing happens
	assert_true(Ledger.of(context.log).is_empty())


# --- Paging by month --------------------------------------------------------

func test_each_page_is_a_month_and_they_come_in_order() -> void:
	var context := _context(3)
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)
	context.state.month = 1
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)
	context.state.month = 2
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)

	var months := Ledger.of(context.log).months()
	assert_eq(Array(months), [1, 2, 3], "the pages are out of order")


func test_a_quiet_month_is_an_empty_page_and_not_an_error() -> void:
	# A month in which nothing passed either way is a fact about the run.
	var context := _context()
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)
	var page := Ledger.of(context.log).page(9)

	assert_eq(page.month, 9)
	assert_empty(page.entries)
	assert_almost_eq(page.net(), 0.0, 0.001)


func test_the_trend_carries_a_row_for_every_month_that_has_one() -> void:
	var context := _context(1)
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)
	context.state.month = 2
	Trade.sell(_town(0.0, {"wood": 40.0}), &"wood", 40.0, context)

	var trend := Ledger.of(context.log).trend()
	assert_eq(trend.size(), 2)
	for row in trend:
		for key in ["month", "in", "out", "net"]:
			assert_has(row, key, "the graph cannot draw without '%s'" % key)


# --- 🔒 Money in is trade, money out is the PC's promises -------------------

func test_a_promise_honoured_is_money_out() -> void:
	# `docs/mechanics/town-economy.md` §5: the Crown's merchants always profit
	# and the colonists always pay, so a month only goes badly because of
	# something the player did.
	var log := EventLog.new()
	var book := PromiseBook.new()
	var promise := Promise.new(&"marshal", &"gold", {"amount": 400.0}, 1, 2)
	book.make(promise, null, log, 1)
	book.settle_due({}, log, 2)

	var ledger := Ledger.of(log)
	assert_false(ledger.is_empty(), "an honoured promise left no trace on the sheet")
	assert_almost_eq(ledger.page(2).paid(), 400.0, 0.001)
	assert_almost_eq(ledger.net_position(), -400.0, 0.001)
	assert_true(promise != null)


func test_a_month_of_both_nets_out() -> void:
	var context := _context()
	Trade.sell(_town(0.0, {"furs": 100.0}), &"furs", 100.0, context)
	var took := context.crown_tax

	var book := PromiseBook.new()
	book.make(Promise.new(&"marshal", &"gold", {"amount": 25.0}, 1, 1), null, context.log, 0)
	book.settle_due({}, context.log, 1)

	var page := Ledger.of(context.log).page(1)
	assert_almost_eq(page.received(), took, 0.001)
	assert_almost_eq(page.paid(), 25.0, 0.001)
	assert_almost_eq(page.net(), took - 25.0, 0.001)


func test_the_position_accumulates_across_the_run() -> void:
	# The one number a diligent player can work out that the Crown will never
	# tell them.
	var context := _context(1)
	Trade.sell(_town(0.0, {"furs": 100.0}), &"furs", 100.0, context)
	context.state.month = 2
	Trade.sell(_town(0.0, {"furs": 100.0}), &"furs", 100.0, context)

	var ledger := Ledger.of(context.log)
	assert_almost_eq(
		ledger.net_position(),
		ledger.page(1).net() + ledger.page(2).net(),
		0.001,
	)


# --- Reading nothing --------------------------------------------------------

func test_a_run_that_has_traded_nothing_reads_as_empty() -> void:
	var ledger := Ledger.of(EventLog.new())
	assert_true(ledger.is_empty())
	assert_empty(Array(ledger.months()))
	assert_almost_eq(ledger.net_position(), 0.0, 0.001)
	assert_almost_eq(ledger.busiest_month(), 0.0, 0.001)


func test_it_survives_being_handed_nothing_at_all() -> void:
	# The desk builds it on open, and a run resumed from an older save may have
	# no log at all.
	var ledger := Ledger.of(null)
	assert_true(ledger.is_empty())
	assert_eq(ledger.page(1).month, 1)


# --- It reads the log, and the log is saved ---------------------------------

func test_the_sheet_survives_save_and_reload() -> void:
	# It is read off the event log rather than kept alongside it, so what really
	# has to survive is the log — and if it did not, the player would come back
	# to a run whose accounts had been wiped.
	var context := _context()
	Trade.sell(_town(0.0, {"furs": 80.0}), &"furs", 80.0, context)
	var before := Ledger.of(context.log).net_position()

	var restored := Ledger.of(EventLog.from_dict(context.log.to_dict()))
	assert_almost_eq(restored.net_position(), before, 0.001)
	assert_eq(restored.page(1).entries.size(), Ledger.of(context.log).page(1).entries.size())
