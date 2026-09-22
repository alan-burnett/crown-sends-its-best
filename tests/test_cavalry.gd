extends TestCase

## Losses take the supplies, and cavalry survives attrition (#217,
## `docs/mechanics/battles.md` §2, §6, §8).
##
## 🔒 **A company that loses a third of its people loses a third of everything it
## carries.** Ratios are preserved, so a fully supplied company stays fully
## supplied with less of everything — and **that single rule is what makes
## cavalry possible**, because a threshold on a ratio cannot be crossed by
## attrition.
##
## 🔒 **Cavalry is a threshold, not a type.** No separate unit and no flag, so
## crossing it in either direction changes behaviour immediately and nothing has
## to be told.
##
## 🔒 **A fort is never ignored.** Horses are no answer to a wall.
##
## 🔒 **A normal company moves and attacks in the same month** — not one or the
## other, or nothing could ever be chased down. Cavalry does both twice, which is
## a tempo advantage as much as a combat one: strike, reposition, strike again
## while the foot are still marching.

const SEED: int = 5171

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	NameBags.reset()
	Company.reset()
	Force.reset()
	Battle.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	NameBags.reset()
	Company.reset()
	Force.reset()
	Battle.reset()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	return context


func _arms(size: int, share: float = 1.0) -> Dictionary:
	var out: Dictionary = {}
	for resource in Company.armed_resources():
		out[String(resource)] = Company.want_per_head(StringName(resource)) \
			* float(size) * share
	return out


func _raise(
	run: RunState,
	allegiance: StringName,
	size: int,
	arms: Dictionary = {},
	at: Vector2i = Company.NOWHERE,
	order: StringName = StandingOrder.DEFEND_THE_TOWN,
) -> Company:
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		allegiance, size, arms, town.id,
		town.at if at == Company.NOWHERE else at, _context(run), order)
	# A commander, when the order calls for one — a headless militia never
	# initiates, and most of this file is about companies that do.
	Commanders.take_command(company, town, run, _context(run))
	return company


func _march(run: RunState) -> void:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	# **The roster, because the decision is a man's** (#221). A driver with no
	# contacts finds no commander and every company holds.
	driver.contacts = run.contacts
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)


const MARCH: StringName = &"march_on_the_enemy"


# --- 🔒 Losses take the supplies with them ---------------------------------

func test_a_third_of_the_people_is_a_third_of_every_cargo_line() -> void:
	var run := _run()
	var company := _raise(run, Company.REBEL, 30, _arms(30))
	var had: Dictionary = {}
	for resource in Company.armed_resources():
		had[String(resource)] = company.held(StringName(resource))

	company.take_casualties(10.0, &"mauled", _context(run))
	assert_eq(company.size, 20, "a third of thirty left %d" % company.size)
	for resource in Company.armed_resources():
		assert_almost_eq(company.held(StringName(resource)),
			float(had[resource]) * (2.0 / 3.0), 0.001,
			"a third of the men went and the %s did not" % resource)


func test_it_is_one_event_and_not_two() -> void:
	# The acceptance line: **in the same event.** A reader must not have to join
	# a loss of men to a loss of stores to know they were the same loss.
	var run := _run()
	var company := _raise(run, Company.REBEL, 30, _arms(30))
	company.take_casualties(10.0, &"mauled", _context(run))

	var told := run.log.of_type(Company.EVENT_DWINDLED)
	assert_eq(told.size(), 1, "one loss was reported %d times" % told.size())
	assert_true(told[0].payload.has("horsed"),
		"the event says how many men went and not what went with them")


func test_a_fully_supplied_company_stays_fully_supplied() -> void:
	var run := _run()
	var company := _raise(run, Company.REBEL, 40, _arms(40))
	var context := _context(run)
	for round in 5:
		company.take_casualties(5.0, &"mauled", context)
	assert_true(company.size < 40 and company.size > 0)
	for resource in Company.armed_resources():
		assert_almost_eq(company.armed_share(StringName(resource)), 1.0, 0.001,
			"it came out short of %s: %f"
				% [resource, company.armed_share(StringName(resource))])


