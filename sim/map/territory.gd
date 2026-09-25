class_name Territory
extends RefCounted

## What the colony holds, what it can work, and what it can see (SPEC §11.2).
##
## **Everything here is derived**, recomputed from the towns each month. Nothing
## is stored by hand, so an influence area cannot drift out of step with the town
## it belongs to — it grows when the town grows because it is a function of it.
##
## This is **phase 3 of the World Month**, and it sits between Movement and the
## Colony Month for a reason: phase 4 assigns population to tiles inside
## influence areas, and recomputing those halfway through would break SPEC
## §11.3's locked phase ordering. In M2 nothing moves yet, so the phase is nearly
## static — it is built in the right place anyway, so that M4 and M5 slot in
## rather than renegotiate.

# --- Tuning ----------------------------------------------------------------

## How far a town's influence reaches at its smallest.
const BASE_INFLUENCE: int = 1

## Population per extra tile of reach. A bigger town works more ground.
const POPULATION_PER_RING: int = 12_000
const MAX_INFLUENCE: int = 4

## **Vision reaches slightly past the border** (SPEC §11.2).
const VISION_MARGIN: int = 2

var influence: Dictionary = {}  ## Vector2i -> town id
var border: Dictionary = {}     ## Vector2i -> true
var visible: Dictionary = {}    ## Vector2i -> true


## How far this town's influence reaches. **Derived from the town**, so it grows
## as the town does — and as it builds.
##
## 🔒 **A building's influence lifts the cap** (#410, the Author's ruling):
## `MAX_INFLUENCE` bounds the rings the population earns, and the rings its
## buildings add sit on top.
static func reach_of(town: Town) -> int:
	var rings := BASE_INFLUENCE + int(town.population() / POPULATION_PER_RING)
	return clampi(rings, BASE_INFLUENCE, MAX_INFLUENCE) + Building.influence_for(town)


## Recompute everything from the colony's towns.
##
## Called in phase 3 and nowhere else. A caller that wanted this mid-month would
## be asking the wrong question.
static func compute(map: WorldMap, towns: Array) -> Territory:
	var territory := Territory.new()

	for town in towns:
		var reach := reach_of(town)
		for at in _within(map, town.at, reach):
			# A tile contested between two towns goes to the first by id, which
			# is stable rather than dependent on iteration order.
			if not territory.influence.has(at):
				territory.influence[at] = String(town.id)

	# The border is the ground the colony's soldiers patrol: everything it works,
	# and the ring immediately around it.
	for at in territory.influence:
		territory.border[at] = true
		for neighbour in map.neighbours(at.x, at.y):
			territory.border[neighbour] = true

	for at in territory.border:
		for seen in _within(map, at, VISION_MARGIN):
			territory.visible[seen] = true

	# **And further, from a town that has built to see** (#410): guard towers
	# carry the town's sight past the common margin, from its own ground.
	for town in towns:
		var further := Building.vision_for(town)
		if further <= 0:
			continue
		# The squares of sight round every tile of its square of ground (its
		# reach and the ring beyond) are one larger square.
		for seen in _within(map, town.at, reach_of(town) + 1 + VISION_MARGIN + further):
			territory.visible[seen] = true

	return territory


## Tiles within `rings` steps, as a square block clipped to the map.
static func _within(map: WorldMap, centre: Vector2i, rings: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-rings, rings + 1):
		for dx in range(-rings, rings + 1):
			var at := Vector2i(centre.x + dx, centre.y + dy)
			if map.in_bounds(at.x, at.y):
				out.append(at)
	return out


# --- Reading ---------------------------------------------------------------

func influenced_by(at: Vector2i) -> StringName:
	return StringName(influence.get(at, ""))


func is_worked_by_anyone(at: Vector2i) -> bool:
	return influence.has(at)


func inside_border(at: Vector2i) -> bool:
	return border.has(at)


func can_see(at: Vector2i) -> bool:
	return visible.has(at)


## The tiles a town works, sorted, so a town's list never depends on iteration
## order.
func tiles_of(town_id: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for at in influence:
		if StringName(influence[at]) == town_id:
			out.append(at)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func to_dict() -> Dictionary:
	# Derived, so it is not saved — it is recomputed in phase 3 on the first
	# month after a reload. Serialised only for tests and traces.
	return {
		"influence": influence.size(),
		"border": border.size(),
		"visible": visible.size(),
	}
