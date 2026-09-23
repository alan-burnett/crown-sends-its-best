extends TestCase

## Villages grow rather than multiply (#205, SPEC §12.5, §11.1;
## `docs/mechanics/natives.md` §4).
##
## 🔒 **A tribe never founds a village.** The map's villages are the map's
## villages, fixed at generation. They grow in place — in population, and in
## influence, the land they work — which is what keeps tribes full actors rather
## than a diminishing obstacle.
##
## 🔒 **No buildings, no governor, no contact, no intent.** A town needs a
## governor's intent because a governor is a person with his own opinion who may
## be wrong; a tribe's situation is its own intent, and it is never wrong about
## what is happening to it.
##
## 🔒 **Who works a contested tile is not settled here** (`natives.md` §10). The
## tests below assert that both claims are *visible* and deliberately assert
## nothing about which wins.

const SEED: int = 3311

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


func _context(map: WorldMap = null) -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)


func _tribe(toward_colony: float = 70.0) -> Tribe:
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): toward_colony}
	return tribe


## A run at the desk, ready to send month after month.
func _playing(seed_value: int = SEED) -> Dictionary:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	return {"run": run, "machine": machine}


func _advance(playing: Dictionary, months: int) -> void:
	var machine: TurnMachine = playing["machine"]
	var run: RunState = playing["run"]
	for _month in months:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()


func _village(people: int = 30) -> Village:
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = &"tribe_test"
	village.at = Vector2i(10, 10)
	village.people = people
	village.stores = {"food": float(people) * 4.0}
	return village


# --- 🔒 They exist from mapgen, and their number never changes --------------

func test_villages_exist_from_the_first_month() -> void:
	var run := RunState.new_run(SEED)
	# **Written out rather than compared against the constant.** Six is three
	# peoples with two settlements each; asserting against `VILLAGES_EACH` would
	# assert that the constant equals itself, which is true however wrong it is.
	assert_eq(run.tribes.villages_in_order().size(), 6,
		"the three peoples were living nowhere in particular")
	for tribe in run.tribes.in_order():
		assert_eq(run.tribes.villages_of(tribe.id).size(), 2,
			"a people with no village of its own")


func test_every_village_stands_on_land_with_people_in_it() -> void:
	var run := RunState.new_run(SEED)
	for village in run.tribes.villages_in_order():
		var at: Vector2i = (village as Village).at
		assert_true(run.map.is_land(at.x, at.y),
			"a village was put in the sea at %d,%d" % [at.x, at.y])
		assert_true((village as Village).people > 0, "an empty village")
		assert_true(String((village as Village).tribe).begins_with("tribe_"),
			"a village belonging to nobody")


func test_no_village_stands_on_the_colonys_doorstep() -> void:
	# A tribe whose village the colony was founded on top of would be a tribe the
	# run had already decided about, before the player wrote a word.
	var run := RunState.new_run(SEED)
	for village in run.tribes.villages_in_order():
		assert_true((village as Village).at.distance_squared_to(run.starting_site) >= 36,
			"the first town was founded in somebody's front garden")


func test_the_same_seed_puts_them_in_the_same_places() -> void:
	var once := RunState.new_run(SEED).tribes.villages_in_order()
	var twice := RunState.new_run(SEED).tribes.villages_in_order()
	assert_eq(once.size(), twice.size())
	for index in once.size():
		assert_eq((once[index] as Village).at, (twice[index] as Village).at,
			"the same seed moved a village")
		assert_eq((once[index] as Village).people, (twice[index] as Village).people,
			"the same seed changed how many lived there")


func test_a_different_seed_is_a_different_country() -> void:
	var here := RunState.new_run(SEED).tribes.villages_in_order()
	var elsewhere := RunState.new_run(SEED + 4_513).tribes.villages_in_order()
	var same := 0
	for index in mini(here.size(), elsewhere.size()):
		if (here[index] as Village).at == (elsewhere[index] as Village).at:
			same += 1
	assert_true(same < here.size(),
		"two unrelated seeds settled every village on the same tile")


