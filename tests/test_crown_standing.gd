extends TestCase

## Crown standing (#67, `docs/mechanics/crown-standing.md`).
##
## **The PC never has to clear the debt.** He has to look like he is on track to,
## which is why recovery reads off the horizon and not off the size of the hole.
## Most of what is worth locking here is that one idea and its consequences.

const SEED: int = 1649


func _standing(at: float, position: float = 0.0) -> CrownStanding:
	var standing := CrownStanding.new()
	standing.standing = at
	standing.net_position = position
	standing.band = CrownStanding.band_of(at)
	return standing


# --- 🔒 The horizon governs recovery ----------------------------------------

func test_equal_profit_and_unequal_debt_recover_at_different_rates() -> void:
	# The doc's own worked pair. Identical profit, opposite verdicts: the
	# thrifty player is recovering nicely, the spendthrift is not seriously
	# trying.
	var thrifty := _standing(30.0, -500.0)
	var spendthrift := _standing(30.0, -50_000.0)

	var one := thrifty.advance(100.0, 50.0)
	var other := spendthrift.advance(100.0, 50.0)

	assert_almost_eq(float(one["monthly_net"]), float(other["monthly_net"]), 0.001,
		"the fixture did not give them equal profit")
	assert_true(float(one["delta"]) > float(other["delta"]),
		"a shallow hole climbed at %f and a deep one at %f" % [one["delta"], other["delta"]])


func test_a_deep_hole_crawls_but_does_not_stop() -> void:
	# **The floor must not be zero.** Without it a player who is genuinely
	# profitable but catastrophically deep is pinned below the threshold for
	# ever with no route back, and the only remaining move is retirement.
	var hopeless := _standing(5.0, -10_000_000.0)
	var moved := hopeless.advance(100.0, 1.0)

	assert_true(float(moved["horizon"]) > CrownStanding.H_MAX,
		"the fixture is not deep enough to be testing the floor")
	assert_true(float(moved["delta"]) > 0.0,
		"a profitable colony in a deep hole did not climb at all")


func test_no_hole_at_all_climbs_at_the_full_rate() -> void:
	var solvent := _standing(50.0, 2_000.0)
	var moved := solvent.advance(100.0, 10.0)
	assert_almost_eq(float(moved["horizon"]), 0.0, 0.001)
	assert_almost_eq(float(moved["delta"]), CrownStanding.K_RISE, 0.001)


func test_the_climb_is_faster_once_confidence_is_lost() -> void:
	# So that getting back is achievable rather than theoretical.
	var lost := _standing(CrownStanding.ALARM - 1.0)
	var warned := _standing(CrownStanding.ALARM + 1.0)

	var one := lost.advance(100.0, 10.0)
	var other := warned.advance(100.0, 10.0)
	assert_true(float(one["delta"]) > float(other["delta"]),
		"climbing out of lost standing was no faster than climbing within alarm")


# --- Falling ----------------------------------------------------------------

func test_falling_scales_with_what_the_colony_earns() -> void:
	# **A hundred gold of overspend hurts a small colony more than a large one**,
	# because the burn ratio is relative to what is actually coming in.
	var small := _standing(80.0)
	var large := _standing(80.0)

	small.advance(50.0, 150.0)
	large.advance(5_000.0, 5_100.0)

	assert_true(small.standing < large.standing,
		"the same hundred of overspend cost a hamlet %f and a province %f" % [
			small.standing, large.standing])


func test_it_may_crash_from_comfortable_to_nothing_in_one_month() -> void:
	# The doc is explicit that nothing stops this, and that it is safe *because*
	# refusal is a separate machine with its own gate (#68).
	var comfortable := _standing(CrownStanding.START)
	comfortable.advance(40.0, 40_000.0)

	assert_almost_eq(comfortable.standing, 0.0, 0.001,
		"a catastrophic promise left standing at %f" % comfortable.standing)
	assert_eq(String(comfortable.band), String(CrownStanding.BAND_LOST))


func test_a_quiet_month_moves_nothing() -> void:
	# No trade and no spending is not a judgement either way.
	var idle := _standing(55.0)
	idle.advance(0.0, 0.0)
	assert_almost_eq(idle.standing, 55.0, 0.001)


func test_breaking_even_does_not_climb() -> void:
	var level := _standing(55.0)
	level.advance(100.0, 100.0)
	assert_almost_eq(level.standing, 55.0, 0.001,
		"a month that paid for itself exactly was treated as profit")


# --- 🔒 Below the threshold is one flat band --------------------------------

