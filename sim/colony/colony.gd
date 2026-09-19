class_name Colony
extends RefCounted

## Everything the PC administers: every town he still holds, loyal or in
## rebellion, their people and their lands (SPEC §4).

var towns: Array[Town] = []


func add(town: Town) -> Town:
	towns.append(town)
	return town


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
