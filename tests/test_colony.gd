extends TestCase

## The town model (#41), improvements (#39) and territory (#40).

const SEED: int = 1620

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	content.free()


func _town(id: StringName = &"ashmere", workers: int = 10) -> Town:
	var town := Town.new(id, "Ashmere", Vector2i(5, 5))
	town.workers = workers
	return town


# --- The town (#41) --------------------------------------------------------

func test_population_types_are_distinct_not_one_number() -> void:
	# Workers, experts and livestock (SPEC §12.2). Experts and livestock grow in
	# M4; they are distinct here so M4 has somewhere to put them.
	var town := _town(&"ashmere", 12)
	town.add_experts(&"iron", 2)
	town.add_livestock(&"cows", 5)

	assert_eq(town.workers, 12)
	assert_eq(town.expert_count(&"iron"), 2)
	assert_eq(town.expert_count(&"furs"), 0)
	assert_eq(town.livestock_head(&"cows"), 5)
	assert_eq(town.population(), 14, "livestock are not people")


func test_workers_decide_how_many_tiles_can_be_worked() -> void:
	assert_eq(_town(&"a", 7).workable_tiles(), 7)


func test_the_stockpile_holds_resources() -> void:
	var town := _town()
	town.store(&"food", 40.0)
	assert_almost_eq(town.held(&"food"), 40.0)
	assert_almost_eq(town.held(&"iron"), 0.0)
	assert_eq(town.stocked(), PackedStringArray(["food"]))


func test_taking_more_than_is_there_takes_what_there_is() -> void:
	# So a caller never has to check first and act second.
	var town := _town()
	town.store(&"food", 10.0)
	assert_almost_eq(town.take(&"food", 25.0), 10.0)
	assert_almost_eq(town.held(&"food"), 0.0)


func test_town_gold_rises_selling_and_falls_buying() -> void:
	var town := _town()
	town.receive_gold(100.0)
	assert_true(town.can_afford(80.0))
	assert_almost_eq(town.spend_gold(80.0), 80.0)
	assert_false(town.can_afford(80.0))


func test_a_town_that_cannot_afford_a_thing_pays_what_it_can() -> void:
	var town := _town()
	town.receive_gold(30.0)
	assert_almost_eq(town.spend_gold(50.0), 30.0, 0.001, "it simply buys less")


func test_town_gold_is_unreachable_from_presentation() -> void:
	# SPEC §11.3 makes it invisible to the player, and §10.2 locks that the
	# player's own gold is not a wallet either. `tools/lint.gd` enforces it —
	# this asserts the shape the lint depends on: there is no getter to call.
	var town := _town()
	town.receive_gold(50.0)
	assert_false(town.has_method("gold"), "a getter would make the lint the only thing standing in the way")
	assert_false(town.has_method("get_gold"))
	assert_true(town.has_method("can_afford"), "a question is all a caller gets")


func test_quality_of_life_is_stored_not_recomputed() -> void:
	# A reader that recomputed it would get a different answer halfway through a
	# month, and two readers would disagree. It moves only in Settle (#50).
	var town := _town()
	town.quality_of_life = 4.0
	town.store(&"food", 1000.0)
	assert_almost_eq(town.quality_of_life, 4.0, 0.001, "stocking food must not silently move it")


func test_a_town_survives_a_round_trip_whole() -> void:
	var town := _town(&"ashmere", 11)
	town.store(&"food", 40.0)
	town.store(&"iron", 6.0)
	town.receive_gold(275.0)
	town.add_experts(&"ore", 1)
	town.add_livestock(&"sheep", 3)
	town.add_building(&"church")
	town.objective = &"stockpile_food"
	town.objective_progress = 2
	town.quality_of_life = 3.5
	town.governor_id = &"gov_ashmere"

	var restored := Town.from_dict(town.to_dict())
	assert_eq(restored.to_dict(), town.to_dict())
	assert_almost_eq(restored.held(&"food"), 40.0)
	assert_eq(restored.objective, &"stockpile_food")
	assert_true(restored.can_afford(275.0), "the balance survived")
	assert_eq(restored.buildings, town.buildings)


func test_the_colony_orders_its_towns() -> void:
	# **Every town completes a phase before any town begins the next**
	# (SPEC §11.3), and a fixed order is what makes "no town benefits from being
	# simulated first" a thing that can be checked.
	var colony := Colony.new()
	colony.add(_town(&"zeta"))
	colony.add(_town(&"alpha"))
	colony.add(_town(&"mu"))
	assert_eq(colony.ids(), PackedStringArray(["alpha", "mu", "zeta"]))
	assert_eq(colony.in_order()[0].id, &"alpha")


func test_a_rebelling_town_is_still_part_of_the_colony() -> void:
	# SPEC §12.3: in the Crown's eyes it still belongs to the PC.
	var colony := Colony.new()
	var rebel := colony.add(_town(&"rebel"))
	rebel.rebelling = true
	colony.add(_town(&"loyal"))
	assert_eq(colony.size(), 2)
	assert_eq(colony.loyal().size(), 1)


# --- Improvements (#39) ----------------------------------------------------

