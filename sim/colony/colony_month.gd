class_name ColonyMonth
extends RefCounted

## The eight phases of SPEC §11.3, run as phase 4 of the World Month.
##
## **This is the runner and the seam, not the phase logic.** Each phase has its
## own ticket (#44 to #50); this decides only when they happen and what they are
## allowed to see.
##
## ## The locked ordering
##
## **🔒 Every town completes a phase before any town begins the next**, and every
## choice in a phase is made from the colony's state **as it stood when that
## phase began**. No town benefits from being simulated first.
##
## Those are two separate promises and the second is the one that gets lost.
## Running every town through Work before any town starts Reckon is easy. Making
## sure the third town's Work sees the *pre-Work* stockpiles of the first two —
## rather than what they left behind — takes a snapshot, and it is the reason
## this exists as a runner rather than as a loop inside each phase.
##
## With one town in M2 none of this is visible. **It is built correctly anyway**:
## the invariant is locked, M4 brings the towns that would expose a violation,
## and retrofitting phase-locking onto eight phases written town-at-a-time is a
## rewrite rather than a fix.

# --- The eight phases (SPEC §11.3) -----------------------------------------

const WORK: StringName = &"work"
const RECKON: StringName = &"reckon"
const RELIEF: StringName = &"relief"
const EXCHANGE: StringName = &"exchange"
const CONSUME: StringName = &"consume"
const BUILD: StringName = &"build"
const SELL: StringName = &"sell"
const SETTLE: StringName = &"settle"

const ORDER: Array[StringName] = [WORK, RECKON, RELIEF, EXCHANGE, CONSUME, BUILD, SELL, SETTLE]

const EVENT_PHASE: StringName = &"colony_phase"

## Phase name -> the handler that runs it. A phase with no handler is a phase
## whose ticket has not landed; it still happens, and still emits, so the order
## is observable before the work is.
var handlers: Dictionary = {}


static func is_phase(name: StringName) -> bool:
	return ORDER.has(name)


func set_handler(phase: StringName, handler: ColonyPhase) -> void:
	if not is_phase(phase):
		push_error("'%s' is not one of the colony month's phases." % phase)
		return
	handlers[phase] = handler


## Run the whole colony month.
func run(colony: Colony, context: ColonyContext) -> void:
	context.colony = colony
	_settle_upkeep(colony, context)
	for phase in ORDER:
		_run_phase(phase, colony, context)


## What the town owes on what it has built, **before the first phase** (#151).
##
## Buildings reach Work through yields, Reckon through reserves and Build through
## speed, so a town that settled afterwards would get a free month of effects
## from a building it cannot pay for.
##
## **Not a ninth phase.** SPEC §11.3 enumerates eight and this does not join
## them — it is a settlement the colony makes before the first of them. Run town
## by town in simulation order so the locked lockstep still holds, and taking no
## snapshot because nothing here reads another town.
func _settle_upkeep(colony: Colony, context: ColonyContext) -> void:
	for town in colony.simulation_order(context.run_seed):
		Upkeep.settle(town, context)


## One phase, for every town, from a single snapshot.
##
## The snapshot is taken **once, before any town moves**, and every town in this
## phase reads it. A town that reads the live colony instead would see whatever
## the towns before it had already done, and the order they ran in would start to
## matter — which is precisely what the invariant forbids.
func _run_phase(phase: StringName, colony: Colony, context: ColonyContext) -> void:
	var before := ColonySnapshot.of(colony)
	var handler: ColonyPhase = handlers.get(phase)

	var towns := colony.simulation_order(context.run_seed)
	for town in towns:
		if handler != null:
			handler.run(town, before, context)

	context.log.emit(EVENT_PHASE, &"colony", context.state.month, {
		"phase": String(phase),
		"towns": towns.size(),
		"handled": handler != null,
	}, WorldPhase.COLONY_MONTH)
