class_name WorldPhase
extends RefCounted

## The nine phases of the World Month, from `docs/mechanics/world-month.md`.
##
## The Colony Month of SPEC §11.3 is phase 4 of these nine. Each phase completes
## for every actor before the next begins, on the same principle §11.3 locks for
## towns: no actor benefits from being simulated first.
##
## Only the names live here. The loop that runs them is the turn state machine
## (#7) and the executors it drives; this exists so that the event log can record
## which phase emitted an event without every call site inventing its own
## spelling. The mechanics doc owns the meaning of each one.

const ARRIVALS: StringName = &"arrivals"
const MOVEMENT: StringName = &"movement"
const TERRITORY: StringName = &"territory"
const COLONY_MONTH: StringName = &"colony_month"
const CROWNS_MONTH: StringName = &"crowns_month"
const RUN_END_CHECK: StringName = &"run_end_check"
const RECKONING: StringName = &"reckoning"
const INTENT: StringName = &"intent"
const DISPATCH: StringName = &"dispatch"

## In order. A phase's position is meaningful — several of the doc's constraints
## are orderings, such as territory sitting between movement and the Colony
## Month, and the run-end check preceding dispatch so the Chancellor's warning
## rides out with the same month's post (SPEC §13.1).
const ORDER: Array[StringName] = [
	ARRIVALS,
	MOVEMENT,
	TERRITORY,
	COLONY_MONTH,
	CROWNS_MONTH,
	RUN_END_CHECK,
	RECKONING,
	INTENT,
	DISPATCH,
]


static func is_phase(name: StringName) -> bool:
	return ORDER.has(name)


## Position in the month, or -1. Ordering events by month then by this then by
## `seq` gives playback the order things actually happened in.
static func index_of(name: StringName) -> int:
	return ORDER.find(name)
