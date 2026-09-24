class_name StandingDriver
extends RefCounted

## What the month did to the neighbours, in **phase 7** (#204, `natives.md` §3).
##
## Phase 7 is Reckoning — what the month did to the colony's patience — and this
## is the same question asked of the people the colony lives beside. It runs
## **after** the Colony Month, so the fields a town worked this month are fields
## it has actually worked, and after Intent's neighbour phase 8 only by a month,
## which is the point: a governor announces what he means to do in month N and
## the tribe reacts to it in month N+1, one month behind, exactly as the PC does.
##
## ## The foundings are read from the log
##
## 🔒 **Seam A.** A town appearing is an event, and this is a consumer of it like
## the map and the letters. That is why `expedition_party` and `crown_founding`
## do not each have to remember to tell the tribes — a founding path added later
## is picked up for free, and a founding path that forgot would be a tribe that
## never noticed a town built in its fields.

const EVENT_THREAT: StringName = &"native_threat_read"

## 🔒 **The colony and a people meet** (#299): the first month a town of the
## colony borders a tribe's land, once a run for each tribe.
const EVENT_MET: StringName = &"tribe_met"

## Event types that mean a town came into being. **Both paths**: the colony
## walking somewhere and the Crown putting people down on the coast.
const FOUNDINGS: Array[StringName] = [
	&"town_founded", &"crown_founding_arrived",
]

var colony: Colony = null
var natives: Tribes = null
var map: WorldMap = null

## Supplied by the territory driver, which runs in phase 3.
var territory_driver: TerritoryDriver = null


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or natives == null:
		return

	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony

	# Tribe ids that had something done to them this month. Whoever is not in it
	# was left alone, which is the only thing that helps for free.
	var moved: Dictionary = {}

	for event in log.for_month(state.month):
		if not FOUNDINGS.has(event.type):
			continue
		var at := _where(event.payload)
		if at == Vector2i(-1, -1):
			continue
		TribeStanding.founding(at, natives, context)
		for tribe in natives.in_order():
			moved[String((tribe as Tribe).id)] = true

	_meet(context)

	var territory: Territory = territory_driver.territory if territory_driver != null else null
	for id in TribeStanding.exploitation(colony, natives, territory, context):
		moved[String(id)] = true
	for id in TribeStanding.hostile_intent(colony, natives, context):
		moved[String(id)] = true

	TribeStanding.left_alone(natives, moved, context)

	# **What the governors make of them**, which is the colony's own reading and
	# not the tribes'. `natives.md` §1: nothing about a tribe reaches anybody
	# except through the colonists who live beside them.
	state.apply(log, EVENT_THREAT, &"colony", {
		WorldValues.NATIVE_THREAT: _threat(),
	}, WorldPhase.RECKONING)


## The first town to border each tribe, the month it first did.
##
## **Borders** is `Intrusion`'s answer, the same one standing is charged against
## and the letters read (`ColonyMeasures.tribe_beside`), so a people is met the
## month it could first be offended and not a month before. Asked after the
## foundings, so a town put down beside a village this month meets it this month.
func _meet(context: ColonyContext) -> void:
	if colony == null:
		return
	for entry in colony.in_order():
		var town: Town = entry
		var nearest: Dictionary = Intrusion.at(town.at, natives)
		if float(nearest["depth"]) <= 0.0:
			continue
		var tribe := natives.find(StringName(nearest["tribe"]))
		if tribe == null or tribe.met_month >= 0:
			continue
		tribe.met_month = context.state.month
		context.log.emit(EVENT_MET, tribe.id, context.state.month, {
			"tribe": String(tribe.id),
			"town": String(town.id),
			"at": [town.at.x, town.at.y],
		}, WorldPhase.RECKONING)


## How dangerous the neighbours look from inside the colony, nought to one.
##
## Read off **the angriest of them**, because a governor writing about "the
## natives" has no more idea than the PC which of three peoples the men on the
## ridge belong to.
func _threat() -> float:
	var angriest := natives.the_angriest()
	if angriest == null:
		return 0.0
	var trust := clampf(angriest.trust(), Tribe.MINIMUM, Tribe.MAXIMUM)
	return clampf(1.0 - trust / Tribe.NEUTRAL, 0.0, 1.0)


## Where a founding event says the town went.
static func _where(payload: Dictionary) -> Vector2i:
	var at: Array = payload.get("at", [])
	if at.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(at[0]), int(at[1]))
