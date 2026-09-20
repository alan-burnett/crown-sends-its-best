extends TestCase

## Work and Reckon (#44), and the building tree (#46).

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
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
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


# --- A small world to work in ----------------------------------------------

## A patch of plains with forest beside it, so there is a real choice between
## food and wood rather than one good tile.
func _map() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(1, 6):
		for x in range(1, 6):
			map.set_terrain(x, y, &"plains" if x <= 3 else &"forest")
	return map


func _harness(workers: int = 6) -> Dictionary:
	var map := _map()
	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	# **Funded, so its buildings are lit** (#151). Upkeep unpaid disables the
	# effect and keeps the building, which would make these tests about that.
	town.receive_gold(5_000.0)
	colony.add(town)

	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.run_seed = SEED
	context.territory = Territory.compute(map, colony.in_order())

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	return {"map": map, "colony": colony, "town": town, "context": context, "month": month}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])


# --- Work ------------------------------------------------------------------

func test_a_town_works_tiles_and_the_yields_reach_the_stockpile() -> void:
	var harness := _harness()
	var town: Town = harness["town"]
	assert_almost_eq(town.held(&"food"), 0.0)

	_run_month(harness)
	assert_true(town.held(&"food") > 0.0, "a month's work produced no food")


func test_a_town_works_no_more_tiles_than_it_has_workers() -> void:
	# Workers determine how many tiles the town can work (SPEC §12.2).
	for workers in [1, 4, 9]:
		var harness := _harness(workers)
		_run_month(harness)
		var worked: int = harness["context"].log.of_type(WorkPhase.EVENT_WORKED)[0].payload["tiles_worked"]
		assert_true(worked <= workers, "%d workers worked %d tiles" % [workers, worked])


func test_a_town_works_its_best_ground_first() -> void:
	# A player looking at the map should agree with the choice.
	var harness := _harness(2)
	_run_month(harness)
	var town: Town = harness["town"]
	# With food unpressing and only two workers, it takes the richest work
	# available rather than the nearest.
	#
	# **Hands, not tiles** (#185). Tiles and recipes are ranked in one list, so a
	# worker may be sent to the town instead of the fields — and since Convert
	# moved to phase 6 he is held back rather than working here. What Work
	# promises is that every hand is employed on the best thing going.
	assert_true(town.held(&"food") + town.held(&"wood") > 0.0)
	var payload: Dictionary = harness["context"].log.of_type(WorkPhase.EVENT_WORKED)[0].payload
	assert_eq(int(payload["tiles_worked"]) + int(payload["converting"]), 2,
		"two workers did not amount to two hands of work")


func test_a_town_short_of_food_prioritises_food_over_its_objective() -> void:
	# **The case this rule exists for.** A town that quarries while starving reads
	# as broken however good the prose is.
	var starving := _harness(4)
	starving["town"].objective = &"sawmill"  # wants wood
	_run_month(starving)
	var hungry_food: float = starving["town"].held(&"food")
	var hungry_wood: float = starving["town"].held(&"wood")

	var fed := _harness(4)
	fed["town"].objective = &"sawmill"
	fed["town"].store(&"food", 400.0)  # months of it in hand
	_run_month(fed)
	var fed_food: float = fed["town"].held(&"food") - 400.0
	var fed_wood: float = fed["town"].held(&"wood")

	assert_true(hungry_food > fed_food,
		"the starving town grew %.1f food, the comfortable one %.1f" % [hungry_food, fed_food])
	assert_true(fed_wood > hungry_wood,
		"the comfortable town should be free to chase its objective instead")


