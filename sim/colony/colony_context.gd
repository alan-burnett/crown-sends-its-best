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

var run_seed: int = 0

## Town id -> what Reckon worked out this month.
##
## **Every later phase reads this rather than working it out again**, which is
## the whole point of Reckon being a phase of its own.
var reckonings: Dictionary = {}


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


## What a town needs and can spare this month, once Reckon has run.
func reckoning_for(town: Town) -> Reckoning:
	return reckonings.get(String(town.id), Reckoning.new(town.id))


## The tiles a town works. Empty until territory has been computed, which phase 3
## does before this phase runs.
func tiles_of(town: Town) -> Array[Vector2i]:
	if territory == null:
		return []
	return territory.tiles_of(town.id)
