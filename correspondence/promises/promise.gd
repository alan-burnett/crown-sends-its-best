class_name Promise
extends RefCounted

## Something the PC committed to in a letter: paying gold, sending resources,
## granting a favour.
##
## **🔒 Promises are tracked** and carried out automatically while the PC is able
## to keep them. A broken promise, whether from lack of means or a Crown refusal,
## costs loyalty (SPEC §9.5, §10.3).

const OUTSTANDING: StringName = &"outstanding"
const KEPT: StringName = &"kept"
const BROKEN: StringName = &"broken"

## Whose purse it comes out of.
##
## The Crown honours **gold** promises, and stops when standing is lost
## (SPEC §10.3). Promises the **colony** fulfils from its own stockpiles are not
## the Crown's to refuse and continue regardless — which is why this is recorded
## rather than inferred from the amount.
const PAYER_CROWN: StringName = &"crown"
const PAYER_COLONY: StringName = &"colony"

var id: StringName = &""
var to: StringName = &""
var kind: StringName = &""
var payer: StringName = PAYER_CROWN

## What was promised: `amount`, and `resource` where it is not gold.
var terms: Dictionary = {}

## The month the promise was made, and the month it falls due.
var made_month: int = 0
var due_month: int = 0

var status: StringName = OUTSTANDING
var settled_month: int = -1

## Why it broke, for the letter that has to explain it.
var broken_reason: String = ""


func _init(
	p_to: StringName = &"",
	p_kind: StringName = &"",
	p_terms: Dictionary = {},
	p_made_month: int = 0,
	p_due_month: int = 0,
) -> void:
	to = p_to
	kind = p_kind
	terms = p_terms.duplicate(true)
	made_month = p_made_month
	due_month = p_due_month


func is_outstanding() -> bool:
	return status == OUTSTANDING


func is_due(month: int) -> bool:
	return is_outstanding() and month >= due_month


func amount() -> float:
	return float(terms.get("amount", 0.0))


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"to": String(to),
		"kind": String(kind),
		"payer": String(payer),
		"terms": terms.duplicate(true),
		"made_month": made_month,
		"due_month": due_month,
		"status": String(status),
		"settled_month": settled_month,
		"broken_reason": broken_reason,
	}


static func from_dict(data: Dictionary) -> Promise:
	var promise := Promise.new(
		StringName(data.get("to", "")),
		StringName(data.get("kind", "")),
		data.get("terms", {}),
		int(data.get("made_month", 0)),
		int(data.get("due_month", 0)),
	)
	promise.id = StringName(data.get("id", ""))
	promise.payer = StringName(data.get("payer", PAYER_CROWN))
	promise.status = StringName(data.get("status", OUTSTANDING))
	promise.settled_month = int(data.get("settled_month", -1))
	promise.broken_reason = String(data.get("broken_reason", ""))
	return promise
