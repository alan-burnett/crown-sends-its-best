extends TestCase

## The bar the Crown holds the colony to, and what moves it (#69,
## `docs/mechanics/crown-demands.md` §§1, 2, 7).
##
## 🔒 Two properties are locked here and neither is a balance number.
##
## **Years one to three do not grow.** The early squeeze is a level set above a
## young colony's output, not a curve. A dev implementing "demands grow over
## time" as a curve from month one produces a very different game, and nothing
## else in the code says otherwise.
##
## **The bucket's guarantee.** Drawing one axis a year at random will sometimes
## pick the same one five years running, which produces a run far harder or far
## easier than the design intends through no decision the player made. Aberrant
## runs poison tuning and scoring, because the best scores start coming from
## lucky seeds rather than good play.

const SEEDS: int = 400
const YEARS: int = 40


func _growth() -> DemandGrowth:
	return DemandGrowth.new()


func _run(seed_value: int, years: int) -> PackedStringArray:
	var growth := DemandGrowth.new()
	var streams := RngStreams.new(seed_value)
	var drawn: PackedStringArray = PackedStringArray()
	for year in range(1, years + 1):
		var axis := growth.advance(year, streams, null, year * 12)
		if String(axis) != "":
			drawn.append(String(axis))
	return drawn


# --- 🔒 The first era is a level ---------------------------------------------

func test_nothing_grows_before_year_four() -> void:
	var growth := _growth()
	var streams := RngStreams.new(7)
	for year in range(1, DemandGrowth.FIRST_GROWTH_YEAR):
		assert_eq(String(growth.advance(year, streams, null, year * 12)), "",
			"the bar moved in year %d" % year)
	assert_false(growth.has_begun(), "the bar had already started moving")
	for dimension in DemandGrowth.DIMENSIONS:
		assert_eq(growth.level_of(StringName(dimension)), 0,
			"%s grew before year four" % dimension)


func test_the_bar_is_the_same_in_year_one_and_year_three() -> void:
	# Stated on the bar rather than on the levels, because it is the bar the
	# player feels and a future growth term could move it without touching a
	# level.
	var growth := _growth()
	var streams := RngStreams.new(7)
	var opening := DemandSchedule.bar(growth)
	for year in range(1, DemandGrowth.FIRST_GROWTH_YEAR):
		growth.advance(year, streams, null, year * 12)
	assert_eq(str(DemandSchedule.bar(growth)), str(opening),
		"three years passed and the Crown asked for something different")


func test_the_bar_moves_in_year_four() -> void:
	var growth := _growth()
	var streams := RngStreams.new(7)
	for year in range(1, DemandGrowth.FIRST_GROWTH_YEAR + 1):
		growth.advance(year, streams, null, year * 12)
	assert_true(growth.has_begun(), "year four came and the bar did not move")
	assert_eq(growth.history.size(), 1, "year four drew more than once")


# --- 🔒 One draw a year ------------------------------------------------------

func test_a_year_grows_once_however_often_the_driver_runs() -> void:
	# The driver runs every month. A bar that moved twelve times a year would be
	# the ramp the doc explicitly rejects, arrived at by accident.
	var growth := _growth()
	var streams := RngStreams.new(7)
	for _month in 12:
		growth.advance(6, streams, null, 72)
	assert_eq(growth.history.size(), 1, "year six grew %d times" % growth.history.size())


func test_every_year_from_the_fourth_grows_exactly_once() -> void:
	var drawn := _run(11, 20)
	assert_eq(drawn.size(), 20 - DemandGrowth.FIRST_GROWTH_YEAR + 1,
		"seventeen growth years produced %d draws" % drawn.size())


# --- 🔒 The bucket's guarantee -----------------------------------------------

func test_the_same_axis_never_comes_five_years_running() -> void:
	# **The property the bucket exists for.** Asserted over many seeds because it
	# is a claim about the distribution, and a single seed proves nothing.
	var worst := 0
	var worst_seed := 0
	for seed_value in SEEDS:
		var drawn := _run(seed_value, YEARS)
		var run_length := 0
		var previous := ""
		for axis in drawn:
			run_length = run_length + 1 if String(axis) == previous else 1
			previous = String(axis)
			if run_length > worst:
				worst = run_length
				worst_seed = seed_value
		assert_true(run_length >= 0, "no draws at all on seed %d" % seed_value)

	assert_true(worst < 5,
		"seed %d drew the same axis %d years running" % [worst_seed, worst])


func test_no_axis_is_drawn_more_than_twice_in_a_bucket() -> void:
	# The guarantee stated where it actually holds: within one bucket's four
	# draws, since the bucket never holds more than two of anything.
	#
	# **It does not hold across a refill.** Two at the end of one bucket and two
	# at the start of the next is four consecutive years on one axis, which is
	# reachable — see the test below, which measures it rather than wishing it
	# away.
	for seed_value in 60:
		var drawn := _run(seed_value, YEARS)
		var block := 0
		while block * DemandGrowth.DRAWS_PER_REFILL < drawn.size():
			var counts: Dictionary = {}
			for at in range(
				block * DemandGrowth.DRAWS_PER_REFILL,
				mini((block + 1) * DemandGrowth.DRAWS_PER_REFILL, drawn.size()),
			):
				var axis := String(drawn[at])
				counts[axis] = int(counts.get(axis, 0)) + 1
				assert_true(int(counts[axis]) <= 2,
					"seed %d drew %s %d times in one bucket" % [
						seed_value, axis, int(counts[axis])])
			block += 1


