extends TestCase

## Safety comes alive, and what a battle costs in prestige (#219,
## `docs/mechanics/quality-of-life.md` §4, §6, `docs/mechanics/prestige.md` §4).
##
## 🔒 **Safety is not "is this town at war."** It is *is this town threatened by
## forces it cannot handle* — so it is a ratio and never a count, and a rebel
## town that has beaten what was sent against it is safe. That is precisely when
## it becomes most dangerous to the colony.
##
## 🔒 **It recovers when the threat passes.** Nothing decays and nothing
## remembers; §6 wants the loop running in both directions.
##
## 🔒 **It reads facts about the world and never rebel sentiment**, which is what
## keeps a month's computation acyclic while §12.3's spiral still runs.
##
## 🔒 **An exchange of casualties is not a defeat.** §6 of `battles.md` has no
## rout and no surrender, so the court hears about annihilation and not about a
## bad month.

const SEED: int = 6203

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


func _town(run: RunState, workers: int = 40) -> Town:
	var town := run.colony.in_order()[0]
	town.workers = workers
	town.experts = {}
	town.stockpile = {}
	town.buildings = PackedStringArray([String(Building.BASE)])
	town.months_hungry = 0
	town.battle_owed = 0.0
	return town


func _company(
	run: RunState, allegiance: StringName, size: int, at: Vector2i,
	arms: Dictionary = {}
) -> Company:
	return run.companies.raise_company(
		allegiance, size, arms, Company.SUPPORTED_BY_CROWN, at, _context(run))


func _safety(run: RunState, town: Town) -> float:
	return QualityOfLife.safety_of(town, _context(run))


# --- 🔒 Safety computes from real threat ------------------------------------

func test_a_town_with_nobody_near_it_is_wholly_safe() -> void:
	var run := _run()
	assert_almost_eq(_safety(run, _town(run)), 1.0, 0.0001)


func test_a_town_under_attack_feels_it() -> void:
	var run := _run()
	var town := _town(run, 20)
	var quiet := _safety(run, town)
	_company(run, Company.NATIVE, 400, town.at, {"guns": 400.0, "tools": 400.0})
	assert_true(_safety(run, town) < quiet,
		"four hundred armed men at the gate did not trouble the town")


func test_it_is_not_is_this_town_at_war() -> void:
	# 🔒 §6, and the heart of the component. A town that can see off what has
	# come for it is barely troubled; a town that cannot is terrified. **The same
	# war, two towns, two answers.**
	var run := _run()
	var town := _town(run, 400)
	var band := _company(
		run, Company.NATIVE, 60, town.at, {"guns": 60.0, "tools": 60.0})
	var unbothered := _safety(run, town)

	town.workers = 12
	var overwhelmed := _safety(run, town)

	assert_true(unbothered > 0.9,
		"a town of four hundred was frightened of sixty men: %f" % unbothered)
	assert_true(overwhelmed < 0.5,
		"the same sixty men barely troubled a town of twelve: %f" % overwhelmed)
	assert_eq(band.size, 60, "the fixture changed the raiders as well")


func test_a_militia_standing_with_the_town_is_felt() -> void:
	# What `battles.md` §4's running cost of defence actually buys. Otherwise a
	# governor who put men under arms has paid to feed them and gained nothing
	# his people can feel.
	var run := _run()
	var town := _town(run, 20)
	_company(run, Company.NATIVE, 400, town.at, {"guns": 400.0, "tools": 400.0})
	var alone := _safety(run, town)

	_company(run, Company.COLONIAL, 400, town.at, {"guns": 400.0, "tools": 400.0})
	assert_true(_safety(run, town) > alone,
		"a company drawn up in the town's defence made nobody feel better")


func test_the_roads_out_of_a_town_matter_too() -> void:
	# §4: *is it safe to travel to other towns.* A company does not have to
	# besiege a town to make life there worse.
	var run := _run()
	var town := run.colony.in_order()[0]
	var far := Town.new(&"outpost", "Outpost", town.at + Vector2i(6, 0))
	far.workers = 10
	run.colony.add(far)

	var quiet := _safety(run, town)
	_company(run, Company.NATIVE, 20, town.at + Vector2i(3, 0))
	var watched := _safety(run, town)

	assert_true(watched < quiet, "a company sitting on the only road changed nothing")
	assert_true(watched > 0.5,
		"a cut road frightened the town as much as a siege would: %f" % watched)


