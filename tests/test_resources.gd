extends TestCase

## The resource model (#36) and the tax rates built on it (#38).

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


# --- The resources ---------------------------------------------------------

func test_every_resource_in_the_spec_is_present() -> void:
	# SPEC §10.1's sixteen, plus the three livestock that trade like them.
	for id in ["food", "wood", "stone", "ore", "furs", "cotton", "sugar", "tobacco", "tea",
			"clothing", "iron", "rum", "cigars", "beer", "guns", "tools"]:
		assert_true(ResourceCatalogue.has(StringName(id)), "no resource '%s'" % id)
	for id in ["cows", "sheep", "horses"]:
		assert_true(ResourceCatalogue.has(StringName(id)), "no livestock '%s'" % id)


func test_luxury_is_a_flag_and_not_a_list_in_code() -> void:
	# SPEC §10.2 taxes luxuries differently and they provoke far less rebel
	# sentiment. Both have to read the flag, or adding one later means hunting
	# through branches.
	var luxuries := ResourceCatalogue.luxuries()
	for id in ["sugar", "tobacco", "tea", "rum", "cigars", "beer"]:
		assert_true(luxuries.has(id), "'%s' should be a luxury" % id)
	for id in ["food", "wood", "iron", "guns"]:
		assert_false(luxuries.has(id), "'%s' should not be a luxury" % id)


func test_tea_can_never_be_produced() -> void:
	# It must be bought from the Crown, which is what makes it a natural first
	# trade protest in M3 — by its mechanics, not by a hardcoded priority.
	assert_false(ResourceCatalogue.is_producible(&"tea"))
	assert_eq(ResourceCatalogue.unproducible(), PackedStringArray(["tea"]))


func test_nothing_in_the_colony_can_generate_tea() -> void:
	# Not merely flagged: there is no conversion anywhere that ends in tea.
	assert_empty(ResourceCatalogue.inputs_for(&"tea"))
	for id in ResourceCatalogue.ids():
		assert_false(ResourceCatalogue.inputs_for(StringName(id)).has("tea"),
			"'%s' claims to be made from tea" % id)


func test_conversions_resolve_from_data() -> void:
	assert_eq(ResourceCatalogue.inputs_for(&"iron"), PackedStringArray(["ore"]))
	assert_eq(ResourceCatalogue.inputs_for(&"rum"), PackedStringArray(["sugar"]))
	assert_eq(ResourceCatalogue.inputs_for(&"cigars"), PackedStringArray(["tobacco"]))
	assert_eq(ResourceCatalogue.inputs_for(&"beer"), PackedStringArray(["food"]))


func test_a_two_input_conversion_accepts_either() -> void:
	# Clothing comes from furs **or** cotton, not both.
	assert_eq(ResourceCatalogue.inputs_for(&"clothing"), PackedStringArray(["cotton", "furs"]))
	assert_true(ResourceCatalogue.get_kind(&"clothing").converts_from_resource(&"furs"))
	assert_true(ResourceCatalogue.get_kind(&"clothing").converts_from_resource(&"cotton"))
	assert_false(ResourceCatalogue.get_kind(&"clothing").converts_from_resource(&"wood"))


func test_iron_becomes_both_tools_and_guns() -> void:
	assert_eq(ResourceCatalogue.conversions_from(&"iron"), PackedStringArray(["guns", "tools"]))


func test_every_processed_resource_can_actually_be_made() -> void:
	# A chain ending in something the colony cannot produce is a hole in the
	# economy, and a quiet one.
	for id in ResourceCatalogue.processed():
		assert_true(ResourceCatalogue.has_complete_chain(StringName(id)),
			"'%s' cannot be made from anything the colony can produce" % id)


func test_livestock_trade_like_resources_but_are_not_stockpile() -> void:
	assert_eq(ResourceCatalogue.livestock(), PackedStringArray(["cows", "horses", "sheep"]))
	assert_false(ResourceCatalogue.staples().has("cows"), "livestock are population, not stockpile")


