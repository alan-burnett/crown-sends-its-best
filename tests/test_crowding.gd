extends TestCase

## Crowding is mouths against **land**, not against influence (#321,
## `docs/mechanics/founding-towns.md` §2, `docs/mechanics/immigration.md` §10).
##
## 🔒 **It had never been anything but exactly zero.** Peak weight `0.0000`
## across 576 scorings, in the same column that showed `room_to_grow` and
## `food_security` doing real work — and not because a milestone was missing. It
## could not reach a non-zero value at any population the game produces.
##
## Influence grows as `1 + population / 12` rings capped at four, so a town of
## thirty-six already commands eighty-one tiles and every further person only
## lowers the ratio. **Sea and ocean counted as ground the town could work.**
##
## 🔒 **And it is the one motive without a floor.** §2: `room_to_grow` alone
## cannot fire in a one-town colony, because one town never sees enough unclaimed
## land to justify leaving. Crowding was the answer to that chicken and egg, and
## it was not answering.

const SEED: int = 4471

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


## A deliberation context over a town whose reach is `land` land tiles and
## `water` water ones.
func _context_for(people: int, land: int, water: int) -> DeliberationContext:
	var run := RunState.new_run(SEED)
	var town: Town = run.colony.in_order()[0]
	# Fixture sizes are in thousands (#426).
	town.workers = people * Population.THOUSAND
	town.experts = {}

	# A reach built by hand, so the only thing under test is what is counted.
	var territory := Territory.new()
	var at := Vector2i(0, 0)
	var placed := 0
	for step in land + water:
		while true:
			at = Vector2i(placed % run.map.width, int(placed / run.map.width))
			placed += 1
			var terrain := Terrain.find(run.map.terrain_at(at.x, at.y))
			if terrain == null:
				continue
			if terrain.land == (step < land):
				break
			if placed > run.map.width * run.map.height:
				return null
		territory.influence[at] = town.id

	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, run.world, run.log)
	context.data = {
		"town": town, "colony": run.colony, "map": run.map, "territory": territory,
	}
	return context


# --- 🔒 Sea is not fields ---------------------------------------------------

func test_water_in_the_reach_does_not_make_a_town_roomier() -> void:
	# The bug. The same forty people with the same ten fields, differing only in
	# how much ocean the town happens to look out over.
	var inland := IntentConsiderations.crowding_of(_context_for(40, 10, 0))
	var coastal := IntentConsiderations.crowding_of(_context_for(40, 10, 60))
	assert_almost_eq(inland, coastal, 0.0001,
		"sixty tiles of water made a town of forty on ten fields less crowded")
	assert_true(inland > 0.0,
		"forty people on ten fields is not crowded, so the measure means nothing")


func test_a_town_with_no_land_at_all_is_as_crowded_as_it_gets() -> void:
	# One really existed: five tiles of influence and not one of them land.
	assert_eq(IntentConsiderations.crowding_of(_context_for(60, 0, 5)), 1.0,
		"a town whose whole reach is water has room to spare")


func test_a_town_with_nobody_left_and_nowhere_left_is_still_a_number() -> void:
	# Dividing by nought gives `inf`, which clamps to 1.0 and looks harmless. But
	# a town that has lost its last man **as well as** its last field divides
	# nought by nought, and that is a NaN — which `balance.gd` treats as a failed
	# run, correctly. The guard is what stops a crowded town reading as a broken
	# seed.
	var crowding := IntentConsiderations.crowding_of(_context_for(0, 0, 4))
	assert_false(is_nan(crowding), "an empty town on no land scored NaN")
	assert_eq(crowding, 1.0, "an empty town on no land is not as crowded as it gets")


func test_room_to_spare_still_reads_as_no_opinion() -> void:
	# 🔒 Every score is in [-1, +1] and neutral is 0.0, so a consideration with
	# nothing to say contributes nothing rather than quietly suppressing an intent.
	assert_eq(IntentConsiderations.crowding_of(_context_for(10, 80, 0)), 0.0,
		"ten people on eighty fields were reckoned crowded")


func test_it_climbs_with_the_mouths_and_falls_with_the_fields() -> void:
	var sparse := IntentConsiderations.crowding_of(_context_for(40, 30, 0))
	var tight := IntentConsiderations.crowding_of(_context_for(40, 12, 0))
	var tighter := IntentConsiderations.crowding_of(_context_for(90, 12, 0))
	assert_true(tight > sparse, "the same people on fewer fields were no more crowded")
	assert_true(tighter > tight, "more people on the same fields were no more crowded")
	assert_true(tighter <= 1.0, "crowding ran past the top of its range")


