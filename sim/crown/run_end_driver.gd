class_name RunEndDriver
extends RefCounted

## Phase 6, the Run-end check, doing something at last (#267,
## `docs/mechanics/world-month.md`, `docs/mechanics/endings.md` §1).
##
## It has been a named phase since the world month was written and has never had
## a body: **the game had no way to lose.** Voluntary retirement shipped in M3,
## so a player could leave, and the colony could not fall.
##
## ## 🔒 After standing and before prestige
##
## The order inside a phase is the order the drivers are listed in.
## `CrownStandingDriver` settles the band this check reads for condition 2, so it
## must have judged the month first; and `PrestigeDriver` settles the score the
## ending is recorded with, so a run that ends this month must end **before**
## that — `RunEnding.end` charges the final optics debt, and a score settled
## first would be the score without it.
##
## ## 🔒 It ends the run once
##
## An ended run is not re-ended. SPEC §16.2's ironman makes the ending part of
## the state, so a check that fired twice would overwrite the month a run was
## lost with the month somebody noticed again.

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RUN_END_CHECK or run == null:
		return
	if run.ending != null and run.ending.is_over():
		return

	# 🔒 **He looks before it is decided, every month** (#268, SPEC §13.1:
	# *defeat is never a surprise*).
	#
	# In this file rather than in a driver of its own, so the ordering is
	# structural: there is no arrangement of the driver list that could let an
	# ending fire in a month the Chancellor was not shown the same facts. And it
	# is a *look*, not a stage — nothing is recorded, nothing counts down, and the
	# log is the whole of the memory.
	LastChance.look(
		run.colony, run.parties, run.companies, run.standing,
		run.contact(&"marshal"), state, log)

	var reason := RunEndCheck.reason_for(
		run.colony, run.parties, run.companies, run.standing,
		run.contact(&"marshal"), state)
	if String(reason).is_empty():
		return

	# **The reason is recorded beside the ending, not instead of it.** Both ways
	# of losing are `RunEnding.FAILED` and cost the same final optics debt, which
	# is priced in the register like every other optic; which of the two it was
	# is what the summary and the epitaph read.
	log.emit(EVENT_LOST, &"crown", state.month, {
		"how": String(reason),
		# **What took the last of them** (#299), so the ending can be painted by
		# it (SPEC §13.1: *the ending names who overran it*).
		"fell_to": fell_to(log),
		"people": RunEndCheck.people_in(run.colony, run.parties),
		"towns": 0 if run.colony == null else run.colony.in_order().size(),
	}, WorldPhase.RUN_END_CHECK)

	run.ending = RunEnding.end(RunEnding.FAILED, log, state.month)
	run.ending.how = reason


## 🔒 **What finished the colony: the last thing that cost it people.**
##
## The allegiance that took its last town or stormed it last — `native`, `rival`,
## `rebel` — or `hunger`, when the last soul it lost starved. Read from the
## *latest* such event, never from the last town lost: a colony that lost a town
## to the natives in its fifth year and starved in its ninth was not overrun by
## the natives. Empty when nothing in the log ever cost a town a life.
static func fell_to(log: EventLog) -> String:
	var events := log.all()
	for index in range(events.size() - 1, -1, -1):
		var event: SimEvent = events[index]
		if event.type == Colony.EVENT_LOST:
			return String(event.payload.get("to", ""))
		if event.type == TownCompany.EVENT_STORMED:
			return String(event.payload.get("by", ""))
		if event.type == ConsumePhase.EVENT_FAMINE:
			return FELL_TO_HUNGER
	return ""


## What `fell_to` says of a colony that starved.
const FELL_TO_HUNGER: String = "hunger"


## How the colony was lost, for the summary to read. Distinct from
## `RunEnding.EVENT_ENDED`, which says only that it stopped.
const EVENT_LOST: StringName = &"colony_was_lost"
