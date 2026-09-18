class_name M1ParamSources
extends RefCounted

## Where the director gets the values a letter declares.
##
## **The director decides the letter and its values**, then supplies them against
## the letter's declared `params` (#8, #14). The letter file never re-decides what
## it is about, and a trigger file names a source rather than computing anything,
## so there is still no logic in a data file.
##
## Named static functions rather than lambdas — a lambda held in a static
## registry crashes Godot 4.7 on shutdown.

static func register_all() -> void:
	ContentRegistry.register_param_source(
		"literal", {"value": "string"}, M1ParamSources.literal
	)
	ContentRegistry.register_param_source(
		"number", {"value": "number"}, M1ParamSources.number
	)
	ContentRegistry.register_param_source(
		"world_value", {"key": "string"}, M1ParamSources.world_value
	)
	ContentRegistry.register_param_source(
		"scaled_world_value",
		{"key": "string", "factor": "number", "minimum": "number", "maximum": "number"},
		M1ParamSources.scaled_world_value,
	)


static func literal(args: Dictionary, _context: LetterContext) -> Variant:
	return args["value"]


static func number(args: Dictionary, _context: LetterContext) -> Variant:
	return args["value"]


static func world_value(args: Dictionary, context: LetterContext) -> Variant:
	if context.state == null:
		return 0
	return context.state.get_value(String(args["key"]), 0.0)


## A whole number scaled off a world value, which is how a demand grows with the
## Crown's circumstances rather than being authored per month.
##
## Returns an int, because a letter that declares `integer` must not render
## "200.0" at the player.
static func scaled_world_value(args: Dictionary, context: LetterContext) -> Variant:
	if context.state == null:
		return int(args["minimum"])
	var raw := float(context.state.get_value(String(args["key"]), 0.0))
	var scaled := raw * float(args["factor"])
	return int(roundf(clampf(scaled, float(args["minimum"]), float(args["maximum"]))))