func test_building_out_the_reach_is_still_a_way_out_of_leaving() -> void:
	# 🔒 The property the class docstring keeps: **the expansion branch lowers
	# crowding by raising influence**, so a town can build its way out of needing
	# to leave and guard towers are a real alternative to a daughter town. That
	# survives counting land, because the land arrives with the rings.
	var cramped := IntentConsiderations.crowding_of(_context_for(60, 12, 0))
	var grown := IntentConsiderations.crowding_of(_context_for(60, 40, 0))
	assert_true(grown < cramped,
		"widening the town's reach did nothing for how crowded it felt")


# --- 🔒 The motive without a floor ------------------------------------------

func test_a_crowded_town_argues_for_settling_and_against_sending_for_more() -> void:
	var context := _context_for(90, 12, 0)
	var crowding := IntentConsiderations.Crowding.new()
	var pressure := IntentConsiderations.crowding_of(context)
	assert_true(pressure > 0.0, "the fixture is not crowded")

	assert_almost_eq(
		crowding.score(null, Candidate.new(GovernorIntent.SETTLEMENT), context),
		pressure, 0.0001, "a crowded town does not argue for settling")
	assert_almost_eq(
		crowding.score(null, Candidate.new(GovernorIntent.POPULATION), context),
		-pressure, 0.0001,
		"a man watching his town outgrow its fields answered by sending for more people")


func test_a_one_town_colony_can_want_to_settle_on_crowding_alone() -> void:
	# 🔒 §2's chicken and egg: `room_to_grow` returns `room * 2 - 1` for settling,
	# which is **negative** while a colony has seen little unclaimed land — so the
	# first daughter town could never be founded on that motive. Crowding is the
	# answer, and it can only answer if it is not nought.
	var context := _context_for(90, 12, 0)
	var settle := Candidate.new(GovernorIntent.SETTLEMENT)
	var from_room := IntentConsiderations.RoomToGrow.new().score(null, settle, context)
	var from_crowding := IntentConsiderations.Crowding.new().score(null, settle, context)

	assert_true(from_crowding > 0.0,
		"crowding says nothing about settling, so there is one motive and not two")
	assert_true(from_room < 0.0,
		"the fixture's colony has seen land, so room is not the floor this is about")

	# 🔒 **The two are exactly matched at the extremes** — room bottoms at -1 and
	# crowding tops at +1 — so raw they can only tie. **The weights are what
	# decide**, which is the whole reason §2 wants two considerations rather than
	# one blended term: two weights make **two kinds of governor**, the ambitious
	# man who settles because there is land and the pragmatic one who settles
	# because there are too many mouths.
	var pragmatic := 1.5 * from_crowding + 0.5 * from_room
	var ambitious := 0.5 * from_crowding + 1.5 * from_room
	assert_true(pragmatic > 0.0,
		"a governor who minds crowded fields still had no reason to send anybody out: "
			+ "room %.2f, crowding %.2f" % [from_room, from_crowding])
	assert_true(ambitious < 0.0,
		"a governor who only wants elbow room wanted to settle in a colony "
			+ "that has seen nowhere to go")


# --- 🔒 Two kinds of expedition ---------------------------------------------

func test_a_poor_town_and_a_prosperous_one_send_out_different_expeditions() -> void:
	# §2: one objective produces both kinds — a prosperous town sets a grand
	# target and a crowded poor one sets almost nothing. The people are a share of
	# the town either way; **what differs is what they carry.**
	var run := RunState.new_run(SEED)
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony

	var poor: Town = run.colony.in_order()[0]
	poor.workers = 60_000
	for resource in ResourceCatalogue.ids():
		poor.store(StringName(resource), 0.0)

	var rich := Town.new(&"rich", "Rich", Vector2i(12, 12))
	rich.workers = 60_000
	for resource in ResourceCatalogue.ids():
		rich.store(StringName(resource), 400.0)

	assert_eq(Expedition.people_for(poor), Expedition.people_for(rich),
		"the two fixtures differ in their people as well as their stores")

	var thin := Expedition.cargo_for(poor, context)
	var grand := Expedition.cargo_for(rich, context)
	var carried := 0.0
	for resource in grand:
		carried += float(grand[resource])
	assert_true(carried > 0.0, "the prosperous town sent its people out with nothing")
	assert_true(thin.size() < grand.size(),
		"a town with empty stores outfitted its expedition as well as a full one: "
			+ "%d kinds against %d" % [thin.size(), grand.size()])
