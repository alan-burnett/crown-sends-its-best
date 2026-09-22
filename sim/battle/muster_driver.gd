class_name MusterDriver
extends RefCounted

## Phase 1: the neighbours put men under arms (#225).
##
## 🔒 **Arrivals, so nothing lands the month it is decided.** A muster is on the
## map for a month before it reaches anybody, which is the month a letter about
## it could still matter — the announce-then-act property holding at the point
## where the colony most needs it.
##
## Thin on purpose. Every rule is in `Muster`; this is the phase and the wiring,
## and #342's finding stands: this is the **first thing in the game that raises a
## company at all**, and it raises them for the other side.

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(
	phase: StringName, state: WorldState, log: EventLog, streams: RngStreams
) -> void:
	if phase != WorldPhase.ARRIVALS or run == null:
		return
	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	Muster.run_month(run, context)
