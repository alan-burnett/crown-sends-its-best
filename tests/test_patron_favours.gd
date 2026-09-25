extends TestCase

## A patron's expert, troops and gold, offered (#443, `patrons.md` §4 *What his
## specialty does*, *The one-offs repeat*, *A policy of his outlives him*).
##
## 🔒 **He offers once his regard is high enough; the PC cannot ask.**
##
## 🔒 **The expert goes to the library that holds fewest of his kind**, ties to
## town order; **the gold goes to the Crown's books**, and is not duty; **the men
## are a company the Crown feeds**, and one still here when he sails stays.
##
## 🔒 **The one-offs repeat** while his regard holds.

const SEED: int = 443
const EXPERT := "trigger.patron.an_expert_for_you"
const GOLD := "trigger.patron.a_gift_for_the_crown"
const MEN := "trigger.patron.his_men_for_you"

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

func _patron(specialty: String, kind: String = "", loyalty: float = 80.0) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, loyalty)
	patron.specialty = specialty
	patron.specialty_kind = kind
	patron.specialty_bonus = ""
	run.add_contact(patron)
	return patron


func _town(index: int = 0) -> Town:
	return run.colony.in_order()[index]


## A second town, last in order.
func _second_town() -> Town:
	return run.colony.add(Town.new(&"second_town", "Second", _town().at + Vector2i(6, 0)))


func _true(trigger_id: String, patron: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[trigger_id], director._context(run, patron))


## The Order his letter's `option_id` answer produces.
func _answer(patron: Contact, letter_id: String, trigger_id: String, option_id: String) -> Order:
	var director := machine.director
	var letter := Letter.from_record(content.record("letters", letter_id))
	var context := director._context(run, patron)
	context.params = director._inbound(content.collection("triggers")[trigger_id], letter, patron, context, run).params
	context.tone = Tone.DUTIFUL
	for option in content.record("letters", letter_id)["reply"]["steps"][0]["options"]:
		if String(option["id"]) != option_id:
			continue
		var effect: Dictionary = option["effect"]
		var id: String = effect.keys()[0]
		return ContentRegistry.run_effect(id, effect[id], context)
	return null


# --- 🔒 His regard ---------------------------------------------------------------------------

func test_below_his_regard_he_offers_none_of_them() -> void:
	_town().buildings.append("library")
	var cold := Patron.OFFERS_AT - 1.0
	assert_false(_true(EXPERT, _patron("experts", "tobacco", cold)))
	assert_false(_true(GOLD, _patron("gold", "", cold)))
	assert_false(_true(MEN, _patron("troops", "", cold)))
	assert_true(_true(EXPERT, _patron("experts", "tobacco")))
	assert_true(_true(GOLD, _patron("gold")))
	assert_true(_true(MEN, _patron("troops")))


func test_only_the_specialty_offers_its_favour() -> void:
	_town().buildings.append("library")
	var gold := _patron("gold")
	assert_false(_true(EXPERT, gold), "a gold man offered an expert")
	assert_false(_true(MEN, gold), "a gold man offered troops")
	assert_false(_true(GOLD, _patron("troops")), "a troops man offered gold")


# --- 🔒 The expert ---------------------------------------------------------------------------

func test_an_expert_is_offered_only_while_a_town_has_a_library() -> void:
	var patron := _patron("experts", "tobacco")
	assert_false(_true(EXPERT, patron), "he offered a man with nowhere to put him")
	_town().buildings.append("library")
	assert_true(_true(EXPERT, patron))


func test_he_lands_in_the_library_town_with_fewest_of_his_kind() -> void:
	var first := _town()
	var second := _second_town()
	first.buildings.append("library")
	second.buildings.append("library")
	first.add_experts(&"tobacco", 2)
	var patron := _patron("experts", "tobacco")
	var order := _answer(patron, "patron.an_expert_for_you", EXPERT, "accept")
	assert_eq(order.kind, M1Registrations.ORDER_SEND_AN_EXPERT)

	var executor := ExpertGiftExecutor.new()
	executor.colony = run.colony
	var intent := Compliance._intent_for(order, Compliance.COMPLY, patron)
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.COMPLETED))
	assert_eq(second.expert_count(&"tobacco"), 1, "he did not go where his kind were fewest")
	assert_eq(first.expert_count(&"tobacco"), 2)


func test_a_town_in_rebellion_is_not_sent_one() -> void:
	var first := _town()
	var second := _second_town()
	first.buildings.append("library")
	second.buildings.append("library")
	first.rebelling = true
	assert_same(ExpertGiftExecutor.town_for(run.colony, &"sugar"), second,
		"his man was sent to a town in rebellion")


func test_ties_go_to_the_first_town() -> void:
	var first := _town()
	var second := _second_town()
	first.buildings.append("library")
	second.buildings.append("library")
	assert_same(ExpertGiftExecutor.town_for(run.colony, &"sugar"), first)


