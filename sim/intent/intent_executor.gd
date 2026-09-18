class_name IntentExecutor
extends RefCounted

## Turns an Intent into changes in the world, over months.
##
## **The Intent model is fixed in M1; later milestones add executors, not a new
## model** (`docs/mechanics/deliberation.md` §7):
##
## | Milestone | What executes |
## | :--- | :--- |
## | M1 | Trivial executor against the stub world |
## | M2 | Colony month **Build** phase advances a town objective over months |
## | M4 | Movement: expeditions crossing the map, interruptible |
## | M6 | Armies, same executor, with combat as an interruption |
##
## **Executors are the only thing that writes sim state.** `tools/lint.gd`
## enforces the outer half of that — nothing above `sim/` may call `apply()` at
## all — and this is the inner half: within the sim, state changes belong to a
## phase or to an executor consuming an Intent.

## Which Intents this executor handles.
func handles(_intent: Intent) -> bool:
	return false


## Do one month of work on `intent`.
##
## Runs in phase 2, Movement and action. Return the resolution to apply, or
## `Intent.IN_PROGRESS` to leave it live for next month. Emitting the state
## change is the executor's job; emitting the resolution event is the book's.
func execute(_intent: Intent, _state: WorldState, _log: EventLog) -> StringName:
	return Intent.IN_PROGRESS


# --- Running the month -----------------------------------------------------

## Advance every live Intent one month, in phase 2.
##
## Intents committed **this** month are skipped: an Intent committed in month N
## executes in phase 2 of month N+1 (`docs/mechanics/world-month.md` §3). That
## one month of separation is the announce-then-act property, and the reason a
## player can never countermand an announced intent — the letter arrives in
## phase 1, four phases after the deed is already done.
static func run_month(executors: Array, book: IntentBook, state: WorldState, log: EventLog) -> void:
	for intent in book.live():
		if not intent.may_advance_in(state.month):
			continue
		var executor: IntentExecutor = _executor_for(executors, intent)
		if executor == null:
			# Nothing can carry it out. That is a stall, not a silent no-op:
			# next month's letters have to be able to say so.
			book.resolve(intent, Intent.STALLED, log, state.month, {"reason": "no_executor"})
			continue
		var resolution := executor.execute(intent, state, log)
		if resolution != Intent.IN_PROGRESS:
			book.resolve(intent, resolution, log, state.month)


static func _executor_for(executors: Array, intent: Intent) -> IntentExecutor:
	for executor in executors:
		if executor.handles(intent):
			return executor
	return null
