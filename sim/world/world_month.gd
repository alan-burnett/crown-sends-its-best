class_name WorldMonth
extends RefCounted

## The nine phases, run in order.
##
## `docs/mechanics/world-month.md`. Each phase completes for every actor before
## the next begins, on the same principle SPEC §11.3 locks for towns: no actor
## benefits from being simulated first.
##
## **This runner is not the stub.** It is the shape of a world month, and M2
## swaps a real colony in behind it by registering a different driver. Phase 2
## always executes Intents, because that is where the timing rule lives; what
## else each phase does is up to the drivers.

## Objects with `on_phase(phase, state, log, streams)`. The stub world (#20) is
## one; M2's colony will be another.
var drivers: Array = []

var book: IntentBook = null
var executors: Array = []
var streams: RngStreams = null


func _init(p_book: IntentBook = null, p_streams: RngStreams = null) -> void:
	book = p_book if p_book != null else IntentBook.new()
	streams = p_streams if p_streams != null else RngStreams.new(0)


## Advance one world month. Returns the diff across it.
##
## The month advances first, then the phases run inside it. An Intent committed
## in month N therefore finds itself in month N+1 when phase 2 comes round, which
## is exactly the one month of separation the timing rule requires.
func run(state: WorldState, log: EventLog) -> WorldDiff:
	var before := state.duplicate_state()

	state.advance_month(log)

	for phase in WorldPhase.ORDER:
		if phase == WorldPhase.MOVEMENT:
			IntentExecutor.run_month(executors, book, state, log)
		for driver in drivers:
			driver.on_phase(phase, state, log, streams)

	return WorldDiff.between(before, state)
