class_name CrownFounding
extends RefCounted

## A town the Crown is sending, rather than one the colony is walking to (#180,
## `founding-towns.md` §1, §3; `the-provost.md` §8).
##
## ## 🔒 It arrives with a character
##
## **This is what a parent town can never do.** A Crown founding can arrive
## already *being* something — a building standing, an expert, an intent already
## set, a lean toward the crop the man who proposed it was taken with. The same
## shape runs the other way: *a parcel of poor souls desperate for a new life*
## arrives with very little and no specialism at all.
##
## And **the correspondence determines what it starts with**. What the PC
## promises is what it is equipped with, which is why the proposal is a letter
## with a figure in it rather than an announcement.
##
## ## 🔒 It appears. There is no journey
##
## After some months it is simply there, on the coast. The Crown managed the
## ships and the guards and whatever else a safe founding needed, so **none of
## §7's dangers apply** — no ambush, no turning back, no map unit at any point.
##
## That is the whole of the trade:
##
## > **Crown expeditions are slow and safe and cost standing. Town expeditions
## > are free and go across open country.**
##
## ## 🔒 The PC may dissuade, but he does not decide
##
## SPEC §11.4 has these *pressed* on the colony. His letter is an Order resolved
## by compliance like any other, and **the decision remains the contact's** — a
## determined patron founds his town over the PC's objection. His only real
## instrument is the regard he built with the man beforehand, which is the point:
## it makes months of ordinary correspondence into a thing he can spend.

const EVENT_PROPOSED: StringName = &"crown_founding_proposed"
const EVENT_ARRIVED: StringName = &"crown_founding_arrived"
const EVENT_ABANDONED: StringName = &"crown_founding_abandoned"

## How long the Crown takes over it. **Slow**, which is the other half of safe.
## Tuning.
const MONTHS_AT_SEA: int = 5

## What a Crown-funded town arrives with in coin. 🔒 **A set purse**, not a share
## of anybody's — the Crown is not dividing a town's savings, it is spending.
## Tuning.
const PURSE: float = 1_400.0

var id: StringName = &""

## Who proposed it. His regard is what the PC's objection is weighed against, and
## the new governor inherits from him (#178).
var proposer: StringName = &""

## What it will arrive as. Set by the correspondence and nothing else.
var people: int = 0
var expert_in: StringName = &""
var building: StringName = &""
var intent: StringName = &""
var cargo: Dictionary = {}
var gold: float = 0.0

var proposed_month: int = 0
var arrives_month: int = 0

## The PC argued against it and the contact relented. It never sails.
var abandoned: bool = false


func is_due(month: int) -> bool:
	return not abandoned and month >= arrives_month


## What the Crown sends when the PC pays for it properly, or does not.
##
## **The correspondence determines what it starts with** (§3), so this is a
## table of what each answer buys rather than a figure computed from anything.
## Every line of it is tuning.
const EQUIPPED: Dictionary = {
	"handsomely": {"people": 26, "food": 900.0, "tools": 120.0, "purse": 1.0, "building": true},
	"adequately": {"people": 18, "food": 500.0, "tools": 60.0, "purse": 0.6, "building": false},
	"meanly": {"people": 10, "food": 160.0, "tools": 0.0, "purse": 0.25, "building": false},
}


## Make one, as a letter's reply describes it (Seam A).
static func proposed(
	by: StringName,
	equipped: String,
	expert: StringName,
	building_id: StringName,
	wanted: StringName,
	context: ColonyContext,
) -> CrownFounding:
	var terms: Dictionary = EQUIPPED.get(equipped, EQUIPPED["adequately"])

	var founding := CrownFounding.new()
	founding.id = StringName("founding_%s_%d" % [by, context.state.month])
	founding.proposer = by
	founding.people = int(terms["people"])
	founding.gold = PURSE * float(terms["purse"])
	founding.cargo = {"food": float(terms["food"])}
	if float(terms["tools"]) > 0.0:
		founding.cargo["tools"] = float(terms["tools"])

	# 🔒 **The character, and only where it was paid for.** A meanly equipped
	# founding is a parcel of poor souls: no expert, no building, no specialism.
	# What separates the botanist's colony from theirs is what the PC promised.
	founding.expert_in = expert
	founding.intent = wanted
	if bool(terms["building"]):
		founding.building = building_id

	founding.proposed_month = context.state.month
	founding.arrives_month = context.state.month + MONTHS_AT_SEA

	context.log.emit(EVENT_PROPOSED, founding.id, context.state.month, {
		"founding": String(founding.id),
		"by": String(by),
		"equipped": equipped,
		"people": founding.people,
		"expert_in": String(founding.expert_in),
		"building": String(founding.building),
		"intent": String(founding.intent),
		"arrives": founding.arrives_month,
	}, WorldPhase.CROWNS_MONTH)
	return founding


