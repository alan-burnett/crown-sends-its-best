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


## What a town has more of than one, and could therefore spare.
##
## 🔒 **More than one, never the last man.** *"If I have more than one expert of
## a particular type"* — a town that holds the colony's only weaver keeps him,
## so this can never strip a specialism out of the place that has it.
##
## Sorted, so the same colony always sends the same man in the same order.
static func spare_kinds(town: Town) -> PackedStringArray:
	var out := PackedStringArray()
	if town == null:
		return out
	var kinds: Array = town.experts.keys()
	kinds.sort()
	for kind in kinds:
		if town.expert_count(StringName(kind)) > 1:
			out.append(String(kind))
	return out


## Where a man of this kind would do the most good, other than where he is.
##
## 🔒 **Asked of `Experts.worth_of`**, which is the same reading a town uses to
## decide what expertise it wants — so the scholar's judgement of *most useful*
## and the colony's are one function. A second opinion here would be a second
## answer to what an expert is for.
##
## ## 🔒 A town with none of them comes first, whatever the arithmetic says
##
## **The first expert a town has is worth more than the arithmetic admits.** He
## is the difference between a trade the town can work at all and one it cannot,
## and `worth_of`'s diminishing returns are a statement about the *second*. So a
## town holding none of this kind wins outright, and among those the one that
## would gain most.
##
## Only when every candidate already has one does this fall back to the plain
## comparison — and then **only if somewhere genuinely beats standing still.**
##
## ## 🔒 And that is what stops the shuffling
##
## Five towns and eight food experts must not spend the run passing men back and
## forth. Three things hold it still: a town never sends its last of a kind
## (`spare_kinds`), an empty town is a one-way destination that stops being empty
## the moment he arrives, and the fallback requires strictly more than staying
## put — so an arrangement with nowhere better to be is an arrangement that stops
## moving.
##
## Null when nowhere would be better, which includes a colony of one town.
static func most_useful_elsewhere(
	home: Town, resource: StringName, context: ColonyContext
) -> Town:
	if home == null or context == null or context.colony == null:
		return null

	# First pass: somewhere that has none of him at all.
	var barest: Town = null
	var barest_worth := 0.0
	for town in context.colony.in_order():
		if town == home or town.expert_count(resource) > 0:
			continue
		var gain := Experts.worth_of(town, resource, context)
		if barest == null or gain > barest_worth:
			barest = town
			barest_worth = gain
	if barest != null:
		return barest

	# Second: everybody has one, so it is worth more only where it is worth more.
	var best: Town = null
	var best_worth := Experts.worth_of(home, resource, context)
	for town in context.colony.in_order():
		if town == home:
			continue
		var worth := Experts.worth_of(town, resource, context)
		if worth > best_worth:
			best_worth = worth
			best = town
	return best
