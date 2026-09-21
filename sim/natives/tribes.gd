class_name Tribes
extends RefCounted

## The three peoples already here (#203, SPEC §12.5).
##
## 🔒 **Three, fixed.** §12.5 says three and says nothing about how many villages
## each has, which is #205's question. The number of tribes is not a tuning value
## and is not drawn.
##
## 🔒 **Generated from the map stream**, like the country itself, because they
## are part of what the New World *is* rather than something that happened to it.
## The same seed gives the same three peoples with the same opinions, however
## many dice anything else throws.
##
## 🔒 **And none of them is a contact.** There is no path from here to the
## roster: `Tribes` holds `Tribe`, `Tribe` has no letters, no loyalty and no
## relationship, and `test_natives` asserts that no tribe id ever turns up as a
## letter's sender.

const HOW_MANY: int = 3

## The stream they are drawn from. `mapgen`, not `contacts`, because they are not
## contacts — which is a statement about the design and not only about the dice.
const STREAM: String = "mapgen"

## Where a tribe's opinion of a colony it has not yet met starts.
##
## **Not neutral.** They have seen ships before. Tuning.
const START_MIN: float = 38.0
const START_MAX: float = 62.0

const NAMES: PackedStringArray = [
	"Aneshko", "Wendat", "Katamik", "Osseo", "Tanaquil", "Chiwaya",
	"Meskwan", "Abenki", "Tsalagi", "Nipmuc",
]

var all: Array = []

## Every village on the map. 🔒 **Fixed at generation**, and their number never
## changes by any path — there is no `found` here and nothing that appends after
## generation.
var villages: Array = []

## How many villages each tribe is given. **Not a tuning value in the sense of a
## dial the balance harness sweeps**: §12.5 fixes the tribes and says nothing
## about villages, and `natives.md` §10 lists this as the open item. Two is the
## smallest number that lets a tribe be somewhere rather than a point.
const VILLAGES_EACH: int = 2

## What a village starts with. Tuning.
const START_PEOPLE_MIN: int = 26
const START_PEOPLE_MAX: int = 48


## Draw the three, in a fixed order, from the map's own stream.
static func generate(streams: RngStreams) -> Tribes:
	var tribes := Tribes.new()
	if streams == null:
		return tribes
	var rng := streams.stream(STREAM)

	var names := PackedStringArray(NAMES)
	var taken: Dictionary = {}
	for index in HOW_MANY:
		# Drawn without replacement, so no run has two tribes of a name — a
		# player who could not tell two peoples apart could not learn either.
		var name := ""
		while name.is_empty() or taken.has(name):
			name = names[rng.randi_range(0, names.size() - 1)]
		taken[name] = true

		var tribe := Tribe.new()
		tribe.id = StringName("tribe_%s" % name.to_lower())
		tribe.display_name = name
		tribe.standing = {
			String(Tribe.COLONY): rng.randf_range(START_MIN, START_MAX),
			String(Tribe.CROWN_TROOPS): rng.randf_range(START_MIN, START_MAX),
		}
		tribes.all.append(tribe)
	return tribes


## Put their villages on the map. 🔒 **Once, at generation**, which is the only
## moment a village ever comes into being.
##
## Kept clear of the colony's own site, because a tribe whose village the colony
## was founded on top of would be a tribe the run had already decided about.
func settle(map: WorldMap, away_from: Vector2i, streams: RngStreams) -> void:
	if map == null or streams == null:
		return
	var rng := streams.stream(STREAM)
	for tribe in in_order():
		for index in VILLAGES_EACH:
			var at := _somewhere_to_live(map, away_from, rng)
			if at == Vector2i(-1, -1):
				continue
			var village := Village.new()
			village.id = StringName("village_%s_%d" % [String(tribe.id).replace("tribe_", ""), index])
			village.tribe = tribe.id
			village.at = at
			village.people = rng.randi_range(START_PEOPLE_MIN, START_PEOPLE_MAX)
			village.stores = {"food": float(village.people) * 3.0}
			villages.append(village)


## Ground a village could stand on: land, and not on the colony's doorstep or
## another village's.
func _somewhere_to_live(map: WorldMap, away_from: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 200:
		var at := Vector2i(rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
		if not map.is_land(at.x, at.y):
			continue
		if away_from != Vector2i(-1, -1) and at.distance_squared_to(away_from) < 36:
			continue
		var crowded := false
		for other in villages:
			if (other as Village).at.distance_squared_to(at) < 25:
				crowded = true
				break
		if not crowded:
			return at
	return Vector2i(-1, -1)


## Every village, in id order.
func villages_in_order() -> Array:
	var out: Array = villages.duplicate()
	out.sort_custom(func(a: Village, b: Village) -> bool: return String(a.id) < String(b.id))
	return out


## The villages of one tribe.
func villages_of(tribe: StringName) -> Array:
	var out: Array = []
	for village in villages_in_order():
		if (village as Village).tribe == tribe:
			out.append(village)
	return out


## Whichever tribe works this tile, or empty.
##
## **The question #204 asks of every tile a town wants to work**, and the one the
## map asks to draw the contest.
func holder_of(tile: Vector2i) -> StringName:
	for village in villages_in_order():
		if (village as Village).holds(tile):
			return (village as Village).tribe
	return &""


## Every tribe, in id order. **Sorted**, because anything that iterates them and
## produces a result must not depend on the order they were drawn in.
func in_order() -> Array:
	var out: Array = all.duplicate()
	out.sort_custom(func(a: Tribe, b: Tribe) -> bool: return String(a.id) < String(b.id))
	return out


func find(id: StringName) -> Tribe:
	for tribe in in_order():
		if tribe.id == id:
			return tribe
	return null


## Whichever of them holds the colony in the lowest regard.
##
## What a governor writing about "the natives" means, since he has no more idea
## than the PC which of three peoples the men on the ridge belong to.
func the_angriest() -> Tribe:
	var worst: Tribe = null
	for tribe in in_order():
		if worst == null or tribe.trust() < worst.trust() - 0.0001:
			worst = tribe
	return worst


func to_dict() -> Dictionary:
	var out: Array = []
	for tribe in in_order():
		out.append((tribe as Tribe).to_dict())
	var homes: Array = []
	for village in villages_in_order():
		homes.append((village as Village).to_dict())
	return {"tribes": out, "villages": homes}


static func from_dict(data: Dictionary) -> Tribes:
	var tribes := Tribes.new()
	for entry in data.get("tribes", []):
		tribes.all.append(Tribe.from_dict(entry))
	for entry in data.get("villages", []):
		tribes.villages.append(Village.from_dict(entry))
	return tribes
