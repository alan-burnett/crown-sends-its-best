class_name SimEvent
extends RefCounted

## One thing that happened, as structured data.
##
## Seam A (`CLAUDE.md`): the sim emits, it does not merely mutate. Map playback,
## cutscene triggers, letter content and the ledger are all consumers of this
## one record. Sim code that changes state without emitting desyncs the map from
## the letters, and SPEC §9.1 makes letters matching the simulation an invariant,
## so that is a correctness bug rather than a polish item.
##
## **The payload is never prose.** A letter about this event is rendered later,
## from data files, in whichever language the player is reading (SPEC §9.7). An
## event that carried a sentence would have decided that question here, in code,
## in English. It carries the numbers; the letter carries the words.

var type: StringName = &""
var subject: StringName = &""
var month: int = 0
var seq: int = 0
var payload: Dictionary = {}


func _init(p_type: StringName = &"", p_subject: StringName = &"", p_month: int = 0, p_payload: Dictionary = {}) -> void:
	type = p_type
	subject = p_subject
	month = p_month
	payload = p_payload


func to_dict() -> Dictionary:
	return {
		"type": String(type),
		"subject": String(subject),
		"month": month,
		"seq": seq,
		"payload": payload,
	}


static func from_dict(data: Dictionary) -> SimEvent:
	var event := SimEvent.new(
		StringName(data.get("type", "")),
		StringName(data.get("subject", "")),
		int(data.get("month", 0)),
		data.get("payload", {}),
	)
	event.seq = int(data.get("seq", 0))
	return event


func _to_string() -> String:
	return "[%d] m%d %s/%s %s" % [seq, month, type, subject, payload]
