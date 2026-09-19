class_name ContentRegistry
extends RefCounted

## Conditions and effects are **ids into a code-side registry with typed
## params**, never logic in a data file.
##
## That keeps content declarative and gives the validator something to check
## against: an unregistered id, or an effect called with a missing or wrongly
## typed argument, is caught at build time rather than at the moment a player
## opens the letter.
##
## **An effect produces an Order. It never writes sim state** (Seam B). That is
## structural here rather than a rule to remember: an effect registration
## *declares the kind of Order it makes*, and the default builder is the only
## code that runs. A handler has nowhere to put a write even if it wanted one.

## Types an effect or condition parameter may declare. The letter param types,
## plus the few a handler needs that never appear in a letter's `params` block.
const ARG_TYPES: Array[StringName] = [
	&"resource", &"integer", &"gold", &"town", &"contact",
	&"tribe", &"rival", &"tile", &"building", &"objective",
	&"string", &"bool", &"number", &"tone",
]

static var _effects: Dictionary = {}  # id -> {params, order_kind, builder}
static var _conditions: Dictionary = {}  # id -> {params, predicate}


# --- Registration ----------------------------------------------------------

## Declare an effect: its id, its typed params, and the Order it produces.
##
## `builder` is optional and exists for effects that need to shape the Order
## from more than its arguments. Leaving it out is the normal case and is what
## makes "no effect writes sim state" true by construction.
static func register_effect(
	id: String,
	params: Dictionary,
	order_kind: StringName,
	builder: Callable = Callable(),
) -> void:
	if not _check_param_types(id, params):
		return
	_effects[id] = {"params": params.duplicate(), "order_kind": order_kind, "builder": builder}


## Declare a condition: its id, its typed params, and the predicate.
##
## The predicate takes `(args: Dictionary, context: LetterContext) -> bool` and
## only ever reads.
static func register_condition(id: String, params: Dictionary, predicate: Callable) -> void:
	if not _check_param_types(id, params):
		return
	_conditions[id] = {"params": params.duplicate(), "predicate": predicate}


static func _check_param_types(id: String, params: Dictionary) -> bool:
	for name in params:
		var declared := StringName(params[name])
		if not ARG_TYPES.has(declared):
			push_error("'%s' declares param '%s' as unknown type '%s'." % [id, name, declared])
			return false
	return true


static func reset() -> void:
	_effects = {}
	_conditions = {}


# --- Enumeration, for the validator ----------------------------------------

static func has_effect(id: String) -> bool:
	return _effects.has(id)


static func has_condition(id: String) -> bool:
	return _conditions.has(id)


static func effect_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_effects.keys())
	out.sort()
	return out


static func condition_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_conditions.keys())
	out.sort()
	return out


static func effect_params(id: String) -> Dictionary:
	return _effects.get(id, {}).get("params", {})


static func condition_params(id: String) -> Dictionary:
	return _conditions.get(id, {}).get("params", {})


# --- Checking a call site --------------------------------------------------

## Problems with calling `id` with `supplied`, as readable strings. Empty means
## the call is well formed.
##
## Values in content may be slot references like `"{amount}"`, which the director
## fills in at send time. Those are checked for **being declared**, not for their
## runtime type, since there is no value yet to check.
static func check_effect_call(id: String, supplied: Dictionary) -> PackedStringArray:
	if not has_effect(id):
		return PackedStringArray(["unregistered effect '%s'" % id])
	return _check_args(id, effect_params(id), supplied)


static func check_condition_call(id: String, supplied: Dictionary) -> PackedStringArray:
	if not has_condition(id):
		return PackedStringArray(["unregistered condition '%s'" % id])
	return _check_args(id, condition_params(id), supplied)


static func _check_args(id: String, declared: Dictionary, supplied: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()

	var expected: Array = declared.keys()
	expected.sort()
	for name in expected:
		if not supplied.has(name):
			problems.append("'%s' is missing param '%s' (%s)" % [id, name, declared[name]])

	var given: Array = supplied.keys()
	given.sort()
	for name in given:
		if not declared.has(name):
			problems.append("'%s' has no param '%s'" % [id, name])
			continue
		var value: Variant = supplied[name]
		if _is_slot_reference(value):
			continue
		if not _matches(value, StringName(declared[name])):
			problems.append("'%s' param '%s' expects %s, got %s" % [
				id, name, declared[name], type_string(typeof(value)),
			])
	return problems


## A `"{name}"` placeholder the director fills from the letter's params.
static func _is_slot_reference(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and value.begins_with("{") and value.ends_with("}")


static func _matches(value: Variant, declared: StringName) -> bool:
	match declared:
		&"integer", &"gold":
			return JsonTypes.is_int_like(value)
		&"number":
			var kind := typeof(value)
			return kind == TYPE_INT or kind == TYPE_FLOAT
		&"bool":
			return typeof(value) == TYPE_BOOL
		&"tone":
			return typeof(value) == TYPE_STRING and Tone.is_tone(StringName(value))
		_:
			# The id-like types are all strings naming something in the world.
			# What they name is checked when the world can answer.
			return typeof(value) == TYPE_STRING


# --- Running ---------------------------------------------------------------

## Fire an effect. Returns the Order it produced, or null.
static func run_effect(id: String, args: Dictionary, context: LetterContext) -> Order:
	if not has_effect(id):
		push_error("Unregistered effect '%s'." % id)
		return null

	var entry: Dictionary = _effects[id]
	var resolved := _resolve_args(args, context)
	var problems := _check_args(id, entry["params"], resolved)
	if not problems.is_empty():
		push_error("Effect '%s' called badly: %s" % [id, ", ".join(problems)])
		return null

	var builder: Callable = entry["builder"]
	var order: Order = (
		builder.call(resolved, context) if builder.is_valid()
		else Order.new(entry["order_kind"], _addressee(resolved, context), resolved, context.month)
	)
	if order != null:
		order.tone = context.tone
	return order


static func test_condition(id: String, args: Dictionary, context: LetterContext) -> bool:
	if not has_condition(id):
		push_error("Unregistered condition '%s'." % id)
		return false
	var entry: Dictionary = _conditions[id]
	return bool(entry["predicate"].call(_resolve_args(args, context), context))


## An effect addressed to nobody in particular goes to the letter's sender —
## a reply is addressed to the person who wrote.
static func _addressee(args: Dictionary, context: LetterContext) -> StringName:
	if args.has("to"):
		return StringName(args["to"])
	return context.sender.id if context.sender != null else &""


## Replace `"{name}"` placeholders with the values the director supplied.
static func _resolve_args(args: Dictionary, context: LetterContext) -> Dictionary:
	var out: Dictionary = {}
	var names: Array = args.keys()
	names.sort()
	for name in names:
		var value: Variant = args[name]
		if _is_slot_reference(value):
			var param_name: String = String(value).substr(1, String(value).length() - 2)
			out[name] = context.param(param_name)
		else:
			out[name] = value
	return out
