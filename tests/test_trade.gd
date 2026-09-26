extends TestCase

## Exchange and Sell, and the tax on both (#47).
##
## **The asymmetry is the point.** A duty on a necessity takes resources out of
## the colony; a duty on a luxury takes nothing from anybody. Those are two code
## paths and they are tested separately, because the whole trade-protest design
## in M3 rests on the difference and a formula that split the difference would
## make the Steward's advice about luxury duties technically true and
## practically meaningless.

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ----------------------------------------------------------------

func _context(rates: Dictionary = {}) -> ColonyContext:
	var state := WorldValues.initial_state()
	for key in rates:
		state.values[key] = float(rates[key])
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	return context


func _town(workers: int, gold: float, stock: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	# Fixture sizes are in thousands (#426).
	town.workers = workers * Population.THOUSAND
	town.receive_gold(gold)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


## Reckon, then the phase under test. Reckon is not optional — every later phase
## honours the quantities it writes down.
func _harness(town: Town, phase: StringName, handler: ColonyPhase, rates: Dictionary = {}) -> Dictionary:
	var colony := Colony.new()
	colony.add(town)
	var context := _context(rates)

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(phase, handler)
	month.run(colony, context)
	return {"town": town, "context": context}


# --- 🔒 The asymmetry --------------------------------------------------------

func test_taxing_a_necessity_takes_resources_not_money() -> void:
	# They need to eat. Raise the duty and they pay the same and carry home less
	# — the tax comes out of the colony's stores.
	var cheap := _town(4, 1000.0)
	var dear := _town(4, 1000.0)
	var free_deal := Trade.buy(cheap, &"food", 10.0, _context({TaxRates.BASE_KEY: 0.0}))
	var taxed_deal := Trade.buy(dear, &"food", 10.0, _context({TaxRates.BASE_KEY: 0.5}))

	assert_almost_eq(float(taxed_deal["spent"]), float(free_deal["spent"]), 0.001,
		"a duty on a necessity changed what the town spent")
	assert_true(float(taxed_deal["received"]) < float(free_deal["received"]),
		"a duty on a necessity cost the town nothing in resources")
	assert_true(float(taxed_deal["tax"]) > 0.0, "the Crown took nothing")


func test_taxing_a_luxury_takes_money_not_resources() -> void:
	# They can go without. Raise the duty and they buy less and **spend less
	# doing it** — which is why taxing rum is politically cheap and materially
	# useless.
	var cheap := _town(4, 1000.0)
	var dear := _town(4, 1000.0)
	var free_deal := Trade.buy(cheap, &"rum", 10.0, _context({TaxRates.BASE_KEY: 0.0}))
	var taxed_deal := Trade.buy(dear, &"rum", 10.0, _context({TaxRates.BASE_KEY: 0.5}))

	assert_true(float(taxed_deal["spent"]) < float(free_deal["spent"]),
		"a duty on a luxury did not reduce what the town spent")
	assert_true(float(taxed_deal["received"]) < float(free_deal["received"]))


func test_the_two_paths_really_are_different() -> void:
	# Stated as one assertion so it cannot be satisfied by tuning one coefficient
	# until both halves happen to pass: at the same duty, spend on a necessity
	# holds and spend on a luxury falls.
	var duty := {TaxRates.BASE_KEY: 0.4}

	var need_free := Trade.buy(_town(4, 1000.0), &"food", 10.0, _context())
	var need_taxed := Trade.buy(_town(4, 1000.0), &"food", 10.0, _context(duty))
	var want_free := Trade.buy(_town(4, 1000.0), &"rum", 10.0, _context())
	var want_taxed := Trade.buy(_town(4, 1000.0), &"rum", 10.0, _context(duty))

	assert_almost_eq(float(need_taxed["spent"]), float(need_free["spent"]), 0.001)
	assert_true(float(want_taxed["spent"]) < float(want_free["spent"]) - 0.001)


# --- Rates ------------------------------------------------------------------

func test_a_per_resource_rate_overrides_the_base() -> void:
	var context := _context({TaxRates.BASE_KEY: 0.1, TaxRates.key_for(&"rum"): 0.6})
	var deal := Trade.buy(_town(4, 1000.0), &"rum", 5.0, context)
	assert_almost_eq(float(deal["rate"]), 0.6, 0.001, "the override was ignored")

	var plain := Trade.buy(_town(4, 1000.0), &"food", 5.0, context)
	assert_almost_eq(float(plain["rate"]), 0.1, 0.001, "an unoverridden resource left the base")


func test_the_rate_reaches_the_crown_both_ways() -> void:
	var buying := _context({TaxRates.BASE_KEY: 0.25})
	Trade.buy(_town(4, 1000.0), &"food", 10.0, buying)
	assert_true(buying.crown_tax > 0.0, "buying paid the Crown nothing")

	var selling := _context({TaxRates.BASE_KEY: 0.25})
	Trade.sell(_town(4, 0.0, {"wood": 10.0}), &"wood", 10.0, selling)
	assert_true(selling.crown_tax > 0.0, "selling paid the Crown nothing")


# --- Gold -------------------------------------------------------------------

func test_buying_and_selling_move_the_towns_gold() -> void:
	var buyer := _town(4, 100.0)
	Trade.buy(buyer, &"food", 10.0, _context())
	assert_false(buyer.can_afford(100.0), "buying cost the town nothing")

	var seller := _town(4, 0.0, {"wood": 10.0})
	Trade.sell(seller, &"wood", 10.0, _context())
	assert_true(seller.can_afford(1.0), "selling earned the town nothing")
	assert_almost_eq(seller.held(&"wood"), 0.0, 0.001, "the wood was sold twice or not at all")


func test_a_town_buys_only_what_it_can_afford() -> void:
	var poor := _town(4, 6.0)
	var context := _context({TaxRates.BASE_KEY: 0.0})
	var deal := Trade.buy(poor, &"food", 100.0, context)

	assert_almost_eq(float(deal["spent"]), 6.0, 0.001,
		"the town spent gold it did not have")
	# **What six gold buys, at whatever the Crown is quoting.** Asked of the
	# dictionary rather than written down, because the quote moves with the
	# Crown's war and a shortage at home (#141) and a figure here would be a
	# second, staler copy of the price table.
	assert_almost_eq(float(deal["received"]),
		6.0 / Valuation.crown(&"food", context.state), 0.001)


# --- Every transaction is in the Ledger's terms -----------------------------

func test_a_purchase_carries_enough_detail_for_the_ledger() -> void:
	var context := _context({TaxRates.BASE_KEY: 0.2})
	Trade.buy(_town(4, 1000.0), &"food", 10.0, context)

	var events: Array = context.log.of_type(Trade.EVENT_BOUGHT)
	assert_eq(events.size(), 1)
	for key in ["town", "resource", "quantity", "unit_price", "rate", "gross", "tax", "spent"]:
		assert_has(events[0].payload, key, "a purchase did not record '%s'" % key)


func test_a_sale_carries_enough_detail_for_the_ledger() -> void:
	var context := _context({TaxRates.BASE_KEY: 0.2})
	Trade.sell(_town(4, 0.0, {"wood": 10.0}), &"wood", 10.0, context)

	var events: Array = context.log.of_type(Trade.EVENT_SOLD)
	assert_eq(events.size(), 1)
	for key in ["town", "resource", "quantity", "unit_price", "rate", "gross", "tax", "earned"]:
		assert_has(events[0].payload, key, "a sale did not record '%s'" % key)
	assert_almost_eq(
		float(events[0].payload["gross"]),
		float(events[0].payload["tax"]) + float(events[0].payload["earned"]),
		0.001,
		"the sale does not add up",
	)


# --- The M3 exception hook --------------------------------------------------

func test_a_rebelling_town_refuses_crown_trade() -> void:
	# Trade protests are M3 and hang off the same gate. Today only open rebellion
	# closes it, but it closes.
	var rebel := _town(4, 1000.0, {"wood": 50.0})
	rebel.rebelling = true
	var context := _context()

	var bought := Trade.buy(rebel, &"food", 10.0, context)
	var sold := Trade.sell(rebel, &"wood", 10.0, context)

	assert_almost_eq(float(bought["received"]), 0.0, 0.001)
	assert_almost_eq(float(sold["sold"]), 0.0, 0.001)
	assert_almost_eq(rebel.held(&"wood"), 50.0, 0.001)
	assert_eq(context.log.of_type(Trade.EVENT_REFUSED).size(), 2)


# --- Exchange ---------------------------------------------------------------

func test_exchange_covers_needs_before_luxuries() -> void:
	# Enough gold for the grain and not a penny more. A town that bought rum
	# first would starve for want of a drink.
	var town := _town(6, 12.0)
	_harness(town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.0})

	assert_true(town.held(&"food") > 0.0, "the town bought no food at all")
	for id in ResourceCatalogue.luxuries():
		assert_almost_eq(town.held(StringName(id)), 0.0, 0.001,
			"the town bought %s while short of food" % id)


