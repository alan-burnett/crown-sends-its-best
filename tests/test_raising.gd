extends TestCase

## Raising a company is an objective, like any other (#342,
## `docs/mechanics/battles.md` §1).
##
## 🔒 **Not a second path.** A town weighs a company against a granary on the
## same axes, which is the only way a governor can decline to raise one because
## the harvest matters more — and that refusal is what makes raising one mean
## something.
##
## 🔒 **Men from workers, never experts**, and all at once: enlistment is a
## decision rather than a misfortune, so `CLAUDE.md`'s one-at-a-time rule for
## hardship is not its business.
##
## 🔒 **Arms at §2's ratio, from the stores, at launch** — and never again,
## because a company does not resupply.
##
## 🔒 **A town must keep enough workers to work**, which is the answer to *may a
## town of twelve put ten under arms*. It may not.

const SEED: int = 2291

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
	return context


## Sizes are people (#426): a town of forty is 40,000.
func _town(run: RunState, workers: int = 40_000, guns: float = 0.0) -> Town:
	var town := run.colony.in_order()[0]
	town.workers = workers
	town.experts = {}
	town.stockpile = {}
	if guns > 0.0:
		town.store(&"guns", guns)
	town.intent = GovernorIntent.MILITARY
	return town


func _raising_id() -> StringName:
	var ids := Objective.company_ids()
	return StringName(ids[0]) if not ids.is_empty() else &""


# --- 🔒 It is an objective like any other -----------------------------------

func test_raising_is_an_objective_the_data_names() -> void:
	assert_false(String(_raising_id()).is_empty(),
		"no raising objective is authored")
	assert_eq(Objective.kind_of(_raising_id()), Objective.COMPANY)
	assert_false(Objective.display_name(_raising_id()).is_empty(),
		"the objective has no name a governor could write about")


func test_nothing_bypasses_the_objective_system() -> void:
	# A second path would be one nobody could decline. `Build` is the only caller.
	var callers := PackedStringArray()
	for path in _scripts_under("res://sim"):
		if path.ends_with("raising.gd"):
			continue
		var code := _code_of(path)
		if code.contains("Raising.raise_from"):
			callers.append(path.get_file())
	assert_eq(callers, PackedStringArray(["build.gd"]),
		"something raises a company outside the objective system: %s" % [callers])


# --- 🔒 The worker floor ----------------------------------------------------

func test_a_town_of_twelve_may_not_put_ten_under_arms() -> void:
	var run := _run()
	var town := _town(run, 12_000)
	var size := Raising.size_for(town)
	assert_true(size < 10_000, "a town of twelve thousand raised %d men" % size)
	assert_true(town.workers - size >= Raising.worker_floor(),
		"it kept %d workers" % [town.workers - size])


func test_a_town_at_the_floor_offers_it_at_all() -> void:
	var run := _run()
	var town := _town(run, Raising.worker_floor())
	assert_false(Raising.may_raise(town),
		"a town with nobody to spare would still raise a company")

	var chosen := ObjectiveSelector.choose(town, GovernorIntent.MILITARY, _context(run))
	assert_false(Objective.kind_of(StringName(chosen["id"])) == Objective.COMPANY,
		"a town that cannot raise a company took one")


func test_a_rebel_town_raises_nothing_this_way() -> void:
	var run := _run()
	var town := _town(run, 40_000)
	town.rebelling = true
	assert_false(Raising.may_raise(town))


# --- 🔒 Men from workers, never experts -------------------------------------

func test_the_men_come_out_of_the_workers() -> void:
	var run := _run()
	var town := _town(run, 40_000)
	town.add_experts(&"tobacco", 8)
	run.world.month = 5

	var company := Raising.raise_from(town, _context(run))
	assert_true(company != null, "nobody was raised")
	assert_eq(town.workers + company.size, 40_000,
		"%d workers left and %d under arms" % [town.workers, company.size])
	assert_eq(town.expert_count(&"tobacco"), 8,
		"a town sent its smith to carry a musket")


