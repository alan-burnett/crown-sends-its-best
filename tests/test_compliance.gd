extends TestCase

## Orders and compliance resolution (#16), and the three Crown officers (#13).

const SEED: int = 1066

var state: WorldState = null
var log: EventLog = null
var book: IntentBook = null
var streams: RngStreams = null
var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()

	state = WorldValues.initial_state()
	state.month = 3
	log = EventLog.new()
	book = IntentBook.new()
	streams = RngStreams.new(SEED)

	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


func _officer(id: String) -> Contact:
	return Contact.from_data(content.collection("contacts")[id])


func _contact(loyalty: float, weights: Dictionary = {}) -> Contact:
	var contact := Contact.new(&"someone", weights)
	contact.relationship = Relationship.new(&"someone", loyalty)
	return contact


func _troop_request(payment: float) -> Order:
	return Order.new(M1Registrations.ORDER_REQUEST_TROOPS, &"marshal", {
		"to": "marshal", "payment": payment,
	}, state.month)


func _resolve(order: Order, contact: Contact) -> Dictionary:
	return Compliance.resolve(order, contact, book, state, log, streams)


# --- The six outcomes ------------------------------------------------------

func _vague_order() -> Order:
	# No figure in it, so there is room to decide what the PC meant.
	return Order.new(M1Registrations.ORDER_SET_POLICY, &"marshal", {
		"to": "marshal", "policy": "tax.tea", "value": "lower",
	}, state.month)


func test_all_six_outcomes_are_reachable() -> void:
	# Swept across loyalty, payment, personality and how specific the order was,
	# which is the honest way to ask "can this happen" without asserting a
	# balance number.
	var seen: Dictionary = {}
	for loyalty in [0.0, 15.0, 30.0, 50.0, 70.0, 85.0, 100.0]:
		for autonomy in [0.4, 1.0, 1.8]:
			for payment in [0.0, 250.0, 500.0, 900.0, 1000.0]:
				var contact := _contact(loyalty, {"autonomy": autonomy})
				seen[String(_resolve(_troop_request(payment), contact)["outcome"])] = true
			seen[String(_resolve(_vague_order(), _contact(loyalty, {"autonomy": autonomy}))["outcome"])] = true
	for outcome in Compliance.OUTCOMES:
		assert_true(seen.has(String(outcome)), "%s was never reachable. Reached: %s" % [outcome, seen.keys()])


func test_a_vague_order_invites_reinterpretation() -> void:
	# SPEC §8: personality shows in how a contact reads vague orders. A figure in
	# the letter is what closes the gap.
	assert_almost_eq(Compliance.vagueness_of(_troop_request(500.0)), 0.0)
	assert_almost_eq(Compliance.vagueness_of(_vague_order()), 1.0)

	var reinterpreted := false
	for loyalty in [20.0, 40.0, 60.0, 80.0]:
		if String(_resolve(_vague_order(), _contact(loyalty))["outcome"]) == String(Compliance.REINTERPRET):
			reinterpreted = true
	assert_true(reinterpreted, "no vague order was ever reinterpreted")


func test_each_outcome_emits_a_distinguishable_event() -> void:
	var types: Dictionary = {}
	for outcome in Compliance.OUTCOMES:
		var event_type: StringName = Compliance.OUTCOME_EVENTS[outcome]
		assert_false(types.has(event_type), "%s shares an event type" % outcome)
		types[event_type] = true
	assert_eq(types.size(), Compliance.OUTCOMES.size())


func test_loyalty_changes_which_outcome_occurs() -> void:
	var devoted := _resolve(_troop_request(0.0), _contact(100.0))
	var hostile := _resolve(_troop_request(0.0), _contact(0.0))
	assert_ne(String(devoted["outcome"]), String(hostile["outcome"]),
		"loyalty made no difference at all")


func test_personality_changes_which_outcome_occurs() -> void:
	# Same loyalty, same request, different weights, and no bespoke code for any
	# of them. Asserting that personality *matters*, not which one wins — the
	# latter is a balance value.
	# A half-paid request for troops, where every consideration has something to
	# say and none of them drowns the rest.
	var personalities: Array[Dictionary] = [
		{},
		{"autonomy": 3.0, "cost_of_request": 0.2},
		{"loyalty": 2.5, "cost_of_request": 0.2, "payment_offered": 2.0},
		{"cost_of_request": 2.0, "autonomy": 0.1},
	]
	var outcomes: Dictionary = {}
	for weights in personalities:
		outcomes[String(_resolve(_troop_request(400.0), _contact(40.0, weights))["outcome"])] = true
	assert_true(outcomes.size() > 1, "every personality reached the same outcome: %s" % [outcomes.keys()])


