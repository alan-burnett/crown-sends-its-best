extends TestCase

## Buildings widen a town's influence and its vision (#410,
## `docs/mechanics/buildings.md` §4 *Defence*, *Expansion*).
##
## 🔒 **Town influence is the expansion branch's signature**, and **a building's
## influence lifts the cap**: `MAX_INFLUENCE` bounds the rings the population
## earns, and the buildings' rings sit on top. Guard towers also see further.

const SEED: int = 410

const THE_FOUR: Array[StringName] = [&"guard_towers", &"scouts", &"worker_cabins", &"fairgrounds"]

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


func _map() -> WorldMap:
	return WorldMap.new(40, 40, &"plains")


func _town(people: int = 12_000, buildings: Array = []) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(20, 20))
	town.workers = people
	for id in buildings:
		town.add_building(StringName(id))
	return town


func _ground(town: Town) -> int:
	return Territory.compute(_map(), [town]).tiles_of(town.id).size()


func test_each_of_the_four_widens_the_ground_a_town_works() -> void:
	var plain := _ground(_town())
	for id in THE_FOUR:
		assert_true(_ground(_town(12_000, [id])) > plain,
			"%s gave the town no more ground in phase 3's influence" % id)


func test_a_building_lifts_the_populations_cap() -> void:
	var grown := _town(80_000)
	assert_eq(Territory.reach_of(grown), Territory.MAX_INFLUENCE, "the fixture has not reached the cap")
	assert_eq(Territory.reach_of(_town(80_000, [&"scouts"])), Territory.MAX_INFLUENCE + 1,
		"a town already at the cap gained no ring from its scouts")


func test_a_dark_building_widens_nothing() -> void:
	var town := _town(12_000, [&"scouts"])
	town.dark_buildings = PackedStringArray(["scouts"])
	assert_eq(Territory.reach_of(town), Territory.reach_of(_town()), "an unpaid-for scouts' post still widened the town")


func test_guard_towers_see_further() -> void:
	var plain := Territory.compute(_map(), [_town()]).visible.size()
	var towered := Territory.compute(_map(), [_town(12_000, [&"guard_towers"])])
	# Past what their influence alone would show: the same ring from scouts.
	var scouted := Territory.compute(_map(), [_town(12_000, [&"scouts"])]).visible.size()
	assert_true(towered.visible.size() > plain)
	assert_true(towered.visible.size() > scouted, "guard towers saw no further than their ring of influence")


func test_crowding_falls_when_influence_rises() -> void:
	# A town packed well past comfortable on its capped ground.
	var crowded := _crowding(_town(300_000))
	var eased := _crowding(_town(300_000, [&"worker_cabins"]))
	assert_true(crowded > 0.0, "the fixture town is not crowded, so this proves nothing")
	assert_true(eased < crowded, "more ground left the town just as crowded")


func _crowding(town: Town) -> float:
	var colony := Colony.new()
	colony.add(town)
	var map := _map()
	var context := DeliberationContext.new(DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	context.data = {"town": town, "colony": colony, "map": map, "territory": Territory.compute(map, [town])}
	return IntentConsiderations.crowding_of(context)
