class_name ColonyDriver
extends RefCounted

## Runs the colony month as **phase 4 of the World Month**.
##
## The seam the sim README promised: M2 replaces the stub's colony half, not the
## runner above it. `WorldMonth` calls this exactly as it called the stub, and
## the correspondence layer cannot tell the difference — it reads events and the
## world diff, and both keep arriving in the same shapes.

var colony: Colony = null
var month: ColonyMonth = null
var map: WorldMap = null
var run_seed: int = 0

## Supplied by the territory driver, which runs in phase 3 — before this.
var territory_driver: TerritoryDriver = null


func _init(p_colony: Colony = null, p_map: WorldMap = null, p_run_seed: int = 0) -> void:
	colony = p_colony
	map = p_map
	run_seed = p_run_seed
	month = ColonyMonth.new()


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.COLONY_MONTH or colony == null:
		return

	# A fresh context each month. **The tax the Crown took is this month's**, and
	# a context that carried it over would have Settle report a year's duty as a
	# month's.
	var context := ColonyContext.new(state, log, streams, map)
	context.run_seed = run_seed
	if territory_driver != null:
		context.territory = territory_driver.territory

	month.run(colony, context)