func test_nothing_varies_within_lost_standing() -> void:
	# A standing of 19 and a standing of 0 behave identically. What separates a
	# warned PC from a cut-off one is the refusal machine, not the number.
	for value in [0.0, 1.0, 9.0, 19.0, 19.99]:
		assert_eq(String(CrownStanding.band_of(value)), String(CrownStanding.BAND_LOST),
			"%f is not in the flat band" % value)
		assert_true(_standing(value).has_lost_confidence())

	var deepest := _standing(0.0)
	var shallowest := _standing(19.0)
	assert_almost_eq(deepest.rise_rate(), shallowest.rise_rate(), 0.001,
		"the flat band is not flat: recovery differs within it")


func test_the_bands_are_where_the_doc_puts_them() -> void:
	assert_eq(String(CrownStanding.band_of(100.0)), String(CrownStanding.BAND_CONTENT))
	assert_eq(String(CrownStanding.band_of(60.0)), String(CrownStanding.BAND_CONTENT))
	assert_eq(String(CrownStanding.band_of(59.9)), String(CrownStanding.BAND_CONCERN))
	assert_eq(String(CrownStanding.band_of(40.0)), String(CrownStanding.BAND_CONCERN))
	assert_eq(String(CrownStanding.band_of(39.9)), String(CrownStanding.BAND_ALARM))
	assert_eq(String(CrownStanding.band_of(20.0)), String(CrownStanding.BAND_ALARM))
	assert_eq(String(CrownStanding.band_of(19.9)), String(CrownStanding.BAND_LOST))


func test_it_never_leaves_its_range() -> void:
	var high := _standing(99.5, 10_000.0)
	for _month in 20:
		high.advance(500.0, 1.0)
	assert_true(high.standing <= CrownStanding.MAXIMUM)

	var low := _standing(1.0)
	for _month in 20:
		low.advance(10.0, 5_000.0)
	assert_true(low.standing >= 0.0)


# --- Political credit, alongside the arithmetic -----------------------------

func test_a_discrete_adjustment_moves_it_and_rebands() -> void:
	# Meeting a Crown demand is worth more than the gold; missing one costs more
	# than the revenue (doc §6). The demands are #69; this is the door.
	var standing := _standing(CrownStanding.CONCERN + 1.0)
	standing.adjust(-5.0)
	assert_eq(String(standing.band), String(CrownStanding.BAND_ALARM),
		"an adjustment moved the number without moving the band")


# --- Saving -----------------------------------------------------------------

func test_it_survives_save_and_reload() -> void:
	var standing := _standing(33.0, -1_234.0)
	var restored := CrownStanding.from_dict(standing.to_dict())

	assert_almost_eq(restored.standing, 33.0, 0.001)
	assert_almost_eq(restored.net_position, -1_234.0, 0.001)
	assert_eq(String(restored.band), String(CrownStanding.BAND_ALARM))


func test_a_run_carries_it_through_a_round_trip() -> void:
	var run := RunState.new_run(SEED)
	run.standing.standing = 41.0
	run.standing.net_position = -900.0

	var restored := RunState.from_dict(run.to_dict())
	assert_almost_eq(restored.standing.standing, 41.0, 0.001)
	assert_almost_eq(restored.standing.net_position, -900.0, 0.001)


# --- 🔒 The number never leaves the sim -------------------------------------

func test_the_month_it_emits_carries_a_band_and_not_a_number() -> void:
	# A payload carrying the figure is a payload a letter could render, and SPEC
	# §10.3 makes the four bands the whole interface.
	var log := EventLog.new()
	var state := WorldValues.initial_state()
	state.month = 3
	var driver := CrownStandingDriver.new(_standing(70.0))
	driver.on_phase(WorldPhase.RUN_END_CHECK, state, log, RngStreams.new(SEED))

	var events: Array = log.of_type(CrownStanding.EVENT_MOVED)
	assert_eq(events.size(), 1, "the Crown did not think about the PC at all")
	assert_has(events[0].payload, "band")
	assert_false(events[0].payload.has("standing"),
		"the standing figure was put on the event log where a letter could read it")
	assert_false(events[0].payload.has("after"))


func test_it_judges_only_in_its_own_phase() -> void:
	var log := EventLog.new()
	var driver := CrownStandingDriver.new(_standing(70.0))
	for phase in WorldPhase.ORDER:
		if phase != WorldPhase.RUN_END_CHECK:
			driver.on_phase(phase, WorldValues.initial_state(), log, RngStreams.new(SEED))
	assert_empty(log.of_type(CrownStanding.EVENT_MOVED))
