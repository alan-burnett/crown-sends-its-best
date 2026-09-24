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
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ----------------------------------------------------------------

## A patch of plains with forest beside it.
func _map() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(1, 6):
		for x in range(1, 6):
			map.set_terrain(x, y, &"plains" if x <= 3 else &"forest")
	return map


func _town(objective: StringName, stock: Dictionary = {}, workers: int = 6) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	# Fixture sizes are in thousands (#426): a worker-slot per thousand, as it was.
	town.workers = workers * Population.THOUSAND
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
	# A granary is thirty wood, and **the timber is the schedule** (#148): a
	# town of six has a capacity of fifteen a month, so it takes two. Having the
	# timber is not the same as having the building.
	var town := _town(&"granary", {"wood": 30.0})
	var harness := _harness(town)

	var capacity := Objective.build_capacity(town)
	assert_true(capacity < 30.0,
		"the fixture town can raise the whole thing in a month, so there is no build to watch")

	_run_month(harness)
	assert_eq(town.objective_progress, 1)
	assert_false(town.has_building(&"granary"), "it went up in a single month")
	assert_almost_eq(town.invested(&"wood"), capacity, 0.001,
		"a month put something other than a month's capacity into the frame")
	assert_almost_eq(town.held(&"wood"), 30.0 - capacity, 0.001,
		"the rest of the timber should still be in the stores")

	_build_out(harness, town, &"granary")
	assert_true(town.has_building(&"granary"), "it never finished")


## Run months until the thing stands, or give up.
##
## **Never a fixed number of months** (#148). The schedule is the cost over the
## town's capacity, and capacity is tuning — a test that counted months would
## break every time somebody moved a constant it is not about.
func _build_out(harness: Dictionary, town: Town, id: StringName, limit: int = 12) -> void:
	for _month in limit:
		if town.has_building(id):
			return
		_run_month(harness)


func test_completion_applies_the_effect_and_emits() -> void:
	var town := _town(&"granary", {"wood": 30.0})
	var harness := _harness(town)
	assert_almost_eq(Building.reserve_months_for(town, &"food"), 0.0, 0.001)

	_build_out(harness, town, &"granary")

	# The effect comes from the building standing, never from this phase copying
	# numbers onto the town.
	var authored: Dictionary = Building.find(&"granary").effect("reserve_months", {})
	assert_almost_eq(Building.reserve_months_for(town, &"food"),
		float(authored.get("food", 0.0)), 0.001,
		"the finished granary holds back something other than what the data says")
	assert_almost_eq(Building.reserve_months_for(town, &"guns"), 0.0, 0.001,
		"it holds guns back too, which is the blanket reserve #148 removed")

	var events: Array = harness["context"].log.of_type(BuildPhase.EVENT_COMPLETED)
	assert_eq(events.size(), 1)
	assert_eq(String(events[0].payload["objective"]), "granary")
	assert_has(events[0].payload, "unlocks")


func test_the_objective_is_finished_with_when_it_is_done() -> void:
	var town := _town(&"granary", {"wood": 30.0})
	var harness := _harness(town)
	_build_out(harness, town, &"granary")

	assert_eq(String(town.objective), "", "the town is still building what it has built")
	assert_eq(town.objective_progress, 0)
	assert_empty(town.objective_invested)


# --- 🔒 Stalling does not undo the work -------------------------------------

func test_a_town_short_of_materials_stalls_without_losing_what_it_invested() -> void:
	# **Stalling is one condition now** (#148): the town cannot get the
	# resources. A month that put timber into the frame is a month's work, even
	# though the wall is nowhere near up — which is what it always was in fact,
	# and what the old two-gate model could not say.
	var town := _town(&"granary", {"wood": 10.0})
	var harness := _harness(town)

	_run_month(harness)
	assert_almost_eq(town.invested(&"wood"), 10.0, 0.001, "the ten it had never reached the frame")
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED),
		"a month that raised ten wood of frame reported itself as stalled")

	# Now there is genuinely nothing to put in.
	_run_month(harness)
	assert_not_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED))
	assert_almost_eq(town.invested(&"wood"), 10.0, 0.001,
		"a stalled month cost the town what it had already put in")

	# The rest arrives and it picks up where it left off, rather than starting
	# the thirty again.
	town.store(&"wood", 20.0)
	var standing := 0.0
	for _month in 6:
		if town.has_building(&"granary"):
			break
		var already := town.invested(&"wood")
		_run_month(harness)
		if not town.has_building(&"granary"):
			assert_true(town.invested(&"wood") >= already,
				"the frame gave timber back between months")
			standing = town.invested(&"wood")
	assert_true(standing >= 10.0, "it started the thirty again rather than picking up")
	assert_true(town.has_building(&"granary"), "it never finished")


