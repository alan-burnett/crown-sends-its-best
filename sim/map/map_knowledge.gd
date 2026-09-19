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

## Vector2i -> {terrain, improvement, month}, as last seen.
var seen: Dictionary = {}

## Tiles in sight as of the last recomputation.
var in_sight: Dictionary = {}


## Record what is visible now. Called in phase 3, after territory.
func observe(map: WorldMap, territory: Territory, month: int) -> void:
	in_sight = {}
	for at in territory.visible:
		in_sight[at] = true
		seen[at] = {
			"terrain": String(map.terrain_at(at.x, at.y)),
			"improvement": String(map.improvement_at(at.x, at.y)),
			"month": month,
		}


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
	return {"seen": entries}


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
	return knowledge
