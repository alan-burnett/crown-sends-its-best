class_name Objective
extends RefCounted

## What a town is working towards, and how far along it is (SPEC §11.3, #49).
##
## ## Two kinds, and the second is the one that gets forgotten
##
## The spec's examples are "constructing a building, stockpiling food, harvesting
## a resource, fortifying". Only the first has a *finish*. The rest are **standing
## postures** — a town told to stockpile food is not building a thing, it is
## behaving a certain way for as long as the order stands.
##
## So an objective is either:
##
## - a **construction** — a building id, with a cost that Build consumes over
##   months and a completion that applies an effect; or
## - a **posture** — no cost, no completion, but it **bends Work and Reckon**: the
##   town works its focus resource by preference and holds more of it back.
##
## A governor who can only ever be part-way through a church writes the same
## letter every month. This is the class that stops that.
##
## ## Why progress lives on the town
##
## Resources put into a build are **spent, not reserved**. They leave the
## stockpile and become `objective_invested`, which is what makes "a town that
## runs short stalls rather than losing what it has already invested" true
## (#49): the invested resources are not in the stockpile to be eaten, sold or
## given away, and a stall does not refund them.

## No objective at all.
const NONE: StringName = &"none"

## A building, with a cost and a completion.
const CONSTRUCTION: StringName = &"construction"

## A standing posture. No cost, no completion.
const POSTURE: StringName = &"posture"

## Posture id -> its record. Data, like everything else the town does.
static var _postures: Dictionary = {}



static func load_from(record: Dictionary) -> void:
	_postures = {}
	var records: Array = record.get("postures", [])
	for entry in records:
		var id := String(entry.get("id", ""))
		if id.is_empty():
			push_error("An objective posture has no id.")
			continue
		_postures[id] = {
			"name": String(entry.get("name", id)),
			"focus": String(entry.get("focus", "")),
		}


static func reset() -> void:
	_postures = {}


## Posture ids, sorted.
static func posture_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_postures.keys())
	out.sort()
	return out


static func is_posture(id: StringName) -> bool:
	return _postures.has(String(id))


## Which sort of objective this is. **A building id that is not a known building
## and not a known posture is `NONE`**, not a crash: content can be wrong.
static func kind_of(id: StringName) -> StringName:
	if String(id).is_empty():
		return NONE
	if Building.has(id):
		return CONSTRUCTION
	if is_posture(id):
		return POSTURE
	return NONE


static func display_name(id: StringName) -> String:
	if Building.has(id):
		return Building.find(id).display_name
	if is_posture(id):
		return String(_postures[String(id)].get("name", String(id)))
	return ""


# --- Postures ---------------------------------------------------------------

## The resource a town's posture favours, or empty.
##
## **Read by Work**, which weights tiles yielding it, and by Reckon, which holds
## more of it back. That is the whole of what a posture *is*.
static func posture_focus(town: Town) -> StringName:
	if not is_posture(town.objective):
		return &""
	return StringName(_postures[String(town.objective)].get("focus", ""))


## Whether the town's posture means it will not part with a resource.
##
## **A town stockpiling food that sold its surplus every month would be
## stockpiling nothing.** Reckon answers this by reserving everything the town
## holds of it, so Sell finds no spare and Relief finds nothing to give — which
## is what a standing order to hoard something actually means.
static func hoards(town: Town, resource: StringName) -> bool:
	return not String(resource).is_empty() and posture_focus(town) == resource


# --- Construction -----------------------------------------------------------

## What the build still needs, over what has already gone into it.
##
## Measured against **invested**, not against the stockpile: once resources go
## into a build they are gone from the stores, so counting the stores again would
## have the town gather everything twice.
static func outstanding(town: Town) -> Dictionary:
	var building := Building.find(town.objective)
	if building == null:
		return {}
	var out: Dictionary = {}
	for resource in building.costed_resources():
		var still := building.cost_of(StringName(resource)) - town.invested(StringName(resource))
		if still > 0.0:
			out[resource] = still
	return out


## What the build still needs that the town does not already have to hand.
##
## **This is the "want"** — what Work goes looking for and Exchange shops for.
## What it is outstanding, less what is already in the stockpile waiting to be
## put in.
static func still_to_gather(town: Town) -> Dictionary:
	var out: Dictionary = {}
	var still := outstanding(town)
	for resource in still:
		var missing := float(still[resource]) - town.held(StringName(resource))
		if missing > 0.0:
			out[resource] = missing
	return out


## Whether every resource the build needs has been invested.
static func materials_complete(town: Town) -> bool:
	return outstanding(town).is_empty()


## How many months of labour this build takes for this town.
##
## A carpenters' hall makes every build faster, which is the point of having one.
static func months_required(town: Town) -> int:
	var building := Building.find(town.objective)
	if building == null:
		return 0
	var speed := 0.0
	for id in town.buildings:
		var standing := Building.find(StringName(id))
		if standing != null:
			speed += float(standing.effect("build_speed", 0.0))
	return maxi(1, int(ceil(float(building.months) / (1.0 + maxf(0.0, speed)))))


## How far along, as `0.0` to `1.0`.
##
## **Materials and months, weighted evenly**, so "the church is half raised"
## (#49) means something whether the town is still gathering stone or already
## cutting it. A posture has no progress and returns `0.0`; ask `kind_of` first
## rather than reading a fraction that was never going to move.
static func progress_fraction(town: Town) -> float:
	var building := Building.find(town.objective)
	if building == null:
		return 0.0

	var required := 0.0
	var invested := 0.0
	for resource in building.costed_resources():
		var needed := building.cost_of(StringName(resource))
		required += needed
		invested += minf(needed, town.invested(StringName(resource)))
	var materials := 1.0 if required <= 0.0 else invested / required

	var months := float(months_required(town))
	var laboured := 0.0 if months <= 0.0 else minf(1.0, float(town.objective_progress) / months)

	return clampf(0.5 * materials + 0.5 * laboured, 0.0, 1.0)
