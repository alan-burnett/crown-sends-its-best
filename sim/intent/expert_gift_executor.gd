class_name ExpertGiftExecutor
extends IntentExecutor

## A patron sends the colony an expert, because the PC took up his offer (#443,
## `docs/mechanics/patrons.md` §4).
##
## ## 🔒 To the library that holds fewest of his kind
##
## *An expert of his kind, arriving in the town with a library that holds the
## fewest experts of that kind, ties to town order.* Chosen the month he lands
## rather than the month he was offered, so a library built meanwhile counts and
## a town lost meanwhile does not. A colony with no library left has nowhere to
## put him, and the Intent stalls so the post can say it came to nothing.
##
## ## Through an Intent, like every other act
##
## The reply is an Order to the patron; compliance decides whether he goes
## through with it; this lands the man the month after (Seam B, C).

## The Order kind and the Intent kind.
const KIND: StringName = &"send_an_expert"

## What he needs to find when he lands.
const LIBRARY: StringName = &"library"

const EVENT_ARRIVED: StringName = &"patron_expert_arrived"

## Supplied by the turn loop: where he could go.
var colony: Colony = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var kind := StringName(intent.data.get("resource", ""))
	var town := town_for(colony, kind)
	if String(kind).is_empty() or town == null:
		return Intent.STALLED
	town.add_experts(kind, 1)
	log.emit(EVENT_ARRIVED, town.id, state.month, {
		"town": String(town.id),
		"resource": String(kind),
		"from": String(intent.source),
	}, WorldPhase.MOVEMENT)
	intent.progress = intent.months_required
	return Intent.COMPLETED


## 🔒 **The loyal town with a library that holds fewest experts of `kind`**,
## ties to the first in town order; null when no such town stands. A town in
## rebellion is not one the patron's man is sent to.
static func town_for(within: Colony, kind: StringName) -> Town:
	if within == null:
		return null
	var chosen: Town = null
	for entry in within.in_order():
		var town: Town = entry
		if town.rebelling or not town.has_building(LIBRARY):
			continue
		if chosen == null or town.expert_count(kind) < chosen.expert_count(kind):
			chosen = town
	return chosen
