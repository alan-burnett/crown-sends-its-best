class_name IntentBook
extends RefCounted

## Every Intent in the run, live and resolved.
##
## Intents **persist across months**. They can be delayed, contradicted by a
## later letter, or invalidated by something that happened meanwhile — SPEC
## §8.5's delay outcome and §11.4's expedition that may be "attacked, turned
## back, delayed, or lost completely" are both this property.
##
## Resolved Intents are kept rather than discarded, because next month's letters
## report what happened and a contact remembers what he was told to do.

## Event types. Distinct per resolution so a trigger (#14) can key on "the thing
## he promised fell through" without unpacking a payload.
const EVENT_COMMITTED: StringName = &"intent_committed"
const EVENT_ADVANCED: StringName = &"intent_advanced"

const RESOLUTION_EVENTS: Dictionary = {
	Intent.COMPLETED: &"intent_completed",
	Intent.STALLED: &"intent_stalled",
	Intent.ABANDONED: &"intent_abandoned",
	Intent.OVERTAKEN_BY_EVENTS: &"intent_overtaken",
}

var _intents: Array[Intent] = []
var _next_ordinal: int = 0


## Commit an Intent, superseding any live Intent it contends with.
##
## Supersession is what makes a later letter able to contradict an earlier one.
## The old Intent resolves as `overtaken_by_events` rather than vanishing, so the
## next month's letters can say so.
func commit(intent: Intent, log: EventLog, month: int) -> Intent:
	if intent.id.is_empty():
		intent.id = StringName("intent_%d" % _next_ordinal)
	_next_ordinal += 1
	intent.committed_month = month

	for existing in live():
		if existing.contends_with(intent) and existing.id != intent.id:
			_resolve(existing, Intent.OVERTAKEN_BY_EVENTS, log, month, {"superseded_by": String(intent.id)})

	_intents.append(intent)
	# Phase 8: everyone deliberates and commits. Nothing here changes the world.
	log.emit(EVENT_COMMITTED, intent.source, month, intent.to_dict(), WorldPhase.INTENT)
	return intent


func add_resolved(intent: Intent) -> void:
	_intents.append(intent)


func all() -> Array[Intent]:
	return _intents.duplicate()


func live() -> Array[Intent]:
	var out: Array[Intent] = []
	for intent in _intents:
		if intent.is_live():
			out.append(intent)
	return out


func resolved() -> Array[Intent]:
	var out: Array[Intent] = []
	for intent in _intents:
		if not intent.is_live():
			out.append(intent)
	return out


func by_id(id: StringName) -> Intent:
	for intent in _intents:
		if intent.id == id:
			return intent
	return null


func live_for_source(source: StringName) -> Array[Intent]:
	var out: Array[Intent] = []
	for intent in live():
		if intent.source == source:
			out.append(intent)
	return out


## Intents that resolved in a given month, for the letters that report them.
func resolved_in(month: int) -> Array[Intent]:
	var out: Array[Intent] = []
	for intent in _intents:
		if not intent.is_live() and intent.resolved_month == month:
			out.append(intent)
	return out


func resolve(intent: Intent, resolution: StringName, log: EventLog, month: int, extra: Dictionary = {}) -> void:
	_resolve(intent, resolution, log, month, extra)


func _resolve(intent: Intent, resolution: StringName, log: EventLog, month: int, extra: Dictionary) -> void:
	if not intent.is_live():
		return
	intent.resolve(resolution, month)
	var payload := intent.to_dict()
	for key in extra:
		payload[key] = extra[key]
	var event_type: StringName = RESOLUTION_EVENTS.get(resolution, &"intent_resolved")
	log.emit(event_type, intent.source, month, payload, WorldPhase.MOVEMENT)


func to_dict() -> Dictionary:
	var entries: Array = []
	for intent in _intents:
		entries.append(intent.to_dict())
	return {"next_ordinal": _next_ordinal, "intents": entries}


static func from_dict(data: Dictionary) -> IntentBook:
	var book := IntentBook.new()
	for entry in data.get("intents", []):
		book._intents.append(Intent.from_dict(entry))
	book._next_ordinal = int(data.get("next_ordinal", book._intents.size()))
	return book
