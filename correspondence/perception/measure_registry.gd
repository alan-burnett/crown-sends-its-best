class_name MeasureRegistry
extends RefCounted

## What counts as high or low for a given sim number.
##
## `docs/mechanics/perception.md` §2 divides the labour: the **simulation** owns
## the true number, the **registry** owns what counts as high or low for it, the
## **contact** owns how much he shades it, and the **Author** owns every word the
## player reads.
##
## The Author never needs to know that `crown_war_intensity` runs 0-100 while a
## food ratio runs 0-3. The registry normalises; the ladder supplies words.
##
## The registry grows with the sim. Registering a measure touches nothing in the
## resolver.

## id -> {low, high} for linear measures, or {callable} for custom ones.
##
## Ranges are stored as plain numbers rather than as a closure over them.
## A lambda held in a static registry crashes Godot 4.7 on shutdown, and plain
## data in a static var is also the thing a save can round-trip.
static var _normalizers: Dictionary = {}


## Register a measure that maps linearly from `raw_low` to `raw_high`.
##
## The common case, and the one the Author never sees. `food_security` is
## "stockpile over consumption, 0.0 at a ratio of 0 and 1.0 at a ratio of 3.0".
static func register_linear(id: String, raw_low: float, raw_high: float) -> void:
	if is_equal_approx(raw_low, raw_high):
		push_error("Measure '%s' has an empty range." % id)
		return
	_normalizers[id] = {"low": raw_low, "high": raw_high}


## Register a measure whose normaliser is a named static function taking the raw
## value and returning `[0, 1]`. Not a lambda — see above.
static func register_custom(id: String, normalizer: Callable) -> void:
	_normalizers[id] = {"callable": normalizer}


static func has_measure(id: String) -> bool:
	return _normalizers.has(id)


## Registered measure ids, sorted.
static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_normalizers.keys())
	out.sort()
	return out


## The raw sim value as `p` in `[0, 1]`.
static func normalize(id: String, raw: float) -> float:
	if not _normalizers.has(id):
		push_error("Unknown measure '%s'. Register it before a letter refers to it." % id)
		return 0.0
	var entry: Dictionary = _normalizers[id]
	if entry.has("callable"):
		var normalizer: Callable = entry["callable"]
		return clampf(float(normalizer.call(raw)), 0.0, 1.0)
	var low: float = entry["low"]
	var high: float = entry["high"]
	return clampf((raw - low) / (high - low), 0.0, 1.0)


static func reset() -> void:
	_normalizers = {}
