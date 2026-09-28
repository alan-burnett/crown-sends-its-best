extends TestCase

## One principle per outcome, order by order (#449, `contacts.md` §3).
##
## 🔒 **Partial** carries out a share of the order's size: the pull of an urging,
## the steps of a rate, the months of an embargo; troops one strength less. An
## order with no size is carried out in full. 🔒 **Act alone** is what he would
## have done had the PC not written: for most orders that is carrying on as he
## was, for troops one strength less, and for the Diplomat the town he asked for.

const SEED: int = 4449

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.world.month = 20


func after_each() -> void:
	reset_world()
	content.free()


func _order(kind: StringName, to: StringName, params: Dictionary, tone: StringName = Tone.DUTIFUL) -> Order:
	var p := params.duplicate()
	p["to"] = String(to)
	var order := Order.new(kind, to, p, run.world.month)
	order.tone = tone
	return order


func _intent_for(order: Order, outcome: StringName) -> Intent:
	var intent := Intent.new(&"", StringName(order.kind), order.addressed_to, order.addressed_to, 1,
		order.params.duplicate())
	Compliance._shape(intent, order, outcome, run.world)
	return intent


# --- 🔒 Act alone ------------------------------------------------------------------------

func test_acting_alone_he_carries_on_as_he_was_but_for_troops_and_the_diplomat() -> void:
	var governor := run.colony.in_order()[0].governor_id
	for kind in [M1Registrations.ORDER_URGE_INTENT, M1Registrations.ORDER_URGE_COMPANY,
			M1Registrations.ORDER_SHIP_RESOURCE, M1Registrations.ORDER_EMBARGO,
			M1Registrations.ORDER_PREFER_SITE, M1Registrations.ORDER_DISSUADE_FOUNDING,
			M1Registrations.ORDER_ANSWER_THE_TRIBE, M1Registrations.ORDER_SET_TAX_RATE]:
		assert_true(Compliance.carries_on_as_he_was(_order(kind, governor, {})),
			"acting alone on %s did something of the PC's" % kind)
	var policy := _order(M1Registrations.ORDER_ENACT_POLICY, &"provost", {"effect": String(PolicyEffects.IMMIGRATION)})
	assert_true(Compliance.carries_on_as_he_was(policy), "a policy was enacted by a man acting alone")
	var troops := _order(M1Registrations.ORDER_ENACT_POLICY, CrownTroops.MARSHAL,
		{"effect": String(PolicyEffects.CROWN_TROOPS), "strength": String(CrownTroops.A_FORCE)})
	assert_false(Compliance.carries_on_as_he_was(troops), "the Marshal acting alone sent nothing")
	assert_false(Compliance.carries_on_as_he_was(
		_order(M1Registrations.ORDER_MOVE_DIPLOMAT, &"diplomat", {"town": "x"})),
		"the Diplomat acting alone stayed where he was")


func test_a_man_acting_alone_on_an_urging_has_nothing_to_carry_out() -> void:
	# Through the resolution itself: the answer is his, and there is no Intent of
	# the PC's for anything to execute.
	var urging := _order(M1Registrations.ORDER_URGE_INTENT, &"someone", {"intent": String(GovernorIntent.GO_TALL)})
	var alone: Dictionary = {}
	for loyalty in [0.0, 5.0, 10.0, 20.0]:
		for autonomy in [1.8, 3.0]:
			var man := Contact.new(&"someone", {"autonomy": autonomy, "loyalty": 1.0})
			man.relationship = Relationship.new(&"someone", loyalty)
			var result := Compliance.resolve(urging, man, run.intents, run.world, run.log, run.streams)
			if String(result["outcome"]) == String(Compliance.ACT_ALONE):
				alone = result
	assert_false(alone.is_empty(), "nobody acted alone to prove anything with")
	if not alone.is_empty():
		assert_true(alone["intent"] == null, "a man acting alone installed the PC's urging")


