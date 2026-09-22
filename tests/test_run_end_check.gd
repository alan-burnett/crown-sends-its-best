extends TestCase

## The run-end check: two fail conditions, two shapes (#267,
## `docs/mechanics/endings.md` §1, §4; SPEC §13.1).
##
## 🔒 **The game had no way to lose.** Voluntary retirement shipped in M3, so a
## player could leave, and phase 6 — named *Run-end check* since the world month
## was written — did nothing at all.
##
## 🔒 **Colony Overrun is one test**, and it counts the walkers. A colony whose
## last town falls while settlers are still crossing the map has one chance left,
## walking.
##
## 🔒 **Independence is four conditions, together**, and the fourth is where a run
## actually ends: the Crown that loses a colony this way does not lose a battle,
## it stops being willing to pay for the next one.

const SEED: int = 6613

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
	Threshold.reset()
	Consultation.reset()
	HarshClause.reset()
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
	Threshold.reset()
	Consultation.reset()
	HarshClause.reset()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## A colony that has lost everybody in its towns.
func _emptied(run: RunState) -> void:
	for town in run.colony.in_order():
		town.workers = 0
		town.experts = {}


## A party of settlers still crossing the map.
func _walking(people: int) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"party"
	party.people = people
	return party


## A colony in which every town has declared.
func _all_rebelling(run: RunState) -> void:
	for town in run.colony.in_order():
		town.rebelling = true


# --- 🔒 Colony Overrun: one test, and it counts the walkers ----------------

func test_a_colony_with_nobody_left_is_overrun() -> void:
	var run := _run()
	assert_false(RunEndCheck.is_overrun(run.colony, run.parties),
		"a colony with people in it was overrun")

	_emptied(run)
	assert_true(RunEndCheck.is_overrun(run.colony, run.parties),
		"a colony with nobody left in it goes on")


func test_an_expedition_in_the_field_keeps_the_run_alive() -> void:
	# 🔒 §1: it has one chance left, walking.
	var run := _run()
	_emptied(run)
	run.parties.append(_walking(6))
	assert_false(RunEndCheck.is_overrun(run.colony, run.parties),
		"the last town fell and the settlers on the road were counted as nobody")

	run.parties[0].people = 0
	assert_true(RunEndCheck.is_overrun(run.colony, run.parties),
		"an expedition with nobody in it kept the run alive")


func test_the_experts_on_the_road_are_people_too() -> void:
	var run := _run()
	_emptied(run)
	var party := _walking(0)
	party.experts = {"iron": 2}
	run.parties.append(party)
	assert_false(RunEndCheck.is_overrun(run.colony, run.parties),
		"two smiths walking across the map were counted as nobody")


func test_a_colony_entirely_in_revolt_is_populous_and_is_not_overrun() -> void:
	# 🔒 §13.1 counts every town the colony holds, **loyal or rebel**.
	var run := _run()
	_all_rebelling(run)
	assert_true(RunEndCheck.people_in(run.colony, run.parties) > 0,
		"the fixture emptied the towns as well as turning them")
	assert_false(RunEndCheck.is_overrun(run.colony, run.parties),
		"a colony in revolt was counted as a colony with nobody in it")


func test_a_run_that_has_not_begun_has_not_ended() -> void:
	# A colony with no towns at all, before the first is founded, would otherwise
	# read as overrun on month one of every game.
	#
	# 🔒 **A colony that has never been founded**, and not a founded one emptied
	# to look like it (#225). Those were the same thing here until something could
	# finally take a town, and the fixture that conflated them was the reason
	# nobody noticed that losing everything read as *the run has not begun*.
	var unfounded := Colony.new()
	assert_true(unfounded.is_empty())
	assert_false(RunEndCheck.is_overrun(unfounded, []),
		"a colony that has not been founded yet was reported lost")


func test_and_a_run_that_lost_every_town_has_ended() -> void:
	# 🔒 The other half, and the pair is the whole distinction. Same empty town
	# list, opposite answer, because one of them held something once.
	var run := _run()
	assert_true(run.parties.is_empty(), "the fixture left somebody walking")
	for town in run.colony.in_order().duplicate():
		run.colony.towns.erase(town)
	assert_true(run.colony.is_empty())
	assert_true(RunEndCheck.is_overrun(run.colony, run.parties),
		"a colony that lost every town it ever had was not overrun")


# --- 🔒 Independence: four conditions, together -----------------------------

