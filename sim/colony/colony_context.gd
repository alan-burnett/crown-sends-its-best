class_name ColonyContext
extends RefCounted

## What a colony phase has to work with.
##
## Bundled rather than passed as six arguments, so a phase ticket that needs one
## more thing adds a field here instead of changing every handler's signature.

var state: WorldState = null
var log: EventLog = null
var streams: RngStreams = null
var map: WorldMap = null
var territory: Territory = null

## Tax rates are read straight off the world; this is here so a phase does not
## have to know that (#47).
var run_seed: int = 0


func _init(
	p_state: WorldState = null,
	p_log: EventLog = null,
	p_streams: RngStreams = null,
	p_map: WorldMap = null,
) -> void:
	state = p_state
	log = p_log
	streams = p_streams
	map = p_map


## The rate a resource is taxed at, wherever it is traded (SPEC §10.2).
func tax_rate(resource: StringName) -> float:
	return TaxRates.rate_for(state, resource)


## The tiles a town works. Empty until territory has been computed, which phase 3
## does before this phase runs.
func tiles_of(town: Town) -> Array[Vector2i]:
	if territory == null:
		return []
	return territory.tiles_of(town.id)
