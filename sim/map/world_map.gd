class_name WorldMap
extends RefCounted

## The New World as a 2D tile grid (SPEC §11.1).
##
## Plain data: a width, a height, and one terrain id per tile. Improvements sit
## on tiles and arrive with #39; towns and their influence areas with #41 and
## #40. Nothing here knows about any of them yet, and none of them will need this
## to change shape.
##
## **🔒 The map only shows what the colony knows** (§11.2) — but that is a
## property of the *view*, not of the map. This is the truth; vision filters it.

var width: int = 0
var height: int = 0

## Row-major, `width * height` terrain ids.
var tiles: PackedStringArray = PackedStringArray()

## Row-major, one improvement id per tile. Empty means a bare tile.
##
## **A tile holds one improvement.** Building a farm where a mine stood replaces
## it, and nothing has to be unwound, because every improvement computes its
## yields from the terrain rather than from what was there before.
var improvements: PackedStringArray = PackedStringArray()

## Tiles whose improvement nobody is paying for (#151), as `"x,y"`.
##
## **The improvement is still there.** `yield_at` reads the bare terrain while a
## tile is in here, so a town too poor to keep its farms sees them yield like
## scrubland — and sees them come back the month it can pay, with no rebuilding.
##
## On the map rather than on the town because `yield_at` is the one place every
## reader goes through: the scoring, the harvest, the projection and the
## governor's choice of where to build all get it at once, and none of them can
## be the one that forgot.
var idle_improvements: Dictionary = {}

## Who built each fort (#419, `tiles-and-improvements.md` §6): `"x,y"` ->
## `{by, side}`. **A fort records its owner** so its fall can say whose it was.
var fort_owners: Dictionary = {}


func _init(p_width: int = 0, p_height: int = 0, fill: StringName = &"ocean") -> void:
	width = p_width
	height = p_height
	tiles = PackedStringArray()
	tiles.resize(width * height)
	tiles.fill(String(fill))
	improvements = PackedStringArray()
	improvements.resize(width * height)
	improvements.fill("")


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func index_of(x: int, y: int) -> int:
	return y * width + x


func terrain_at(x: int, y: int) -> StringName:
	if not in_bounds(x, y):
		return &""
	return StringName(tiles[index_of(x, y)])


func set_terrain(x: int, y: int, id: StringName) -> void:
	if not in_bounds(x, y):
		return
	tiles[index_of(x, y)] = String(id)


func is_land(x: int, y: int) -> bool:
	var terrain := Terrain.find(terrain_at(x, y))
	return terrain != null and terrain.land


## The four orthogonal neighbours that exist, in a fixed order.
func neighbours(x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var at: Vector2i = Vector2i(x, y) + offset
		if in_bounds(at.x, at.y):
			out.append(at)
	return out


func land_count() -> int:
	var total := 0
	for y in height:
		for x in width:
			if is_land(x, y):
				total += 1
	return total


## What a tile yields of a resource, before any improvement.
func yield_at(x: int, y: int, resource: StringName) -> float:
	var terrain := Terrain.find(terrain_at(x, y))
	if terrain == null:
		return 0.0
	var improvement := Improvement.find(improvement_at(x, y))
	if improvement != null and not is_idle(x, y):
		return improvement.yield_of(terrain, resource)
	return terrain.yield_of(resource)


## What a tile and its neighbours together yield of a resource.
##
## How good a **site** is, rather than how good a tile is: a town works the
## ground around it, not the square it stands on.
func yield_around(x: int, y: int, resource: StringName) -> float:
	var total := yield_at(x, y, resource)
	for at in neighbours(x, y):
		total += yield_at(at.x, at.y, resource)
	return total


# --- Improvements ----------------------------------------------------------

func improvement_at(x: int, y: int) -> StringName:
	if not in_bounds(x, y):
		return &""
	return StringName(improvements[index_of(x, y)])


## Whether an improvement may be built here at all.
func can_build(x: int, y: int, id: StringName) -> bool:
	var improvement := Improvement.find(id)
	if improvement == null or not is_land(x, y):
		return false
	return improvement.can_build_on(terrain_at(x, y))


## Build, replacing whatever was there. Returns the improvement displaced, or "".
##
## Emits, because map playback and the letters both want to know (Seam A).
func build(
	x: int, y: int, id: StringName, log: EventLog = null, month: int = 0, by: StringName = &"",
	side: StringName = &"",
) -> StringName:
	if not can_build(x, y, id):
		push_error("Cannot build '%s' at %d,%d." % [id, x, y])
		return &""

	var displaced := improvement_at(x, y)
	improvements[index_of(x, y)] = String(id)
	var key := "%d,%d" % [x, y]
	fort_owners.erase(key)
	var built := Improvement.find(id)
	if built != null and built.is_a_fortification():
		fort_owners[key] = {"by": String(by), "side": String(side)}

	if log != null:
		log.emit(&"improvement_built", by, month, {
			"improvement": String(id),
			"displaced": String(displaced),
			"at": Vector2i(x, y),
			"terrain": String(terrain_at(x, y)),
		}, WorldPhase.COLONY_MONTH)
	return displaced


func clear_improvement(x: int, y: int) -> void:
	if in_bounds(x, y):
		improvements[index_of(x, y)] = ""
		fort_owners.erase("%d,%d" % [x, y])


## Who built the fort on this tile, `{by, side}`, or empty.
func fort_owner(x: int, y: int) -> Dictionary:
	return fort_owners.get("%d,%d" % [x, y], {})


## Livestock this tile can support without their eating (SPEC §11.1).
func livestock_capacity_at(x: int, y: int) -> int:
	var improvement := Improvement.find(improvement_at(x, y))
	return improvement.capacity_on(terrain_at(x, y)) if improvement != null else 0


## Whether nobody is paying to work this tile's improvement.
func is_idle(x: int, y: int) -> bool:
	return idle_improvements.has("%d,%d" % [x, y])


func set_idle(x: int, y: int, idle: bool) -> void:
	var key := "%d,%d" % [x, y]
	if idle:
		idle_improvements[key] = true
	else:
		idle_improvements.erase(key)


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"tiles": tiles.duplicate(),
		"improvements": improvements.duplicate(),
		"idle_improvements": idle_improvements.duplicate(),
		"fort_owners": fort_owners.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldMap:
	var map := WorldMap.new()
	map.width = int(data.get("width", 0))
	map.height = int(data.get("height", 0))
	map.tiles = PackedStringArray(data.get("tiles", []))
	map.improvements = PackedStringArray(data.get("improvements", []))
	map.idle_improvements = data.get("idle_improvements", {}).duplicate()
	map.fort_owners = data.get("fort_owners", {}).duplicate(true)
	if map.improvements.size() != map.tiles.size():
		map.improvements.resize(map.tiles.size())
	return map


## A hash of the grid, so "the same seed produces the same map" is checkable.
func map_hash() -> String:
	return Canonical.hash_of(to_dict())


## The map as text, one character per tile. For reading a generated map in a
## terminal, and for nothing the player ever sees.
func to_ascii() -> String:
	var glyphs: Dictionary = {
		"ocean": "~", "sea": ".", "desert": ":", "grassland": ",",
		"plains": "-", "forest": "T", "mountains": "^",
	}
	var lines: PackedStringArray = PackedStringArray()
	for y in height:
		var row := ""
		for x in width:
			row += String(glyphs.get(String(terrain_at(x, y)), "?"))
		lines.append(row)
	return "\n".join(lines)
