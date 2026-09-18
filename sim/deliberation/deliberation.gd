class_name Deliberation
extends RefCounted

## The one kernel every actor that chooses goes through.
##
## `docs/mechanics/deliberation.md` §2. Six decision points, one mechanism, so a
## system added in a later milestone extends every decision point at once
## instead of each one growing an `if` branch.
##
## The shape of a call:
##
## 1. **Filter.** Hard rules remove candidates before anything is scored (§5).
## 2. **Score.** Each applicable consideration scores each surviving candidate in
##    `[-1, +1]`, multiplied by the actor's weight for it (§3, §4).
## 3. **Aggregate.** Weighted sum, for now (§9 flags this as open: if a single
##    strong consideration ever needs to dominate, revisit toward a
##    multiplicative or infinite-axis scheme *before* adding more
##    considerations).
## 4. **Emit.** The trace goes to the event log, every time (§6).
##
## Registration is global and static because the mechanics doc specifies a static
## `choose()`, and because considerations are owned by the systems that
## introduce them — each registers itself once at startup. `reset()` exists so
## tests can work against a known set.

static var _considerations: Dictionary = {}  # kind -> Array[Consideration]
static var _filters: Dictionary = {}  # kind -> Array[DeliberationFilter]

const TRACE_EVENT: StringName = &"deliberation"


# --- Registration ----------------------------------------------------------

## Register a consideration against the decision kinds it affects.
##
## Adding one requires no change to this kernel and no change to any existing
## consideration.
static func register_consideration(consideration: Consideration, kinds: Array) -> void:
	for kind in kinds:
		_append(_considerations, kind, consideration)


static func register_filter(filter: DeliberationFilter, kinds: Array) -> void:
	for kind in kinds:
		_append(_filters, kind, filter)


static func _append(target: Dictionary, kind: Variant, entry: Variant) -> void:
	var key := StringName(kind)
	if not DecisionKind.is_kind(key):
		push_error("Unknown decision kind '%s'. Add it to DecisionKind." % key)
		return
	if not target.has(key):
		target[key] = []
	target[key].append(entry)


## Considerations for a kind, **sorted by id**, so scoring order — and therefore
## the order of the trace and the exact floating-point sum — does not depend on
## the order systems happened to register in.
static func considerations_for(kind: StringName) -> Array:
	return _sorted(_considerations.get(kind, []))


static func filters_for(kind: StringName) -> Array:
	return _sorted(_filters.get(kind, []))


static func _sorted(entries: Array) -> Array:
	var copy := entries.duplicate()
	copy.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a.id) < String(b.id))
	return copy


## Drop every registration. For tests, and for starting a fresh run.
static func reset() -> void:
	_considerations = {}
	_filters = {}


# --- Choosing --------------------------------------------------------------

## Weigh `candidates` and choose. Always returns a `Decision`, and always emits
## its trace.
static func choose(actor: DeliberationActor, candidates: Array, context: DeliberationContext) -> Decision:
	var decision := Decision.new(context.kind, actor.id)
	var filters := filters_for(context.kind)
	var considerations := considerations_for(context.kind)

	var best: Candidate = null
	var best_total: float = Decision.NO_SCORE

	for candidate in candidates:
		var blocked_by := _first_blocking_filter(filters, actor, candidate, context)
		if not blocked_by.is_empty():
			decision.entries.append({"id": String(candidate.id), "filtered_by": String(blocked_by)})
			continue

		var scored: Array[Dictionary] = []
		var total: float = 0.0
		for consideration in considerations:
			if not consideration.applies_to(candidate):
				continue
			var raw := consideration.scored(actor, candidate, context)
			var weight := actor.weight_for(consideration.id)
			var weighted := raw * weight
			total += weighted
			scored.append({
				"id": String(consideration.id),
				"raw": raw,
				"weight": weight,
				"weighted": weighted,
			})

		decision.entries.append({
			"id": String(candidate.id),
			"total": total,
			"considerations": scored,
		})

		# Ties break on candidate id rather than on a die roll, so a tie does not
		# consume from the actor's stream and shift every later draw. A decision
		# that should be random gets that from a consideration, not from here.
		if best == null or total > best_total or (is_equal_approx(total, best_total) and String(candidate.id) < String(best.id)):
			best = candidate
			best_total = total

	decision.chosen = best
	_emit_trace(decision, context)
	return decision


static func _first_blocking_filter(filters: Array, actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> StringName:
	for filter in filters:
		if not filter.permits(actor, candidate, context):
			return filter.id
	return &""


## The trace goes to the log every time. Structured, never prose — the letter
## that explains a decision is rendered later, from data, per language.
static func _emit_trace(decision: Decision, context: DeliberationContext) -> void:
	if context.log == null:
		push_error("Deliberation.choose() had no event log. The trace is not optional.")
		return
	context.log.emit(TRACE_EVENT, decision.actor_id, context.month, decision.to_dict(), context.phase)
