class_name Building
extends RefCounted

## Something a town can build (SPEC §11.3).
##
## **Prerequisites, costs and effects are all data.** Nothing in code names a
## building, so adding one is adding a file — which is the test of whether the
## tree is really a tree or a switch statement wearing one.

static var _buildings: Dictionary = {}  # String -> Building

var id: StringName = &""
var display_name: String = ""

## Buildings that must already stand. **All of them**, not any.
var requires: PackedStringArray = PackedStringArray()

## How long it takes once the resources are there.
var months: int = 1

## Resource id -> how much the Build phase consumes (#49).
var cost: Dictionary = {}

## What it does once it stands.
var effects: Dictionary = {}

## **Uncommon.** A church brings a clergyman, an armoury a quartermaster
## (SPEC §8.2). Declared here; nothing consumes it until M7 — the field, not the
## feature.
var grants_contact: String = ""


static func load_from(records: Array) -> void:
	_buildings = {}
	for record in records:
		var building := Building.new()
		building.id = StringName(record.get("id", ""))
		if building.id.is_empty():
			push_error("A building record has no id.")
			continue
		building.display_name = String(record.get("name", record.get("id", "")))
		building.requires = PackedStringArray(record.get("requires", []))
		building.months = maxi(1, JsonTypes.to_int(record.get("months", 1), "months"))
		building.cost = record.get("cost", {}).duplicate()
		building.effects = record.get("effects", {}).duplicate()
		building.grants_contact = String(record.get("grants_contact", ""))
		_buildings[String(building.id)] = building


static func reset() -> void:
	_buildings = {}


static func has(id: StringName) -> bool:
	return _buildings.has(String(id))


static func find(id: StringName) -> Building:
	return _buildings.get(String(id))


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_buildings.keys())
	out.sort()
	return out


## Buildings a town could start right now, sorted.
##
## **A building cannot be started when its prerequisites are unmet**, and one
## already standing is not on offer again.
static func available_to(town: Town) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids():
		if town.has_building(StringName(id)):
			continue
		if find(StringName(id)).prerequisites_met(town):
			out.append(id)
	return out


## What this building leads to, sorted. The other direction through the tree.
static func unlocked_by(id: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for other in ids():
		if find(StringName(other)).requires.has(String(id)):
			out.append(other)
	return out


func prerequisites_met(town: Town) -> bool:
	for required in requires:
		if not town.has_building(StringName(required)):
			return false
	return true


func cost_of(resource: StringName) -> float:
	return float(cost.get(String(resource), 0.0))


## Resources this building needs, sorted.
func costed_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(cost.keys())
	out.sort()
	return out


func effect(name: String, fallback: Variant = 0.0) -> Variant:
	return effects.get(name, fallback)


# --- What standing buildings add up to -------------------------------------
#
# Asked of the town rather than stored on it, so a building's effect cannot
# drift out of step with whether the building is actually there.

## How much this town's production of a resource is raised by what it has built.
static func yield_bonus_for(town: Town, resource: StringName) -> float:
	var bonus := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building == null:
			continue
		var bonuses: Dictionary = building.effect("yield_bonus", {})
		bonus += float(bonuses.get(String(resource), 0.0))
	return bonus


## Extra months of need a town holds back, on top of the data's baseline.
static func reserve_months_for(town: Town) -> float:
	var months_held := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null:
			months_held += float(building.effect("reserve_months", 0.0))
	return months_held


## How many head this town's buildings can graze.
##
## **Livestock off pasture eat the town's grain** (#48), so this is the
## difference between a herd that feeds the town and one that competes with it.
static func pasture_capacity_for(town: Town) -> int:
	var head := 0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null:
			head += int(building.effect("pasture", 0))
	return head


## What standing buildings contribute to quality of life. Read in Settle (#50).
static func quality_of_life_for(town: Town) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null:
			total += float(building.effect("quality_of_life", 0.0))
	return total


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"requires": requires.duplicate(),
		"months": months,
		"cost": cost.duplicate(),
		"effects": effects.duplicate(),
		"grants_contact": grants_contact,
	}
