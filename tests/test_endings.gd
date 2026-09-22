extends TestCase

## Recovery, retirement, and what an ending scores (#269,
## `docs/mechanics/endings.md` §5, §6, §7, `docs/mechanics/prestige.md` §9).
##
## 🔒 **A fail condition fires one optic, once**, and it is the largest single
## entry in the tally. **Voluntary retirement fires none** — the tally stands,
## and the timing was the decision.
##
## 🔒 **Reversing any one Independence condition exits the stage**, and the
## Chancellor stops writing about it. Overrun has no doors; its only remedy is
## not losing the people.
##
## 🔒 **Retirement is always open** (SPEC §13.2), including from inside the
## stage — which is where *retiring from a losing position can earn more
## prestige than hanging on* stops being a theoretical claim.

const SEED: int = 5527

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
	NameBags.reset()
	HarshClause.reset()
	IndependenceClause.reset()
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
	NameBags.reset()
	HarshClause.reset()
	IndependenceClause.reset()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _look(run: RunState, month: int) -> Dictionary:
	run.world.month = month
	return LastChance.look(
		run.colony, run.parties, run.standing, run.contact(&"marshal"),
		run.world, run.log)


## A colony that has been taken to the last town and then past it.
func _overrun(run: RunState) -> void:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	for town in run.colony.in_order().duplicate():
		run.colony.lost(town, Company.NATIVE, "stormed", context, WorldPhase.MOVEMENT)


# --- 🔒 What an ending scores -----------------------------------------------

func test_a_fail_condition_fires_exactly_one_optic() -> void:
	var run := _run()
	var driver := RunEndDriver.new(run)
	_overrun(run)

	run.world.month = 30
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)
	# 🔒 And again, because the shape that charges twice is one that does not
	# notice the run is already over.
	run.world.month = 31
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)

	assert_eq(run.log.of_type(OpticsRegister.EVENT_RUN_FAILED).size(), 1,
		"a lost run embarrassed the Crown more than once")
	assert_eq(run.log.of_type(RunEnding.EVENT_ENDED).size(), 1)


func test_and_it_dominates_a_typical_tally() -> void:
	# 🔒 §7: *a large final optics debt — fixed, undecaying, and the largest
	# single entry in the tally.* Asked of the price table, because that is where
	# it would stop being true.
	var failing := OpticsRegister.price_of(OpticsRegister.EVENT_RUN_FAILED)
	var biggest := 0.0
	var prices := OpticsRegister.prices()
	for type in prices:
		if String(type) == String(OpticsRegister.EVENT_RUN_FAILED):
			continue
		biggest = maxf(biggest, float(prices[type]))
	assert_true(failing > biggest,
		"losing the colony costs %f and something else costs %f" % [failing, biggest])


func test_voluntary_retirement_fires_none() -> void:
	# 🔒 §7: *nothing. The tally stands, and the timing was the decision.*
	var run := _run()
	RunEnding.end(RunEnding.RETIRED, run.log, 200)
	assert_empty(run.log.of_type(OpticsRegister.EVENT_RUN_FAILED),
		"a man who asked to be relieved was charged for losing the colony")
	assert_almost_eq(OpticsRegister.debt_in(run.log), 0.0, 0.0001)


func test_fifty_years_fires_none_either() -> void:
	var run := _run()
	RunEnding.end(RunEnding.TERM_EXPIRED, run.log, 600)
	assert_almost_eq(OpticsRegister.debt_in(run.log), 0.0, 0.0001,
		"serving the full term embarrassed the Crown")


func test_retiring_from_inside_the_stage_leaves_the_tally_intact() -> void:
	# 🔒 §6, and the decision the whole design points at. The Chancellor has named
	# how close the end is; the PC's prestige is still positive; hanging on risks
	# turning it into a fail condition's debt.
	var run := _run()
	_look(run, 20)
	for town in run.colony.in_order():
		town.rebelling = true
	assert_true(LastChance.how_many_true(_look(run, 21)) > 1,
		"the fixture never entered the stage")

	var before := OpticsRegister.debt_in(run.log)
	var ending := RunEnding.end(RunEnding.RETIRED, run.log, 21)

	assert_eq(String(ending.reason), String(RunEnding.RETIRED))
	assert_almost_eq(ending.optics_debt, before, 0.0001,
		"retiring mid-stage added a debt of its own")
	assert_empty(run.log.of_type(OpticsRegister.EVENT_RUN_FAILED))


