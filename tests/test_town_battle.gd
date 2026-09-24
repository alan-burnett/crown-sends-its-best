extends TestCase

## A town is a company with a wall, and attacks depopulate fast (#218,
## `docs/mechanics/battles.md` §9, `CLAUDE.md`).
##
## 🔒 **Towns fight by the same arithmetic.** A town has population and supplies,
## so it computes force exactly as a company does — its own fortification, the
## terrain it stands on, and its defence buildings on top.
##
## 🔒 **There is no siege subsystem.** *A siege takes months* falls out of a hard
## target being worn down by §6's curve. No siege state, no stages, no second
## resolver.
##
## 🔒 **Armed attack depopulates fast, and that is the exception.** No event of
## hardship costs a town more than one population; overwhelming force takes a
## share, because a rule that metered a massacre out one man a month would make
## it read as a bad harvest.
##
## 🔒 **Workers go before experts, always** — under arms exactly as under famine.
##
## 🔒 **A town reduced to nothing is a lost town**, and fires exactly one optic.

const SEED: int = 5171

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


## The colony's first town, stripped to a known population and no wall but its
## own, so every figure below is one the test set.
func _town(run: RunState, workers: int = 40) -> Town:
	var town := run.colony.in_order()[0]
	# Fixture sizes are in thousands (#426).
	town.workers = workers * Population.THOUSAND
	town.experts = {}
	town.stockpile = {}
	town.buildings = PackedStringArray([String(Building.BASE)])
	town.months_hungry = 0
	town.battle_owed = 0.0
	return town


## What the town's own works are worth to it, the two halves put together the
## way `Force` puts them together.
func _wall(town: Town, defending: bool = true) -> float:
	return Force.wall_worth(Building.fortification_points_for(town), defending)


## A company of somebody else's, standing on the town.
func _besieger(
	run: RunState, size: int, at: Vector2i, arms: Dictionary = {}
) -> Company:
	return run.companies.raise_company(
		Company.NATIVE, size * Population.THOUSAND, arms, Company.SUPPORTED_BY_CROWN, at, _context(run))


## The same, under a man who can decide to press the attack.
func _under_a_commander(run: RunState, company: Company) -> Company:
	company.order = &"march_on_them"
	Commanders.take_command(company, run.colony.in_order()[0], run, _context(run))
	company.destination = company.at
	return company


# --- 🔒 A town computes force as a company does -----------------------------

func test_a_town_computes_force_from_what_it_is() -> void:
	var run := _run()
	var town := _town(run, 40)
	var wall := TownCompany.of(town)
	var parts := Force.breakdown(wall, run.map, true)

	assert_eq(int(parts["size"]), 40_000, "the town did not fight with its people")
	assert_true(float(parts["fortification"]) > 1.0,
		"a town with no wall at all is not §9's town")
	assert_true(float(parts["force"]) > 0.0)


func test_a_towns_experts_defend_it_too() -> void:
	var run := _run()
	var town := _town(run, 10)
	town.add_experts(&"tobacco", 5)
	assert_eq(TownCompany.of(town).size, 10_005,
		"the experts stayed indoors while the town was stormed")


func test_its_warehouse_is_its_armoury() -> void:
	var run := _run()
	var bare := Force.of(TownCompany.of(_town(run, 40)), run.map, true)

	var armed_town := _town(run, 40)
	armed_town.store(&"guns", 1_000.0)
	var armed := Force.of(TownCompany.of(armed_town), run.map, true)

	assert_true(armed > bare,
		"a town that stockpiled a thousand muskets fought no better for it")


func test_a_hungry_town_defends_worse() -> void:
	var run := _run()
	var fed := Force.of(TownCompany.of(_town(run, 40)), run.map, true)

	var starving := _town(run, 40)
	starving.months_hungry = 4
	var hungry := Force.of(TownCompany.of(starving), run.map, true)

	assert_true(hungry < fed, "famine did not reach the walls")


