extends TestCase

## Compliance can tell an agreeable order from an unwelcome one (#213,
## `contacts.md` §3, SPEC §8.5).
##
## 🔒 **It changes the manner of his answer and never the decision.** Compliance
## decides whether he engages with the letter; his phase 8 deliberation decides
## whether he agrees with it. Collapsing the two would put the PC's letter and
## the governor's judgement in one scoring pass, and the argument would stop
## being an argument.
##
## 🔒 **It does not pull toward refusing.** Refusing is about regard — a man who
## disagrees but likes the PC finds a way to do both, and the way he finds is
## reinterpretation.

const SEED: int = 2255

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _town(intent: StringName) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 20
	town.governor_id = &"governor_ashmere"
	town.intent = intent
	return town


func _urging(intent: StringName) -> Order:
	return Order.new(
		M1Registrations.ORDER_URGE_INTENT,
		&"governor_ashmere",
		{"to": "governor_ashmere", "intent": String(intent)},
	)


# --- 🔒 Distance comes off the profile table -------------------------------

func test_an_intent_is_no_distance_from_itself() -> void:
	for intent in GovernorIntent.IN_ORDER:
		assert_almost_eq(GovernorIntent.distance_between(intent, intent), 0.0, 0.0001,
			"'%s' disagrees with itself" % intent)


func test_opposites_are_further_apart_than_neighbours() -> void:
	# Read off the table and nothing else, so "settling and surviving want
	# opposite things" falls out of the numbers rather than being written down
	# where a later edit could contradict it.
	var opposed := GovernorIntent.distance_between(
		GovernorIntent.SETTLEMENT, GovernorIntent.SURVIVAL)
	var adjacent := GovernorIntent.distance_between(
		GovernorIntent.ECONOMY, GovernorIntent.POPULATION)
	assert_true(opposed > adjacent,
		"settling and surviving are no further apart than trading and growing")
	assert_true(opposed <= 1.0 and adjacent >= 0.0, "the figure left nought to one")


func test_an_unknown_intent_is_no_distance_at_all() -> void:
	assert_almost_eq(
		GovernorIntent.distance_between(&"", GovernorIntent.ECONOMY), 0.0, 0.0001)
	assert_almost_eq(
		GovernorIntent.distance_between(&"nonsense", GovernorIntent.ECONOMY), 0.0, 0.0001,
		"an intent nobody has heard of read as a disagreement")


# --- 🔒 Zero where nothing applies ------------------------------------------

func test_it_is_silent_on_order_kinds_it_cannot_read() -> void:
	# Exactly as harshness is zero for a mild letter. An order kind with no
	# answer to "against his judgement" must not crash and must not invent one.
	var town := _town(GovernorIntent.DEFENCE)
	for kind in [
		M1Registrations.ORDER_PROMISE_GOLD,
		M1Registrations.ORDER_EMBARGO,
		M1Registrations.ORDER_SHIP_RESOURCE,
		M1Registrations.ORDER_SET_TAX_RATE,
	]:
		var order := Order.new(kind, &"governor_ashmere", {"to": "governor_ashmere"})
		assert_almost_eq(Compliance.dissonance_of(order, town), 0.0, 0.0001,
			"'%s' was read as cutting against his judgement" % kind)


func test_it_is_silent_when_there_is_no_town_to_disagree() -> void:
	assert_almost_eq(
		Compliance.dissonance_of(_urging(GovernorIntent.ECONOMY), null), 0.0, 0.0001,
		"a Crown officer with no town held an opinion about his town's intent")


func test_urging_a_man_toward_what_he_already_wants_is_no_dissonance() -> void:
	var town := _town(GovernorIntent.DEFENCE)
	assert_almost_eq(
		Compliance.dissonance_of(_urging(GovernorIntent.DEFENCE), town), 0.0, 0.0001,
		"a governor minded telling being told to do what he was already doing")


func test_urging_a_man_against_himself_is_dissonance() -> void:
	var town := _town(GovernorIntent.SURVIVAL)
	assert_true(Compliance.dissonance_of(_urging(GovernorIntent.SETTLEMENT), town) > 0.0,
		"a starving town told to found another one saw nothing to object to")


# --- 🔒 It changes the manner, and never toward refusing --------------------

func test_it_pulls_toward_reinterpreting_and_away_from_complying() -> void:
	# **The letter this exists to make reachable**: *I have read Your Grace's
	# instruction regarding our profits, and have applied it to the timber we
	# shall need for the palisade.*
	var consideration := ComplianceConsiderations.DissonanceConsideration.new(&"x")
	var pull: Dictionary = ComplianceConsiderations.DissonanceConsideration.PULL
	assert_true(float(pull[Compliance.REINTERPRET]) > 0.0)
	assert_true(float(pull[Compliance.ACT_ALONE]) > 0.0)
	assert_true(float(pull[Compliance.COMPLY]) < 0.0)
	assert_true(float(pull[Compliance.DELAY]) > 0.0
			and float(pull[Compliance.DELAY]) < float(pull[Compliance.REINTERPRET]),
		"delay should be pulled mildly, not as strongly as reinterpreting")
	assert_false(consideration.applies_to(_candidate(Compliance.REFUSE)),
		"disagreement pulled toward refusing, which is about regard and not about being right")


