extends TestCase

## Standing orders: explore, guard the border, march on a foe (#434,
## `docs/mechanics/commanders.md` §3, the Author's ruling on #423).
##
## 🔒 One fixed rule gives the order when a company is raised, from the intent it
## was raised under and whether a threat is near its town — no personality, no
## dice. A leaderless company then follows it every month and does nothing
## else; a commander starts with it and deliberates from there.

const SEED: int = 434

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
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	context.knowledge = run.knowledge
	context.natives = run.tribes
	context.territory = Territory.compute(run.map, run.colony.in_order())
	return context


func _driver(run: RunState) -> CompanyDriver:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	driver.knowledge = run.knowledge
	driver.natives = run.tribes
	return driver


func _town(run: RunState, intent: StringName, objective: StringName, workers: int = 40_000) -> Town:
	var town: Town = run.colony.in_order()[0]
	town.workers = workers
	town.experts = {}
	town.intent = intent
	town.objective = objective
	return town


## A body of men of `allegiance` standing `offset` from the town.
func _stranger(run: RunState, allegiance: StringName, town: Town, offset: Vector2i) -> Company:
	return run.companies.raise_company(
		allegiance, 2_000, {}, Company.SUPPORTED_ABROAD, town.at + offset, _context(run),
		StandingOrder.DEFEND_THE_TOWN, Company.MILITIA)


func _land_near(run: RunState, town: Town, want: int) -> Vector2i:
	# The first land tile `want` tiles east of the town, or nearest to it.
	for step in range(want, 0, -1):
		var at := town.at + Vector2i(step, 0)
		if run.map.in_bounds(at.x, at.y) and run.map.is_land(at.x, at.y):
			return Vector2i(step, 0)
	return Vector2i(1, 0)


# --- 🔒 The rule (§3) -------------------------------------------------------------

func test_a_scouting_company_under_go_wide_explores_with_no_threat_and_defends_with_one() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.GO_WIDE, &"scouting_company")
	var scouts := Raising.raise_from(town, _context(run))
	assert_eq(String(scouts.order), String(StandingOrder.EXPLORE),
		"a scouting party with nothing near its town was not sent to explore")

	var threatened := _run()
	var home := _town(threatened, GovernorIntent.GO_WIDE, &"scouting_company")
	_stranger(threatened, Company.NATIVE, home, _land_near(threatened, home, 3))
	var kept := Raising.raise_from(home, _context(threatened))
	assert_eq(String(kept.order), String(StandingOrder.DEFEND_THE_TOWN),
		"a scouting party was sent off with a war party three tiles from its town")


func test_a_military_company_guards_the_border_or_marches_on_its_foe() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.MILITARY, Raising.BIG)
	assert_eq(String(Raising.raise_from(town, _context(run)).order), String(StandingOrder.GUARD_THE_BORDER))

	var threatened := _run()
	var home := _town(threatened, GovernorIntent.MILITARY, Raising.BIG)
	_stranger(threatened, Company.NATIVE, home, _land_near(threatened, home, 5))
	assert_eq(String(Raising.raise_from(home, _context(threatened)).order),
		String(StandingOrder.MARCH_ON_A_FOE))


func test_no_colonial_company_is_ever_raised_to_march_on_a_colonial_town() -> void:
	# \U0001f512 Colonists never fight colonists (`battles.md` §1): a rebel company beside a
	# loyal town is no threat to it and never its foe.
	var run := _run()
	var town := _town(run, GovernorIntent.MILITARY, Raising.BIG)
	_stranger(run, Company.REBEL, town, _land_near(run, town, 2))
	_stranger(run, Company.COLONIAL, town, _land_near(run, town, 3))
	var company := Raising.raise_from(town, _context(run))
	assert_eq(String(company.order), String(StandingOrder.GUARD_THE_BORDER),
		"colonists near the town read as a threat to it")
	company.order = StandingOrder.MARCH_ON_A_FOE
	assert_eq(OrderRule.foe_of(company, town, _context(run)), null,
		"a colonial company found a foe among the colony's own people")