func test_retirement_is_open_from_any_desk_phase() -> void:
	# 🔒 SPEC §13.2, and it is what makes the stage a decision rather than a
	# status. A man who has decided to go does not owe the Crown his
	# correspondence first.
	var machine := TurnMachine.new(_run())
	machine.use_content(content)
	machine.saves_on_send = false
	machine.begin_turn()

	assert_true(machine.retire(), "a man at his desk could not ask to be relieved")
	assert_true(machine.is_over())
	assert_eq(String(machine.run.ending.reason), String(RunEnding.RETIRED))


# --- 🔒 Four doors out of Independence --------------------------------------

func test_reversing_one_condition_exits_the_stage() -> void:
	# 🔒 §5: *the stage ends the moment any one condition stops being true.*
	var run := _run()
	_look(run, 10)
	for town in run.colony.in_order():
		town.rebelling = true
	var inside := LastChance.how_many_true(_look(run, 11))

	# A town comes home, which is door one.
	run.colony.in_order()[0].rebelling = false
	var outside := LastChance.how_many_true(_look(run, 12))

	assert_true(outside < inside,
		"a town came home and nothing about the colony's position changed")
	assert_false(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"a colony with a loyal town in it still reads as independent")


func test_and_the_chancellor_stops_writing_about_it() -> void:
	var run := _run()
	_look(run, 10)
	for town in run.colony.in_order():
		town.rebelling = true
	_look(run, 11)
	assert_false(LastChance.newly_true(run.log, 11).is_empty(),
		"he never started, so this proves nothing")

	run.colony.in_order()[0].rebelling = false
	_look(run, 12)
	_look(run, 13)
	assert_empty(LastChance.newly_true(run.log, 12),
		"a condition reversing set him writing")
	assert_empty(LastChance.newly_true(run.log, 13),
		"he went on writing about a colony that had recovered")


func test_and_he_starts_again_if_it_goes_back() -> void:
	# The doors swing both ways, which is what makes them doors.
	var run := _run()
	_look(run, 10)
	for town in run.colony.in_order():
		town.rebelling = true
	_look(run, 11)
	run.colony.in_order()[0].rebelling = false
	_look(run, 12)
	run.colony.in_order()[0].rebelling = true
	_look(run, 13)

	assert_eq(LastChance.newly_true(run.log, 13),
		PackedStringArray([LastChance.EVERY_TOWN_REBELS]),
		"the last town went again and he said nothing")


func test_overrun_has_no_doors() -> void:
	# 🔒 §5: *its only remedy is not losing the people.* There is nothing here
	# that could reverse it, and a test asks the codebase rather than the prose,
	# because the tempting fix is a town that comes back from nothing.
	var found := PackedStringArray()
	for path in ["res://sim/colony/colony.gd", "res://sim/crown/run_end_check.gd"]:
		var code := _code_of(path)
		for token in ["restore(", "refound", "unlost", "recover_town", "regain"]:
			if code.contains(token):
				found.append("%s has %s" % [path.get_file(), token])
	assert_empty(found, "a lost town can come back: %s" % ", ".join(found))


# --- 🔒 The summary names which ending, and why -----------------------------

func test_the_summary_names_which_fail_condition_it_was() -> void:
	var run := _run()
	var driver := RunEndDriver.new(run)
	_overrun(run)
	run.world.month = 44
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)

	var facts := RunSummary.of(run)
	assert_eq(String(facts.get("reason", "")), String(RunEnding.FAILED))
	assert_eq(String(facts.get("how", "")), String(RunEndCheck.OVERRUN),
		"the summary says the run failed without saying how")


func test_a_retirement_needs_no_second_question() -> void:
	var run := _run()
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, 100)
	var facts := RunSummary.of(run)
	assert_eq(String(facts.get("reason", "")), String(RunEnding.RETIRED))
	assert_eq(String(facts.get("how", "")), "",
		"a man who chose to go home was given a cause of death")


func test_the_two_losses_read_differently_on_the_screen() -> void:
	# 🔒 *The colony was overrun* and *the colony threw us out* are two entirely
	# different stories about the same man.
	var code := _code_of("res://presentation/summary/summary_screen.gd")
	assert_true(code.contains("RunEndCheck.OVERRUN")
			and code.contains("RunEndCheck.INDEPENDENCE"),
		"the summary screen ends both losses with the same sentence")


func test_the_score_belongs_to_the_ending_and_not_to_the_summary() -> void:
	# 🔒 Prestige is settled once when the run stops (#77). Recomputing it here
	# could disagree with the ending the save holds.
	var run := _run()
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, 100)
	run.ending.score = 4_242.0
	assert_almost_eq(float(RunSummary.of(run).get("score", 0.0)), 4_242.0, 0.0001,
		"the summary recomputed the score instead of reporting it")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
