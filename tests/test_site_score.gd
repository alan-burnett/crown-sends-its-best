extends TestCase

## An expedition's site is scored by its ground and its distance from other
## towns (#433, `docs/mechanics/founding-towns.md` §5, the Author's ruling on
## #422).
##
##     site = ( 2 × total yield of the tiles within 1
##              + total yield of the other tiles within 3 ) × closeness
##
## with every tile's yield discounted for native land by the sending intent's
## aversion.

const SEED: int = 433

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


## Plains from edge to edge, with ocean round the rim.
func _plains(width: int = 32, height: int = 22) -> WorldMap:
	var map := WorldMap.new(width, height, &"ocean")
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			map.set_terrain(x, y, &"plains")
	return map


func _colony(at: Vector2i, people: int = 1_000) -> Colony:
	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", at)
	town.workers = people
	colony.add(town)
	return colony


func _village(at: Vector2i) -> Tribes:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = tribe.id
	village.at = at
	village.people = 30
	natives.villages.append(village)
	return natives


# --- 🔒 Closeness ------------------------------------------------------------------

func test_of_two_sites_on_equal_ground_the_one_six_tiles_from_a_town_wins() -> void:
	var map := _plains()
	var colony := _colony(Vector2i(6, 10))
	var near := Vector2i(9, 10)    # three tiles off
	var far := Vector2i(12, 10)    # six
	assert_almost_eq(SitePreference.total_yield(near, map), SitePreference.total_yield(far, map), 0.0001)
	assert_true(SitePreference.site_score(far, map, colony) > SitePreference.site_score(near, map, colony),
		"a site three tiles from a town outscored one six away on the same ground")

	# And the pick itself: of a region spanning both, the choice stands clear of
	# the town's crowding.
	var chosen := SitePreference.site_in(Vector2i(10, 10), SitePreference.GOOD_GROUND, map, colony)
	assert_true(maxi(absi(chosen.x - 6), absi(chosen.y - 10)) > 4,
		"he settled at %s, crowding a town on equal ground" % [chosen])


func test_closeness_reads_towns_by_ring_distance() -> void:
	var colony := _colony(Vector2i(10, 10))
	assert_almost_eq(SitePreference.closeness(Vector2i(13, 13), colony), 0.2, 0.0001)
	assert_almost_eq(SitePreference.closeness(Vector2i(14, 10), colony), 0.75, 0.0001)
	assert_almost_eq(SitePreference.closeness(Vector2i(15, 10), colony), 1.0, 0.0001)
	assert_almost_eq(SitePreference.closeness(Vector2i(15, 10), null), 1.0, 0.0001)


func test_the_near_ground_counts_double() -> void:
	# One rich tile beside the site is worth twice the same tile three out.
	var map := _plains()
	var at := Vector2i(12, 10)
	var plain := SitePreference.site_score(at, map)
	map.set_terrain(13, 10, &"forest")
	var beside := SitePreference.site_score(at, map) - plain
	map.set_terrain(13, 10, &"plains")
	map.set_terrain(15, 10, &"forest")
	var beyond := SitePreference.site_score(at, map) - plain
	assert_true(beyond > 0.0, "the fixture's forest yields no more than plains")
	assert_almost_eq(beside, 2.0 * beyond, 0.0001)


# --- 🔒 Native land, by the sending intent's aversion (§8) ------------------------

func test_a_thick_expedition_keeps_off_native_land_where_a_lean_one_may_not() -> void:
	# The tribe's country is forest, richer than the plains beside it. Go tall
	# (aversion one) takes the plains; go wide (0.3) is drawn onto their land.
	var map := _plains()
	for y in range(6, 15):
		for x in range(17, 26):
			map.set_terrain(x, y, &"forest")
	var natives := _village(Vector2i(21, 10))
	var region := Vector2i(17, 10)
	var thick := SitePreference.site_in(region, SitePreference.GOOD_GROUND, map, null, natives,
		AgendaMenu.aversion_of(GovernorIntent.GO_TALL))
	var lean := SitePreference.site_in(region, SitePreference.GOOD_GROUND, map, null, natives,
		AgendaMenu.aversion_of(GovernorIntent.GO_WIDE))
	assert_true(Intrusion.depth_at(lean, natives) > Intrusion.depth_at(thick, natives),
		"a lean expedition was no bolder about their land than a thick one: %s against %s" % [lean, thick])
	assert_true(Intrusion.depth_at(thick, natives) <= 0.2,
		"a thick expedition settled deep in their land at %s with plains beside it" % [thick])


