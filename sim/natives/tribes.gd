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

## 🔒 **How much further down that band begins** (#288, *Restless
## country*).
##
## **Zero in every run without the quirk**, and negative under it: they have seen
## ships before and they did not care for them.
##
## 🔒 **A shift on the band, not a narrowing of it.** The spread between a
## tribe that will deal and one that will not is what makes three neighbours three
## characters, and a quirk that collapsed it would leave the PC facing one people
## in triplicate. They all start lower and they still differ by as much.
##
## It moves the draw rather than the tribes afterwards, so it costs nothing at
## run time and a save carries only the figures it produced.
static var _start_shift: float = 0.0


static func start_shift() -> float:
	return _start_shift


static func set_start_shift(shift: float) -> void:
	_start_shift = shift


static func reset() -> void:
	_start_shift = 0.0

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
const START_PEOPLE_MIN: int = 26_000
const START_PEOPLE_MAX: int = 48_000


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
		# **Both draws happen whatever the shift is**, so the stream advances the
		# same way and a run with the quirk is the same map as one without it.
		var toward_colony := rng.randf_range(START_MIN, START_MAX)
		var toward_crown := rng.randf_range(START_MIN, START_MAX)
		tribe.standing = {
			String(Tribe.COLONY): _shifted(toward_colony),
			String(Tribe.CROWN_TROOPS): _shifted(toward_crown),
		}
		tribes.all.append(tribe)
	return tribes


static func _shifted(standing: float) -> float:
	return clampf(standing + _start_shift, Tribe.MINIMUM, Tribe.MAXIMUM)


## How near the colony settles to its neighbours (#274, `map.md` §8).
##
## 🔒 **Only the nearest neighbour is in question.** Two tribes are distant
## whatever the PC answers, so the rest of the native game arrives in its own
## time however he chose — what he is deciding is **who is over the next ridge,
## not how many there are.**
const NEAR: StringName = &"near"
const APART: StringName = &"apart"

const PROXIMITIES: Array[StringName] = [APART, NEAR]

## The bands, in tiles from the colony's site. Tuning.
##
## The first tribe moves between the first two; the other two are always far and
## very far.
const CLOSE: int = 6
const MEDIUM: int = 12
const FAR: int = 18
const VERY_FAR: int = 24

## How near a tribe's second village sits to its first. They are one people, and
## a people scattered to opposite ends of the map is two peoples.
const VILLAGES_APART: int = 4


static func is_proximity(id: StringName) -> bool:
	return PROXIMITIES.has(id)


## Where each tribe sits, nearest first.
static func bands_for(proximity: StringName) -> Array[int]:
	return [CLOSE if proximity == NEAR else MEDIUM, FAR, VERY_FAR]


## Put their villages on the map. 🔒 **Once, at generation**, which is the only
## moment a village ever comes into being.
##
## 🔒 **After the site, and relative to it** (#274, §8). The order is the whole
## of how the second question is honoured: searching for ground that happened to
## sit the right distance from a village would fight the terrain request and
## lose, because a good defensive mountain that is *also* exactly six tiles from
## a tribe is a great deal to ask of one seed. Placing the villages afterwards
## honours both questions exactly, on every seed.
##
## 🔒 **And being placed near a tribe is not itself an offence.** The colony did
## not choose its neighbours' land; it was put there. Standing starts where it
## starts and what the colony does next is what moves it — there is no call to
## `TribeStanding` anywhere in this file.
func settle(
	map: WorldMap,
	away_from: Vector2i,
	streams: RngStreams,
	proximity: StringName = APART,
) -> void:
	if map == null or streams == null:
		return
	var rng := streams.stream(STREAM)
	var bands := bands_for(proximity)

	var rank := 0
	for tribe in in_order():
		# The people, then their second village beside them.
		var anchor := _somewhere_at(
			map, away_from, bands[mini(rank, bands.size() - 1)], rng)
		if anchor == Vector2i(-1, -1):
			anchor = _somewhere_to_live(map, away_from, rng)
		for index in VILLAGES_EACH:
			var at := anchor if index == 0 else _beside(map, anchor, rng)
			if at == Vector2i(-1, -1):
				continue
			var village := Village.new()
			village.id = StringName("village_%s_%d" % [String(tribe.id).replace("tribe_", ""), index])
			village.tribe = tribe.id
			village.at = at
			village.people = rng.randi_range(START_PEOPLE_MIN, START_PEOPLE_MAX)
			village.stores = {"food": Population.of(3.0, float(village.people))}
			villages.append(village)
		rank += 1


## Ground about this far from the colony, or nowhere.
func _somewhere_at(
	map: WorldMap,
	from: Vector2i,
	band: int,
	rng: RandomNumberGenerator,
) -> Vector2i:
	# Widened a ring at a time, so a band nothing sits in exactly is answered by
	# the nearest thing to it rather than by giving up.
	for slack in range(1, 6):
		for _attempt in 120:
			var at := Vector2i(
				rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
			if not map.is_land(at.x, at.y) or _crowded(at):
				continue
			if from == Vector2i(-1, -1):
				return at
			var away := sqrt(float(at.distance_squared_to(from)))
			if absf(away - float(band)) <= float(slack):
				return at
	return Vector2i(-1, -1)


## And a second village within a short walk of the first.
func _beside(map: WorldMap, anchor: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 120:
		var at := anchor + Vector2i(
			rng.randi_range(-VILLAGES_APART, VILLAGES_APART),
			rng.randi_range(-VILLAGES_APART, VILLAGES_APART))
		if not map.in_bounds(at.x, at.y) or not map.is_land(at.x, at.y):
			continue
		if not _crowded(at):
			return at
	return Vector2i(-1, -1)


func _crowded(at: Vector2i) -> bool:
	for other in villages:
		if (other as Village).at.distance_squared_to(at) < 9:
			return true
	return false


## Ground a village could stand on when no band could be answered: land, clear of
## the colony's doorstep and of another village.
func _somewhere_to_live(map: WorldMap, away_from: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 200:
		var at := Vector2i(rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
		if not map.is_land(at.x, at.y):
			continue
		if away_from != Vector2i(-1, -1) and at.distance_squared_to(away_from) < 36:
			continue
		if not _crowded(at):
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
