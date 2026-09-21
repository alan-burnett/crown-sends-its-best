class_name ExpeditionParty
extends RefCounted

## A body of people crossing country to found a town (#176,
## `docs/mechanics/founding-towns.md` §6, §7).
##
## ## 🔒 It cannot fight
##
## **An expedition never defends itself**, whatever it is carrying. Settlers with
## wagons of goods — and guns among the cargo — are no substitute for an army
## ready to fight. **It is prey until it arrives**, and there is deliberately no
## code here that could ever return fire.
##
## ## 🔒 A deliberate exception to the one-at-a-time rule
##
## `CLAUDE.md` holds that no event of hardship costs a town more than one
## population. **A body of people in the open is not a town.**
##
## That rule exists to keep per-population consequences uniform and legible
## inside a settled town — the Diplomat's death roll, quality of life, letters
## that name what happened. An expedition has no walls, no neighbours and nobody
## to call on, and an ambush that takes a quarter of them is the correct fiction.
##
## **A dev should not "fix" this to match the town rule.** The share is the
## point, and the proportional loss of the stores with the people is the rest of
## it: a quarter of the people lost is a quarter of the stores lost with them.
##
## ## 🔒 Two attacks and it turns back
##
## A setback rather than a catastrophe. The people come home, the remaining
## stores come home, and the months are gone — which is the real cost, because
## the season is what was actually spent.
##
## **Lost completely is the extreme of the same rule and not a separate case**:
## an expedition small enough, hit hard enough, has nobody left to turn back.

const EVENT_MOVED: StringName = &"expedition_moved"
const EVENT_ATTACKED: StringName = &"expedition_attacked"
const EVENT_TURNED_BACK: StringName = &"expedition_turned_back"
const EVENT_DESTROYED: StringName = &"expedition_destroyed"
const EVENT_CAME_HOME: StringName = &"expedition_came_home"

## How many attacks it will take before turning for home. Tuning (§7 says two).
const ATTACKS_BEFORE_TURNING: int = 2

## Tiles crossed in a month. **Slow on purpose**: the months are the cost, and a
## party that arrived next month would make the whole journey a formality.
const TILES_PER_MONTH: int = 1

var id: StringName = &""

## The town that sent it, and the town it comes home to.
var parent: StringName = &""

var people: int = 0
var experts: Dictionary = {}
var cargo: Dictionary = {}
var gold: float = 0.0

var at: Vector2i = Vector2i(-1, -1)

## Where it is going. **Left open for #177**, which gives the governor a site
## preference and lets a letter shift him; until then whatever launched it says
## where, and a party with no destination simply waits.
var destination: Vector2i = Vector2i(-1, -1)

var launched_month: int = 0
var attacks: int = 0

## Turned for home, and not yet arrived. It still moves; it moves the other way.
var turning_back: bool = false


func is_empty() -> bool:
	return people <= 0 and expert_total() <= 0


func expert_total() -> int:
	var total := 0
	for kind in experts:
		total += int(experts[kind])
	return total


## Everyone aboard, skilled or not.
func souls() -> int:
	return people + expert_total()


## Where it is heading this month — its site, or home if it has turned.
func heading_for() -> Vector2i:
	return at if turning_back and destination == Vector2i(-1, -1) else destination


## Move one step (Seam A).
##
## Returns true when it has reached whatever it was heading for.
func advance(toward: Vector2i, context: ColonyContext) -> bool:
	if toward == Vector2i(-1, -1) or at == Vector2i(-1, -1):
		return false
	if at == toward:
		return true

	# **One tile a month**, in the plainest possible line. Pathfinding is not the
	# question this ticket asks, and a party that took a clever route would be a
	# party the player could not follow on a map that shows what the colony knows.
	var step := Vector2i(signi(toward.x - at.x), signi(toward.y - at.y))
	for _tile in TILES_PER_MONTH:
		if at == toward:
			break
		at += step

	context.log.emit(EVENT_MOVED, id, context.state.month, {
		"expedition": String(id),
		"town": String(parent),
		"at": [at.x, at.y],
		"toward": [toward.x, toward.y],
		"turning_back": turning_back,
		"souls": souls(),
	}, WorldPhase.MOVEMENT)
	return at == toward


