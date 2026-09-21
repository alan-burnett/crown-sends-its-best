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
	return {"tribes": out}


static func from_dict(data: Dictionary) -> Tribes:
	var tribes := Tribes.new()
	for entry in data.get("tribes", []):
		tribes.all.append(Tribe.from_dict(entry))
	return tribes
