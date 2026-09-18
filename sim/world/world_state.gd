class_name WorldState
extends RefCounted

## The full serialisable state of the world at a point in time.
##
## M1's world is the stub (#20), so the substance here is a bag of named values.
## The shape is what matters: the sim owns state, state is plain data, and it
## round-trips without loss. M2 adds towns and tiles inside this envelope.
##
## **Changing state goes through `apply()`, which requires an `EventLog`.**
## Seam A says the sim emits rather than merely mutating, and making the log an
## argument is the cheapest way to stop that being a rule people remember to
## follow. A caller who wants to change a value has to have somewhere to say so.

## The sim's own schema version. The save envelope (#6) stamps its own version
## on top of this; this one tracks the shape of the state itself.
const STATE_VERSION: int = 1

const MONTHS_PER_YEAR: int = 12

var version: int = STATE_VERSION

## Months elapsed since the run began. Month 0 is the first turn.
var month: int = 0

## Named scalars the world is made of. #20 decides what lives here in M1.
var values: Dictionary = {}


func _init(p_month: int = 0, p_values: Dictionary = {}) -> void:
	month = p_month
	values = p_values.duplicate(true)


# --- Calendar --------------------------------------------------------------
#
# SPEC §9.6 locks the phase of a run to the calendar year, not colony size, so
# the year has to be derivable from state alone. What the months are *called*
# is flavour and belongs to presentation, not here.

## 1-based year of the run. Months 0-11 are year 1.
func year_index() -> int:
	return month / MONTHS_PER_YEAR + 1


## 1-based month within the year, 1 to 12.
func month_of_year() -> int:
	return month % MONTHS_PER_YEAR + 1


# --- Reading ---------------------------------------------------------------

func get_value(key: String, default_value: Variant = 0.0) -> Variant:
	return values.get(key, default_value)


func has_value(key: String) -> bool:
	return values.has(key)


## Value keys, sorted. Never iterate `values` directly where order matters.
func value_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray(values.keys())
	keys.sort()
	return keys


# --- Changing --------------------------------------------------------------

## Apply a set of changes and emit one event describing them.
##
## `changes` maps value key to its new value. The emitted payload carries both
## the old and new value of each, so a consumer can render "revenue fell by 40"
## without holding the previous state.
func apply(log: EventLog, type: StringName, subject: StringName, changes: Dictionary) -> SimEvent:
	var keys: Array = changes.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var recorded: Dictionary = {}
	for key in keys:
		var key_text := String(key)
		var before: Variant = values.get(key_text, null)
		var after: Variant = changes[key]
		values[key_text] = after
		recorded[key_text] = {"from": before, "to": after}
	return log.emit(type, subject, month, {"changes": recorded})


## Advance to the next month. The turn machine (#7) owns when this is called.
func advance_month(log: EventLog) -> SimEvent:
	month += 1
	return log.emit(&"month_advanced", &"world", month, {
		"month": month,
		"year": year_index(),
		"month_of_year": month_of_year(),
	})


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": version,
		"month": month,
		"values": values.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldState:
	var state := WorldState.new(int(data.get("month", 0)), data.get("values", {}))
	state.version = int(data.get("version", STATE_VERSION))
	return state


func duplicate_state() -> WorldState:
	return WorldState.from_dict(to_dict())


## Identical states hash identically, on any platform and in any process.
func state_hash() -> String:
	return Canonical.hash_of(to_dict())
