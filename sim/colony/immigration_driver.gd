class_name ImmigrationDriver
extends RefCounted

## Lands each month's settlers, in phase 1 (#170, `immigration.md` §1).
##
## **Arrivals, alongside everything else crossing from the Crown.** It runs
## before the Colony Month, so the people who land this month work, eat and are
## counted this month — and it reads the quality of life **last month's Settle**
## wrote, which is what makes arrivals a consequence of how the town was doing
## rather than of what it is about to do.
##
## Towns are served in simulation order, but nothing here reads another town:
## each computes its own figure from its own state, so the order cannot matter
## and is fixed only so the log reads the same way twice.

var colony: Colony = null


func _init(p_colony: Colony = null) -> void:
	colony = p_colony


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.ARRIVALS or colony == null:
		return
	var context := ColonyContext.new(state, log, streams, null)
	context.colony = colony
	for town in colony.in_order():
		Immigration.arrive(town, context)
