class_name M1Registrations
extends RefCounted

## The effects and conditions M1 needs, and the measures its letters judge.
##
## Registering is the whole of it. **Every one of these is a declaration**, not a
## handler with a body: an effect says what Order it makes, and the registry
## builds it. That is what makes "no effect handler writes sim state" (Seam B)
## true by construction rather than by review.
##
## A later milestone adds entries here, or registers its own from its own system.
## Neither the letter schema nor the renderer changes when it does.

# --- Order kinds -----------------------------------------------------------

const ORDER_PROMISE_GOLD: StringName = &"promise_gold"
const ORDER_PROMISE_RESOURCE: StringName = &"promise_resource"
const ORDER_REFUSE: StringName = &"refuse"
const ORDER_GRANT_FAVOR: StringName = &"grant_favor"
const ORDER_SET_POLICY: StringName = &"set_policy"
const ORDER_REQUEST_TROOPS: StringName = &"request_troops"
const ORDER_ADJUST_LOYALTY: StringName = &"adjust_loyalty"


static func register_all() -> void:
	register_effects()
	register_conditions()
	register_measures()
	register_considerations()
	M1ParamSources.register_all()


## **A milestone that adds a system ships that system's considerations with it.**
static func register_considerations() -> void:
	ComplianceConsiderations.register_all()
	UnansweredConsiderations.register_all()


# --- Effects ---------------------------------------------------------------

static func register_effects() -> void:
	# Commits the Crown to paying. Whether it *can* pay is crown standing, which
	# is M3 (#17); for M1 the Crown always pays and the seam is left open.
	ContentRegistry.register_effect(
		"promise_gold", {"to": "contact", "amount": "gold"}, ORDER_PROMISE_GOLD
	)
	ContentRegistry.register_effect(
		"promise_resource",
		{"to": "contact", "resource": "resource", "amount": "integer"},
		ORDER_PROMISE_RESOURCE,
	)
	# A refusal is still an Order. The contact learns of it and reacts, which is
	# not the same as the PC saying nothing at all (SPEC §9.3).
	ContentRegistry.register_effect("refuse", {"to": "contact"}, ORDER_REFUSE)
	ContentRegistry.register_effect(
		"grant_favor", {"to": "contact", "favor": "string"}, ORDER_GRANT_FAVOR
	)
	ContentRegistry.register_effect(
		"set_policy", {"policy": "string", "value": "string"}, ORDER_SET_POLICY
	)
	# The payment level is chosen in the letter. It drives the loyalty cost and
	# then the refusal probability (SPEC §8.5, §12.6, #16).
	ContentRegistry.register_effect(
		"request_troops", {"to": "contact", "payment": "gold"}, ORDER_REQUEST_TROOPS
	)
	ContentRegistry.register_effect(
		"adjust_loyalty", {"to": "contact", "amount": "number"}, ORDER_ADJUST_LOYALTY
	)


# --- Conditions ------------------------------------------------------------

static func register_conditions() -> void:
	ContentRegistry.register_condition("always", {}, M1Conditions.always)

	ContentRegistry.register_condition(
		"world_value_above", {"key": "string", "value": "number"}, M1Conditions.world_value_above
	)
	ContentRegistry.register_condition(
		"world_value_below", {"key": "string", "value": "number"}, M1Conditions.world_value_below
	)

	ContentRegistry.register_condition(
		"world_value_fell_by", {"path": "string", "amount": "number"}, M1Conditions.world_value_fell_by
	)
	ContentRegistry.register_condition(
		"world_value_rose_by", {"path": "string", "amount": "number"}, M1Conditions.world_value_rose_by
	)

	ContentRegistry.register_condition(
		"loyalty_below", {"value": "number"}, M1Conditions.loyalty_below
	)
	ContentRegistry.register_condition(
		"loyalty_above", {"value": "number"}, M1Conditions.loyalty_above
	)

	ContentRegistry.register_condition(
		"year_at_least", {"year": "integer"}, M1Conditions.year_at_least
	)
	ContentRegistry.register_condition(
		"months_silent_at_least", {"months": "integer"}, M1Conditions.months_silent_at_least
	)


# --- Measures --------------------------------------------------------------

## What counts as high or low, per measure. The Author never needs to know that
## `crown_war_intensity` runs 0-100 while a food ratio runs 0-3.
static func register_measures() -> void:
	# The worked example in `docs/mechanics/perception.md` §4: stockpile over
	# consumption, 0.0 at a ratio of 0 and 1.0 at a ratio of 3.0.
	MeasureRegistry.register_linear("food_security", 0.0, 3.0)
	MeasureRegistry.register_linear("crown_war_intensity", 0.0, 100.0)
	MeasureRegistry.register_linear("colony_revenue", 0.0, 2000.0)
	MeasureRegistry.register_linear("supply_situation", 0.0, 100.0)
