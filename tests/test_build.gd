extends TestCase

## Build, and objectives that are not construction (#49).
##
## Half of this is about the second kind. **A governor who can only ever be
## part-way through a building writes the same letter every month**, and the
## spec's own examples of objectives — stockpiling food, harvesting a resource,
## fortifying — mostly have no finish at all.

const SEED: int = 1649

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


# --- Fixture ----------------------------------------------------------------

## A patch of plains with forest beside it, so a posture towards timber has
## somewhere to send the men that a hungry town would not have chosen.
func _map() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(1, 6):
		for x in range(1, 6):
			map.set_terrain(x, y, &"plains" if x <= 3 else &"forest")
	return map


func _town(objective: StringName, stock: Dictionary = {}, workers: int = 6) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	town.objective = objective
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


## Build alone, so nothing is produced or eaten and the stores are what the test
## put there.
func _harness(town: Town, phases: Array = [ColonyMonth.BUILD]) -> Dictionary:
	var map := _map()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.territory = Territory.compute(map, colony.in_order())

	var month := ColonyMonth.new()
	if phases.has(ColonyMonth.WORK):
		month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	if phases.has(ColonyMonth.RECKON):
		month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	if phases.has(ColonyMonth.BUILD):
		month.set_handler(ColonyMonth.BUILD, BuildPhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


# --- Building ---------------------------------------------------------------

func test_a_multi_month_build_accumulates_progress() -> void:
	# A storehouse is thirty wood and two months. Having the timber is not the
	# same as having the building.
	var town := _town(&"storehouse", {"wood": 30.0})
	var harness := _harness(town)

	_run_month(harness)
	assert_eq(town.objective_progress, 1)
	assert_false(town.has_building(&"storehouse"), "it went up in a single month")
	assert_almost_eq(town.held(&"wood"), 0.0, 0.001, "the timber never left the stores")
	assert_almost_eq(town.invested(&"wood"), 30.0, 0.001, "the timber never reached the frame")

	_run_month(harness)
	assert_true(town.has_building(&"storehouse"), "it never finished")


func test_completion_applies_the_effect_and_emits() -> void:
	var town := _town(&"storehouse", {"wood": 30.0})
	var harness := _harness(town)
	assert_almost_eq(Building.reserve_months_for(town), 0.0, 0.001)

	_run_month(harness)
	_run_month(harness)

	# The effect comes from the building standing, never from this phase copying
	# numbers onto the town.
	assert_almost_eq(Building.reserve_months_for(town), 1.0, 0.001,
		"the finished storehouse holds nothing back")

	var events: Array = harness["context"].log.of_type(BuildPhase.EVENT_COMPLETED)
	assert_eq(events.size(), 1)
	assert_eq(String(events[0].payload["building"]), "storehouse")
	assert_has(events[0].payload, "unlocks")


func test_the_objective_is_finished_with_when_it_is_done() -> void:
	var town := _town(&"storehouse", {"wood": 30.0})
	var harness := _harness(town)
	_run_month(harness)
	_run_month(harness)

	assert_eq(String(town.objective), "", "the town is still building what it has built")
	assert_eq(town.objective_progress, 0)
	assert_empty(town.objective_invested)


# --- 🔒 Stalling does not undo the work -------------------------------------

func test_a_town_short_of_materials_stalls_without_losing_what_it_invested() -> void:
	var town := _town(&"storehouse", {"wood": 10.0})
	var harness := _harness(town)

	_run_month(harness)
	assert_eq(town.objective_progress, 0, "a stalled build put in a month's labour")
	assert_almost_eq(town.invested(&"wood"), 10.0, 0.001, "the invested timber was lost")
	assert_not_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED))

	_run_month(harness)
	assert_almost_eq(town.invested(&"wood"), 10.0, 0.001,
		"a second stalled month cost the town what it had already put in")

	# The rest arrives and it picks up where it left off, rather than starting
	# the thirty again.
	town.store(&"wood", 20.0)
	_run_month(harness)
	assert_eq(town.objective_progress, 1)
	assert_almost_eq(town.invested(&"wood"), 30.0, 0.001)


func test_invested_resources_are_out_of_reach() -> void:
	# Not reserved — spent. Timber in the frame cannot be eaten, sold or given
	# away, which is the whole reason it is tracked apart from the stockpile.
	var town := _town(&"storehouse", {"wood": 10.0})
	_run_month(_harness(town))

	assert_almost_eq(town.held(&"wood"), 0.0, 0.001)
	assert_almost_eq(town.take(&"wood", 10.0), 0.0, 0.001,
		"something took timber out of a half-built wall")


func test_a_stall_reports_what_is_still_wanted() -> void:
	var town := _town(&"storehouse", {"wood": 10.0})
	var harness := _harness(town)
	_run_month(harness)

	var events: Array = harness["context"].log.of_type(BuildPhase.EVENT_STALLED)
	assert_not_empty(events)
	var still: Dictionary = events[0].payload["still_needed"]
	assert_almost_eq(float(still["wood"]), 20.0, 0.001)


