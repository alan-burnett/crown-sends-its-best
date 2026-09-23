extends TestCase

## The bar the Crown holds the colony to, and what moves it (#69, #339,
## `docs/mechanics/crown-demands.md` §§1, 2, 6, 7).
##
## 🔒 Three properties are locked here and none is a balance number.
##
## **Year one does not grow.** The early squeeze is a level set above a young
## colony's output, not a curve. A dev implementing "demands grow over time" as
## a curve from month one produces a very different game.
##
## **Twice a year from year two, on months nobody can learn** (#339). The months
## are drawn from a named stream and kept with the save, so a player cannot bank
## against the next turn of the screw and a reload cannot move it.
##
## **The bucket's guarantee.** Drawing an axis at random will sometimes pick the
## same one five times running, which produces a run far harder or far easier
## than the design intends through no decision the player made. Aberrant runs
## poison tuning and scoring, because the best scores start coming from lucky
## seeds rather than good play.

const SEEDS: int = 400
const YEARS: int = 40
const MONTHS: int = 12


func _growth() -> DemandGrowth:
	return DemandGrowth.new()


## Call the growth for every month in `[from, to)`, as `CrownAffairs` does.
func _months(growth: DemandGrowth, streams: RngStreams, from: int, to: int) -> void:
	for month in range(from, to):
		growth.advance(month / MONTHS + 1, streams, null, month)


## A whole run's growth, month by month.
func _grown(seed_value: int, years: int) -> DemandGrowth:
	var growth := DemandGrowth.new()
	_months(growth, RngStreams.new(seed_value), 0, years * MONTHS)
	return growth


func _run(seed_value: int, years: int) -> PackedStringArray:
	return _grown(seed_value, years).history


# --- 🔒 The first era is a level ---------------------------------------------

func test_nothing_grows_in_year_one() -> void:
	var growth := _growth()
	_months(growth, RngStreams.new(7), 0, MONTHS)
	assert_false(growth.has_begun(), "the bar moved in year one")
	for dimension in DemandGrowth.DIMENSIONS:
		assert_eq(growth.level_of(StringName(dimension)), 0,
			"%s grew in year one" % dimension)


func test_the_bar_is_the_same_all_through_year_one() -> void:
	# Stated on the bar rather than on the levels, because it is the bar the
	# player feels and a future growth term could move it without touching a
	# level.
	var growth := _growth()
	var opening := DemandSchedule.bar(growth)
	_months(growth, RngStreams.new(7), 0, MONTHS)
	assert_eq(str(DemandSchedule.bar(growth)), str(opening),
		"a year passed and the Crown asked for something different")


func test_the_bar_moves_twice_in_year_two() -> void:
	# 🔒 *Two draws a year, from year two* — §7, the Author's ruling on #339.
	# Stated as the number rather than the constant, because a test that read
	# `DRAWS_PER_YEAR` would agree with whatever the constant said.
	var growth := _growth()
	_months(growth, RngStreams.new(7), 0, 2 * MONTHS)
	assert_eq(growth.history.size(), 2, "year two drew %d times" % growth.history.size())


# --- 🔒 Twice a year, on months nobody can learn -----------------------------

func test_a_month_grows_once_however_often_the_driver_runs() -> void:
	# A bar that moved every time the driver was called would be the ramp the doc
	# explicitly rejects, arrived at by accident.
	var growth := _growth()
	var streams := RngStreams.new(7)
	for month in range(MONTHS, 2 * MONTHS):
		for _call in 3:
			growth.advance(2, streams, null, month)
	assert_eq(growth.history.size(), DemandGrowth.DRAWS_PER_YEAR,
		"year two grew %d times" % growth.history.size())


func test_every_year_from_the_second_grows_exactly_twice() -> void:
	var growth := _grown(11, 20)
	for year in range(2, 21):
		assert_eq(growth.drawn_in(year).size(), 2,
			"year %d grew %d times" % [year, growth.drawn_in(year).size()])


func test_the_two_months_are_different_months() -> void:
	for seed_value in 60:
		var growth := _grown(seed_value, 6)
		for at in range(1, growth.drawn_months.size()):
			assert_ne(growth.drawn_months[at], growth.drawn_months[at - 1],
				"seed %d grew twice in month %d" % [seed_value, growth.drawn_months[at]])


func test_the_months_are_drawn_rather_than_fixed() -> void:
	# 🔒 The point of drawing them: a fixed half-yearly clock is one a player
	# learns and banks against.
	var seen: Dictionary = {}
	for seed_value in 40:
		var growth := _grown(seed_value, 3)
		seen[posmod(growth.drawn_months[0], MONTHS)] = true
	assert_true(seen.size() >= 4,
		"forty runs met the first turn of the screw in only %d different months" % seen.size())


