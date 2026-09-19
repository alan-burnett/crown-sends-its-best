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

var _events: Array[SimEvent] = []
var _next_seq: int = 0


## Record an event and return it, `seq` already stamped.
func emit(type: StringName, subject: StringName, month: int, payload: Dictionary = {}, phase: StringName = &"") -> SimEvent:
	var event := SimEvent.new(type, subject, month, payload, phase)
	event.seq = _next_seq
	_next_seq += 1
	_events.append(event)
	return event


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
	var out: Array[SimEvent] = []
	for event in _events:
		if event.type == type:
			out.append(event)
	return out


## Events emitted since a given `seq`. The correspondence layer uses this to ask
## "what happened since I last looked" without holding on to the whole log.
func since(seq: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event in _events:
		if event.seq >= seq:
			out.append(event)
	return out


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
		log._events.append(SimEvent.from_dict(entry))
	log._next_seq = int(data.get("next_seq", log._events.size()))
	return log