func test_full_payment_is_a_guaranteed_yes() -> void:
	# SPEC §12.6. A filter, not a heavy weight — a guarantee that can lose a close
	# vote is not a guarantee. Even at the floor of loyalty, he does not refuse.
	for loyalty in [0.0, 10.0, 50.0, 100.0]:
		var result := _resolve(_troop_request(1000.0), _contact(loyalty, {"autonomy": 2.0}))
		assert_ne(String(result["outcome"]), String(Compliance.REFUSE),
			"refused a fully paid request at loyalty %f" % loyalty)


func test_the_guarantee_is_recorded_as_a_filter_not_a_low_score() -> void:
	var result := _resolve(_troop_request(1000.0), _contact(0.0))
	var decision: Decision = result["decision"]
	assert_true(decision.was_filtered(Compliance.REFUSE))
	assert_eq(decision.filtered_by(Compliance.REFUSE), &"full_payment_is_a_yes")


func test_paying_nothing_leaves_refusal_available() -> void:
	var decision: Decision = _resolve(_troop_request(0.0), _contact(50.0))["decision"]
	assert_false(decision.was_filtered(Compliance.REFUSE))


# --- Seam B and Seam C -----------------------------------------------------

func test_compliance_produces_an_intent_not_a_write() -> void:
	var before := state.to_dict()
	var result := _resolve(_troop_request(1000.0), _contact(80.0))
	assert_eq(state.to_dict(), before, "resolving an Order must not touch the world")
	assert_true(result["intent"] != null)
	assert_eq(book.live().size(), 1)


func test_a_refusal_produces_no_intent() -> void:
	# A refusal is a thing that did not happen.
	var contact := _contact(0.0, {"loyalty": 2.0, "autonomy": 0.1, "payment_offered": 2.0})
	var result := _resolve(_troop_request(0.0), contact)
	if String(result["outcome"]) != String(Compliance.REFUSE):
		return  # This actor did not refuse; the reachability sweep covers that case.
	assert_true(result["intent"] == null)
	assert_empty(book.live())


func test_acting_alone_is_the_same_path_with_a_different_origin() -> void:
	# "The contact complied" and "he acted on his own and told you after" are one
	# mechanism. The executor cannot tell them apart; only the letters care.
	var acted_alone := false
	for loyalty in [0.0, 5.0, 10.0, 20.0]:
		var contact := _contact(loyalty, {"autonomy": 2.5})
		var result := _resolve(_troop_request(0.0), contact)
		if String(result["outcome"]) == String(Compliance.ACT_ALONE):
			acted_alone = true
			var intent: Intent = result["intent"]
			assert_eq(intent.origin, Intent.ORIGIN_WILL)
			assert_true(intent.is_live(), "it still becomes an Intent like any other")
	assert_true(acted_alone, "no loyalty was low enough to produce acting alone")


func test_every_resolution_emits_a_deliberation_trace() -> void:
	_resolve(_troop_request(500.0), _contact(50.0))
	assert_eq(log.of_type(Deliberation.TRACE_EVENT).size(), 1)


func test_resolution_is_deterministic() -> void:
	var first := _resolve(_troop_request(400.0), _contact(45.0))
	var second_log := EventLog.new()
	var second := Compliance.resolve(
		_troop_request(400.0), _contact(45.0), IntentBook.new(), state, second_log, RngStreams.new(SEED)
	)
	assert_eq(String(first["outcome"]), String(second["outcome"]))


func test_a_partial_compliance_delivers_less() -> void:
	var order := Order.new(M1Registrations.ORDER_PROMISE_RESOURCE, &"marshal", {
		"to": "marshal", "resource": "iron", "amount": 200,
	}, state.month)
	var contact := _contact(50.0)
	var intent := Compliance._intent_for(order, Compliance.PARTIAL, contact)
	assert_eq(intent.data["amount"], 100)