func test_defence_buildings_add_on_top_of_the_towns_own_wall() -> void:
	var run := _run()
	var town := _town(run, 40)
	var bare := _wall(town)
	assert_true(bare > 1.0, "the bare town fortifies nothing")

	town.buildings.append("stockade")
	var walled := _wall(town)
	town.buildings.append("palisade")
	var better := _wall(town)

	assert_true(walled > bare, "a stockade was worth nothing")
	assert_true(better > walled, "a palisade on top of it was worth nothing")


func test_a_wall_the_town_cannot_pay_for_is_not_a_wall_this_month() -> void:
	# It reads through `is_lit` like every other building effect (#151), which is
	# the counterweight the defence branch has otherwise never had.
	var run := _run()
	var town := _town(run, 40)
	town.buildings.append("stockade")
	town.buildings.append("palisade")
	var lit := _wall(town)

	town.dark_buildings = PackedStringArray(["palisade"])
	assert_true(_wall(town) < lit,
		"a town too poor to pay for its palisade still had one")


func test_the_ground_a_town_stands_on_matters_as_it_does_for_anyone() -> void:
	var run := _run()
	var town := _town(run, 40)
	var wall := TownCompany.of(town)
	assert_almost_eq(
		Force.terrain_of(wall, run.map, true),
		Force.terrain_worth(run.map.terrain_at(town.at.x, town.at.y)),
		0.0001,
		"a town got a different terrain figure from a company on the same tile")


func test_a_town_defends_and_never_attacks_from_its_wall() -> void:
	# 🔒 §9 gives the town a wall, not a sally port. Ground is taken by coming to
	# it, so there is no second figure to give a town and none is invented.
	var run := _run()
	var town := _town(run, 40)
	town.buildings.append("palisade")
	assert_almost_eq(_wall(town, false), 1.0, 0.0001,
		"a town was given an attacking bonus it can never use")


func test_a_veterans_siegecraft_discounts_a_towns_wall_as_it_does_a_fort() -> void:
	var run := _run()
	var town := _town(run, 40)
	town.buildings.append("palisade")
	var wall := TownCompany.of(town)

	var green := _besieger(run, 30, town.at)
	var plain := Force.fortification_of(wall, run.map, true, green)

	green.commander_level = CommanderExperience.top_level()
	var discounted := Force.fortification_of(wall, run.map, true, green)

	assert_true(discounted < plain, "siegecraft did not reach a town's wall")
	assert_true(discounted > 1.0, "siegecraft ignored the whole wall")


# --- 🔒 There is no siege subsystem -----------------------------------------

func test_no_siege_state_exists_anywhere() -> void:
	# 🔒 §9: *a dev who finds himself writing one has missed that the town is
	# already a combatant.* Asked of the codebase, because the temptation is
	# strongest on the day somebody wants a letter that says "month four of the
	# siege" and reaches for a counter to write it from.
	#
	# `siegecraft` is a commander's bonus (`commanders.md` §6), not a state, so it
	# is the one spelling allowed.
	var found := PackedStringArray()
	for path in _scripts_under("res://sim"):
		var code := _code_of(path)
		for line in code.split("\n"):
			var text := String(line)
			if text.to_lower().contains("siege") \
					and not text.to_lower().contains("siegecraft"):
				found.append("%s: %s" % [path.get_file(), text.strip_edges()])
	assert_empty(found, "something in the sim holds siege state: %s" % ", ".join(found))


func test_a_siege_takes_months_without_anything_saying_so() -> void:
	# The whole of §9's argument, run: a small company grinding a large town does
	# not kill anybody for months, and then does — and the *rate rises on its own*
	# as the town's force falls with its people.
	var run := _run()
	var town := _town(run, 40)
	var raiders := _besieger(run, 30, town.at, {"guns": 30.0})

	# **What one population used to be** (#426): at the people scale a man falls
	# in the first month, and what takes months is the first thousand. And the
	# grind accelerates only against a besieger that outguns the town: counted in
	# people, a weaker one is worn down faster than it wears, which the old
	# thousands hid by rounding everything below one to nobody.
	var first_death := -1
	var lost_so_far := 0
	var early := 0
	var late := 0
	for month in range(1, 61):
		run.world.month = month
		var before := town.population()
		if before <= 0:
			break
		Battle.resolve(raiders, TownCompany.of(town, raiders), run.map, _context(run))
		var killed := before - town.population()
		lost_so_far += killed
		if lost_so_far >= Population.THOUSAND and first_death < 0:
			first_death = month
		if month <= 12:
			early += killed
		elif month <= 24:
			late += killed

	assert_true(first_death > 1,
		"the first thousand died in month %d, which is not a siege" % first_death)
	assert_true(late > early,
		"the grind did not accelerate: %d in the first year, %d in the second"
			% [early, late])