func test_troops_granted_in_part_or_alone_are_one_strength_less() -> void:
	var troops := _order(M1Registrations.ORDER_ENACT_POLICY, CrownTroops.MARSHAL,
		{"effect": String(PolicyEffects.CROWN_TROOPS), "strength": String(CrownTroops.A_FORCE)})
	for outcome in [Compliance.PARTIAL, Compliance.ACT_ALONE]:
		assert_eq(String(_intent_for(troops, outcome).data["strength"]), String(CrownTroops.A_GARRISON),
			"%s landed the force asked for" % outcome)
	assert_eq(String(_intent_for(troops, Compliance.COMPLY).data["strength"]), String(CrownTroops.A_FORCE))
	assert_eq(String(CrownTroops.one_less(CrownTroops.A_GARRISON)), String(CrownTroops.NONE))


func test_the_diplomat_acting_alone_goes_where_he_asked() -> void:
	var diplomat := run.contact(&"diplomat")
	if diplomat == null or run.colony.in_order().size() < 1:
		return
	var home: Town = run.colony.in_order()[0]
	var second := Town.new(&"second", "Second", home.at + Vector2i(6, 0))
	second.workers = 30_000
	run.colony.add(second)
	diplomat.town = home.display_name
	var asked_for := Diplomat.destination_for(home, run.colony)
	var elsewhere := home if asked_for != home else second
	var order := _order(M1Registrations.ORDER_MOVE_DIPLOMAT, &"diplomat", {"town": elsewhere.display_name})
	var intent := _intent_for(order, Compliance.ACT_ALONE)
	intent.target = &"diplomat"
	var executor := DiplomatMoveExecutor.new()
	executor.colony = run.colony
	executor.contacts = run.contacts
	executor.execute(intent, run.world, run.log)
	assert_true(asked_for == null or diplomat.town == asked_for.display_name,
		"acting alone, he went where the PC sent him rather than where he asked to go")


# --- 🔒 Partial ----------------------------------------------------------------------------

func test_a_partial_urging_lands_a_share_of_its_pull() -> void:
	var town: Town = run.colony.in_order()[0]
	var order := _order(M1Registrations.ORDER_URGE_INTENT, town.governor_id,
		{"intent": String(GovernorIntent.GO_TALL)})
	var intent := _intent_for(order, Compliance.PARTIAL)
	intent.source = town.governor_id
	assert_true(intent.share() < 1.0, "a partial urging carried its whole pull")
	var executor := UrgeIntentExecutor.new()
	executor.colony = run.colony
	executor.execute(intent, run.world, run.log)
	var whole := Urging.from_pc(GovernorIntent.GO_TALL, run.world.month, Tone.DUTIFUL).strength
	assert_almost_eq(town.urging_by().strength, whole * intent.share(), 0.0001)


func test_a_partial_rate_moves_a_share_of_the_way() -> void:
	var standing := TaxRates.rate_for(run.world, &"sugar")
	var order := _order(M1Registrations.ORDER_SET_TAX_RATE, &"steward",
		{"resource": "sugar", "rate": standing + 0.2})
	var intent := _intent_for(order, Compliance.PARTIAL)
	var share := Compliance.partial_share(order)
	assert_true(share < 1.0)
	assert_almost_eq(float(intent.data["rate"]), standing + 0.2 * share, 0.0001,
		"a partial answer set the rate the PC asked for")


func test_a_partial_embargo_is_a_share_of_its_months_and_a_lifting_is_in_full() -> void:
	var governor := run.colony.in_order()[0].governor_id
	var laid := _intent_for(_order(M1Registrations.ORDER_EMBARGO, governor, {"months": 12}), Compliance.PARTIAL)
	assert_true(int(laid.data["months"]) < 12 and int(laid.data["months"]) >= 1)
	var lifted := _intent_for(_order(M1Registrations.ORDER_EMBARGO, governor, {"months": 0}), Compliance.PARTIAL)
	assert_eq(int(lifted.data["months"]), 0, "a partial lifting lifted part of an embargo")
