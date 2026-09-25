class_name GoldGiftExecutor
extends IntentExecutor

## A patron's gold reaches the Crown, because the PC took up his offer (#443,
## `docs/mechanics/patrons.md` §4).
##
## ## 🔒 To the Crown's books, and shown in the Ledger
##
## One event naming who gave it and how much. `CrownAccounts` counts it among
## what the Crown received, so it moves `net_position` as duty does, and the
## Ledger shows it as a line of its own. **It is not duty**: a revenue target the
## PC undertook is judged on what the colony's trade brought in, and a gift is
## not trade.
##
## ## Through an Intent, like every other act
##
## The reply is an Order to the patron; compliance decides whether he goes
## through with it; this lands it the month after (Seam B, C).

## The Order kind and the Intent kind.
const KIND: StringName = &"give_the_crown_gold"

const EVENT_GIVEN: StringName = &"crown_given_gold"


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var amount := float(intent.data.get("amount", 0.0))
	if amount <= 0.0:
		return Intent.STALLED
	log.emit(EVENT_GIVEN, intent.source, state.month, {
		"from": String(intent.source),
		"amount": amount,
	}, WorldPhase.MOVEMENT)
	intent.progress = intent.months_required
	return Intent.COMPLETED
