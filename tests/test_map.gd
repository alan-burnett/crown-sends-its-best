extends TestCase

## Map generation (#37).

const SEED: int = 20_260_918

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	content.free()


func _map(seed_value: int = SEED) -> WorldMap:
	return MapGenerator.generate(RngStreams.new(seed_value).stream("mapgen"))


# --- Terrain ---------------------------------------------------------------

func test_every_terrain_in_the_spec_is_present() -> void:
	for id in ["desert", "grassland", "plains", "forest", "mountains", "sea", "ocean"]:
		assert_true(Terrain.has(StringName(id)), "no terrain '%s'" % id)


func test_yields_come_from_data() -> void:
	# High, medium and low are tuning values in data, not constants in code, so
	# balancing every forest in the game is one number in one place.
	var levels := Terrain.levels()
	assert_true(levels.has("high") and levels.has("medium") and levels.has("low"))
	assert_true(float(levels["high"]) > float(levels["medium"]))
	assert_true(float(levels["medium"]) > float(levels["low"]))


func test_the_spec_table_is_what_the_terrains_yield() -> void:
	# SPEC §11.1, read back out of the data.
	var high := Terrain.level_value("high")
	var low := Terrain.level_value("low")
	assert_almost_eq(Terrain.get_terrain(&"plains").yield_of(&"food"), high)
	assert_almost_eq(Terrain.get_terrain(&"forest").yield_of(&"wood"), high)
	assert_almost_eq(Terrain.get_terrain(&"forest").yield_of(&"furs"), high)
	assert_almost_eq(Terrain.get_terrain(&"mountains").yield_of(&"stone"), high)
	assert_almost_eq(Terrain.get_terrain(&"mountains").yield_of(&"ore"), high)
	assert_almost_eq(Terrain.get_terrain(&"sea").yield_of(&"food"), high)
	assert_almost_eq(Terrain.get_terrain(&"ocean").yield_of(&"food"), low)


func test_sea_and_ocean_yield_nothing_but_food() -> void:
	assert_eq(Terrain.get_terrain(&"sea").yielded_resources(), PackedStringArray(["food"]))
	assert_eq(Terrain.get_terrain(&"ocean").yielded_resources(), PackedStringArray(["food"]))


func test_an_unmentioned_yield_is_zero() -> void:
	assert_almost_eq(Terrain.get_terrain(&"desert").yield_of(&"wood"), 0.0)


# --- Determinism -----------------------------------------------------------

func test_the_same_seed_produces_an_identical_map() -> void:
	assert_eq(_map().map_hash(), _map().map_hash())


func test_a_different_seed_produces_a_different_map() -> void:
	assert_ne(_map(SEED).map_hash(), _map(SEED + 1).map_hash())


func test_a_draw_on_another_stream_does_not_change_the_map() -> void:
	# The whole point of a named stream per system.
	var expected := _map().map_hash()

	var streams := RngStreams.new(SEED)
	for i in 20:
		streams.stream("sim").randi()
		streams.stream("letters").randf()
		streams.contact_stream("marshal").randi()
	assert_eq(MapGenerator.generate(streams.stream("mapgen")).map_hash(), expected)


# --- Shape -----------------------------------------------------------------

func test_the_map_has_an_ocean_edge() -> void:
	# The New World is reached by sea.
	var map := _map()
	for x in map.width:
		assert_false(map.is_land(x, 0), "land on the top edge at %d" % x)
		assert_false(map.is_land(x, map.height - 1), "land on the bottom edge at %d" % x)
	for y in map.height:
		assert_false(map.is_land(0, y), "land on the left edge at %d" % y)
		assert_false(map.is_land(map.width - 1, y), "land on the right edge at %d" % y)


func test_there_is_a_useful_amount_of_land() -> void:
	var map := _map()
	var land := map.land_count()
	assert_true(land > 0, "no land at all")
	assert_true(land < map.width * map.height, "no water at all")


