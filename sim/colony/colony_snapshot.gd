class_name ColonySnapshot
extends RefCounted

## The colony as it stood when a phase began.
##
## **Read-only on purpose.** Every choice in a phase is made from this, not from
## the live colony, so a town that runs third sees the same world the town that
## ran first did. Handing out `Town` objects would let a phase write through it
## by accident and quietly make the running order matter again.

var towns: Dictionary = {}  ## town id -> its state when the phase began


static func of(colony: Colony) -> ColonySnapshot:
	var snapshot := ColonySnapshot.new()
	for town in colony.in_order():
		snapshot.towns[String(town.id)] = town.to_dict()
	return snapshot


func has(id: StringName) -> bool:
	return towns.has(String(id))


## Town ids as they stood, sorted.
func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(towns.keys())
	out.sort()
	return out


## Livestock from the herd, as `Town.held` reads it (#461).
func held(id: StringName, resource: StringName) -> float:
	if not towns.has(String(id)):
		return 0.0
	var pen := "livestock" if ResourceCatalogue.is_livestock(resource) else "stockpile"
	var stock: Dictionary = towns[String(id)].get(pen, {})
	return float(stock.get(String(resource), 0.0))


func workers(id: StringName) -> int:
	if not towns.has(String(id)):
		return 0
	return int(towns[String(id)].get("workers", 0))


func quality_of_life(id: StringName) -> float:
	if not towns.has(String(id)):
		return 0.0
	return float(towns[String(id)].get("quality_of_life", 0.0))


func objective(id: StringName) -> StringName:
	if not towns.has(String(id)):
		return &""
	return StringName(towns[String(id)].get("objective", ""))


## Whatever else a phase needs, by key, as it stood.
func field(id: StringName, key: String, fallback: Variant = null) -> Variant:
	if not towns.has(String(id)):
		return fallback
	return towns[String(id)].get(key, fallback)
