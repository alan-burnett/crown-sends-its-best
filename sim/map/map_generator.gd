class_name MapGenerator
extends RefCounted

## Generates the New World from the run seed (SPEC §11.1, §16.1).
##
## **Every draw comes from the `mapgen` stream and nothing else**, so the same
## seed always produces the same map however many dice any other system throws.
##
## The aim is **coherent landmasses with an ocean edge**, not noise. Noise gives
## a map with no shape to it — no coast worth settling, no interior, nothing that
## reads as a place. So land is grown from a handful of seeds rather than rolled
## per tile, which produces blobs with real coastlines and the occasional island.
##
## Colony site selection among several generated regions is SPEC §6.1 and belongs
## to Run Setup in M3. **M2 generates one map and places one town on it**, and
## `choose_starting_site` is the seam that will one day offer a choice.

const DEFAULT_WIDTH: int = 34
const DEFAULT_HEIGHT: int = 26

## Ocean around the whole map. The New World is reached by sea.
const OCEAN_MARGIN: int = 2

# --- Tuning ----------------------------------------------------------------
#
# All of it. The shape of a continent is a thing to look at and adjust.

const LANDMASS_MIN: int = 2
const LANDMASS_MAX: int = 4
## Share of the inner area that ends up as land, before coastlines are cut.
const LAND_SHARE: float = 0.42
## How strongly a growing landmass prefers to stay compact rather than sprawl.
const COMPACTNESS: float = 0.65

## Terrain weights inland. Mountains cluster, deserts are rare.
const INLAND_WEIGHTS: Dictionary = {
	"plains": 0.30, "grassland": 0.28, "forest": 0.27, "mountains": 0.10, "desert": 0.05,
}
## Coastal land is gentler — nobody lands on a mountain.
const COASTAL_WEIGHTS: Dictionary = {
	"plains": 0.38, "grassland": 0.36, "forest": 0.22, "desert": 0.04,
}


## Generate a map. `rng` must be the `mapgen` stream.
##
## Generating without the terrain table loaded would ask about every tile in
## turn and be told, every time, that it does not know — so it says so once and
## hands back an empty map instead.
static func generate(rng: RandomNumberGenerator, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> WorldMap:
	if Terrain.land_ids().is_empty():
		push_error("Cannot generate a map: no terrain is loaded.")
		return WorldMap.new(0, 0)

	var map := WorldMap.new(width, height, &"ocean")
	var land := _grow_land(rng, map)
	_paint_terrain(rng, map, land)
	_cut_shallows(map)
	return map


## Grow a few landmasses from seed points, well inside the ocean margin.
##
## Each step takes a tile from the frontier and spreads to its neighbours. Taking
## from near the end of the frontier keeps a mass compact; taking from anywhere
## in it lets the mass sprawl into peninsulas. The mix of the two is what makes a
## coastline look like a coastline.
static func _grow_land(rng: RandomNumberGenerator, map: WorldMap) -> Dictionary:
	var inner_width := map.width - OCEAN_MARGIN * 2
	var inner_height := map.height - OCEAN_MARGIN * 2
	var target := int(float(inner_width * inner_height) * LAND_SHARE)

	var land: Dictionary = {}
	var frontier: Array[Vector2i] = []

	var masses := rng.randi_range(LANDMASS_MIN, LANDMASS_MAX)
	for i in masses:
		var seed_at := Vector2i(
			rng.randi_range(OCEAN_MARGIN + 1, map.width - OCEAN_MARGIN - 2),
			rng.randi_range(OCEAN_MARGIN + 1, map.height - OCEAN_MARGIN - 2),
		)
		land[seed_at] = true
		frontier.append(seed_at)

	while land.size() < target and not frontier.is_empty():
		var index := frontier.size() - 1
		if rng.randf() > COMPACTNESS:
			index = rng.randi_range(0, frontier.size() - 1)
		var from: Vector2i = frontier[index]
		frontier.remove_at(index)

		for at in map.neighbours(from.x, from.y):
			if land.has(at):
				continue
			if at.x < OCEAN_MARGIN or at.y < OCEAN_MARGIN:
				continue
			if at.x >= map.width - OCEAN_MARGIN or at.y >= map.height - OCEAN_MARGIN:
				continue
			# Not every neighbour, or the mass grows as a diamond.
			if rng.randf() < 0.45:
				continue
			land[at] = true
			frontier.append(at)
			if land.size() >= target:
				break

	return land


static func _paint_terrain(rng: RandomNumberGenerator, map: WorldMap, land: Dictionary) -> void:
	# Sorted, so the order tiles are painted in does not depend on how the
	# dictionary happened to be built.
	var positions: Array = land.keys()
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))

	for at in positions:
		var coastal := false
		for neighbour in map.neighbours(at.x, at.y):
			if not land.has(neighbour):
				coastal = true
				break
		map.set_terrain(at.x, at.y, _weighted_terrain(rng, COASTAL_WEIGHTS if coastal else INLAND_WEIGHTS))


static func _weighted_terrain(rng: RandomNumberGenerator, weights: Dictionary) -> StringName:
	var names: Array = weights.keys()
	names.sort()
	var total: float = 0.0
	for name in names:
		total += float(weights[name])

	var roll := rng.randf() * total
	for name in names:
		roll -= float(weights[name])
		if roll <= 0.0:
			return StringName(name)
	return StringName(names[names.size() - 1])


## Water touching land becomes sea; the rest stays ocean.
##
## Sea yields high food and ocean yields almost none (§11.1), so this is what
## makes a coastal site worth having.
static func _cut_shallows(map: WorldMap) -> void:
	var shallows: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.is_land(x, y):
				continue
			for at in map.neighbours(x, y):
				if map.is_land(at.x, at.y):
					shallows.append(Vector2i(x, y))
					break
	for at in shallows:
		map.set_terrain(at.x, at.y, &"sea")


## Where the first town goes.
##
## **A site that can actually sustain a town**, so M2 is playable rather than a
## famine simulator: the best food in reach, with a coast preferred because a
## colony that cannot be resupplied is a short story.
##
## Ties break on position, so the choice is the map's rather than the
## dictionary's.
static func choose_starting_site(map: WorldMap) -> Vector2i:
	var ranked := sites_by_score(map)
	return ranked[0] if not ranked.is_empty() else Vector2i(-1, -1)


## Every land tile, best site first.
##
## **The seam SPEC §6.1 needs**, where Run Setup offers a choice of regions
## rather than dropping the town on the best ground on the map. It exists now
## because the balance harness needs the other end of the list: no colony has
## ever gone hungry (#90), and a colony that always starts on the best food in
## reach never will, so there is no evidence about how a town behaves on ground
## it cannot live on.
##
## Ties break on position, so the order is the map's rather than the traversal's.
static func sites_by_score(map: WorldMap) -> Array[Vector2i]:
	var scored: Array = []
	for y in map.height:
		for x in map.width:
			if map.is_land(x, y):
				scored.append([site_score(map, x, y), y, x])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[2]) < int(b[2])))

	var out: Array[Vector2i] = []
	for entry in scored:
		out.append(Vector2i(int(entry[2]), int(entry[1])))
	return out


## How good a site is. Food first, then the makings of a town, then the sea.
static func site_score(map: WorldMap, x: int, y: int) -> float:
	var score := map.yield_around(x, y, &"food") * 2.0
	score += map.yield_around(x, y, &"wood")
	score += map.yield_around(x, y, &"stone") * 0.5
	for at in map.neighbours(x, y):
		if map.terrain_at(at.x, at.y) == &"sea":
			score += 3.0
			break
	return score
