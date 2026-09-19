class_name ColonyNeeds
extends RefCounted

## What a town consumes, and how much it keeps back (#44).
##
## **Reserve sizing is data, not a magic number in code.** A town covers its
## needs, holds a reserve against the months ahead, and only what is left over is
## spare — and how many months it holds is the sort of number that gets tuned
## every playtest.

static var _per_head: Dictionary = {"food": 1.0, "clothing": 0.15}
static var _reserve_months: Dictionary = {"food": 2.0, "clothing": 1.0}
static var _default_reserve_months: float = 0.5

## How many months of food a town considers comfortable. Above this it stops
## treating hunger as urgent.
const COMFORTABLE_MONTHS: float = 3.0


static func load_from(record: Dictionary) -> void:
	_per_head = record.get("per_head", _per_head).duplicate()
	_reserve_months = record.get("reserve_months", _reserve_months).duplicate()
	_default_reserve_months = float(record.get("default_reserve_months", _default_reserve_months))


## Consumed per head each month. **Absence of these threatens survival**, which
## is what makes them needs rather than wants (SPEC §11.3).
static func per_head(resource: StringName) -> float:
	return float(_per_head.get(String(resource), 0.0))


## Resources a town needs to live, sorted.
static func needed_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_per_head.keys())
	out.sort()
	return out


static func reserve_months(resource: StringName) -> float:
	return float(_reserve_months.get(String(resource), _default_reserve_months))


static func comfortable_months() -> float:
	return COMFORTABLE_MONTHS
