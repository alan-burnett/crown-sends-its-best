class_name Order
extends RefCounted

## What a player's letter actually produces.
##
## **Seam B: Orders are never writes.** A player letter never touches sim state
## (SPEC §8.5, §7). It creates an Order **addressed to a contact**. The contact
## resolves it — comply, partly comply, delay, reinterpret, refuse, or act
## unilaterally — into intents the sim consumes on the *next* step.
##
## **🔒 Your orders are requests.** Nothing here commands anything; this is a
## letter's worth of intent, waiting on somebody else's judgement.
##
## Compliance resolution is #16. This is the object it resolves.

var id: StringName = &""

## What is being asked for. An effect id in the registry maps to one of these.
var kind: StringName = &""

## The contact the letter was addressed to. He decides what happens next.
var addressed_to: StringName = &""

## Typed arguments, already checked against the effect's declared params.
var params: Dictionary = {}

## The world month the post carrying this was sent.
var issued_month: int = 0

## The tone of the letter that carried it. Flavours how the recipient reacts,
## with **only a minor effect** compared with what the letter actually grants or
## promises (SPEC §9.2).
var tone: StringName = &""


func _init(
	p_kind: StringName = &"",
	p_addressed_to: StringName = &"",
	p_params: Dictionary = {},
	p_issued_month: int = 0,
) -> void:
	kind = p_kind
	addressed_to = p_addressed_to
	params = p_params.duplicate(true)
	issued_month = p_issued_month


func get_param(key: String, default_value: Variant = null) -> Variant:
	return params.get(key, default_value)


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"kind": String(kind),
		"addressed_to": String(addressed_to),
		"params": params.duplicate(true),
		"issued_month": issued_month,
		"tone": String(tone),
	}


static func from_dict(data: Dictionary) -> Order:
	var order := Order.new(
		StringName(data.get("kind", "")),
		StringName(data.get("addressed_to", "")),
		data.get("params", {}),
		int(data.get("issued_month", 0)),
	)
	order.id = StringName(data.get("id", ""))
	order.tone = StringName(data.get("tone", ""))
	return order


func _to_string() -> String:
	return "Order(%s -> %s %s)" % [kind, addressed_to, params]
