class_name Colony
extends RefCounted

## Everything the PC administers: every town he still holds, loyal or in
## rebellion, their people and their lands (SPEC §4).
##
## 🔒 **A rebel town is still part of the colony** (SPEC §12.3). In the Crown's
## eyes it still belongs to the PC and his job is to bring it back into line.
## What is *not* part of it any more is a **lost town** — one rivals or natives
## have destroyed or taken — and `lost()` below is the only way out.

## The one thing that can happen to a town that ends its membership of the
## colony (#210, SPEC §12.3; `prestige.md` §4).
const EVENT_LOST: StringName = &"town_lost"

var towns: Array[Town] = []


func add(town: Town) -> Town:
	towns.append(town)
	return town


## A town has been destroyed or taken, and is no longer the PC's (Seam A).
##
## 🔒 **The only way out of the colony**, and deliberately the only one. A rebel
## town has not left; it is misbehaving, and §12.3 is explicit that the Crown
## still holds the PC responsible for it. The day a dev makes rebellion remove a
## town from this list, an optic worth three thousand gold starts firing on a
## thing the spec says has not happened.
##
## 🔒 **The optic fires here and exactly once**, because a town can only be
## removed once. `prestige.md` §4 prices it; this file only says it happened, and
## the court decides what to make of it.
##
## **Nothing calls this yet.** Taking a town needs rivals and natives who can
## fight, which is M6 — so this is the seam that milestone fills, said out loud
## rather than left as a gap somebody has to discover.
func lost(town: Town, to: StringName, why: String, context: ColonyContext) -> bool:
	if town == null or by_id(town.id) == null:
		return false
	towns.erase(town)
	context.log.emit(EVENT_LOST, town.id, context.state.month, {
		"town": String(town.id),
		"name": town.display_name,
		"to": String(to),
		"why": why,
		"population": town.population(),
		"at": [town.at.x, town.at.y],
	}, WorldPhase.COLONY_MONTH)
	return true


func by_id(id: StringName) -> Town:
	for town in towns:
		if town.id == id:
			return town
	return null


func at(position: Vector2i) -> Town:
	for town in towns:
		if town.at == position:
			return town
	return null


## Town ids, sorted. Never iterate towns where the result depends on order.
func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for town in towns:
		out.append(String(town.id))
	out.sort()
	return out


## Towns in id order. **Every town completes a phase before any town begins the
## next** (SPEC §11.3), and a fixed order is what makes "no town benefits from
## being simulated first" testable.
func in_order() -> Array[Town]:
	var sorted_towns := towns.duplicate()
	sorted_towns.sort_custom(func(a: Town, b: Town) -> bool: return String(a.id) < String(b.id))
	return sorted_towns


## The order towns are simulated in, **fixed by the seed** (SPEC §11.3).
##
## Id order would be deterministic too, but it would also mean Ashmere always
## went first, in every run, for ever. Seeding the order means no town has a
## standing advantage, while the same seed still replays exactly.
func simulation_order(run_seed: int) -> Array[Town]:
	var keyed: Array = []
	for town in towns:
		keyed.append([StableHash.stream_seed(run_seed, "town_order:" + String(town.id)), town])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		return String(a[1].id) < String(b[1].id))

	var out: Array[Town] = []
	for entry in keyed:
		out.append(entry[1])
	return out


## The town this contact speaks for, or null.
##
## **One governor, one town** (SPEC §8.2), which is what lets a letter addressed
## to a man be an instruction about a place without naming the place.
func governed_by(contact_id: StringName) -> Town:
	if String(contact_id).is_empty():
		return null
	for town in in_order():
		if town.governor_id == contact_id:
			return town
	return null


func loyal() -> Array[Town]:
	var out: Array[Town] = []
	for town in in_order():
		if not town.rebelling:
			out.append(town)
	return out


func size() -> int:
	return towns.size()


func is_empty() -> bool:
	return towns.is_empty()


func to_dict() -> Dictionary:
	var entries: Array = []
	for town in in_order():
		entries.append(town.to_dict())
	return {"towns": entries}


static func from_dict(data: Dictionary) -> Colony:
	var colony := Colony.new()
	for entry in data.get("towns", []):
		colony.towns.append(Town.from_dict(entry))
	return colony