## The town appears (Seam A).
##
## 🔒 **On the coast**, because that is where the Crown's ships put people down,
## and because the whole justification for there being no journey is that the
## Crown brought them by sea.
func arrive(colony: Colony, map: WorldMap, context: ColonyContext) -> Town:
	if abandoned or colony == null or map == null:
		return null
	var at := _somewhere_on_the_coast(colony, map)
	if at == Vector2i(-1, -1):
		return null

	var town := Town.new(
		StringName("town_%s" % String(id).replace("founding_", "")),
		String(id).replace("founding_", "").capitalize().replace("_", " "),
		at,
	)
	town.workers = people
	if not String(expert_in).is_empty():
		town.add_experts(expert_in, 1)
	var carried: Array = cargo.keys()
	carried.sort()
	for resource in carried:
		town.store(StringName(resource), float(cargo[resource]))
	town.receive_gold(gold)
	if not String(building).is_empty():
		town.add_building(building)
	# 🔒 **An intent already set** (§3). It arrives *being* something, which is
	# the thing a parent town can never do.
	if GovernorIntent.is_intent(intent):
		town.intent = intent
		town.intent_since = context.state.month

	colony.add(town)
	context.log.emit(EVENT_ARRIVED, town.id, context.state.month, {
		"founding": String(id),
		"town": String(town.id),
		"by": String(proposer),
		"at": [at.x, at.y],
		"people": people,
		"expert_in": String(expert_in),
		"building": String(building),
		"intent": String(intent),
		"gold": gold,
		"months_at_sea": context.state.month - proposed_month,
	}, WorldPhase.ARRIVALS)
	return town


## Where the Crown's ships put people down.
##
## 🔒 **The coast is a filter, not a weight** (`CLAUDE.md`). §3 says it appears
## on the coast, so an inland tile is not merely a worse answer — it is not an
## answer at all. Scored as a preference it was redundant against the rest of the
## sum, and a redundant guard is one nobody notices has stopped working: taking
## it out changed nothing a test could see.
##
## Among the tiles that pass, the best ground going and clear of the towns
## already there — the same choice a governor makes, asked with the coast already
## decided because a ship decided it.
func _somewhere_on_the_coast(colony: Colony, map: WorldMap) -> Vector2i:
	var best := Vector2i(-1, -1)
	var most := -1.0e30
	for y in map.height:
		for x in map.width:
			var at := Vector2i(x, y)
			if not map.is_land(x, y) or _too_near(at, colony):
				continue
			if _water_by(at, map) <= 0:
				continue  # 🔒 The filter. Not on the coast, so not a site.
			var worth := map.yield_around(x, y, &"food")
			if worth > most + 0.0001 \
					or (absf(worth - most) <= 0.0001 and _before(at, best)):
				best = at
				most = worth
	return best


static func _too_near(at: Vector2i, colony: Colony) -> bool:
	for town in colony.in_order():
		if town.at.distance_squared_to(at) <= 9:
			return true
	return false


static func _water_by(at: Vector2i, map: WorldMap) -> int:
	var water := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := at + Vector2i(dx, dy)
			if map.in_bounds(near.x, near.y) and not map.is_land(near.x, near.y):
				water += 1
	return water


static func _before(a: Vector2i, b: Vector2i) -> bool:
	if b == Vector2i(-1, -1):
		return true
	return a.y < b.y or (a.y == b.y and a.x < b.x)


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"proposer": String(proposer),
		"people": people,
		"expert_in": String(expert_in),
		"building": String(building),
		"intent": String(intent),
		"cargo": cargo.duplicate(),
		"gold": gold,
		"proposed_month": proposed_month,
		"arrives_month": arrives_month,
		"abandoned": abandoned,
	}


static func from_dict(data: Dictionary) -> CrownFounding:
	var founding := CrownFounding.new()
	founding.id = StringName(data.get("id", ""))
	founding.proposer = StringName(data.get("proposer", ""))
	founding.people = int(data.get("people", 0))
	founding.expert_in = StringName(data.get("expert_in", ""))
	founding.building = StringName(data.get("building", ""))
	founding.intent = StringName(data.get("intent", ""))
	founding.cargo = data.get("cargo", {}).duplicate()
	founding.gold = float(data.get("gold", 0.0))
	founding.proposed_month = int(data.get("proposed_month", 0))
	founding.arrives_month = int(data.get("arrives_month", 0))
	founding.abandoned = bool(data.get("abandoned", false))
	return founding