func test_a_town_with_nowhere_to_travel_fears_no_road() -> void:
	# The founding settlement's first years. The road it cannot use does not
	# exist yet.
	var run := _run()
	var town := _town(run, 20)
	while run.colony.in_order().size() > 1:
		run.colony.towns.remove_at(1)
	_company(run, Company.NATIVE, 20, town.at + Vector2i(4, 0))
	assert_almost_eq(_safety(run, town), 1.0, 0.0001,
		"the only town in the colony was afraid of a road to nowhere")


func test_safety_recovers_the_month_the_threat_is_gone() -> void:
	# 🔒 §6, and it runs in both directions: *if the town survives the danger,
	# its safety re-establishes and quality of life recovers.* Nothing decays,
	# because nothing remembers.
	var run := _run()
	var town := _town(run, 20)
	var raiders := _company(
		run, Company.NATIVE, 400, town.at, {"guns": 400.0, "tools": 400.0})
	assert_true(_safety(run, town) < 0.9, "the fixture never frightened anybody")

	raiders.lose(1.0, &"wiped_out", _context(run))
	run.companies.bury_the_dead()
	assert_almost_eq(_safety(run, town), 1.0, 0.0001,
		"the raiders were destroyed and the town stayed afraid")


func test_a_rebel_town_that_beat_what_was_sent_is_safe() -> void:
	# 🔒 §6's whole point, and it is not a rule anywhere — it falls out. The
	# Crown's company is gone, so there is nothing in contact, so there is no
	# threat. *That is precisely when it becomes most dangerous to the colony.*
	var run := _run()
	var town := _town(run, 40)
	town.rebelling = true
	var troops := _company(
		run, Company.CROWN, 400, town.at, {"guns": 400.0, "tools": 400.0})
	assert_true(_safety(run, town) < 0.9, "Crown troops at the gate troubled nobody")

	troops.lose(1.0, &"wiped_out", _context(run))
	run.companies.bury_the_dead()
	assert_almost_eq(_safety(run, town), 1.0, 0.0001,
		"a rebel town that won is still frightened")


func test_a_loyal_town_is_not_afraid_of_men_who_cannot_touch_it() -> void:
	# 🔒 §12.3's locks are filters on allegiance and nothing else
	# (`battles.md` §1). Rebels never fight loyal towns, so a loyal town that
	# feared them would be a second, quieter place those locks had to be kept.
	var run := _run()
	var town := _town(run, 20)
	_company(run, Company.REBEL, 400, town.at, {"guns": 400.0, "tools": 400.0})
	assert_almost_eq(_safety(run, town), 1.0, 0.0001,
		"a loyal town was frightened by rebels who may never attack it")


# --- 🔒 Quality of life moves with it ---------------------------------------

func test_a_town_under_attack_shows_a_quality_of_life_fall() -> void:
	# The acceptance line, through the whole path rather than through `safety_of`.
	var run := _run()
	var town := _town(run, 20)
	var context := _context(run)
	var quiet := float(QualityOfLife.of(town, context)["quality_of_life"])

	_company(run, Company.NATIVE, 400, town.at, {"guns": 400.0, "tools": 400.0})
	var outmatched := float(QualityOfLife.of(town, _context(run))["quality_of_life"])

	assert_true(outmatched < quiet,
		"quality of life did not move: %f then %f" % [quiet, outmatched])


func test_settle_writes_the_figure_the_town_lived_by() -> void:
	# `town.safety` is stored and moved only in Settle, and the Diplomat reports
	# it — so the figure he writes about and the figure the town lived by must be
	# the same one.
	var run := _run()
	var town := _town(run, 20)
	_company(run, Company.NATIVE, 400, town.at, {"guns": 400.0, "tools": 400.0})
	var context := _context(run)
	var parts := QualityOfLife.of(town, context)

	SettlePhase.new().run(town, ColonySnapshot.of(run.colony), context)
	assert_almost_eq(town.safety, float(parts["safety"]), 0.0001,
		"Settle stored a different safety from the one the parts reported")


# --- 🔒 Never by reading combat directly ------------------------------------

func test_rebel_sentiment_reaches_combat_only_through_quality_of_life() -> void:
	# 🔒 The acceptance line, and the acyclicity rule behind it (§7). Sentiment
	# reads quality of life, which reads safety, which reads the map. A sentiment
	# that reached past that to the battles themselves would be a second, shorter
	# path with no attribution on it — and §2's attribution is the only reason a
	# rebel town can ever be brought home.
	var found := PackedStringArray()
	var code := _code_of("res://sim/colony/rebel_sentiment.gd")
	for token in ["Battle", "Company", "Threat", "Force", "battle_fought",
			"company_destroyed", "town_stormed"]:
		if code.contains(token):
			found.append(token)
	assert_empty(found,
		"rebel sentiment reads combat directly: %s" % ", ".join(found))