func test_the_months_come_from_their_own_stream() -> void:
	# Named streams per `CLAUDE.md`: how many dice the rest of the world throws
	# must not move the Crown's calendar.
	var quiet := _grown(31, 6)
	var busy := DemandGrowth.new()
	var streams := RngStreams.new(31)
	for month in 6 * MONTHS:
		streams.stream(&"sim").randi()
		busy.advance(month / MONTHS + 1, streams, null, month)
	assert_eq(Array(busy.drawn_months), Array(quiet.drawn_months),
		"the rest of the world's dice moved the months the bar grows in")
	assert_eq(Array(busy.history), Array(quiet.history))


# --- 🔒 The bucket's guarantee -----------------------------------------------

func test_the_same_axis_never_comes_five_draws_running() -> void:
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
		assert_false(drawn.is_empty(), "no draws at all on seed %d" % seed_value)

	assert_true(worst < 5,
		"seed %d drew the same axis %d times running" % [worst_seed, worst])


func test_no_axis_is_drawn_more_than_twice_in_a_bucket() -> void:
	# The guarantee stated where it actually holds: within one bucket's four
	# draws, since the bucket never holds more than two of anything.
	#
	# **It does not hold across a refill.** Two at the end of one bucket and two
	# at the start of the next is four consecutive draws on one axis, which is
	# reachable.
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


# --- 🔒 More hands out, and whose (#339) -------------------------------------

func test_every_hand_the_squeeze_puts_out_is_somebody() -> void:
	# Every `reach` draw produces a source while any has room — a draw of *more
	# hands out* that put out nobody's hand would be a turn of the screw the
	# player never feels.
	var room := 0
	for source in DemandGrowth.SOURCES:
		room += DemandSchedule.room_for(StringName(source))
	for seed_value in 60:
		var growth := _grown(seed_value, YEARS)
		assert_eq(growth.sources.size(), mini(growth.level_of(DemandGrowth.REACH), room),
			"seed %d drew reach %d times and put out %d hands" % [
				seed_value, growth.level_of(DemandGrowth.REACH), growth.sources.size()])


func test_any_of_the_three_can_come_first() -> void:
	# 🔒 **There is no ladder.** The first hand a run meets may be a patron's; it
	# may equally be a duke's or a Crown officer's.
	var first: Dictionary = {}
	for seed_value in SEEDS:
		var growth := _grown(seed_value, YEARS)
		if not growth.sources.is_empty():
			first[growth.sources[0]] = true
	for source in DemandGrowth.SOURCES:
		assert_true(first.has(source), "no run ever met a %s first" % source)


func test_no_source_outgrows_the_room_the_world_has() -> void:
	# A fourth duke does not exist, however long the run.
	for seed_value in 60:
		var growth := _grown(seed_value, YEARS)
		for source in DemandGrowth.SOURCES:
			assert_true(growth.sources_of(StringName(source))
				<= DemandSchedule.room_for(StringName(source)),
				"seed %d put out %d %s hands" % [
					seed_value, growth.sources_of(StringName(source)), source])


# --- 🔒 The run's future does not change on a reload -------------------------

func test_the_growth_survives_a_round_trip() -> void:
	# SPEC §16.1: seeded generation is locked, and the bucket, the calendar and
	# the hands already out are all part of the run's future.
	var growth := _grown(23, 9)
	var restored := DemandGrowth.from_dict(growth.to_dict())
	assert_eq(restored.to_dict(), growth.to_dict(), "the growth came back different")


func test_reloading_does_not_change_what_comes_next() -> void:
	# **The property that matters**, as opposed to the round trip above: a run
	# saved partway through a year and resumed must grow in the months, along
	# the axes and through the hands it would have had it never stopped. Saved
	# mid-year on purpose, because this year's months are drawn once.
	var straight := _grown(23, 15)

	var interrupted := DemandGrowth.new()
	var streams := RngStreams.new(23)
	_months(interrupted, streams, 0, 6 * MONTHS + 5)

	var resumed := DemandGrowth.from_dict(interrupted.to_dict())
	_months(resumed, RngStreams.from_dict(streams.to_dict()), 6 * MONTHS + 5, 15 * MONTHS)

	assert_eq(resumed.to_dict(), straight.to_dict(),
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


func test_askers_counts_the_hands_out() -> void:
	# A count for the log and the harness, and nothing gates on it (#339).
	var growth := _growth()
	var alone := DemandSchedule.askers(growth)
	growth.sources.append(String(DemandGrowth.SOURCE_PATRON))
	assert_eq(DemandSchedule.askers(growth), alone + 1, "a hand went out and was not counted")
