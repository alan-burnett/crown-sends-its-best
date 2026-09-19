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

## Intent kind -> what it moves and by how much.
##
## | Key | Meaning |
## | :--- | :--- |
## | `target` | The world value it moves. `""` means it moves nothing |
## | `target_from_data` | Read the world value's name out of the Intent instead, for Orders that choose their own target — a tax rate names the resource it is levied on |
## | `per_month` | A fixed monthly change |
## | `amount_factor` | Scale whatever the letter promised |
## | `set_from_data` | **Set** the value outright, rather than move it, reading the new value out of the Intent. A tax instruction puts a rate somewhere; it does not drift one towards it — and it has to be able to create the value, since a resource with no override yet has no rate of its own |
##
## **What each kind of Order means in the world.** The sim cannot name the Order
## kinds — they belong to the correspondence layer — so the table is handed in by
## whoever can see both, which is the turn loop. That also keeps the whole
## mapping in one readable place, to be deleted with the rest of the stub in M2.
##
## A `target` of `""` means the Order has no effect on the world at all. It still
## completes rather than stalling: a stall is "nothing could carry this out",
## which is a different and much louder thing to say.
var table: Dictionary = {}


func handles(intent: Intent) -> bool:
	return intent.kind == KIND or table.has(String(intent.kind))


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var entry: Dictionary = table.get(String(intent.kind), {})
	var key: String = String(entry.get("target", intent.target))
	if entry.has("target_from_data"):
		key = String(intent.data.get(String(entry["target_from_data"]), ""))

	# An Order with nothing to do in the world is done the moment it is read.
	if key.is_empty():
		intent.progress = intent.months_required
		log.emit(IntentBook.EVENT_ADVANCED, intent.source, state.month, {
			"intent": String(intent.id),
			"kind": String(intent.kind),
			"target": "",
			"progress": intent.progress,
			"months_required": intent.months_required,
			"remaining": 0,
		}, WorldPhase.MOVEMENT)
		return Intent.COMPLETED

	# Setting a value outright, which may not exist yet — that is the normal case
	# for the first override on a resource.
	if entry.has("set_from_data"):
		var settled := float(intent.data.get(String(entry["set_from_data"]), 0.0))
		intent.progress = intent.months_required
		state.apply(log, EVENT_PROGRESSED, intent.source, {key: settled}, WorldPhase.MOVEMENT)
		return Intent.COMPLETED

	if not state.has_value(key):
		# The thing it was aimed at is gone. Next month's letters need to be able
		# to report that it came to nothing, so this stalls rather than silently
		# doing nothing for ever.
		return Intent.STALLED

	var per_month := _per_month(intent, entry)
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


## How far this Intent moves its target each month.
##
## An Intent carrying its own `per_month` says so directly. Otherwise the table
## scales whatever the letter promised — send more iron and the colony feels it
## more, which is what makes the amount in the letter a real choice.
func _per_month(intent: Intent, entry: Dictionary) -> float:
	if intent.data.has("per_month"):
		return float(intent.data["per_month"])
	if entry.has("amount_factor"):
		var amount := float(intent.data.get("amount", 0.0))
		return amount * float(entry["amount_factor"]) / float(maxi(1, intent.months_required))
	return float(entry.get("per_month", 0.0))
