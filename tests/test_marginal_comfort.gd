extends TestCase

## Luxury buying is marginal quality of life per gold (#115,
## `docs/mechanics/town-economy.md` §2).
##
## **The backfire is the point.** Taxing tea is supposed to push towns toward the
## rum they distil themselves, so the Crown collects *nothing* rather than more
## — which is what makes a per-resource rate a real instrument, and what makes
## SPEC §10.2's trade protests emerge from the mechanics rather than being
## hardcoded. Cheapest-first toward a flat appetite produced none of that.

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


## A town with grain to spare brews its own beer and buys none, so `granary`
## says whether this fixture is a town with a surplus or a town buying its
## dinner. It decides whether beer is even on the list.
func _town(stock: Dictionary = {}, gold: float = 6_000.0, granary: float = 600.0) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 20
	town.receive_gold(gold)
	town.store(&"food", granary)
	town.store(&"clothing", 120.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _shop(town: Town, rates: Dictionary = {}) -> Dictionary:
	var state := WorldValues.initial_state()
	for key in rates:
		state.values[key] = float(rates[key])

	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.EXCHANGE, ExchangePhase.new())
	month.run(colony, context)

	var bought: Dictionary = {}
	for id in ResourceCatalogue.luxuries():
		bought[id] = town.held(StringName(id)) - float(_started.get(id, 0.0))
	return bought


var _started: Dictionary = {}


func _record(town: Town) -> void:
	_started = {}
	for id in ResourceCatalogue.luxuries():
		_started[id] = town.held(StringName(id))


# --- 🔒 The margin, not the price -------------------------------------------

func test_a_town_with_a_heap_of_one_thing_reaches_for_another() -> void:
	# **The variety bonus read backwards.** A town swimming in tea gets more from
	# its first rum than from its hundredth tea, and pays more for it gladly.
	# Short of grain, so beer is genuinely on the list — otherwise the town would
	# be refusing beer because it can brew it, and the test would prove nothing.
	var stocked := _town({"beer": 400.0}, 6_000.0, 0.0)
	_record(stocked)
	var bought := _shop(stocked)

	assert_almost_eq(float(bought["beer"]), 0.0, 0.01,
		"a town with four hundred beer bought more beer")
	var others := 0.0
	for id in ResourceCatalogue.luxuries():
		if id != "beer":
			others += float(bought[id])
	assert_true(others > 0.0, "it bought nothing else either")


func test_it_does_not_simply_buy_the_cheapest_thing() -> void:
	# Beer is cheapest and a town with none of it will start there — but a town
	# that already has beer moves on, which price alone could never express.
	var cellar := _town({"beer": 400.0}, 6_000.0, 0.0)
	_record(cellar)
	var bought := _shop(cellar)

	var dearest_bought := 0.0
	for id in ResourceCatalogue.luxuries():
		if float(bought[id]) > 0.0:
			dearest_bought = maxf(dearest_bought, ResourceCatalogue.price_of(StringName(id)))
	assert_true(dearest_bought > ResourceCatalogue.price_of(&"beer"),
		"it only ever bought things no dearer than beer")


func test_marginal_value_falls_as_the_cellar_fills() -> void:
	var mouths := 20.0
	var empty: Dictionary = {}
	var stocked := {"tea": 100.0}

	var first := QualityOfLife.marginal_pleasure(mouths, empty, &"tea", 1.0)
	var another := QualityOfLife.marginal_pleasure(mouths, stocked, &"tea", 1.0)
	assert_true(first > another,
		"the hundredth measure of tea was worth as much as the first")


func test_a_new_kind_is_worth_more_than_more_of_the_same() -> void:
	var mouths := 20.0
	var held := {"tea": 100.0}
	var more_tea := QualityOfLife.marginal_pleasure(mouths, held, &"tea", 1.0)
	var some_rum := QualityOfLife.marginal_pleasure(mouths, held, &"rum", 1.0)
	assert_true(some_rum > more_tea,
		"a town drowning in tea valued more tea above its first rum")


# --- 🔒 A town that makes it does not buy it --------------------------------

func test_a_town_with_grain_to_spare_buys_no_beer() -> void:
	# **The brewhouse.** Beer is made from food, so a town with a full granary has
	# beer at the cost of the labour and the Crown sells it none — even though beer
	# is the cheapest comfort there is and it would otherwise be first on the list.
	var granary := _town()
	_record(granary)
	assert_almost_eq(float(_shop(granary)["beer"]), 0.0, 0.01,
		"a town sitting on six hundred grain bought beer from the Crown")


