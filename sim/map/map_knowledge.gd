class_name MapKnowledge
extends RefCounted

## **🔒 The map only shows what the colony knows** (SPEC §11.2).
##
## Known and actual are modelled separately and on purpose. M5 puts rivals and
## tribes on the map and moves them about outside vision; an implementation that
## handed the presentation layer the real map and trusted it to filter would leak
## their positions the first time somebody drew a debug overlay. So the truth
## lives in `WorldMap` and **this is the only thing presentation may read**.
##
## Each tile is unexplored, remembered, or in sight:
##
## - **Unexplored** — never seen. The map shows nothing at all.
## - **Remembered** — seen once, not now. The map shows it **as last seen**,
##   which may be out of date, and that is the point.
## - **In sight** — inside vision this month. What is shown is true.

const UNEXPLORED: StringName = &"unexplored"
const REMEMBERED: StringName = &"remembered"
const IN_SIGHT: StringName = &"in_sight"

## Vector2i -> {terrain, improvement, month, border, worked_by}, as last seen.
var seen: Dictionary = {}

## Vector2i -> the name of the town standing there, as last seen.
##
## **A town is a thing the colony knows about**, and the map has to draw it. It
## is recorded here rather than read off the colony so that `presentation/` has
## exactly one object to ask — which is what `tools/lint.gd` enforces, and what
## keeps M5 from leaking a tribe's position the first time somebody draws an
## overlay.
var towns: Dictionary = {}

## Tiles in sight as of the last recomputation.
var in_sight: Dictionary = {}


## Record what is visible now. Called in phase 3, after territory.
func observe(
	map: WorldMap,
	territory: Territory,
	month: int,
	towns_present: Array = [],
) -> void:
	in_sight = {}
	for at in territory.visible:
		in_sight[at] = true
		seen[at] = {
			"terrain": String(map.terrain_at(at.x, at.y)),
			"improvement": String(map.improvement_at(at.x, at.y)),
			"month": month,
			"border": territory.inside_border(at),
			"worked_by": String(territory.influenced_by(at)),
		}

	for town in towns_present:
		if in_sight.has(town.at):
			towns[town.at] = town.display_name


func state_of(at: Vector2i) -> StringName:
	if in_sight.has(at):
		return IN_SIGHT
	return REMEMBERED if seen.has(at) else UNEXPLORED


func is_explored(at: Vector2i) -> bool:
	return seen.has(at)


## The terrain as last seen, or "" if never seen.
##
## **Not the terrain as it is.** A caller that wants the truth is asking the
## wrong object.
func terrain_at(at: Vector2i) -> StringName:
	if not seen.has(at):
		return &""
	return StringName(seen[at].get("terrain", ""))


func improvement_at(at: Vector2i) -> StringName:
	if not seen.has(at):
		return &""
	return StringName(seen[at].get("improvement", ""))


## Which month a tile was last looked at. How stale what is shown may be.
## Whether the tile was inside the colony's border when last seen.
func inside_border(at: Vector2i) -> bool:
	return bool(seen.get(at, {}).get("border", false))


## Which town works this tile, as last seen, or empty.
func worked_by(at: Vector2i) -> StringName:
	return StringName(seen.get(at, {}).get("worked_by", ""))


## The town standing on this tile, or empty.
func town_at(at: Vector2i) -> String:
	return String(towns.get(at, ""))


## Every tile ever seen, in a stable order.
##
## Sorted north-west first, so anything drawing or listing the map gets the same
## order every time rather than the dictionary's.
func explored() -> Array:
	var out: Array = []
	for at in seen:
		out.append(at)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The rectangle the colony has seen, as {from, to} inclusive. Empty when it has
## seen nothing at all.
func bounds() -> Dictionary:
	if seen.is_empty():
		return {}
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for at in seen:
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
	return {"from": low, "to": high}


func seen_in_month(at: Vector2i) -> int:
	if not seen.has(at):
		return -1
	return int(seen[at].get("month", -1))


func explored_count() -> int:
	return seen.size()


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	var entries: Dictionary = {}
	var keys: Array = seen.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for at in keys:
		entries["%d,%d" % [at.x, at.y]] = seen[at]

	var settlements: Dictionary = {}
	var places: Array = towns.keys()
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for at in places:
		settlements["%d,%d" % [at.x, at.y]] = towns[at]

	return {"seen": entries, "towns": settlements}


static func from_dict(data: Dictionary) -> MapKnowledge:
	var knowledge := MapKnowledge.new()
	var entries: Dictionary = data.get("seen", {})
	var keys: Array = entries.keys()
	keys.sort()
	for key in keys:
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		knowledge.seen[Vector2i(int(parts[0]), int(parts[1]))] = entries[key]

	var settlements: Dictionary = data.get("towns", {})
	var places: Array = settlements.keys()
	places.sort()
	for key in places:
		var where := String(key).split(",")
		if where.size() == 2:
			knowledge.towns[Vector2i(int(where[0]), int(where[1]))] = settlements[key]
	return knowledge
