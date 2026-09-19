class_name Reckoning
extends RefCounted

## What a town needs and wants this month, and what it can spare (SPEC §11.3).
##
## **🔒 Needs before wants.** A town covers its needs before it spends on its
## objective or on luxuries, and keeps a reserve before it sells anything to the
## Crown. Reckon establishes these quantities; **Relief, Exchange, Consume, Build
## and Sell all honour them** rather than each working out its own answer.
##
## That is why it is a record rather than a calculation. Five phases asking the
## same question and getting five answers is how a town ends up selling the grain
## it is about to eat.
##
## **Not a ledger.** SPEC §4 fixes Ledger as the gold screen and nothing else.

var town_id: StringName = &""

## What the town will die without: food and clothing, by population (#48).
var needs: Dictionary = {}

## What the objective requires — the rest of the cost of what it is building.
var wants: Dictionary = {}

## Held back before anything is sold. Months of need, per the data.
var reserve: Dictionary = {}

## What is left once needs and reserve are covered. What Relief may give away
## (#45) and Sell may sell (#47).
var spare: Dictionary = {}

## What the town does not have and cannot cover from its own stores. What
## Exchange goes shopping for (#47), and what the letters call a shortage.
var shortfall: Dictionary = {}


func _init(p_town_id: StringName = &"") -> void:
	town_id = p_town_id


func need_of(resource: StringName) -> float:
	return float(needs.get(String(resource), 0.0))


func want_of(resource: StringName) -> float:
	return float(wants.get(String(resource), 0.0))


func reserve_of(resource: StringName) -> float:
	return float(reserve.get(String(resource), 0.0))


func spare_of(resource: StringName) -> float:
	return float(spare.get(String(resource), 0.0))


func shortfall_of(resource: StringName) -> float:
	return float(shortfall.get(String(resource), 0.0))


func is_short() -> bool:
	for resource in shortfall:
		if float(shortfall[resource]) > 0.0:
			return true
	return false


## Resources the town is short of, worst first, then by name.
##
## **Need is served worst-first** when towns give to each other (SPEC §11.3), so
## the order is part of the answer rather than a detail of presentation.
func shortages() -> PackedStringArray:
	var entries: Array = []
	for resource in shortfall:
		if float(shortfall[resource]) > 0.0:
			entries.append([float(shortfall[resource]), String(resource)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		return String(a[1]) < String(b[1]))

	var out: PackedStringArray = PackedStringArray()
	for entry in entries:
		out.append(String(entry[1]))
	return out


func to_dict() -> Dictionary:
	return {
		"town": String(town_id),
		"needs": needs.duplicate(),
		"wants": wants.duplicate(),
		"reserve": reserve.duplicate(),
		"spare": spare.duplicate(),
		"shortfall": shortfall.duplicate(),
	}