func test_every_axis_is_reachable() -> void:
	# A dimension that never comes up is a quarter of the bucket wasted, and the
	# kind of thing a typo in the dimension list would cause silently.
	var seen: Dictionary = {}
	for seed_value in 40:
		for axis in _run(seed_value, YEARS):
			seen[String(axis)] = true
	for dimension in DemandGrowth.DIMENSIONS:
		assert_true(seen.has(String(dimension)), "%s was never drawn at all" % dimension)


# --- 🔒 The run's future does not change on a reload -------------------------

func test_the_bucket_survives_a_round_trip() -> void:
	# SPEC §16.1: seeded generation is locked, and the bucket is part of the
	# run's future. Ironman means there is no second chance to notice.
	var growth := _growth()
	var streams := RngStreams.new(23)
	for year in range(1, 10):
		growth.advance(year, streams, null, year * 12)

	var restored := DemandGrowth.from_dict(growth.to_dict())
	assert_eq(Array(restored.bucket), Array(growth.bucket), "the bucket came back different")
	assert_eq(Array(restored.history), Array(growth.history), "the history came back different")
	assert_eq(restored.last_drawn_year, growth.last_drawn_year)
	for dimension in DemandGrowth.DIMENSIONS:
		assert_eq(restored.level_of(StringName(dimension)),
			growth.level_of(StringName(dimension)), "%s came back at a different level" % dimension)


func test_reloading_does_not_change_what_comes_next() -> void:
	# **The property that matters**, as opposed to the round trip above: a run
	# saved in year seven and resumed must draw in years eight to fifteen exactly
	# what it would have drawn had it never stopped. The RNG stream is saved with
	# it, because the bucket alone is only half the future.
	var straight := DemandGrowth.new()
	var straight_streams := RngStreams.new(23)
	for year in range(1, 16):
		straight.advance(year, straight_streams, null, year * 12)

	var interrupted := DemandGrowth.new()
	var streams := RngStreams.new(23)
	for year in range(1, 8):
		interrupted.advance(year, streams, null, year * 12)

	var resumed := DemandGrowth.from_dict(interrupted.to_dict())
	var resumed_streams := RngStreams.from_dict(streams.to_dict())
	for year in range(8, 16):
		resumed.advance(year, resumed_streams, null, year * 12)

	assert_eq(Array(resumed.history), Array(straight.history),
		"a run saved in year seven came back with a different future")


# --- The bar responds to what grew -------------------------------------------

func test_frequency_brings_demands_closer_together_and_then_floors() -> void:
	var growth := _growth()
	var opening := DemandSchedule.months_between(growth)
	growth.levels[String(DemandGrowth.FREQUENCY)] = 1
	assert_true(DemandSchedule.months_between(growth) < opening,
		"a year of frequency growth did not bring demands any closer together")

	growth.levels[String(DemandGrowth.FREQUENCY)] = 50
	assert_true(DemandSchedule.months_between(growth) > 0.0,
		"growth drove the interval to nothing, which buries the desk (SPEC §9.6)")


func test_size_and_desperation_move_different_numbers() -> void:
	# **The reason the dimensions cannot be one number** (§8): a player who pays
	# everything never feels desperation, and a player who refuses everything
	# barely feels size.
	var bigger := _growth()
	bigger.levels[String(DemandGrowth.SIZE)] = 2
	var harsher := _growth()
	harsher.levels[String(DemandGrowth.DESPERATION)] = 2
	var steady := _growth()

	assert_true(DemandSchedule.gold_target(bigger) > DemandSchedule.gold_target(steady))
	assert_almost_eq(DemandSchedule.refusal_cost(bigger),
		DemandSchedule.refusal_cost(steady), 0.001,
		"growing what is asked also changed what refusing costs")

	assert_true(DemandSchedule.refusal_cost(harsher) > DemandSchedule.refusal_cost(steady))
	assert_almost_eq(DemandSchedule.gold_target(harsher),
		DemandSchedule.gold_target(steady), 0.001,
		"growing the price of refusal also changed what was asked")


func test_reach_adds_askers_up_to_a_ceiling() -> void:
	var growth := _growth()
	var alone := DemandSchedule.askers(growth)
	growth.levels[String(DemandGrowth.REACH)] = 1
	assert_true(DemandSchedule.askers(growth) > alone, "nobody new put a hand out")

	growth.levels[String(DemandGrowth.REACH)] = 50
	assert_true(DemandSchedule.askers(growth) <= 8,
		"reach grew without bound, and there are not that many people in the world yet")
