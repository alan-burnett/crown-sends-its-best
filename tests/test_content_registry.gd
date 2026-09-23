extends TestCase

## The conditions and effects registry (#11).

var context: LetterContext = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()

	var sender := Contact.from_data({"id": "marshal", "name": "Vane", "loyalty": 40.0})
	context = LetterContext.new(WorldState.new(5, {"crown_war_intensity": 60.0}), sender, &"dutiful")
	context.params = {"amount": 200, "resource": "iron"}


func after_each() -> void:
	reset_world()


# --- Effects produce Orders, never writes ----------------------------------

func test_an_effect_produces_an_order() -> void:
	# Seam B. A player letter never touches sim state; it creates an Order
	# addressed to a contact, which that contact then resolves.
	var order := ContentRegistry.run_effect(
		"promise_resource", {"to": "marshal", "resource": "iron", "amount": 200}, context
	)
	assert_true(order != null)
	assert_eq(order.kind, M1Registrations.ORDER_PROMISE_RESOURCE)
	assert_eq(order.addressed_to, &"marshal")
	assert_eq(order.get_param("amount"), 200)


func test_every_m1_effect_is_registered() -> void:
	for id in ["promise_gold", "promise_resource", "refuse", "grant_favor",
			"set_policy", "request_troops", "adjust_loyalty"]:
		assert_true(ContentRegistry.has_effect(id), "missing effect '%s'" % id)


func test_every_m1_effect_produces_an_order() -> void:
	# Not one of them has anywhere to put a write.
	var calls: Dictionary = {
		"promise_gold": {"to": "marshal", "amount": 100},
		"promise_resource": {"to": "marshal", "resource": "iron", "amount": 10},
		"refuse": {"to": "marshal"},
		"grant_favor": {"to": "marshal", "favor": "a commission for his nephew"},
		"set_policy": {"policy": "tax.tea", "value": "lower"},
		"request_troops": {"to": "marshal", "payment": 500},
		"adjust_loyalty": {"to": "marshal", "amount": 5},
	}
	for id in calls:
		var order := ContentRegistry.run_effect(id, calls[id], context)
		assert_true(order != null, "'%s' produced nothing" % id)


func test_an_order_carries_the_letters_tone() -> void:
	var order := ContentRegistry.run_effect("refuse", {"to": "marshal"}, context)
	assert_eq(order.tone, &"dutiful")


func test_an_effect_addressed_to_nobody_goes_to_the_sender() -> void:
	# A reply is addressed to the person who wrote.
	var order := ContentRegistry.run_effect("set_policy", {"policy": "tax.tea", "value": "lower"}, context)
	assert_eq(order.addressed_to, &"marshal")


func test_slot_references_are_filled_from_the_letters_params() -> void:
	var order := ContentRegistry.run_effect(
		"promise_resource", {"to": "marshal", "resource": "{resource}", "amount": "{amount}"}, context
	)
	assert_eq(order.get_param("resource"), "iron")
	assert_eq(order.get_param("amount"), 200)


# --- Checking call sites ---------------------------------------------------

func test_a_missing_param_fails_validation_not_runtime() -> void:
	var problems := ContentRegistry.check_effect_call("promise_resource", {"to": "marshal"})
	assert_not_empty(problems)
	assert_true(String(problems[0]).contains("missing"), problems[0])


func test_a_wrongly_typed_param_fails_validation() -> void:
	var problems := ContentRegistry.check_effect_call(
		"promise_resource", {"to": "marshal", "resource": "iron", "amount": "quite a lot"}
	)
	assert_not_empty(problems)


func test_an_unknown_param_fails_validation() -> void:
	assert_not_empty(ContentRegistry.check_effect_call(
		"refuse", {"to": "marshal", "vigour": "great"}
	))


func test_an_unregistered_effect_is_caught() -> void:
	# The validator can enumerate the registry, so an unregistered id in content
	# is caught at build time.
	assert_not_empty(ContentRegistry.check_effect_call("summon_a_dragon", {}))
	assert_false(ContentRegistry.has_effect("summon_a_dragon"))


func test_a_slot_reference_is_not_type_checked_at_build_time() -> void:
	# There is no value yet to check — the director supplies it at send time.
	assert_empty(ContentRegistry.check_effect_call(
		"promise_resource", {"to": "marshal", "resource": "{resource}", "amount": "{amount}"}
	))


func test_a_well_formed_call_has_no_problems() -> void:
	assert_empty(ContentRegistry.check_effect_call(
		"promise_gold", {"to": "marshal", "amount": 500}
	))


func test_registering_an_effect_needs_no_schema_or_renderer_change() -> void:
	ContentRegistry.register_effect("commission_a_portrait", {"to": "contact"}, &"commission_portrait")
	assert_true(ContentRegistry.has_effect("commission_a_portrait"))
	var order := ContentRegistry.run_effect("commission_a_portrait", {"to": "marshal"}, context)
	assert_eq(order.kind, &"commission_portrait")


func test_an_effect_declaring_an_unknown_type_is_refused() -> void:
	ContentRegistry.register_effect("nonsense", {"thing": "sonnet"}, &"nonsense")
	assert_false(ContentRegistry.has_effect("nonsense"))


# --- Conditions ------------------------------------------------------------

func test_conditions_read_world_state() -> void:
	assert_true(ContentRegistry.test_condition(
		"world_value_above", {"key": "crown_war_intensity", "value": 30}, context
	))
	assert_false(ContentRegistry.test_condition(
		"world_value_above", {"key": "crown_war_intensity", "value": 90}, context
	))


func test_conditions_read_the_diff() -> void:
	# People react to change as much as to standing conditions.
	context.diff = WorldDiff.between(
		WorldState.new(4, {"colony_revenue": 300}),
		WorldState.new(5, {"colony_revenue": 200}),
	)
	assert_true(ContentRegistry.test_condition(
		"world_value_fell_by", {"path": "values.colony_revenue", "amount": 50}, context
	))
	assert_false(ContentRegistry.test_condition(
		"world_value_rose_by", {"path": "values.colony_revenue", "amount": 50}, context
	))


func test_conditions_read_loyalty() -> void:
	assert_true(ContentRegistry.test_condition("loyalty_below", {"value": 50}, context))
	assert_false(ContentRegistry.test_condition("loyalty_above", {"value": 50}, context))


func test_the_run_phase_is_the_calendar_year() -> void:
	# SPEC §9.6 sets the phase of a run by the calendar year, not colony size.
	assert_true(ContentRegistry.test_condition("year_at_least", {"year": 1}, context))
	assert_false(ContentRegistry.test_condition("year_at_least", {"year": 2}, context))


func test_months_silent_is_a_condition() -> void:
	context.sender.relationship.note_letter_sent(1)
	assert_true(ContentRegistry.test_condition("months_silent_at_least", {"months": 4}, context))
	assert_false(ContentRegistry.test_condition("months_silent_at_least", {"months": 5}, context))


func test_an_unregistered_condition_is_caught() -> void:
	assert_not_empty(ContentRegistry.check_condition_call("the_stars_are_right", {}))


func test_reset_clears_the_registry() -> void:
	ContentRegistry.reset()
	assert_empty(ContentRegistry.effect_ids())
	assert_empty(ContentRegistry.condition_ids())
