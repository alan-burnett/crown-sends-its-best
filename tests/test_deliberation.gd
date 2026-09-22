extends TestCase

## The deliberation kernel (#5), against `docs/mechanics/deliberation.md`.


# --- Test doubles ----------------------------------------------------------
#
# Considerations are owned by the system that introduces them, so these stand in
# for systems that do not exist yet. They also demonstrate the point of the
# registry: none of them required a change to the kernel.

class FixedConsideration:
	extends Consideration

	var scores: Dictionary = {}
	var only: PackedStringArray = PackedStringArray()

	func _init(p_id: StringName, p_scores: Dictionary, p_only: PackedStringArray = PackedStringArray()) -> void:
		super(p_id)
		scores = p_scores
		only = p_only

	func applies_to(candidate: Candidate) -> bool:
		return only.is_empty() or only.has(String(candidate.id))

	func score(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> float:
		return float(scores.get(String(candidate.id), 0.0))


class OutOfRangeConsideration:
	extends Consideration

	func score(_actor: DeliberationActor, _candidate: Candidate, _context: DeliberationContext) -> float:
		return 40.0


class BlockingFilter:
	extends DeliberationFilter

	var blocked: PackedStringArray = PackedStringArray()

	func _init(p_id: StringName, p_blocked: PackedStringArray) -> void:
		super(p_id)
		blocked = p_blocked

	func permits(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> bool:
		return not blocked.has(String(candidate.id))


# --- Fixtures --------------------------------------------------------------

const KIND: StringName = DecisionKind.GOVERNOR_INTENT

var log: EventLog = null
var context: DeliberationContext = null


func before_each() -> void:
	Deliberation.reset()
	log = EventLog.new()
	context = DeliberationContext.new(KIND, WorldState.new(4, {}), log)


func after_each() -> void:
	Deliberation.reset()


func _candidates() -> Array:
	return [
		Candidate.new(&"fortify"),
		Candidate.new(&"plantation"),
	]


func _threat(fortify: float, plantation: float) -> FixedConsideration:
	return FixedConsideration.new(&"native_threat", {"fortify": fortify, "plantation": plantation})


func _revenue(fortify: float, plantation: float) -> FixedConsideration:
	return FixedConsideration.new(&"revenue", {"fortify": fortify, "plantation": plantation})


# --- Tests -----------------------------------------------------------------

func test_weights_change_the_choice() -> void:
	# The acceptance criterion: two contacts with different weights choose
	# differently from identical candidates and context. This is what
	# "personality drives behaviour, not merely prose" has to mean in code.
	Deliberation.register_consideration(_threat(0.6, -0.2), [KIND])
	Deliberation.register_consideration(_revenue(-0.3, 0.7), [KIND])

	var cautious := DeliberationActor.new(&"cautious", {"native_threat": 1.6, "revenue": 0.5})
	var greedy := DeliberationActor.new(&"greedy", {"native_threat": 0.5, "revenue": 1.6})

	assert_eq(Deliberation.choose(cautious, _candidates(), context).chosen_id(), &"fortify")
	assert_eq(Deliberation.choose(greedy, _candidates(), context).chosen_id(), &"plantation")


func test_no_bespoke_code_per_personality() -> void:
	# Both actors run the same considerations and the same kernel. The only
	# difference between them is data.
	Deliberation.register_consideration(_threat(0.6, -0.2), [KIND])
	var first := DeliberationActor.new(&"a", {"native_threat": 1.5})
	var second := DeliberationActor.new(&"b", {"native_threat": 0.1})
	assert_ne(
		Deliberation.choose(first, _candidates(), context).total_for(&"fortify"),
		Deliberation.choose(second, _candidates(), context).total_for(&"fortify"),
	)


func test_filter_removes_before_scoring() -> void:
	# A locked rule is a filter, never a weight that could lose a close vote.
	# SPEC §11.3's "needs before wants" is this: a town that cannot feed itself
	# has plantation-building removed from the set, not scored down.
	Deliberation.register_consideration(_revenue(-0.9, 0.9), [KIND])
	Deliberation.register_filter(BlockingFilter.new(&"needs_before_wants", PackedStringArray(["plantation"])), [KIND])

	var actor := DeliberationActor.new(&"governor", {})
	var decision := Deliberation.choose(actor, _candidates(), context)

	# Plantation scores far higher, and still loses, because it never ran.
	assert_eq(decision.chosen_id(), &"fortify")
	assert_true(decision.was_filtered(&"plantation"))
	assert_eq(decision.filtered_by(&"plantation"), &"needs_before_wants")


func test_trace_distinguishes_filtered_from_scored_low() -> void:
	# "He was never going to do that" and "he nearly did that" are different
	# facts about the same actor, and the trace has to keep them apart.
	Deliberation.register_consideration(_revenue(0.5, -0.9), [KIND])
	Deliberation.register_filter(BlockingFilter.new(&"locked", PackedStringArray(["plantation"])), [KIND])

	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)
	assert_eq(decision.total_for(&"plantation"), Decision.NO_SCORE, "a filtered candidate has no score at all")
	assert_false(decision.was_filtered(&"fortify"))


func test_trace_names_every_consideration_with_raw_weight_and_total() -> void:
	Deliberation.register_consideration(_threat(0.6, 0.0), [KIND])
	Deliberation.register_consideration(_revenue(-0.2, 0.0), [KIND])

	var actor := DeliberationActor.new(&"ashmere", {"native_threat": 1.4, "revenue": 1.0})
	var decision := Deliberation.choose(actor, _candidates(), context)

	var entry: Dictionary = decision.entries[0]
	assert_eq(entry["id"], "fortify")
	assert_almost_eq(entry["total"], 0.6 * 1.4 + -0.2 * 1.0)

	var scored: Array = entry["considerations"]
	assert_eq(scored.size(), 2)
	# Sorted by consideration id, so the trace and the sum do not depend on the
	# order systems happened to register in.
	assert_eq(scored[0]["id"], "native_threat")
	assert_almost_eq(scored[0]["raw"], 0.6)
	assert_almost_eq(scored[0]["weight"], 1.4)
	assert_almost_eq(scored[0]["weighted"], 0.84)
	assert_eq(scored[1]["id"], "revenue")


func test_trace_is_always_emitted() -> void:
	# Not optional: it feeds the balance harness, explains behaviour in playtest,
	# and gives letters their motive.
	Deliberation.register_consideration(_threat(0.6, -0.2), [KIND])
	Deliberation.choose(DeliberationActor.new(&"marshal", {}), _candidates(), context)

	var traces := log.of_type(Deliberation.TRACE_EVENT)
	assert_eq(traces.size(), 1)
	assert_eq(traces[0].subject, &"marshal")
	assert_eq(traces[0].payload["kind"], String(KIND))
	assert_eq(traces[0].payload["chosen"], "fortify")


func test_trace_payload_is_structured_not_prose() -> void:
	# Events carry structure; the words a player reads come from data files, per
	# language (SPEC §9.7).
	Deliberation.register_consideration(_threat(0.6, -0.2), [KIND])
	Deliberation.choose(DeliberationActor.new(&"marshal", {}), _candidates(), context)
	var payload := log.of_type(Deliberation.TRACE_EVENT)[0].payload
	assert_eq(typeof(payload["candidates"]), TYPE_ARRAY)
	assert_eq(typeof(payload["candidates"][0]), TYPE_DICTIONARY)


func test_adding_a_consideration_needs_no_kernel_change() -> void:
	# Registering a third consideration changes the outcome without touching the
	# kernel or either of the other two.
	Deliberation.register_consideration(_threat(0.2, 0.0), [KIND])
	var actor := DeliberationActor.new(&"g", {})
	assert_eq(Deliberation.choose(actor, _candidates(), context).chosen_id(), &"fortify")

	Deliberation.register_consideration(
		FixedConsideration.new(&"food_security", {"fortify": -0.5, "plantation": 0.4}), [KIND]
	)
	assert_eq(Deliberation.choose(actor, _candidates(), context).chosen_id(), &"plantation")


func test_considerations_are_scoped_to_their_decision_kinds() -> void:
	Deliberation.register_consideration(_threat(0.9, 0.0), [DecisionKind.ORDER_COMPLIANCE])
	var other := DeliberationContext.new(KIND, WorldState.new(0, {}), log)
	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), other)
	assert_empty(decision.entries[0]["considerations"], "a consideration must not leak across decision kinds")