func test_nothing_here_can_reach_an_expert_at_all() -> void:
	# 🔒 The behavioural test above passes for a structural reason — the worker
	# floor means a company is never larger than the spare workers — so this is
	# the guard that actually bites. `Town.take_one_life` is the **one** path
	# that falls through to experts once the workers are gone, and reaching for
	# it here is exactly the plausible mistake: it is the helper famine uses, and
	# it looks like the obvious way to take people out of a town.
	var code := _code_of("res://sim/battle/raising.gd")
	for token in ["take_one_life", "add_experts", "experts"]:
		assert_false(code.contains(token),
			"raising can reach a town's experts: %s" % token)
	assert_true(code.contains("town.workers -="),
		"the men do not come out of the workers at all")


func test_and_a_company_is_never_larger_than_the_spare_workers() -> void:
	# What makes the above structural. If this stops holding, the expert guard
	# above is the only thing left.
	var run := _run()
	for workers in [7_000, 12_000, 20_000, 40_000, 200_000]:
		var town := _town(run, workers)
		assert_true(Raising.size_for(town) <= Raising.spare_workers(town),
			"a town of %d would raise %d from %d spare"
				% [workers, Raising.size_for(town), Raising.spare_workers(town)])


func test_and_they_go_all_at_once() -> void:
	# 🔒 `CLAUDE.md`'s one-at-a-time rule governs hardship. Enlistment is a
	# decision, and a company raised one man a month would never assemble.
	var run := _run()
	var town := _town(run, 40_000)
	run.world.month = 5
	var company := Raising.raise_from(town, _context(run))
	assert_true(company.size > 1, "only one man enlisted")
	assert_eq(run.log.of_type(Raising.EVENT_RAISED).size(), 1,
		"the muster was reported piecemeal")


# --- 🔒 Arms at launch, from the stores -------------------------------------

func test_a_town_that_stockpiled_guns_launches_an_armed_company() -> void:
	# This is what the defensive intents' stockpiling was always for. Until now
	# a governor under `drive_them_off` bought guns, held them, and never used
	# them.
	var run := _run()
	var armed := _town(run, 40_000, 500.0)
	run.world.month = 5
	var good := Raising.raise_from(armed, _context(run))
	assert_true(good.armed_share(&"guns") > 0.9,
		"a warehouse full of muskets armed nobody")

	var other := _run()
	var bare := _town(other, 40_000, 0.0)
	other.world.month = 5
	var mob := Raising.raise_from(bare, _context(other))
	assert_almost_eq(mob.armed_share(&"guns"), 0.0, 0.0001,
		"a town with no guns armed its men anyway")


func test_the_arms_come_out_of_the_warehouse() -> void:
	var run := _run()
	var town := _town(run, 40_000, 500.0)
	run.world.month = 5
	var company := Raising.raise_from(town, _context(run))
	assert_almost_eq(company.held(&"guns") + town.held(&"guns"), 500.0, 0.001,
		"muskets were conjured or lost in the muster")
	assert_true(town.held(&"guns") < 500.0, "it armed them out of nothing")


func test_it_takes_no_more_than_a_head_wants() -> void:
	# 🔒 §2: surplus does nothing. A town with ten thousand muskets does not send
	# them all.
	var run := _run()
	var town := _town(run, 40_000, 10_000.0)
	run.world.month = 5
	var company := Raising.raise_from(town, _context(run))
	assert_true(company.held(&"guns")
			<= Company.want_per_head(&"guns") * float(company.size) + 0.001,
		"the company marched out with the whole warehouse")


# --- 🔒 The order comes from the intent -------------------------------------

func test_defence_raises_a_militia_that_needs_nobody() -> void:
	var run := _run()
	var town := _town(run, 40_000)
	town.intent = GovernorIntent.MILITARY
	run.world.month = 5
	var company := Raising.raise_from(town, _context(run))
	assert_eq(company.order, StandingOrder.DEFEND_THE_TOWN)


