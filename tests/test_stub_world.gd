extends TestCase

## The stub world (#20). Its only job is to produce enough month-to-month
## variety that letters genuinely differ.

const SEED: int = 20_260_918


func _run(months: int, seed_value: int = SEED) -> Dictionary:
	var state := StubWorld.initial_state()
	var log := EventLog.new()
	var streams := RngStreams.new(seed_value)
	var month := WorldMonth.new(IntentBook.new(), streams)
	month.drivers = [StubWorld.new()]
	month.executors = [StubIntentExecutor.new()]

	var history: Array = []
	for i in months:
		month.run(state, log)
		history.append(StubWorld.measures(state))
	return {"state": state, "log": log, "history": history, "month": month, "streams": streams}


func test_twelve_turns_look_different() -> void:
	# If it were static the playtest would test nothing: the Author would read the
	# same four letters twelve times and correctly conclude the game is dull.
	var history: Array = _run(12)["history"]
	var seen: Dictionary = {}
	for snapshot in history:
		seen[Canonical.hash_of(snapshot)] = true
	assert_eq(seen.size(), 12, "twelve months produced %d distinct situations" % seen.size())


func test_the_situation_gets_better_and_worse() -> void:
	# Not a ramp in one direction. Things have to recover as well as decay, or
	# there is no month where a letter brings good news.
	var history: Array = _run(24)["history"]
	var rose := false
	var fell := false
	for index in range(1, history.size()):
		var change: float = history[index][StubWorld.SUPPLY] - history[index - 1][StubWorld.SUPPLY]
		if change > 0.0:
			rose = true
		if change < 0.0:
			fell = true
	assert_true(rose, "supply never improved")
	assert_true(fell, "supply never worsened")


func test_values_push_on_each_other() -> void:
	# Not "hold some numbers": the war has to actually cost the colony something,
	# or the Marshal and the Steward have nothing to disagree about.
	#
	# Compared as thirds rather than against fixed thresholds, so the test asks
	# whether the coupling exists rather than whether a tuning value landed in a
	# particular band.
	var history: Array = _run(48)["history"]
	history.sort_custom(func(a, b): return float(a[StubWorld.WAR]) < float(b[StubWorld.WAR]))

	var third: int = history.size() / 3
	var calm := _mean_supply(history.slice(0, third))
	var fierce := _mean_supply(history.slice(history.size() - third, history.size()))

	assert_true(fierce < calm,
		"supply averaged %f in the fiercest third of months and %f in the calmest" % [fierce, calm])


func _mean_supply(months: Array) -> float:
	if months.is_empty():
		return 0.0
	var total: float = 0.0
	for snapshot in months:
		total += float(snapshot[StubWorld.SUPPLY])
	return total / float(months.size())


func test_a_campaign_begins_and_ends() -> void:
	var log: EventLog = _run(36)["log"]
	assert_not_empty(log.of_type(StubWorld.EVENT_CAMPAIGN_BEGAN), "no campaign ever began")
	assert_not_empty(log.of_type(StubWorld.EVENT_CAMPAIGN_ENDED), "no campaign ever ended")


func test_it_is_deterministic_for_a_seed() -> void:
	assert_eq(_run(12)["state"].state_hash(), _run(12)["state"].state_hash())


func test_different_seeds_diverge() -> void:
	assert_ne(_run(12, SEED)["state"].state_hash(), _run(12, SEED + 1)["state"].state_hash())


func test_it_emits_real_events_in_real_phases() -> void:
	# The correspondence layer must not be able to tell it is a stub, so the
	# events and their phases are the ones the real sim will use.
	var log: EventLog = _run(3)["log"]
	assert_not_empty(log.of_type(StubWorld.EVENT_WAR_MOVED))
	assert_not_empty(log.of_type(StubWorld.EVENT_COLONY_SETTLED))
	assert_eq(log.of_type(StubWorld.EVENT_WAR_MOVED)[0].phase, WorldPhase.CROWNS_MONTH)
	assert_eq(log.of_type(StubWorld.EVENT_COLONY_SETTLED)[0].phase, WorldPhase.COLONY_MONTH)


func test_it_produces_a_real_diff() -> void:
	var state := StubWorld.initial_state()
	var log := EventLog.new()
	var month := WorldMonth.new(IntentBook.new(), RngStreams.new(SEED))
	month.drivers = [StubWorld.new()]
	var diff := month.run(state, log)
	assert_false(diff.is_empty())
	assert_true(diff.has_change("month"))


func test_it_supplies_the_measures_the_letters_judge() -> void:
	var measures := StubWorld.measures(StubWorld.initial_state())
	for id in [StubWorld.WAR, StubWorld.REVENUE, StubWorld.SUPPLY, StubWorld.FOOD]:
		assert_true(measures.has(id), "no measure '%s'" % id)


func test_a_decision_changes_the_following_month() -> void:
	# An Intent committed in one month executes in the next, so a player decision
	# is acknowledged before it takes effect.
	var state := StubWorld.initial_state()
	var log := EventLog.new()
	var book := IntentBook.new()
	var month := WorldMonth.new(book, RngStreams.new(SEED))
	month.drivers = [StubWorld.new()]
	month.executors = [StubIntentExecutor.new()]

	var untouched := StubWorld.initial_state()
	var untouched_log := EventLog.new()
	var untouched_month := WorldMonth.new(IntentBook.new(), RngStreams.new(SEED))
	untouched_month.drivers = [StubWorld.new()]
	untouched_month.executors = [StubIntentExecutor.new()]

	book.commit(Intent.new(
		&"", StubIntentExecutor.KIND, &"marshal", StubWorld.SUPPLY, 1, {"per_month": 25.0}
	), log, state.month)

	month.run(state, log)
	untouched_month.run(untouched, untouched_log)

	assert_ne(
		float(state.get_value(StubWorld.SUPPLY)),
		float(untouched.get_value(StubWorld.SUPPLY)),
		"the decision left no mark on the world",
	)
