class_name InboundLetter
extends RefCounted

## One letter on the desk this turn, with the values it arrived with.
##
## The director (#14) decides the letter **and its values**, then supplies them
## against the letter's declared `params`. The letter file never re-decides what
## it is about, so everything needed to render it is here.

## How the player dealt with it.
const UNREAD: StringName = &"unread"
const ANSWERED: StringName = &"answered"
## **Explicitly set aside**, which is not the same as never having read it. The
## post cannot be sent while anything is still unread (#18, #23).
const SET_ASIDE: StringName = &"set_aside"

var id: StringName = &""
var letter_id: String = ""
var sender: StringName = &""

## The one tone id the director computed from loyalty, personality, circumstance
## and urgency (SPEC §9.1). Downstream code treats it as opaque and never
## re-derives circumstance from it.
var tone: StringName = &""

## Exact, truthful values, against the letter's declared params.
var params: Dictionary = {}

## Raw sim values the letter's perception entries will judge.
var measures: Dictionary = {}

var status: StringName = UNREAD

## The world month it was dispatched in.
var month: int = 0


func _init(p_letter_id: String = "", p_sender: StringName = &"", p_tone: StringName = &"") -> void:
	letter_id = p_letter_id
	sender = p_sender
	tone = p_tone


func is_handled() -> bool:
	return status != UNREAD


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"letter_id": letter_id,
		"sender": String(sender),
		"tone": String(tone),
		"params": params.duplicate(true),
		"measures": measures.duplicate(true),
		"status": String(status),
		"month": month,
	}


static func from_dict(data: Dictionary) -> InboundLetter:
	var letter := InboundLetter.new(
		String(data.get("letter_id", "")),
		StringName(data.get("sender", "")),
		StringName(data.get("tone", "")),
	)
	letter.id = StringName(data.get("id", ""))
	letter.params = data.get("params", {}).duplicate(true)
	letter.measures = data.get("measures", {}).duplicate(true)
	letter.status = StringName(data.get("status", UNREAD))
	letter.month = int(data.get("month", 0))
	return letter
