class_name PatronCredit
extends RefCounted

## What a patron is worth to the PC's name (#282, `docs/mechanics/prestige.md`
## §5; `patrons.md` §6, §9).
##
## ## 🔒 Deeds bank immediately, and stay banked
##
## §5's first rule: a favour granted to a patron adds to prestige **the month it
## is granted**, and it survives his departure, because he remembers it and says
## so at court. A refusal is the same line with the sign turned over.
##
## So the term is a sum over the event log rather than a figure anybody keeps.
## Nothing can fall out of step with it, and `Prestige.of` stays a pure reading
## of what happened.
##
## **The other two halves of §5 are not here.** His regard while he is present is
## a live term and his final loyalty banks when he goes — both belong with the
## departure window (§8), which is #283.
##
## ## 🔒 The loudmouth's knob, and why it is a scale
##
## *He talks. Granting banks more prestige; refusing costs it outright.* One
## multiplier on the amount, applied to both directions, because a man with a
## voice at court is louder about a slight and louder about a kindness — a knob
## that only cut one way would be a different vice.
##
## Everyone else scales by one, which is what keeps this a per-contact override
## on machinery everybody shares rather than a patron-shaped branch in prestige.

## The event prestige reads. **Declared by `Prestige`**, because `sim/` depends
## on nothing above it: the term is the sim's and the judgement of what is worth
## banking is this layer's.
const EVENT_BANKED: StringName = Prestige.EVENT_PATRON_CREDIT

## What a favour to a patron is worth in the Crown's unit, and what a refusal
## costs. **Tuning**, and `patrons.md` §11 leaves the figure to a harness sweep:
## §1's target is that a fed patron is a net material drain whose prestige is
## worth the drain, and that is measured rather than judged.
const GRANTED_WORTH: float = 90.0
const REFUSED_COST: float = 120.0

## The knob a vice turns here.
const KNOB: String = "prestige_voice"


## How loudly this man speaks of the PC at court.
##
## **One unless his vice says otherwise**, so the ordinary patron reads exactly
## as he did before there were vices.
static func voice_of(contact: Contact) -> float:
	return maxf(0.0, float(PatronVices.knob_of(contact, KNOB).get("scale", 1.0)))


## Bank what the PC just did to a patron (Seam A).
##
## **Called on every deed and returns at once for everybody else**, rather than
## compliance knowing which contacts are patrons. A guard in one place is a rule;
## a guard at the call site is a rule somebody has to remember at the next call
## site.
static func bank(
	contact: Contact, deed: StringName, log: EventLog, month: int
) -> float:
	if not Patron.is_patron(contact) or log == null:
		return 0.0
	var amount := 0.0
	match deed:
		Relationship.GRANTED, Relationship.DELIVERED:
			amount = GRANTED_WORTH
		Relationship.REFUSED, Relationship.PROMISE_BROKEN:
			amount = -REFUSED_COST
		_:
			# **Silence is not a deed at court.** `IGNORED` moves his regard,
			# which is §5's live term and not this one — a man cannot tell the
			# room about a letter that never came.
			return 0.0

	amount *= voice_of(contact)
	log.emit(EVENT_BANKED, contact.id, month, {
		"contact": String(contact.id),
		"deed": String(deed),
		"amount": amount,
	}, WorldPhase.RECKONING)
	return amount