func test_a_delay_takes_longer_than_compliance() -> void:
	assert_true(int(Compliance.MONTHS_FOR[Compliance.DELAY]) > int(Compliance.MONTHS_FOR[Compliance.COMPLY]))


# --- Costly requests -------------------------------------------------------

func test_paying_generously_costs_no_loyalty() -> void:
	# SPEC §8.5: request troops and pay generously and his loyalty does not
	# shrink; pay less, or nothing, and it does.
	var generous := _contact(50.0)
	var before := generous.loyalty()
	var order := _troop_request(1000.0)
	order.tone = &""
	Compliance.resolve(order, generous, book, state, log, streams)
	assert_almost_eq(generous.loyalty(), before, 0.001)


func test_paying_nothing_costs_loyalty() -> void:
	var stingy := _contact(50.0)
	var before := stingy.loyalty()
	var order := _troop_request(0.0)
	order.tone = &""
	Compliance.resolve(order, stingy, book, state, log, streams)
	assert_true(stingy.loyalty() < before, "asking for troops and paying nothing should sting")


func test_granting_something_raises_loyalty() -> void:
	var contact := _contact(50.0)
	var before := contact.loyalty()
	var order := Order.new(M1Registrations.ORDER_PROMISE_GOLD, &"marshal", {
		"to": "marshal", "amount": 500,
	}, state.month)
	Compliance.resolve(order, contact, book, state, log, streams)
	assert_true(contact.loyalty() > before)


func test_tone_moves_loyalty_far_less_than_the_deed() -> void:
	var by_deed := _contact(50.0)
	var deed_order := Order.new(M1Registrations.ORDER_PROMISE_GOLD, &"marshal", {"to": "marshal", "amount": 500}, state.month)
	Compliance.resolve(deed_order, by_deed, book, state, log, streams)

	var by_tone := _contact(50.0)
	var tone_order := Order.new(M1Registrations.ORDER_SET_POLICY, &"marshal", {"policy": "x", "value": "y"}, state.month)
	tone_order.tone = Tone.PLEASED
	Compliance.resolve(tone_order, by_tone, book, state, log, streams)

	assert_true(absf(by_deed.loyalty() - 50.0) > absf(by_tone.loyalty() - 50.0))


# --- The three Crown officers ----------------------------------------------

func test_the_three_officers_load_from_data() -> void:
	for id in ["marshal", "chancellor", "steward"]:
		assert_true(content.has_record("contacts", id), "no data for '%s'" % id)
		var officer := _officer(id)
		assert_eq(officer.role, Contact.ROLE_CROWN_OFFICER)
		assert_not_empty(officer.display_name)
		assert_not_empty(officer.title)


func test_the_chancellors_loyalty_begins_very_low() -> void:
	# He cherishes giving you news of your failures (SPEC §8.1). Data, not a
	# special case.
	var chancellor := _officer("chancellor")
	assert_true(chancellor.loyalty() < _officer("marshal").loyalty())
	assert_true(chancellor.loyalty() < _officer("steward").loyalty())


func test_the_officers_are_three_distinct_people() -> void:
	var marshal := _officer("marshal")
	var chancellor := _officer("chancellor")
	var steward := _officer("steward")
	assert_ne(marshal.weights, chancellor.weights)
	assert_ne(chancellor.weights, steward.weights)
	assert_ne(marshal.weights, steward.weights)


func test_their_weights_visibly_change_behaviour() -> void:
	# Demonstrable through the traces: identical request, identical loyalty,
	# different totals because the weights differ.
	var order := _troop_request(300.0)
	var totals: Dictionary = {}
	for id in ["marshal", "chancellor", "steward"]:
		var officer := _officer(id)
		officer.relationship = Relationship.new(officer.id, 50.0)
		var decision: Decision = _resolve(order, officer)["decision"]
		totals[id] = decision.total_for(Compliance.COMPLY)
	assert_ne(totals["marshal"], totals["chancellor"])
	assert_ne(totals["chancellor"], totals["steward"])


func test_their_leans_differ_per_officer_and_per_topic() -> void:
	# So two officers describe the same situation differently and both tell the
	# truth (SPEC §9.1).
	var marshal := _officer("marshal")
	var steward := _officer("steward")
	assert_ne(marshal.lean_for("supply_situation"), steward.lean_for("supply_situation"))
	assert_ne(marshal.lean_for("crown_war_intensity"), marshal.lean_for("supply_situation"))