func test_exchange_buys_the_worst_need_first() -> void:
	# Short of both, able to afford one. It covers the thing that will kill it.
	var town := _town(6, 12.0)
	_harness(town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.0})

	assert_true(town.held(&"food") > 0.0)
	assert_almost_eq(town.held(&"clothing"), 0.0, 0.001,
		"the lesser need was bought ahead of the greater")


func test_exchange_buys_luxuries_when_there_is_money_left() -> void:
	# Not forbidden — only last.
	var town := _town(6, 5000.0, {"food": 100.0, "clothing": 50.0})
	_harness(town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.0})

	var bought := 0.0
	for id in ResourceCatalogue.luxuries():
		bought += town.held(StringName(id))
	assert_true(bought > 0.0, "a rich and well-fed town bought no comforts at all")


## What a month's shopping laid out on food, and what it carried home.
func _food_bought(context: ColonyContext) -> Dictionary:
	var out := {"spent": 0.0, "received": 0.0}
	for event in context.log.of_type(Trade.EVENT_BOUGHT):
		if String(event.payload.get("resource", "")) == "food":
			out["spent"] += float(event.payload["spent"])
			out["received"] += float(event.payload["quantity"])
	return out


func test_exchange_spends_a_needs_budget_once() -> void:
	# 🔒 SPEC §10.2 across a whole month, not one purchase (#453): *colonists will
	# spend the same amount of money, and receive less of the resource*. A town
	# that went back for what the duty kept from it spent more and got the same.
	var free_town := _town(6, 50_000.0, {"clothing": 50.0})
	var free: ColonyContext = _harness(
		free_town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.0})["context"]
	var taxed_town := _town(6, 50_000.0, {"clothing": 50.0})
	var taxed: ColonyContext = _harness(
		taxed_town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.5})["context"]

	var without := _food_bought(free)
	var with_duty := _food_bought(taxed)
	assert_true(float(with_duty["received"]) > 0.0, "the taxed town bought no food to compare")
	assert_true(float(with_duty["spent"]) <= float(without["spent"]) * 1.1,
		"a duty on food made the town spend more on it: %.1f against %.1f"
			% [float(with_duty["spent"]), float(without["spent"])])
	assert_true(float(with_duty["received"]) < float(without["received"]) * 0.9,
		"a duty on food did not leave the town with less of it")