func test_two_governors_alike_but_for_their_situation_answer_differently() -> void:
	# 🔒 The acceptance, and the whole point: **in manner, not merely in
	# outcome.** The same man, the same letter, two towns.
	var contented := _resolve(GovernorIntent.ECONOMY, GovernorIntent.ECONOMY)
	var affronted := _resolve(GovernorIntent.ECONOMY, GovernorIntent.SURVIVAL)

	assert_true(_scored(affronted, Compliance.REINTERPRET)
			> _scored(contented, Compliance.REINTERPRET),
		"a governor told to chase profit while his town starves read the letter as plainly as one who agreed with it")
	assert_true(_scored(affronted, Compliance.COMPLY) < _scored(contented, Compliance.COMPLY),
		"disagreeing made him no less likely to simply do as he was told")


func test_a_contented_governor_still_complies_plainly() -> void:
	# The other half. A consideration that made everybody evasive would have
	# replaced one flat answer with another.
	var contented := _resolve(GovernorIntent.ECONOMY, GovernorIntent.ECONOMY)
	assert_almost_eq(
		_scored(contented, Compliance.REINTERPRET), 0.0, 0.0001,
		"a governor urged toward what he already wanted found something to read into it")


func test_the_trace_names_it_in_a_real_deliberation() -> void:
	# 🔒 `choose()` always emits its scoring trace (`CLAUDE.md`), and here it is
	# load-bearing: the letter has to be able to say **why** he read the order as
	# he did, and a nameless term in a sum cannot tell it.
	#
	# Run through `Compliance.resolve` rather than by scoring the consideration
	# by hand, because that also proves the thing is **wired** — a consideration
	# registered and never reached is the failure this ticket is about.
	var run := _resolved_for_real(GovernorIntent.ECONOMY, GovernorIntent.SURVIVAL)
	var traces: Array = run["log"].of_type(Deliberation.TRACE_EVENT)
	assert_not_empty(traces, "nobody deliberated at all")

	var named := false
	for trace in traces:
		for candidate in trace.payload.get("candidates", []):
			for row in candidate.get("considerations", []):
				if String(row.get("id", "")) == "against_his_judgement":
					named = true
	assert_true(named,
		"the trace does not say the order cut against him, so no letter can say why")


func test_it_is_reached_in_a_real_deliberation_and_moves_the_scores() -> void:
	# The inert-machinery check. A consideration that scores zero everywhere is a
	# consideration nobody would notice was never called.
	var affronted := _weight_of(_resolved_for_real(
		GovernorIntent.ECONOMY, GovernorIntent.SURVIVAL), "against_his_judgement")
	var contented := _weight_of(_resolved_for_real(
		GovernorIntent.ECONOMY, GovernorIntent.ECONOMY), "against_his_judgement")
	assert_true(affronted > 0.0,
		"the consideration was registered and scored nothing in a real disagreement")
	assert_almost_eq(contented, 0.0, 0.0001,
		"it scored against a governor who was urged toward what he already wanted")


# --- Fixture -----------------------------------------------------------------

func _candidate(id: StringName) -> Candidate:
	var candidate := Candidate.new()
	candidate.id = id
	return candidate


## Score one governor's compliance, and hand back the trace.
func _resolve(urged: StringName, holds: StringName) -> Dictionary:
	var town := _town(holds)
	var contact := Contact.new(&"governor_ashmere")
	contact.role = Contact.ROLE_GOVERNOR
	contact.relationship.loyalty = 60.0

	var context := DeliberationContext.new(
		DecisionKind.ORDER_COMPLIANCE, WorldValues.initial_state(), EventLog.new())
	context.rng = RngStreams.new(SEED).contact_stream("governor_ashmere")
	var order := _urging(urged)
	context.data = {
		"order": order,
		"cost": 0.0,
		"payment": 0.0,
		"loyalty": contact.loyalty(),
		"vagueness": Compliance.vagueness_of(order),
		"harsh": false,
		"dissonance": Compliance.dissonance_of(order, town),
	}

	var consideration := ComplianceConsiderations.DissonanceConsideration.new(
		&"against_his_judgement")
	var scores: Dictionary = {}
	var trace: Array = []
	for id in Compliance.OUTCOMES:
		var candidate := _candidate(id)
		var score := 0.0
		if consideration.applies_to(candidate):
			score = consideration.score(null, candidate, context)
			trace.append({"consideration": "against_his_judgement", "candidate": String(id)})
		scores[String(id)] = score
	return {"scores": scores, "trace": trace}


func _scored(resolved: Dictionary, outcome: StringName) -> float:
	return float(resolved["scores"].get(String(outcome), 0.0))


## Put a real order in front of a real governor, through the real kernel.
func _resolved_for_real(urged: StringName, holds: StringName) -> Dictionary:
	var town := _town(holds)
	var contact := Contact.new(&"governor_ashmere")
	contact.role = Contact.ROLE_GOVERNOR
	contact.relationship.loyalty = 60.0

	var log := EventLog.new()
	var outcome := Compliance.resolve(
		_urging(urged), contact, IntentBook.new(),
		WorldValues.initial_state(), log, RngStreams.new(SEED), town)
	return {"log": log, "outcome": outcome}


## The largest absolute weight one consideration reached anywhere in the trace.
func _weight_of(run: Dictionary, id: String) -> float:
	var most := 0.0
	for trace in run["log"].of_type(Deliberation.TRACE_EVENT):
		for candidate in trace.payload.get("candidates", []):
			for row in candidate.get("considerations", []):
				if String(row.get("id", "")) == id:
					most = maxf(most, absf(float(row.get("weighted", row.get("score", 0.0)))))
	return most
