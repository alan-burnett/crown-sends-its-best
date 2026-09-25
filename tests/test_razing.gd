extends TestCase

## Improvements can be razed (#418, `docs/mechanics/tiles-and-improvements.md`
## §7).
##
## 🔒 **Harassment, not war.** A commander may spend his month burning a farm on
## the ground of a town he may fight. The tile reverts to its unimproved yield,
## the town rebuilds at full cost and time, no optic is charged, and the event
## names the culprit — which a letter must not assume the PC knows.

const SEED: int = 418

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town: Town = run.colony.in_order()[0]
	town.workers = 24_000
	# Plains east of the town: a farm two tiles out, and a field beyond it.
	for dx in range(1, 5):
		run.map.set_terrain(town.at.x + dx, town.at.y, &"plains")
	run.map.build(town.at.x + 2, town.at.y, &"farm")
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	return context


func _driver(run: RunState) -> CompanyDriver:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	return driver


## A duke's men, commanded, standing beside the farm and out of the town's reach
## of contact.
func _dukes_men(run: RunState, allegiance: StringName = Company.RIVAL) -> Company:
	var town: Town = run.colony.in_order()[0]
	var context := _context(run)
	var company := run.companies.raise_company(
		allegiance, 2_000, {}, Company.SUPPORTED_ABROAD, town.at + Vector2i(3, 0), context,
		StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	company.raised_by = &"rival_duke_montargis"
	Commanders.take_command(company, null, run, context)
	return company


func _farm(run: RunState) -> Vector2i:
	return run.colony.in_order()[0].at + Vector2i(2, 0)


func test_a_dukes_company_beside_a_worked_farm_razes_it() -> void:
	var run := _run()
	var at := _farm(run)
	var farmed := run.map.yield_at(at.x, at.y, &"food")
	_dukes_men(run)
	run.world.month = 4
	_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	assert_eq(String(run.map.improvement_at(at.x, at.y)), "", "the farm stood")
	assert_true(run.map.yield_at(at.x, at.y, &"food") < farmed, "the field still yields as a farm")
	assert_almost_eq(run.map.yield_at(at.x, at.y, &"food"),
		Terrain.find(run.map.terrain_at(at.x, at.y)).yield_of(&"food"), 0.0001,
		"the tile does not yield as unimproved ground")
	var razed: Array = run.log.of_type(Company.EVENT_RAZED)
	assert_eq(razed.size(), 1)
	assert_eq(String(razed[0].payload["town"]), String(run.colony.in_order()[0].id))
	assert_eq(String(razed[0].payload["raised_by"]), "rival_duke_montargis", "the record lost who did it")


func test_the_town_can_build_it_again_at_full_cost_and_time() -> void:
	var run := _run()
	var town: Town = run.colony.in_order()[0]
	var at := _farm(run)
	town.objective = &"farm"
	town.objective_target = at
	var months := Objective.months_required(town)
	var cost := Objective.total_cost(town)
	_dukes_men(run)
	_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_true(run.map.can_build(at.x, at.y, &"farm"), "the burnt field cannot be farmed again")
	assert_eq(Objective.months_required(town), months)
	assert_almost_eq(Objective.total_cost(town), cost, 0.0001)


func test_a_man_sent_against_them_is_argued_toward_razing_and_a_garrison_is_not() -> void:
	# His orders reach the choice as a weight (`commanders.md` §5).
	var orders := CommanderConsiderations.OrdersConsideration.new(&"the_orders_i_was_given")
	var actor := DeliberationActor.new(&"commander", {})
	var context := DeliberationContext.new(DecisionKind.COMMANDER_ORDERS, WorldState.new(), EventLog.new())
	var sent := Company.new(&"sent", 1)
	sent.order = StandingOrder.MARCH_ON_A_FOE
	var kept := Company.new(&"kept", 2)
	kept.order = StandingOrder.DEFEND_THE_TOWN
	assert_true(orders.score(actor, Candidate.new(CommanderConsiderations.RAZE, {"company": sent}), context) > 0.0)
	assert_true(orders.score(actor, Candidate.new(CommanderConsiderations.RAZE, {"company": kept}), context) < 0.0,
		"a garrison's orders argued for burning somebody's fields")


func test_a_month_of_razing_adds_no_optics_debt() -> void:
	assert_true(OpticsRegister.is_ignored(Company.EVENT_RAZED))
	assert_almost_eq(OpticsRegister.price_of(Company.EVENT_RAZED), 0.0, 0.0001)


func test_the_runs_first_razing_by_a_duke_shows_they_burned_it() -> void:
	var run := _run()
	_dukes_men(run)
	_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	var triggers: Array = []
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if record.has("cutscene"):
			triggers.append(record)
	var shown := CutsceneTriggers.ids_of(CutsceneTriggers.fired(triggers, run.log.of_type(Company.EVENT_RAZED), {}))
	assert_true(shown.has("they_burned_it"), "a duke's men burnt a farm and nothing was painted: %s" % [shown])


func test_nobody_burns_what_they_may_not_fight() -> void:
	# Colonists never fight colonists (`battles.md` §1), so the colony's own
	# company beside a loyal town's farm has nothing to burn.
	var run := _run()
	var at := _farm(run)
	_dukes_men(run, Company.COLONIAL)
	_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "farm", "the colony burnt its own farm")
	assert_empty(run.log.of_type(Company.EVENT_RAZED))


func test_roads_come_of_trade_and_are_not_burnt() -> void:
	var run := _run()
	var at := _farm(run)
	run.map.clear_improvement(at.x, at.y)
	run.map.build(at.x, at.y, &"road")
	_dukes_men(run)
	_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "road")