func test_invested_resources_are_out_of_reach() -> void:
	# Not reserved — spent. Timber in the frame cannot be eaten, sold or given
	# away, which is the whole reason it is tracked apart from the stockpile.
	var town := _town(&"granary", {"wood": 10.0})
	_run_month(_harness(town))

	assert_almost_eq(town.held(&"wood"), 0.0, 0.001)
	assert_almost_eq(town.take(&"wood", 10.0), 0.0, 0.001,
		"something took timber out of a half-built wall")


func test_a_stall_reports_what_is_still_wanted() -> void:
	var town := _town(&"granary", {"wood": 10.0})
	var harness := _harness(town)
	_run_month(harness)  # puts the ten in
	_run_month(harness)  # and now there is nothing to put

	var events: Array = harness["context"].log.of_type(BuildPhase.EVENT_STALLED)
	assert_not_empty(events)
	var still: Dictionary = events[0].payload["still_needed"]
	assert_almost_eq(float(still["wood"]), 20.0, 0.001)


# --- Progress is something a letter can say ---------------------------------

func test_progress_is_expressible_as_a_fraction() -> void:
	# "The church is half raised" has to be derivable from the town, or the
	# governor cannot write it.
	var town := _town(&"granary", {"wood": 30.0})
	var harness := _harness(town)
	assert_almost_eq(Objective.progress_fraction(town), 0.0, 0.001)

	_run_month(harness)
	var half := Objective.progress_fraction(town)
	assert_true(half > 0.0 and half < 1.0,
		"a build one month into two reads as %f done" % half)


func test_progress_survives_save_and_reload_mid_construction() -> void:
	# Ironman means a corrupt save is a lost run, and a build that reset itself
	# on load would be found by a player, not by a test.
	var town := _town(&"granary", {"wood": 20.0})
	var expected := minf(20.0, Objective.build_capacity(town))
	_run_month(_harness(town))

	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(restored.invested(&"wood"), expected, 0.001)
	assert_eq(restored.objective_progress, town.objective_progress)
	assert_eq(String(restored.objective), "granary")
	assert_almost_eq(Objective.progress_fraction(restored), Objective.progress_fraction(town), 0.001)


func test_nothing_in_the_tree_speeds_building() -> void:
	# 🔒 `buildings.md` §3 (#327). **Build speed is a policy's business, not a
	# building's.** A building whose only effect is building faster is one a
	# governor can never sensibly want, because everything it would accelerate
	# outscores it — the crane was scored at 0.07, and every conversion building
	# sat behind it for seven years.
	assert_not_empty(Building.ids(), "no buildings loaded, so this proves nothing")
	for id in Building.ids():
		assert_almost_eq(float(Building.find(StringName(id)).effect("build_speed", 0.0)), 0.0,
			0.0001, "%s speeds building" % id)


func test_nothing_gates_the_way_out() -> void:
	# 🔒 `buildings.md` §5 (#327): *no cheap entry fee ahead of it and no
	# cheaper thing to build first.* Every building that converts one resource
	# into another asks for nothing before it — except the guns, whose chain §6
	# locks: armoury, then gunsmith, then foundry.
	var chain := {"gunsmith": ["foundry"], "armoury": ["gunsmith"]}
	var converting := 0
	for id in Building.ids():
		var building := Building.find(StringName(id))
		if not building.effects.has("conversions"):
			continue
		converting += 1
		assert_eq(Array(building.requires), chain.get(String(id), []),
			"%s is gated on %s" % [id, Array(building.requires)])
	assert_true(converting >= 9, "only %d buildings convert anything" % converting)
# --- No building ------------------------------------------------------------

func test_no_building_is_an_objective_without_a_finish() -> void:
	# `governor-agendas.md` §3: the shared fallback never completes, never
	# gathers, and never reports itself stalled.
	var town := _town(AgendaMenu.NO_BUILDING, {"food": 50.0})
	var harness := _harness(town)
	_run_month(harness)
	_run_month(harness)

	assert_eq(Objective.kind_of(town.objective), Objective.NO_BUILDING)
	assert_eq(String(town.objective), String(AgendaMenu.NO_BUILDING), "the fallback ended by itself")
	assert_eq(town.objective_progress, 0)
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED),
		"the fallback reported itself stalled for want of materials it never needed")


func test_no_building_works_every_tile_harder() -> void:
	# 🔒 §3: **+10% yield on every tile the town works** while it stands.
	# Same map, same workers, same month; the only difference is the fallback.
	var idle := _town(AgendaMenu.NO_BUILDING, {"food": 100.0, "clothing": 20.0})
	var building := _town(&"", {"food": 100.0, "clothing": 20.0})
	_run_month(_harness(idle, [ColonyMonth.WORK]))
	_run_month(_harness(building, [ColonyMonth.WORK]))

	var more := 0.0
	var less := 0.0
	for resource in idle.harvested:
		more += float(idle.harvested[resource])
	for resource in building.harvested:
		less += float(building.harvested[resource])
	assert_true(less > 0.0, "the fixture town harvested nothing, so this compared nothing")
	assert_almost_eq(more / less, 1.0 + AgendaMenu.NO_BUILDING_YIELD, 0.02,
		"no building did not work the ground a tenth harder")


