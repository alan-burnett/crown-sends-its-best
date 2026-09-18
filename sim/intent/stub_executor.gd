class_name StubIntentExecutor
extends IntentExecutor

## The M1 executor: moves one of the stub world's scalars, a month at a time.
##
## Deliberately thin. The point of M1 is whether reading and answering the mail
## is fun, so the world only has to move plausibly underneath the letters (#20).
## What matters is that this is a **real executor against the real model**, so
## M2's colony month swaps in behind the seam without the Intent model changing.
##
## An Intent it handles looks like:
##
## ```gdscript
## Intent.new(&"", KIND, &"marshal", &"crown_war_intensity", 3, {"per_month": -4.0})
## ```
##
## Three months of work, moving `crown_war_intensity` by -4 each month.

const KIND: StringName = &"adjust_value"

const EVENT_PROGRESSED: StringName = &"intent_progressed"


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var key: String = String(intent.target)
	if not state.has_value(key):
		# The thing it was aimed at is gone. Next month's letters need to be able
		# to report that it came to nothing, so this stalls rather than silently
		# doing nothing for ever.
		return Intent.STALLED

	var per_month := float(intent.data.get("per_month", 0.0))
	var before := float(state.get_value(key, 0.0))
	var completed := intent.advance()

	state.apply(
		log,
		EVENT_PROGRESSED,
		intent.source,
		{key: before + per_month},
		WorldPhase.MOVEMENT,
	)
	log.emit(IntentBook.EVENT_ADVANCED, intent.source, state.month, {
		"intent": String(intent.id),
		"kind": String(intent.kind),
		"target": key,
		"progress": intent.progress,
		"months_required": intent.months_required,
		"remaining": intent.remaining(),
	}, WorldPhase.MOVEMENT)

	return Intent.COMPLETED if completed else Intent.IN_PROGRESS