## A run in which all four conditions hold.
func _independent() -> RunState:
	var run := _run()
	_all_rebelling(run)
	run.standing.standing = 0.0
	run.standing.band = CrownStanding.BAND_LOST
	run.contact(&"marshal").relationship = Relationship.new(&"marshal", 0.0)
	return run


func test_all_four_together_end_the_run() -> void:
	var run := _independent()
	assert_true(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"every condition held and the colony was still the Crown's")


func test_one_loyal_town_is_enough_to_go_on() -> void:
	var run := _independent()
	run.colony.in_order()[0].rebelling = false
	assert_true(RunEndCheck.any_town_is_loyal(run.colony))
	assert_false(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"a colony with a loyal town in it declared independence")


func test_standing_that_is_merely_alarmed_is_enough_to_go_on() -> void:
	var run := _independent()
	run.standing.band = CrownStanding.BAND_ALARM
	assert_false(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"the Crown had not given up and the colony left anyway")


func test_a_marshal_who_would_still_send_is_enough_to_go_on() -> void:
	# 🔒 Condition 4, and the one where a run actually ends.
	var run := _independent()
	run.contact(&"marshal").relationship = Relationship.new(&"marshal", 100.0)
	assert_true(RunEndCheck.will_send_more(
		run.contact(&"marshal"), run.standing, run.world),
		"a devoted Marshal would send nobody")
	assert_false(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"the colony went while the Marshal was still willing")


func test_the_marshal_refuses_only_once_the_crown_has_stopped_paying() -> void:
	# 🔒 §4: he will never refuse troops the PC is paying for in full — that is
	# `FullPaymentIsAYes`, a filter and not a weight. **But the filter reads
	# whether the Crown can pay**, and once standing is lost the Crown honours
	# nothing, so the PC is not paying at all.
	var run := _run()
	var marshal := run.contact(&"marshal")
	marshal.relationship = Relationship.new(&"marshal", 0.0)

	run.standing.band = CrownStanding.BAND_CONTENT
	assert_true(RunEndCheck.will_send_more(marshal, run.standing, run.world),
		"a Marshal at nothing refused while the Crown was still paying, so the "
			+ "guarantee is not a guarantee")

	run.standing.band = CrownStanding.BAND_LOST
	assert_false(RunEndCheck.will_send_more(marshal, run.standing, run.world),
		"a Marshal at nothing kept sending men the Crown would not pay for")


func test_condition_four_cannot_be_true_while_the_crown_is_paying() -> void:
	# 🔒 **Conditions 2 and 4 are not independent**, and this is why.
	# `FullPaymentIsAYes` is a filter, so while the Crown honours the bill the
	# Marshal cannot refuse **for any reason at all** — not low regard, not a
	# ruinous cost, not a personality that hates being asked. Condition 4 is
	# therefore only reachable once condition 2 already holds.
	#
	# §1 lists four conditions and this keeps all four, because the implication is
	# a property of today's Marshal rather than of the ending: give him another
	# reason to refuse and the two come apart, and the check should not have to be
	# rewritten when they do.
	var run := _run()
	for loyalty in [0.0, 25.0, 50.0, 100.0]:
		for band in [CrownStanding.BAND_CONTENT, CrownStanding.BAND_CONCERN,
				CrownStanding.BAND_ALARM]:
			run.standing.band = band
			run.contact(&"marshal").relationship = Relationship.new(&"marshal", loyalty)
			assert_true(
				RunEndCheck.will_send_more(
					run.contact(&"marshal"), run.standing, run.world),
				"a Marshal at %.0f refused while the Crown was still paying, at %s"
					% [loyalty, band])


func test_no_marshal_at_all_is_not_a_refusal() -> void:
	# An office nobody holds has not declined anything, and a run must not end
	# because a contact is missing.
	var run := _independent()
	assert_true(RunEndCheck.will_send_more(null, run.standing, run.world))
	run.contacts.erase("marshal")
	assert_false(RunEndCheck.is_independent(
		run.colony, run.standing, run.contact(&"marshal"), run.world),
		"a colony declared independence because nobody held the Marshal's office")


# --- 🔒 The hypothetical leaves no mark -------------------------------------

func test_asking_what_he_would_do_writes_nothing_to_the_log() -> void:
	# 🔒 `choose()` always emits its scoring trace, and a weighing nobody asked
	# for must not appear in the record every consumer of Seam A reads.
	var run := _independent()
	var before := run.log.all().size()
	RunEndCheck.will_send_more(run.contact(&"marshal"), run.standing, run.world)
	assert_eq(run.log.all().size(), before,
		"asking the Marshal a hypothetical wrote it down")


