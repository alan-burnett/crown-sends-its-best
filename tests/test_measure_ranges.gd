extends TestCase

## Measure ranges track the size of the colony (#63,
## `docs/mechanics/perception.md` §4a).
##
## A measure normalised against a **fixed** range stops meaning anything as the
## colony grows. Two hundred gold is a fortune in year one and a rounding error
## in year ten, and a ladder pinned to absolutes says *ruinous* for ever.
##
## **Nothing is lost by making them relative**, because `{param:}` carries the
## true figure and always did. A letter can say the month brought four thousand
## in duties and that the returns are thin, in one sentence.

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


func _state(duty: float, baseline: float) -> WorldState:
	var state := WorldValues.initial_state()
	state.values[WorldValues.REVENUE] = duty
	state.values[WorldValues.REVENUE_BASELINE] = baseline
	return state


# --- 🔒 The same colony, ten times the size, reads the same -----------------

func test_a_colony_ten_times_the_size_doing_as_well_reads_the_same() -> void:
	# **This is the whole of #63.** The hamlet and the city are both having an
	# ordinary month, and both should say so.
	var hamlet := WorldValues.measures(_state(40.0, 40.0))
	var province := WorldValues.measures(_state(400.0, 400.0))
	var empire := WorldValues.measures(_state(40_000.0, 40_000.0))

	assert_almost_eq(float(hamlet[WorldValues.REVENUE]), 1.0, 0.001)
	assert_almost_eq(float(province[WorldValues.REVENUE]), 1.0, 0.001)
	assert_almost_eq(float(empire[WorldValues.REVENUE]), 1.0, 0.001)


func test_every_rung_stays_reachable_at_any_size() -> void:
	# The failure this replaces: at the old fixed ceiling a real colony sat on
	# the bottom rung of the Steward's ladder for the entire run, and three of
	# his four words could never be said.
	for scale in [1.0, 10.0, 1000.0]:
		var rungs: Dictionary = {}
		for share in [0.1, 0.6, 1.0, 1.4, 1.9]:
			var state := _state(40.0 * scale * share, 40.0 * scale)
			var raw := float(WorldValues.measures(state)[WorldValues.REVENUE])
			rungs[MeasureRegistry.normalize(WorldValues.REVENUE, raw)] = true
		assert_true(rungs.size() >= 4,
			"at %fx the colony, five months produced %d distinct readings" % [scale, rungs.size()])


func test_a_collapse_reads_low_and_a_windfall_reads_high() -> void:
	var collapsed := float(WorldValues.measures(_state(4.0, 400.0))[WorldValues.REVENUE])
	var ordinary := float(WorldValues.measures(_state(400.0, 400.0))[WorldValues.REVENUE])
	var windfall := float(WorldValues.measures(_state(900.0, 400.0))[WorldValues.REVENUE])

	assert_true(collapsed < ordinary, "a month at a hundredth of normal did not read low")
	assert_true(windfall > ordinary, "a month at double normal did not read high")
	assert_almost_eq(MeasureRegistry.normalize(WorldValues.REVENUE, ordinary), 0.5, 0.001,
		"an ordinary month is not in the middle of the ladder")


# --- The running normal -----------------------------------------------------

func test_the_first_month_of_trade_becomes_the_normal() -> void:
	# There is nothing to follow yet, so a colony that has just started trading
	# is not judged against a figure it has never met.
	var state := WorldValues.initial_state()
	state.values[WorldValues.REVENUE_BASELINE] = 0.0
	assert_almost_eq(WorldValues.followed_baseline(state, 90.0), 90.0, 0.001)


func test_the_normal_follows_without_chasing() -> void:
	# **One good month does not become the new expectation**, or a colony that
	# had a windfall spends the next year being told it is doing badly.
	var state := _state(0.0, 100.0)
	var after := WorldValues.followed_baseline(state, 500.0)
	assert_true(after > 100.0, "the normal did not move at all")
	assert_true(after < 300.0, "one month at five times normal dragged the normal to %f" % after)


func test_the_normal_arrives_where_the_colony_is() -> void:
	# A colony that has genuinely grown stops being judged against what it was.
	var state := _state(0.0, 100.0)
	var baseline := 100.0
	for _month in 40:
		state.values[WorldValues.REVENUE_BASELINE] = baseline
		baseline = WorldValues.followed_baseline(state, 800.0)
	assert_almost_eq(baseline, 800.0, 10.0,
		"forty months at eight times the old normal left the normal at %f" % baseline)


func test_a_colony_that_has_never_traded_does_not_divide_by_nothing() -> void:
	var state := WorldValues.initial_state()
	state.values[WorldValues.REVENUE] = 0.0
	state.values[WorldValues.REVENUE_BASELINE] = 0.0
	var reading := float(WorldValues.measures(state)[WorldValues.REVENUE])
	assert_true(is_finite(reading), "an untraded colony read as %f" % reading)
	assert_almost_eq(reading, 0.0, 0.001)


