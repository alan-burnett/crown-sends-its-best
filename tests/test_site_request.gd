extends TestCase

## Run start's site half: he states what he wants and the map answers (#273,
## SPEC §11.4, §16.1; `docs/mechanics/map.md` §4, §5, §6).
##
## 🔒 **The PC never chooses a tile.** §11.4 locks it for founding a town, and
## run start is the same act by the same sort of person. A coordinate means
## nothing to a player who has never played.
##
## 🔒 **A request tilts a good site. It does not pick a strange one.** The base
## score is what the ground is worth; the request adds weight on top and never in
## place of it.
##
## 🔒 **Sea within reach, whatever was asked.** A landlocked first town cannot be
## supplied, traded with, or reinforced.

const SEED: int = 1649

## Enough seeds that a claim about the generator is not a claim about one world.
const SEEDS: int = 40

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


func _map(seed_value: int) -> WorldMap:
	return MapGenerator.generate(RngStreams.new(seed_value).stream("mapgen"))


## What share of the ground around a site is this terrain, across many seeds.
func _around(request: StringName, terrain: String) -> float:
	var found := 0
	var looked := 0
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		var at := SiteRequest.choose(map, request)
		if at.x < 0:
			continue
		for dy in range(-SiteRequest.REACH, SiteRequest.REACH + 1):
			for dx in range(-SiteRequest.REACH, SiteRequest.REACH + 1):
				var tile := Vector2i(at.x + dx, at.y + dy)
				if not map.in_bounds(tile.x, tile.y):
					continue
				looked += 1
				if String(map.terrain_at(tile.x, tile.y)) == terrain:
					found += 1
	return 0.0 if looked == 0 else float(found) / float(looked)


# --- 🔒 A request, not a coordinate -----------------------------------------

func test_nothing_offers_the_player_a_list_of_coordinates() -> void:
	# 🔒 The acceptance, against the code that used to do it. `SITES_OFFERED` and
	# `sites_for` are gone, and the setup screen no longer prints leagues.
	# **Declarations, not mentions.** The first version searched for the bare
	# words and tripped on the comment explaining what had been removed, which is
	# a test failing on its own changelog.
	for path in ["res://game/run_setup.gd", "res://presentation/setup/setup_screen.gd"]:
		var source := FileAccess.get_file_as_string(path)
		assert_not_empty(source, "%s could not be read" % path)
		for gone in ["const SITES_OFFERED", "func sites_for", "var site_choice",
				"func _site_line", "func _sites("]:
			assert_false(source.contains(gone),
				"%s still offers the player a chart: '%s'" % [path, gone])


func test_a_setup_carries_a_purpose_rather_than_a_place() -> void:
	var setup := RunSetup.new()
	assert_true(SiteRequest.is_request(setup.request),
		"a fresh setup does not know what the colony is for")
	var fields: Dictionary = {}
	for entry in setup.get_property_list():
		fields[String(entry["name"])] = true
	assert_false(fields.has("site_choice"),
		"a setup still carries which chart was picked")


func test_the_request_survives_a_save() -> void:
	var setup := RunSetup.new()
	setup.request = SiteRequest.DEFENSIVE_POSITION
	assert_eq(RunSetup.from_dict(setup.to_dict()).request,
		SiteRequest.DEFENSIVE_POSITION, "a reload forgot what the colony was for")


# --- 🔒 Sea within reach, whatever was asked --------------------------------

func test_every_answer_has_sea_within_reach() -> void:
	# 🔒 Not negotiable (§6). The Crown reaches the colony by ship: a landlocked
	# first town cannot run Exchange, cannot be supplied, and cannot receive a
	# single immigrant or soldier.
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		for request in SiteRequest.ALL:
			var at := SiteRequest.choose(map, request)
			assert_true(at.x >= 0, "seed %d offered no site at all for %s" % [index, request])
			assert_true(SiteRequest.sea_within_reach(map, at.x, at.y),
				"seed %d put a %s colony out of reach of a ship" % [index, request])


