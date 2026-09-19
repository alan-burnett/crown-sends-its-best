extends TestCase

## Conversion of raw resources into processed ones (#64), SPEC §11.3 step 1.
##
## Seven of the nineteen resources could not come into existence before this, and
## one of them — **clothing** — is a need. A town with no gold could not clothe
## itself at all.
##
## ## A note on the fixtures
##
## Every town here is **fed and clothed unless the test is about going without**.
## A town short of food weights fishing above every forge on the board, which is
## correct and makes the phase look broken when it is merely being sensible. The
## first draft of these tests starved their towns and spent an hour proving that
## hungry people fish.

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


# --- Fixtures ---------------------------------------------------------------

## A town on a spit of land in open water.
##
## **Deliberately barren**, so the choice is between a loom and what little the
## sea gives. Good ground beats every forge on the board, which is realistic and
## useless for testing whether a forge works at all.
func _barren() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	map.set_terrain(3, 3, &"desert")
	return map


## Ground worth working, for the tests about what a town chooses.
func _land() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(2, 5):
		for x in range(2, 5):
			map.set_terrain(x, y, &"desert")
	return map


## Fed, clothed, and holding whatever the test puts in its hands.
func _town(stock: Dictionary = {}, workers: int = 4) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	town.store(&"food", 500.0)
	town.store(&"clothing", 200.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


## A town with nothing in the larder. Used only where that is the point.
func _destitute(stock: Dictionary = {}, workers: int = 4) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _harness(town: Town, map: WorldMap = null) -> Dictionary:
	var ground := map if map != null else _barren()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), ground
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(ground, colony.in_order())

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


func _worked(harness: Dictionary) -> Dictionary:
	var events: Array = harness["context"].log.of_type(WorkPhase.EVENT_WORKED)
	return events[events.size() - 1].payload


# --- All six conversions ----------------------------------------------------

func test_every_conversion_the_spec_names_exists() -> void:
	# SPEC §10.1: ore to iron, furs or cotton to clothing, iron to tools and
	# guns, food to beer, sugar to rum, tobacco to cigars.
	var expected: Array = [
		["iron", "ore"], ["clothing", "furs"], ["clothing", "cotton"],
		["tools", "iron"], ["guns", "iron"],
		["beer", "food"], ["rum", "sugar"], ["cigars", "tobacco"],
	]
	var found: Dictionary = {}
	for recipe in Conversion.all():
		found[String(recipe.id())] = recipe

	for pair in expected:
		var id := "%s<-%s" % [pair[0], pair[1]]
		assert_has(found, id, "no recipe turns %s into %s" % [pair[1], pair[0]])
		assert_true(found[id].made > 0.0, "%s makes nothing" % id)
		assert_true(found[id].consumed > 0.0, "%s uses nothing up" % id)


func test_every_conversion_actually_produces_its_output() -> void:
	# Six workers on barren ground, with a heap of the input. If a recipe cannot
	# happen here it cannot happen anywhere.
	for recipe in Conversion.all():
		var town := _town({String(recipe.input): 500.0}, 6)
		var before := town.held(recipe.output)
		_run_month(_harness(town))
		assert_true(town.held(recipe.output) > before,
			"six workers with five hundred %s made no %s" % [recipe.input, recipe.output])


func test_a_conversion_consumes_its_input() -> void:
	var town := _town({"ore": 500.0}, 6)
	_run_month(_harness(town))
	assert_true(town.held(&"ore") < 500.0, "iron was smelted out of nothing")


func test_clothing_can_be_woven_from_either_furs_or_cotton() -> void:
	# The two-input case. Whichever the town actually has will do.
	for source in ["furs", "cotton"]:
		var town := _town({source: 500.0}, 6)
		_run_month(_harness(town))
		assert_true(town.held(&"clothing") > 200.0, "a town with %s wove nothing" % source)


# --- 🔒 A worker is in the fields or in the town, never both ---------------

func test_hands_are_split_and_never_exceed_the_population() -> void:
	for workers in [1, 3, 7]:
		var town := _town({"ore": 500.0, "furs": 500.0, "sugar": 500.0}, workers)
		var harness := _harness(town)
		_run_month(harness)
		var payload := _worked(harness)
		assert_true(int(payload["tiles_worked"]) + int(payload["converting"]) <= workers,
			"%d workers did %d tiles and %d conversions" % [
				workers, payload["tiles_worked"], payload["converting"]])


func test_converting_costs_a_worked_tile() -> void:
	# Two identical towns and the same number of hands. The one with ore to smelt
	# works **fewer tiles**, because the smelters came off the land.
	var plain := _town({}, 4)
	var forge := _town({"ore": 500.0}, 4)
	var one := _harness(plain)
	var other := _harness(forge)
	_run_month(one)
	_run_month(other)

	assert_true(int(_worked(other)["converting"]) > int(_worked(one)["converting"]),
		"the town with ore put no more hands to the forge")
	assert_true(int(_worked(other)["tiles_worked"]) < int(_worked(one)["tiles_worked"]),
		"the smelters were conjured out of nowhere rather than taken off the land")


# --- 🔒 The start-of-month stockpile ----------------------------------------

