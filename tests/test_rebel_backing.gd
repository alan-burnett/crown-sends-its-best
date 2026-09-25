extends TestCase

## Dukes back rebel towns (#403, `rival-pressure.md` §8 *They back rebel towns*).
##
## 🔒 **The roll**: three months into a rebellion, every arrived duke who has not
## backed one rolls, certain at no loyalty and never at full. He backs the most
## populous such town.
##
## 🔒 **What he sends**: gold, food and guns scaled to the town's people, and a
## rebel company with a rebel commander that he feeds, not the town.
##
## 🔒 **Once in his life**; a second duke may back the same town. **The town is
## never lost by it**, and when it comes back to the Crown his men go home.

const SEED: int = 403
const DIPLOMAT := "trigger.diplomat.a_duke_backs_the_rebels"

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
	run.world.month = 12


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


## `count` dukes arrived, each at `loyalty`.
func _dukes(count: int, loyalty: float = 0.0) -> Array:
	for _index in count:
		run.demands.sources.append(String(DemandGrowth.SOURCE_DUKE))
	var dukes := RivalDuke.arrived_in(run, run.demands)
	for entry in dukes:
		(entry as Contact).relationship.loyalty = loyalty
	return dukes


func _rebelling(town: Town, months: int = RebelBacking.AFTER_MONTHS) -> void:
	town.rebelling = true
	town.rebelling_since = run.world.month - months


func _roll() -> void:
	RebelBacking.new(run).on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)


func _backings() -> Array:
	var out: Array = []
	for intent in run.intents.live():
		if intent.kind == BackRebellionExecutor.KIND:
			out.append(intent)
	return out


func _land() -> void:
	var executor := BackRebellionExecutor.new()
	executor.run = run
	for intent in _backings():
		var resolution := executor.execute(intent, run.world, run.log)
		run.intents.resolve(intent, resolution, run.log, run.world.month)


func _his_company(duke: Contact) -> Company:
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.raised_by == duke.id and not String(company.backs).is_empty():
			return company
	return null


func _second_town(workers: int) -> Town:
	var town := run.colony.add(Town.new(&"second_town", "Second", _town().at + Vector2i(6, 0)))
	town.workers = workers
	return town


# --- 🔒 The roll ------------------------------------------------------------------------------

func test_a_duke_at_nought_backs_a_town_three_months_out() -> void:
	var duke: Contact = _dukes(1)[0]
	_rebelling(_town())
	_roll()
	assert_eq(_backings().size(), 1, "a duke who hates the PC let a rebellion go unbacked")
	assert_eq(String(_backings()[0].data.get("town", "")), String(_town().id))


func test_a_duke_at_full_loyalty_never_does() -> void:
	_dukes(1, Relationship.MAX_LOYALTY)
	_rebelling(_town())
	for month in 24:
		run.world.month += 1
		_roll()
	assert_empty(_backings(), "a duke at full regard backed a rebellion against the PC")


func test_not_before_the_town_has_been_out_three_months() -> void:
	_dukes(1)
	_rebelling(_town(), RebelBacking.AFTER_MONTHS - 1)
	_roll()
	assert_empty(_backings(), "a duke backed a rebellion that had barely begun")


func test_the_most_populous_rebel_town_is_backed() -> void:
	_dukes(1)
	var larger := _second_town(_town().population() + 5_000)
	_rebelling(_town())
	_rebelling(larger)
	assert_same(RebelBacking.town_to_back(run.colony, run.world.month), larger)
	# The same number of people in each: the first in town order.
	larger.workers = _town().population() - larger.expert_total()
	assert_eq(larger.population(), _town().population())
	assert_same(RebelBacking.town_to_back(run.colony, run.world.month), _town(), "a tie did not go to the first town")


# --- 🔒 What he sends ------------------------------------------------------------------------

func test_he_sends_gold_food_and_guns_and_a_rebel_company_he_feeds() -> void:
	var duke: Contact = _dukes(1)[0]
	var town := _town()
	_rebelling(town)
	var thousands := Population.thousands(float(town.population()))
	var food := town.held(&"food")
	var guns := town.held(&"guns")
	var purse := town._gold
	var events_before := run.log.of_type(BackRebellionExecutor.EVENT_BACKED).size()
	_roll()
	_land()
	assert_eq(run.log.of_type(BackRebellionExecutor.EVENT_BACKED).size(), events_before + 1)
	var backed := run.log.of_type(BackRebellionExecutor.EVENT_BACKED)[-1]
	assert_almost_eq(float(backed.payload["gold"]), thousands * BackRebellionExecutor.GOLD_PER_THOUSAND, 0.01)
	assert_almost_eq(town._gold - purse, thousands * BackRebellionExecutor.GOLD_PER_THOUSAND, 0.01,
		"his gold never reached the town's purse")
	assert_almost_eq(town.held(&"food") - food, thousands * BackRebellionExecutor.FOOD_PER_THOUSAND, 0.01,
		"the town's food did not rise with its people")
	assert_almost_eq(town.held(&"guns") - guns, thousands * BackRebellionExecutor.GUNS_PER_THOUSAND, 0.01)

	var company := _his_company(duke)
	assert_true(company != null, "no company of his came ashore")
	assert_eq(String(company.allegiance), String(Company.REBEL))
	assert_eq(String(company.support), String(Company.SUPPORTED_ABROAD), "the town was left to feed his men")
	assert_false(run.companies.supported_by(town.id).has(company), "the town's stores feed the duke's company")
	assert_false(String(company.commander).is_empty(), "his company came without a commander")
	assert_eq(company.size, int(roundf(thousands * BackRebellionExecutor.MEN_PER_THOUSAND)))
	assert_eq(duke.backed_rebellion, String(town.id))


