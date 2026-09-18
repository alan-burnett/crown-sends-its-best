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