func test_the_same_town_and_map_give_the_same_order_and_draw_nothing() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.GO_WIDE, &"scouting_company")
	var context := _context(run)
	var before := Canonical.hash_of(run.streams.to_dict())
	var first := OrderRule.order_for(town, GovernorIntent.GO_WIDE, context)
	for _again in 3:
		assert_eq(String(OrderRule.order_for(town, GovernorIntent.GO_WIDE, context)), String(first))
	assert_eq(Canonical.hash_of(run.streams.to_dict()), before, "choosing an order drew from a stream")


# --- 🔒 A militia follows its order ----------------------------------------------

func test_an_exploring_militia_explores_until_its_term_then_goes_home_where_it_stands() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.GO_WIDE, &"scouting_company")
	run.world.month = 3
	var scouts := Raising.raise_from(town, _context(run))
	var raised := scouts.size
	var before := town.workers
	var known := run.knowledge.explored_count()
	var driver := _driver(run)

	for month in range(4, 3 + Company.militia_months()):
		run.world.month = month
		driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
		scouts.was_supplied(month)
		driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
		assert_false(scouts.is_empty(), "it went home in month %d, before its term" % month)
	assert_ne(scouts.at, town.at, "an exploring militia never left its town")
	assert_true(run.knowledge.explored_count() > known, "it walked for a year and the colony saw nothing new")
	assert_not_empty(run.log.of_type(Company.EVENT_EXPLORED))

	run.world.month = 3 + Company.militia_months()
	scouts.was_supplied(run.world.month)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_true(scouts.is_empty(), "it stood its term and stayed out")
	assert_eq(town.workers, before + raised, "its people were not the town's workers that month")


func test_guarding_the_border_goes_to_the_edge_that_faces_the_threat() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.MILITARY, Raising.BIG, 5_000)
	Raising.load_from({"worker_floor": 1_000})
	var guard := Raising.raise_from(town, _context(run))
	assert_eq(String(guard.order), String(StandingOrder.GUARD_THE_BORDER))
	assert_true(guard.is_headless(), "the fixture's company has a commander, so its order is his to follow")

	var offset := _land_near(run, town, 7)
	_stranger(run, Company.NATIVE, town, offset)
	var post := OrderRule.border_post(town, _context(run))
	assert_ne(post, town.at, "a threat within eight tiles left the border post in the town")
	assert_true((post - (town.at + offset)).length_squared() < (town.at - (town.at + offset)).length_squared(),
		"the post does not face the threat")
	var driver := _driver(run)
	for month in range(1, 6):
		run.world.month = month
		driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_eq(guard.at, post, "the guard never reached its post")


func test_a_rebel_towns_company_marches_on_crown_troops_once_the_town_has_declared() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.SEDITION, Raising.BIG, 5_000)
	Raising.load_from({"worker_floor": 1_000})
	var company := Raising.raise_from(town, _context(run))
	assert_eq(String(company.order), String(StandingOrder.MARCH_ON_A_FOE))
	assert_true(company.is_headless())
	# A war party close by and the Crown's troops further off. Before the town
	# declares it may fight neither the Crown nor — being raised for the
	# rebellion — anybody else.
	_stranger(run, Company.NATIVE, town, _land_near(run, town, 2))
	var crown := _stranger(run, Company.CROWN, town, _land_near(run, town, 6))
	var driver := _driver(run)
	run.world.month = 1
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_eq(company.at, town.at, "a company marched out before its town declared")

	town.rebel_sentiment = Rebellion.DECLARES_AT + 1.0
	Rebellion.resolve(town, _context(run))
	assert_eq(String(company.allegiance), String(Company.REBEL), "the town declared and its company did not")
	assert_not_empty(run.log.of_type(Company.EVENT_TURNED))
	var gap := (crown.at - company.at).length_squared()
	run.world.month = 2
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_true((crown.at - company.at).length_squared() < gap,
		"a rebel company did not march on the Crown's troops")


# --- 🔒 A commander may explore (§5) --------------------------------------------