func test_consideration_that_does_not_apply_is_absent_from_the_trace() -> void:
	# Distinct from scoring zero, which records that it looked and found nothing
	# to say.
	Deliberation.register_consideration(
		FixedConsideration.new(&"fortify_only", {"fortify": 0.5}, PackedStringArray(["fortify"])), [KIND]
	)
	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)
	assert_eq(decision.entries[0]["considerations"].size(), 1)
	assert_empty(decision.entries[1]["considerations"])


func test_out_of_range_scores_are_clamped() -> void:
	# Scores are normalised so considerations from different systems stay
	# comparable and no system can dominate by choosing a larger scale.
	Deliberation.register_consideration(OutOfRangeConsideration.new(&"runaway"), [KIND])
	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)
	assert_almost_eq(decision.total_for(&"fortify"), 1.0)


func test_unweighted_considerations_default_to_one() -> void:
	# Adding a consideration must not require revisiting every actor already in
	# the game.
	Deliberation.register_consideration(_threat(0.5, 0.0), [KIND])
	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)
	assert_almost_eq(decision.total_for(&"fortify"), 0.5)


func test_every_candidate_filtered_leaves_no_choice() -> void:
	Deliberation.register_filter(
		BlockingFilter.new(&"all", PackedStringArray(["fortify", "plantation"])), [KIND]
	)
	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)
	assert_false(decision.has_choice())
	assert_eq(decision.chosen_id(), &"")