func test_the_fraction_owed_survives_the_month() -> void:
	# 🔒 Without this the view is rebuilt each month, the remainder is thrown away
	# and a besieger inflicting less than a whole man a month kills nobody ever.
	var run := _run()
	var town := _town(run, 40)
	var raiders := _besieger(run, 6, town.at)

	Battle.resolve(raiders, TownCompany.of(town, raiders), run.map, _context(run))
	assert_true(town.battle_owed > 0.0,
		"a month of fighting left the town owing nothing at all")
	assert_true(town.population() > 40_000 - Population.THOUSAND,
		"six thousand men took a thousand from a fortified town of forty thousand in a month")


# --- 🔒 Attacks depopulate fast, and famine does not ------------------------

func test_a_battle_can_take_several_in_one_month() -> void:
	# 🔒 **Overwhelming force takes a share.** The exception, and the point of it.
	var run := _run()
	var town := _town(run, 40)
	var host := _besieger(run, 600, town.at, {"guns": 600.0, "tools": 600.0})

	run.world.month = 1
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))
	assert_true(40_000 - town.population() > Population.THOUSAND,
		"six hundred thousand men under arms took barely a thousand from a town of forty thousand")


func test_one_event_names_everybody_in_it() -> void:
	var run := _run()
	var town := _town(run, 40)
	var host := _besieger(run, 600, town.at, {"guns": 600.0, "tools": 600.0})

	run.world.month = 1
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))
	var stormed := run.log.of_type(TownCompany.EVENT_STORMED)
	assert_eq(stormed.size(), 1, "a storming emitted %d events" % stormed.size())
	assert_eq(int(stormed[0].payload.get("lost", 0)), 40_000 - town.population(),
		"the event does not say how many it took")


func test_famine_still_cannot() -> void:
	# 🔒 `CLAUDE.md`: famine and war take a share the same way (#427) — one
	# event a month, saying how many. What differs is how many, never the shape.
	var run := _run()
	var town := _town(run, 40)
	town.months_hungry = 12
	town.stockpile = {}

	var before := run.log.of_type(ConsumePhase.EVENT_FAMINE).size()
	var head := town.population()
	for month in range(1, 4):
		run.world.month = month
		ConsumePhase.new().run(town, ColonySnapshot.of(run.colony), _context(run))
	var died := head - town.population()
	var counted := 0
	var events := run.log.of_type(ConsumePhase.EVENT_FAMINE)
	assert_eq(events.size() - before, 3, "three famine months were not three events")
	for index in range(before, events.size()):
		counted += int(events[index].payload["count"])
	assert_eq(counted, died, "%d died of famine and the events counted %d" % [died, counted])


func test_a_town_keeps_its_stores_though_it_loses_its_people() -> void:
	# 🔒 `CLAUDE.md`: a body of people **in the open** loses a share of its stores
	# with its people. A town's warehouse is not on its back.
	var run := _run()
	var town := _town(run, 40)
	town.store(&"food", 500.0)
	town.store(&"guns", 100.0)
	var host := _besieger(run, 600, town.at, {"guns": 600.0, "tools": 600.0})

	run.world.month = 1
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))
	assert_true(town.population() < 40_000, "nobody was lost, so this proves nothing")
	assert_almost_eq(town.held(&"food"), 500.0, 0.0001, "the granary was sacked")
	assert_almost_eq(town.held(&"guns"), 100.0, 0.0001, "the armoury was sacked")


# --- 🔒 Workers before experts, always --------------------------------------

