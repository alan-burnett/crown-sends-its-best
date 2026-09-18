class_name OutgoingLetter
extends RefCounted

## A letter the player has written but not yet sent.
##
## **It stores the player's choices, not the Orders they will become.** Orders
## are built when the post is sent, which is what makes "changes of mind are
## allowed only within a turn" (SPEC §7) cheap: reopening a letter and picking a
## different option is editing this, and nothing downstream has happened yet.
##
## A half-finished letter is a normal state. The player may quit mid-turn and
## resume with the outgoing post intact (SPEC §16.2), so an incomplete one has to
## survive a save exactly as a finished one does.

var id: StringName = &""

## The letter file this reply or composition is built from.
var letter_id: String = ""

var addressed_to: StringName = &""

## The inbound letter this answers, or "" when the player wrote unprompted (#19).
var in_reply_to: StringName = &""

## The chosen tone, or "" where this letter has no tone step. **Not every
## outgoing letter has a tone** (SPEC §9.2).
var tone: StringName = &""

## Step id -> chosen option id.
var choices: Dictionary = {}

## The params of the letter being answered, needed to fill `{amount}` style
## references when the Orders are finally built.
var params: Dictionary = {}


func _init(p_letter_id: String = "", p_addressed_to: StringName = &"") -> void:
	letter_id = p_letter_id
	addressed_to = p_addressed_to


func choose(step_id: String, option_id: String) -> void:
	choices[step_id] = option_id


func chosen_for(step_id: String) -> String:
	return String(choices.get(step_id, ""))


func has_chosen(step_id: String) -> bool:
	return choices.has(step_id)


## Whether every step of the letter has an answer.
func is_complete(letter: Letter) -> bool:
	if letter.has_tone_step() and tone.is_empty():
		return false
	for step in letter.steps():
		if not has_chosen(String(step.get("id", ""))):
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"letter_id": letter_id,
		"addressed_to": String(addressed_to),
		"in_reply_to": String(in_reply_to),
		"tone": String(tone),
		"choices": choices.duplicate(),
		"params": params.duplicate(true),
	}


static func from_dict(data: Dictionary) -> OutgoingLetter:
	var letter := OutgoingLetter.new(
		String(data.get("letter_id", "")),
		StringName(data.get("addressed_to", "")),
	)
	letter.id = StringName(data.get("id", ""))
	letter.in_reply_to = StringName(data.get("in_reply_to", ""))
	letter.tone = StringName(data.get("tone", ""))
	letter.choices = data.get("choices", {}).duplicate()
	letter.params = data.get("params", {}).duplicate(true)
	return letter
