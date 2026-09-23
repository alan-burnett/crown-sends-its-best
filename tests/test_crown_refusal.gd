extends TestCase

## The refusal state machine (#68, `docs/mechanics/crown-standing.md` §3).
##
## **SPEC §10.3 locks it: the player always gets the Chancellor's warning before
## the Crown first refuses to honour his promised gold.** `CrownStanding` is
## deliberately built so that standing can fall from Content to nothing in a
## single month, so the guarantee cannot be kept by a threshold — it is kept
## here, by a gate.

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


func _standing(at: float) -> CrownStanding:
	var standing := CrownStanding.new()
	standing.standing = at
	standing.band = CrownStanding.band_of(at)
	return standing


## Run the process forward, holding standing where the test put it.
func _months(refusal: CrownRefusal, standing: CrownStanding, count: int, from: int = 1) -> Array:
	var happened: Array = []
	for index in count:
		var result := refusal.advance(standing, from + index)
		if not result.is_empty():
			happened.append(result)
	return happened


# --- 🔒 The gate ------------------------------------------------------------

func test_a_crash_from_content_to_nothing_still_gets_its_warning() -> void:
	# **The case a threshold check gets wrong**, and the reason this is a gate.
	# Standing is allowed to collapse in one month; the faucet is not.
	var refusal := CrownRefusal.new()
	var crashed := _standing(0.0)

	var first := refusal.advance(crashed, 1)
	assert_eq(String(first["event"]), String(CrownRefusal.EVENT_WARNED))
	assert_eq(String(refusal.state), String(CrownRefusal.WARNED))
	assert_true(refusal.pays(), "the Crown stopped paying the month standing collapsed")


func test_refusal_waits_for_the_full_countdown() -> void:
	var refusal := CrownRefusal.new()
	var lost := _standing(0.0)

	refusal.advance(lost, 1)  # the warning
	for month in range(2, 2 + CrownRefusal.WARNING_TURNS - 1):
		refusal.advance(lost, month)
		assert_true(refusal.pays(), "the faucet closed with %d turns still to run" % refusal.countdown)

	refusal.advance(lost, 1 + CrownRefusal.WARNING_TURNS)
	assert_eq(String(refusal.state), String(CrownRefusal.REFUSING))
	assert_false(refusal.pays())


func test_the_crown_pays_throughout_the_window() -> void:
	# **The window is the point**: two turns to make decisive commitments knowing
	# they will be paid, before the faucet closes.
	var refusal := CrownRefusal.new()
	var lost := _standing(0.0)
	refusal.advance(lost, 1)

	assert_true(refusal.is_warning())
	assert_true(refusal.pays(), "a warned Crown is still a paying Crown")


func test_the_warning_states_a_deadline_the_player_can_act_on() -> void:
	# A window the player cannot see is a trap rather than an opportunity.
	var refusal := CrownRefusal.new()
	var warned := refusal.advance(_standing(0.0), 7)

	assert_eq(int(warned["turns"]), CrownRefusal.WARNING_TURNS)
	assert_eq(int(warned["deadline_month"]), 7 + CrownRefusal.WARNING_TURNS)
	assert_eq(refusal.deadline_month, 7 + CrownRefusal.WARNING_TURNS)


func test_the_chancellor_writes_it_and_says_how_long() -> void:
	# The content half of the same guarantee. The letter must name the number of
	# letters the Treasury will still honour — no standing figure, but something
	# to count.
	var letter := Letter.from_record(content.record("letters", "chancellor.final_warning"))
	assert_true(letter != null, "there is no final warning letter")

	var body := ""
	for line in letter.body:
		body += String(line.get("text", ""))
	assert_true(body.contains("{param:turns}"),
		"the final warning does not tell the player how long he has")
	assert_false(letter.skippable, "the final warning can be set aside unread")


func test_the_warning_fires_only_on_the_month_the_window_opens() -> void:
	var refusal := CrownRefusal.new()
	var lost := _standing(0.0)
	var context := LetterContext.new(WorldValues.initial_state(), null, &"")
	context.refusal = refusal

	refusal.advance(lost, 1)
	assert_true(ColonyConditions.crown_opened_the_window({}, context))

	refusal.advance(lost, 2)
	assert_false(ColonyConditions.crown_opened_the_window({}, context),
		"the Chancellor writes the same final warning every month of the window")