func test_every_map_offers_somewhere_a_ship_can_reach() -> void:
	# The one guarantee generation has to make. It holds by construction — land
	# is grown inside an ocean margin and the shallows are cut around it — but a
	# generator change that broke it would break every run rather than one.
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		var reachable := 0
		for y in map.height:
			for x in map.width:
				if map.is_land(x, y) and SiteRequest.sea_within_reach(map, x, y):
					reachable += 1
		assert_true(reachable > 0, "seed %d has no coast to land on" % index)


# --- 🔒 It tilts, and does not pick a strange site --------------------------

func test_a_request_measurably_moves_the_answer() -> void:
	var moved: Dictionary = {}
	for request in SiteRequest.ALL:
		moved[String(request)] = 0

	for index in SEEDS:
		var map := _map(index * 131 + 7)
		# The defensive request is the untilted one, so it is the comparison.
		var untilted := SiteRequest.choose(map, SiteRequest.DEFENSIVE_POSITION)
		for request in SiteRequest.ALL:
			if SiteRequest.choose(map, request) != untilted:
				moved[String(request)] += 1

	for request in [SiteRequest.QUICK_GROWTH, SiteRequest.ECONOMIC_OPPORTUNITY,
			SiteRequest.LONG_TERM_CULTIVATION]:
		assert_true(int(moved[String(request)]) > SEEDS / 2,
			"asking for %s moved the site in only %d of %d seeds"
				% [request, moved[String(request)], SEEDS])
	assert_eq(int(moved[String(SiteRequest.DEFENSIVE_POSITION)]), 0,
		"the defensive request tilted the search, which §4 answers by fiat instead")


func test_each_request_leans_where_it_says_it_does() -> void:
	# The tilt is a weight vector over terrain, so it shows up in what surrounds
	# the answer rather than in the answer's coordinates.
	var base_forest := _around(SiteRequest.DEFENSIVE_POSITION, "forest")
	var base_sea := _around(SiteRequest.DEFENSIVE_POSITION, "sea")
	var base_grass := _around(SiteRequest.DEFENSIVE_POSITION, "grassland")

	assert_true(_around(SiteRequest.ECONOMIC_OPPORTUNITY, "forest") > base_forest + 0.05,
		"a colony asking for something to sell was put in open country")
	assert_true(_around(SiteRequest.QUICK_GROWTH, "sea") > base_sea + 0.05,
		"a colony asking for quick growth was put away from the water")
	assert_true(_around(SiteRequest.LONG_TERM_CULTIVATION, "grassland") > base_grass + 0.05,
		"a colony asking for cultivation was put off the good soil")


func test_a_request_never_answers_with_somewhere_bad_at_everything_else() -> void:
	# 🔒 §4: *prioritise sea* does not find the most maritime tile on the map
	# regardless of what surrounds it. A player who asks for one thing is never
	# handed somewhere poor at all the others.
	for index in SEEDS:
		var map := _map(index * 131 + 7)
		var best := MapGenerator.site_score(
			map, SiteRequest.choose(map, SiteRequest.DEFENSIVE_POSITION).x,
			SiteRequest.choose(map, SiteRequest.DEFENSIVE_POSITION).y)
		for request in SiteRequest.ALL:
			var at := SiteRequest.choose(map, request)
			var worth := MapGenerator.site_score(map, at.x, at.y)
			assert_true(worth > best * 0.6,
				"seed %d answered %s with ground worth %.1f against the best %.1f"
					% [index, request, worth, best])