func test_every_improvement_in_the_ticket_is_present() -> void:
	for id in ["farm", "pasture", "plantation_sugar", "plantation_cotton",
			"plantation_tobacco", "mine", "road", "fort"]:
		assert_true(Improvement.has(StringName(id)), "no improvement '%s'" % id)


func test_best_on_is_a_number_in_a_file() -> void:
	# "Best on plains, decent on grassland" without any code knowing which.
	var farm := Improvement.find(&"farm")
	assert_true(farm.factor_on(&"plains") > farm.factor_on(&"grassland"))
	assert_true(farm.factor_on(&"grassland") > farm.factor_on(&"mountains"))

	var mine := Improvement.find(&"mine")
	assert_true(mine.factor_on(&"mountains") > mine.factor_on(&"plains"))


func _bare(terrain: StringName) -> WorldMap:
	var map := WorldMap.new(3, 3, &"ocean")
	map.set_terrain(1, 1, terrain)
	return map


func test_a_farm_raises_food_and_lowers_everything_else() -> void:
	var map := _bare(&"plains")
	var food_before := map.yield_at(1, 1, &"food")
	var wood_before := map.yield_at(1, 1, &"wood")

	map.build(1, 1, &"farm")
	assert_true(map.yield_at(1, 1, &"food") > food_before)
	assert_true(map.yield_at(1, 1, &"wood") < wood_before)


func test_a_plantation_introduces_its_resource_and_keeps_the_food() -> void:
	var map := _bare(&"grassland")
	var food_before := map.yield_at(1, 1, &"food")
	assert_almost_eq(map.yield_at(1, 1, &"sugar"), 0.0, 0.001, "grassland yields no sugar on its own")

	map.build(1, 1, &"plantation_sugar")
	assert_true(map.yield_at(1, 1, &"sugar") > 0.0)
	assert_almost_eq(map.yield_at(1, 1, &"food"), food_before, 0.001, "it keeps the tile's food")
	assert_almost_eq(map.yield_at(1, 1, &"furs"), 0.0, 0.001, "and eliminates everything else")


func test_a_mine_introduces_ore_and_yields_nothing_else() -> void:
	var map := _bare(&"mountains")
	map.build(1, 1, &"mine")
	assert_true(map.yield_at(1, 1, &"ore") > 0.0)
	assert_true(map.yield_at(1, 1, &"stone") > 0.0)
	assert_almost_eq(map.yield_at(1, 1, &"furs"), 0.0, 0.001)


func test_a_road_slightly_raises_yields() -> void:
	var map := _bare(&"forest")
	var before := map.yield_at(1, 1, &"wood")
	map.build(1, 1, &"road")
	var after := map.yield_at(1, 1, &"wood")
	assert_true(after > before, "a road should help")
	assert_true(after < before * 2.0, "slightly")


func test_a_pasture_supports_livestock_and_reduces_yields() -> void:
	var map := _bare(&"grassland")
	var before := map.yield_at(1, 1, &"food")
	map.build(1, 1, &"pasture")
	assert_true(map.yield_at(1, 1, &"food") < before)
	assert_true(map.livestock_capacity_at(1, 1) > 0)


func test_one_improvement_replaces_another_cleanly() -> void:
	# A farm on a tile that had a mine. Nothing accumulates, because every
	# improvement computes from the terrain rather than from what was there.
	var map := _bare(&"plains")
	var farm_first := WorldMap.new(3, 3, &"ocean")
	farm_first.set_terrain(1, 1, &"plains")
	farm_first.build(1, 1, &"farm")

	map.build(1, 1, &"mine")
	var displaced := map.build(1, 1, &"farm")

	assert_eq(displaced, &"mine", "it says what it replaced")
	assert_eq(map.improvement_at(1, 1), &"farm")
	assert_almost_eq(map.yield_at(1, 1, &"food"), farm_first.yield_at(1, 1, &"food"), 0.001,
		"a farm is a farm, whatever stood there before")
	assert_almost_eq(map.yield_at(1, 1, &"ore"), 0.0, 0.001, "the mine left nothing behind")


func test_an_improvement_cannot_be_built_where_it_does_not_belong() -> void:
	var map := _bare(&"plains")
	assert_false(map.can_build(0, 0, &"farm"), "not in the ocean")
	assert_true(map.can_build(1, 1, &"farm"), "but on plains, yes")

	var peak := _bare(&"mountains")
	assert_false(peak.can_build(1, 1, &"plantation_sugar"), "sugar does not grow on a mountain")
	assert_true(peak.can_build(1, 1, &"mine"))

	# And a refused build changes nothing.
	assert_eq(peak.build(1, 1, &"plantation_sugar"), &"")
	assert_eq(peak.improvement_at(1, 1), &"")


func test_building_emits_an_event() -> void:
	# Map playback and the letters both want to know (Seam A).
	var map := _bare(&"plains")
	var log := EventLog.new()
	map.build(1, 1, &"farm", log, 4, &"ashmere")

	var events := log.of_type(&"improvement_built")
	assert_eq(events.size(), 1)
	assert_eq(events[0].payload["improvement"], "farm")
	assert_eq(events[0].payload["at"], Vector2i(1, 1))
	assert_eq(events[0].subject, &"ashmere")