# --- 🔒 Cavalry is a threshold, not a type ---------------------------------

func test_a_fully_horsed_company_remains_horsed_after_any_casualties() -> void:
	var run := _run()
	var mounted := _raise(run, Company.REBEL, 40, _arms(40))
	var context := _context(run)
	assert_true(mounted.is_cavalry())
	for round in 8:
		if mounted.is_empty():
			break
		mounted.take_casualties(4.0, &"mauled", context)
		assert_true(mounted.is_cavalry() or mounted.is_empty(),
			"it dismounted at %d men, %f horsed"
				% [mounted.size, mounted.armed_share(&"horses")])


func test_crossing_the_threshold_changes_behaviour_at_once() -> void:
	# 🔒 **No stored flag**, so there is nothing to tell and nothing to forget.
	var run := _run()
	var company := _raise(run, Company.REBEL, 20, _arms(20))
	assert_true(company.is_cavalry())
	assert_eq(company.tiles_this_month(), 2)

	company.arms["horses"] = float(company.arms["horses"]) * 0.5
	assert_false(company.is_cavalry(), "half the horses were still cavalry")
	assert_eq(company.tiles_this_month(), 1, "it went on riding")

	company.arms["horses"] = Company.want_per_head(&"horses") * float(company.size)
	assert_true(company.is_cavalry(), "remounting did not take")
	assert_eq(company.tiles_this_month(), 2)


func test_a_company_stores_no_flag_saying_it_is_cavalry() -> void:
	var company := Company.new(&"probe", 1)
	for entry in company.get_property_list():
		assert_false(String(entry["name"]).contains("cavalry"),
			"a company carries '%s', which is a flag the ratio already answers"
				% entry["name"])


# --- 🔒 Terrain and the wall ------------------------------------------------

func test_cavalry_attacking_pays_no_terrain_and_the_fort_in_full() -> void:
	var run := _run()
	var defender := _raise(run, Company.CROWN, 20, _arms(20))
	run.map.set_terrain(defender.at.x, defender.at.y, &"mountains")
	run.map.improvements[run.map.index_of(defender.at.x, defender.at.y)] = "fort"

	var horse := _raise(run, Company.REBEL, 20, _arms(20))
	var foot_arms := _arms(20)
	foot_arms["horses"] = 0.0
	var foot := _raise(run, Company.REBEL, 20, foot_arms)
	assert_true(horse.is_cavalry() and not foot.is_cavalry())

	var against_horse := Force.breakdown(defender, run.map, true, horse)
	var against_foot := Force.breakdown(defender, run.map, true, foot)
	assert_almost_eq(float(against_horse["terrain"]), 1.0, 0.001,
		"the mountain held against horse")
	assert_true(float(against_foot["terrain"]) > 1.0,
		"the mountain did nothing against foot")
	assert_almost_eq(float(against_horse["fortification"]),
		float(against_foot["fortification"]), 0.001,
		"horses rode over the wall")


# --- 🔒 Move and attack in the same month ----------------------------------

func test_a_company_moves_and_then_attacks_in_one_month() -> void:
	# 🔒 The acceptance line, and §8's reason for it: **not one or the other, or
	# nothing could ever be chased down.**
	var run := _run()
	var home := run.colony.in_order()[0].at
	var quarry := _raise(run, Company.CROWN, 20, {}, home + Vector2i(1, 0))
	var foot_arms := _arms(20)
	foot_arms["horses"] = 0.0
	var hunter := _raise(run, Company.REBEL, 20, foot_arms, home + Vector2i(-1, 0), MARCH)
	hunter.destination = quarry.at

	assert_false(Battle.are_in_contact(hunter, quarry),
		"the fixture started them already in contact")
	_march(run)

	assert_true(Battle.are_in_contact(hunter, quarry),
		"it did not march: %s against %s" % [hunter.at, quarry.at])
	assert_eq(run.log.of_type(Battle.EVENT_FOUGHT).size(), 1,
		"it marched into contact and did not fight")