func test_decisions_are_deterministic() -> void:
	Deliberation.register_consideration(_threat(0.6, -0.2), [KIND])
	Deliberation.register_consideration(_revenue(-0.3, 0.7), [KIND])
	var actor := DeliberationActor.new(&"g", {"native_threat": 1.2})
	var first := Deliberation.choose(actor, _candidates(), context)
	var second := Deliberation.choose(actor, _candidates(), context)
	assert_eq(first.to_dict(), second.to_dict())


func test_ties_break_without_consuming_rng() -> void:
	# A tie resolves on candidate id rather than a die roll, so it cannot shift
	# every later draw in the actor's stream.
	Deliberation.register_consideration(_threat(0.5, 0.5), [KIND])
	var streams := RngStreams.new(99)
	context.rng = streams.contact_stream("g")
	var state_before := streams.to_dict()

	var decision := Deliberation.choose(DeliberationActor.new(&"g", {}), _candidates(), context)

	assert_eq(decision.chosen_id(), &"fortify", "ties break on the lower candidate id")
	assert_eq(streams.to_dict(), state_before, "a tie must not consume from the stream")


# --- 🔒 A trade protest is not a deliberation -------------------------------

func test_nothing_can_register_a_consideration_against_a_trade_protest() -> void:
	# **It is a calculation, not a decision** (#131). No actor chooses it: a
	# score per town per resource is recomputed each month and crosses a
	# threshold, the same shape as rebellion in SPEC §12.3, which is a protest's
	# larger sibling.
	#
	# **It is the people's decision, not the governor's.** He is an input — his
	# loyalty and temperament colour his town's mood — but the refusal is the
	# town's. A declared kind is an invitation to register a weight against it,
	# so the kind is gone and `_append` rejects what it does not know.
	#
	# A governor who wants to hurt the Crown has his own route, and it is intent
	# (#128), not this.
	assert_false(DecisionKind.is_kind(&"trade_protest"),
		"trade_protest is a decision kind again, so a personality can weigh it")
	assert_empty(Deliberation.considerations_for(&"trade_protest"),
		"something registered a consideration against a trade protest")


func test_every_declared_kind_is_one_an_actor_actually_chooses() -> void:
	# The list is short on purpose. Each of these is a moment where somebody
	# weighs options and could have chosen otherwise; anything that is worked out
	# rather than decided does not belong here.
	var expected: Array[StringName] = [
		DecisionKind.GOVERNOR_INTENT,
		DecisionKind.ORDER_COMPLIANCE,
		DecisionKind.UNANSWERED,
		DecisionKind.DIRECTOR_URGENCY,
		DecisionKind.FACTION_POSTURE,
		# **Considered, and it belongs** (#221). A commander weighing attack,
		# hold, march, withdraw and disband is plainly a moment where somebody
		# could have chosen otherwise — and `commanders.md` §5 is explicit that
		# it must be one, because *refusing to attack is attack scoring below
		# retreat* and a branch here would be the "will he obey" check the
		# section forbids.
		#
		# ⚠️ `deliberation.md` §1 still lists six decision points and this is a
		# seventh. The doc is the PO's; the table wants a row.
		DecisionKind.COMMANDER_ORDERS,
	]
	assert_eq(DecisionKind.ALL.size(), expected.size(),
		"a decision kind was added or removed without this test being considered")
	for kind in expected:
		assert_true(DecisionKind.is_kind(kind), "%s is no longer a decision kind" % kind)
