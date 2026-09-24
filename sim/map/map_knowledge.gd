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

## Vector2i -> the name of the tribe whose village stands there, as last seen.
##
## 🔒 **The colony learns of a village by seeing it**, like everything else. A
## village the colony walked past two years ago is drawn where it was, at the
## size it was, which is the same lie the terrain tells and for the same reason.
var villages: Dictionary = {}

## Tiles in sight as of the last recomputation.
var in_sight: Dictionary = {}


## Record what is visible now. Called in phase 3, after territory.
func observe(
	map: WorldMap,
	territory: Territory,
	month: int,
	towns_present: Array = [],
	natives: Tribes = null,
	denied: DeniedTiles = null,
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
			# 🔒 **Both claims are recorded, and neither is resolved here.** A
			# tile can be worked by a town and held by a village at once, and
			# `natives.md` §10 leaves to the Author who actually works it. The
			# map draws the contest; nothing in the sim decides it.
			"native": _native_name(natives, at),
			# 🔒 **Soldiers on your own doorstep are not a secret** (#188). SPEC
			# §11.2's lock is satisfied without an exception: a tile a duke has
			# parked men on is a tile inside the colony's own influence, so the
			# colony is looking straight at it.
			"denied_by": String(denied.denied_by(at)) if denied != null else "",
		}

	for town in towns_present:
		if in_sight.has(town.at):
			towns[town.at] = town.display_name

	if natives != null:
		for village in natives.villages_in_order():
			if in_sight.has((village as Village).at):
				villages[(village as Village).at] = _tribe_name(natives, (village as Village).tribe)


## What a company on the march sees as it passes (#434, `commanders.md` §3
## *Explore*): the tile it stands on and those around it. **Explored for good**;
## once it moves on they are remembered, as last seen. A tile the colony already
## knows keeps what it knew and is dated this month. Returns how many were new.
func reveal_around(map: WorldMap, at: Vector2i, month: int, natives: Tribes = null, radius: int = 1) -> int:
	var fresh := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tile := at + Vector2i(dx, dy)
			if not map.in_bounds(tile.x, tile.y):
				continue
			var record: Dictionary = seen.get(tile, {})
			if record.is_empty():
				fresh += 1
				record = {"border": false, "worked_by": "", "denied_by": ""}
			record["terrain"] = String(map.terrain_at(tile.x, tile.y))
			record["improvement"] = String(map.improvement_at(tile.x, tile.y))
			record["month"] = month
			record["native"] = _native_name(natives, tile)
			seen[tile] = record
	if natives != null:
		for village in natives.villages_in_order():
			var place := (village as Village).at
			if maxi(absi(place.x - at.x), absi(place.y - at.y)) <= radius:
				villages[place] = _tribe_name(natives, (village as Village).tribe)
	return fresh


## Whichever tribe works this tile, by name, or empty.
static func _native_name(natives: Tribes, at: Vector2i) -> String:
	if natives == null:
		return ""
	return _tribe_name(natives, natives.holder_of(at))


static func _tribe_name(natives: Tribes, id: StringName) -> String:
	if natives == null or String(id).is_empty():
		return ""
	var tribe := natives.find(id)
	return tribe.display_name if tribe != null else ""


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


## Whichever tribe was working this tile when the colony last looked, or empty.
##
## **The map's whole knowledge of the natives**, and the reason presentation
## needs no access to `Tribes`.
func native_at(at: Vector2i) -> String:
	return String(seen.get(at, {}).get("native", ""))


## Which rival has men on this tile, as last seen, or empty.
##
## **The id, because presentation may not reach a duke to ask his name** — the
## lint keeps `RivalDuke` out of that layer for the same reason it keeps `Tribe`
## out. What the map needs is that the ground is not the colony's to work.
func denied_at(at: Vector2i) -> String:
	return String(seen.get(at, {}).get("denied_by", ""))


## The tribe whose village stands here, as last seen, or empty.
func village_at(at: Vector2i) -> String:
	return String(villages.get(at, ""))


## Ground both a town and a village lay claim to, as last seen.
##
## 🔒 **Reports, never resolves.** `natives.md` §10 leaves who actually works a
## contested tile to the Author, so this answers the question the map asks and
## refuses the one the sim would want.
func is_contested(at: Vector2i) -> bool:
	var tile: Dictionary = seen.get(at, {})
	return not String(tile.get("worked_by", "")).is_empty() \
		and not String(tile.get("native", "")).is_empty()


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

	var homes: Dictionary = {}
	var sites: Array = villages.keys()
	sites.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for at in sites:
		homes["%d,%d" % [at.x, at.y]] = villages[at]

	return {"seen": entries, "towns": settlements, "villages": homes}


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

	var homes: Dictionary = data.get("villages", {})
	var sites: Array = homes.keys()
	sites.sort()
	for key in sites:
		var site := String(key).split(",")
		if site.size() == 2:
			knowledge.villages[Vector2i(int(site[0]), int(site[1]))] = homes[key]
	return knowledge