func test_every_company_holds_its_town_until_it_chooses_its_own_order() -> void:
	# #428: *drive them off* went into *military*, which names no enemy; how a
	# company picks an order that leaves is #434's. Until then, every intent's
	# company holds the town.
	var run := _run()
	for intent in [GovernorIntent.MILITARY, GovernorIntent.SEDITION, GovernorIntent.GO_WIDE]:
		var town := _town(run, 40_000)
		town.intent = intent
		run.world.month = 5
		var company := Raising.raise_from(town, _context(run))
		assert_eq(company.order, StandingOrder.DEFEND_THE_TOWN,
			"a %s company was given an order nothing chose" % intent)


func test_preparing_for_rebellion_raises_a_militia() -> void:
	var run := _run()
	var town := _town(run, 40_000)
	town.intent = GovernorIntent.SEDITION
	run.world.month = 5
	assert_eq(Raising.raise_from(town, _context(run)).order,
		StandingOrder.DEFEND_THE_TOWN)


func test_the_order_is_not_a_separate_choice() -> void:
	# 🔒 §4's test applied rather than restated. Nothing anywhere asks the
	# governor which order to give.
	var code := _code_of("res://sim/battle/raising.gd")
	assert_true(code.contains("order_for"), "the order is not derived at all")
	for token in ["choose_order", "Deliberation.choose", "order_options"]:
		assert_false(code.contains(token),
			"the standing order is a second decision: %s" % token)


# --- 🔒 It reaches the world through Build ----------------------------------

func test_finishing_the_objective_puts_men_under_arms() -> void:
	var run := _run()
	var town := _town(run, 40_000, 500.0)
	town.objective = _raising_id()
	town.objective_intent = GovernorIntent.MILITARY
	town.objective_since = 1
	run.world.month = 9

	var had := run.companies.in_resolution_order().size()
	for month in range(1, 12):
		run.world.month = month
		BuildPhase.new().run(town, ColonySnapshot.of(run.colony), _context(run))
		if run.companies.in_resolution_order().size() > had:
			break
	assert_eq(run.companies.in_resolution_order().size(), had + 1,
		"the objective finished and nobody was raised")
	assert_true(String(town.objective).is_empty(),
		"the objective was not cleared")


func test_a_commander_is_found_when_it_is_time_to_move() -> void:
	# 🔒 Phase 4 puts men under arms; phase 2 of the next month is the first time
	# they could go anywhere, and that is where a man is needed.
	var run := _run()
	var town := _town(run, 40_000, 500.0)
	town.intent = GovernorIntent.MILITARY
	run.world.month = 5
	# A big company from a town of forty thousand has a man (#432), whatever
	# its order.
	var company := Raising.raise_from(town, _context(run))
	assert_true(company.is_headless(), "he was commissioned in the colony month")

	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	run.world.month = 6
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	assert_false(company.is_headless(),
		"a big company from a town of forty thousand had nobody to lead it")


func test_and_a_militia_is_never_given_one() -> void:
	# A scouting party is always a militia (#432), from however large a town —
	# **and whatever its order**: one sent off the town's ground (as #434 will
	# send it to explore) still has nobody deciding for it.
	var run := _run()
	var town := _town(run, 40_000)
	town.intent = GovernorIntent.GO_WIDE
	town.objective = &"scouting_company"
	run.world.month = 5
	var militia := Raising.raise_from(town, _context(run))
	militia.order = Raising.MARCH

	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	run.world.month = 6
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	assert_true(militia.is_headless(),
		"a scouting party was given a general")


# --- 🔒 Small and big (#432, `governor-agendas.md` §6) --------------------------

func _driver(run: RunState) -> CompanyDriver:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	return driver


