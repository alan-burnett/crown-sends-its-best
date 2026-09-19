class_name M1Conditions
extends RefCounted

## The condition predicates M1's triggers need.
##
## **Named static functions, not lambdas.** A lambda held in a static registry
## crashes Godot 4.7 on shutdown — the validator CLI segfaulted at exit, which
## would have handed CI a meaningless 139 instead of a real result. Named
## functions also show up in a stack trace, which lambdas do not.
##
## Every one of these only ever **reads**. A condition that changed anything
## would be logic in what is supposed to be a declarative layer.

static func always(_args: Dictionary, _context: LetterContext) -> bool:
	return true


static func world_value_above(args: Dictionary, context: LetterContext) -> bool:
	if context.state == null:
		return false
	return float(context.state.get_value(String(args["key"]), 0.0)) > float(args["value"])


static func world_value_below(args: Dictionary, context: LetterContext) -> bool:
	if context.state == null:
		return false
	return float(context.state.get_value(String(args["key"]), 0.0)) < float(args["value"])


## Contacts react to **change** as much as to standing conditions, so a trigger
## can ask about the diff and not only the state. "Revenue fell by a third" and
## "revenue is low" are different letters.
static func world_value_fell_by(args: Dictionary, context: LetterContext) -> bool:
	if context.diff == null:
		return false
	return context.diff.delta(String(args["path"])) <= -absf(float(args["amount"]))


static func world_value_rose_by(args: Dictionary, context: LetterContext) -> bool:
	if context.diff == null:
		return false
	return context.diff.delta(String(args["path"])) >= absf(float(args["amount"]))


static func loyalty_below(args: Dictionary, context: LetterContext) -> bool:
	return context.loyalty() < float(args["value"])


static func loyalty_above(args: Dictionary, context: LetterContext) -> bool:
	return context.loyalty() > float(args["value"])


## **The phase of a run is set by the calendar year**, not the colony's size
## (SPEC §9.6), so a trigger asks about the year and never about town count.
static func year_at_least(args: Dictionary, context: LetterContext) -> bool:
	if context.state == null:
		return false
	return context.state.year_index() >= JsonTypes.to_int(args["year"], "year_at_least.year")


static func months_silent_at_least(args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null:
		return false
	var months := JsonTypes.to_int(args["months"], "months_silent_at_least.months")
	return context.sender.relationship.months_silent(context.month) >= months