func test_adding_a_resource_needs_only_data() -> void:
	ResourceCatalogue.load_from([
		{"id": "food", "producible": true},
		{"id": "amber", "luxury": true, "producible": true},
		{"id": "varnish", "converts_from": ["amber"]},
	])
	assert_true(ResourceCatalogue.has(&"amber"))
	assert_true(ResourceCatalogue.luxuries().has("amber"))
	assert_eq(ResourceCatalogue.conversions_from(&"amber"), PackedStringArray(["varnish"]))
	assert_true(ResourceCatalogue.has_complete_chain(&"varnish"))


func test_ids_are_sorted() -> void:
	var ids := ResourceCatalogue.ids()
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids)


# --- Tax rates -------------------------------------------------------------

func _state() -> WorldState:
	var state := WorldState.new(0, {})
	for key in TaxRates.initial_values():
		state.values[key] = TaxRates.initial_values()[key]
	return state


func test_the_base_rate_applies_to_everything() -> void:
	var state := _state()
	for id in ResourceCatalogue.ids():
		assert_almost_eq(TaxRates.rate_for(state, StringName(id)), TaxRates.base_rate(state))


func test_a_per_resource_override_wins() -> void:
	var state := _state()
	state.values[TaxRates.key_for(&"tea")] = 0.4
	assert_almost_eq(TaxRates.rate_for(state, &"tea"), 0.4)
	assert_almost_eq(TaxRates.rate_for(state, &"food"), TaxRates.base_rate(state))
	assert_true(TaxRates.has_override(state, &"tea"))
	assert_false(TaxRates.has_override(state, &"food"))


func test_overrides_are_colony_wide_and_listed() -> void:
	var state := _state()
	state.values[TaxRates.key_for(&"tea")] = 0.4
	state.values[TaxRates.key_for(&"sugar")] = 0.2
	assert_eq(TaxRates.overridden(state), PackedStringArray(["sugar", "tea"]))


func test_there_is_no_way_to_set_a_rate_for_one_town() -> void:
	# **🔒 No per-town rates. Ever.** Not a rule this remembers — a rate is keyed
	# by resource and nothing else, so there is nowhere to put a town.
	var state := _state()
	state.values[TaxRates.key_for(&"tea")] = 0.4
	for key in TaxRates.overridden(state):
		assert_eq(TaxRates.rate_for(state, StringName(key)), 0.4 if key == "tea" else TaxRates.base_rate(state))
	# The key for a resource is the whole of the address.
	assert_eq(TaxRates.key_for(&"tea"), "tax.tea")


func test_rates_are_clamped_to_a_share_of_the_trade() -> void:
	var state := _state()
	state.values[TaxRates.key_for(&"tea")] = 9.0
	assert_almost_eq(TaxRates.rate_for(state, &"tea"), TaxRates.MAX_RATE)
	state.values[TaxRates.key_for(&"tea")] = -3.0
	assert_almost_eq(TaxRates.rate_for(state, &"tea"), TaxRates.MIN_RATE)


func test_a_move_can_be_previewed_before_it_is_ordered() -> void:
	# Every choice's mechanical effect is understandable from its wording, which
	# means a letter can say where a rate will land.
	var state := _state()
	assert_almost_eq(TaxRates.moved(state, &"tea", 1.0), TaxRates.base_rate(state) + TaxRates.STEP)
	assert_almost_eq(TaxRates.moved(state, &"tea", -1.0), TaxRates.base_rate(state) - TaxRates.STEP)
	assert_almost_eq(TaxRates.moved(state, &"tea", 99.0), TaxRates.MAX_RATE)


func test_the_burden_reflects_an_override_not_only_the_base() -> void:
	var state := _state()
	var before := TaxRates.burden(state)
	state.values[TaxRates.key_for(&"tea")] = TaxRates.MAX_RATE
	assert_true(TaxRates.burden(state) > before)


func test_rates_serialise_with_the_world() -> void:
	var state := _state()
	state.values[TaxRates.key_for(&"tea")] = 0.35
	var restored := WorldState.from_dict(state.to_dict())
	assert_almost_eq(TaxRates.rate_for(restored, &"tea"), 0.35)
	assert_eq(restored.state_hash(), state.state_hash())