# --- Progress is something a letter can say ---------------------------------

func test_progress_is_expressible_as_a_fraction() -> void:
	# "The church is half raised" has to be derivable from the town, or the
	# governor cannot write it.
	var town := _town(&"storehouse", {"wood": 30.0})
	var harness := _harness(town)
	assert_almost_eq(Objective.progress_fraction(town), 0.0, 0.001)

	_run_month(harness)
	var half := Objective.progress_fraction(town)
	assert_true(half > 0.0 and half < 1.0,
		"a build one month into two reads as %f done" % half)


func test_progress_survives_save_and_reload_mid_construction() -> void:
	# Ironman means a corrupt save is a lost run, and a build that reset itself
	# on load would be found by a player, not by a test.
	var town := _town(&"storehouse", {"wood": 20.0})
	_run_month(_harness(town))

	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(restored.invested(&"wood"), 20.0, 0.001)
	assert_eq(restored.objective_progress, town.objective_progress)
	assert_eq(String(restored.objective), "storehouse")
	assert_almost_eq(Objective.progress_fraction(restored), Objective.progress_fraction(town), 0.001)


func test_a_carpenters_hall_shortens_a_build() -> void:
	var plain := _town(&"church", {})
	var helped := _town(&"church", {})
	helped.add_building(&"carpenters_hall")
	assert_true(Objective.months_required(helped) < Objective.months_required(plain),
		"the carpenters' hall saves nobody any time")


# --- Standing postures ------------------------------------------------------

func test_a_posture_is_an_objective_without_a_finish() -> void:
	var town := _town(&"stockpile_food", {"food": 50.0})
	var harness := _harness(town)
	_run_month(harness)
	_run_month(harness)

	assert_eq(Objective.kind_of(town.objective), Objective.POSTURE)
	assert_eq(String(town.objective), "stockpile_food", "a standing order ended by itself")
	assert_eq(town.objective_progress, 0)
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED),
		"a posture reported itself stalled for want of materials it never needed")


func test_a_posture_changes_what_work_does() -> void:
	# Same map, same workers, same month — two different standing orders. **If
	# the objective did not reach Work these would be the same month twice.**
	#
	# Compared against another posture rather than against no objective at all:
	# forest outscores plains on this map before any weighting is applied, so a
	# town with no orders already cuts timber, and "no orders" would have made a
	# weaker comparison look like a passing one.
	var timber := _town(&"harvest_timber", {"food": 100.0})
	var grain := _town(&"stockpile_food", {"food": 100.0})
	_run_month(_harness(timber, [ColonyMonth.WORK]))
	_run_month(_harness(grain, [ColonyMonth.WORK]))

	assert_true(timber.held(&"wood") > grain.held(&"wood"),
		"a town told to cut timber cut no more of it than one told to store grain")
	assert_true(grain.held(&"food") > timber.held(&"food"),
		"a town told to store grain grew no more of it than one told to cut timber")


func test_a_posture_changes_what_reckon_does() -> void:
	# **A town stockpiling food that sold its surplus every month would be
	# stockpiling nothing.** Reserving all of it is how the standing order
	# becomes true in Relief and Sell at once.
	var hoarder := _town(&"stockpile_food", {"food": 90.0})
	var ordinary := _town(&"", {"food": 90.0})
	var hoarding := _harness(hoarder, [ColonyMonth.RECKON])
	var usual := _harness(ordinary, [ColonyMonth.RECKON])
	_run_month(hoarding)
	_run_month(usual)

	var hoarded: Reckoning = hoarding["context"].reckonings["ashmere"]
	var normal: Reckoning = usual["context"].reckonings["ashmere"]

	assert_almost_eq(hoarded.spare_of(&"food"), 0.0, 0.001,
		"a town under orders to stockpile food had food to spare")
	assert_true(normal.spare_of(&"food") > 0.0)


func test_a_posture_towards_a_resource_is_not_a_building() -> void:
	# Content can be wrong, and an unknown objective must read as nothing rather
	# than crash the month.
	assert_eq(Objective.kind_of(&"stockpile_food"), Objective.POSTURE)
	assert_eq(Objective.kind_of(&"storehouse"), Objective.CONSTRUCTION)
	assert_eq(Objective.kind_of(&"a_pony"), Objective.NONE)
	assert_eq(Objective.kind_of(&""), Objective.NONE)


func test_a_town_with_no_objective_builds_nothing_and_says_nothing() -> void:
	var town := _town(&"", {"wood": 100.0})
	var harness := _harness(town)
	_run_month(harness)

	assert_almost_eq(town.held(&"wood"), 100.0, 0.001)
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED))
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_ADVANCED))