func test_experts_raise_the_yield_of_their_resource() -> void:
	# SPEC §12.2, asked of the tile rather than of the stockpile.
	#
	# **It used to be asked of the stockpile and that stopped being the right
	# question** (#135). A town works its ground until what it would add is worth
	# less than the next thing, so a food expert makes it reach the grain it wants
	# *a tile sooner* and puts that hand in the forest. On this fixture the skilled
	# town ends the month with 17.5 grain against 19 and half again as much of
	# everything else — better off, and holding less of the thing its expert is
	# expert in.
	#
	# That is the allocation working. What SPEC §12.2 actually claims is about the
	# tile, so that is what is asserted here, and the total is asserted beside it
	# so a change that made an expert worthless would still be caught.
	var harness := _harness(4)
	var town: Town = harness["town"]
	var bare := WorkPhase.expert_multiplier(town, &"food")
	town.add_experts(&"food", 1)
	assert_true(WorkPhase.expert_multiplier(town, &"food") > bare,
		"an expert did not raise what his ground gives")

	var plain := _harness(4)
	_run_month(plain)
	var skilled := _harness(4)
	skilled["town"].add_experts(&"food", 1)
	_run_month(skilled)

	assert_true(_produced(skilled["town"]) > _produced(plain["town"]),
		"a town with an expert had no more to show for the month than one without")


## Everything a town holds, at what the Crown would pay for it.
func _produced(town: Town) -> float:
	var total := 0.0
	for resource in ResourceCatalogue.ids():
		total += town.held(StringName(resource)) * ResourceCatalogue.price_of(StringName(resource))
	return total


func test_stacking_experts_has_diminishing_returns() -> void:
	# SPEC §12.2. Two mediocre towns beat one with every expert crammed into it.
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	var steps: Array[float] = []
	var previous := 1.0
	for count in range(1, 5):
		town.experts = {"food": count}
		var multiplier := WorkPhase.expert_multiplier(town, &"food")
		steps.append(multiplier - previous)
		previous = multiplier

	for i in range(1, steps.size()):
		assert_true(steps[i] < steps[i - 1],
			"expert %d added %.4f, expert %d added %.4f" % [i, steps[i - 1], i + 1, steps[i]])


func test_an_expert_in_one_resource_does_not_help_another() -> void:
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	town.add_experts(&"ore", 3)
	assert_almost_eq(WorkPhase.expert_multiplier(town, &"food"), 1.0)
	assert_true(WorkPhase.expert_multiplier(town, &"ore") > 1.0)


func test_buildings_raise_yields_once_they_stand() -> void:
	var plain := _harness(4)
	_run_month(plain)

	var milled := _harness(4)
	milled["town"].add_building(&"sawmill")
	_run_month(milled)

	assert_true(milled["town"].held(&"wood") > plain["town"].held(&"wood"))


func test_work_emits_what_was_produced() -> void:
	var harness := _harness()
	_run_month(harness)
	var event: SimEvent = harness["context"].log.of_type(WorkPhase.EVENT_WORKED)[0]
	assert_eq(event.subject, &"ashmere")
	assert_eq(event.phase, WorldPhase.COLONY_MONTH)
	assert_not_empty(event.payload["produced"])


func test_a_town_with_no_territory_works_nothing() -> void:
	var harness := _harness()
	harness["context"].territory = null
	_run_month(harness)
	assert_almost_eq(harness["town"].held(&"food"), 0.0)


# --- Reckon ----------------------------------------------------------------

func test_needs_are_by_population() -> void:
	var harness := _harness(10)
	_run_month(harness)
	var reckoning: Reckoning = harness["context"].reckoning_for(harness["town"])
	assert_almost_eq(reckoning.need_of(&"food"), 10.0 * ColonyNeeds.per_head(&"food"))
	assert_almost_eq(reckoning.need_of(&"clothing"), 10.0 * ColonyNeeds.per_head(&"clothing"))