## Something fell on it (Seam A).
##
## 🔒 **A share of the people and the same share of every cargo line.** Not a
## count, and not the stores rounded separately — the wagons that were lost were
## carrying something.
##
## Returns what it cost, so the attacker's own event can say.
func attacked(share: float, cause: String, context: ColonyContext) -> Dictionary:
	var taken := clampf(share, 0.0, 1.0)
	var before := souls()

	var lost_people := mini(people, int(ceilf(float(people) * taken)))
	people -= lost_people

	var lost_experts: Dictionary = {}
	var kinds: Array = experts.keys()
	kinds.sort()
	for kind in kinds:
		var had := int(experts[kind])
		var gone := mini(had, int(floorf(float(had) * taken)))
		if gone <= 0:
			continue
		experts[kind] = had - gone
		lost_experts[kind] = gone

	# **The same share of every line**, so the party that arrives is the party
	# that set out, smaller — not a party that somehow kept all its iron.
	var lost_cargo: Dictionary = {}
	var carried: Array = cargo.keys()
	carried.sort()
	for resource in carried:
		var gone := float(cargo[resource]) * taken
		if gone <= 0.0:
			continue
		cargo[resource] = maxf(0.0, float(cargo[resource]) - gone)
		lost_cargo[resource] = gone
	var lost_gold := gold * taken
	gold = maxf(0.0, gold - lost_gold)

	attacks += 1
	context.log.emit(EVENT_ATTACKED, id, context.state.month, {
		"expedition": String(id),
		"town": String(parent),
		"cause": cause,
		"share": taken,
		"lost_people": lost_people,
		"lost_experts": lost_experts,
		"lost_cargo": lost_cargo,
		"lost_gold": lost_gold,
		"remaining": souls(),
		"was": before,
		"attacks": attacks,
	}, WorldPhase.MOVEMENT)

	# 🔒 **Destroyed is the extreme of the same rule**, not a separate case: an
	# expedition small enough, hit hard enough, has nobody left to turn back.
	if is_empty():
		context.log.emit(EVENT_DESTROYED, id, context.state.month, {
			"expedition": String(id),
			"town": String(parent),
			"cause": cause,
			"at": [at.x, at.y],
		}, WorldPhase.MOVEMENT)
	elif attacks >= ATTACKS_BEFORE_TURNING and not turning_back:
		turn_back(context)

	return {
		"people": lost_people, "experts": lost_experts,
		"cargo": lost_cargo, "gold": lost_gold,
	}


## Give it up and head for home (Seam A).
func turn_back(context: ColonyContext) -> void:
	if turning_back:
		return
	turning_back = true
	context.log.emit(EVENT_TURNED_BACK, id, context.state.month, {
		"expedition": String(id),
		"town": String(parent),
		"souls": souls(),
		"attacks": attacks,
		"months_out": context.state.month - launched_month,
	}, WorldPhase.MOVEMENT)


## Put what is left back into the town that sent it (Seam A).
##
## **The months are the loss.** The people come home, the remaining stores come
## home, and a season is gone — which is a setback rather than a catastrophe, and
## deliberately so.
func come_home(town: Town, context: ColonyContext) -> void:
	if town == null:
		return
	town.workers += people
	var kinds: Array = experts.keys()
	kinds.sort()
	for kind in kinds:
		town.add_experts(StringName(kind), int(experts[kind]))
	var carried: Array = cargo.keys()
	carried.sort()
	for resource in carried:
		town.store(StringName(resource), float(cargo[resource]))
	town.receive_gold(gold)

	context.log.emit(EVENT_CAME_HOME, id, context.state.month, {
		"expedition": String(id),
		"town": String(town.id),
		"souls": souls(),
		"months_out": context.state.month - launched_month,
		"attacks": attacks,
	}, WorldPhase.MOVEMENT)

	people = 0
	experts.clear()
	cargo.clear()
	gold = 0.0


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"parent": String(parent),
		"people": people,
		"experts": experts.duplicate(),
		"cargo": cargo.duplicate(),
		"gold": gold,
		"at": [at.x, at.y],
		"destination": [destination.x, destination.y],
		"launched_month": launched_month,
		"attacks": attacks,
		"turning_back": turning_back,
	}


static func from_dict(data: Dictionary) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = StringName(data.get("id", ""))
	party.parent = StringName(data.get("parent", ""))
	party.people = int(data.get("people", 0))
	party.experts = data.get("experts", {}).duplicate()
	party.cargo = data.get("cargo", {}).duplicate()
	party.gold = float(data.get("gold", 0.0))
	party.at = _point(data.get("at", [-1, -1]))
	party.destination = _point(data.get("destination", [-1, -1]))
	party.launched_month = int(data.get("launched_month", 0))
	party.attacks = int(data.get("attacks", 0))
	party.turning_back = bool(data.get("turning_back", false))
	return party


static func _point(value: Variant) -> Vector2i:
	var pair: Array = value if typeof(value) == TYPE_ARRAY else [-1, -1]
	if pair.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(pair[0]), int(pair[1]))
