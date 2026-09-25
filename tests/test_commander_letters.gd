extends TestCase

## Commanders can be written to and written from (#394, `commanders.md` §8,
## SPEC §8.6, §12.6).
##
## 🔒 A commander writes from his own company's situation, and the PC's reply
## reaches `Company.urge` through compliance — **never a write to the company**
## (Seam B). He weighs it next deliberation; nothing here decides anything.

const SEED: int = 394
const FRONT := "trigger.commander.at_the_front"
const BATTLE := "trigger.commander.after_the_battle"

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


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	context.commanders = run.commanders
	return context


## A commanded company `away` tiles east of the first town, and the man who
## leads it.
func _in_the_field(allegiance: StringName = Company.COLONIAL, away: int = 3) -> Contact:
	var town := _town()
	var company := run.companies.raise_company(
		allegiance, 5_000, {}, town.id, town.at + Vector2i(away, 0), _context(),
		StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	return Commanders.take_command(company, town, run, _context())


func _enemy_beside(man: Contact) -> Company:
	var his := UrgeCompanyExecutor.commanded_by(run.companies, man.id)
	return run.companies.raise_company(
		Company.NATIVE, 3_000, {}, Company.SUPPORTED_ABROAD, his.at + Vector2i(2, 0), _context())


func _his(man: Contact) -> Company:
	return UrgeCompanyExecutor.commanded_by(run.companies, man.id)


func _true(trigger_id: String, man: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[trigger_id], director._context(run, man))


func _written(trigger_id: String, man: Contact) -> InboundLetter:
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[trigger_id]
	var letter := Letter.from_record(content.record("letters", String(trigger["letter"])))
	return director._inbound(trigger, letter, man, director._context(run, man), run)


# --- 🔒 He writes from his own company's situation ------------------------------------------

func test_in_the_field_facing_an_enemy_he_asks_what_the_pc_wants() -> void:
	var man := _in_the_field()
	assert_true(man != null, "the fixture's company has nobody leading it")
	_enemy_beside(man)
	assert_true(_true(FRONT, man), "a commander facing an enemy in the field had nothing to ask")
	var letter := _written(FRONT, man)
	assert_eq(int(letter.params.get("enemies", 0)), 1)
	assert_eq(String(letter.params.get("near", "")), _town().display_name)
	assert_eq(int(letter.params.get("men", 0)), _his(man).size)


func test_at_home_or_with_nobody_in_reach_he_does_not() -> void:
	var at_home := _in_the_field(Company.COLONIAL, 0)
	_enemy_beside(at_home)
	assert_false(_true(FRONT, at_home), "a company in its own town wrote from the front")
	var alone := _in_the_field(Company.COLONIAL, 3)
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if company.allegiance == Company.NATIVE:
			company.size = 0
	assert_false(_true(FRONT, alone), "a commander with nobody in reach asked whether to storm them")


func test_a_dukes_officer_never_writes() -> void:
	# 🔒 The duke is the PC's only contact with his empire (`rival-pressure.md` §8).
	var officer := _in_the_field(Company.RIVAL)
	run.companies.raise_company(
		Company.COLONIAL, 3_000, {}, _town().id, _his(officer).at + Vector2i(2, 0), _context())
	assert_false(_true(FRONT, officer), "a duke's officer wrote to the PC")


func test_after_a_battle_he_reports_and_the_month_after_he_does_not() -> void:
	var man := _in_the_field()
	var enemy := _enemy_beside(man)
	enemy.at = _his(man).at + Vector2i(1, 0)
	Battle.resolve(_his(man), enemy, run.map, _context())
	assert_true(_his(man) != null, "the fixture's company did not survive its battle")
	assert_true(_true(BATTLE, man), "a commander who fought this month had nothing to report")
	run.world.month += 1
	assert_false(_true(BATTLE, man), "last month's battle was reported as this month's")


func test_what_the_conditions_read_of_a_company_that_went_unfed_or_a_man_without_one() -> void:
	var man := _in_the_field()
	var context := machine.director._context(run, man)
	assert_false(ColonyConditions.my_company_is_unsupported({"within": 1}, context))
	run.log.emit(Company.EVENT_UNSUPPORTED, _his(man).id, run.world.month, {"company": String(_his(man).id)})
	assert_true(ColonyConditions.my_company_is_unsupported({"within": 1}, context))
	assert_false(ColonyConditions.i_have_no_command({}, context))
	_his(man).size = 0
	assert_true(ColonyConditions.i_have_no_command({}, context), "a commander with no company still had one")


# --- 🔒 The reply argues; it does not move the company ------------------------------------------

func test_the_reply_reaches_the_company_through_compliance_and_never_moves_it() -> void:
	var man := _in_the_field()
	_enemy_beside(man)
	var company := _his(man)
	var at := company.at
	var order_before := company.order

	var context := machine.director._context(run, man)
	context.params = _written(FRONT, man).params
	context.tone = Tone.DESPERATE
	var option: Dictionary = {}
	for entry in content.record("letters", "commander.at_the_front")["reply"]["steps"][0]["options"]:
		if String(entry["id"]) == "withdraw":
			option = entry
	var order := ContentRegistry.run_effect("urge_company", option["effect"]["urge_company"], context)
	assert_eq(order.kind, M1Registrations.ORDER_URGE_COMPANY)
	assert_eq(order.addressed_to, man.id)

	var intent := Compliance._intent_for(order, Compliance.COMPLY, man)
	run.world.month += 1
	var executor := UrgeCompanyExecutor.new()
	executor.companies = run.companies
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.COMPLETED))
	var urged := company.urging_by(Urging.PC)
	assert_true(urged != null, "the PC's letter never reached the company")
	assert_eq(String(urged.target), String(CommanderConsiderations.WITHDRAW))
	assert_eq(String(urged.tone), String(Tone.DESPERATE), "how hard it was written did not travel")
	assert_eq(company.at, at, "a letter moved a company")
	assert_eq(String(company.order), String(order_before), "a letter rewrote a company's order")


func test_a_man_who_has_lost_his_command_is_argued_at_about_nothing() -> void:
	var man := _in_the_field()
	var intent := Intent.new(&"", UrgeCompanyExecutor.KIND, man.id, man.id, 1, {"order": "attack"})
	_his(man).size = 0
	var executor := UrgeCompanyExecutor.new()
	executor.companies = run.companies
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.STALLED))


func test_an_urging_toward_nothing_he_weighs_comes_to_nothing_loudly() -> void:
	var man := _in_the_field()
	var intent := Intent.new(&"", UrgeCompanyExecutor.KIND, man.id, man.id, 1, {"order": "take_ashmere"})
	var executor := UrgeCompanyExecutor.new()
	executor.companies = run.companies
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.STALLED))
	assert_true(_his(man).urging_by(Urging.PC) == null, "an urging toward a tile reached the company")


func test_the_turn_loop_lands_it() -> void:
	var found := false
	for executor in machine.month_runner.executors:
		found = found or executor is UrgeCompanyExecutor
	assert_true(found, "nothing in the month lands a letter to a commander")


func test_the_validator_refuses_an_order_he_does_not_weigh() -> void:
	var validator := ContentValidator.new()
	validator.check_company_urgings(content)
	assert_true(validator.ok(), "the shipped commander letters do not validate")
	var letter: Dictionary = content.collection("letters")["commander.at_the_front"]
	letter["reply"]["steps"][0]["options"][0]["effect"]["urge_company"]["order"] = "take_ashmere"
	validator = ContentValidator.new()
	validator.check_company_urgings(content)
	assert_false(validator.ok(), "a letter named a tile for a commander")
