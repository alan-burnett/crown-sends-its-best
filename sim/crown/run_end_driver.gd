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
		_end_the_term(state, log)
		return

	# 🔒 **Defeat is never a surprise** (#447, SPEC §13.1, `endings.md` §2). His
	# letters are composed after the month is resolved, so a colony that fell in
	# one month, or met every Independence condition at once, ended before his
	# warning could be written. A run that meets a fail condition unwarned goes
	# on one more month: the warning goes out in this month's post, and the run
	# ends at the next check. Once only, so nothing can hold a run open.
	if not was_warned(reason, log, state.month) and not _deferred_last_month(log, state.month):
		log.emit(EVENT_DEFERRED, &"crown", state.month, {"how": String(reason)}, WorldPhase.RUN_END_CHECK)
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


## 🔒 **The PC is retired at fifty years** (#447, SPEC §13.2). `TERM_EXPIRED`
## was declared, and read by the records, the epitaph and the summary, and
## nothing ever ended a run with it.
const TERM_YEARS: int = 50

## A fail ending held back a month so the Chancellor's warning could reach the
## player first (#447).
const EVENT_DEFERRED: StringName = &"run_end_deferred"

## Which of the Chancellor's letters warns of each way of losing (#447,
## `endings.md` §2): the colony dwindling for Overrun, a condition flipping for
## Independence.
const WARNED_BY: Dictionary = {
	"colony_overrun": "chancellor.colony_dwindling",
	"independence": "chancellor.last_chance",
}


func _end_the_term(state: WorldState, log: EventLog) -> void:
	if state.month < TERM_YEARS * WorldState.MONTHS_PER_YEAR:
		return
	run.ending = RunEnding.end(RunEnding.TERM_EXPIRED, log, state.month)


## Whether the warning for this way of losing went out in an earlier month's
## post, so the player has read it.
static func was_warned(reason: StringName, log: EventLog, month: int) -> bool:
	var letter := String(WARNED_BY.get(String(reason), ""))
	if letter.is_empty() or log == null:
		return true
	for event in log.of_type(Director.EVENT_DISPATCHED):
		if event.month < month and String(event.payload.get("letter", "")) == letter:
			return true
	return false


static func _deferred_last_month(log: EventLog, month: int) -> bool:
	for event in log.of_type(EVENT_DEFERRED):
		if event.month == month - 1:
			return true
	return false


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