func test_a_town_without_a_library_never_receives_him_and_none_at_all_stalls() -> void:
	var second := _second_town()
	second.buildings.append("library")
	assert_same(ExpertGiftExecutor.town_for(run.colony, &"sugar"), second,
		"he went to a town with no library")
	second.buildings.clear()
	var executor := ExpertGiftExecutor.new()
	executor.colony = run.colony
	var intent := Intent.new(&"", ExpertGiftExecutor.KIND, &"patron_1", &"patron_1", 1, {"resource": "sugar"})
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.STALLED))


# --- 🔒 The gold ---------------------------------------------------------------------------------

func test_his_gold_reaches_the_crowns_books_and_the_ledger_and_is_not_duty() -> void:
	var patron := _patron("gold")
	var order := _answer(patron, "patron.a_gift_for_the_crown", GOLD, "accept")
	assert_eq(order.kind, M1Registrations.ORDER_GIVE_THE_CROWN_GOLD)
	var amount := float(order.get_param("amount", 0.0))
	assert_true(amount > 0.0, "he offered nothing")

	var before := CrownAccounts.of(run.log)
	var intent := Compliance._intent_for(order, Compliance.COMPLY, patron)
	assert_eq(String(GoldGiftExecutor.new().execute(intent, run.world, run.log)), String(Intent.COMPLETED))
	var after := CrownAccounts.of(run.log)
	assert_almost_eq(after.net_position() - before.net_position(), amount, 0.001,
		"his gold never reached the Crown's books")
	assert_almost_eq(after.received_in(run.world.month), before.received_in(run.world.month), 0.001,
		"a gift was counted as duty")
	var page := Ledger.of(run.log).page(run.world.month)
	var shown := 0.0
	for entry in page.entries:
		if entry.direction == Ledger.IN:
			shown += entry.amount
	assert_almost_eq(shown, amount, 0.001, "the Ledger does not show his gift")


# --- 🔒 His men ------------------------------------------------------------------------------------

func _troops(split: String = "all") -> Contact:
	var patron := _patron("troops")
	patron.leaves_month = 40
	var order := _answer(patron, "patron.his_men_for_you", MEN, split)
	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.policies = run.policies
	orders._enact_if_agreed(order, patron, {"outcome": String(Compliance.COMPLY)}, run.world, run.log)
	return patron


func _land() -> void:
	CrownTroops.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)


func _his_company(patron: Contact) -> Company:
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.raised_by == patron.id:
			return company
	return null


func test_his_men_are_a_company_the_crown_feeds() -> void:
	var patron := _troops()
	var held := run.policies.held_by(patron.id)
	assert_eq(held.size(), 1, "accepting his men enacted no policy")
	assert_eq(String(held[0].effect), String(PolicyEffects.CROWN_TROOPS))
	_land()
	var company := _his_company(patron)
	assert_true(company != null, "his men never landed")
	assert_eq(String(company.allegiance), String(Company.CROWN))
	assert_false(_true(MEN, patron), "he offered men while his own were here")


func test_his_company_stays_when_he_sails_at_no_charge() -> void:
	var patron := _troops("half")
	_land()
	PatronTerm.advance(run, run.log, 40)
	assert_false(run.contacts.has(String(patron.id)), "he never sailed")
	_land()
	assert_true(_his_company(patron) != null, "his company sailed home with him")
	assert_almost_eq(run.policies.bill(run.contacts, run.log, 41), 0.0, 0.0001,
		"the Crown is still paying for men nobody holds")


# --- 🔒 The one-offs repeat --------------------------------------------------------------------

func test_the_one_offs_are_offered_again_after_they_are_given() -> void:
	_town().buildings.append("library")
	var expert := _patron("experts", "tobacco")
	var executor := ExpertGiftExecutor.new()
	executor.colony = run.colony
	executor.execute(Compliance._intent_for(_answer(expert, "patron.an_expert_for_you", EXPERT, "accept"),
		Compliance.COMPLY, expert), run.world, run.log)
	assert_true(_true(EXPERT, expert), "one expert given, and he would never offer another")

	var gold := _patron("gold")
	GoldGiftExecutor.new().execute(Compliance._intent_for(_answer(gold, "patron.a_gift_for_the_crown", GOLD, "accept"),
		Compliance.COMPLY, gold), run.world, run.log)
	assert_true(_true(GOLD, gold), "one gift given, and he would never offer another")


# --- 🔒 Taken up, they bank, and the month lands them ------------------------------------------

func test_accepting_either_is_a_favour_he_banks_and_costs_him_nothing() -> void:
	for kind in [M1Registrations.ORDER_SEND_AN_EXPERT, M1Registrations.ORDER_GIVE_THE_CROWN_GOLD]:
		var order := Order.new(kind, &"patron_1", {"to": "patron_1"}, 0)
		assert_eq(String(Compliance._deed_of(order)), String(Relationship.GRANTED))
		assert_almost_eq(float(Compliance._priced(order)), 0.0, 0.0001)


func test_the_turn_loop_lands_them() -> void:
	var experts := false
	var gold := false
	for executor in machine.month_runner.executors:
		experts = experts or executor is ExpertGiftExecutor
		gold = gold or executor is GoldGiftExecutor
	assert_true(experts and gold, "nothing in the month lands a patron's expert or his gold")
