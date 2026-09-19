class_name JsonTypes
extends RefCounted

## Reading typed values back out of parsed JSON.
##
## **Godot's JSON parser returns every number as a float.** `{"amount": 200}`
## parses as `200.0`. Left alone that reaches the player: `{param:amount}`
## renders "200.0" in a letter, which is exactly the class of mistake the
## content validator (#8) exists to catch before a player ever sees it. It also
## moves the state hash without changing the state, because `Canonical` renders
## `200` and `200.0` differently on purpose.
##
## So content is coerced against its declared type at the point it is read.
## `params` in a letter file (SPEC §9.2, #8) declares `integer`, `gold`,
## `resource` and the rest; those declarations drive these calls. That is what
## makes the typed contract do work rather than document an intention.

## An integer, or an error if the value is not one.
##
## `200.0` is accepted and returns 200 — JSON has no integer type and the author
## wrote `200`. `200.5` is refused, because the author wrote something this
## field cannot hold and quietly truncating it would lose a real mistake.
static func to_int(value: Variant, context: String = "value") -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			if not is_equal_approx(value, roundf(value)):
				push_error("%s: expected a whole number, got %s" % [context, value])
				return 0
			return int(roundf(value))
		TYPE_STRING:
			if value.is_valid_int():
				return value.to_int()
	push_error("%s: expected a whole number, got %s (%s)" % [context, value, type_string(typeof(value))])
	return 0


static func is_int_like(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_equal_approx(value, roundf(value))
	return false


static func to_float(value: Variant, context: String = "value") -> float:
	var kind := typeof(value)
	if kind == TYPE_FLOAT or kind == TYPE_INT:
		return float(value)
	push_error("%s: expected a number, got %s (%s)" % [context, value, type_string(kind)])
	return 0.0


static func to_string_value(value: Variant, context: String = "value") -> String:
	var kind := typeof(value)
	if kind == TYPE_STRING or kind == TYPE_STRING_NAME:
		return String(value)
	push_error("%s: expected a string, got %s (%s)" % [context, value, type_string(kind)])
	return ""


static func to_bool(value: Variant, context: String = "value") -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	push_error("%s: expected true or false, got %s (%s)" % [context, value, type_string(typeof(value))])
	return false


## Walk a parsed tree and turn every integral float back into an int.
##
## Used where a whole file is known to hold no genuine fractional values. It is
## deliberately **not** the default: a lean of `0.3` and a tax rate of `0.0` are
## both real floats, and a blanket conversion would corrupt the first time
## someone writes `1.0` and means it. Declared types are the reliable route;
## this is for the cases that have no schema.
static func normalise_integers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(roundf(value)) if is_equal_approx(value, roundf(value)) else value
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(normalise_integers(item))
			return items
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in value:
				out[key] = normalise_integers(value[key])
			return out
	return value
