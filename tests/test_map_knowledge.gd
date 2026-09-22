extends TestCase

## What the colony knows, and what the map may therefore draw (#55, SPEC §11.2).
##
## **No tests on the view itself.** CLAUDE.md rules those out, and the seam that
## actually matters is enforced by `tools/lint.gd`: nothing under `presentation/`
## may mention `WorldMap`, `Territory` or `MapGenerator`. What is worth locking
## is that this object can answer everything a map needs, so nothing is ever
## tempted to reach past it.

const SEED: int = 1649


func before_each() -> void:
	Terrain.reset()
	Improvement.reset()
	Terrain.load_from([
		{"id": "ocean", "name": "ocean", "land": false, "colour": "#123456"},
		{"id": "plains", "name": "plains", "land": true, "colour": "#abcdef",
		 "yields": {"food": "high"}},
		{"id": "forest", "name": "forest", "land": true, "colour": "#0f2f0f",
		 "yields": {"wood": "high"}},
	], {"low": 1.0, "medium": 3.0, "high": 6.0})


func after_each() -> void:
	Terrain.reset()
	Improvement.reset()


func _world() -> Dictionary:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_terrain(x, y, &"plains" if x <= 4 else &"forest")

	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = 8
	colony.add(town)

	return {
		"map": map,
		"colony": colony,
		"town": town,
		"territory": Territory.compute(map, colony.in_order()),
	}


func _knowing(world: Dictionary, month: int = 1) -> MapKnowledge:
	var knowledge := MapKnowledge.new()
	knowledge.observe(world["map"], world["territory"], month, world["colony"].in_order())
	return knowledge


# --- 🔒 Only what the colony knows ------------------------------------------

func test_unexplored_ground_answers_nothing_at_all() -> void:
	# **Not a grey tile: no tile.** A caller that wants the truth about ground
	# nobody has walked is asking the wrong object, and M5 puts tribes on that
	# ground.
	var knowledge := _knowing(_world())
	var far := Vector2i(80, 80)

	assert_eq(String(knowledge.state_of(far)), String(MapKnowledge.UNEXPLORED))
	assert_false(knowledge.is_explored(far))
	assert_eq(String(knowledge.terrain_at(far)), "")
	assert_eq(String(knowledge.improvement_at(far)), "")
	assert_false(knowledge.inside_border(far))
	assert_eq(String(knowledge.worked_by(far)), "")
	assert_eq(knowledge.town_at(far), "")


func test_the_three_states_are_distinguishable() -> void:
	# Unexplored, remembered and in sight have to be tellable apart, or the map
	# cannot draw the difference and the player cannot feel it.
	var world := _world()
	var knowledge := _knowing(world)
	var seen_tile: Vector2i = knowledge.explored()[0]

	assert_eq(String(knowledge.state_of(seen_tile)), String(MapKnowledge.IN_SIGHT))

	# The colony looks away: vision moves on, memory does not.
	knowledge.in_sight = {}
	assert_eq(String(knowledge.state_of(seen_tile)), String(MapKnowledge.REMEMBERED))
	assert_true(knowledge.is_explored(seen_tile), "it forgot ground it had walked")
	assert_eq(String(knowledge.state_of(Vector2i(80, 80))), String(MapKnowledge.UNEXPLORED))


func test_remembered_ground_is_as_last_seen_and_not_as_it_is() -> void:
	# **That it may be out of date is the point** (SPEC §11.2).
	var world := _world()
	var knowledge := _knowing(world)
	var at: Vector2i = Vector2i(3, 3)
	assert_eq(String(knowledge.terrain_at(at)), "plains")

	# The world changes behind the colony's back.
	world["map"].set_terrain(at.x, at.y, &"forest")
	knowledge.in_sight = {}

	assert_eq(String(knowledge.terrain_at(at)), "plains",
		"the map told the truth about ground nobody was looking at")


# --- Everything a map needs -------------------------------------------------