func test_a_town_buying_its_dinner_buys_its_beer_too() -> void:
	# The other half, and the reason the test is *spare* grain rather than any
	# grain: a town with nothing in the granary has none to brew with, so the
	# cheapest comfort in the colony is back on the list. Without this half,
	# "holds the input" would quietly make beer unpurchasable everywhere.
	var hungry := _town({}, 6_000.0, 0.0)
	_record(hungry)
	assert_true(float(_shop(hungry)["beer"]) > 0.0,
		"a town with an empty granary still would not buy a beer")


func test_a_plantation_is_not_sold_what_it_grows() -> void:
	var planter := _town({"sugar": 200.0})
	_record(planter)
	var bought := _shop(planter)
	assert_almost_eq(float(bought["rum"]), 0.0, 0.01,
		"a town with two hundred sugar bought rum from the Crown")
	assert_almost_eq(float(bought["sugar"]), 0.0, 0.01,
		"it bought sugar it already has in quantity")
	var elsewhere := 0.0
	for id in ResourceCatalogue.luxuries():
		elsewhere += float(bought[id])
	assert_true(elsewhere > 0.0,
		"the plantation bought nothing at all, so what it skipped proves nothing")


func test_tea_is_always_a_purchase() -> void:
	# SPEC §10.1: the colony can never grow it. So there is no holding that makes
	# a town stop wanting it, which is exactly why taxing it bites.
	assert_empty(Array(ResourceCatalogue.inputs_for(&"tea")),
		"tea can be made from something, and the trade-protest design assumes it cannot")


# --- 🔒 The backfire --------------------------------------------------------

func test_taxing_one_comfort_pushes_the_town_onto_the_others() -> void:
	# **The whole reason this ticket exists.** Per-resource rates are a real
	# instrument with a real backfire, and SPEC §10.2's line about tea being
	# favoured for the first trade protest falls out of this.
	var untaxed := _town()
	_record(untaxed)
	var before := _shop(untaxed)

	var taxed := _town()
	_record(taxed)
	var after := _shop(taxed, {TaxRates.key_for(&"tea"): 0.9})

	assert_true(float(after["tea"]) < float(before["tea"]),
		"a ninety per cent duty on tea did not reduce how much tea was bought")

	var others_before := 0.0
	var others_after := 0.0
	for id in ResourceCatalogue.luxuries():
		if id == "tea":
			continue
		others_before += float(before[id])
		others_after += float(after[id])
	assert_true(others_after > others_before,
		"taxing tea did not shift the town onto anything else: %f then %f" % [
			others_before, others_after])


func test_the_duty_is_part_of_what_a_comfort_costs() -> void:
	# Not applied afterwards: the comparison is quality of life per gold
	# *including* the duty, or the rate could never change what is chosen.
	var cheap := _town()
	_record(cheap)
	var at_rest := _shop(cheap)
	assert_true(float(at_rest["tobacco"]) > 0.0, "the fixture never bought tobacco at all")

	var dear := _town()
	_record(dear)
	var taxed := _shop(dear, {TaxRates.key_for(&"tobacco"): 0.95})

	assert_true(float(taxed["tobacco"]) < float(at_rest["tobacco"]),
		"a duty on tobacco left tobacco buying untouched")


# --- 🔒 Not a flat per-head appetite ----------------------------------------

func test_the_purse_is_a_budget_rather_than_a_shopping_list() -> void:
	var town := _town()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.run(colony, context)

	var reckoning := context.reckoning_for(town)
	assert_true(reckoning.comfort_budget > 0.0, "the town set nothing aside for comforts")
	for id in ResourceCatalogue.luxuries():
		assert_almost_eq(reckoning.want_of(StringName(id)), 0.0, 0.001,
			"Reckon still names a per-kind appetite for %s" % id)


func test_a_town_with_no_money_buys_no_comforts() -> void:
	var broke := _town({}, 0.0)
	_record(broke)
	var bought := _shop(broke)
	for id in ResourceCatalogue.luxuries():
		assert_almost_eq(float(bought[id]), 0.0, 0.01,
			"a penniless town came home with %s" % id)


