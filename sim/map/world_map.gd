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


func _init(p_width: int = 0, p_height: int = 0, fill: StringName = &"ocean") -> void:
	width = p_width
	height = p_height
	tiles = PackedStringArray()
	tiles.resize(width * height)
	tiles.fill(String(fill))


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
	return terrain.yield_of(resource) if terrain != null else 0.0


## What a tile and its neighbours together yield of a resource.
##
## How good a **site** is, rather than how good a tile is: a town works the
## ground around it, not the square it stands on.
func yield_around(x: int, y: int, resource: StringName) -> float:
	var total := yield_at(x, y, resource)
	for at in neighbours(x, y):
		total += yield_at(at.x, at.y, resource)
	return total


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"width": width, "height": height, "tiles": tiles.duplicate()}


static func from_dict(data: Dictionary) -> WorldMap:
	var map := WorldMap.new()
	map.width = int(data.get("width", 0))
	map.height = int(data.get("height", 0))
	map.tiles = PackedStringArray(data.get("tiles", []))
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
