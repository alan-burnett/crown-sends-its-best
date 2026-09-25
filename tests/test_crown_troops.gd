extends TestCase

## The Marshal's troops (#420, `the-marshal.md` §2, §3, §6; `policy.md` §5).
##
## 🔒 A standing troops policy puts Crown companies in the colony, victualled by
## the Crown; when it lapses the Marshal has written first, and then they sail,
## in one event naming how many went.

const SEED: int = 420

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


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _enact(
	strength: StringName = CrownTroops.A_FORCE,
	posture: StringName = CrownTroops.HOLD_THE_TOWNS,
	split: StringName = Policy.ALL,
) -> Policy:
	return run.policies.enact(Policy.new(
		CrownTroops.MARSHAL, PolicyEffects.CROWN_TROOPS, 350.0, split,
		{"strength": String(strength), "posture": String(posture)}), run.log, run.world.month)


## Phase 1.
func _arrive() -> void:
	CrownTroops.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)


func _crown() -> Array:
	var out: Array = []
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if company.allegiance == Company.CROWN and not company.is_empty():
			out.append(company)
	return out


func _context_for(contact: Contact) -> LetterContext:
	var context := LetterContext.new(run.world, contact, &"")
	context.month = run.world.month
	context.colony = run.colony
	context.contacts = run.contacts
	context.policies = run.policies
	context.log = run.log
	return context


# --- 🔒 The policy lands them ---------------------------------------------------------

func test_a_standing_troops_policy_puts_crown_companies_in_the_colony() -> void:
	assert_empty(_crown(), "Crown troops were here before anybody asked")
	var policy := _enact()
	_arrive()
	var landed := _crown()
	assert_eq(landed.size(), 1, "the troops policy landed nobody")
	var company: Company = landed[0]
	assert_eq(company.size, CrownTroops.men_for(CrownTroops.A_FORCE))
	assert_eq(String(company.policy), String(policy.id))
	assert_false(company.is_headless(), "Crown troops came without a commander (§9)")
	assert_eq(run.log.of_type(CrownTroops.EVENT_LANDED).size(), 1)


func test_they_are_never_the_colonys_burden() -> void:
	# 🔒 §3: victualled by the Crown, never from a town's stores.
	_enact(CrownTroops.A_GARRISON, CrownTroops.HOLD_THE_TOWNS, Policy.NONE)
	_arrive()
	assert_eq(String((_crown()[0] as Company).support), String(Company.SUPPORTED_ABROAD),
		"Crown soldiers depend on a town to eat")


func test_one_company_for_each_policy_however_many_months_it_stands() -> void:
	_enact()
	_arrive()
	run.world.month += 1
	_arrive()
	assert_eq(_crown().size(), 1, "a standing policy landed its troops again")


func test_the_posture_is_the_order_they_land_under() -> void:
	var expected := {
		CrownTroops.HOLD_THE_TOWNS: StandingOrder.DEFEND_THE_TOWN,
		CrownTroops.PATROL_THE_COUNTRY: StandingOrder.GUARD_THE_BORDER,
		CrownTroops.PUT_DOWN_THE_REBELLION: StandingOrder.MARCH_ON_A_FOE,
	}
	# Three policies at once, each with its own company.
	var posture_of: Dictionary = {}
	for posture in expected:
		posture_of[String(_enact(CrownTroops.A_GARRISON, posture).id)] = posture
	_arrive()
	assert_eq(_crown().size(), 3)
	for entry in _crown():
		var company: Company = entry
		var posture: StringName = posture_of[String(company.policy)]
		assert_eq(String(company.order), String(expected[posture]),
			"'%s' landed under the wrong order" % posture)


func test_men_sent_to_put_down_the_rebellion_march_only_on_rebels() -> void:
	_enact(CrownTroops.AN_ARMY, CrownTroops.PUT_DOWN_THE_REBELLION)
	_arrive()
	var troops: Company = _crown()[0]
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	var home: Town = run.colony.in_order()[0]
	var war_party := run.companies.raise_company(
		Company.NATIVE, 5_000, {}, Company.SUPPORTED_ABROAD, home.at + Vector2i(1, 0), context)
	assert_true(OrderRule.foe_of(troops, home, context) == null,
		"men sent against a rebellion marched on a war party")
	var rebels := run.companies.raise_company(
		Company.REBEL, 5_000, {}, Company.SUPPORTED_ABROAD, home.at + Vector2i(6, 0), context)
	assert_same(OrderRule.foe_of(troops, home, context), rebels)
	assert_true(war_party != null)


# --- 🔒 He writes first, then they sail ---------------------------------------------------

func test_when_it_lapses_they_sail_and_say_how_many() -> void:
	var policy := _enact()
	_arrive()
	var men := (_crown()[0] as Company).size
	run.policies.lapse(policy.id, run.log, run.world.month)
	run.world.month += 1
	_arrive()
	assert_empty(_crown(), "the soldiers stayed after their policy lapsed")
	var sailed: Array = run.log.of_type(CrownTroops.EVENT_SAILED)
	assert_eq(sailed.size(), 1, "their going was not one event")
	assert_eq(int(sailed[0].payload["men"]), men, "the event did not say how many went")


