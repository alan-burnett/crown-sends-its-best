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

## The colony itself.
##
## Most phases only ever touch the town they were handed, and should keep to
## that. **Relief is the exception**: giving is a transaction between two towns,
## so it needs to reach the other end of it.
var colony: Colony = null

## The run's live Intents, so Reckon can see what this town owes the Crown (#69).
##
## **The Intent is the record.** A second copy of an outstanding shipment on the
## town would be one more thing to serialise and one more thing to fall out of
## step with the book the executor works from.
var intents: IntentBook = null

## Expeditions in the open (#176). Set by the turn loop and shared with the
## driver that moves them, so a party launched in the Colony Month is already on
## the map when phase 2 next comes round.
var parties: Array = []

## What each town holds against the Crown (#71). Null in fixtures that do not
## care, which is why every reader checks.
var grievances: Grievances = null

## The colony's contacts, so sentiment can weigh who lives where and what they
## think of the PC. Contact id -> `Contact`.
var contacts: Dictionary = {}

var run_seed: int = 0

## Town id -> what Reckon worked out this month.
##
## **Every later phase reads this rather than working it out again**, which is
## the whole point of Reckon being a phase of its own.
var reckonings: Dictionary = {}

## Town id -> the recipes Work put hands on, for Convert to run.
##
## **Scratch for one month**, like the reckonings above. Work decides *who* is on
## town work and Convert decides *what comes of it*, four phases later, and the
## assignment has to survive the gap between them without being state anybody
## could save half-way through.
var conversions: Dictionary = {}

## What the Crown has taken in duty this month, across both trade phases.
##
## Exchange taxes purchases and Sell taxes sales, with Consume and Build between
## them. **Sell writes the total to `WorldValues.REVENUE`** because it is the
## later of the two; neither phase alone is the colony's return to the Crown.
var crown_tax: float = 0.0

## Town id -> what Consume found out about how the town is living.
##
## Quality of life is **stored on the town and moved only in Settle** (#50), so
## Consume records its findings here rather than writing them. Keys: `food`,
## `clothing`, `luxury`, each a `0.0`-to-`1.0` share of the need that was met.
var wellbeing: Dictionary = {}


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
