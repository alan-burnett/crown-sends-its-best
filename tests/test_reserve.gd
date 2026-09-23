extends TestCase

## Reserve: the objective and the intent raise it (#114,
## `docs/mechanics/town-economy.md` §3).
##
## **A buying target and a selling floor.** For resources a town does not eat,
## months of consumption is zero — so the modifiers are the *only* thing that
## creates demand, and without them a military intent protects the guns a town
## has and never sends it shopping for guns it does not.
##
## That matters beyond the economy: the harness found (#90) that the player's
## letters barely move the colony, and intent reaching the reserve is one of the
## few routes by which they do.

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


func _town(intent: StringName, stock: Dictionary = {}, gold: float = 4_000.0) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 10
	town.intent = intent
	town.receive_gold(gold)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _reckon(town: Town) -> Reckoning:
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
	return context.reckoning_for(town)


## Reckon, then let the town go shopping.
func _shop(town: Town) -> Dictionary:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.EXCHANGE, ExchangePhase.new())
	month.run(colony, context)
	return {"town": town, "context": context}


# --- 🔒 The intent creates demand -------------------------------------------

func test_a_military_intent_sends_the_town_shopping_for_guns() -> void:
	# **The headline of the ticket.** A military intent does not protect the guns
	# the town has; it creates demand for guns it does not.
	var defended := _town(GovernorIntent.DEFENCE, {"food": 400.0, "clothing": 80.0})
	var thrifty := _town(GovernorIntent.ECONOMY, {"food": 400.0, "clothing": 80.0})

	_shop(defended)
	_shop(thrifty)

	assert_true(defended.held(&"guns") > 0.0,
		"a governor bent on defence bought no powder at all")
	assert_almost_eq(thrifty.held(&"guns"), 0.0, 0.001,
		"a governor attending to profit bought guns anyway")


func test_the_intent_raises_the_reserve_on_what_it_wants_held() -> void:
	var defended := _reckon(_town(GovernorIntent.DEFENCE, {"food": 400.0, "clothing": 80.0}))
	var thrifty := _reckon(_town(GovernorIntent.ECONOMY, {"food": 400.0, "clothing": 80.0}))

	assert_true(defended.reserve_of(&"guns") > 0.0,
		"a military intent left the reserve on guns at nothing")
	assert_almost_eq(thrifty.reserve_of(&"guns"), 0.0, 0.001)


func test_a_resource_nobody_eats_has_no_reserve_without_an_intent() -> void:
	# Months of consumption is zero for stone, so the base is zero and the
	# modifiers are the only thing that can create demand.
	var idle := _town(&"", {"food": 400.0, "clothing": 80.0})
	assert_almost_eq(_reckon(idle).reserve_of(&"stone"), 0.0, 0.001)


func test_the_demand_grows_with_the_town() -> void:
	# Per head rather than absolute, so a town of three hundred wants more
	# powder than a town of ten and neither figure has to be authored.
	var small := _town(GovernorIntent.DEFENCE, {"food": 400.0, "clothing": 80.0})
	var large := _town(GovernorIntent.DEFENCE, {"food": 400.0, "clothing": 80.0})
	large.workers = 200

	assert_true(_reckon(large).reserve_of(&"guns") > _reckon(small).reserve_of(&"guns"))


# --- The objective raises it on its own inputs ------------------------------

func test_the_objective_raises_the_reserve_on_what_it_consumes() -> void:
	# The reserve exists to serve the project, so what the project still needs
	# is held back rather than counted as spare.
	var building := _town(&"", {"food": 400.0, "clothing": 80.0, "wood": 200.0})
	building.objective = &"granary"
	building.objective_intent = &""

	var idle := _town(&"", {"food": 400.0, "clothing": 80.0, "wood": 200.0})

	assert_true(_reckon(building).reserve_of(&"wood") > _reckon(idle).reserve_of(&"wood"),
		"a town raising a granary held back no more timber than one raising nothing")


func test_a_hoarding_posture_still_reserves_everything() -> void:
	# The strongest form the modifier takes: an order to hoard means Relief and
	# Sell both find nothing to give away.
	var hoarder := _town(&"", {"food": 400.0, "clothing": 80.0})
	hoarder.objective = &"stockpile_food"

	var reckoning := _reckon(hoarder)
	assert_almost_eq(reckoning.spare_of(&"food"), 0.0, 0.001,
		"a town under orders to stockpile food had food to spare")


# --- 🔒 Who respects the reserve --------------------------------------------

func test_needs_draw_freely_through_the_reserve() -> void:
	# Survival ignores it. The citizens meet their needs with the town's gold
	# whatever the governor wants.
	var hungry := _town(GovernorIntent.DEFENCE, {"clothing": 80.0})
	_shop(hungry)
	assert_true(hungry.held(&"food") > 0.0,
		"a starving town bought powder and no grain")


func test_the_objective_draws_below_the_reserve() -> void:
	# **Delaying the project to protect a stockpile gathered for that project
	# would be nonsense.** Build takes straight from the stockpile.
	var town := _town(&"", {"wood": 30.0, "food": 400.0, "clothing": 80.0})
	town.objective = &"granary"

	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.BUILD, BuildPhase.new())
	month.run(colony, context)

	assert_true(town.invested(&"wood") > 0.0,
		"the project refused to touch the timber gathered for it")


func test_wants_are_bought_only_above_the_reserve() -> void:
	# The one tier that respects it. A town sells nothing below its comfort
	# target and buys toward it.
	var town := _town(&"", {"food": 400.0, "clothing": 80.0, "beer": 400.0})
	var reckoning := _reckon(town)

	assert_true(reckoning.reserve_of(&"beer") > 0.0,
		"a town kept no beer back at all, so Sell would sell what it just bought")
	assert_almost_eq(reckoning.want_of(&"beer"), 0.0, 0.001,
		"a town swimming in beer still wanted more")


func test_sell_keeps_what_the_intent_asked_to_be_kept() -> void:
	var armed := _town(GovernorIntent.DEFENCE, {"food": 400.0, "clothing": 80.0, "guns": 6.0}, 0.0)
	var colony := Colony.new()
	colony.add(armed)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.SELL, SellPhase.new())
	month.run(colony, context)

	assert_true(armed.held(&"guns") > 0.0,
		"the town sold the powder its governor had just told it to keep")


# --- The baseline is unchanged ----------------------------------------------

func test_the_baseline_is_still_what_the_data_says() -> void:
	# food 2, clothing 1, everything else 0.5, with the modifiers on top.
	var plain := _town(&"", {"food": 400.0, "clothing": 80.0})
	var reckoning := _reckon(plain)
	var mouths := float(plain.population())

	assert_almost_eq(
		reckoning.reserve_of(&"food"),
		mouths * ColonyNeeds.per_head(&"food") * ColonyNeeds.reserve_months(&"food"),
		0.001,
	)
	assert_almost_eq(ColonyNeeds.reserve_months(&"food"), 2.0, 0.001)
	assert_almost_eq(ColonyNeeds.reserve_months(&"clothing"), 1.0, 0.001)
	assert_almost_eq(ColonyNeeds.reserve_months(&"ore"), 0.5, 0.001)


func test_every_intent_wants_something_kept() -> void:
	# An intent with no stocks would reach the economy only through which
	# project the governor picks, which is the gap this ticket closes.
	for intent in GovernorIntent.IN_ORDER:
		assert_not_empty(Objective.intent_stocks(intent),
			"'%s' asks the town to lay in nothing at all" % intent)