# --- 🔒 A near miss is not a default ----------------------------------------

func test_clawing_back_inside_the_window_costs_no_grade() -> void:
	# **The grade drops on entering REFUSING, not on falling below the
	# threshold.** Charging him for a near miss would blunt the very thing the
	# window is for.
	var refusal := CrownRefusal.new()
	refusal.advance(_standing(0.0), 1)
	assert_eq(String(refusal.state), String(CrownRefusal.WARNED))

	var recovered := refusal.advance(_standing(CrownStanding.ALARM + 1.0), 2)

	assert_eq(String(refusal.state), String(CrownRefusal.SOLVENT))
	assert_true(bool(recovered["near_miss"]))
	assert_eq(refusal.cutoffs, 0, "a near miss was counted as a default")
	assert_almost_eq(refusal.restore_threshold, CrownRefusal.FIRST_RESTORE, 0.001)


func test_slipping_again_gets_a_fresh_warning_and_a_fresh_countdown() -> void:
	# So restoration is never immediately undone.
	var refusal := CrownRefusal.new()
	refusal.advance(_standing(0.0), 1)
	refusal.advance(_standing(CrownStanding.ALARM + 1.0), 2)

	var again := refusal.advance(_standing(0.0), 3)
	assert_eq(String(again["event"]), String(CrownRefusal.EVENT_WARNED))
	assert_eq(refusal.countdown, CrownRefusal.WARNING_TURNS)
	assert_true(refusal.pays())


# --- The perk (SPEC §5) -----------------------------------------------------

func test_the_perk_runs_the_cycle_a_second_time_and_is_spent_once() -> void:
	var refusal := CrownRefusal.new()
	refusal.has_grace = true
	var lost := _standing(0.0)

	var events := _months(refusal, lost, 1 + CrownRefusal.WARNING_TURNS * 2 + 1)
	var warnings := 0
	var refusals := 0
	for happened in events:
		if String(happened["event"]) == String(CrownRefusal.EVENT_WARNED):
			warnings += 1
		if String(happened["event"]) == String(CrownRefusal.EVENT_REFUSING):
			refusals += 1

	assert_eq(warnings, 2, "the perk did not buy a second warning")
	assert_eq(refusals, 1, "the faucet never closed")
	assert_true(refusal.grace_spent)


func test_the_second_warning_knows_it_is_the_last() -> void:
	var refusal := CrownRefusal.new()
	refusal.has_grace = true
	var lost := _standing(0.0)

	var first := refusal.advance(lost, 1)
	assert_false(bool(first["final"]), "the first warning claimed to be the last")

	var events := _months(refusal, lost, CrownRefusal.WARNING_TURNS, 2)
	assert_eq(events.size(), 1)
	assert_true(bool(events[0]["on_grace"]))
	assert_true(bool(events[0]["final"]), "the perk's warning did not read as final")


func test_without_the_perk_the_first_warning_is_the_last() -> void:
	var refusal := CrownRefusal.new()
	assert_true(bool(refusal.advance(_standing(0.0), 1)["final"]))


func test_the_perk_is_not_granted_by_default() -> void:
	# Run Setup (#79) grants it. Until then nobody has it, which is honest rather
	# than a quiet gift.
	assert_false(CrownRefusal.new().has_grace)


# --- 🔒 The credit grade ----------------------------------------------------

func _cut_off(refusal: CrownRefusal, month: int) -> int:
	var lost := _standing(0.0)
	for index in CrownRefusal.WARNING_TURNS + 1:
		refusal.advance(lost, month + index)
	return month + CrownRefusal.WARNING_TURNS + 1