func test_a_year_of_living_founds_nothing() -> void:
	# 🔒 The acceptance criterion, run rather than read: **no code path founds a
	# village.** A year of months through the real turn loop, and the list is the
	# list generation made.
	var playing := _playing()
	var run: RunState = playing["run"]
	var before := run.tribes.villages.size()
	var sites: Array = []
	for village in run.tribes.villages_in_order():
		sites.append((village as Village).at)

	_advance(playing, 12)

	assert_eq(run.tribes.villages.size(), before,
		"a village came into being somewhere in a year of world months")
	var after: Array = []
	for village in run.tribes.villages_in_order():
		after.append((village as Village).at)
	assert_eq(after, sites, "a village moved house")


# --- 🔒 They grow in place, in people and in influence ----------------------

func test_a_village_grows_in_population_over_a_run() -> void:
	var playing := _playing()
	var run: RunState = playing["run"]
	var before: Array = []
	for village in run.tribes.villages_in_order():
		before.append((village as Village).people)

	_advance(playing, 36)

	var grew := 0
	for index in run.tribes.villages_in_order().size():
		if (run.tribes.villages_in_order()[index] as Village).people > int(before[index]):
			grew += 1
	assert_true(grew > 0,
		"three years passed and not one village had a child in it")


func test_influence_follows_the_people_and_nothing_else() -> void:
	# A village presses outward because it has mouths to feed, not because it
	# decided to. Nothing in the file sets reach directly and this is why.
	var small := _village(4)
	var large := _village(200)
	assert_eq(small.influence(), Village.INFLUENCE_MIN,
		"a hamlet of four commanded the country")
	assert_eq(large.influence(), Village.INFLUENCE_MAX,
		"a village of two hundred worked one ring of fields")
	assert_true(_village(60).influence() > small.influence(),
		"growing changed nothing about the ground they work")


func test_growing_past_a_ring_is_on_the_record() -> void:
	# 🔒 Seam A. The event the map reads to draw the contest — a village that
	# spread and emitted nothing would leave the map drawing last month's border.
	var village := _village(Village.MOUTHS_PER_REACH as int - 1)
	village.growth_accrued = 0.999
	village.stores = {"food": 9_000.0}
	var context := _context()
	village.live(_tribe(), context)

	assert_eq(context.log.of_type(Village.EVENT_GREW).size(), 1,
		"a child was born in silence")
	var spread: Array = context.log.of_type(Village.EVENT_SPREAD)
	assert_eq(spread.size(), 1, "the village worked new ground and told nobody")
	assert_eq(int(spread[0].payload["reach"]), village.influence())
	assert_true(int(spread[0].payload["was"]) < int(spread[0].payload["reach"]),
		"the map was told the border had shrunk")


func test_a_village_that_has_not_crossed_a_ring_says_nothing_about_ground() -> void:
	var village := _village(2)
	village.growth_accrued = 0.999
	village.stores = {"food": 9_000.0}
	var context := _context()
	village.live(_tribe(), context)

	assert_eq(context.log.of_type(Village.EVENT_GREW).size(), 1,
		"a child was born in silence")
	assert_eq(context.log.of_type(Village.EVENT_SPREAD).size(), 0,
		"one more child moved the border")


func test_a_village_with_nothing_to_eat_loses_one_person_and_only_one() -> void:
	# `CLAUDE.md`: no single event ever costs a settlement more than one
	# population. A village is a settled population going about its business and
	# the rule is exactly about that.
	var village := _village(40)
	village.stores = {"food": 0.0}
	village.live(_tribe(), _context())
	assert_eq(village.people, 39, "a hungry month emptied the place")


# --- 🔒 Objectives, and no layer a town has ---------------------------------

func test_a_village_always_holds_one_of_the_five_objectives() -> void:
	for standing in [0.0, 15.0, 30.0, 45.0, 90.0]:
		var village := _village()
		village.decide(_tribe(float(standing)), 6.0, _context())
		assert_true(Village.OBJECTIVES.has(village.objective),
			"a village at standing %s was doing something unnameable" % standing)


