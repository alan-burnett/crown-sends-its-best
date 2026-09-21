class_name PreferenceExecutor
extends IntentExecutor

## The PC tells a governor what he is looking for (#177,
## `docs/mechanics/founding-towns.md` §5, SPEC §11.4).
##
## ## 🔒 The PC never chooses a tile
##
## He approves, refuses, or states a preference — toward the coast, near the ore,
## away from the tribes. **The Intent carries a name and there is nowhere in it
## to put a coordinate**, which is how the locked invariant is kept rather than
## remembered.
##
## ## 🔒 And it only works while he is walking
##
## A preference letter that arrives mid-crossing changes where the town ends up.
## **The same letter arriving after he has settled changes nothing**, because
## there is no party left to read it — which is the point of the window, and the
## clearest case in the game of a letter arriving in time to matter.
##
## That is `world-month.md` §3's interruptible multi-month action in its purest
## form: the journey is long *so that* the letter can reach it.

const EVENT_TOO_LATE: StringName = &"preference_arrived_too_late"

const KIND: StringName = &"prefer_site"

## The parties in the open. The same array everything else shares.
var parties: Array = []


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var wanted := StringName(intent.data.get("preference", ""))
	if not SitePreference.is_preference(wanted):
		return Intent.ABANDONED

	var context := ColonyContext.new(state, log, null, null)
	var told := false
	# Sorted by id, so which party hears first cannot depend on launch order.
	for party in _in_order():
		if party.parent != intent.target and party.parent != intent.source:
			continue
		if party.turning_back or party.is_empty():
			continue
		told = party.prefer(wanted, context) or told

	if told:
		return Intent.COMPLETED

	# 🔒 **Overtaken by events, and said so.** The governor has already settled,
	# or never set out. A letter that quietly did nothing would teach the player
	# that preferences do not work; this is what lets the reply say it came late.
	log.emit(EVENT_TOO_LATE, intent.target, state.month, {
		"to": String(intent.target),
		"preference": String(wanted),
	}, WorldPhase.MOVEMENT)
	return Intent.OVERTAKEN_BY_EVENTS


func _in_order() -> Array:
	var out: Array = parties.duplicate()
	out.sort_custom(func(a: ExpeditionParty, b: ExpeditionParty) -> bool:
		return String(a.id) < String(b.id))
	return out