# --- Still agrees with the drinking side ------------------------------------

func test_the_buying_side_and_the_drinking_side_value_a_cellar_alike() -> void:
	# A town that bought on one theory and drank on another would hold a heap of
	# beer and wonder why it felt no better for it.
	var mouths := 20.0
	var held := {"beer": 1.0, "tea": 1.0, "rum": 1.0}
	var from_stock := QualityOfLife.pleasure_from(mouths, held)

	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 20
	town.store(&"food", 600.0)
	for id in held:
		town.store(StringName(id), float(held[id]))

	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	month.run(colony, context)

	var drunk: Dictionary = context.wellbeing["ashmere"]
	assert_almost_eq(QualityOfLife.pleasure_of(drunk), from_stock, 0.001,
		"the cellar was worth one thing to buy and another to drink")


# --- 🔒 The tiers favour, they do not gate (#137) ---------------------------

func _comforts(town: Town) -> float:
	var total := 0.0
	for id in ResourceCatalogue.luxuries():
		total += town.held(StringName(id))
	return total


func test_a_town_saving_for_its_project_still_buys_a_little_comfort() -> void:
	# **SPEC §11.3 as the Author revised it**: a town spends "a little on
	# luxuries even when there are more important things to buy." Exchange used
	# to work down needs, then the objective, then comforts, so a town that ran
	# out of money anywhere above the comforts bought none at all, ever.
	#
	# That is not a leak. It is the instinct `quality-of-life.md` is built on —
	# enough rum and people do not mind that they are hungry — arriving on the
	# buying side instead of the consumption side.
	#
	# **Asked of the objective rather than of a need**, and that is a finding
	# rather than a convenience. A need's valuation is enormous while it is unmet
	# — eight times a shortage premium — so the only rate at which a comfort
	# outranks a need is one where a starving town buys drink before grain. The
	# doc is not obviously against that ("enough rum and people do not mind that
	# they are hungry") but it is the Author's call, not mine, and it is raised on
	# the pull request.
	#
	# The objective tier is where the property is real and testable today: a town
	# gathering for a build is short of something it wants a great deal, and it
	# still buys its beer.
	# **And the purse has to leave the build out of reach**, or the town finishes
	# it, the list empties, and the comfort is bought because it is the only
	# candidate left — which is true of a strict gate as well and so proves
	# nothing. Sixty gold is under the reserve this town holds against the months
	# ahead, so the timber is gated all month and stays on the list.
	var town := _town({}, 60.0)
	town.objective = &"granary"
	town.objective_target = Vector2i(0, 0)
	_record(town)
	_shop(town)

	assert_almost_eq(town.held(&"wood"), 0.0, 0.001,
		"the reserve did not hold the timber back, so there is nothing left unmet to test against")
	assert_true(_comforts(town) > 0.0,
		"a town with its build still unmet bought no comfort at all, which is the gate again")


func test_the_reserve_gates_the_objective_and_never_survival() -> void:
	# §4: the purse reserve is gold held against coming months' needs, and it
	# **gates comforts and the objective, never survival**. A town that cannot
	# eat this month spends its last coin, because holding money against next
	# month while starving is not prudence.
	var starving := _town({}, 40.0, 0.0)
	_shop(starving)
	assert_true(starving.held(&"food") > 0.0,
		"a starving town sat on its purse reserve rather than buying grain")


func test_comfort_spending_is_bounded_by_its_allowance() -> void:
	# **And "a little" has to mean a little.** The allowance sits outside the
	# purse reserve — it has to, or a reserve worth holding is larger than a poor
	# town's whole purse and the gate comes back wearing a different coat — so
	# the thing that stops a town drinking its way through the winter is the size
	# of the allowance rather than the reserve.
	var town := _town({}, 6_000.0)
	_record(town)
	_shop(town)

	var laid_out := 0.0
	for id in ResourceCatalogue.luxuries():
		laid_out += town.held(StringName(id)) * ResourceCatalogue.price_of(StringName(id))
	var mouths := float(town.population())
	var allowance := mouths * ColonyNeeds.luxury_per_head() * 3.0 * ResourceCatalogue.price_of(&"tea")
	assert_true(laid_out <= allowance * 1.25,
		"a town with six thousand gold laid out %.0f on drink against an allowance of %.0f" % [
			laid_out, allowance])
