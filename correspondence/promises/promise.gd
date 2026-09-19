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

## A revenue target the PC accepted from the Steward (#69).
##
## **The only promise whose keeping is not in the PC's hands.** Gold and
## resources are paid out of a purse or a stockpile and either can be found or
## cannot; a revenue target is kept by whether the colony's trade reached the
## figure over the term. That is why it is a bet rather than a payment, and why
## it settles against the Crown's own books rather than against anybody's will.
const KIND_REVENUE: StringName = &"revenue"

## Goods the PC undertook that the Marshal's wars need (#69).
##
## Like a revenue target and for the same reason: the PC does not control it.
## SPEC §11.3 locks that towns run themselves, so whether this is kept depends on
## whether a governor agreed to ship and whether his town could. **One acceptance
## can make two enemies** — the Marshal's regard falls because he was failed, the
## governor's because he was asked something costly.
const KIND_SHIPMENT: StringName = &"shipment"

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


## Whether this promise is kept by an outcome rather than by a payment.
##
## The driver has to judge it against what actually happened, so `settle_due`
## cannot simply mark it kept when the month comes round.
func is_a_wager() -> bool:
	return kind == KIND_REVENUE or kind == KIND_SHIPMENT


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
