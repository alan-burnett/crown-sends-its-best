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
static var _luxury_per_head: float = 0.12
static var _severity: Dictionary = {"food": 1.0, "clothing": 0.5}

## How many months of food a town considers comfortable. Above this it stops
## treating hunger as urgent.
const COMFORTABLE_MONTHS: float = 3.0


static func load_from(record: Dictionary) -> void:
	_per_head = record.get("per_head", _per_head).duplicate()
	_reserve_months = record.get("reserve_months", _reserve_months).duplicate()
	_default_reserve_months = float(record.get("default_reserve_months", _default_reserve_months))
	_luxury_per_head = float(record.get("luxury_per_head", _luxury_per_head))
	_severity = record.get("severity", _severity).duplicate()


## Back to the declared defaults.
##
## **The only `load_from` in the game that had no partner**, so a test that loaded
## a tuned record left it loaded for whatever ran next. `TestCase.reset_world()`
## calls this one with the rest.
static func reset() -> void:
	_per_head = {"food": 1.0, "clothing": 0.15}
	_reserve_months = {"food": 2.0, "clothing": 1.0}
	_default_reserve_months = 0.5
	_luxury_per_head = 0.12
	_severity = {"food": 1.0, "clothing": 0.5}


## Consumed per head each month. **Absence of these threatens survival**, which
## is what makes them needs rather than wants (SPEC §11.3).
static func per_head(resource: StringName) -> float:
	return float(_per_head.get(String(resource), 0.0))


## Resources a town needs to live, sorted.
static func needed_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_per_head.keys())
	out.sort()
	return out


## **How fast going without this kills you**, as a share of the worst case.
##
## Needs are not equal. A town with no grain is dead in weeks; a town with no
## cloth is merely wretched, for months. Without this the two rank the same and
## a starving town goes trapping furs because it is also cold — which is the
## same failure as a town quarrying while it starves, wearing a different coat.
static func severity(resource: StringName) -> float:
	return float(_severity.get(String(resource), 1.0))


static func reserve_months(resource: StringName) -> float:
	return float(_reserve_months.get(String(resource), _default_reserve_months))


## **The ceiling on comfort bought with drink** (#48). Consumption above this is
## not consumed at all, so a rich town cannot buy its way to perfect contentment
## and make quality of life stop being about how the colony is run.
static func luxury_per_head() -> float:
	return _luxury_per_head


static func comfortable_months() -> float:
	return COMFORTABLE_MONTHS