func test_a_big_company_from_a_town_of_5000_has_no_commander_and_from_5001_one() -> void:
	# The worker floor is tuning (`battles.md` §1), and at the shipped figure no
	# town of five thousand can spare a big company at all. Lowered here, so the
	# rule under test is the only thing that differs.
	Raising.load_from({"worker_floor": 1_000})
	for pair in [[5_000, true], [5_001, false]]:
		var run := _run()
		var town := _town(run, int(pair[0]))
		town.intent = GovernorIntent.MILITARY
		town.objective = Raising.BIG
		run.world.month = 5
		var company := Raising.raise_from(town, _context(run))
		assert_true(company != null, "a town of %d raised nothing" % pair[0])
		run.world.month = 6
		_driver(run).on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
		assert_eq(company.is_headless(), bool(pair[1]),
			"a big company from a town of %d: headless is %s" % [pair[0], company.is_headless()])


func test_a_scouting_party_is_a_tenth_of_the_town_whatever_the_floor() -> void:
	# Sized for exploring rather than fighting (§6), so a town below the worker
	# floor still sends one.
	var run := _run()
	var small := _town(run, 3_000)
	assert_false(Raising.may_raise(small, Raising.BIG), "a town of three thousand spared a big company")
	assert_true(Raising.may_raise(small, &"scouting_company"))
	assert_eq(Raising.size_for(small, &"scouting_company"), 300)
	var large := _town(run, 40_000)
	assert_eq(Raising.size_for(large, &"scouting_company"), 4_000)


func test_a_militia_raised_in_month_n_goes_home_at_the_end_of_its_term() -> void:
	# `commanders.md` §3: it disbands where it stands, and its people are the
	# town's workers again that month. Raised in a month other than nought, so
	# the term is counted from the raising and not from the start of the run.
	var run := _run()
	var town := _town(run, 40_000, 20.0)
	town.intent = GovernorIntent.GO_WIDE
	town.objective = &"scouting_company"
	run.world.month = 7
	var militia := Raising.raise_from(town, _context(run))
	var raised := militia.size
	var armed := float(militia.arms.get("guns", 0.0))
	var before := town.workers
	var driver := _driver(run)

	run.world.month = 7 + Company.militia_months() - 1
	militia.was_supplied(run.world.month)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_false(militia.is_empty(), "it went home a month early")

	run.world.month = 7 + Company.militia_months()
	militia.was_supplied(run.world.month)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_true(militia.is_empty(), "it stood its term and stayed under arms")
	assert_eq(town.workers, before + raised, "its people did not rejoin the town")
	assert_true(armed > 0.0, "the fixture sent it out unarmed, so the next line proves nothing")
	assert_almost_eq(town.held(&"guns"), 20.0, 0.001, "its muskets did not come back into the stores")


func test_the_walk_raises_a_company_where_its_menu_says() -> void:
	# Go wide's first move is a scouting party to *find* land (§13, Filters);
	# a military town under threat raises a big company before anything else.
	var run := _run()
	var town := _town(run, 40_000)
	var context := _context(run)
	context.territory = Territory.compute(run.map, run.colony.in_order())
	# Nothing seen beyond the town's own ground, and nobody in the field.
	context.territory.visible = {}
	context.companies = Companies.new()
	assert_eq(String(ObjectiveSelector.choose(town, GovernorIntent.GO_WIDE, context)["id"]), "scouting_company")
	town.safety = 0.3
	assert_eq(String(ObjectiveSelector.choose(town, GovernorIntent.MILITARY, context)["id"]), "big_company")
	town.rebelling = true
	assert_false(Objective.is_company(StringName(ObjectiveSelector.choose(town, GovernorIntent.MILITARY, context)["id"])),
		"a rebel town raised a company through the Crown's machinery")


func test_who_leads_it_survives_the_save() -> void:
	var run := _run()
	var town := _town(run, 40_000)
	town.objective = &"scouting_company"
	var company := Raising.raise_from(town, _context(run))
	var restored := Company.from_dict(company.to_dict())
	assert_eq(String(restored.led_by), String(Company.MILITIA))
	assert_false(restored.wants_a_commander(), "a reloaded scouting party wanted a general")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _scripts_under(at: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			out.append_array(_scripts_under(at.path_join(entry)))
		elif entry.ends_with(".gd"):
			out.append(at.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out
