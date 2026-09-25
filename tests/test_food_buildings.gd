extends TestCase

## The four food buildings (#409, `docs/mechanics/buildings.md` §4 *Food*,
## `map.md` §7).
##
## 🔒 **Sea is one building; plains is four.** A dock raises what sea and ocean
## give, and nothing else improves it. A farm, then an irrigation station
## (doubled where a farm stands), then a windmill and a river mill, each raise
## what the plains give again. Quick and capped against slow and climbing — the
## magnitudes are placeholders, and the shape is what is locked.

const SEED: int = 409

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


## Sea to the west, then plains, grassland and forest, all within the town's reach.
func _map() -> WorldMap:
	var map := WorldMap.new(12, 9, &"ocean")
	for y in range(1, 8):
		map.set_terrain(1, y, &"sea")
		for x in range(2, 11):
			map.set_terrain(x, y, &"plains" if x <= 5 else (&"grassland" if x <= 7 else &"forest"))
	return map


func _town(buildings: Array = []) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = 40_000
	for id in buildings:
		town.add_building(StringName(id))
	return town


func _context(map: WorldMap, town: Town) -> ColonyContext:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return context


## What one tile gives this town of food, as Work reckons it.
func _food(map: WorldMap, town: Town, at: Vector2i) -> float:
	return WorkPhase.new()._yield_of(_context(map, town), town, at, &"food")


# --- 🔒 Each on its own ground, and only there -----------------------------------

func test_the_dock_raises_sea_and_ocean_and_nothing_else() -> void:
	var map := _map()
	var sea := Vector2i(1, 4)
	var ocean := Vector2i(0, 4)
	var plains := Vector2i(3, 4)
	assert_true(_food(map, _town(["dock"]), sea) > _food(map, _town(), sea), "the dock fed nobody from the sea")
	assert_true(_food(map, _town(["dock"]), ocean) > _food(map, _town(), ocean))
	assert_almost_eq(_food(map, _town(["dock"]), plains), _food(map, _town(), plains), 0.0001,
		"a dock raised the plains")
	# And through the table Work assigns hands from, not only the one-tile path.
	var bare := _town()
	var docked := _town(["dock"])
	var plain: Dictionary = WorkPhase.new()._yields_for(bare, _context(map, bare), [sea])
	var fed: Dictionary = WorkPhase.new()._yields_for(docked, _context(map, docked), [sea])
	assert_true(float(fed["1,4"]["food"]) > float(plain["1,4"]["food"]),
		"the hands Work sends to sea saw no dock")


func test_irrigation_raises_grassland_and_plains_and_doubles_on_a_farm() -> void:
	var map := _map()
	var plains := Vector2i(3, 4)
	var grass := Vector2i(6, 4)
	var forest := Vector2i(9, 4)
	var plain := _food(map, _town(), plains)
	var watered := _food(map, _town(["irrigation_station"]), plains)
	assert_true(watered > plain, "irrigation did nothing for the plains")
	assert_true(_food(map, _town(["irrigation_station"]), grass) > _food(map, _town(), grass))
	assert_almost_eq(_food(map, _town(["irrigation_station"]), forest), _food(map, _town(), forest), 0.0001,
		"irrigation raised the forest")

	# Doubled where a farm stands: the station adds twice as much, as a share.
	map.build(plains.x, plains.y, &"farm")
	var farmed := _food(map, _town(), plains)
	var farmed_watered := _food(map, _town(["irrigation_station"]), plains)
	assert_almost_eq(farmed_watered / farmed - 1.0, 2.0 * (watered / plain - 1.0), 0.0001,
		"irrigation was not doubled on a farm")


func test_the_mills_raise_farms_and_nothing_else() -> void:
	var map := _map()
	var farm := Vector2i(3, 4)
	var field := Vector2i(3, 5)
	map.build(farm.x, farm.y, &"farm")
	for mill in ["windmill", "river_mill"]:
		assert_true(_food(map, _town([mill]), farm) > _food(map, _town(), farm), "the %s did nothing for a farm" % mill)
		assert_almost_eq(_food(map, _town([mill]), field), _food(map, _town(), field), 0.0001,
			"the %s raised a field with no farm" % mill)


# --- 🔒 Speed against ceiling (`map.md` §7) ------------------------------------------

func test_the_plains_keep_climbing_through_each_of_their_buildings() -> void:
	var map := _map()
	var farm := Vector2i(3, 4)
	map.build(farm.x, farm.y, &"farm")
	var built: Array = []
	var last := _food(map, _town(built), farm)
	for id in ["irrigation_station", "windmill", "river_mill"]:
		built.append(id)
		var now := _food(map, _town(built), farm)
		assert_true(now > last, "the %s added nothing to a farm already watered and milled" % id)
		last = now
	assert_true(last > _food(map, _town(["dock"]), Vector2i(1, 4)),
		"a fully built farm yields no more than a docked sea tile, so plains has no higher ceiling")


func test_the_dock_does_nothing_for_a_town_with_no_sea() -> void:
	var map := WorldMap.new(12, 9, &"plains")
	var town := _town()
	var docked := _town(["dock"])
	var context := _context(map, town)
	var yields := WorkPhase.new()._yields_for(town, context, context.tiles_of(town))
	var with_dock := WorkPhase.new()._yields_for(docked, _context(map, docked), context.tiles_of(town))
	assert_eq(with_dock, yields, "a dock changed what an inland town's ground gives")


# --- 🔒 A governor can want them ------------------------------------------------------

func test_improve_yield_values_irrigation_by_the_plains_the_town_worked() -> void:
	# At its improvement limit, so only buildings are on offer.
	var map := _map()
	var town := _town()
	town.workers = 2_000
	var context := _context(map, town)
	map.build(3, 3, &"farm")
	map.build(4, 3, &"farm")
	town.harvested_at = {"3,4": {"food": 6.0}, "4,4": {"food": 6.0}}
	town.harvested = {"food": 12.0}
	town.receive_gold(5_000.0)
	var chosen := SlotScorers.place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context)
	assert_eq(String(chosen.get("id", "")), "irrigation_station",
		"a town working the plains for grain saw nothing in an irrigation station")


func test_the_validator_refuses_ground_that_does_not_exist() -> void:
	var validator := ContentValidator.new()
	validator.check_tile_yield_bonuses(content)
	assert_true(validator.ok(), "the shipped food buildings do not validate")
	var rules: Array = content.collection("buildings")["dock"]["effects"]["tile_yield_bonus"]
	rules[0]["terrain"] = ["the_briny_deep"]
	validator = ContentValidator.new()
	validator.check_tile_yield_bonuses(content)
	assert_false(validator.ok(), "a dock on a terrain nobody has heard of passed")
