extends TestCase

## `WorldState` round-trips without loss, hashes stably, and cannot be changed
## without emitting (Seam A).


func _state() -> WorldState:
	return WorldState.new(3, {
		"crown_war_intensity": 0.42,
		"colony_revenue": 1200,
		"supply_situation": "strained",
	})


func test_round_trips_without_loss() -> void:
	var original := _state()
	var restored := WorldState.from_dict(original.to_dict())
	assert_eq(restored.to_dict(), original.to_dict())
	assert_eq(restored.state_hash(), original.state_hash())


func test_round_trip_preserves_number_types() -> void:
	# `colony_revenue` is an int and `crown_war_intensity` is a float. If a round
	# trip turned 1200 into 1200.0 the state would hash differently while being
	# the same state, and a letter would render "1200.0" at the player.
	var restored := WorldState.from_dict(_state().to_dict())
	assert_eq(typeof(restored.get_value("colony_revenue")), TYPE_INT)
	assert_eq(typeof(restored.get_value("crown_war_intensity")), TYPE_FLOAT)


func test_hash_distinguishes_states() -> void:
	var first := _state()
	var second := _state()
	assert_eq(first.state_hash(), second.state_hash(), "identical states must hash identically")

	second.values["colony_revenue"] = 1201
	assert_ne(first.state_hash(), second.state_hash())


func test_hash_ignores_key_insertion_order() -> void:
	var forwards := WorldState.new(1, {"a": 1, "b": 2})
	var backwards := WorldState.new(1, {"b": 2, "a": 1})
	assert_eq(forwards.state_hash(), backwards.state_hash())


func test_apply_changes_state_and_emits_event() -> void:
	# The acceptance criterion from #3: a state change and its emitted event.
	var state := _state()
	var log := EventLog.new()

	var event := state.apply(log, &"revenue_settled", &"colony", {"colony_revenue": 900})

	assert_eq(state.get_value("colony_revenue"), 900, "state did not change")
	assert_eq(log.size(), 1, "the change emitted nothing")
	assert_eq(event.type, &"revenue_settled")
	assert_eq(event.subject, &"colony")
	assert_eq(event.month, 3, "the event is stamped with the month it happened in")

	var changes: Dictionary = event.payload["changes"]
	assert_eq(changes["colony_revenue"]["from"], 1200)
	assert_eq(changes["colony_revenue"]["to"], 900)


func test_apply_records_new_keys_as_from_null() -> void:
	var state := _state()
	var log := EventLog.new()
	var event := state.apply(log, &"policy_set", &"colony", {"tea_rate": 0.3})
	assert_eq(event.payload["changes"]["tea_rate"]["from"], null)
	assert_eq(event.payload["changes"]["tea_rate"]["to"], 0.3)


func test_advance_month_emits() -> void:
	var state := WorldState.new(11, {})
	var log := EventLog.new()
	var event := state.advance_month(log)
	assert_eq(state.month, 12)
	assert_eq(event.type, &"month_advanced")
	assert_eq(event.payload["year"], 2)
	assert_eq(event.payload["month_of_year"], 1)


func test_calendar_derives_from_month() -> void:
	# SPEC §9.6 sets the phase of a run by the calendar year, so the year has to
	# come from state alone rather than from anything the colony did.
	assert_eq(WorldState.new(0, {}).year_index(), 1)
	assert_eq(WorldState.new(0, {}).month_of_year(), 1)
	assert_eq(WorldState.new(11, {}).year_index(), 1)
	assert_eq(WorldState.new(11, {}).month_of_year(), 12)
	assert_eq(WorldState.new(12, {}).year_index(), 2)
	assert_eq(WorldState.new(12, {}).month_of_year(), 1)


func test_value_keys_are_sorted() -> void:
	var state := WorldState.new(0, {"zeta": 1, "alpha": 2, "mu": 3})
	assert_eq(state.value_keys(), PackedStringArray(["alpha", "mu", "zeta"]))


func test_duplicate_state_is_independent() -> void:
	var original := _state()
	var copy := original.duplicate_state()
	copy.values["colony_revenue"] = 0
	assert_eq(original.get_value("colony_revenue"), 1200, "the copy shared the original's dictionary")
