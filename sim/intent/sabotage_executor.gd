class_name SabotageExecutor
extends IntentExecutor

## A patron works against a duke, because the PC accepted his offer (#395,
## `docs/mechanics/patrons.md` §5).
##
## ## 🔒 He interferes with a rival; he never touches the PC's relationship with him
##
## The patron's rival specialty, granted, is `SabotageDriver.arrange`: that
## duke's companies fight at a heavy disadvantage for a year, and while they do
## the third door is open on his tribute letters (`a_patron_can_deflect_him`).
## **Nothing here moves the duke's regard**, because he never puts it together.
##
## ## Through an Intent, like every other act
##
## The reply is an Order to the patron; compliance decides whether he goes
## through with it; this lands it the month after (Seam B, C). A duke who has
## reached minimum by then cannot be troubled — `arrange` refuses outright rather
## than granting weakly — and the Intent stalls, so the post can say it came to
## nothing.

## The Order kind and the Intent kind.
const KIND: StringName = &"trouble_a_duke"

## Supplied by the turn loop: who the duke is.
var contacts: Dictionary = {}


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var duke: Contact = contacts.get(String(intent.data.get("duke", "")))
	if duke == null or duke.role != RivalDuke.ROLE:
		return Intent.STALLED
	if not SabotageDriver.arrange(duke, state, log, state.month):
		return Intent.STALLED
	intent.progress = intent.months_required
	return Intent.COMPLETED
