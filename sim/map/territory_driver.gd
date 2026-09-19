class_name TerritoryDriver
extends RefCounted

## Recomputes territory and records what the colony can see, in **phase 3**.
##
## It sits between Movement and the Colony Month because phase 4 assigns
## population to tiles inside influence areas. Recomputing those halfway through
## would break SPEC §11.3's locked phase ordering in a way that is cheap to
## prevent and expensive to debug.
##
## In M2 nothing moves, so this is nearly static. It is here anyway, in the right
## phase, so M4's expeditions and M5's neighbours slot in rather than renegotiate.

const EVENT_TERRITORY: StringName = &"territory_recomputed"

var map: WorldMap = null
var colony: Colony = null
var knowledge: MapKnowledge = null

## The latest result, for whoever needs to know what a town can work.
var territory: Territory = null


func _init(p_map: WorldMap = null, p_colony: Colony = null, p_knowledge: MapKnowledge = null) -> void:
	map = p_map
	colony = p_colony
	knowledge = p_knowledge


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.TERRITORY or map == null or colony == null:
		return

	territory = Territory.compute(map, colony.in_order())
	if knowledge != null:
		knowledge.observe(map, territory, state.month, colony.in_order())

	log.emit(EVENT_TERRITORY, &"colony", state.month, {
		"worked": territory.influence.size(),
		"border": territory.border.size(),
		"visible": territory.visible.size(),
		"explored": knowledge.explored_count() if knowledge != null else 0,
	}, WorldPhase.TERRITORY)