func test_a_commander_told_to_explore_explores() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.GO_WIDE, &"scouting_company")
	var context := _context(run)
	var company := run.companies.raise_company(
		Company.COLONIAL, 4_000, {}, town.id, town.at, context,
		StandingOrder.EXPLORE, Company.COMMANDED)
	Commanders.take_command(company, town, run, context)
	assert_false(company.is_headless())
	var known := run.knowledge.explored_count()
	var driver := _driver(run)
	# Months enough to walk out of what the town can already see.
	for month in range(1, 9):
		run.world.month = month
		driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_ne(company.at, town.at, "a commander told to explore held")
	assert_true(run.knowledge.explored_count() > known, "he walked and the colony saw nothing new")


func test_what_he_was_told_argues_for_exploring_only_if_he_was_told_to_explore() -> void:
	# The order reaches his choice as a weight (§5), never as a command.
	var orders := CommanderConsiderations.OrdersConsideration.new(&"the_orders_i_was_given")
	var actor := DeliberationActor.new(&"commander", {})
	var context := DeliberationContext.new(DecisionKind.COMMANDER_ORDERS, WorldState.new(), EventLog.new())
	var sent := Company.new(&"sent", 1)
	sent.order = StandingOrder.EXPLORE
	var kept := Company.new(&"kept", 2)
	kept.order = StandingOrder.DEFEND_THE_TOWN
	var go := orders.score(actor, Candidate.new(CommanderConsiderations.EXPLORE, {"company": sent}), context)
	var stay := orders.score(actor, Candidate.new(CommanderConsiderations.EXPLORE, {"company": kept}), context)
	assert_true(go > 0.0, "an order to explore said nothing for exploring")
	assert_true(stay < 0.0, "an order to hold the town argued for wandering off")


func test_explore_is_offered_only_with_land_to_find_and_nobody_in_front() -> void:
	var ids := func(options: Array) -> PackedStringArray:
		var out := PackedStringArray()
		for candidate in options:
			out.append(String((candidate as Candidate).id))
		return out
	var company := Company.new(&"c", 1)
	var enemy := Company.new(&"e", 2)
	assert_true(ids.call(CommanderConsiderations.options_for(company, null, false, true)).has("explore"))
	assert_false(ids.call(CommanderConsiderations.options_for(company, null, false, false)).has("explore"))
	assert_false(ids.call(CommanderConsiderations.options_for(company, enemy, false, true)).has("explore"),
		"a company in contact could walk away exploring")


# --- 🔒 What the colony has seen (#434, correcting #429) ------------------------------

func test_room_to_grow_counts_the_land_the_colony_has_seen() -> void:
	# `governor-agendas.md` §13: *scouting raises it by revealing land*. The
	# same towns and the same sight, and more country walked: more room.
	var run := _run()
	var town: Town = run.colony.in_order()[0]
	var looking := DeliberationContext.new(DecisionKind.GOVERNOR_INTENT, run.world, run.log)
	looking.data = {
		"map": run.map,
		"territory": Territory.compute(run.map, run.colony.in_order()),
		"knowledge": run.knowledge,
	}
	var before := IntentConsiderations.room_in_the_colony(looking)
	var walked := 0
	for y in run.map.height:
		for x in run.map.width:
			if walked >= 60 or not run.map.is_land(x, y):
				continue
			if maxi(absi(x - town.at.x), absi(y - town.at.y)) > 10:
				run.knowledge.reveal_around(run.map, Vector2i(x, y), 0, null, 0)
				walked += 1
	assert_true(walked > 0, "the fixture map has no land far from the town")
	assert_true(IntentConsiderations.room_in_the_colony(looking) > before,
		"walking unclaimed country gave the colony no more room to grow")


func test_the_scouting_gate_reads_what_the_colony_has_ever_seen() -> void:
	var run := _run()
	var town := _town(run, GovernorIntent.GO_WIDE, &"scouting_company")
	var context := _context(run)
	var gate := {"is": "unexplored_within", "n": 8}
	assert_true(AgendaMenu.holds(gate, town, context), "the fixture has nothing left to find, so this proves nothing")
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var at := town.at + Vector2i(dx, dy)
			if run.map.in_bounds(at.x, at.y):
				run.knowledge.reveal_around(run.map, at, 0, null, 0)
	assert_false(AgendaMenu.holds(gate, town, context),
		"land a scouting party had already walked read as unexplored")