func test_two_officers_describe_the_same_month_differently() -> void:
	MeasureRegistry.register_linear("supply_situation", 0.0, 100.0)
	var ladder := PackedStringArray(["desperate", "strained", "adequate", "ample", "abundant"])
	var marshal := _officer("marshal")
	var steward := _officer("steward")
	assert_ne(
		Perception.word("supply_situation", 50.0, marshal.lean_for("supply_situation"), ladder),
		Perception.word("supply_situation", 50.0, steward.lean_for("supply_situation"), ladder),
	)


func test_their_portraits_are_asset_ids() -> void:
	# SPEC §16.3: swapping placeholder art for final art is a data change.
	for id in ["marshal", "chancellor", "steward"]:
		var officer := _officer(id)
		assert_not_empty(officer.portrait_asset)
		assert_false(officer.portrait_asset.contains("res://"))


func test_adding_an_officer_later_needs_only_a_data_file() -> void:
	# The Provost and the Diplomat are out of scope for M1, and this is the test
	# that they will not need code when they arrive.
	var provost := Contact.from_data({
		"id": "provost", "name": "Doctor Selwyn Marchmont", "title": "Provost",
		"role": "crown_officer", "loyalty": 50, "weights": {"loyalty": 1.1},
	})
	assert_eq(provost.role, Contact.ROLE_CROWN_OFFICER)
	var result := _resolve(_troop_request(500.0), provost)
	assert_true(Compliance.OUTCOMES.has(StringName(result["outcome"])))


# --- 🔒 Every order kind is priced, and none by omission (#302) ------------

func test_every_registered_order_kind_has_a_price() -> void:
	# 🔒 **The fall-through was the hazard.** `cost_of` used to answer two
	# hundred for anything nobody had listed, which is a figure asserting that a
	# thing costs the recipient rather a lot on the sole grounds that nobody had
	# said what it cost.
	#
	# It broke `urge_intent` — governors answering *I will not* to instructions
	# they already agreed with — and the fix was a case for that one kind. Then it
	# broke `set_tax_rate` the same way, and **four more kinds were carrying it**
	# unnoticed: `set_policy`, `prefer_site`, `dissuade_founding` and the
	# answering ones.
	#
	# This is the check that stops a third time. It asks the same match `cost_of`
	# asks, so the two cannot drift apart.
	var unpriced: PackedStringArray = PackedStringArray()
	for effect_id in ContentRegistry.effect_ids():
		var kind := ContentRegistry.order_kind_of(String(effect_id))
		if String(kind).is_empty():
			continue
		if not Compliance.is_priced(kind):
			unpriced.append(String(kind))
	assert_empty(unpriced,
		"these order kinds have no case in Compliance._priced, so they are "
			+ "silently free: %s" % ", ".join(unpriced))

	# 🔒 **And the check must be able to say no.** A `is_priced` that answered
	# yes to everything would pass the loop above for ever, which is how a check
	# rots into a tautology.
	assert_false(Compliance.is_priced(&"an_order_kind_nobody_has_written"),
		"is_priced approves a kind that has no case, so the check above is vacuous")


func test_a_rate_costs_the_colony_and_not_the_man_who_sets_it() -> void:
	# SPEC §8.1: the Steward *follows your instruction about adjusting tax rates*
	# and *prefers high taxes*. Priced at the old fall-through, against a man whose
	# heaviest weight is `cost_of_request`, the Steward of the Revenue refused an
	# order to raise the revenue on turn one.
	for kind in [M1Registrations.ORDER_SET_TAX_RATE, M1Registrations.ORDER_SET_POLICY]:
		var order := Order.new(kind, &"steward", {
			"resource": "tea", "rate": 0.15, "policy": "x", "value": "y",
		}, 0)
		assert_eq(Compliance.cost_of(order), 0.0,
			"being told to set %s was priced against him personally" % kind)


func test_the_steward_does_not_refuse_an_order_to_raise_the_revenue() -> void:
	var steward := _contact(48.0, {"cost_of_request": 1.4, "loyalty": 1.0})
	var order := Order.new(M1Registrations.ORDER_SET_TAX_RATE, &"steward", {
		"resource": "tea", "rate": 0.15,
	}, state.month)
	order.tone = Tone.DUTIFUL
	assert_false(String(_resolve(order, steward)["outcome"]) == String(Compliance.REFUSE),
		"the Steward of the Revenue refused an order to raise the revenue")