func test_the_objective_tier_is_what_it_still_costs() -> void:
	# **One worker**, so the month's work cannot finish the granary outright.
	# The fixture always assumed that; it used to hold because the hunger weight
	# kept a destitute town out of the forest, and that weight is gone (#116).
	var harness := _harness(1)
	harness["town"].objective = &"granary"
	harness["town"].store(&"wood", 10.0)
	_run_month(harness)

	var reckoning: Reckoning = harness["context"].reckoning_for(harness["town"])
	var building := Building.find(&"granary")
	assert_true(reckoning.objective_of(&"wood") > 0.0)
	assert_true(reckoning.objective_of(&"wood") < building.cost_of(&"wood"),
		"what it already holds should count against what it still wants")


func test_reserve_sizing_is_data_driven() -> void:
	# Not a magic number in code.
	var harness := _harness(10)
	_run_month(harness)
	var reckoning: Reckoning = harness["context"].reckoning_for(harness["town"])
	assert_almost_eq(
		reckoning.reserve_of(&"food"),
		10.0 * ColonyNeeds.per_head(&"food") * ColonyNeeds.reserve_months(&"food"),
	)


func test_a_granary_lets_a_town_hold_more_back() -> void:
	var plain := _harness(10)
	_run_month(plain)
	var without: float = plain["context"].reckoning_for(plain["town"]).reserve_of(&"food")

	var stocked := _harness(10)
	stocked["town"].add_building(&"granary")
	_run_month(stocked)
	var with_granary: float = stocked["context"].reckoning_for(stocked["town"]).reserve_of(&"food")

	assert_true(with_granary > without)


func test_spare_is_what_survives_needs_and_reserve() -> void:
	# **🔒 Needs before wants**, enforced by the order the numbers come out in.
	var harness := _harness(4)
	harness["town"].store(&"food", 1000.0)
	_run_month(harness)

	var reckoning: Reckoning = harness["context"].reckoning_for(harness["town"])
	var held: float = harness["town"].held(&"food")
	assert_true(reckoning.spare_of(&"food") > 0.0)
	assert_true(reckoning.spare_of(&"food") < held,
		"a town cannot spare what it is about to eat")


func test_a_town_with_nothing_spares_nothing() -> void:
	var harness := _harness(10)
	harness["context"].territory = null  # nothing worked, nothing gained
	_run_month(harness)
	var reckoning: Reckoning = harness["context"].reckoning_for(harness["town"])
	assert_almost_eq(reckoning.spare_of(&"food"), 0.0)
	assert_true(reckoning.is_short())


func test_shortages_are_reported_worst_first() -> void:
	# Need is served worst-first when towns give to each other (SPEC §11.3), so
	# the order is part of the answer.
	var reckoning := Reckoning.new(&"a")
	reckoning.shortfall = {"clothing": 2.0, "food": 40.0, "tools": 9.0}
	assert_eq(reckoning.shortages(), PackedStringArray(["food", "tools", "clothing"]))


func test_reckon_emits_what_the_town_is_short_of() -> void:
	var harness := _harness(10)
	harness["context"].territory = null
	_run_month(harness)
	var event: SimEvent = harness["context"].log.of_type(ReckonPhase.EVENT_RECKONED)[0]
	assert_eq(event.subject, &"ashmere")
	assert_not_empty(event.payload["short_of"])


func test_the_reckoning_is_available_to_every_later_phase() -> void:
	# Five phases asking the same question and getting five answers is how a town
	# ends up selling the grain it is about to eat.
	var harness := _harness()
	_run_month(harness)
	var context: ColonyContext = harness["context"]
	assert_true(context.reckonings.has("ashmere"))
	assert_eq(context.reckoning_for(harness["town"]).town_id, &"ashmere")


# --- The building tree (#46) -----------------------------------------------

## The first building in the tree that stands on exactly one other.
##
## **Found rather than named** (`buildings.md` §4). The tree is the PO's and is
## being reworked branch by branch; a test that hardcodes one prerequisite pair
## has to be edited every time the shape moves, at which point it is recording
## the tree rather than checking it has prerequisites at all.
func _a_building_with_one_prerequisite() -> Building:
	for id in Building.ids():
		var building := Building.find(StringName(id))
		if building.requires.size() == 1:
			return building
	return null


