class_name WorldDiff
extends RefCounted

## What changed between two states.
##
## The correspondence layer needs both this and the state itself. Contacts react
## to change — what have you done for me lately — and to standing conditions, so
## "revenue fell by a third this month" and "revenue is low" are different
## letters and need different inputs.
##
## A diff is not a substitute for the event log, either. The log says *what
## happened and why*; the diff says *what is different now*. A value that rose
## and fell back within the month shows in the log and not here, which is
## correct for both of them.

var month_from: int = 0
var month_to: int = 0

## Leaf path -> {"from": Variant, "to": Variant}. `from` is null for a path that
## did not exist before, `to` is null for one that has gone.
var changes: Dictionary = {}


func _init(p_month_from: int = 0, p_month_to: int = 0) -> void:
	month_from = p_month_from
	month_to = p_month_to


## The diff from `before` to `after`.
##
## Both sides are walked as sorted leaf paths, so the result is the same
## whatever order the two states were built in.
static func between(before: WorldState, after: WorldState) -> WorldDiff:
	var diff := WorldDiff.new(before.month, after.month)
	var before_leaves: Dictionary = Canonical.leaf_paths(before.to_dict())
	var after_leaves: Dictionary = Canonical.leaf_paths(after.to_dict())

	var paths: Dictionary = {}
	for path in before_leaves:
		paths[path] = true
	for path in after_leaves:
		paths[path] = true

	var sorted_paths: Array = paths.keys()
	sorted_paths.sort()

	for path in sorted_paths:
		var old_value: Variant = before_leaves.get(path, null)
		var new_value: Variant = after_leaves.get(path, null)
		if not _same(old_value, new_value):
			diff.changes[path] = {"from": old_value, "to": new_value}
	return diff


## Compared through the canonical encoding, so `1` and `1.0` are not the same
## value. A number that changed type between a save and a load is a real
## difference and hiding it here would hide a save bug.
static func _same(a: Variant, b: Variant) -> bool:
	return Canonical.encode(a) == Canonical.encode(b)


func is_empty() -> bool:
	return changes.is_empty()


func changed_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray(changes.keys())
	paths.sort()
	return paths


func has_change(path: String) -> bool:
	return changes.has(path)


## The signed change at a path, for numeric values. Returns 0.0 where either
## side is absent or not a number.
func delta(path: String) -> float:
	if not changes.has(path):
		return 0.0
	var entry: Dictionary = changes[path]
	var old_value: Variant = entry.get("from")
	var new_value: Variant = entry.get("to")
	if not _is_number(old_value) or not _is_number(new_value):
		return 0.0
	return float(new_value) - float(old_value)


static func _is_number(value: Variant) -> bool:
	var kind := typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT


func to_dict() -> Dictionary:
	return {
		"month_from": month_from,
		"month_to": month_to,
		"changes": changes.duplicate(true),
	}


static func from_dict(data: Dictionary) -> WorldDiff:
	var diff := WorldDiff.new(int(data.get("month_from", 0)), int(data.get("month_to", 0)))
	diff.changes = data.get("changes", {}).duplicate(true)
	return diff