func test_conversion_draws_on_the_start_of_month_stockpile() -> void:
	# SPEC §11.3 step 1. **Ore bought from the Crown this month is smelted next
	# month**, so Exchange cannot be used as a same-month forge.
	#
	# The phase is run against a deliberately stale snapshot, which is exactly
	# the situation a mid-month purchase creates.
	var town := _town({"ore": 3.0}, 6)
	var harness := _harness(town)
	var before := ColonySnapshot.of(harness["colony"])

	# The ship docks. The snapshot does not know.
	town.store(&"ore", 500.0)
	WorkPhase.new().run(town, before, harness["context"])

	var smelted := town.held(&"iron")
	assert_true(smelted > 0.0, "the three ore it did have were never smelted")
	assert_true(smelted <= 3.0 / ResourceCatalogue.input_per_unit_of(&"iron") + 0.0001,
		"it made %f of iron, which is more than three of ore can yield" % smelted)
	assert_true(town.held(&"ore") > 490.0, "the new ore went into the furnace the day it landed")


func test_two_recipes_cannot_spend_the_same_stock_twice() -> void:
	# Tools and guns are both made of iron. Between them they may use what is
	# there and no more.
	var town := _town({"iron": 3.0}, 6)
	_run_month(_harness(town))

	assert_true(town.held(&"iron") >= -0.0001,
		"the town forged iron it did not have: %f left" % town.held(&"iron"))
	assert_true(town.held(&"tools") + town.held(&"guns") > 0.0, "nothing was forged at all")


# --- 🔒 The food-and-clothing lockstep --------------------------------------

func test_a_town_with_furs_and_hands_clothes_itself() -> void:
	# **The acceptance criterion this ticket exists for.** No gold, no Crown, no
	# Exchange phase — just furs and people.
	var town := _destitute({"furs": 100.0, "food": 500.0}, 4)
	var harness := _harness(town)
	_run_month(harness)

	assert_true(town.held(&"clothing") > 0.0, "a town with furs and spare hands stayed naked")
	assert_not_empty(harness["context"].log.of_type(WorkPhase.EVENT_CONVERTED))


func test_a_cold_town_leaves_good_ground_to_weave() -> void:
	# Clothing is not a tile yield, so before this the survival check could only
	# ever act on food and the lockstep was half a rule.
	#
	# One worker, ground worth working, and furs in the store. The cold town goes
	# to the loom and the clothed one goes to the fields.
	var cold := _destitute({"furs": 100.0, "food": 500.0}, 1)
	var clothed := _destitute({"furs": 100.0, "food": 500.0, "clothing": 200.0}, 1)
	var one := _harness(cold, _land())
	var other := _harness(clothed, _land())
	_run_month(one)
	_run_month(other)

	assert_eq(int(_worked(one)["converting"]), 1, "a cold town with furs worked the fields")
	assert_eq(int(_worked(other)["converting"]), 0, "a well-clothed town wove anyway")


func test_a_hungry_town_does_not_brew_its_grain() -> void:
	# The recipe subtracts what it consumes, so this falls out of the scoring
	# rather than out of a rule about beer.
	var hungry := _destitute({"food": 2.0}, 4)
	_run_month(_harness(hungry))
	assert_almost_eq(hungry.held(&"beer"), 0.0, 0.0001,
		"a town with two days of grain turned it into drink")


func test_a_town_swimming_in_grain_brews() -> void:
	var fed := _town({}, 4)
	_run_month(_harness(fed))
	assert_true(fed.held(&"beer") > 0.0, "a town with five hundred of grain brewed nothing")


# --- Making against buying --------------------------------------------------

func test_a_town_with_sugar_makes_rum_and_one_without_cannot() -> void:
	var planter := _town({"sugar": 200.0}, 6)
	var without := _town({}, 6)
	_run_month(_harness(planter))
	_run_month(_harness(without))

	assert_true(planter.held(&"rum") > 0.0, "a town with sugar distilled nothing")
	assert_almost_eq(without.held(&"rum"), 0.0, 0.0001,
		"a town with no sugar produced rum from somewhere")


# --- Experts and buildings (SPEC §12.2) -------------------------------------

func test_experts_multiply_processed_yields_too() -> void:
	# "Each expert increases all of a town's yield of that particular resource,
	# **including processed resources**."
	var plain := _town({"ore": 500.0}, 6)
	var skilled := _town({"ore": 500.0}, 6)
	skilled.add_experts(&"iron", 2)

	_run_month(_harness(plain))
	_run_month(_harness(skilled))

	assert_true(skilled.held(&"iron") > plain.held(&"iron"),
		"two ironmasters smelted no more than nobody: %f against %f" % [
			skilled.held(&"iron"), plain.held(&"iron")])


func test_a_building_that_helps_a_conversion_helps_it() -> void:
	var plain := _town({"ore": 500.0}, 6)
	var equipped := _town({"ore": 500.0}, 6)
	equipped.add_building(&"smithy")  # a yield bonus on iron

	_run_month(_harness(plain))
	_run_month(_harness(equipped))

	assert_true(equipped.held(&"iron") > plain.held(&"iron"), "the smithy smelted no better")


# --- Determinism ------------------------------------------------------------

func test_the_labour_split_is_deterministic() -> void:
	var first: String = ""
	for _attempt in 4:
		var town := _town({"ore": 60.0, "furs": 60.0, "sugar": 60.0}, 5)
		_run_month(_harness(town))
		var shape := Canonical.hash_of(town.stockpile)
		if first.is_empty():
			first = shape
		assert_eq(shape, first, "the same town worked a different month the second time")


func test_recipes_come_back_in_a_stable_order() -> void:
	var ids: PackedStringArray = PackedStringArray()
	for recipe in Conversion.all():
		ids.append(String(recipe.id()))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(Array(ids), Array(sorted), "recipes came back in an unstable order")
