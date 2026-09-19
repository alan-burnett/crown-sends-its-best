class_name Recollection
extends RefCounted

## One thing a contact remembers the PC doing
## (#127, `docs/mechanics/contacts.md` §6).
##
## ## Counts answer *how often*. They cannot answer *what*.
##
## A `Relationship` that only tallies deeds can tell a letter that the PC has
## been generous four times. It cannot let a contact say:
##
## > *Your Grace was good enough to send two hundred measures of iron in the
## > spring, when we had none. I would not ask again so soon were the need not
## > greater.*
##
## That needs the month, the deed, how much of it, and what it was about — and
## **never a pre-rendered string**. Prose belongs in the letter files, one per
## language; a sentence stored here would be a sentence no translation could
## reach.
##
## ## It is always true, and the bias is in the choosing
##
## Referring to a real past event is a fact about the past, which SPEC §9.1
## requires letters to get right. **The bias lives in which event a contact
## reaches for** — one man remembers the last kindness, a sourer one the last
## slight — and that is framing, which §9.1 allows.

## The month it happened.
var month: int = 0

## Which deed it was, from `Relationship.DEEDS`.
var kind: StringName = &""

## How much of it. Two hundred measures of iron is a different memory from two.
var magnitude: float = 0.0

## What it concerned — a resource id, an intent, whatever the deed was about.
## Empty when the deed had no subject, which a letter has to be able to handle.
var subject: String = ""


func _init(
	p_kind: StringName = &"",
	p_month: int = 0,
	p_magnitude: float = 0.0,
	p_subject: String = "",
) -> void:
	kind = p_kind
	month = p_month
	magnitude = p_magnitude
	subject = p_subject


## Whether this is something the PC did *for* him.
func is_a_kindness() -> bool:
	return kind == Relationship.GRANTED or kind == Relationship.DELIVERED


## Whether this is something the PC did *to* him.
func is_a_slight() -> bool:
	return kind == Relationship.REFUSED or kind == Relationship.IGNORED \
		or kind == Relationship.PROMISE_BROKEN


## How much this would weigh on a man, for deciding what survives a pruning.
##
## Size and severity together: a broken word is memorable at any size, and two
## hundred iron is memorable whatever it was.
func weight() -> float:
	var severity := absf(float(Relationship.DEED_WEIGHT.get(kind, 1.0)))
	return severity + minf(maxf(0.0, magnitude), LARGE) / LARGE


## What counts as a large deed, past which more of it is not more memorable.
##
## **A tie-breaker within a kind, not the measure itself.** Taking size as the
## measure would let one enormous favour crowd out every betrayal, and taking
## `DEED_WEIGHT` signed would make a broken promise the *first* thing forgotten
## — which is precisely backwards. A thing being bad is not a reason to forget
## it.
const LARGE: float = 250.0


func to_dict() -> Dictionary:
	return {
		"kind": String(kind),
		"month": month,
		"magnitude": magnitude,
		"subject": subject,
	}


static func from_dict(data: Dictionary) -> Recollection:
	return Recollection.new(
		StringName(data.get("kind", "")),
		int(data.get("month", 0)),
		float(data.get("magnitude", 0.0)),
		String(data.get("subject", "")),
	)