func test_improvements_serialise_with_the_map() -> void:
	var map := _bare(&"plains")
	map.build(1, 1, &"farm")
	var restored := WorldMap.from_dict(map.to_dict())
	assert_eq(restored.improvement_at(1, 1), &"farm")
	assert_eq(restored.map_hash(), map.map_hash())


# --- Territory (#40) -------------------------------------------------------

func _run_with_a_town() -> RunState:
	var run := RunState.new_run(SEED)
	var town := Town.new(&"ashmere", "Ashmere", run.starting_site)
	town.workers = 10
	run.colony.add(town)
	return run


func test_influence_is_derived_and_grows_with_the_town() -> void:
	var run := _run_with_a_town()
	var town := run.colony.by_id(&"ashmere")

	var small := Territory.compute(run.map, [town]).tiles_of(&"ashmere").size()
	town.workers = 200
	var large := Territory.compute(run.map, [town]).tiles_of(&"ashmere").size()

	assert_true(large > small, "a bigger town works more ground")
	assert_true(Territory.reach_of(town) <= Territory.MAX_INFLUENCE, "but not without limit")


func test_vision_reaches_past_the_border() -> void:
	var run := _run_with_a_town()
	var territory := Territory.compute(run.map, run.colony.in_order())
	assert_true(territory.visible.size() > territory.border.size(),
		"vision should see further than the soldiers patrol")
	assert_true(territory.border.size() >= territory.influence.size())


func test_a_last_seen_record_exists_per_tile() -> void:
	var run := _run_with_a_town()
	var territory := Territory.compute(run.map, run.colony.in_order())
	run.knowledge.observe(run.map, territory, 3)

	var seen := run.starting_site
	assert_eq(run.knowledge.state_of(seen), MapKnowledge.IN_SIGHT)
	assert_eq(run.knowledge.terrain_at(seen), run.map.terrain_at(seen.x, seen.y))
	assert_eq(run.knowledge.seen_in_month(seen), 3)


func test_what_was_never_seen_is_unexplored() -> void:
	var run := _run_with_a_town()
	var territory := Territory.compute(run.map, run.colony.in_order())
	run.knowledge.observe(run.map, territory, 1)

	# Somewhere the colony cannot possibly see, found rather than assumed.
	var far := Vector2i(-1, -1)
	for y in run.map.height:
		for x in run.map.width:
			if not territory.can_see(Vector2i(x, y)):
				far = Vector2i(x, y)
				break
		if far.x >= 0:
			break

	assert_true(far.x >= 0, "the colony can see the entire map, which cannot be right")
	assert_eq(run.knowledge.state_of(far), MapKnowledge.UNEXPLORED)
	assert_eq(run.knowledge.terrain_at(far), &"", "and nothing is shown for it")


func test_a_tile_out_of_sight_is_remembered_as_last_seen() -> void:
	# Which may be out of date, and that is the point.
	var run := _run_with_a_town()
	var territory := Territory.compute(run.map, run.colony.in_order())
	run.knowledge.observe(run.map, territory, 1)

	var seen := run.starting_site
	# The colony withdraws entirely: nothing is in sight any more.
	run.knowledge.observe(run.map, Territory.new(), 2)

	assert_eq(run.knowledge.state_of(seen), MapKnowledge.REMEMBERED)
	assert_eq(run.knowledge.seen_in_month(seen), 1, "remembered as of the month it was seen")


func test_territory_is_recomputed_only_in_phase_three() -> void:
	var run := _run_with_a_town()
	var driver := TerritoryDriver.new(run.map, run.colony, run.knowledge)
	var log := EventLog.new()
	var streams := RngStreams.new(SEED)

	for phase in WorldPhase.ORDER:
		if phase == WorldPhase.TERRITORY:
			continue
		driver.on_phase(phase, run.world, log, streams)
	assert_true(driver.territory == null, "no other phase may recompute it")

	driver.on_phase(WorldPhase.TERRITORY, run.world, log, streams)
	assert_true(driver.territory != null)
	assert_eq(log.of_type(TerritoryDriver.EVENT_TERRITORY).size(), 1)


func test_the_turn_loop_recomputes_territory_each_month() -> void:
	var run := _run_with_a_town()
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	machine.send_post()

	assert_true(machine.territory.territory != null, "phase 3 never ran")
	assert_true(run.knowledge.explored_count() > 0, "the colony learnt nothing about its own site")


func test_what_the_colony_knows_survives_a_round_trip() -> void:
	var run := _run_with_a_town()
	run.knowledge.observe(run.map, Territory.compute(run.map, run.colony.in_order()), 5)

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.knowledge.explored_count(), run.knowledge.explored_count())
	assert_eq(restored.knowledge.terrain_at(run.starting_site), run.knowledge.terrain_at(run.starting_site))
	assert_eq(restored.colony.to_dict(), run.colony.to_dict())
	assert_eq(restored.state_hash(), run.state_hash())
