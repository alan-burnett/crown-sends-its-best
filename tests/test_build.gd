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


func test_a_crane_shortens_a_build() -> void:
	var plain := _town(&"church", {})
	var helped := _town(&"church", {})
	helped.add_building(&"crane")
	assert_true(Objective.months_required(helped) < Objective.months_required(plain),
		"the crane saves nobody any time")


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
	# **Both towns are fed and clothed.** A town with no cloth at all weights furs
	# heavily enough to send everybody to the forest whatever its standing order
	# is, which is correct behaviour and a second signal louder than the one this
	# test is about.
	var timber := _town(&"harvest_timber", {"food": 100.0, "clothing": 20.0})
	var grain := _town(&"stockpile_food", {"food": 100.0, "clothing": 20.0})
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
	small.workers = 4
	var large := _town(&"granary", {})
	large.workers = 40
	assert_true(Objective.build_capacity(large) > Objective.build_capacity(small),
		"forty people build no faster than four")


func test_build_speed_multiplies_capacity() -> void:
	var plain := _town(&"church", {})
	var helped := _town(&"church", {})
	helped.add_building(&"crane")
	assert_true(Objective.build_capacity(helped) > Objective.build_capacity(plain),
		"the crane saves nobody any time")
	assert_true(Objective.months_required(helped) <= Objective.months_required(plain),
		"and it did not shorten the build")


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
	weaving.add_building(&"crane")
	weaving.add_building(&"weaving_shed")

	var colony := Colony.new()
	colony.add(plain)
	var bare := DesiredStock.for_town(plain, ColonySnapshot.of(colony))
	var other := Colony.new()
	other.add(weaving)
	var equipped := DesiredStock.for_town(weaving, ColonySnapshot.of(other))

	assert_true(equipped.wanted(&"cotton") > bare.wanted(&"cotton"),
		"a weaving shed gives the town no reason to lay in cotton")


# --- 🔒 A governor can want every building for the right reason -------------

## Effects that reach `ObjectiveSelector._building_axes`, and so can be a reason
## a governor chooses to build a thing.
const REACHES_THE_GOVERNOR: Array[String] = [
	"amusement", "build_speed", "counts_distant_experts", "defence", "draws_experts",
	"education", "education_per_expert", "growth", "immigration", "pasture",
	"quality_of_life", "reserve_months", "yield_bonus",
]

## And effects that deliberately do not, with why.
##
## `converts` and `conversions` are terms, not reasons: a town wants a foundry for
## the iron it will yield, which arrives through `yield_bonus` or through the
## recipe being worth running, rather than because the building has an opinion
## about ratios.
const DELIBERATELY_SILENT: Array[String] = ["conversions", "converts"]


func test_every_building_effect_is_something_a_governor_can_weigh() -> void:
	# 🔒 **The claim `_building_axes` makes about itself**: nothing there knows
	# what a granary is, so adding a building to the data is enough for a governor
	# to want it for the right reasons.
	#
	# An effect it has not been told about breaks that **silently**, and this has
	# now happened three times in one milestone — `reserve_months` read as a float
	# in #148 and again in #151, and `amusement` unread in #153, where the colony
	# built fourteen of the eighteen buildings in the tree and never the two that
	# exist to make people happy.
	#
	# So a new effect is now a decision: either it is a reason to build, or it is
	# listed above as one that is not.
	var seen: Dictionary = {}
	for id in Building.ids():
		for effect in Building.find(StringName(id)).effects:
			seen[String(effect)] = true

	var unclassified: PackedStringArray = PackedStringArray()
	for effect in seen:
		if not REACHES_THE_GOVERNOR.has(String(effect)) \
				and not DELIBERATELY_SILENT.has(String(effect)):
			unclassified.append(String(effect))
	unclassified.sort()
	assert_empty(unclassified,
		"%s reaches no governor and is not listed as deliberately silent, so no town will ever build for it" % [unclassified])


## A value of the right shape for an effect, so it can be scored on its own.
func _sample_for(effect: String) -> Variant:
	match effect:
		"yield_bonus":
			return {"wood": 0.5}
		"reserve_months":
			return {"food": 2}
		"pasture":
			return 12
		"counts_distant_experts":
			return 1.0
		_:
			return 1.0


func test_an_effect_that_reaches_the_governor_actually_moves_his_score() -> void:
	# **Listing it is not the same as wiring it**, and asking whether any real
	# building carrying it scores anything is not the same either: the theatre
	# also carries `quality_of_life`, so unwiring `amusement` entirely left that
	# version of this test green.
	#
	# So each effect is put on a building of its own, with nothing else on it.
	# Then the only thing that can produce a score is the effect under test.
	for effect in REACHES_THE_GOVERNOR:
		Building.load_from([{
			"id": "probe", "name": "a probe", "cost": {"wood": 10},
			"effects": {effect: _sample_for(effect)},
		}])
		var axes := ObjectiveSelector.building_axes(&"probe")
		var moved := false
		for axis in axes:
			if absf(float(axes[axis])) > 0.0001:
				moved = true
		assert_true(moved,
			"a building whose only effect is '%s' is worth nothing to any governor" % effect)

	# Put the real tree back for whatever runs next.
	Building.reset()
	M1Registrations.load_resources(content)
