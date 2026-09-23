class_name ExpertTransfer
extends RefCounted

## Moving an expert from one town to another (#280,
## `docs/mechanics/institutional-contacts.md` §3, the scholar).
##
## ## 🔒 The only thing in the game that can do this
##
## `the-provost.md` brings experts **into** the colony and nothing else could
## move one once it had landed. A fur town that became a weaving town was stuck
## with its trapper for the rest of the run, and a colony's expertise was fixed
## by wherever growth happened to put it.
##
## **The scholar is the cure**, and this is the whole of the machinery. A guard
## in `test_experts` refuses a second route: two ways to move a man is two rules
## about who may, and the first time one is tuned the other will not know.
##
## ## 🔒 It moves a man; it does not make or unmake one
##
## One expert leaves and the same expert arrives. No share, no rounding, no
## remainder — `Experts` carries all of that for people who are *becoming*
## expert, and this is a man who already is, walking to another town.
##
## So the colony's total is unchanged by construction, which is what stops this
## becoming a second source of experts next to the Provost's.
##
## ## What it is not
##
## **Not an objective, and not the town's decision.** SPEC §11.3 locks that towns
## run themselves and the PC never manages them directly — but an expert is not
## a project, a tile or a month. He is a man the scholar writes to, and who goes.
## The town he leaves is not consulted, which is the one thing about the scholar
## that ought to make a player uneasy.

const EVENT_MOVED: StringName = &"expert_moved"


## Whether there is a man of this kind to move, and somewhere to move him.
static func may_move(from: Town, to: Town, resource: StringName) -> bool:
	if from == null or to == null or from == to:
		return false
	return from.expert_count(resource) > 0


## Move one (Seam A). Returns whether anybody went.
##
## **Silent when he cannot.** A scholar asked for a weaver by a town that has no
## weaver has nothing to report but his regrets, and those are a letter rather
## than an event.
static func move(
	from: Town, to: Town, resource: StringName, context: ColonyContext
) -> bool:
	if not may_move(from, to, resource) or context == null:
		return false

	from.add_experts(resource, -1)
	to.add_experts(resource, 1)

	context.log.emit(EVENT_MOVED, to.id, context.state.month, {
		"resource": String(resource),
		"from": String(from.id),
		"from_name": from.display_name,
		"to": String(to.id),
		"to_name": to.display_name,
	}, WorldPhase.COLONY_MONTH)
	return true


## Where this man would send an expert if nobody told him (§3).
##
## 🔒 **His bias corrupts his own capability**, which is the sharpest kind.
## `buildings.md` calls him *a contact who wants experts spread about the
## colony*, and that is what he sincerely believes about himself. **What he
## actually does is gather them** — toward his own library, because that is where
## expertise can be properly used and where the real work is done. The frontier
## town that needs a farmer is not his concern; it has no library to receive one.
##
## Follow his advice and you end with one brilliant town and a colony of hamlets,
## and he will be sincerely delighted about it.
##
## 🔒 **Asked directly he still obeys.** This is his *unprompted* judgement, and
## nothing here is consulted when a letter names a destination — exactly as the
## Steward follows an instruction he disagrees with.
static func where_he_would_send(scholar: Contact, colony: Colony) -> Town:
	if scholar == null or colony == null:
		return null
	for town in colony.in_order():
		if town.display_name == scholar.town:
			return town
	return null


## Somewhere to take one from, for a man who has decided where they should go.
##
## **The town with the most of them**, so he raids the colony's surplus rather
## than the last weaver a hamlet has — sorted by id underneath, so the same
## colony always gives up the same man.
static func where_he_would_take_from(
	resource: StringName, colony: Colony, destination: Town
) -> Town:
	if colony == null or destination == null:
		return null
	var best: Town = null
	for town in colony.in_order():
		if town == destination or town.expert_count(resource) <= 0:
			continue
		if best == null or town.expert_count(resource) > best.expert_count(resource):
			best = town
	return best
