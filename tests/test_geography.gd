extends TestCase

## Geography: two fields instead of a per-tile draw (#271, SPEC §11.1, §16.1;
## `docs/mechanics/map.md` §2).
##
## 🔒 **The world is made first, and the colony arrives into it.** The map is not
## a surface for towns to be placed on.
##
## 🔒 **Nothing is placed.** A ridge of mountains is a ridge because elevation
## runs in ridges. Every tile used to be rolled independently of its neighbours,
## which does not make country — it makes **confetti**.
##
## 🔒 **Moisture falls away behind high ground**, which is why a desert is
## inland rather than scattered where nobody can explain it.

const SEED: int = 1649

## Enough seeds that a structural claim is about the generator and not about one
## lucky world. Kept modest because each one builds a whole map.
const SEEDS: int = 60

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


func _map(seed_value: int) -> WorldMap:
	return MapGenerator.generate(RngStreams.new(seed_value).stream("mapgen"))


func _is_land(map: WorldMap, x: int, y: int) -> bool:
	var terrain := String(map.terrain_at(x, y))
	return terrain != "ocean" and terrain != "sea"


## What share of this terrain's tiles have a neighbour of the same terrain.
##
## **The confetti measure.** If every tile were rolled independently, a terrain
## covering a share `p` of the land would have a same-terrain neighbour with
## probability about `1 - (1 - p)^4` — so at a sixth of the land, about half its
## tiles would be touching another. Country is well above that; confetti is at it.
func _clustered(terrain: String) -> float:
	var touching := 0
	var total := 0
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		for y in map.height:
			for x in map.width:
				if String(map.terrain_at(x, y)) != terrain:
					continue
				total += 1
				for neighbour in map.neighbours(x, y):
					if String(map.terrain_at(neighbour.x, neighbour.y)) == terrain:
						touching += 1
						break
	return 0.0 if total == 0 else float(touching) / float(total)


# --- 🔒 Nothing is rolled per tile ------------------------------------------

func test_terrain_is_read_off_the_two_fields_and_not_drawn() -> void:
	# 🔒 There is no `rng` in `terrain_at`, and there must not be: a tile whose
	# terrain depended on a die could differ from its neighbour for no reason
	# anybody could see, which is the confetti this ticket removes.
	var country := Geography.of(RngStreams.new(SEED).stream("mapgen"), 34, 26)
	for _repeat in 3:
		for y in [2, 9, 17]:
			for x in [3, 14, 29]:
				assert_eq(country.terrain_at(x, y), country.terrain_at(x, y),
					"asking twice about one tile gave two answers")


func test_the_weight_tables_are_gone_rather_than_layered_on_top() -> void:
	# 🔒 The acceptance, in as many words. Low elevation at a coastline already
	# does the work the coastal table did, and a second rule saying the same
	# thing is a second rule to fall out of step.
	var source := FileAccess.get_file_as_string("res://sim/map/map_generator.gd")
	assert_not_empty(source, "the generator could not be read")
	for gone in ["INLAND_WEIGHTS", "COASTAL_WEIGHTS", "_weighted_terrain"]:
		assert_false(source.contains(gone),
			"the generator still carries '%s'" % gone)


func test_mountains_form_ranges() -> void:
	var together := _clustered("mountains")
	assert_true(together > 0.85,
		"only %.0f%% of mountains touch another — that is a lottery, not a ridge"
			% (together * 100.0))


func test_deserts_form_regions() -> void:
	var together := _clustered("desert")
	assert_true(together > 0.85,
		"only %.0f%% of desert touches more desert — that is five per cent of everywhere, not a place"
			% (together * 100.0))


func test_forests_form_regions_too() -> void:
	assert_true(_clustered("forest") > 0.85, "forest is scattered rather than wooded")


# --- 🔒 And a region is not a blob ------------------------------------------

func test_a_forest_carries_clearings() -> void:
	# **Where the moisture field dips inside a wet region the terrain dips with
	# it**, so grassland appears in a forest without anybody authoring clearings.
	# Homogeneous patches read as a map editor; mixed ones read as country.
	var clearings := 0
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		for y in map.height:
			for x in map.width:
				if String(map.terrain_at(x, y)) != "grassland":
					continue
				var wooded := 0
				for neighbour in map.neighbours(x, y):
					if String(map.terrain_at(neighbour.x, neighbour.y)) == "forest":
						wooded += 1
				if wooded >= 3:
					clearings += 1
	assert_true(clearings > 0,
		"not one clearing in %d worlds — every forest is a solid block" % SEEDS)


func test_no_terrain_is_five_per_cent_of_everywhere() -> void:
	# The complaint the ticket opens with. A desert that is a fixed small share
	# of every tile is not a place.
	var tally: Dictionary = {}
	var land := 0
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		for y in map.height:
			for x in map.width:
				if not _is_land(map, x, y):
					continue
				land += 1
				var terrain := String(map.terrain_at(x, y))
				tally[terrain] = int(tally.get(terrain, 0)) + 1

	assert_true(land > 0, "no land was generated at all")
	var names: Array = tally.keys()
	names.sort()
	for terrain in names:
		var share := float(tally[terrain]) / float(land)
		assert_true(share > 0.08,
			"%s is %.1f%% of the land, which is a garnish rather than a country"
				% [terrain, share * 100.0])


# --- 🔒 Rain shadow ----------------------------------------------------------