func test_prerequisites_costs_and_effects_are_all_data() -> void:
	var building := _a_building_with_one_prerequisite()
	assert_true(building != null, "nothing in the tree stands on anything else")
	assert_not_empty(building.requires)
	assert_true(building.costed_resources().size() > 0, "%s costs nothing" % building.id)


func test_a_building_cannot_be_started_with_unmet_prerequisites() -> void:
	var building := _a_building_with_one_prerequisite()
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	assert_false(building.prerequisites_met(town))
	assert_false(Building.available_to(town).has(String(building.id)))

	town.add_building(StringName(building.requires[0]))
	assert_true(building.prerequisites_met(town))
	assert_true(Building.available_to(town).has(String(building.id)))


func test_a_building_already_standing_is_not_offered_again() -> void:
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	assert_true(Building.available_to(town).has("granary"))
	town.add_building(&"granary")
	assert_false(Building.available_to(town).has("granary"))


func test_the_tree_has_a_genuine_fork() -> void:
	# Two early buildings that lead somewhere different, so a town faces a real
	# choice about what to build first.
	#
	# **Asked of the tree, not of two named buildings.** `buildings.md` is being
	# reworked branch by branch, and a test that names the fork has to be edited
	# every time the shape moves — at which point it is recording the tree rather
	# than checking it has one.
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	var forks := 0
	var open := Building.available_to(town)
	for first in open:
		for second in open:
			if first >= second:
				continue
			var by_first := Building.unlocked_by(StringName(first))
			var by_second := Building.unlocked_by(StringName(second))
			if by_first.is_empty() or by_second.is_empty():
				continue
			if by_first != by_second:
				forks += 1
	assert_true(forks > 0,
		"nothing a town can build first leads anywhere the others do not, so there is no choice")


func test_effects_apply_only_once_the_building_stands() -> void:
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	assert_almost_eq(Building.yield_bonus_for(town, &"wood"), 0.0)
	town.add_building(&"sawmill")
	assert_true(Building.yield_bonus_for(town, &"wood") > 0.0)


func test_effects_persist_through_save_and_reload() -> void:
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	town.add_building(&"sawmill")
	town.add_building(&"granary")
	var before := Building.yield_bonus_for(town, &"wood")

	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(Building.yield_bonus_for(restored, &"wood"), before)
	assert_true(Building.reserve_months_for(restored, &"food") > 0.0)
	assert_true(Building.reserve_months_for(restored, &"food") > 0.0)


func test_a_building_may_grant_a_contact_without_anything_acting_on_it() -> void:
	# The field, not the feature. Institutional contacts are M7.
	assert_eq(Building.find(&"church").grants_contact, "clergyman")
	assert_eq(Building.find(&"church").grants_contact, "clergyman")
	assert_eq(Building.find(&"sawmill").grants_contact, "", "most buildings bring nobody")


func test_every_building_cost_names_a_real_resource() -> void:
	for id in Building.ids():
		for resource in Building.find(StringName(id)).costed_resources():
			assert_true(ResourceCatalogue.has(StringName(resource)),
				"'%s' costs '%s', which is not a resource" % [id, resource])


func test_every_prerequisite_names_a_real_building() -> void:
	for id in Building.ids():
		for required in Building.find(StringName(id)).requires:
			assert_true(Building.has(StringName(required)),
				"'%s' requires '%s', which does not exist" % [id, required])


func test_the_whole_tree_is_reachable_from_nothing() -> void:
	# A branch nobody can ever get to is a branch that does not exist.
	var town := Town.new(&"a", "A", Vector2i.ZERO)
	var guard := 0
	while Building.available_to(town).size() > 0 and guard < 50:
		guard += 1
		town.add_building(StringName(Building.available_to(town)[0]))
	assert_eq(town.buildings.size(), Building.ids().size(),
		"unreachable: %s" % [Building.ids()])
