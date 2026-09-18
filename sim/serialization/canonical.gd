class_name Canonical
extends RefCounted

## One canonical text form for any serialisable value, and the state hash built
## on it.
##
## Two rules make the hash trustworthy:
##
## 1. **Dictionary keys are sorted.** GDScript dictionaries preserve insertion
##    order, so a hash over raw order would encode the order things happened to
##    be built in, and two equal states could hash differently. Sorting removes
##    the question. This is the same discipline as `CLAUDE.md`'s "no iteration
##    over unordered collections anywhere a result depends on order".
##
## 2. **Floats get one fixed rendering.** `str(0.1 + 0.2)` is free to vary in its
##    last digit between builds; `String.num(value, FLOAT_PRECISION)` does not.
##
## Integers and floats render differently on purpose, so `1` and `1.0` never
## collide. Godot's JSON parser returns every number as a float (see
## `JsonTypes`), and a value that silently changed type between a save and a
## load would move the hash without changing the state.

const FLOAT_PRECISION: int = 12


## A stable text rendering of `value`. Not JSON, and not meant to be parsed —
## its only job is to be identical for identical values and different otherwise.
static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return "i%d" % value
		TYPE_FLOAT:
			return "f%s" % String.num(value, FLOAT_PRECISION)
		TYPE_STRING, TYPE_STRING_NAME:
			return "s%s" % String(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var items: PackedStringArray = PackedStringArray()
			for item in value:
				items.append(encode(item))
			return "[%s]" % ",".join(items)
		TYPE_DICTIONARY:
			return _encode_dictionary(value)
		_:
			push_error("Canonical.encode(): unsupported type %d. Sim state must be plain data." % typeof(value))
			return "?"


static func _encode_dictionary(value: Dictionary) -> String:
	var keys: Array = value.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var pairs: PackedStringArray = PackedStringArray()
	for key in keys:
		pairs.append("%s:%s" % [String(key), encode(value[key])])
	return "{%s}" % ",".join(pairs)


## A hex state hash. Equal states hash equally; different states almost never do.
static func hash_of(value: Variant) -> String:
	return "%08x" % StableHash.of_string(encode(value))


## Every leaf path in a nested structure, sorted, as "a.b[0].c" style keys.
## `WorldDiff` walks these so a diff between two states is itself deterministic.
static func leaf_paths(value: Variant, prefix: String = "") -> Dictionary:
	var out: Dictionary = {}
	_collect_leaves(value, prefix, out)
	return out


static func _collect_leaves(value: Variant, prefix: String, out: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
			for key in keys:
				var child: String = String(key) if prefix.is_empty() else "%s.%s" % [prefix, key]
				_collect_leaves(value[key], child, out)
		TYPE_ARRAY:
			for index in value.size():
				_collect_leaves(value[index], "%s[%d]" % [prefix, index], out)
		_:
			out[prefix] = value