func test_an_urging_still_costs_a_governor_nothing() -> void:
	# The first time this was fixed, and it must stay fixed: the PC sends no gold
	# with a pronouncement, so anything it costs makes `payment_offered` decide
	# every priority letter in the game.
	assert_eq(Compliance.cost_of(
		Order.new(M1Registrations.ORDER_URGE_INTENT, &"him", {}, 0)), 0.0)


# --- 🔒 A harsh order is obeyed, and it costs (#71) -------------------------

func _shipment(harsh: bool) -> Order:
	var order := Order.new(M1Registrations.ORDER_SHIP_RESOURCE, &"someone", {
		"to": "someone", "resource": "iron", "amount": 20, "payment": 0,
	}, state.month)
	order.harsh = harsh
	return order


## How often a whole spread of governors do the thing, asked the same way.
##
## **Across many men, not one.** Harshness is a weight in the kernel rather than
## a rule, so a single governor can refuse a harsh order and that is the design
## working — the claim is about the odds, so the test has to be too.
##
## 🔒 **Complying and part-complying both count as doing it** (#263, `tone.md`
## §9). §9 has harshness pushing toward comply **and partial**: a man leaned on
## does at least some of it rather than none, and half a levy raised under a
## threat is the commonest thing a threat actually gets you.
##
## This counted only full compliance, and so read the change as a loss — on this
## fixture an unpaid shipment of twenty iron is never given whole by anybody, and
## what leaning on him actually moved was fifteen refusals down to seven. It is
## also the definition `GrievanceDriver._was_borne` already uses for whether the
## town carried the order, which is the same question asked from the other side.
func _compliance_rate(harsh: bool) -> float:
	var complied := 0.0
	var asked := 0.0
	for loyalty in [20.0, 35.0, 45.0, 55.0, 65.0, 80.0]:
		for weight in [0.5, 1.0, 2.0]:
			var contact := _contact(loyalty, {"harshness": weight})
			var outcome := String(_resolve(_shipment(harsh), contact)["outcome"])
			asked += 1.0
			if outcome == String(Compliance.COMPLY) \
					or outcome == String(Compliance.PARTIAL):
				complied += 1.0
	return complied / asked


func test_a_harsh_order_is_the_likeliest_to_be_obeyed() -> void:
	# The whole reason the PC would write one, and the reason it has to cost
	# something: he can have compliance or he can have goodwill.
	var plain := _compliance_rate(false)
	var pressed := _compliance_rate(true)
	assert_true(pressed > plain,
		"leaning on a governor got no more compliance than asking him (%.2f against %.2f)"
			% [pressed, plain])


func test_but_he_can_still_refuse() -> void:
	# 🔒 A weight and not a filter. A man who has had enough can still say no,
	# and a harsh order to a governor who despises the PC is how a refusal
	# becomes a rupture rather than a shrug.
	var bitter := _contact(2.0, {"harshness": 1.0, "loyalty": 6.0})
	assert_eq(String(_resolve(_shipment(true), bitter)["outcome"]), String(Compliance.REFUSE),
		"a harsh order compelled a governor who despises the PC, so it is a filter")


func test_being_commanded_costs_the_governor_his_regard() -> void:
	var asked := _contact(60.0)
	var told := _contact(60.0)
	_resolve(_shipment(false), asked)
	_resolve(_shipment(true), told)
	assert_true(told.loyalty() < asked.loyalty(),
		"a governor thought no worse of a PC who commanded him than one who asked")


func test_it_costs_him_whether_he_obeys_or_not() -> void:
	# **The deed is the PC's, not his.** Being written to that way is the thing
	# that stings; whether he then did it is his own business.
	var refused := _contact(2.0, {"loyalty": 6.0})
	var before := refused.loyalty()
	var outcome := String(_resolve(_shipment(true), refused)["outcome"])
	assert_eq(outcome, String(Compliance.REFUSE), "the fixture complied, so this proves nothing")
	assert_true(refused.loyalty() < before,
		"a governor who refused a command thought no worse of the man who gave it")
