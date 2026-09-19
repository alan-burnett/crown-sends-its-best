class_name LetterContext
extends RefCounted

## What is known while a letter is being judged and rendered.
##
## The correspondence layer reads **world state, the world diff, and
## Relationship** together. People react to change as much as to standing
## conditions, so "revenue fell by a third" and "revenue is low" are different
## letters and need different inputs.
##
## The same object serves trigger conditions (#14) and the renderer (#9), so a
## condition and a slot can never disagree about what month it is.

var state: WorldState = null
var diff: WorldDiff = null

## Who is writing. Supplies `{sender:}` fields and the perception leans.
var sender: Contact = null

var month: int = 0

## Values the director supplied against the letter's declared `params` (#14).
## **Exact and truthful** — this is the quantities half of SPEC §9.1.
var params: Dictionary = {}

## Raw sim values for the letter's `perception` entries, keyed by measure id.
## The **judgments** half: biased on the way out, never false.
var measures: Dictionary = {}

## The one tone id the director computed for this letter (SPEC §9.1).
## Downstream code treats tone as opaque and never re-derives circumstance
## from it.
var tone: StringName = &""

## The Order an acknowledgement is about, where there is one. Lets a letter say
## what it was you asked for without the director having to flatten it first.
var data_order: Order = null

## The town this letter is about, when the sender speaks for one.
##
## **A governor's letter is about a place**, and the conditions that decide
## whether he writes at all need to see it. Null for the Crown's officers, who
## write about the colony and have no town of their own.
var town: Town = null


func _init(p_state: WorldState = null, p_sender: Contact = null, p_tone: StringName = &"") -> void:
	state = p_state
	sender = p_sender
	tone = p_tone
	if state != null:
		month = state.month


func param(name: String, default_value: Variant = null) -> Variant:
	return params.get(name, default_value)


func has_param(name: String) -> bool:
	return params.has(name)


func measure(id: String, default_value: float = 0.0) -> float:
	return float(measures.get(id, default_value))


func loyalty() -> float:
	return sender.loyalty() if sender != null else Relationship.NEUTRAL_LOYALTY


## A whitelisted contact field. **Not open field access** — the list is fixed so
## the validator can check it and renaming a field in code cannot silently break
## hundreds of letter files.
func sender_field(field: StringName) -> String:
	if sender == null:
		return ""
	match field:
		&"name":
			return sender.display_name
		&"title":
			return sender.title
		&"town":
			return sender.town
		&"months_silent":
			return str(sender.relationship.months_silent(month))
	push_error("'%s' is not on the sender whitelist." % field)
	return ""