# --- A town against the colony it is part of --------------------------------

func _colony(traded: Array) -> Colony:
	var colony := Colony.new()
	for index in traded.size():
		var town := Town.new(StringName("town_%d" % index), "Town %d" % index, Vector2i(index, 0))
		town.workers = 10
		town.traded_value = float(traded[index])
		colony.add(town)
	return colony


func test_a_town_pulling_its_weight_reads_the_same_at_any_size() -> void:
	# A hundred gold of business is a busy month for a hamlet and nothing at all
	# for a port. A governor calling his month brisk means brisk for the place he
	# governs.
	for amount in [10.0, 100.0, 100_000.0]:
		var colony := _colony([amount, amount, amount])
		var standing := ColonyMeasures.trade_standing(colony, colony.in_order()[0])
		assert_almost_eq(standing, ColonyMeasures.AVERAGE_TOWN, 0.001,
			"a town trading its exact share at %f read as %f" % [amount, standing])


func test_a_busy_town_outreads_a_quiet_one() -> void:
	var colony := _colony([300.0, 100.0])
	var busy := ColonyMeasures.trade_standing(colony, colony.in_order()[0])
	var quiet := ColonyMeasures.trade_standing(colony, colony.in_order()[1])

	assert_true(busy > quiet)
	assert_almost_eq(busy + quiet, 2.0 * ColonyMeasures.AVERAGE_TOWN, 0.001,
		"the shares do not add up to the colony")


func test_a_colony_that_traded_nothing_reads_nothing() -> void:
	var colony := _colony([0.0, 0.0])
	assert_almost_eq(ColonyMeasures.trade_standing(colony, colony.in_order()[0]), 0.0, 0.001)
	assert_almost_eq(ColonyMeasures.trade_standing(null, colony.in_order()[0]), 0.0, 0.001)


# --- 🔒 No measure is pinned to a quantity ----------------------------------

func test_no_measure_is_normalised_against_a_raw_quantity() -> void:
	# **The guard this ticket is really asking for.** Every measure is either
	# already a ratio or bounded by something that does not grow with the colony
	# — a share, a rate, or a synthetic 0-100 scale. A measure registered against
	# a number of gold or a number of bushels will say one word for ever.
	var bounded: PackedStringArray = [
		"food_security",          # stockpile over consumption
		"quality_of_life",        # a share, by definition
		"tax_burden",             # a rate, 0 to 1
		# **A mean over towns, not a total** (#174), so it reads the same in a
		# colony of one town and a colony of ten — which is what keeps the
		# Provost's ladder reachable for the whole run.
		WorldValues.EDUCATION,
		"colony_revenue",         # duty against what a month lately brings
		"crown_war_intensity",    # the Crown's war, not the colony's size
		"supply_situation",       # a synthetic 0-100 condition
		ColonyMeasures.OBJECTIVE_PROGRESS,
		ColonyMeasures.STOCKPILE_HEALTH,
		ColonyMeasures.TRADE_VOLUME,
		# **A standing on a fixed nought-to-a-hundred scale** (#208), like the
		# Crown's war. It does not grow with the colony because it is not a
		# quantity of anything — it is what one people think of another.
		ColonyMeasures.NATIVE_REGARD,
		# **A share of this town's own ground**, so a town of four hundred with a
		# village in its fields reads the same as a town of forty with one.
		ColonyMeasures.NATIVE_PRESSURE,
	]
	for id in MeasureRegistry.ids():
		assert_true(bounded.has(String(id)),
			"'%s' is registered and nothing says what it is normalised against" % id)


func test_the_gold_measures_are_registered_as_ratios() -> void:
	# A ratio of one is an ordinary month, so an ordinary month sits in the
	# middle of whatever ladder a letter hangs on it.
	assert_almost_eq(MeasureRegistry.normalize(WorldValues.REVENUE, 1.0), 0.5, 0.001)
	assert_almost_eq(
		MeasureRegistry.normalize(ColonyMeasures.TRADE_VOLUME, ColonyMeasures.AVERAGE_TOWN),
		0.5,
		0.001,
	)


# --- Truth is untouched -----------------------------------------------------

func test_the_exact_figure_is_still_exact() -> void:
	# §4a: nothing is lost, because `{param:}` carries the true figure and always
	# did. The judgement is relative; the number is not.
	var state := _state(4_000.0, 400.0)
	assert_almost_eq(float(state.get_value(WorldValues.REVENUE, 0.0)), 4_000.0, 0.001,
		"the world value was rewritten into a ratio")

	var context := LetterContext.new(state, null, &"")
	assert_eq(
		int(M1ParamSources.scaled_world_value(
			{"key": WorldValues.REVENUE, "factor": 1.0, "minimum": 0.0, "maximum": 99_999.0},
			context,
		)),
		4_000,
	)