func test_it_knows_its_own_towns_borders_and_worked_ground() -> void:
	var world := _world()
	var knowledge := _knowing(world)
	var town: Town = world["town"]

	assert_eq(knowledge.town_at(town.at), "Ashmere")
	assert_eq(String(knowledge.worked_by(town.at)), String(town.id))

	var bordered := 0
	for at in knowledge.explored():
		if knowledge.inside_border(at):
			bordered += 1
	assert_true(bordered > 0, "the colony does not know where its own border is")


func test_a_town_outside_vision_is_not_drawn() -> void:
	var world := _world()
	var knowledge := MapKnowledge.new()
	var elsewhere := Town.new(&"faraway", "Faraway", Vector2i(80, 80))
	world["colony"].add(elsewhere)

	knowledge.observe(world["map"], world["territory"], 1, world["colony"].in_order())
	assert_eq(knowledge.town_at(Vector2i(80, 80)), "",
		"a town nobody can see was put on the map")


func test_explored_comes_back_in_a_stable_order() -> void:
	var knowledge := _knowing(_world())
	var first := knowledge.explored()
	assert_not_empty(first)
	for _attempt in 3:
		assert_eq(knowledge.explored(), first, "the map would draw in a different order")

	for index in range(1, first.size()):
		var previous: Vector2i = first[index - 1]
		var current: Vector2i = first[index]
		assert_true(previous.y < current.y or (previous.y == current.y and previous.x < current.x),
			"the order is not north-west first")


func test_bounds_cover_what_has_been_seen_and_nothing_else() -> void:
	var knowledge := _knowing(_world())
	var bounds := knowledge.bounds()
	assert_has(bounds, "from")

	for at in knowledge.explored():
		var from: Vector2i = bounds["from"]
		var to: Vector2i = bounds["to"]
		assert_true(at.x >= from.x and at.x <= to.x and at.y >= from.y and at.y <= to.y,
			"%s was seen and sits outside the bounds" % at)


func test_a_colony_that_has_seen_nothing_has_no_bounds() -> void:
	assert_empty(MapKnowledge.new().bounds())


# --- Saving -----------------------------------------------------------------

func test_what_the_colony_knows_survives_save_and_reload() -> void:
	# Ironman means a corrupt save is a lost run, and a map that forgot the
	# colony's own border would be found by a player rather than by a test.
	var world := _world()
	var knowledge := _knowing(world, 4)
	var restored := MapKnowledge.from_dict(knowledge.to_dict())
	var town: Town = world["town"]

	assert_eq(restored.seen.size(), knowledge.seen.size())
	assert_eq(restored.town_at(town.at), "Ashmere")
	assert_eq(String(restored.terrain_at(town.at)), String(knowledge.terrain_at(town.at)))
	assert_eq(restored.inside_border(town.at), knowledge.inside_border(town.at))
	assert_eq(String(restored.worked_by(town.at)), String(knowledge.worked_by(town.at)))
	assert_eq(restored.seen_in_month(town.at), 4)


func test_a_reloaded_colony_remembers_rather_than_sees() -> void:
	# `in_sight` is recomputed in phase 3 of every month and is not saved, so a
	# resumed run correctly shows its ground as remembered until it looks again.
	var knowledge := _knowing(_world())
	var at: Vector2i = knowledge.explored()[0]
	var restored := MapKnowledge.from_dict(knowledge.to_dict())
	assert_eq(String(restored.state_of(at)), String(MapKnowledge.REMEMBERED))


# --- The colony knows where it built ----------------------------------------

func test_a_new_run_can_see_the_town_it_just_founded() -> void:
	# Territory is recomputed in phase 3 of every world month, and the first of
	# those does not run until the first post is sent. Without observing at
	# founding, the player opens the map on turn one and is shown an empty sea.
	var run := RunState.new_run(SEED)
	assert_true(run.knowledge.seen.size() > 0, "a colony was founded and saw nothing")
	assert_not_empty(run.knowledge.towns, "it does not know where its own town is")
	# **Whatever it is called.** The first town is named from the towns' bag now
	# (#304), so this asks whether the map knows *the town that is there* rather
	# than whether it is still called Ashmere.
	var town := run.colony.in_order()[0]
	assert_eq(run.knowledge.town_at(town.at), town.display_name)
