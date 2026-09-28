extends TestCase

## An acknowledgement says what actually happened (#448, `contacts.md` §3;
## SPEC §9.1 🔒 letters match the simulation).
##
## 🔒 **A governor acknowledges**: his acknowledgement's sender is the role
## `governor`, resolved as every other trigger's is.
##
## 🔒 **The Marshal's thanks for a consignment follow goods sent**, never a
## refusal, a declined requisition, a promise to ship or a favour.

const SEED: int = 448

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false


func after_each() -> void:
	reset_world()
	content.free()


func _governor() -> Contact:
	return run.contact(run.colony.in_order()[0].governor_id)


func _acknowledged(kind: StringName, to: StringName, params: Dictionary, outcome: StringName) -> PackedStringArray:
	var order := Order.new(kind, to, params, run.world.month)
	order.id = &"order_448"
	var ids := PackedStringArray()
	for inbound in machine.director._acknowledgements(run, [{"order": order, "outcome": outcome}]):
		ids.append(inbound.letter_id)
	return ids


# --- 🔒 Governors acknowledge ------------------------------------------------------------------

func test_a_governor_acknowledges_every_outcome_of_an_urging() -> void:
	var governor := _governor()
	var expected := {
		Compliance.COMPLY: "governor.ack_complied",
		Compliance.DELAY: "governor.ack_delayed",
		Compliance.REFUSE: "governor.ack_refused",
		Compliance.ACT_ALONE: "governor.ack_acted_alone",
	}
	for outcome in expected:
		var ids := _acknowledged(M1Registrations.ORDER_URGE_INTENT, governor.id,
			{"to": String(governor.id), "intent": "go_tall"}, outcome)
		assert_true(ids.has(expected[outcome]),
			"a governor who answered '%s' sent no acknowledgement: %s" % [outcome, ids])


func test_a_governor_does_not_say_he_turned_his_town_when_nothing_was_turned() -> void:
	var governor := _governor()
	var ids := _acknowledged(M1Registrations.ORDER_REFUSE, governor.id,
		{"to": String(governor.id)}, Compliance.COMPLY)
	assert_false(ids.has("governor.ack_complied"), "a refusal was acknowledged as his town turned")


# --- 🔒 The Marshal's thanks follow goods ------------------------------------------------------

func test_goods_sent_from_stores_bring_his_thanks() -> void:
	var ids := _acknowledged(M1Registrations.ORDER_PROMISE_RESOURCE, &"marshal",
		{"to": "marshal", "resource": "iron", "amount": 200}, Compliance.COMPLY)
	assert_true(ids.has("marshal.ack_complied"), "goods sent to the Marshal went unthanked")


func test_an_answer_that_moves_no_goods_is_never_thanked_as_a_consignment() -> void:
	var nothing_moved := [
		[M1Registrations.ORDER_REFUSE, {"to": "marshal"}],
		[M1Registrations.ORDER_DECLINE_DEMAND, {"to": "marshal"}],
		[M1Registrations.ORDER_PROMISE_SHIPMENT, {"to": "marshal", "resource": "iron", "amount": 200, "months": 6}],
		[M1Registrations.ORDER_GRANT_FAVOR, {"to": "marshal", "favor": "a kindness"}],
	]
	for pair in nothing_moved:
		var ids := _acknowledged(pair[0], &"marshal", pair[1], Compliance.COMPLY)
		assert_false(ids.has("marshal.ack_complied"),
			"'%s' brought the Marshal's thanks for a consignment" % pair[0])


# --- 🔒 And what they say is what happened (#449) ------------------------------------

func _acks(order: Order, outcome: StringName) -> Array:
	order.id = &"order_449"
	return machine.director._acknowledgements(run, [{"order": order, "outcome": outcome}])


func test_what_each_acknowledgement_says_is_what_happened() -> void:
	var governor := _governor()
	var town: Town = run.colony.in_order()[0]
	# **The intent urged, never the one his town holds.**
	var urged := GovernorIntent.GO_TALL if town.intent != GovernorIntent.GO_TALL else GovernorIntent.GO_WIDE
	var urging := Order.new(M1Registrations.ORDER_URGE_INTENT, governor.id,
		{"to": String(governor.id), "intent": String(urged)}, run.world.month)
	for inbound in _acks(urging, Compliance.COMPLY):
		assert_eq(String(inbound.params.get("what", "")), Objective.intent_name(urged),
			"he acknowledged an urging by naming what his town already does")
	# **A delay names when it lands.**
	var delayed := _acks(urging, Compliance.DELAY)
	assert_eq(delayed.size(), 1)
	for inbound in delayed:
		assert_eq(int(inbound.params.get("months", 0)), Compliance.DELAY_MONTHS + 1,
			"a delay did not say when")
	# **A partial answer names the share.**
	var tax := Order.new(M1Registrations.ORDER_SET_TAX_RATE, &"steward",
		{"to": "steward", "resource": "sugar", "rate": 0.3}, run.world.month)
	tax.tone = Tone.DUTIFUL
	var partly := _acks(tax, Compliance.PARTIAL)
	assert_eq(partly.size(), 1, "a tax rate carried out in part went unacknowledged")
	for inbound in partly:
		assert_eq(int(inbound.params.get("share", -1)), int(roundf(Compliance.partial_share(tax) * 100.0)))
	# **Troops in part, or alone, are one strength less, and he says so.**
	var troops := Order.new(M1Registrations.ORDER_ENACT_POLICY, CrownTroops.MARSHAL, {
		"to": String(CrownTroops.MARSHAL), "effect": String(PolicyEffects.CROWN_TROOPS),
		"strength": String(CrownTroops.A_FORCE),
	}, run.world.month)
	for outcome in [Compliance.PARTIAL, Compliance.ACT_ALONE]:
		assert_eq(_acks(troops, outcome).size(), 1, "the Marshal sent fewer men and said nothing (%s)" % outcome)