func test_the_marshal_writes_before_they_go() -> void:
	var policy := _enact(CrownTroops.A_FORCE, CrownTroops.HOLD_THE_TOWNS, Policy.NONE)
	_arrive()
	var marshal := run.contact(CrownTroops.MARSHAL)
	assert_false(ColonyConditions.his_troops_are_going_home({}, _context_for(marshal)))
	policy.carried_months = PolicyBook.PATIENCE
	run.policies.take_stock(run.log, run.world.month)
	assert_true(ColonyConditions.his_troops_are_going_home({}, _context_for(marshal)),
		"the Marshal had nothing to say about calling his troops home")
	_arrive()
	assert_eq(_crown().size(), 1, "the soldiers sailed before he had written")
	run.world.month = policy.ends_month
	run.policies.take_stock(run.log, run.world.month)
	run.world.month += 1
	_arrive()
	assert_empty(_crown(), "the warning ran out and the soldiers stayed")


func test_the_first_departure_shows_the_marshal_withdraws() -> void:
	var policy := _enact()
	_arrive()
	run.policies.lapse(policy.id, run.log, run.world.month)
	_arrive()
	var triggers: Array = []
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if record.has("cutscene"):
			triggers.append(record)
	var shown := CutsceneTriggers.ids_of(
		CutsceneTriggers.fired(triggers, run.log.of_type(CrownTroops.EVENT_SAILED), {}))
	assert_true(shown.has("the_marshal_withdraws"), "the soldiers sailed and nothing was painted: %s" % [shown])


# --- 🔒 The PC asks the Marshal, and only him ------------------------------------------------

func test_the_pcs_letter_enacts_the_troops_policy_and_the_troops_land() -> void:
	var marshal := run.contact(CrownTroops.MARSHAL)
	var context := _context_for(marshal)
	context.params = {"to": "marshal"}
	var option: Dictionary = {}
	for entry in content.record("letters", "pc.request_troops")["reply"]["steps"][0]["options"]:
		if String(entry["id"]) == "garrison":
			option = entry
	var effect: Dictionary = option["effect"]
	var order := ContentRegistry.run_effect("station_troops", effect["station_troops"], context)
	assert_eq(order.kind, M1Registrations.ORDER_ENACT_POLICY)

	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.policies = run.policies
	orders._enact_if_agreed(order, marshal, {"outcome": String(Compliance.COMPLY)}, run.world, run.log)
	_arrive()
	assert_eq(_crown().size(), 1, "the Marshal agreed and no soldiers came")
	assert_eq((_crown()[0] as Company).size, CrownTroops.men_for(CrownTroops.A_GARRISON))


func test_only_the_marshal_is_asked_for_troops() -> void:
	var composer := Composer.new(content)
	var letter := Letter.from_record(content.record("letters", "pc.request_troops"))
	var trigger: Dictionary = content.record("triggers", "trigger.pc.request_troops")
	var recipients := composer.recipients_for(letter, run, trigger)
	assert_true(recipients.has(CrownTroops.MARSHAL), "the Marshal cannot be asked for troops")
	assert_false(recipients.has(&"provost"), "the Provost was offered a troops policy")


func test_there_is_a_rebellion_to_put_down_only_while_a_town_is_out() -> void:
	var context := _context_for(run.contact(CrownTroops.MARSHAL))
	assert_false(ColonyConditions.a_town_is_in_rebellion({}, context))
	run.colony.in_order()[0].rebelling = true
	assert_true(ColonyConditions.a_town_is_in_rebellion({}, context))


func test_the_policy_they_serve_survives_the_save() -> void:
	var policy := _enact()
	_arrive()
	var restored := Company.from_dict((_crown()[0] as Company).to_dict())
	assert_eq(String(restored.policy), String(policy.id))


func test_the_turn_loop_lands_and_recalls_them() -> void:
	# The driver above is built by hand; this is the one the game runs.
	var machine := TurnMachine.new(run)
	var found := false
	for driver in machine.month_runner.drivers:
		found = found or driver is CrownTroops
	assert_true(found, "the month never lands or recalls the Crown's troops")


func test_the_validator_refuses_troops_the_marshal_does_not_have() -> void:
	var validator := ContentValidator.new()
	validator.check_troop_requests(content)
	assert_true(validator.ok(), "the shipped troop requests do not validate")
	var letter: Dictionary = content.collection("letters")["pc.request_troops"]
	letter["reply"]["steps"][0]["options"][0]["effect"]["station_troops"]["strength"] = "a_horde"
	validator = ContentValidator.new()
	validator.check_troop_requests(content)
	assert_false(validator.ok(), "a horde passed for a strength")
	letter["reply"]["steps"][0]["options"][0]["effect"]["station_troops"]["strength"] = "a_force"
	letter["reply"]["steps"][0]["options"][0]["effect"]["station_troops"]["posture"] = "loiter"
	validator = ContentValidator.new()
	validator.check_troop_requests(content)
	assert_false(validator.ok(), "loitering passed for a posture")