func test_the_town_is_never_lost_by_it() -> void:
	_dukes(1)
	_rebelling(_town())
	_roll()
	_land()
	assert_same(run.colony.by_id(_town().id), _town(), "backing a rebellion took the town out of the colony")
	assert_true(_town().rebelling)


# --- 🔒 Once in his life ---------------------------------------------------------------------

func test_a_duke_who_has_backed_one_never_backs_another() -> void:
	var duke: Contact = _dukes(1)[0]
	_rebelling(_town())
	_roll()
	_roll()
	assert_eq(_backings().size(), 1, "he rolled again while his backing was on its way")
	assert_empty(run.log.of_type(&"intent_overtaken"),
		"he rolled again while his backing was on its way, and overtook it")
	_land()
	_rebelling(_second_town(20_000))
	for month in 12:
		run.world.month += 1
		_roll()
	assert_empty(_backings(), "a duke backed a second rebellion")
	assert_eq(duke.backed_rebellion, String(_town().id))


func test_a_second_duke_may_back_the_same_town() -> void:
	_dukes(2)
	_rebelling(_town())
	_roll()
	assert_eq(_backings().size(), 2, "the second duke was kept from a town the first had chosen")
	_land()
	var companies := 0
	for entry in run.companies.in_resolution_order():
		if String((entry as Company).backs) == String(_town().id) and not (entry as Company).is_empty():
			companies += 1
	assert_eq(companies, 2)


# --- 🔒 His men go home ----------------------------------------------------------------------

func test_when_the_town_returns_his_company_goes_home_commander_and_all() -> void:
	var duke: Contact = _dukes(1)[0]
	_rebelling(_town())
	_roll()
	_land()
	var commander := String(_his_company(duke).commander)
	_town().rebelling = false
	_roll()
	assert_true(_his_company(duke) == null, "his men stayed after the town came back to the Crown")
	assert_false(run.contacts.has(commander), "his commander stayed behind")
	assert_eq(run.log.of_type(RebelBacking.EVENT_WENT_HOME).size(), 1)


func test_when_the_town_is_gone_his_company_goes_home() -> void:
	var duke: Contact = _dukes(1)[0]
	var town := _second_town(20_000)
	_rebelling(town)
	_roll()
	_land()
	run.colony.towns.erase(town)
	_roll()
	assert_true(_his_company(duke) == null, "his men stayed after the town was taken")


func test_a_town_that_came_back_before_he_landed_is_not_backed() -> void:
	var duke: Contact = _dukes(1)[0]
	_rebelling(_town())
	_roll()
	_town().rebelling = false
	_land()
	assert_true(_his_company(duke) == null)
	assert_eq(duke.backed_rebellion, "", "a backing that never landed spent his one chance")


# --- 🔒 The PC hears of it -------------------------------------------------------------------

func test_the_diplomat_writes_to_the_pc_about_it() -> void:
	var duke: Contact = _dukes(1)[0]
	var diplomat := ColonyConditions.diplomat_in(run.contacts)
	assert_true(diplomat != null, "there is no Diplomat in the colony, so this proves nothing")
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[DIPLOMAT]
	assert_false(director._conditions_hold(trigger, director._context(run, diplomat)))
	_rebelling(_town())
	_roll()
	_land()
	var context := director._context(run, diplomat)
	assert_true(director._conditions_hold(trigger, context), "a duke backed a rebellion and the Diplomat said nothing")
	var letter := Letter.from_record(content.record("letters", "diplomat.a_duke_backs_the_rebels"))
	var params := director._inbound(trigger, letter, diplomat, context, run).params
	assert_eq(String(params.get("duke", "")), duke.display_name)
	assert_eq(String(params.get("town", "")), _town().display_name)
	assert_true(int(params.get("men", 0)) > 0)


# --- 🔒 Saved, and wired ---------------------------------------------------------------------

func test_having_backed_a_rebellion_survives_a_save() -> void:
	var duke: Contact = _dukes(1)[0]
	_rebelling(_town())
	_roll()
	_land()
	assert_eq(Contact.from_data(duke.to_dict()).backed_rebellion, String(_town().id))
	assert_eq(String(Company.from_dict(_his_company(duke).to_dict()).backs), String(_town().id))


func test_the_turn_loop_rolls_and_lands() -> void:
	var rolls := false
	var lands := false
	for driver in machine.month_runner.drivers:
		rolls = rolls or driver is RebelBacking
	for executor in machine.month_runner.executors:
		lands = lands or executor is BackRebellionExecutor
	assert_true(rolls and lands, "nothing in the month rolls or lands a duke's backing")