func test_cavalry_strikes_repositions_and_strikes_again() -> void:
	# §8: a tempo advantage as much as a combat one. Two moves and two attacks in
	# the month, interleaved — which only works because the march is taken a tile
	# at a time.
	var run := _run()
	var home := run.colony.in_order()[0].at
	# A picket it will ride straight over, and the real target beyond it. A
	# company still standing after the first strike is one the second strike
	# cannot ride past, which is correct and is not what this is about.
	var picket := _raise(run, Company.CROWN, 1, {}, home + Vector2i(1, 0))
	var beyond := _raise(run, Company.CROWN, 20, {}, home + Vector2i(3, 0))
	var horse := _raise(run, Company.REBEL, 40, _arms(40), home, MARCH)
	horse.destination = beyond.at

	assert_true(horse.is_cavalry())
	_march(run)

	var fought := run.log.of_type(Battle.EVENT_FOUGHT)
	assert_eq(fought.size(), 2,
		"cavalry got through %d fights in a month" % fought.size())
	var struck := PackedStringArray()
	for event in fought:
		struck.append(String(event.payload.get("defender", "")))
	assert_true(struck.has(String(picket.id)) and struck.has(String(beyond.id)),
		"it did not strike, reposition and strike again: %s" % [struck])
	assert_true(picket.is_empty(), "the picket held")


func test_a_foot_company_gets_one_fight_a_month() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	_raise(run, Company.CROWN, 20, {}, home + Vector2i(1, 0))
	_raise(run, Company.CROWN, 20, {}, home + Vector2i(2, 0))
	var foot_arms := _arms(20)
	foot_arms["horses"] = 0.0
	var foot := _raise(run, Company.REBEL, 20, foot_arms, home, MARCH)
	foot.destination = home + Vector2i(3, 0)

	_march(run)
	assert_eq(run.log.of_type(Battle.EVENT_FOUGHT).size(), 1,
		"foot fought more than once in a month")


func test_a_headless_militia_never_initiates() -> void:
	# 🔒 `battles.md` §4: a leaderless militia defends its town, and that is the
	# whole of what it can ever do. It has nobody to decide where to go or when
	# to stop — and being attacked is not a decision.
	var run := _run()
	var home := run.colony.in_order()[0].at
	_raise(run, Company.RIVAL, 20, {}, home + Vector2i(1, 0))
	var militia := _raise(run, Company.COLONIAL, 40, _arms(40), home)

	assert_true(militia.is_headless(), "the fixture gave the militia a commander")
	_march(run)
	assert_empty(run.log.of_type(Battle.EVENT_FOUGHT),
		"a leaderless militia marched out and picked a fight")


func test_a_company_with_nobody_in_contact_simply_marches() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var lonely := _raise(run, Company.REBEL, 20, {}, home, MARCH)
	lonely.destination = home + Vector2i(3, 0)
	_march(run)
	assert_eq(lonely.at, home + Vector2i(1, 0), "it did not march")
	assert_empty(run.log.of_type(Battle.EVENT_FOUGHT))
	assert_eq(run.log.of_type(Company.EVENT_MOVED).size(), 1,
		"a month's marching was reported %d times"
			% run.log.of_type(Company.EVENT_MOVED).size())


# --- 🔒 Save and load -------------------------------------------------------

func test_a_cavalry_company_round_trips_mid_manoeuvre() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var horse := _raise(run, Company.REBEL, 33, _arms(33), home, MARCH)
	horse.destination = home + Vector2i(5, 2)
	_march(run)
	horse.take_casualties(2.5, &"mauled", _context(run))

	var restored := Companies.from_dict(run.companies.to_dict())
	var back := restored.find(horse.id)
	assert_true(back.is_cavalry(), "it came back on foot")
	assert_eq(back.at, horse.at, "it forgot where it had got to")
	assert_eq(back.destination, horse.destination, "it forgot where it was going")
	assert_almost_eq(back.casualties_owed, horse.casualties_owed, 0.0001,
		"the half man it owed was forgiven by the save")
	assert_eq(back.tiles_this_month(), 2)