func test_the_land_is_in_coherent_masses_rather_than_noise() -> void:
	# A map of scattered single tiles has no coast worth settling and no
	# interior — it does not read as a place. So most of the land should be in
	# one piece. The threshold is deliberately generous: this asks whether land
	# clumps at all, not how large a continent ought to be.
	for seed_value in [SEED, SEED + 1, SEED + 2, SEED + 3]:
		var map := _map(seed_value)
		var largest := _largest_landmass(map)
		var share := float(largest) / float(map.land_count())
		assert_true(share >= 0.25,
			"seed %d: the largest landmass holds %.0f%% of the land" % [seed_value, share * 100.0])


func test_coasts_are_sea_rather_than_open_ocean() -> void:
	# Sea yields high food and ocean almost none, which is what makes a coastal
	# site worth having.
	var map := _map()
	var found := false
	for y in map.height:
		for x in map.width:
			if not map.is_land(x, y):
				continue
			for at in map.neighbours(x, y):
				if not map.is_land(at.x, at.y):
					assert_eq(map.terrain_at(at.x, at.y), &"sea",
						"water beside land at %d,%d is open ocean" % [at.x, at.y])
					found = true
	assert_true(found, "no coastline at all")


func _largest_landmass(map: WorldMap) -> int:
	var seen: Dictionary = {}
	var largest := 0
	for y in map.height:
		for x in map.width:
			if not map.is_land(x, y) or seen.has(Vector2i(x, y)):
				continue
			var size := 0
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				size += 1
				for next in map.neighbours(at.x, at.y):
					if map.is_land(next.x, next.y) and not seen.has(next):
						seen[next] = true
						stack.append(next)
			largest = maxi(largest, size)
	return largest


# --- The starting site -----------------------------------------------------

func test_a_starting_site_can_sustain_a_town() -> void:
	# So M2 is playable rather than a famine simulator.
	for seed_value in [SEED, SEED + 1, SEED + 2, SEED + 3, SEED + 4]:
		var map := _map(seed_value)
		var site := MapGenerator.choose_starting_site(map)
		assert_true(map.in_bounds(site.x, site.y), "seed %d: no site at all" % seed_value)
		assert_true(map.is_land(site.x, site.y), "seed %d: the site is in the water" % seed_value)
		assert_true(map.yield_around(site.x, site.y, &"food") > 0.0,
			"seed %d: nothing to eat at the site" % seed_value)


func test_the_site_is_the_best_one_on_the_map() -> void:
	var map := _map()
	var site := MapGenerator.choose_starting_site(map)
	var best := MapGenerator.site_score(map, site.x, site.y)
	for y in map.height:
		for x in map.width:
			if map.is_land(x, y):
				assert_true(MapGenerator.site_score(map, x, y) <= best,
					"a better site exists at %d,%d" % [x, y])


func test_choosing_a_site_does_not_draw_from_any_stream() -> void:
	# It reads the map. A site that consumed a draw would shift every later one.
	var streams := RngStreams.new(SEED)
	var map := MapGenerator.generate(streams.stream("mapgen"))
	var before := streams.to_dict()
	MapGenerator.choose_starting_site(map)
	assert_eq(streams.to_dict(), before)


# --- Serialisation ---------------------------------------------------------

func test_the_map_survives_a_round_trip() -> void:
	var map := _map()
	var restored := WorldMap.from_dict(map.to_dict())
	assert_eq(restored.map_hash(), map.map_hash())
	assert_eq(restored.width, map.width)
	assert_eq(restored.land_count(), map.land_count())


func test_the_map_is_carried_by_the_run() -> void:
	var run := RunState.new_run(SEED)
	assert_true(run.map != null)
	assert_true(run.map.land_count() > 0)
	assert_true(run.map.is_land(run.starting_site.x, run.starting_site.y))

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.map.map_hash(), run.map.map_hash())
	assert_eq(restored.starting_site, run.starting_site)
	assert_eq(restored.state_hash(), run.state_hash())