func test_workers_are_lost_before_experts_under_arms() -> void:
	# Asked as the invariant rather than as an outcome, because how many a given
	# assault takes depends on the ground the map happened to put the town on.
	# **At no point may an expert be gone while a worker remains.**
	var run := _run()
	var town := _town(run, 20)
	town.add_experts(&"tobacco", 6)
	var raiders := _besieger(run, 60, town.at, {"guns": 60.0})

	var took_a_worker := false
	for month in range(1, 25):
		run.world.month = month
		if town.population() <= 0:
			break
		Battle.resolve(raiders, TownCompany.of(town, raiders), run.map, _context(run))
		if town.workers < 20_000:
			took_a_worker = true
		if town.expert_count(&"tobacco") < 6:
			assert_eq(town.workers, 0,
				"an expert was killed in month %d while %d workers still stood"
					% [month, town.workers])
	assert_true(took_a_worker, "nobody was lost at all, so this proves nothing")


func test_experts_go_only_when_no_worker_remains() -> void:
	var run := _run()
	var town := _town(run, 0)
	town.add_experts(&"tobacco", 4)
	town.add_experts(&"sugar", 4)

	var lost := PackedStringArray()
	for _each in 3:
		lost.append(town.take_one_life())
	assert_eq(lost, PackedStringArray(["sugar", "sugar", "sugar"]),
		"experts were not taken in sorted order: %s" % [lost])


func test_the_rule_has_exactly_one_home() -> void:
	# 🔒 A second implementation is how *workers before experts* stops being true
	# somewhere. Famine and a storming both call `Town.take_one_life`.
	#
	# ⚠️ **What is forbidden is a second *ordering*, not every write to
	# `workers`.** People also leave a town alive — an expedition takes them
	# (`founding-towns.md` §7) and #342's company enlists them — and those are
	# **transfers rather than losses**: the men still exist somewhere, and nobody
	# had to decide whose turn it was to die.
	#
	# The first cut of this scanned for `workers -=` and passed only because
	# `Expedition` happens to spell it `workers - going`. So the test asks the
	# question it means: **a file that removes workers *and* removes experts is
	# deciding an order**, and there may be exactly one of those.
	var found := PackedStringArray()
	for path in _scripts_under("res://sim"):
		if path.ends_with("town.gd"):
			continue
		var code := _code_of(path)
		var takes_workers := code.contains("workers -=") or code.contains("workers - ")
		var takes_experts := code.contains("add_experts(") and code.contains("-1")
		if takes_workers and takes_experts:
			found.append(path.get_file())
	assert_empty(found,
		"something decides its own loss order: %s" % ", ".join(found))


# --- 🔒 A town reduced to nothing is a lost town ----------------------------

func test_a_town_reduced_to_nothing_leaves_the_colony() -> void:
	var run := _run()
	var town := _town(run, 8)
	var had := run.colony.in_order().size()
	var host := _besieger(run, 4_000, town.at, {"guns": 4_000.0, "tools": 4_000.0})

	run.world.month = 1
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))

	assert_eq(town.population(), 0, "the town survived, so this proves nothing")
	assert_eq(run.colony.in_order().size(), had - 1, "the town is still in the colony")
	assert_true(run.colony.by_id(town.id) == null, "the town can still be found by id")


func test_a_town_lost_fires_exactly_one_optic() -> void:
	# 🔒 Not `company_destroyed` as well. A town emitting both would have the
	# court hear about one disaster twice and charge for it twice
	# (`prestige.md` §4).
	var run := _run()
	var town := _town(run, 8)
	var host := _besieger(run, 4_000, town.at, {"guns": 4_000.0, "tools": 4_000.0})

	run.world.month = 1
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))

	var optics := 0
	for event in run.log.all():
		if OpticsRegister.is_an_optic(event.type) and String(event.subject) == String(town.id):
			optics += 1
	assert_eq(optics, 1, "a town was stormed and the court heard about it %d times" % optics)
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 1)
	assert_empty(run.log.of_type(Company.EVENT_DESTROYED),
		"a town lost was also reported as a company wiped out")


