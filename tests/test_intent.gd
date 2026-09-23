extends TestCase

## The Intent model and the stub executor (#4), and the timing rule from
## `docs/mechanics/world-month.md` §3.

var log: EventLog = null
var book: IntentBook = null
var state: WorldState = null
var executors: Array = []


func before_each() -> void:
	log = EventLog.new()
	book = IntentBook.new()
	state = WorldState.new(0, {"crown_war_intensity": 50.0})
	executors = [WorldValueExecutor.new()]


func _adjust(months: int, per_month: float = -4.0, source: StringName = &"marshal") -> Intent:
	return Intent.new(
		&"", WorldValueExecutor.KIND, source, &"crown_war_intensity", months, {"per_month": per_month}
	)


## One world month: advance the clock, then run phase 2.
func _run_month() -> void:
	state.advance_month(log)
	IntentExecutor.run_month(executors, book, state, log)


# --- The timing rule -------------------------------------------------------

func test_an_intent_does_not_advance_in_the_month_it_was_committed() -> void:
	# An Intent committed in month N executes in phase 2 of month N+1. That one
	# month of separation is the announce-then-act property the whole loop
	# depends on.
	var intent := book.commit(_adjust(1), log, state.month)
	IntentExecutor.run_month(executors, book, state, log)

	assert_eq(intent.progress, 0, "it must not act in the month it was committed")
	assert_true(intent.is_live())
	assert_almost_eq(state.get_value("crown_war_intensity"), 50.0, 0.001, "the world must not have moved yet")

	_run_month()
	assert_eq(intent.progress, 1)
	assert_almost_eq(state.get_value("crown_war_intensity"), 46.0, 0.001)


func test_a_player_can_never_countermand_an_announced_intent() -> void:
	# He writes "I shall retreat"; you write back "no, attack." Your letter
	# arrives in phase 1, but he retreats in phase 2, four phases before he reads
	# you. You watch the retreat, and the month after that he attacks.
	var retreat := book.commit(_adjust(1, -10.0, &"commander"), log, state.month)

	# Month 1: the countermand arrives, but the retreat is already committed.
	state.advance_month(log)
	IntentExecutor.run_month(executors, book, state, log)
	assert_eq(retreat.resolution, Intent.COMPLETED, "the deed is done before the letter is read")

	# Only now can the new order become an Intent, and it acts the month after.
	var attack := book.commit(_adjust(1, 10.0, &"commander"), log, state.month)
	assert_eq(attack.progress, 0)
	_run_month()
	assert_eq(attack.resolution, Intent.COMPLETED)


# --- Spanning months -------------------------------------------------------

func test_an_intent_spans_months_and_reports_progress() -> void:
	var intent := book.commit(_adjust(3), log, state.month)
	assert_eq(intent.remaining(), 3)

	_run_month()
	assert_eq(intent.progress, 1)
	assert_eq(intent.remaining(), 2)
	assert_true(intent.is_live())

	_run_month()
	assert_eq(intent.progress, 2)
	assert_true(intent.is_live())

	_run_month()
	assert_eq(intent.progress, 3)
	assert_eq(intent.resolution, Intent.COMPLETED)


func test_progress_is_reported_every_month() -> void:
	book.commit(_adjust(3), log, state.month)
	_run_month()
	_run_month()
	var advances := log.of_type(IntentBook.EVENT_ADVANCED)
	assert_eq(advances.size(), 2)
	assert_eq(advances[0].payload["remaining"], 2)
	assert_eq(advances[1].payload["remaining"], 1)


func test_a_multi_month_intent_can_be_interrupted_partway() -> void:
	# "Make consequential actions multi-month, so they can be interrupted."
	var march := book.commit(_adjust(3), log, state.month)
	_run_month()
	assert_eq(march.progress, 1)

	book.commit(_adjust(1, 2.0), log, state.month)
	assert_eq(march.resolution, Intent.OVERTAKEN_BY_EVENTS, "a letter turned him around partway")


# --- The four resolutions --------------------------------------------------

func test_completed_is_reachable_and_distinguishable() -> void:
	book.commit(_adjust(1), log, state.month)
	_run_month()
	assert_eq(log.of_type(&"intent_completed").size(), 1)


func test_stalled_is_reachable_and_distinguishable() -> void:
	# Nothing can carry it out, which is a stall rather than a silent no-op —
	# next month's letters have to be able to say so.
	var orphan := Intent.new(&"", &"nobody_handles_this", &"marshal", &"crown_war_intensity", 1, {})
	book.commit(orphan, log, state.month)
	_run_month()
	assert_eq(orphan.resolution, Intent.STALLED)
	assert_eq(log.of_type(&"intent_stalled").size(), 1)


func test_stalled_when_the_target_is_gone() -> void:
	var intent := book.commit(_adjust(2), log, state.month)
	state.values.erase("crown_war_intensity")
	_run_month()
	assert_eq(intent.resolution, Intent.STALLED)


