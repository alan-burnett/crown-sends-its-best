class_name EmbargoExecutor
extends IntentExecutor

## The Crown forbids the colony to relieve one of its own towns
## (#73, #74, SPEC §12.3).
##
## ## The PC's one punishment before he has troops
##
## Crown troops are M6, so SPEC §12.3 names three answers to a rebellion —
## force, punishment, reward — and M3 has only two of them. This is punishment:
## the rebel town's neighbours stop relieving it, and the rebellion begins to
## cost something its neighbours can see.
##
## ## It cuts both ways on purpose
##
## | | |
## | :--- | :--- |
## | On the town punished | sentiment **rises** — the hunger is plainly the Crown's doing |
## | On everyone watching | the spread term **falls** — rebelling is visibly not working |
##
## That tension is the design and not a bug (`rebel-sentiment.md` §9). The PC
## buys quiet among the loyal towns at the price of digging in the one he is
## trying to win back, and he has to decide which he needs more.
##
## ## It takes effect at once, and then runs down
##
## Unlike a shipment there is nothing to carry: an order not to send convoys is
## obeyed or it is not. So the Intent completes the month it is executed, and
## what lasts is the count of months on the town, which Settle spends.

const EVENT_LAID: StringName = &"embargo_laid"
const EVENT_LIFTED: StringName = &"embargo_lifted"

const KIND: StringName = &"embargo"

## The colony the Intent names a town in. Supplied by the turn loop.
var colony: Colony = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	if colony == null:
		return Intent.STALLED
	var town := Shipment.town_of(colony, intent)
	if town == null:
		return Intent.OVERTAKEN_BY_EVENTS

	var months := maxi(0, int(intent.data.get("months", 0)))
	town.embargo_months = months
	log.emit(EVENT_LAID if months > 0 else EVENT_LIFTED, town.id, state.month, {
		"town": String(town.id),
		"months": months,
		"rebelling": town.rebelling,
	}, WorldPhase.MOVEMENT)
	return Intent.COMPLETED