func test_no_building_hoards_nothing() -> void:
	# The postures it replaces made a town sell none of what it stockpiled.
	# **The fallback bends nothing but the yield**: a town on it has as much to
	# spare as one with no objective at all.
	var fallback := _town(AgendaMenu.NO_BUILDING, {"food": 90.0})
	var ordinary := _town(&"", {"food": 90.0})
	var on_it := _harness(fallback, [ColonyMonth.RECKON])
	var usual := _harness(ordinary, [ColonyMonth.RECKON])
	_run_month(on_it)
	_run_month(usual)

	var spare: Reckoning = on_it["context"].reckonings["ashmere"]
	var normal: Reckoning = usual["context"].reckonings["ashmere"]
	assert_true(normal.spare_of(&"food") > 0.0, "the fixture had nothing to spare, so this compared nothing")
	assert_almost_eq(spare.spare_of(&"food"), normal.spare_of(&"food"), 0.001,
		"a town on the fallback held back food it had no use for")


func test_the_kinds_of_objective() -> void:
	# Content can be wrong, and an unknown objective must read as nothing rather
	# than crash the month. **The retired postures are unknown now**, so an old
	# name in a file reads as nothing rather than as a standing order.
	assert_eq(Objective.kind_of(AgendaMenu.NO_BUILDING), Objective.NO_BUILDING)
	assert_eq(Objective.kind_of(&"stockpile_food"), Objective.NONE)
	assert_eq(Objective.kind_of(&"granary"), Objective.CONSTRUCTION)
	assert_eq(Objective.kind_of(&"a_pony"), Objective.NONE)
	assert_eq(Objective.kind_of(&""), Objective.NONE)


func test_a_town_with_no_objective_builds_nothing_and_says_nothing() -> void:
	var town := _town(&"", {"wood": 100.0})
	var harness := _harness(town)
	_run_month(harness)

	assert_almost_eq(town.held(&"wood"), 100.0, 0.001)
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED))
	assert_empty(harness["context"].log.of_type(BuildPhase.EVENT_ADVANCED))


# --- 🔒 The materials are the time (#148) -----------------------------------

func test_build_capacity_comes_from_the_population() -> void:
	# A large town raises a granary in a month; a small one takes an age over the
	# same structure, and nothing had to be authored to say so.
	var small := _town(&"granary", {})
	small.workers = 4_000
	var large := _town(&"granary", {})
	large.workers = 40_000
	assert_true(Objective.build_capacity(large) > Objective.build_capacity(small),
		"forty people build no faster than four")


func test_duration_is_the_cost_over_the_capacity_and_is_not_authored() -> void:
	# 🔒 **One authored number per building instead of two**, so they can no
	# longer disagree. Doubling a cost doubles the schedule with nothing else
	# touched.
	var town := _town(&"granary", {})
	var capacity := Objective.build_capacity(town)
	var cost := Objective.total_cost(town)
	assert_eq(Objective.months_required(town), maxi(1, int(ceil(cost / capacity))),
		"the duration is not the cost divided by what the town can raise in a month")


func test_a_town_with_no_materials_makes_no_progress() -> void:
	var town := _town(&"granary", {})
	var harness := _harness(town)
	_run_month(harness)
	assert_eq(town.objective_progress, 0, "a town with an empty yard raised a month of wall")
	assert_not_empty(harness["context"].log.of_type(BuildPhase.EVENT_STALLED))


func test_a_reserve_names_its_resources_and_leaves_the_rest_alone() -> void:
	# 🔒 The blanket form held guns and rum back as readily as grain, which only
	# made the town trade less. Targeted, it changes behaviour instead.
	var town := _town(&"", {})
	town.add_building(&"granary")
	assert_true(Building.reserve_months_for(town, &"food") > 0.0,
		"a granary gives the town no reason to hold grain")
	for id in ["guns", "rum", "furs", "stone"]:
		assert_almost_eq(Building.reserve_months_for(town, StringName(id)), 0.0, 0.001,
			"the granary holds %s back, which is the blanket reserve again" % id)


func test_a_buildings_reserve_reaches_the_same_desired_stock_as_everything_else() -> void:
	# Buildings are a fourth contributor to #135's figure, not a separate system.
	var plain := _town(&"", {})
	var weaving := _town(&"", {})
	weaving.add_building(&"weaving_shed")

	var colony := Colony.new()
	colony.add(plain)
	var bare := DesiredStock.for_town(plain, ColonySnapshot.of(colony))
	var other := Colony.new()
	other.add(weaving)
	var equipped := DesiredStock.for_town(weaving, ColonySnapshot.of(other))

	assert_true(equipped.wanted(&"cotton") > bare.wanted(&"cotton"),
		"a weaving shed gives the town no reason to lay in cotton")
