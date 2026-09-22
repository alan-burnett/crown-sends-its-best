class_name EventLog
extends RefCounted

## The ordered record of everything the sim did.
##
## Ordering is emission order, stamped with a monotonic `seq`. Given a seed the
## sim runs the same way, so the log comes out in the same order, and consumers
## that replay it — map playback especially — see events in the order they
## happened rather than an order that depends on dictionary iteration.
##
## The deliberation kernel writes here too: `choose()` always emits its scoring
## trace (`docs/mechanics/deliberation.md` §6), which is what later lets a
## governor's letter give the same reason the trace gives.
##
## **A question to the log costs the answer, not the whole record.** Several
## settlers ask the same one every month — what the Crown took in, what the court
## has heard about, whether a patron has spoken ill — and a scan charges each of
## them the length of the run. Eight years of one seed asks `of_type` some three
## thousand times and reads sixteen million events doing it. So the log keeps an
## index by type, written as the events arrive, and answers `of_type` from it;
## `since` halves the log rather than reading it.
##
## The index is derived, never saved: `from_dict` rebuilds it from the events
## themselves, which is why loading goes through the same `_record` as emitting.

var _events: Array[SimEvent] = []

## Type -> that type's events, in emission order. Appending as they arrive is
## what keeps each bucket in the order a scan would have produced.
var _by_type: Dictionary = {}

var _next_seq: int = 0


## Record an event and return it, `seq` already stamped.
func emit(type: StringName, subject: StringName, month: int, payload: Dictionary = {}, phase: StringName = &"") -> SimEvent:
	var event := SimEvent.new(type, subject, month, payload, phase)
	event.seq = _next_seq
	_next_seq += 1
	_record(event)
	return event


## Into the record and into the index that reads it back, never one without the
## other.
func _record(event: SimEvent) -> void:
	_events.append(event)
	if not _by_type.has(event.type):
		var first: Array[SimEvent] = []
		_by_type[event.type] = first
	var of_that_type: Array[SimEvent] = _by_type[event.type]
	of_that_type.append(event)


func all() -> Array[SimEvent]:
	return _events.duplicate()


func size() -> int:
	return _events.size()


func for_month(month: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event in _events:
		if event.month == month:
			out.append(event)
	return out


func for_phase(phase: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event in _events:
		if event.phase == phase:
			out.append(event)
	return out


func of_type(type: StringName) -> Array[SimEvent]:
	if not _by_type.has(type):
		return []
	var of_that_type: Array[SimEvent] = _by_type[type]
	return of_that_type.duplicate()


## Events emitted since a given `seq`. The correspondence layer uses this to ask
## "what happened since I last looked" without holding on to the whole log.
##
## `seq` is stamped in emission order, so the log is sorted by it and the first
## event to return can be found by halving.
func since(seq: int) -> Array[SimEvent]:
	return _events.slice(_first_at_or_after(seq))


## Where an event with this `seq` would sit — the earliest at or after it, or the
## end of the log where nothing is.
func _first_at_or_after(seq: int) -> int:
	var low := 0
	var high := _events.size()
	while low < high:
		var middle := (low + high) / 2
		if _events[middle].seq < seq:
			low = middle + 1
		else:
			high = middle
	return low


func next_seq() -> int:
	return _next_seq


func to_dict() -> Dictionary:
	var events: Array = []
	for event in _events:
		events.append(event.to_dict())
	return {"next_seq": _next_seq, "events": events}


static func from_dict(data: Dictionary) -> EventLog:
	var log := EventLog.new()
	for entry in data.get("events", []):
		log._record(SimEvent.from_dict(entry))
	log._next_seq = int(data.get("next_seq", log._events.size()))
	return log