func test_exchange_shops_for_the_objective() -> void:
	var town := _town(6, 5000.0, {"food": 100.0, "clothing": 50.0})
	town.objective = &"granary"
	_harness(town, ColonyMonth.EXCHANGE, ExchangePhase.new(), {TaxRates.BASE_KEY: 0.0})

	assert_true(town.held(&"wood") > 0.0, "the town bought nothing towards what it is building")


# --- Sell -------------------------------------------------------------------

func test_the_reserve_is_respected_before_anything_is_sold() -> void:
	# Six mouths need six food a month and hold two months against the winter, so
	# eighteen is the floor. A town that sold down to its needs would look
	# prosperous for a month and starve in the second.
	var town := _town(6, 0.0, {"food": 30.0})
	_harness(town, ColonyMonth.SELL, SellPhase.new())

	assert_almost_eq(town.held(&"food"), 18.0, 0.001, "the town sold into its reserve")
	assert_true(town.can_afford(1.0), "the surplus was not sold")


func test_a_town_with_nothing_spare_sells_nothing() -> void:
	var town := _town(6, 0.0, {"food": 10.0})
	var harness := _harness(town, ColonyMonth.SELL, SellPhase.new())

	assert_almost_eq(town.held(&"food"), 10.0, 0.001)
	assert_empty(harness["context"].log.of_type(Trade.EVENT_SOLD))


func test_selling_pays_the_crown_its_duty() -> void:
	var town := _town(6, 0.0, {"wood": 100.0})
	var harness := _harness(town, ColonyMonth.SELL, SellPhase.new(), {TaxRates.BASE_KEY: 0.3})
	var context: ColonyContext = harness["context"]

	var events: Array = context.log.of_type(Trade.EVENT_SOLD)
	assert_not_empty(events)
	assert_almost_eq(float(events[0].payload["rate"]), 0.3, 0.001)
	assert_true(context.crown_tax > 0.0)


# --- 🔒 The rate is an instrument the player can actually reach -------------

func test_every_letter_about_a_rate_moves_the_rate() -> void:
	# **The bug this exists to stop coming back.** `set_tax_rate` was registered
	# in code, carried a builder that worked out the world key and the step, had
	# an entry in the executor table — and was used by no letter. Every letter
	# that asked about a rate used `set_policy`, which the table maps to nothing.
	#
	# So the player could not change a tax rate at all, for the whole of M1 and
	# M2, while SPEC §10.2 makes per-resource rates his main economic instrument
	# and #115 built the trade-protest backfire on top of them. Nothing failed,
	# because nothing asserted that the instrument was connected.
	var database := ContentDatabase.new()
	database.load_all("en")

	var about_rates := 0
	for id in database.ids("letters"):
		var record: Dictionary = database.collection("letters")[id]
		var text := JSON.stringify(record)
		if not text.contains("tax.") and not text.contains("set_tax_rate"):
			continue
		about_rates += 1
		assert_true(text.contains("set_tax_rate"),
			"%s talks about a rate and moves nothing: a letter that asks the "
			% id + "player to raise a duty must use `set_tax_rate`")
		assert_false(text.contains("\"policy\": \"tax."),
			"%s sets a tax rate as though it were a policy string" % id)

	assert_true(about_rates > 0, "no letter in the game asks about a tax rate at all")
	database.free()


func test_a_step_moves_the_rate_by_a_step() -> void:
	var state := WorldValues.initial_state()
	var before := TaxRates.rate_for(state, &"tea")
	var raised := TaxRates.moved(state, &"tea", 1.0)
	var lowered := TaxRates.moved(state, &"tea", -1.0)

	assert_true(raised > before, "raising a duty by one step left it where it was")
	assert_true(lowered < before, "lowering a duty by one step left it where it was")
	assert_almost_eq(raised - before, TaxRates.STEP, 0.0001,
		"a step was not a step")
