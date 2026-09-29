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

	# 🔒 **Losing the last town is not yet the end** (#470, SPEC §13.1,
	# `endings.md` §1). Overrun is every town gone *and the Crown will commit no
	# more resources to retake them*, and the second half is the last chance: the
	# month the colony falls, the Chancellor writes his formal warning and the
	# Provost offers a town by sea. The run goes on until the Crown gives up.
	var since := -1
	if reason == RunEndCheck.OVERRUN:
		var fall := the_fall(log)
		if fall == null:
			fall = _falls(state, log)
		if not _the_crown_gives_up(fall, log):
			return
		# His warning is about *this* fall. One written about an earlier fall the
		# colony came back from warned the player of nothing now.
		since = fall.month

	# 🔒 **Defeat is never a surprise** (#447, SPEC §13.1, `endings.md` §2). His
	# letters are composed after the month is resolved, so a colony that fell in
	# one month, or met every Independence condition at once, ended before his
	# warning could be written. A run that meets a fail condition unwarned goes
	# on one more month: the warning goes out in this month's post, and the run
	# ends at the next check. Once only, so nothing can hold a run open.
	if not was_warned(reason, log, state.month, since) and not _deferred_last_month(log, state.month):
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
## `endings.md` §2): the colony fallen for Overrun (#470), a condition flipping
## for Independence.
const WARNED_BY: Dictionary = {
	"colony_overrun": "chancellor.the_colony_has_fallen",
	"independence": "chancellor.last_chance",
}


func _end_the_term(state: WorldState, log: EventLog) -> void:
	if state.month < TERM_YEARS * WorldState.MONTHS_PER_YEAR:
		return
	run.ending = RunEnding.end(RunEnding.TERM_EXPIRED, log, state.month)


## Whether the warning for this way of losing went out in an earlier month's
## post, so the player has read it — and no earlier than `since`, when the
## warning is about something that happened then.
static func was_warned(reason: StringName, log: EventLog, month: int, since: int = -1) -> bool:
	var letter := String(WARNED_BY.get(String(reason), ""))
	if letter.is_empty() or log == null:
		return true
	for event in log.of_type(Director.EVENT_DISPATCHED):
		if event.month < month and event.month >= since \
				and String(event.payload.get("letter", "")) == letter:
			return true
	return false


static func _deferred_last_month(log: EventLog, month: int) -> bool:
	for event in log.of_type(EVENT_DEFERRED):
		if event.month == month - 1:
			return true
	return false


# --- 🔒 The last chance: the Crown gives up, or it does not (#470) -----------

## The colony has fallen: no town and nobody walking. Emitted once for each fall,
## in the month it happens, and both letters of the last chance hang off it.
const EVENT_FALLEN: StringName = &"colony_fell"

## The Provost's offer of a town by sea (`founding-towns.md` §3). What the PC
## does with **this** letter is what can end the run; arguing against some other
## founding is not letting the recovery go.
const OFFER: String = "provost.begin_again"


## The fall that opened the last chance the colony is in, or null.
##
## 🔒 **The log is the memory**, as it is for `LastChance`. The latest fall counts
## only while nobody has been in the colony since, so a colony that took its
## ship, stood again and fell again is offered its chance again.
static func the_fall(log: EventLog) -> SimEvent:
	var falls := log.of_type(EVENT_FALLEN)
	if falls.is_empty():
		return null
	var fall: SimEvent = falls.back()
	var looks := log.of_type(LastChance.EVENT_LOOKED)
	for index in range(looks.size() - 1, -1, -1):
		var look: SimEvent = looks[index]
		if look.seq < fall.seq:
			break
		if int(look.payload.get("people", 0)) > 0:
			return null
	return fall


func _falls(state: WorldState, log: EventLog) -> SimEvent:
	return log.emit(EVENT_FALLEN, &"crown", state.month, {
		# 🔒 **Whether the Crown could fund a recovery the month it fell.** A Crown
		# refusing payments makes no offer (§1), so a fall it could not pay for has
		# no offer to wait on, even should the Treasury reopen the month after.
		"paying": run.refusal == null or run.refusal.pays(),
	}, WorldPhase.RUN_END_CHECK)


## 🔒 **The Crown will commit no more** (`endings.md` §1). Two things end it:
##
## - **the Crown is refusing payments**, so no recovery can be funded, and a
##   town promised and still at sea is a promise the refusal breaks before it
##   lands;
## - **the PC let the Provost's offer go**, arguing him out of it or leaving it
##   unanswered.
##
## A town of the Crown's on its way keeps the run alive, and so does an offer not
## yet answered: the ending never arrives before the player has had it.
func _the_crown_gives_up(fall: SimEvent, log: EventLog) -> bool:
	if not bool(fall.payload.get("paying", true)):
		return true
	if run.refusal != null and not run.refusal.pays():
		return true
	if a_town_is_coming(run):
		return false
	return the_offer_was_let_go(log, fall.month)


## Whether a town the Crown is paying for is on its way: the answer that funds it
## still at sea, the Intent that answer became, or the founding itself.
##
## Asked of what is in hand rather than of what the log once said, so a founding
## argued away after it was promised no longer holds the run open.
static func a_town_is_coming(p_run: RunState) -> bool:
	for entry in p_run.foundings:
		if not (entry as CrownFounding).abandoned:
			return true
	if p_run.intents != null:
		for intent in p_run.intents.live():
			if intent.kind == FoundingExecutor.KIND_FUND:
				return true
	for order in p_run.orders_at_sea:
		if order.kind == M1Registrations.ORDER_FUND_FOUNDING:
			return true
	return false


## Whether the PC let the Provost's offer go since the colony fell: argued him out
## of it, or set the letter aside.
##
## 🔒 **Read from the post as it went**, in the month it went, so the answer ends
## the run at the next resolution, where a reply would be read. The silence it
## becomes is read as well, for a post that never went through the desk.
static func the_offer_was_let_go(log: EventLog, since: int) -> bool:
	for event in log.of_type(TurnMachine.EVENT_ORDER_ISSUED):
		if event.month >= since \
				and String(event.payload.get(TurnMachine.ANSWERS_KEY, "")) == OFFER \
				and String(event.payload.get("kind", "")) == String(M1Registrations.ORDER_DISSUADE_FOUNDING):
			return true
	for kind in [TurnMachine.EVENT_SET_ASIDE, Silence.EVENT_IGNORED]:
		for event in log.of_type(kind):
			if event.month >= since and String(event.payload.get("letter", "")) == OFFER:
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