# --- A tax change is an Order like any other --------------------------------

func _run_with_a_willing_steward() -> Dictionary:
	var run := RunState.new_run(1707)
	ContactRoster.load_into(run, content)
	# A Steward who will do as he is told, so this test is about the plumbing
	# rather than about whether he felt like it.
	run.contact(&"steward").relationship = Relationship.new(&"steward", 95.0)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	return {"run": run, "machine": machine}


func _advance(machine: TurnMachine, run: RunState, turns: int) -> void:
	for turn in turns:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()


func test_the_player_never_sets_a_rate_directly() -> void:
	# It is always a letter, resolved through compliance. The proof is that the
	# effect produces an Order and nothing else.
	var harness := _run_with_a_willing_steward()
	var run: RunState = harness["run"]
	var before := run.world.state_hash()

	var context := LetterContext.new(run.world, run.contact(&"steward"), Tone.DUTIFUL)
	var order := ContentRegistry.run_effect(
		"set_tax_rate", {"to": "steward", "resource": "tea", "steps": 2}, context
	)
	assert_true(order != null)
	assert_eq(order.kind, M1Registrations.ORDER_SET_TAX_RATE)
	assert_eq(run.world.state_hash(), before, "asking for a rate change must not change it")


func test_a_tax_order_reaches_the_world_through_compliance() -> void:
	var harness := _run_with_a_willing_steward()
	var run: RunState = harness["run"]
	var machine: TurnMachine = harness["machine"]

	var context := LetterContext.new(run.world, run.contact(&"steward"), Tone.DUTIFUL)
	machine.orders.carry(ContentRegistry.run_effect(
		"set_tax_rate", {"to": "steward", "resource": "tea", "steps": 2}, context
	))
	_advance(machine, run, 3)

	assert_true(TaxRates.has_override(run.world, &"tea"), "the rate on tea never changed")
	assert_true(TaxRates.rate_for(run.world, &"tea") > TaxRates.base_rate(run.world))
	assert_empty(run.log.of_type(&"intent_stalled"))


func test_the_first_override_on_a_resource_can_be_created() -> void:
	# A resource with no override yet has no rate of its own, so an executor that
	# insisted the value already existed could never levy the first one.
	var harness := _run_with_a_willing_steward()
	var run: RunState = harness["run"]
	var machine: TurnMachine = harness["machine"]
	assert_false(TaxRates.has_override(run.world, &"sugar"))

	var context := LetterContext.new(run.world, run.contact(&"steward"), Tone.DUTIFUL)
	machine.orders.carry(ContentRegistry.run_effect(
		"set_tax_rate", {"to": "steward", "resource": "sugar", "steps": 1}, context
	))
	_advance(machine, run, 3)
	assert_true(TaxRates.has_override(run.world, &"sugar"))


func test_a_rate_change_can_be_delayed_by_the_steward() -> void:
	# SPEC §10.2: at low loyalty, doing something he advised against, he may
	# delay — the outcome already exists in the compliance system.
	assert_true(Compliance.OUTCOMES.has(Compliance.DELAY))
	assert_true(int(Compliance.MONTHS_FOR[Compliance.DELAY]) > int(Compliance.MONTHS_FOR[Compliance.COMPLY]))


func test_the_unilateral_path_is_behind_the_crown_standing_seam() -> void:
	# He may raise taxes on his own only once standing is lost, which is M3. The
	# seam is the flag the officers already use, and in M2 it is never false.
	var harness := _run_with_a_willing_steward()
	var machine: TurnMachine = harness["machine"]
	assert_true(machine.orders.can_crown_pay, "M2 treats the Crown as always paying")
	assert_true(machine.promise_driver.can_crown_pay)


func test_the_steward_writes_about_the_burden_through_a_measure() -> void:
	# His bias is a perception lean on a registered measure, not special-cased
	# prose.
	assert_true(MeasureRegistry.has_measure("tax_burden"))
	var steward: Dictionary = content.collection("contacts")["steward"]
	assert_true(steward.has("leans"), "the Steward carries perception leans")