func test_a_desert_sits_in_the_lee_of_high_ground() -> void:
	# 🔒 The acceptance: **materially more often** behind high ground than in
	# front of it.
	#
	# Asked of the fields rather than of the painted map, and that is not a
	# convenience. The shadow is cast by anything above `SHADOW_FROM`, which is
	# well below the mountain threshold — so a desert behind foothills is a
	# desert in a rain shadow, and a test that counted only painted mountains
	# misses it. My first version did, reported a bias of 1.03, and I nearly
	# retuned a mechanism that was working.
	#
	# The contrast is a range close upwind and open country downwind, against the
	# same thing reversed. Anything looser catches tiles with high ground on both
	# sides, which says nothing either way — and since elevation is normalised,
	# that is most of the map.
	var lee_dry := 0
	var lee_total := 0
	var windward_dry := 0
	var windward_total := 0

	for index in SEEDS:
		var country := Geography.of(
			RngStreams.new(index * 131 + 7).stream("mapgen"), 34, 26)
		for y in country.height:
			for x in country.width:
				var upwind := 0.0
				var downwind := 0.0
				for back in range(1, 4):
					if x - back >= 0:
						upwind = maxf(upwind, country.elevation_at(x - back, y))
					if x + back < country.width:
						downwind = maxf(downwind, country.elevation_at(x + back, y))

				var desert := String(country.terrain_at(x, y)) == "desert"
				if upwind >= 0.75 and downwind <= 0.5:
					lee_total += 1
					lee_dry += 1 if desert else 0
				elif downwind >= 0.75 and upwind <= 0.5:
					windward_total += 1
					windward_dry += 1 if desert else 0

	assert_true(lee_total > 200 and windward_total > 200,
		"too few tiles clearly on one side of a range to tell")
	var behind := float(lee_dry) / float(lee_total)
	var in_front := float(windward_dry) / float(windward_total)
	assert_true(behind > in_front * 1.5,
		"desert covers %.0f%% of the country behind a range and %.0f%% in front of one — that is a rounding error, not a rain shadow"
			% [behind * 100.0, in_front * 100.0])


func test_the_lee_of_a_range_is_drier_than_its_windward_side() -> void:
	# The mechanism itself, under the terrain that reads off it. *Moisture falls
	# away behind high ground* is the one rule that gives the driest country a
	# reason to sit where it does.
	var lee := 0.0
	var lee_count := 0
	var windward := 0.0
	var windward_count := 0

	for index in SEEDS:
		var country := Geography.of(
			RngStreams.new(index * 131 + 7).stream("mapgen"), 34, 26)
		for y in country.height:
			for x in country.width:
				var upwind := 0.0
				var downwind := 0.0
				for back in range(1, 4):
					if x - back >= 0:
						upwind = maxf(upwind, country.elevation_at(x - back, y))
					if x + back < country.width:
						downwind = maxf(downwind, country.elevation_at(x + back, y))
				if upwind >= 0.75 and downwind <= 0.5:
					lee += country.moisture_at(x, y)
					lee_count += 1
				elif downwind >= 0.75 and upwind <= 0.5:
					windward += country.moisture_at(x, y)
					windward_count += 1

	assert_true(lee_count > 200 and windward_count > 200, "too few tiles to tell")
	assert_true(lee / float(lee_count) < windward / float(windward_count) - 0.05,
		"the country behind a range is no drier than the country in front of it")


func test_drying_the_lee_only_ever_takes_moisture_away() -> void:
	var country := Geography.of(RngStreams.new(SEED).stream("mapgen"), 34, 26)
	for value in country.moisture:
		assert_true(value >= 0.0 and value <= 1.0,
			"a tile came out of the shadow at %f" % value)


# --- The rest of the generator is untouched ---------------------------------

func test_the_ocean_margin_is_unchanged() -> void:
	var map := _map(SEED)
	for y in map.height:
		for x in map.width:
			if x < MapGenerator.OCEAN_MARGIN or y < MapGenerator.OCEAN_MARGIN \
					or x >= map.width - MapGenerator.OCEAN_MARGIN \
					or y >= map.height - MapGenerator.OCEAN_MARGIN:
				assert_false(_is_land(map, x, y),
					"land at %d,%d is inside the ocean margin" % [x, y])


func test_the_shallows_cut_is_unchanged() -> void:
	# Water touching land is sea; the rest is ocean. It is what makes a coastal
	# site worth having, and this ticket must not have touched it.
	var map := _map(SEED)
	for y in map.height:
		for x in map.width:
			if String(map.terrain_at(x, y)) != "sea":
				continue
			var beside_land := false
			for neighbour in map.neighbours(x, y):
				if _is_land(map, neighbour.x, neighbour.y):
					beside_land = true
			assert_true(beside_land, "sea at %d,%d touches no land" % [x, y])


func test_there_is_still_land_to_settle() -> void:
	for index in 20:
		var map := _map(index * 131 + 7)
		var land := 0
		for y in map.height:
			for x in map.width:
				if _is_land(map, x, y):
					land += 1
		assert_true(land > 100, "seed %d produced almost no land at all" % index)


# --- 🔒 The same seed makes the same world ----------------------------------

func test_the_same_seed_produces_the_same_world() -> void:
	# SPEC §16.1, and the reason the noise is hand-rolled rather than
	# `FastNoiseLite`: an engine upgrade must not quietly reshape every map.
	var once := _map(SEED)
	var twice := _map(SEED)
	for y in once.height:
		for x in once.width:
			assert_eq(once.terrain_at(x, y), twice.terrain_at(x, y),
				"the same seed made different ground at %d,%d" % [x, y])


func test_a_different_seed_is_a_different_country() -> void:
	var here := _map(SEED)
	var elsewhere := _map(SEED + 977)
	var same := 0
	var total := 0
	for y in here.height:
		for x in here.width:
			total += 1
			if here.terrain_at(x, y) == elsewhere.terrain_at(x, y):
				same += 1
	assert_true(float(same) / float(total) < 0.9,
		"two unrelated seeds made nearly the same world")