func test_desert_is_the_lowest_valued_terrain_there_is() -> void:
	# 🔒 §4, and what stops *economic opportunity* answering with a mountain in
	# the middle of a waste.
	#
	# The base score does this on its own — desert yields effectively no food,
	# wood or stone — which an explicit penalty on top turned out not to change.
	for request in SiteRequest.ALL:
		assert_true(_around(request, "desert") < 0.1,
			"%s answers with a site ringed by desert" % request)

	# And it really is the worst of them, asked of the scorer rather than assumed.
	var map := _map(SEED)
	var by_terrain: Dictionary = {}
	for y in map.height:
		for x in map.width:
			if not map.is_land(x, y):
				continue
			var terrain := String(map.terrain_at(x, y))
			var worth := map.yield_at(x, y, &"food") * 2.0 				+ map.yield_at(x, y, &"wood") + map.yield_at(x, y, &"stone") * 0.5
			by_terrain[terrain] = minf(float(by_terrain.get(terrain, 1.0e30)), worth)
	assert_true(by_terrain.has("desert"), "this seed has no desert to judge")
	for terrain in by_terrain:
		if String(terrain) == "desert":
			continue
		assert_true(float(by_terrain["desert"]) <= float(by_terrain[terrain]),
			"desert is worth more than %s, so it is not the lowest-valued terrain"
				% terrain)


# --- 🔒 The defensive request is answered by fiat ---------------------------

func test_the_defensive_request_puts_a_mountain_under_the_town() -> void:
	for index in 12:
		var run := RunState.new_run(
			index * 131 + 7, Vector2i(-1, -1), SiteRequest.DEFENSIVE_POSITION)
		var at := run.starting_site
		assert_eq(String(run.map.terrain_at(at.x, at.y)), "mountains",
			"seed %d gave a defensive colony no high ground" % index)
		assert_true(SiteRequest.sea_within_reach(run.map, at.x, at.y),
			"seed %d put the high ground out of reach of a ship" % index)


func test_the_ground_under_it_was_good_before_the_mountain_arrived() -> void:
	# **It asked for a position rather than a country**, so what surrounds it is
	# whatever surrounded the best untilted site — which is the honest trade.
	for index in 12:
		var map := _map(index * 131 + 7)
		var at := SiteRequest.choose(map, SiteRequest.DEFENSIVE_POSITION)
		var untouched := MapGenerator.site_score(map, at.x, at.y)
		SiteRequest.raise_high_ground(map, at)
		assert_eq(String(map.terrain_at(at.x, at.y)), "mountains")
		assert_true(untouched > 0.0,
			"seed %d chose worthless ground and then put a mountain on it" % index)


func test_no_other_request_moves_the_ground() -> void:
	for request in SiteRequest.ALL:
		if request == SiteRequest.DEFENSIVE_POSITION:
			continue
		assert_false(SiteRequest.wants_high_ground(request),
			"%s raises high ground, which only the defensive request may" % request)
		var run := RunState.new_run(SEED, Vector2i(-1, -1), request)
		var at := run.starting_site
		assert_ne(String(run.map.terrain_at(at.x, at.y)), "mountains",
			"%s put the town on a mountain nobody asked for" % request)


# --- 🔒 The same seed and request answer the same way -----------------------

func test_the_same_seed_and_request_choose_the_same_ground() -> void:
	for request in SiteRequest.ALL:
		var once := SiteRequest.choose(_map(SEED), request)
		var twice := SiteRequest.choose(_map(SEED), request)
		assert_eq(once, twice, "%s answered two different ways" % request)


func test_a_run_lands_where_the_request_says() -> void:
	var setup := RunSetup.new()
	setup.seed_value = SEED
	setup.request = SiteRequest.ECONOMIC_OPPORTUNITY

	var run := RunState.from_setup(setup)
	assert_eq(run.starting_site,
		SiteRequest.choose(_map(SEED), SiteRequest.ECONOMIC_OPPORTUNITY),
		"the run landed somewhere other than where it asked for")
	assert_eq(run.colony.in_order()[0].at, run.starting_site,
		"the first town is not on the chosen ground")


func test_two_requests_on_one_seed_are_two_different_runs() -> void:
	var growth := RunSetup.new()
	growth.seed_value = SEED
	growth.request = SiteRequest.QUICK_GROWTH
	var trade := RunSetup.new()
	trade.seed_value = SEED
	trade.request = SiteRequest.ECONOMIC_OPPORTUNITY

	assert_ne(RunState.from_setup(growth).starting_site,
		RunState.from_setup(trade).starting_site,
		"the same world answered two different purposes identically")