func test_the_tribes_standing_is_the_only_thing_steering_it() -> void:
	# 🔒 §4: what steers a village is the tribe's standings. A tribe that believes
	# itself threatened takes defensive objectives; one that is secure takes
	# prosperous ones — and nothing about the village itself changes that.
	var frightened := _village()
	frightened.decide(_tribe(Village.FRIGHTENED_BELOW - 1.0), 6.0, _context())
	assert_eq(frightened.objective, Village.ARM_OURSELVES,
		"a people who thought the colony meant them harm went on planting")

	var uneasy := _village()
	uneasy.decide(_tribe(Village.UNEASY_BELOW - 1.0), 6.0, _context())
	assert_eq(uneasy.objective, Village.WORK_MORE_LAND)

	var at_ease := _village()
	at_ease.decide(_tribe(85.0), 6.0, _context())
	assert_eq(at_ease.objective, Village.GROW,
		"a people with nothing to fear were still arming")


func test_hunger_comes_before_everything_including_the_colony() -> void:
	# A hungry people has one question, and it is not about the colony.
	var starving := _village()
	starving.decide(_tribe(5.0), Village.HUNGRY_BELOW - 0.1, _context())
	assert_eq(starving.objective, Village.FEED_OURSELVES,
		"a village with two weeks of food in it went to war instead")


func test_a_people_who_have_concluded_do_not_go_back_to_farming() -> void:
	# 🔒 The latch (§2). Past the point of no return there is nothing left to
	# discuss, and what a village does about that is not a mood.
	var tribe := _tribe(60.0)
	tribe.irreconcilable[String(Tribe.COLONY)] = true
	var village := _village()
	village.decide(tribe, 6.0, _context())
	assert_eq(village.objective, Village.DRIVE_THEM_OFF,
		"a people who had concluded the colony meant them destroyed took up the plough")


func test_taking_up_an_objective_is_on_the_record() -> void:
	var village := _village()
	village.objective = Village.GROW
	var context := _context()
	village.decide(_tribe(5.0), 6.0, context)

	var taken: Array = context.log.of_type(Village.EVENT_OBJECTIVE)
	assert_eq(taken.size(), 1, "a village changed its whole purpose in silence")
	assert_eq(String(taken[0].payload["was"]), String(Village.GROW))
	assert_eq(String(taken[0].payload["now"]), String(Village.ARM_OURSELVES))

	var again := _context()
	village.decide(_tribe(5.0), 6.0, again)
	assert_eq(again.log.of_type(Village.EVENT_OBJECTIVE).size(), 0,
		"a village carrying on as before announced it")


func test_no_village_holds_a_building_or_an_intent() -> void:
	# 🔒 §4, and the reason a village needs no layer a town needs. Asserted on the
	# object rather than in prose, so a dev who adds either finds out here.
	var fields: Dictionary = {}
	for entry in Village.new().get_property_list():
		fields[String(entry["name"])] = true
	for forbidden in ["intent", "intent_since", "buildings", "building", "governor", "contact"]:
		assert_false(fields.has(forbidden),
			"a village grew a %s, which is a town's problem and not a tribe's" % forbidden)

	var run := RunState.new_run(SEED)
	for village in run.tribes.villages_in_order():
		assert_false((village as Village).to_dict().has("intent"),
			"a village saved an intent")
		assert_false((village as Village).to_dict().has("buildings"),
			"a village saved a building")


func test_no_village_is_a_contact() -> void:
	# 🔒 §1. They have not heard of the PC, so there is nobody to write to.
	var run := RunState.new_run(SEED)
	var roster: Dictionary = {}
	for id in run.contact_ids():
		roster[String(id)] = true
	for village in run.tribes.villages_in_order():
		assert_false(roster.has(String((village as Village).id)),
			"a village turned up on the roster of people who write to the PC")
		assert_false(roster.has(String((village as Village).tribe)),
			"a people who have never heard of the PC are writing to him")


# --- 🔒 The contest is visible, and nothing here resolves it ----------------

func test_a_villages_influence_can_reach_a_tile_a_town_wants() -> void:
	var village := _village(200)
	assert_eq(village.influence(), Village.INFLUENCE_MAX)
	assert_true(village.holds(village.at + Vector2i(Village.INFLUENCE_MAX, 0)),
		"a village of two hundred did not work the field at the end of its own street")
	assert_false(village.holds(village.at + Vector2i(Village.INFLUENCE_MAX + 1, 0)),
		"a village worked ground beyond any reach it claims")