func test_quality_of_life_never_reads_rebel_sentiment() -> void:
	# 🔒 The other half, and the older half. QoL feeds sentiment, so sentiment
	# reading back would close the loop inside a single month.
	for path in ["res://sim/colony/quality_of_life.gd", "res://sim/battle/threat.gd"]:
		assert_false(_code_of(path).contains("rebel_sentiment"),
			"%s reads rebel sentiment" % path.get_file())


# --- 🔒 Prestige: annihilation, not a bad month -----------------------------

func test_a_company_destroyed_fires_its_optic_exactly_once() -> void:
	var run := _run()
	var town := _town(run, 20)
	var doomed := _company(run, Company.NATIVE, 6, town.at)
	run.world.month = 1

	doomed.lose(1.0, &"wiped_out", _context(run))
	# And again, because the shape that fires twice is one that does not notice
	# it has already emptied.
	doomed.lose(1.0, &"wiped_out", _context(run))

	assert_eq(run.log.of_type(OpticsRegister.EVENT_COMPANY_DESTROYED).size(), 1)
	assert_almost_eq(OpticsRegister.debt_in(run.log),
		OpticsRegister.price_of(OpticsRegister.EVENT_COMPANY_DESTROYED), 0.0001,
		"one company wiped out cost the Crown something other than one optic")


func test_a_month_of_heavy_casualties_fires_none() -> void:
	# 🔒 **An exchange of casualties is not a defeat** (`prestige.md` §4). §6 has
	# no rout and no surrender, so there is no *battle lost* to price — the court
	# hears about annihilation, not about a bad month.
	var run := _run()
	var town := _town(run, 20)
	var mauled := _company(run, Company.NATIVE, 100, town.at)
	run.world.month = 1

	mauled.lose(0.6, &"fought", _context(run))
	assert_true(mauled.size > 0, "the fixture destroyed it, so this proves nothing")
	assert_true(mauled.size < 100, "nobody was lost, so this proves nothing")
	assert_almost_eq(OpticsRegister.debt_in(run.log), 0.0, 0.0001,
		"sixty men killed embarrassed the Crown")


func test_a_company_that_stood_down_is_not_a_defeat_either() -> void:
	var run := _run()
	var town := _town(run, 20)
	var militia := _company(run, Company.COLONIAL, 30, town.at)
	run.world.month = 1
	militia.stand_down(town, _context(run))

	assert_true(militia.is_empty())
	assert_almost_eq(OpticsRegister.debt_in(run.log), 0.0, 0.0001,
		"a militia that went home when its time was up embarrassed the Crown")


func test_nothing_that_emits_a_battle_event_knows_what_it_costs() -> void:
	# 🔒 `prestige.md` §4: **a mechanic emits the event, it never prices it.** Two
	# of the register's hooks came alive in M6 and neither file that fires them
	# has ever mentioned prestige — which is what makes a new optic a row in a
	# table rather than a change to the mechanic that causes it.
	var found := PackedStringArray()
	for path in ["res://sim/battle/company.gd", "res://sim/battle/battle.gd",
			"res://sim/battle/town_company.gd", "res://sim/colony/colony.gd"]:
		var code := _code_of(path)
		for token in ["OpticsRegister", "Prestige", "prestige"]:
			if code.contains(token):
				found.append("%s names %s" % [path.get_file(), token])
	assert_empty(found, "a mechanic prices its own event: %s" % ", ".join(found))


# --- Found in passing: two systems, one remainder ---------------------------

func test_a_neighbour_who_walks_in_is_not_logged_as_a_passenger() -> void:
	# 🔒 Seam A. Settlers off a ship and a tribe's people walking in from the next
	# valley are **different events**, and sharing one fractional accumulator
	# meant whichever crossed a whole number first spent the other's fraction.
	#
	# Found because #219's weights raised quality of life a little, which raised
	# immigration, which silently drained the pool every month — so the *more*
	# attractive a colony was, the less reliably it recorded the neighbours who
	# came to live in it.
	var town := Town.new(&"harbour", "Harbour", Vector2i(2, 2))
	town.arrivals_accrued = 0.97
	town.native_arrivals_accrued = 0.5
	var back := Town.from_dict(town.to_dict())
	assert_almost_eq(back.arrivals_accrued, 0.97, 0.0001)
	assert_almost_eq(back.native_arrivals_accrued, 0.5, 0.0001,
		"a saved run gave the neighbours' remainder away")

	assert_false(
		_code_of("res://sim/natives/native_help.gd").contains("town.arrivals_accrued"),
		"native arrivals still spend immigration's remainder")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