func test_abandoned_is_reachable_and_distinguishable() -> void:
	var intent := book.commit(_adjust(3), log, state.month)
	book.resolve(intent, Intent.ABANDONED, log, state.month, {"reason": "he thought better of it"})
	assert_eq(intent.resolution, Intent.ABANDONED)
	assert_eq(log.of_type(&"intent_abandoned").size(), 1)


func test_overtaken_is_reachable_and_distinguishable() -> void:
	var first := book.commit(_adjust(4), log, state.month)
	var second := book.commit(_adjust(1), log, state.month)
	assert_eq(first.resolution, Intent.OVERTAKEN_BY_EVENTS)
	assert_true(second.is_live())

	var events := log.of_type(&"intent_overtaken")
	assert_eq(events.size(), 1)
	assert_eq(events[0].payload["superseded_by"], String(second.id))


func test_a_resolved_intent_does_not_resolve_twice() -> void:
	var intent := book.commit(_adjust(3), log, state.month)
	book.resolve(intent, Intent.ABANDONED, log, state.month)
	book.resolve(intent, Intent.COMPLETED, log, state.month)
	assert_eq(intent.resolution, Intent.ABANDONED)
	assert_eq(log.of_type(&"intent_completed").size(), 0)


# --- Supersession ----------------------------------------------------------

func test_intents_aimed_elsewhere_do_not_contend() -> void:
	var first := book.commit(_adjust(3), log, state.month)
	var elsewhere := Intent.new(&"", WorldValueExecutor.KIND, &"marshal", &"colony_revenue", 1, {})
	book.commit(elsewhere, log, state.month)
	assert_true(first.is_live(), "a different target is a different matter")


func test_another_actors_intent_does_not_contend() -> void:
	var marshal := book.commit(_adjust(3, -4.0, &"marshal"), log, state.month)
	book.commit(_adjust(3, -4.0, &"steward"), log, state.month)
	assert_true(marshal.is_live())


# --- Origin ----------------------------------------------------------------

func test_order_and_will_are_the_same_code_path() -> void:
	# "The contact complied" and "the contact acted on his own and informed the
	# PC afterward" are the same path with different origins. That is Seam C.
	var from_order := _adjust(1, -4.0, &"marshal")
	from_order.origin = Intent.ORIGIN_ORDER
	var from_will := _adjust(1, -4.0, &"steward")
	from_will.origin = Intent.ORIGIN_WILL

	book.commit(from_order, log, state.month)
	book.commit(from_will, log, state.month)
	_run_month()

	assert_eq(from_order.resolution, Intent.COMPLETED)
	assert_eq(from_will.resolution, Intent.COMPLETED)
	assert_eq(log.of_type(&"intent_completed").size(), 2)


# --- Serialisation ---------------------------------------------------------

func test_in_flight_intents_survive_a_round_trip() -> void:
	book.commit(_adjust(4), log, state.month)
	_run_month()

	var restored := IntentBook.from_dict(book.to_dict())
	assert_eq(restored.to_dict(), book.to_dict())

	var intent := restored.live()[0]
	assert_eq(intent.progress, 1)
	assert_eq(intent.remaining(), 3)
	assert_eq(intent.committed_month, 0)


func test_a_restored_intent_carries_on_where_it_left_off() -> void:
	book.commit(_adjust(3), log, state.month)
	_run_month()

	var restored := IntentBook.from_dict(book.to_dict())
	IntentExecutor.run_month(executors, restored, state, log)
	assert_eq(restored.live()[0].progress, 2, "it must not restart after a reload")


func test_resolved_intents_are_kept() -> void:
	# Next month's letters report what happened, and a contact remembers what he
	# was told to do.
	var intent := book.commit(_adjust(1), log, state.month)
	_run_month()
	assert_eq(book.resolved().size(), 1)
	assert_eq(book.resolved_in(intent.resolved_month).size(), 1)
	assert_eq(book.by_id(intent.id).resolution, Intent.COMPLETED)


func test_ids_are_assigned_and_unique() -> void:
	var first := book.commit(_adjust(1, -4.0, &"a"), log, state.month)
	var second := book.commit(_adjust(1, -4.0, &"b"), log, state.month)
	assert_ne(String(first.id), String(second.id))
	assert_not_empty(String(first.id))


func test_committing_emits_in_the_intent_phase() -> void:
	# Phase 8: everyone deliberates and commits. Nothing in that phase changes
	# the world — will is not a write.
	book.commit(_adjust(1), log, state.month)
	var committed := log.of_type(IntentBook.EVENT_COMMITTED)
	assert_eq(committed.size(), 1)
	assert_eq(committed[0].phase, WorldPhase.INTENT)
	assert_empty(log.for_phase(WorldPhase.MOVEMENT), "committing must not move the world")


func test_execution_emits_in_the_movement_phase() -> void:
	book.commit(_adjust(1), log, state.month)
	_run_month()
	assert_eq(log.of_type(WorldValueExecutor.EVENT_PROGRESSED)[0].phase, WorldPhase.MOVEMENT)


func test_an_unknown_resolution_is_refused() -> void:
	var intent := _adjust(1)
	intent.resolve(&"not_a_resolution", 3)
	assert_eq(intent.resolution, Intent.IN_PROGRESS)
