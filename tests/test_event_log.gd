extends TestCase

## The event log keeps a stable order and round-trips (#3).


func _log() -> EventLog:
	var log := EventLog.new()
	log.emit(&"revenue_settled", &"colony", 1, {"amount": 100})
	log.emit(&"demand_issued", &"marshal", 1, {"resource": "iron", "amount": 40})
	log.emit(&"revenue_settled", &"colony", 2, {"amount": 120})
	return log


func test_seq_is_monotonic_in_emission_order() -> void:
	var log := _log()
	var events := log.all()
	for index in events.size():
		assert_eq(events[index].seq, index, "seq must follow emission order")


func test_filters_by_month_and_type() -> void:
	var log := _log()
	assert_eq(log.for_month(1).size(), 2)
	assert_eq(log.for_month(2).size(), 1)
	assert_eq(log.of_type(&"revenue_settled").size(), 2)
	assert_eq(log.of_type(&"nothing_of_the_sort").size(), 0)


func test_since_returns_only_later_events() -> void:
	# How the correspondence layer asks "what happened since I last looked"
	# without holding the whole log.
	var log := _log()
	var recent := log.since(1)
	assert_eq(recent.size(), 2)
	assert_eq(recent[0].seq, 1)


func test_round_trips_without_loss() -> void:
	var original := _log()
	var restored := EventLog.from_dict(original.to_dict())
	assert_eq(restored.to_dict(), original.to_dict())
	assert_eq(restored.next_seq(), original.next_seq())


func test_seq_continues_after_reload() -> void:
	# A reloaded log must not restart numbering, or two different events would
	# share a seq and the ordering the map plays back would be ambiguous.
	var restored := EventLog.from_dict(_log().to_dict())
	var event := restored.emit(&"after_reload", &"colony", 3, {})
	assert_eq(event.seq, 3)


func test_payload_carries_structure_not_prose() -> void:
	# SPEC §9.7: prose lives in data files, per language. An event that carried a
	# sentence would have settled that here, in code, in English.
	var log := _log()
	var payload := log.all()[1].payload
	assert_eq(payload["resource"], "iron")
	assert_eq(payload["amount"], 40)


func test_emission_order_is_the_same_for_the_same_run() -> void:
	assert_eq(_log().to_dict(), _log().to_dict())


func test_events_can_record_the_phase_that_emitted_them() -> void:
	# Every World Month phase emits (`docs/mechanics/world-month.md` §4), and
	# several of that document's rules are orderings, so an event has to say
	# which phase it came from rather than leave it to be inferred.
	var log := EventLog.new()
	log.emit(&"fort_built", &"ashmere", 1, {}, WorldPhase.MOVEMENT)
	log.emit(&"promise_broken", &"marshal", 1, {}, WorldPhase.CROWNS_MONTH)

	assert_eq(log.for_phase(WorldPhase.MOVEMENT).size(), 1)
	assert_eq(log.for_phase(WorldPhase.CROWNS_MONTH).size(), 1)
	assert_eq(log.for_phase(WorldPhase.DISPATCH).size(), 0)
	assert_eq(log.all()[0].phase, WorldPhase.MOVEMENT)


func test_phase_survives_a_round_trip() -> void:
	var log := EventLog.new()
	log.emit(&"fort_built", &"ashmere", 1, {}, WorldPhase.MOVEMENT)
	var restored := EventLog.from_dict(log.to_dict())
	assert_eq(restored.all()[0].phase, WorldPhase.MOVEMENT)


func test_phase_is_optional() -> void:
	# Nothing is running the loop in M1, so an event with no phase is normal.
	var log := EventLog.new()
	assert_eq(log.emit(&"anything", &"world", 0, {}).phase, &"")


func test_world_phases_are_the_nine_in_order() -> void:
	assert_eq(WorldPhase.ORDER.size(), 9)
	assert_eq(WorldPhase.index_of(WorldPhase.ARRIVALS), 0)
	# Territory sits between movement and the Colony Month, and the run-end check
	# precedes dispatch so the Chancellor's warning rides out with the same
	# month's post (SPEC §13.1).
	assert_true(WorldPhase.index_of(WorldPhase.TERRITORY) > WorldPhase.index_of(WorldPhase.MOVEMENT))
	assert_true(WorldPhase.index_of(WorldPhase.TERRITORY) < WorldPhase.index_of(WorldPhase.COLONY_MONTH))
	assert_true(WorldPhase.index_of(WorldPhase.RUN_END_CHECK) < WorldPhase.index_of(WorldPhase.DISPATCH))
	assert_true(WorldPhase.index_of(WorldPhase.RECKONING) < WorldPhase.index_of(WorldPhase.INTENT))
	assert_false(WorldPhase.is_phase(&"not_a_phase"))


func test_type_lookup_keeps_emission_order() -> void:
	# `of_type` answers from an index rather than a scan, and a bucket that was
	# not in emission order would put the map and the letters in a different
	# order from the one the sim ran in.
	var events := _log().of_type(&"revenue_settled")
	assert_eq(events[0].seq, 0)
	assert_eq(events[1].seq, 2)


func test_type_lookup_survives_a_reload() -> void:
	# The index is derived and never saved. A load that restored the events and
	# not the index would answer "that never happened" to every question the
	# monthly settlers ask, quietly, on a loaded run only.
	var restored := EventLog.from_dict(_log().to_dict())
	assert_eq(restored.of_type(&"revenue_settled").size(), 2)
	restored.emit(&"revenue_settled", &"colony", 3, {"amount": 140})
	assert_eq(restored.of_type(&"revenue_settled").size(), 3)


func test_since_takes_the_whole_log_and_stops_at_its_end() -> void:
	var log := _log()
	assert_eq(log.since(0).size(), 3)
	assert_eq(log.since(2).size(), 1)
	assert_eq(log.since(3).size(), 0)
	assert_eq(EventLog.new().since(0).size(), 0)
