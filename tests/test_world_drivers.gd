extends TestCase

## The world's drivers: the Crown's month (#20, still a stand-in) and the colony
## month runner (#43).
##
## Their only job between them is to produce enough month-to-month variety that
## letters genuinely differ. If the world were static the playtest would test
## nothing.

const SEED: int = 20_260_918


## A colony driver with the drifting placeholder in Settle, which is what keeps
## the colony's numbers moving until #44 to #50 land.
func _colony_driver() -> ColonyDriver:
	# A colony with no towns is the Colony Overrun ending, not a normal state
	# (SPEC §13.1), so the fixture has one.
	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = 12
	colony.add(town)

	var driver := ColonyDriver.new(colony, null, SEED)
	driver.month.set_handler(ColonyMonth.SETTLE, SettlePhase.new())
	return driver


func _run(months: int, seed_value: int = SEED) -> Dictionary:
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var streams := RngStreams.new(seed_value)
	var month := WorldMonth.new(IntentBook.new(), streams)
	month.drivers = [CrownAffairs.new(), _colony_driver()]
	month.executors = [WorldValueExecutor.new()]

	var history: Array = []
	for i in months:
		month.run(state, log)
		history.append(WorldValues.measures(state))
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
		var change: float = history[index][WorldValues.SUPPLY] - history[index - 1][WorldValues.SUPPLY]
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
	# Compared as **month-on-month change**, not as levels. Supply is an
	# integrator — it carries the last month's damage into this one — so a calm
	# month in the middle of a recovery still reads low, and comparing levels
	# measures the lag rather than the coupling. What the war does is push supply
	# *down*, and that is what this asks.
	var history: Array = _run(48)["history"]

	var months: Array = []
	for index in range(1, history.size()):
		months.append({
			"war": float(history[index][WorldValues.WAR]),
			"change": float(history[index][WorldValues.SUPPLY])
				- float(history[index - 1][WorldValues.SUPPLY]),
		})
	months.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["war"]) < float(b["war"]))

	var third: int = months.size() / 3
	var calm := _mean_change(months.slice(0, third))
	var fierce := _mean_change(months.slice(months.size() - third, months.size()))

	assert_true(fierce < calm,
		"supply moved by %f a month in the fiercest third and %f in the calmest" % [fierce, calm])


func _mean_change(months: Array) -> float:
	if months.is_empty():
		return 0.0
	var total: float = 0.0
	for entry in months:
		total += float(entry["change"])
	return total / float(months.size())


func test_a_campaign_begins_and_ends() -> void:
	var log: EventLog = _run(36)["log"]
	assert_not_empty(log.of_type(CrownAffairs.EVENT_CAMPAIGN_BEGAN), "no campaign ever began")
	assert_not_empty(log.of_type(CrownAffairs.EVENT_CAMPAIGN_ENDED), "no campaign ever ended")


## The war after one month without a campaign, from `war`, with the Crown this
## far into its decline. The same seed every time, so the dice are the same and
## only the two inputs differ.
func _a_quiet_month(war: float, declined: int) -> float:
	var state := WorldValues.initial_state()
	state.values[WorldValues.WAR] = war
	state.values[WorldValues.CAMPAIGN_MONTHS_LEFT] = 0
	var affairs := CrownAffairs.new()
	affairs.growth = DemandGrowth.new()
	for _draw in declined:
		affairs.growth.history.append(String(DemandGrowth.SIZE))
	affairs._advance_war(state, EventLog.new(), RngStreams.new(SEED).stream(&"sim"))
	return float(state.get_value(WorldValues.WAR, 0.0))


func test_the_war_worsens_as_the_crown_declines() -> void:
	# 🔒 `the-marshal.md` §8, #376: *his war worsens on the same curve as the
	# Crown's decline.* A fixed cooling against a fixed climb was a ramp instead
	# — at its ceiling from about year four and a constant for the rest of the
	# run. Stated on the settling rather than on a number, so it holds however
	# the constants are tuned.
	assert_true(_a_quiet_month(50.0, 10) > _a_quiet_month(50.0, 0),
		"ten turns of the Crown's decline and its wars settle no higher")


func test_the_higher_the_war_the_faster_it_falls() -> void:
	# What makes it a curve rather than a ramp: the further above where it
	# settles, the more a quiet month takes off it.
	var from_high := 90.0 - _a_quiet_month(90.0, 0)
	var from_middling := 50.0 - _a_quiet_month(50.0, 0)
	assert_true(from_high > from_middling,
		"a quiet month took %.1f off a war at 90 and %.1f off one at 50"
			% [from_high, from_middling])


func test_it_is_deterministic_for_a_seed() -> void:
	assert_eq(_run(12)["state"].state_hash(), _run(12)["state"].state_hash())


func test_different_seeds_diverge() -> void:
	assert_ne(_run(12, SEED)["state"].state_hash(), _run(12, SEED + 1)["state"].state_hash())


func test_it_emits_real_events_in_real_phases() -> void:
	# The correspondence layer must not be able to tell it is a stub, so the
	# events and their phases are the ones the real sim will use.
	var log: EventLog = _run(3)["log"]
	assert_not_empty(log.of_type(CrownAffairs.EVENT_WAR_MOVED))
	assert_not_empty(log.of_type(SettlePhase.EVENT_SETTLED))
	assert_eq(log.of_type(CrownAffairs.EVENT_WAR_MOVED)[0].phase, WorldPhase.CROWNS_MONTH)
	assert_eq(log.of_type(SettlePhase.EVENT_SETTLED)[0].phase, WorldPhase.COLONY_MONTH)


func test_it_produces_a_real_diff() -> void:
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var month := WorldMonth.new(IntentBook.new(), RngStreams.new(SEED))
	month.drivers = [CrownAffairs.new(), _colony_driver()]
	var diff := month.run(state, log)
	assert_false(diff.is_empty())
	assert_true(diff.has_change("month"))


func test_it_supplies_the_measures_the_letters_judge() -> void:
	var measures := WorldValues.measures(WorldValues.initial_state())
	for id in [WorldValues.WAR, WorldValues.REVENUE, WorldValues.SUPPLY, WorldValues.FOOD]:
		assert_true(measures.has(id), "no measure '%s'" % id)


func test_a_decision_changes_the_following_month() -> void:
	# An Intent committed in one month executes in the next, so a player decision
	# is acknowledged before it takes effect.
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var book := IntentBook.new()
	var month := WorldMonth.new(book, RngStreams.new(SEED))
	month.drivers = [CrownAffairs.new(), _colony_driver()]
	month.executors = [WorldValueExecutor.new()]

	var untouched := WorldValues.initial_state()
	var untouched_log := EventLog.new()
	var untouched_month := WorldMonth.new(IntentBook.new(), RngStreams.new(SEED))
	untouched_month.drivers = [CrownAffairs.new(), _colony_driver()]
	untouched_month.executors = [WorldValueExecutor.new()]

	book.commit(Intent.new(
		&"", WorldValueExecutor.KIND, &"marshal", WorldValues.SUPPLY, 1, {"per_month": 25.0}
	), log, state.month)

	month.run(state, log)
	untouched_month.run(untouched, untouched_log)

	assert_ne(
		float(state.get_value(WorldValues.SUPPLY)),
		float(untouched.get_value(WorldValues.SUPPLY)),
		"the decision left no mark on the world",
	)
