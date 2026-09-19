extends TestCase

## Consume (#48).
##
## The shortage gradient is what the governor's letters are made of in M2, so
## most of these are about the difference between kinds of going without rather
## than about the arithmetic of eating.

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

func _town(workers: int, stock: Dictionary = {}, herd: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = workers
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	for kind in herd:
		town.add_livestock(StringName(kind), int(herd[kind]))
	return town


func _harness(town: Town) -> Dictionary:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town}


func _eat(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


# --- Eating -----------------------------------------------------------------

func test_consumption_scales_with_population() -> void:
	var small := _town(4, {"food": 100.0})
	var large := _town(12, {"food": 100.0})
	_eat(_harness(small))
	_eat(_harness(large))

	assert_almost_eq(100.0 - small.held(&"food"), 4.0, 0.001)
	assert_almost_eq(100.0 - large.held(&"food"), 12.0, 0.001)


func test_eating_is_deterministic() -> void:
	var first := _town(7, {"food": 100.0, "clothing": 20.0, "beer": 30.0})
	var second := _town(7, {"food": 100.0, "clothing": 20.0, "beer": 30.0})
	_eat(_harness(first))
	_eat(_harness(second))
	assert_eq(Canonical.hash_of(first.to_dict()), Canonical.hash_of(second.to_dict()))


func test_clothing_is_worn_in_proportion_to_population() -> void:
	var town := _town(20, {"food": 100.0, "clothing": 100.0})
	_eat(_harness(town))
	assert_almost_eq(100.0 - town.held(&"clothing"), 20.0 * ColonyNeeds.per_head(&"clothing"), 0.001)


# --- 🔒 Shortage is graded ---------------------------------------------------

func test_a_shortfall_is_graded_not_boolean() -> void:
	# A town that missed a meal must not read the same as a town eating its
	# horses. The perception ladders in the governor's letters have nothing to
	# climb if these collapse to one value.
	var grades: Dictionary = {}
	for food in [9.0, 5.0, 1.0, 0.0]:
		var town := _town(10, {"food": food})
		var harness := _harness(town)
		_eat(harness)
		var events: Array = harness["context"].log.of_type(ConsumePhase.EVENT_WENT_SHORT)
		assert_not_empty(events, "%f food for ten mouths was not a shortage" % food)
		grades[String(events[0].payload["severity"])] = true

	assert_true(grades.size() >= 3,
		"four depths of hunger produced %d distinct severities" % grades.size())


func test_a_fed_town_is_not_short_at_all() -> void:
	var town := _town(10, {"food": 100.0, "clothing": 100.0})
	var harness := _harness(town)
	_eat(harness)
	assert_empty(harness["context"].log.of_type(ConsumePhase.EVENT_WENT_SHORT))
	assert_eq(town.months_hungry, 0)


func test_a_shortage_names_what_ran_out() -> void:
	# A letter has to be able to say *what* the town is without.
	var town := _town(10, {"food": 2.0})
	var harness := _harness(town)
	_eat(harness)

	var events: Array = harness["context"].log.of_type(ConsumePhase.EVENT_WENT_SHORT)
	assert_not_empty(events)
	assert_eq(String(events[0].payload["resource"]), "food")
	for key in ["needed", "had", "unmet", "severity", "months_hungry"]:
		assert_has(events[0].payload, key, "the shortage did not record '%s'" % key)


func test_the_grades_span_the_gradient() -> void:
	assert_eq(Shortage.grade_of(0.0), Shortage.NONE)
	assert_eq(Shortage.grade_of(1.0), Shortage.STARVING)
	assert_ne(Shortage.grade_of(0.1), Shortage.grade_of(0.6))


# --- Famine -----------------------------------------------------------------

func test_sustained_hunger_reduces_the_population() -> void:
	var town := _town(20)
	var harness := _harness(town)
	var before := town.population()

	for _month in ConsumePhase.FAMINE_MONTHS:
		_eat(harness)

	assert_true(town.population() < before,
		"twenty people ate nothing for %d months and none of them died" % ConsumePhase.FAMINE_MONTHS)
	assert_not_empty(harness["context"].log.of_type(ConsumePhase.EVENT_FAMINE))


func test_a_brief_shortfall_kills_nobody() -> void:
	# **This asymmetry is what makes relief and a timely order worth something.**
	# A town that goes short, is helped, and eats the next month has lost nothing.
	var town := _town(20)
	var harness := _harness(town)

	_eat(harness)
	assert_eq(town.months_hungry, 1)

	town.store(&"food", 100.0)
	_eat(harness)
	assert_eq(town.months_hungry, 0, "the hunger counter did not reset once the town ate")

	_eat(harness)  # short again, but the run was broken
	assert_eq(town.population(), 20, "a brief shortfall killed people")
	assert_empty(harness["context"].log.of_type(ConsumePhase.EVENT_FAMINE))


func test_a_famine_takes_lives_one_at_a_time() -> void:
	# **🔒 No single event ever costs a town more than one population**
	# (CLAUDE.md). A bad month may take several, but each is its own resolution
	# and its own event — never one event saying three died. The Diplomat's death
	# roll and everything else per-population hangs off that.
	var town := _town(60)
	var harness := _harness(town)
	var before := town.population()
	for _month in ConsumePhase.FAMINE_MONTHS:
		_eat(harness)

	var deaths: Array = harness["context"].log.of_type(ConsumePhase.EVENT_FAMINE)
	assert_not_empty(deaths, "sixty people starved for three months and nobody died")
	assert_eq(deaths.size(), before - town.population(),
		"%d died and %d events were emitted" % [before - town.population(), deaths.size()])

	for event in deaths:
		# Each names one person, not a count.
		assert_true(typeof(event.payload["lost"]) == TYPE_STRING,
			"a famine event carried a tally rather than a single loss")


func test_a_famine_never_takes_more_than_the_town_has() -> void:
	var town := _town(2)
	var harness := _harness(town)
	for _month in ConsumePhase.FAMINE_MONTHS + 4:
		_eat(harness)
	assert_true(town.population() >= 0, "the town was taken below empty")


func test_famine_takes_workers_before_experts() -> void:
	# A colony loses its skilled men last.
	var town := _town(4)
	town.add_experts(&"wood", 3)
	var harness := _harness(town)
	for _month in ConsumePhase.FAMINE_MONTHS:
		_eat(harness)

	assert_true(town.workers < 4, "nobody died")
	assert_eq(town.expert_count(&"wood"), 3, "an expert died while labourers remained")


# --- Livestock --------------------------------------------------------------

func test_livestock_are_eaten_only_when_the_town_would_go_hungry() -> void:
	var fed := _town(4, {"food": 100.0}, {"sheep": 10})
	_eat(_harness(fed))
	assert_eq(fed.livestock_head(&"sheep"), 10, "a well-fed town killed its sheep")

	var starving := _town(4, {}, {"sheep": 10})
	var harness := _harness(starving)
	_eat(harness)
	assert_true(starving.livestock_head(&"sheep") < 10, "a hungry town did not touch its herd")
	assert_not_empty(harness["context"].log.of_type(ConsumePhase.EVENT_SLAUGHTERED))


func test_eating_the_herd_actually_feeds_the_town() -> void:
	# A last resort that does not work is not a mechanic, it is a message.
	var town := _town(4, {}, {"cows": 8})
	var harness := _harness(town)
	_eat(harness)

	assert_eq(town.months_hungry, 0, "the town starved with cattle in the field")
	assert_empty(harness["context"].log.of_type(ConsumePhase.EVENT_WENT_SHORT))


func test_livestock_eat_the_towns_grain_unless_there_is_pasture() -> void:
	var grazing := _town(4, {"food": 100.0}, {"cows": 20})
	grazing.add_building(&"stockyard")
	var penned := _town(4, {"food": 100.0}, {"cows": 20})

	_eat(_harness(grazing))
	_eat(_harness(penned))

	assert_true(grazing.held(&"food") > penned.held(&"food"),
		"pasture saved the town nothing")
	assert_almost_eq(100.0 - grazing.held(&"food"), 4.0, 0.001,
		"a pastured herd still ate the stores")


# --- Luxuries ---------------------------------------------------------------

func test_luxury_consumption_is_capped() -> void:
	# Without a ceiling a town with money buys its way to perfect contentment and
	# quality of life stops being about how the colony is run.
	var town := _town(10, {"food": 100.0, "beer": 500.0, "rum": 500.0})
	var harness := _harness(town)
	_eat(harness)

	var drunk := 1000.0 - town.held(&"beer") - town.held(&"rum")
	assert_almost_eq(drunk, 10.0 * ColonyNeeds.luxury_per_head(), 0.001,
		"the town drank past the cap")


func test_comfort_is_recorded_for_settle() -> void:
	# Quality of life is stored on the town and moved only in Settle (#50), so
	# Consume writes down what it found rather than applying it.
	var town := _town(10, {"food": 100.0, "clothing": 100.0, "beer": 100.0})
	var harness := _harness(town)
	_eat(harness)

	var record: Dictionary = harness["context"].wellbeing["ashmere"]
	for key in ["food", "clothing", "luxury"]:
		assert_has(record, key)
	assert_almost_eq(float(record["food"]), 1.0, 0.001)
	assert_almost_eq(float(record["luxury"]), 1.0, 0.001)


func test_a_dull_town_is_not_a_suffering_one() -> void:
	var town := _town(10, {"food": 100.0, "clothing": 100.0})
	var harness := _harness(town)
	_eat(harness)

	var record: Dictionary = harness["context"].wellbeing["ashmere"]
	assert_almost_eq(float(record["luxury"]), 0.0, 0.001)
	assert_almost_eq(float(record["food"]), 1.0, 0.001)
	assert_empty(harness["context"].log.of_type(ConsumePhase.EVENT_WENT_SHORT))
