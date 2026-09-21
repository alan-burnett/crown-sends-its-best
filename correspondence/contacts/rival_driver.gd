class_name RivalDriver
extends RefCounted

## Watches the dukes reach the bottom, in **phase 7** (#209).
##
## 🔒 **It moves nothing.** Every duke's loyalty is moved by `DriftDriver` and by
## the deeds in `Relationship`, exactly as a governor's is — there is no bespoke
## rival machinery and this driver adds none. All it does is notice the one fact
## that is not derivable from the number afterwards: **he has been to the
## bottom.**
##
## It runs after `DriftDriver` in the same phase, so a month that took a duke
## under is latched in the month it happened rather than the month after.

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or run == null or run.rivals == null:
		return

	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony

	for duke in RivalDuke.all_in(run):
		if duke.relationship == null:
			continue
		if RivalDuke.band_of(duke.relationship.loyalty) != RivalDuke.MINIMUM:
			continue
		run.rivals.reached_minimum(duke, context)
