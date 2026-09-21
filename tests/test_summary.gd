extends TestCase

## The closing screen's two halves (#78, SPEC §6.3, §14.2).
##
## 🔒 **The recap reads the event log**, never a tally kept beside it. At the one
## moment there is no next month in which to notice a disagreement.
##
## 🔒 **Every way a run can end has an epitaph**, for every prestige band. The
## PC always goes to a comfortable retirement (SPEC §5) — that is not a
## consolation prize, it is the joke, and there is no outcome that withholds it.
##
## The screen itself is not tested. It is presentation and it will iterate.

const SEED: int = 6607

var content: ContentDatabase = null


func before_each() -> void:
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _received(run: RunState, month: int, amount: float) -> void:
	run.log.emit(Trade.EVENT_SOLD, &"ashmere", month, {
		"town": "ashmere", "resource": "furs", "sold": 1.0,
		"earned": amount, "tax": amount, "rate": 0.1,
	}, WorldPhase.COLONY_MONTH)


# --- 🔒 The recap reads the log ---------------------------------------------

func test_the_recap_counts_what_the_log_says_happened() -> void:
	var run := _run()
	run.world.month = 30
	for month in 4:
		run.log.emit(TradeProtest.EVENT_DECLARED, &"ashmere", month, {
			"town": "ashmere", "resource": "tea", "luxury": true, "rate": 0.8,
			"loudest": "rise", "running": ["tea"], "prestige": true,
		}, WorldPhase.COLONY_MONTH)
	run.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 12, {
		"town": "ashmere", "population": 40, "governor": "g",
	}, WorldPhase.COLONY_MONTH)
	run.log.emit(Immigration.EVENT_ARRIVED, &"ashmere", 5, {
		"town": "ashmere", "workers": 7, "experts": 1, "expert_in": "furs", "brought": 96.0,
	}, WorldPhase.ARRIVALS)
	_received(run, 6, 1_500.0)
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, run.world.month)

	var facts := RunSummary.of(run)
	assert_eq(int(facts["protests"]), 4, "the recap lost a protest")
	assert_eq(int(facts["rebellions"]), 1)
	assert_eq(int(facts["settlers"]), 8, "workers and experts both crossed the ocean")
	assert_almost_eq(float(facts["received"]), 1_500.0, 0.001)
	assert_eq(int(facts["months"]), 30)
	assert_eq(int(facts["years"]), 2)


func test_the_recap_reports_the_score_the_run_ended_on() -> void:
	# 🔒 Not recomputed here. The ending settled it (#77) and a second reckoning
	# could disagree with the one the save holds.
	var run := _run()
	_received(run, 1, 2_200.0)
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, 4)
	# Something happens after the run stopped, which must not change the score.
	_received(run, 5, 90_000.0)

	assert_almost_eq(float(RunSummary.of(run)["score"]), run.ending.score, 0.001,
		"the summary rescored a finished run")


func test_an_empty_run_still_summarises() -> void:
	# The pathological case, and the one most likely to be reached by accident: a
	# player who retires in month one must not get a blank page.
	var run := _run()
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, 0)
	var facts := RunSummary.of(run)
	assert_eq(int(facts["months"]), 0)
	assert_true(int(facts["towns"]) >= 1, "a run began with no colony at all")


# --- 🔒 Every ending has an epitaph -----------------------------------------

func test_every_outcome_and_band_resolves() -> void:
	# The content validator holds this too; here it is as a test, because a run
	# that ends on a blank screen is a bug nobody gets a second month to notice.
	for outcome in Epitaph.outcomes():
		for band in Prestige.band_names():
			var record := Epitaph.for_outcome(StringName(outcome), StringName(band), content)
			assert_false(record.is_empty(),
				"nothing to say about a run that ended '%s' at '%s'" % [outcome, band])
			assert_false(String(record.get("text", "")).strip_edges().is_empty(),
				"the epitaph for %s/%s is blank" % [outcome, band])


func test_the_exact_band_beats_the_general_one() -> void:
	# The general form is what makes an outcome cheap to give a floor to; the
	# sharpened ones are what make the band worth having.
	var celebrated := Epitaph.for_outcome(
		RunEnding.RETIRED, &"celebrated", content)
	var ruinous := Epitaph.for_outcome(RunEnding.RETIRED, &"ruinous", content)
	assert_true(String(celebrated.get("text", "")) != String(ruinous.get("text", "")),
		"a celebrated run and a ruinous one were sent home with the same words")


func test_a_ruinous_run_still_goes_home_comfortable() -> void:
	# 🔒 SPEC §5: **nothing in the game can harm the PC**, and every ending sends
	# him into comfort. There is no destitute epitaph and there never will be —
	# that is the joke, and it only works if it is never withheld.
	var run := _run()
	run.log.emit(PolicyBook.EVENT_BILLED, &"crown", 1, {
		"policy": "curriculum", "crown_paid": 200_000.0,
	}, WorldPhase.CROWNS_MONTH)
	for month in 6:
		run.log.emit(Rebellion.EVENT_DECLARED, StringName("town%d" % month), month, {
			"town": "town%d" % month, "population": 3, "governor": "g",
		}, WorldPhase.COLONY_MONTH)
	run.ending = RunEnding.end(RunEnding.FAILED, run.log, 60)

	assert_eq(String(Prestige.band_of(run.ending.score)), "ruinous",
		"the fixture was not ruinous, so this tests nothing")
	var text := String(Epitaph.for_ending(run.ending, content).get("text", ""))
	assert_false(text.is_empty(), "the worst run in the game was sent home with nothing")
	assert_true(text.to_lower().contains("house") or text.to_lower().contains("annuity"),
		"the worst ending did not put him somewhere comfortable, which SPEC 5 locks")


func test_the_bands_are_ordered_and_a_score_lands_in_one() -> void:
	assert_eq(String(Prestige.band_of(-999_999.0)), "ruinous")
	assert_eq(String(Prestige.band_of(0.0)), "obscure",
		"a run that broke exactly even fell off the bottom of the scale")
	assert_eq(String(Prestige.band_of(1.0e30)), "celebrated")


func test_an_ending_with_no_outcome_asks_for_nothing() -> void:
	# A run still in progress has no ending to write, and asking must not produce
	# a stray epitaph for it.
	assert_true(Epitaph.for_ending(RunEnding.new(), content).is_empty(),
		"an unfinished run already had an epitaph waiting")
