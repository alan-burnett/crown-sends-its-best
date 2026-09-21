class_name Provost
extends RefCounted

## The man behind the knobs (#174, `docs/mechanics/the-provost.md` §5–§8).
##
## #173 built the instrument. This is the character who has opinions about it.
##
## ## 🔒 Two things, and the pair is the whole man
##
## **Gold**, because he is a Crown officer: enact expensive policies through him
## and fail to pay for them and his regard falls, exactly as `policy.md`
## describes and entirely through that machinery.
##
## **Education**, because he is a scholar: **his loyalty rises when the colony's
## towns are learned, whether or not the PC paid for it.** So there are two ways
## to keep him — pay his bills, or build his libraries — and the second is why
## the curriculum is the cheapest way in the game to keep him content.
##
## ## 🔒 He never escalates on his own
##
## He will not enact a policy more expensive than the one in place, and he will
## not spend the PC's money unasked. **He advises** — and when he advises, he
## also advises that the PC pay for it.
##
## That makes him the opposite of the Steward, who raises duties over the PC's
## head once standing is lost (SPEC §10.2). **The Provost does not act. He simply
## stops carrying**, through `policy.md` §5's renegotiation, of which he is the
## clearest case.
##
## ## His bias is permanent and in one direction
##
## He thinks the colony is under-educated, under-peopled and its settlers poorly
## provisioned, **at every level of investment**. His leans run that way on every
## measure he reports, so his advice is predictably "spend more" — something the
## player learns to discount rather than merely resent, like the Steward's
## appetite for duties.
##
## His trade-specialisation advice (SPEC §8.1) is **advice about these same
## knobs** and not a separate mechanic. He suggests more educated immigrants the
## way the Steward suggests a firmer duty: a real opinion, honestly held, and
## reliably self-serving.

const ID: StringName = &"provost"

const EVENT_PLEASED: StringName = &"provost_regard_moved"

## How much a month of a thoroughly learned colony is worth to his regard.
##
## Small, because it is a monthly drip against a scale of a hundred and it has to
## be **worth less than paying his bills** — otherwise a PC could stiff him for
## every policy and buy him back with one library. Tuning (§9).
const REGARD_PER_MONTH: float = 0.5

## The colony education at which he is entirely satisfied. A theatre and a
## printing press in every town is 4.0; this is above that on purpose, because he
## is never entirely satisfied. Tuning.
const LEARNED_ENOUGH: float = 6.0


## What the colony's learning is worth to him this month.
##
## 🔒 **Whether or not the PC paid for it.** A colony that built its own
## libraries pleases him exactly as much as one whose curriculum he was funded
## to supply — he is a scholar before he is an accountant, and that is the half
## of him the gold does not reach.
##
## Read as the **mean across towns**, not the total, so a colony does not please
## him simply by being large.
static func regard_from_education(colony: Colony) -> float:
	if colony == null or colony.is_empty():
		return 0.0
	var total := 0.0
	var towns := 0
	for town in colony.in_order():
		total += maxf(0.0, town.education)
		towns += 1
	if towns == 0:
		return 0.0
	return REGARD_PER_MONTH * clampf((total / float(towns)) / LEARNED_ENOUGH, 0.0, 1.0)


## Let a learned colony warm him, once a month (Seam A).
static func settle_regard(contact: Contact, colony: Colony, context: ColonyContext) -> void:
	if contact == null or contact.relationship == null:
		return
	var pleased := regard_from_education(colony)
	if pleased <= 0.0:
		return
	var before := contact.relationship.loyalty
	contact.relationship.loyalty = clampf(
		before + pleased, Relationship.MIN_LOYALTY, Relationship.MAX_LOYALTY)
	if is_equal_approx(contact.relationship.loyalty, before):
		return
	# **The direction, never the figure.** Loyalty is not a number the player
	# sees (SPEC §8.5); what the letters need is that the colony's schools have
	# been noticed.
	context.log.emit(EVENT_PLEASED, contact.id, context.state.month, {
		"why": "education",
		"warming": true,
	}, WorldPhase.CROWNS_MONTH)


# --- 🔒 What he will not do ---------------------------------------------------

## What he would ask for, given what is already in force.
##
## Returns `{effect, level, monthly}`, or empty when he has nothing to say.
##
## 🔒 **Never a setting above the one in place.** He advises the PC to *pay for*
## what has already been agreed, and the knob he names is the one being carried
## at the PC's expense rather than the Crown's. Asking for more would be
## escalating on his own, which §7 is explicit he does not do.
##
## 🔒 **And the cost is always in it.** "When he advises, he also advises that
## the PC pay for it" — an advice letter with no figure in it would be him
## asking for a favour rather than presenting a bill.
static func advises(book: PolicyBook) -> Dictionary:
	if book == null:
		return {}
	var worst: Policy = null
	var most := 0.0
	for policy in book.held_by(ID):
		if not PolicyEffects.is_a_knob(policy.effect):
			continue
		# **What it actually costs him**, which is the charge times how much of it
		# he is bearing — `drains()` alone is a figure per split and would have
		# made a shilling of books rank with three hundred pounds of experts.
		#
		# A knob set to nothing costs nothing, so there is no charge to complain
		# about however the split is written.
		var out_of_pocket := policy.cost * policy.drains()
		if out_of_pocket <= 0.0:
			continue
		if worst == null or out_of_pocket > most + 0.0001:
			worst = policy
			most = out_of_pocket
	if worst == null:
		return {}

	return {
		"effect": worst.effect,
		# 🔒 **The level already in force**, and never a higher one.
		"level": StringName(worst.params.get("level", String(PolicyEffects.NOTHING))),
		"monthly": worst.cost,
	}


## Whether his advice actually names this knob at this setting.
##
## Exposed so a test can hold the lock from the outside: **there is no state of
## the world in which he names something dearer than he is already carrying.**
## Asked this way round rather than as "would this be an escalation", because the
## claim is about what he says and not about what a setting is.
static func asks_for(book: PolicyBook, effect: StringName, level: StringName) -> bool:
	var asking := advises(book)
	return not asking.is_empty() \
		and StringName(asking["effect"]) == effect \
		and StringName(asking["level"]) == level
