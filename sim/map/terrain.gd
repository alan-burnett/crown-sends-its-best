class_name Terrain
extends RefCounted

## A tile type and what it yields (SPEC §11.1).
##
## **Yields are data twice over**: a terrain says it is *high* in wood, and a
## separate table says what "high" is worth. Balancing every forest in the game
## is then editing one number, rather than seven files that have to agree.
##
## A yield a terrain does not mention is zero. Sea yields high food and nothing
## else.

static var _terrains: Dictionary = {}  # String -> Terrain
static var _levels: Dictionary = {"none": 0.0, "low": 1.0, "medium": 3.0, "high": 6.0}

var id: StringName = &""
var display_name: String = ""
var land: bool = false
var navigable: bool = false

## Resource id -> level name, as authored.
var yields: Dictionary = {}

## 🔒 **What the ground is worth to whoever is holding it** (#215,
## `battles.md` §5, `tiles-and-improvements.md` §6).
##
## Mountains high, forest medium, plains low — **authored here, alongside the
## yields**, because a terrain that produced one thing and defended another from
## two different files would be two answers to what a mountain is.
##
## **One is open ground**, so a terrain that says nothing is no advantage at all
## and a new terrain cannot silently become cover. Never below one: the ground
## does not make a man easier to kill.
##
## It reaches a battle through `Force` alone. Terrain folds into the defender's
## force and appears nowhere else (`battles.md` §5), and `test_force` refuses a
## second reader — so this is the authored figure and `Force.terrain_worth` is
## the only thing that asks for it.
var defence: float = 1.0

## What the map draws this terrain as.
##
## **Content, not code** (SPEC §16.3). A placeholder palette now; swapping in
## real tile art is a change to `data/terrain/` and to whatever draws it, never
## to the model.
var colour: String = "#808080"


# --- Loading ---------------------------------------------------------------

static func load_from(records: Array, levels: Dictionary = {}) -> void:
	_terrains = {}
	if not levels.is_empty():
		_levels = levels.duplicate()
	for record in records:
		var terrain := Terrain.new()
		terrain.id = StringName(record.get("id", ""))
		if terrain.id.is_empty():
			push_error("A terrain record has no id.")
			continue
		terrain.display_name = String(record.get("name", record.get("id", "")))
		terrain.colour = String(record.get("colour", "#808080"))
		terrain.land = bool(record.get("land", false))
		terrain.navigable = bool(record.get("navigable", not terrain.land))
		terrain.yields = record.get("yields", {}).duplicate()
		terrain.defence = maxf(1.0, float(record.get("defence", 1.0)))
		_terrains[String(terrain.id)] = terrain


static func reset() -> void:
	_terrains = {}
	reset_yield_scale()


static func has(id: StringName) -> bool:
	return _terrains.has(String(id))


## Look one up without complaining if it is not there.
##
## For questions like "is this land", where the honest answer for an unknown
## terrain is "no". `get_terrain` stays loud, because asking for a terrain by
## name and not finding it is a content mistake.
static func find(id: StringName) -> Terrain:
	return _terrains.get(String(id))


static func get_terrain(id: StringName) -> Terrain:
	if not _terrains.has(String(id)):
		push_error("Unknown terrain '%s'." % id)
		return null
	return _terrains[String(id)]


## Every terrain id, sorted.
static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_terrains.keys())
	out.sort()
	return out


static func land_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids():
		if _terrains[id].land:
			out.append(id)
	return out


## What holding this ground is worth, by terrain id.
##
## **One for anything unwritten**, including the sea: a company cannot stand on
## it, and a figure there would be an advantage nobody can take.
static func defence_of(id: StringName) -> float:
	var terrain := find(id)
	return terrain.defence if terrain != null else 1.0


static func level_value(level: String) -> float:
	return float(_levels.get(level, 0.0))


static func levels() -> Dictionary:
	return _levels.duplicate()


# --- Yields ----------------------------------------------------------------

## What one tile of this terrain yields of a resource, before improvements.
func yield_of(resource: StringName) -> float:
	if not yields.has(String(resource)):
		return 0.0
	return Terrain.level_value(String(yields[String(resource)])) \
		* Terrain.yield_scale_of(resource)


# --- 🔒 The knob: what the ground gives, by resource ------------------------

## A standing multiplier on every tile's yield of one resource.
##
## **A fact about the world the PC was given**, which is what makes it a quirk's
## business (`perks-and-quirks.md` §1, §4 *Scarce iron*) rather than a terrain's.
## A colony where ore is scarce is one where every mountain gives less, and
## authoring that on each terrain record would be six places to forget.
##
## 🔒 **Applied at the single source of a yield**, so improvements, town work,
## site preference and the harness all see the same ground. `Improvement.yield_of`
## multiplies this value rather than the authored one, which is what makes a mine
## on poor ore still poor.
##
## Empty is the only state the game had before quirks, and it means every yield
## is exactly as authored.
static var _yield_scale: Dictionary = {}


static func yield_scale_of(resource: StringName) -> float:
	return float(_yield_scale.get(String(resource), 1.0))


## Turn it. **Never below zero**: ground that owes the colony resources is not a
## thing the economy can express.
static func scale_yields(scales: Dictionary) -> void:
	var resources: Array = scales.keys()
	resources.sort()
	for resource in resources:
		_yield_scale[String(resource)] = maxf(0.0, float(scales[resource]))


## Every yield back to what the ground says, **and the ground kept** — the knob
## alone, for `RunModifiers.reset_knobs`, where `reset` also forgets the terrain.
static func reset_yield_scale() -> void:
	_yield_scale = {}


## Resources this terrain yields anything of, sorted.
func yielded_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for resource in yields:
		if yield_of(StringName(resource)) > 0.0:
			out.append(String(resource))
	out.sort()
	return out


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"land": land,
		"navigable": navigable,
		"yields": yields.duplicate(),
	}