func test_the_map_is_told_which_people_work_a_tile_it_can_see() -> void:
	# The acceptance criterion: the contest is visible on the map. Visible
	# **through `MapKnowledge`**, which is the only thing presentation may read.
	var run := RunState.new_run(SEED)
	var village: Village = run.tribes.villages_in_order()[0]
	# Put a village where the first town can see it, and recompute what the
	# colony knows the way phase 3 does.
	village.at = run.colony.in_order()[0].at + Vector2i(1, 0)
	village.people = 200
	var territory := Territory.compute(run.map, run.colony.in_order())
	run.knowledge.observe(run.map, territory, 1, run.colony.in_order(), run.tribes)

	var tribe := run.tribes.find(village.tribe)
	assert_eq(run.knowledge.village_at(village.at), tribe.display_name,
		"the colony stood next door to a village and did not see it")
	assert_eq(run.knowledge.native_at(village.at), tribe.display_name,
		"the map was not told whose ground it was")
	assert_true(run.knowledge.is_contested(village.at),
		"a tile a town works and a village holds was reported as nobody's quarrel")


func test_ground_nobody_has_walked_to_keeps_its_villages_secret() -> void:
	# 🔒 SPEC §11.2. The whole reason `MapKnowledge` exists: a screen that read
	# `Tribes` would draw every village in the country on turn one.
	var run := RunState.new_run(SEED)
	var hidden := 0
	for village in run.tribes.villages_in_order():
		if not run.knowledge.in_sight.has((village as Village).at):
			assert_eq(run.knowledge.village_at((village as Village).at), "",
				"the map knew about a village nobody has walked to")
			hidden += 1
	assert_true(hidden > 0,
		"the colony could see every village in the country from its first town")


func test_the_map_reports_the_contest_and_refuses_to_settle_it() -> void:
	# 🔒 `natives.md` §10 leaves who actually works a contested tile to the
	# Author. Both claims survive being recorded, which is the whole of what this
	# ticket may say about it.
	var run := RunState.new_run(SEED)
	var town: Town = run.colony.in_order()[0]
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = town.at + Vector2i(1, 0)
	village.people = 200
	var territory := Territory.compute(run.map, run.colony.in_order())
	run.knowledge.observe(run.map, territory, 1, run.colony.in_order(), run.tribes)

	assert_eq(String(run.knowledge.worked_by(town.at)), String(town.id),
		"the town lost its own tile to the neighbours")
	assert_false(run.knowledge.native_at(town.at).is_empty(),
		"the village's claim on the same tile was dropped")
	# And the sim still gives the town every tile its territory says it works:
	# nothing here took one away, because nothing here is entitled to.
	assert_true(territory.tiles_of(town.id).size() > 0,
		"something decided the contest, which is the Author's to decide")


# --- The save ----------------------------------------------------------------

func test_the_villages_survive_a_save() -> void:
	var run := RunState.new_run(SEED)
	var village: Village = run.tribes.villages_in_order()[0]
	village.people = 137
	village.objective = Village.ARM_OURSELVES
	village.stores = {"food": 412.5}
	village.growth_accrued = 0.75

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.tribes.villages_in_order().size(),
		run.tribes.villages_in_order().size(), "a village vanished in the save")
	var same: Village = restored.tribes.villages_in_order()[0]
	assert_eq(same.id, village.id)
	assert_eq(same.at, village.at, "a reload moved a village")
	assert_eq(same.people, 137, "a reload emptied a village")
	assert_eq(same.objective, Village.ARM_OURSELVES,
		"a reload talked them out of arming")
	assert_almost_eq(float(same.stores.get("food", 0.0)), 412.5, 0.0001)
	assert_almost_eq(same.growth_accrued, 0.75, 0.0001)
	assert_eq(same.influence(), village.influence(),
		"a reload changed the ground they work")


func test_what_the_map_remembers_of_them_survives_a_save() -> void:
	var run := RunState.new_run(SEED)
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = run.colony.in_order()[0].at + Vector2i(1, 0)
	village.people = 200
	run.knowledge.observe(
		run.map, Territory.compute(run.map, run.colony.in_order()), 1,
		run.colony.in_order(), run.tribes)

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.knowledge.village_at(village.at),
		run.knowledge.village_at(village.at),
		"a reload forgot the village next door")
	assert_eq(restored.knowledge.native_at(village.at),
		run.knowledge.native_at(village.at),
		"a reload forgot whose ground it was")
