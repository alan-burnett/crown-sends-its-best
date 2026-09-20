class_name Improvement
extends RefCounted

## Something built on a tile that changes what it yields (SPEC §11.1).
##
## **"Best on plains" is a number in a file.** `terrain_factor` scales what the
## improvement contributes, so a farm on plains is worth more than a farm on
## scrubland without any code knowing which is which.
##
## A tile holds **one** improvement. Building a farm where a mine stood replaces
## it cleanly, because every improvement computes from the terrain rather than
## from whatever was there before — there is no accumulated state to unwind.

static var _improvements: Dictionary = {}  # String -> Improvement

const ANY: String = "*"

var id: StringName = &""
var display_name: String = ""

## Resources exempt from `scale`. A farm lowers every yield but food.
var keeps: PackedStringArray = PackedStringArray()

## Multiplies the tile's existing yields. `"*"` is everything.
var scale: Dictionary = {}

## Yields the improvement contributes, by level name, scaled by how well the
## terrain suits it.
var adds: Dictionary = {}

## Terrain id -> how well suited it is. `"*"` is the fallback.
var terrain_factor: Dictionary = {}

## Terrains it may be built on at all.
var allowed_on: PackedStringArray = PackedStringArray()

## Livestock supported without eating (SPEC §11.1). The population side is M4.
var livestock_capacity: int = 0

## Built at no cost by trade rather than chosen. Roads only (SPEC §11.1).
var natural: bool = false

## Resource id -> how much raising it costs the town (#49, #53).
var cost: Dictionary = {}



# --- Loading ---------------------------------------------------------------

static func load_from(records: Array) -> void:
	_improvements = {}
	for record in records:
		var improvement := Improvement.new()
		improvement.id = StringName(record.get("id", ""))
		if improvement.id.is_empty():
			push_error("An improvement record has no id.")
			continue
		improvement.display_name = String(record.get("name", record.get("id", "")))
		improvement.keeps = PackedStringArray(record.get("keeps", []))
		improvement.scale = record.get("scale", {}).duplicate()
		improvement.adds = record.get("adds", {}).duplicate()
		improvement.terrain_factor = record.get("terrain_factor", {}).duplicate()
		improvement.allowed_on = PackedStringArray(record.get("allowed_on", []))
		improvement.livestock_capacity = JsonTypes.to_int(record.get("livestock_capacity", 0), "livestock_capacity")
		improvement.natural = bool(record.get("natural", false))
		improvement.cost = record.get("cost", {}).duplicate()
		_improvements[String(improvement.id)] = improvement


static func reset() -> void:
	_improvements = {}


static func has(id: StringName) -> bool:
	return _improvements.has(String(id))


## Look one up without complaining. An empty id is a bare tile, which is normal.
static func find(id: StringName) -> Improvement:
	return _improvements.get(String(id))


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_improvements.keys())
	out.sort()
	return out


# --- Building --------------------------------------------------------------

func cost_of(resource: StringName) -> float:
	return float(cost.get(String(resource), 0.0))


## Resources this improvement needs, sorted.
func costed_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(cost.keys())
	out.sort()
	return out


func can_build_on(terrain: StringName) -> bool:
	return allowed_on.has(String(terrain))


## How well this terrain suits the improvement.
func factor_on(terrain: StringName) -> float:
	if terrain_factor.has(String(terrain)):
		return float(terrain_factor[String(terrain)])
	return float(terrain_factor.get(ANY, 1.0))


func capacity_on(terrain: StringName) -> int:
	return int(roundf(float(livestock_capacity) * factor_on(terrain)))


# --- Yields ----------------------------------------------------------------

## What a tile yields of a resource once this is built on it.
##
## The terrain's own yield is scaled, unless the resource is one the improvement
## keeps, and then the improvement's own contribution is added — scaled by how
## well the terrain suits it.
func yield_of(terrain: Terrain, resource: StringName) -> float:
	var base := terrain.yield_of(resource) if terrain != null else 0.0
	var name := String(resource)

	if not keeps.has(name):
		var factor: float = float(scale.get(name, scale.get(ANY, 1.0)))
		base *= factor

	if adds.has(name):
		base += Terrain.level_value(String(adds[name])) * factor_on(terrain.id if terrain != null else &"")

	return maxf(0.0, base)


## Resources this improvement introduces that the terrain does not yield.
func introduced() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(adds.keys())
	out.sort()
	return out


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"keeps": keeps.duplicate(),
		"scale": scale.duplicate(),
		"adds": adds.duplicate(),
		"terrain_factor": terrain_factor.duplicate(),
		"allowed_on": allowed_on.duplicate(),
		"livestock_capacity": livestock_capacity,
		"natural": natural,
		"cost": cost.duplicate(),
	}