func test_a_town_that_holds_fires_no_optic() -> void:
	var run := _run()
	var town := _town(run, 40)
	var raiders := _besieger(run, 12, town.at, {"guns": 12.0})

	for month in range(1, 7):
		run.world.month = month
		Battle.resolve(raiders, TownCompany.of(town, raiders), run.map, _context(run))

	assert_true(town.population() > 0, "the town fell, so this proves nothing")
	assert_empty(run.log.of_type(Colony.EVENT_LOST))


# --- 🔒 §12.3's locks still hold --------------------------------------------

func test_the_colonys_own_militia_cannot_march_on_a_town() -> void:
	# 🔒 *Colonists do not fight colonists*, and it is a filter on allegiance and
	# nothing else — so presenting a town as a company applies it for free rather
	# than needing a rule of its own.
	var run := _run()
	var town := _town(run, 40)
	var militia := run.companies.raise_company(
		Company.COLONIAL, 30_000, {}, town.id, town.at, _context(run))
	assert_false(Battle.may_fight(militia, TownCompany.of(town, militia)))

	town.rebelling = true
	assert_false(Battle.may_fight(militia, TownCompany.of(town, militia)),
		"the colony's militia marched on a rebel town")


func test_crown_troops_may_take_a_rebel_town_and_not_a_loyal_one() -> void:
	var run := _run()
	var town := _town(run, 40)
	var troops := run.companies.raise_company(
		Company.CROWN, 30_000, {}, Company.SUPPORTED_BY_CROWN, town.at, _context(run))
	assert_false(Battle.may_fight(troops, TownCompany.of(town, troops)),
		"Crown troops fired on a loyal town")

	town.rebelling = true
	assert_true(Battle.may_fight(troops, TownCompany.of(town, troops)),
		"Crown troops could not put down a rebellion")


# --- The commander in front of it -------------------------------------------

func test_a_company_finds_a_town_in_front_of_it() -> void:
	var run := _run()
	var town := _town(run, 40)
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders

	var raiders := _under_a_commander(
		run, _besieger(run, 400, town.at, {"guns": 400.0, "tools": 400.0}))
	run.world.month = 1
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	var fought := run.log.of_type(Battle.EVENT_FOUGHT)
	assert_false(fought.is_empty(),
		"a hostile company stood on a town for a month and did not fight it")
	assert_eq(String(fought[0].payload.get("defender", "")), String(town.id),
		"it fought something, but not the town it was standing on")
	assert_eq(String(raiders.id), String(fought[0].payload.get("attacker", "")))


func test_a_company_cannot_stroll_past_a_defender_to_the_town_behind_it() -> void:
	# 🔒 **Ground is taken only when the last defender is gone** (§6), and a
	# town's field army is a defender. Companies before towns.
	var run := _run()
	var town := _town(run, 40)
	var militia := run.companies.raise_company(
		Company.COLONIAL, 20_000, {}, town.id, town.at, _context(run))

	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders

	var raiders := _under_a_commander(
		run, _besieger(run, 400, town.at, {"guns": 400.0, "tools": 400.0}))
	run.world.month = 1
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	var fought := run.log.of_type(Battle.EVENT_FOUGHT)
	assert_false(fought.is_empty(), "nothing fought at all")
	for event in fought:
		assert_eq(String(event.payload.get("defender", "")), String(militia.id),
			"the raiders went past the militia and struck the town")
	assert_eq(town.population(), 40_000, "the town lost people with its militia intact")
	assert_empty(run.log.of_type(TownCompany.EVENT_STORMED))


# --- Save and load -----------------------------------------------------------

func test_the_fraction_owed_survives_a_save() -> void:
	# Ironman: a run reloaded mid-siege must not hand the town back the men it
	# had already lost the arithmetic for.
	var town := Town.new(&"harbour", "Harbour", Vector2i(3, 4))
	town.workers = 20
	town.battle_owed = 0.61
	var back := Town.from_dict(town.to_dict())
	assert_almost_eq(back.battle_owed, 0.61, 0.0001,
		"a saved siege gave the town its casualties back")


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