func test_the_bar_rises_with_every_default_and_is_capped() -> void:
	# A credit rating losing a grade on every default. The arithmetic of recovery
	# does not change; the Crown requires more proof each time.
	var refusal := CrownRefusal.new()
	var month := 1
	var seen: Array = []

	for _default in 6:
		month = _cut_off(refusal, month)
		seen.append(refusal.restore_threshold)
		# Climb back out so the next collapse is a fresh default.
		refusal.advance(_standing(CrownRefusal.MAX_RESTORE + 1.0), month)
		month += 1

	assert_eq(seen.slice(0, 4), [35.0, 45.0, 55.0, 65.0])
	for threshold in seen:
		assert_true(float(threshold) <= CrownRefusal.MAX_RESTORE,
			"the bar rose past the cap to %f, which makes recovery impossible" % threshold)


func test_restoration_waits_for_the_raised_bar() -> void:
	var refusal := CrownRefusal.new()
	_cut_off(refusal, 1)
	assert_almost_eq(refusal.restore_threshold, CrownRefusal.FIRST_RESTORE, 0.001)

	# Out of the lost band, but not yet up to the bar.
	refusal.advance(_standing(CrownStanding.ALARM + 5.0), 9)
	assert_eq(String(refusal.state), String(CrownRefusal.REFUSING),
		"the Crown paid again before the PC reached the bar")

	refusal.advance(_standing(CrownRefusal.FIRST_RESTORE), 10)
	assert_eq(String(refusal.state), String(CrownRefusal.SOLVENT))
	assert_true(refusal.pays())


# --- What the rest of the game sees -----------------------------------------

func test_the_promise_driver_is_told_whether_the_crown_pays() -> void:
	var promises := PromiseDriver.new(PromiseBook.new())
	var refusal := CrownRefusal.new()
	var driver := CrownStandingDriver.new(_standing(0.0), refusal)
	driver.promises = promises

	var log := EventLog.new()
	var state := WorldValues.initial_state()
	for month in range(1, 2 + CrownRefusal.WARNING_TURNS + 1):
		state.month = month
		driver.on_phase(WorldPhase.RUN_END_CHECK, state, log, RngStreams.new(SEED))

	assert_eq(String(refusal.state), String(CrownRefusal.REFUSING))
	assert_false(promises.can_crown_pay, "the Crown refused and nobody told the promises")


func test_a_promise_paid_after_the_faucet_shuts_breaks() -> void:
	# **A promise is honoured when the Crown pays, not when it is made.** The
	# window resolves near-term commitments; it cannot be used to bank long ones.
	var book := PromiseBook.new()
	var log := EventLog.new()

	# Pledged during the window, falling due well after it.
	book.make(Promise.new(&"marshal", &"gold", {"amount": 500.0}, 1, 9), null, log, 1)
	book.settle_due({}, log, 9, false)

	assert_empty(log.of_type(PromiseBook.EVENT_KEPT),
		"a promise made in the window was honoured after the faucet shut")
	assert_not_empty(log.of_type(PromiseBook.EVENT_BROKEN))


func test_a_promise_paid_inside_the_window_is_honoured() -> void:
	var book := PromiseBook.new()
	var log := EventLog.new()
	book.make(Promise.new(&"marshal", &"gold", {"amount": 500.0}, 1, 2), null, log, 1)
	book.settle_due({}, log, 2, true)

	assert_not_empty(log.of_type(PromiseBook.EVENT_KEPT),
		"the window did not pay what was pledged inside it")


# --- Saving -----------------------------------------------------------------

func test_it_survives_save_and_reload() -> void:
	var refusal := CrownRefusal.new()
	refusal.has_grace = true
	_cut_off(refusal, 1)

	var restored := CrownRefusal.from_dict(refusal.to_dict())
	assert_eq(String(restored.state), String(refusal.state))
	assert_eq(restored.cutoffs, refusal.cutoffs)
	assert_almost_eq(restored.restore_threshold, refusal.restore_threshold, 0.001)
	assert_eq(restored.grace_spent, refusal.grace_spent)
	assert_eq(restored.pays(), refusal.pays())


func test_a_run_carries_it_through_a_round_trip() -> void:
	# No grace here: the perk buys two more months of window, and this test is
	# about serialisation rather than about the perk.
	var run := RunState.new_run(SEED)
	_cut_off(run.refusal, 1)

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(String(restored.refusal.state), String(CrownRefusal.REFUSING))
	assert_eq(restored.refusal.cutoffs, 1)
	assert_false(restored.refusal.pays())
