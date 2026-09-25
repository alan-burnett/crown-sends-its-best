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

## The month it comes off the ship, or `-1` when it never went on one (#390).
##
## 🔒 **Set by `Crossing` and by nothing else.** `month` is when it was
## *written*, and the two differ only under *Distant colony* — which is the whole
## of the quirk: the letter describes the colony as it was when composed, not as
## it is when read.
var arrives_month: int = -1

## The trigger that sent it (#404), so the director can find the companion it
## brings. **Not saved**: it is read in the pass that composes the post and
## never again.
var trigger_id: String = ""


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
		"arrives_month": arrives_month,
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
	letter.arrives_month = int(data.get("arrives_month", -1))
	letter.month = int(data.get("month", 0))
	return letter