func test_the_party_carries_the_aversion_of_the_intent_that_sent_it() -> void:
	for pair in [[GovernorIntent.GO_TALL, &"thick_expedition"], [GovernorIntent.GO_WIDE, &"lean_expedition"]]:
		var town := Town.new(&"ashmere", "Ashmere", Vector2i(6, 10))
		town.workers = 10_000
		town.intent = pair[0]
		town.objective = pair[1]
		town.objective_intent = pair[0]
		var colony := Colony.new()
		colony.add(town)
		var map := _plains()
		var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
		context.colony = colony
		context.territory = Territory.compute(map, colony.in_order())
		var party := Expedition.launch(town, context)
		assert_almost_eq(party.aversion, AgendaMenu.aversion_of(pair[0]), 0.0001,
			"an expedition from a %s town carried the wrong aversion" % pair[0])


# --- 🔒 The region: the best site the colony has seen ------------------------------

func test_the_region_is_the_best_explored_site_and_nothing_unseen() -> void:
	var map := _plains()
	# A rich valley to the east nobody has walked, and a modest one to the west
	# that the colony has seen.
	for y in range(8, 13):
		for x in range(24, 29):
			map.set_terrain(x, y, &"forest")
	for y in range(8, 11):
		for x in range(2, 5):
			map.set_terrain(x, y, &"forest")
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(14, 10))
	town.workers = 1_000
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	context.knowledge = MapKnowledge.new()
	for y in range(1, 21):
		for x in range(1, 20):
			context.knowledge.reveal_around(map, Vector2i(x, y), 0, null, 0)

	var region := Expedition.region_for(town, context)
	assert_true(region.x < 20, "he set out for country nobody has seen: %s" % [region])
	assert_false(SitePreference.inside_a_town(region, colony), "he set out for his own town's ground")
	assert_true(region.x <= 8, "he passed over the best ground the colony had seen: %s" % [region])


func test_no_site_and_no_region_lies_inside_a_towns_ground() -> void:
	# §5: candidates are land outside every town's influence. An island that is
	# all one town's ground has nowhere to found another, however good the soil.
	var map := WorldMap.new(24, 22, &"ocean")
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(10, 10))
	town.workers = 40_000
	var reach := Territory.reach_of(town)
	for y in range(10 - reach, 11 + reach):
		for x in range(10 - reach, 11 + reach):
			map.set_terrain(x, y, &"forest")
	var colony := Colony.new()
	colony.add(town)
	assert_eq(SitePreference.site_in(Vector2i(12, 10), SitePreference.GOOD_GROUND, map, colony),
		Vector2i(-1, -1), "a site was found on the town's own ground")

	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	context.knowledge = MapKnowledge.new()
	for y in map.height:
		for x in map.width:
			context.knowledge.reveal_around(map, Vector2i(x, y), 0, null, 0)
	assert_false(SitePreference.inside_a_town(Expedition.region_for(town, context), colony),
		"an expedition set out for its own town's ground")


# --- 🔒 Deterministic, and it survives the crossing -----------------------------------

func test_the_same_map_region_and_preference_give_the_same_site_across_a_save() -> void:
	var map := _plains()
	for y in range(6, 15):
		for x in range(17, 26):
			map.set_terrain(x, y, &"forest")
	var natives := _village(Vector2i(21, 10))
	var party := ExpeditionParty.new()
	party.id = &"expedition_test"
	party.people = 2_000
	party.at = Vector2i(10, 10)
	party.region = Vector2i(17, 10)
	party.aversion = 1.0
	var first := party.settle_destination(map, null, natives)
	assert_eq(party.settle_destination(map, null, natives), first)

	# The aversion is what it settles by: the same party minding nobody's land
	# goes elsewhere.
	var careless := ExpeditionParty.from_dict(party.to_dict())
	careless.aversion = 0.0
	assert_ne(careless.settle_destination(map, null, natives), first,
		"a party's aversion changed nothing about where it settled")

	var reloaded := ExpeditionParty.from_dict(party.to_dict())
	assert_almost_eq(reloaded.aversion, 1.0, 0.0001, "the aversion was lost mid-crossing")
	assert_eq(reloaded.settle_destination(map, null, natives), first,
		"a save made mid-crossing founds somewhere else")