func test_asking_costs_him_no_regard_and_commits_no_intent() -> void:
	# It consults a request the PC has not made, so nothing about it may land.
	var run := _independent()
	var marshal := run.contact(&"marshal")
	var before := marshal.loyalty()
	var live := run.intents.live().size()

	for round in 5:
		RunEndCheck.will_send_more(marshal, run.standing, run.world)
	assert_eq(marshal.loyalty(), before,
		"a request nobody made cost the Marshal his regard")
	assert_eq(run.intents.live().size(), live,
		"a request nobody made committed an Intent")


func test_asking_twice_gives_the_same_answer() -> void:
	# It takes no RNG stream at all, so it cannot shift a later draw and cannot
	# disagree with itself.
	var run := _independent()
	var first := RunEndCheck.will_send_more(
		run.contact(&"marshal"), run.standing, run.world)
	for round in 20:
		assert_eq(RunEndCheck.will_send_more(
			run.contact(&"marshal"), run.standing, run.world), first,
			"the same question got two different answers")


# --- 🔒 At most one ending, and it is recorded ------------------------------

func test_overrun_beats_independence_when_both_would_fire() -> void:
	# A colony with nobody left has no loyal town either. **There is nothing left
	# to save** beats **they have taken it from us**, because the second describes
	# people who are still there.
	var run := _independent()
	_emptied(run)
	assert_eq(RunEndCheck.reason_for(
		run.colony, run.parties, run.standing, run.contact(&"marshal"), run.world),
		RunEndCheck.OVERRUN,
		"an empty colony declared independence")


func test_a_going_concern_ends_nothing() -> void:
	var run := _run()
	assert_eq(String(RunEndCheck.reason_for(
		run.colony, run.parties, run.standing, run.contact(&"marshal"), run.world)), "",
		"a colony going about its business was reported lost")


func test_phase_six_ends_the_run_and_says_how() -> void:
	var run := _independent()
	_emptied(run)
	var driver := RunEndDriver.new(run)
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)

	assert_true(run.ending.is_over(), "phase 6 watched the colony fall and did nothing")
	assert_eq(run.ending.reason, RunEnding.FAILED)
	assert_eq(run.ending.how, RunEndCheck.OVERRUN,
		"the ending does not say which way the colony was lost")
	assert_eq(run.log.of_type(RunEndDriver.EVENT_LOST).size(), 1)
	assert_eq(run.log.of_type(OpticsRegister.EVENT_RUN_FAILED).size(), 1,
		"losing the colony cost the Crown nothing at court")


func test_it_ends_the_run_once() -> void:
	# 🔒 Ironman makes the ending part of the state, so a check that fired twice
	# would overwrite the month a run was lost with the month somebody noticed.
	var run := _independent()
	_emptied(run)
	var driver := RunEndDriver.new(run)
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)
	var lost_in := run.ending.month

	run.world.month += 4
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)
	assert_eq(run.ending.month, lost_in, "the run was lost twice")
	assert_eq(run.log.of_type(RunEndDriver.EVENT_LOST).size(), 1)


func test_it_does_nothing_in_any_other_phase() -> void:
	var run := _independent()
	_emptied(run)
	var driver := RunEndDriver.new(run)
	for phase in WorldPhase.ORDER:
		if phase == WorldPhase.RUN_END_CHECK:
			continue
		driver.on_phase(phase, run.world, run.log, run.streams)
	assert_false(run.ending.is_over(),
		"the run ended in a phase that is not the run-end check")


func test_how_survives_the_save() -> void:
	# Ironman, one save per run. An ending that forgot which way it happened
	# would have the summary and the epitaph guess.
	var ending := RunEnding.new()
	ending.reason = RunEnding.FAILED
	ending.how = RunEndCheck.INDEPENDENCE
	assert_eq(RunEnding.from_dict(ending.to_dict()).how, RunEndCheck.INDEPENDENCE,
		"how the colony was lost did not survive the save")


# --- 🔒 Crown troops, which do not exist yet --------------------------------

func test_the_troop_condition_is_derived_and_reads_true_today() -> void:
	# Crown troops are M6. Deriving the count rather than assuming none means the
	# milestone that brings them gives one function a body and changes nothing
	# else — the condition is already wired and already tested.
	var run := _run()
	assert_eq(RunEndCheck.crown_troops_in(run.colony), 0,
		"something is producing Crown troops and this has not been told")
