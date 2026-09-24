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

## Every body of armed men in the world (#211, `battles.md` §3).
##
## Here because a town victuals the companies it supports, which is part of its
## month rather than a thing done to it afterwards — and because §3's order puts
## them above the objective, which is a decision the Colony Month makes.
var companies: Companies = null

## What the colony has ever seen (#434, SPEC §11.2): the unexplored land a
## scouting party is raised to find. Null where nothing supplies it, and the
## visible ground stands in.
var knowledge: MapKnowledge = null

## What each commander has learned (#223). Here because a battle is where it is
## earned, and a battle happens in a context.
var commanders: CommanderBook = null

## What each town holds against the Crown (#71). Null in fixtures that do not
## care, which is why every reader checks.
var grievances: Grievances = null

## The colony's contacts, so sentiment can weigh who lives where and what they
## think of the PC. Contact id -> `Contact`.
var contacts: Dictionary = {}

## Standing agreements with the villages, and the peoples who hold them (#206).
##
## 🔒 **SPEC §11.3 puts the natives ahead of the Crown in Exchange**, so a phase
## that buys has to be able to ask them first. Null in fixtures that do not care,
## which is why every reader checks.
var native_trade: TradeBook = null
var natives: Tribes = null

## Ground a rival has parked men on (#188). Null in fixtures that do not care.
var denied: DeniedTiles = null

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


## The rate a resource is **actually charged** at, wherever it is traded
## (SPEC §10.2).
##
## 🔒 **The authored rate, unless a duty is presently set aside** (#278,
## `institutional-contacts.md` §3). The clergy's festival and holy day are
## time-limited waivers, and this is the one place that decides what a trade pays
## — Exchange, Sell, Spending and `Valuation` all come through here, so none of
## them can disagree about what a duty costs this month.
##
## 🔒 **A resource under protest keeps its duty**, which is the Author's
## third ruling and is nearly definitional: a protest is a town refusing the
## Crown's duty, so there is no duty flowing to waive. It bites on the holy day,
## which waives everything else — **a colony in protest does not get a holiday
## from the thing it is protesting.**
##
## The question needs the colony as well as the state, which is why it is asked
## here and not in `TaxWaiver`.
func tax_rate(resource: StringName) -> float:
	var authored := TaxRates.rate_for(state, resource)
	if not TaxWaiver.running(state, resource):
		return authored
	if is_protested(resource):
		return authored
	return TaxRates.MIN_RATE


## Whether any town in the colony is refusing to deal in this resource.
func is_protested(resource: StringName) -> bool:
	if colony == null:
		return false
	for town in colony.in_order():
		if TradeProtest.is_protesting(town, resource):
			return true
	return false


## What a town needs and can spare this month, once Reckon has run.
func reckoning_for(town: Town) -> Reckoning:
	return reckonings.get(String(town.id), Reckoning.new(town.id))


## The tiles a town works. Empty until territory has been computed, which phase 3
## does before this phase runs.
##
## 🔒 **Ground a rival is sitting on is absent, not scored at zero** (#188). This
## is the one place it is removed, so Work — and anything else that asks what a
## town can work — cannot disagree about it. A tile nobody can reach is not a
## tile the town looked at and rejected.
func tiles_of(town: Town) -> Array[Vector2i]:
	if territory == null:
		return []
	var mine := territory.tiles_of(town.id)
	if denied == null or denied.held.is_empty():
		return mine

	var workable: Array[Vector2i] = []
	for at in mine:
		if not denied.is_denied(at):
			workable.append(at)
	return workable
