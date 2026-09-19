class_name LoyaltyDrift
extends RefCounted

## Why should I be loyal to the Crown?
## (#126, SPEC §8.5; `docs/mechanics/contacts.md` §5.)
##
## ## 🔒 Loyalty has two sources, and neither alone works
##
## **Deeds are memory**: what the PC granted, refused, delivered, broke and
## ignored. **Drift is the world**: whether the things this contact judges the
## Crown by are going well.
##
## Deeds without drift means a contact is indifferent to a colony falling apart
## around him so long as the PC is polite. Drift without deeds means the PC's
## choices stop mattering, which is the game. So the two combine, and the
## balance between them is a tuning value rather than a constant buried in a
## formula.
##
## ## Every contact already answers the question
##
## *They send me what I need. They keep me safe. They pay me. They leave me
## alone.* That answer is his `cares_about` — the measure ids he judges the PC
## by — and it has been on every contact since M1 with nothing reading it for
## this purpose.
##
## ## What it does, and what it does not
##
## A well-run colony makes its governors fonder of the Crown, which shows up
## where contact loyalty already matters — measured across 20 seeds and 8 years,
## mean rebel sentiment falls from 1.65 to 0.27 by year four with this on. A
## colony going badly does the reverse.
##
## **It does not on its own settle #90's finding** that the miser and the
## absentee produce identical colonies, and it is worth saying why rather than
## claiming it did. Drift is a function of the world, so two players who both do
## nothing get the same drift. Their colonies are identical because **every
## governor letter is skippable**: a policy that answers only what it must never
## answers a governor at all, so "refuse everything" and "write nothing" are the
## same instruction where the colony is concerned. That is a content gap, not a
## loyalty one, and it is reported on #90.
##
## ## Only a still world does not drift
##
## A measure sitting at its middling value moves nobody. That is the one case
## §5 allows: *a contact whose world is untouched and who has had no
## correspondence has no drift.* The Squeeze tightening while the colony grows
## means almost nobody stays there for long.

## How far a month of a perfect world, or a ruined one, can move a man.
##
## **The balance between drift and deeds**, and the thing to reach for first if
## the PC's letters start to feel weightless or irrelevant. A granted request is
## worth several points at once (`Relationship.DEED_WEIGHT`); a month of things
## going badly is worth a fraction of one, and there are a great many months.
const MONTHLY_REACH: float = 0.9

## Where a measure stops being good news and starts being bad.
##
## Measures are normalised to `0..1` by `MeasureRegistry`, so the middle is the
## natural place for "no opinion either way" — and it is what makes an untouched
## world produce no drift at all rather than a slow slide in one direction.
const INDIFFERENT: float = 0.5

const EVENT_DRIFTED: StringName = &"loyalty_drifted"


## How far this contact's regard should move this month, before deeds.
##
## Returns zero when he judges the Crown by nothing, which is not a failure: a
## contact with no `cares_about` is a man with no stake, and the PC's letters are
## the only thing that will ever move him.
static func for_contact(contact: Contact, measures: Dictionary) -> float:
	if contact == null or contact.cares_about.is_empty():
		return 0.0

	var judged := 0.0
	var counted := 0
	# Ordered, so the average is the contact's and not the array's.
	var topics := contact.cares_about.duplicate()
	topics.sort()
	for topic in topics:
		if not measures.has(topic) or not MeasureRegistry.has_measure(topic):
			continue
		judged += MeasureRegistry.normalize(topic, float(measures[topic]))
		counted += 1

	if counted == 0:
		return 0.0
	return MONTHLY_REACH * (judged / float(counted) - INDIFFERENT) / INDIFFERENT


## Which of the things he cares about is doing the most to his regard.
##
## **What a letter can name.** A contact who is cooling has a reason, and the
## reason is a topic rather than a number — so he can write about the war going
## badly without anybody seeing how badly he has taken it.
static func loudest(contact: Contact, measures: Dictionary) -> String:
	if contact == null:
		return ""
	var topics := contact.cares_about.duplicate()
	topics.sort()

	var worst := ""
	var furthest := 0.0
	for topic in topics:
		if not measures.has(topic) or not MeasureRegistry.has_measure(topic):
			continue
		var distance := absf(MeasureRegistry.normalize(topic, float(measures[topic])) - INDIFFERENT)
		if distance > furthest + 0.000001:
			furthest = distance
			worst = String(topic)
	return worst
