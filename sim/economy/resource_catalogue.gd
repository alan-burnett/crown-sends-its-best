class_name ResourceCatalogue
extends RefCounted

## Every resource the colony knows about.
##
## Loaded from `data/resources/`, so **adding a resource is adding a file**. The
## catalogue is handed the records rather than reading them itself: the sim has
## no business touching the filesystem, and this way the balance harness and the
## tests can supply their own.
##
## Static, like the other registries, because a resource list is a property of
## the game rather than of a run.

static var _kinds: Dictionary = {}  # String -> ResourceKind


## Populate from loaded records. Replaces whatever was there.
static func load_from(records: Array) -> void:
	_kinds = {}
	for record in records:
		var kind := ResourceKind.from_data(record)
		if kind.id.is_empty():
			push_error("A resource record has no id.")
			continue
		_kinds[String(kind.id)] = kind


static func reset() -> void:
	_kinds = {}


static func has(id: StringName) -> bool:
	return _kinds.has(String(id))


static func get_kind(id: StringName) -> ResourceKind:
	if not _kinds.has(String(id)):
		push_error("Unknown resource '%s'." % id)
		return null
	return _kinds[String(id)]


static func size() -> int:
	return _kinds.size()


## Every resource id, sorted. Never iterate the catalogue where order matters.
static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_kinds.keys())
	out.sort()
	return out


## Ids matching a predicate on the resource, sorted.
static func _ids_where(test: Callable) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids():
		if bool(test.call(_kinds[id])):
			out.append(id)
	return out


## **Luxuries are read from the flag**, never listed in code. SPEC §10.2 taxes
## them differently and they provoke far less rebel sentiment; both have to ask
## the resource rather than consult a branch.
static func luxuries() -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return kind.luxury)


static func staples() -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return not kind.luxury and not kind.livestock)


static func livestock() -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return kind.livestock)


## What the colony cannot make for itself, and must buy from the Crown.
static func unproducible() -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return not kind.producible)


static func processed() -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return kind.is_processed())


## What one unit trades for with the Crown, before tax.
static func price_of(id: StringName) -> float:
	var kind := get_kind(id)
	return kind.price if kind != null else 1.0


## Food one head of this eats each month, off pasture.
static func feed_of(id: StringName) -> float:
	var kind := get_kind(id)
	return kind.feed if kind != null else 0.0


## Food one head yields when it is killed for the table.
static func slaughter_yield_of(id: StringName) -> float:
	var kind := get_kind(id)
	return kind.slaughter_yield if kind != null else 0.0


## How much raw resource one unit of this takes to make.
static func input_per_unit_of(id: StringName) -> float:
	var kind := get_kind(id)
	return kind.input_per_unit if kind != null else 1.0


## How much of this one worker makes in a month.
static func per_worker_of(id: StringName) -> float:
	var kind := get_kind(id)
	return kind.per_worker if kind != null else 0.0


## What a tribe would give for it, as a multiple of the Crown's price
## (#136, `town-economy.md` §1).
##
## **A thing is valuable to them when making it requires a craft they cannot
## do.** Iron is worth nothing because they cannot work it; tools are worth a
## great deal for the same reason from the other end. Authored in the resource
## data and inert until M5.
static func native_worth(id: StringName) -> float:
	var kind := get_kind(id)
	return 0.0 if kind == null else kind.native_worth


static func is_livestock(id: StringName) -> bool:
	var kind := get_kind(id)
	return kind != null and kind.livestock


static func is_luxury(id: StringName) -> bool:
	var kind := get_kind(id)
	return kind != null and kind.luxury


static func is_producible(id: StringName) -> bool:
	var kind := get_kind(id)
	return kind != null and kind.producible


# --- Conversions -----------------------------------------------------------

## What `input` can be turned into, sorted.
##
## The other direction from `converts_from`, and the one a producing town asks:
## it has ore, and wants to know what that is good for.
static func conversions_from(input: StringName) -> PackedStringArray:
	return _ids_where(func(kind: ResourceKind) -> bool: return kind.converts_from_resource(input))


## What `output` can be made from, sorted. **Any one of them will do.**
static func inputs_for(output: StringName) -> PackedStringArray:
	var kind := get_kind(output)
	if kind == null:
		return PackedStringArray()
	var out := kind.converts_from.duplicate()
	out.sort()
	return out


## Whether a resource can be reached from raw materials at all, following
## conversions. Used to check the data hangs together rather than at runtime.
static func has_complete_chain(id: StringName, seen: Dictionary = {}) -> bool:
	var kind := get_kind(id)
	if kind == null:
		return false
	if kind.is_raw():
		return kind.producible
	if seen.has(String(id)):
		return false  # A cycle, which is a content mistake.
	seen[String(id)] = true
	for input in kind.converts_from:
		if has_complete_chain(StringName(input), seen.duplicate()):
			return true
	return false
