extends TestCase

## Force: one number per company (#214, `docs/mechanics/battles.md` §2, §5).
##
## 🔒 **Terrain folds into force and appears nowhere else.** It is not a
## defender's bonus applied at resolution — it multiplies into the defender's
## force here, and attacker and defender are then **equal actors with no second
## adjustment anywhere.** A dev who adds a defender's bonus at resolution has
## double-counted it, and the letters will describe a mismatch that did not
## happen, which SPEC §9.1 makes a correctness bug.
##
## 🔒 **Surplus does nothing.** Ten times the muskets is not ten times the
## company, and a company at half its wanted guns is measurably weaker than one
## at full.
##
## 🔒 **And force is derived, never stored.** A company that kept its force would
## have two answers to what it is worth the moment it lost a man.

const SEED: int = 3313

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


func _raise(run: RunState, size: int = 20, arms: Dictionary = {}) -> Company:
	var town := run.colony.in_order()[0]
	return run.companies.raise_company(
		Company.COLONIAL, size, arms, town.id, town.at, _context(run))


## A tile of known ground, so terrain is the test's and not the seed's.
func _standing_on(run: RunState, company: Company, terrain: StringName) -> void:
	run.map.set_terrain(company.at.x, company.at.y, terrain)


## A fort where the company stands. Written straight onto the map rather than
## through `build`, which refuses ground a fort cannot go on — the question here
## is what a fort is worth, not where one may be put.
func _fortify(run: RunState, company: Company) -> void:
	run.map.improvements[run.map.index_of(company.at.x, company.at.y)] = "fort"


# --- 🔒 One number, from the six factors ------------------------------------

func test_force_is_the_product_of_the_six_factors() -> void:
	var run := _run()
	var company := _raise(run, 20, _arms(20))
	company.commander = &"commander_one"

	var parts := Force.breakdown(company, run.map)
	var product := float(parts["size"]) * float(parts["arms"]) \
		* float(parts["leadership"]) * float(parts["supply"]) \
		* float(parts["terrain"]) * float(parts["fortification"])
	assert_almost_eq(float(parts["force"]), product, 0.001,
		"the total is not the product of what it is made of")
	for factor in ["size", "arms", "leadership", "supply", "terrain", "fortification"]:
		assert_has(parts, factor, "the breakdown does not carry '%s'" % factor)


func test_an_empty_company_is_worth_nothing() -> void:
	var run := _run()
	var company := _raise(run, 4, _arms(4))
	company.lose(1.0, &"wiped_out", _context(run))
	assert_almost_eq(Force.of(company, run.map), 0.0, 0.001,
		"a company with nobody in it still had a force")
	assert_almost_eq(Force.of(null, run.map), 0.0, 0.001)


func test_more_men_is_more_force() -> void:
	var run := _run()
	var small := _raise(run, 10, _arms(10))
	var large := _raise(run, 30, _arms(30))
	assert_true(Force.of(large, run.map) > Force.of(small, run.map),
		"thirty armed men were not worth more than ten")


# --- 🔒 Arms are a supply ratio, and surplus does nothing -------------------

func test_half_the_guns_is_measurably_weaker_than_all_of_them() -> void:
	# The acceptance line, stated as written.
	var run := _run()
	var full := _raise(run, 20, _arms(20))
	var half_armed := _arms(20)
	half_armed["guns"] = float(half_armed["guns"]) * 0.5
	var half := _raise(run, 20, half_armed)

	assert_true(Force.of(half, run.map) < Force.of(full, run.map),
		"a company at half its guns was no weaker: %f against %f"
			% [Force.of(half, run.map), Force.of(full, run.map)])


func test_surplus_arms_contribute_nothing() -> void:
	# 🔒 §2, and the reason `armed_share` caps. Ten times the muskets is not ten
	# times the company.
	var run := _run()
	var full := _raise(run, 20, _arms(20))
	var heaps := _raise(run, 20, _arms(20, 10.0))
	assert_almost_eq(Force.of(heaps, run.map), Force.of(full, run.map), 0.001,
		"ten times the arms made a stronger company")


func test_each_of_the_three_is_worth_something_on_its_own() -> void:
	# 🔒 **Tools are a weapon here, not a toolbox** (§2) — trenches dug,
	# battlements thrown up, muskets kept firing. A resource that multiplied by
	# one would be one the player could stop sending with no consequence.
	var run := _run()
	var bare := _raise(run, 20, {})
	for resource in Company.armed_resources():
		var only: Dictionary = {}
		only[String(resource)] = Company.want_per_head(StringName(resource)) * 20.0
		var armed := _raise(run, 20, only)
		assert_true(Force.of(armed, run.map) > Force.of(bare, run.map),
			"a company supplied with %s alone was worth no more than an unarmed mob"
				% resource)


func test_an_unarmed_mob_is_still_worth_its_men() -> void:
	var run := _run()
	var mob := _raise(run, 20, {})
	assert_true(Force.of(mob, run.map) >= 20.0,
		"twenty men with nothing were worth less than nothing")


# --- 🔒 Leadership and supply -----------------------------------------------

func test_a_commander_is_worth_something_and_none_is_not_a_penalty() -> void:
	# §4: leadership is **agency before it is a bonus**, so a leaderless company
	# is not a broken one.
	var run := _run()
	var led := _raise(run, 20, _arms(20))
	var leaderless := _raise(run, 20, _arms(20))
	assert_almost_eq(Force.leadership_of(leaderless), 1.0, 0.001,
		"a company with no commander was penalised for it")

	led.commander = &"commander_one"
	assert_true(Force.of(led, run.map) > Force.of(leaderless, run.map),
		"a commander was worth nothing")


func test_an_unsupported_companys_force_falls_and_recovers() -> void:
	# The acceptance line. §3: effectiveness falls **at once**, and it recovers
	# the moment supply resumes.
	var run := _run()
	var company := _raise(run, 40, _arms(40))
	var fed := Force.of(company, run.map)

	company.go_without(_context(run))
	var hungry := Force.of(company, run.map)
	assert_true(hungry < fed,
		"a company nobody fed was as strong as one that ate: %f against %f"
			% [hungry, fed])

	# Its men are gone as well as its rations, so the comparison that isolates
	# supply is the factor itself.
	assert_true(float(Force.breakdown(company, run.map)["supply"]) < 1.0)
	company.was_supplied(run.world.month)
	assert_almost_eq(float(Force.breakdown(company, run.map)["supply"]), 1.0, 0.001,
		"a company fed again was still worth less for it")


# --- 🔒 Terrain is the defender's, and it appears nowhere else --------------

func test_terrain_helps_the_defender_and_not_the_attacker() -> void:
	var run := _run()
	var company := _raise(run, 20, _arms(20))
	_standing_on(run, company, &"mountains")

	var attacking := Force.of(company, run.map, false)
	var defending := Force.of(company, run.map, true)
	assert_true(defending > attacking,
		"a mountain was worth nothing to the man standing on it")
	assert_almost_eq(float(Force.breakdown(company, run.map, false)["terrain"]), 1.0, 0.001,
		"the attacker took his mountain with him")


func test_the_three_tiers_are_ordered() -> void:
	# §5's table: mountains high, forest medium, plains low.
	assert_true(Force.terrain_worth(&"mountains") > Force.terrain_worth(&"forest"),
		"a forest is better cover than a mountain")
	assert_true(Force.terrain_worth(&"forest") > Force.terrain_worth(&"plains"),
		"plains are better cover than a forest")
	assert_almost_eq(Force.terrain_worth(&"plains"), 1.0, 0.001,
		"open ground is an advantage")


func test_ground_nobody_has_written_about_is_open_ground() -> void:
	# It must not silently become cover, and it must never be a penalty.
	assert_almost_eq(Force.terrain_worth(&"a_terrain_nobody_has_written"), 1.0, 0.001)


func test_cavalry_attacking_ignores_the_ground() -> void:
	# 🔒 §8, and the reason terrain and fortification are separate terms.
	var run := _run()
	var defender := _raise(run, 20, _arms(20))
	_standing_on(run, defender, &"mountains")
	var horse := _raise(run, 20, _arms(20))
	var foot := _raise(run, 20, _arms(20))
	foot.arms["horses"] = 0.0

	assert_true(horse.is_cavalry() and not foot.is_cavalry(),
		"the fixture did not actually make one of them cavalry")
	assert_true(
		Force.of(defender, run.map, true, horse) < Force.of(defender, run.map, true, foot),
		"the mountain held against horse exactly as it held against foot")


func test_horses_are_no_answer_to_a_wall() -> void:
	# 🔒 §8: **a fort is never ignored.** If the two terms were one, cavalry would
	# ride over a wall.
	var run := _run()
	var defender := _raise(run, 20, _arms(20))
	_standing_on(run, defender, &"mountains")
	_fortify(run, defender)
	var horse := _raise(run, 20, _arms(20))

	var parts := Force.breakdown(defender, run.map, true, horse)
	assert_almost_eq(float(parts["terrain"]), 1.0, 0.001,
		"cavalry did not ignore the mountain after all")
	assert_true(float(parts["fortification"]) > 1.0,
		"cavalry rode over the wall as well")


func test_a_fort_helps_whoever_holds_it_and_helps_a_defender_more() -> void:
	var run := _run()
	var company := _raise(run, 20, _arms(20))
	_fortify(run, company)

	assert_true(Force.fort_worth(&"fort", false) > 1.0,
		"a company attacking from a fort got nothing for it")
	assert_true(Force.fort_worth(&"fort", true) > Force.fort_worth(&"fort", false),
		"a fort is worth no more to the man defending it")
	assert_true(float(Force.breakdown(company, run.map, true)["fortification"]) > 1.0,
		"the fort on his tile was not read at all")


func test_a_rebel_in_a_fort_on_a_mountain_is_close_to_unassailable() -> void:
	# §5 says so in as many words, and it is meant to be. The answer is not a
	# better army — it is wearing them down over years.
	var run := _run()
	var holed_up := _raise(run, 20, _arms(20))
	_standing_on(run, holed_up, &"mountains")
	_fortify(run, holed_up)
	var attacker := _raise(run, 20, _arms(20))
	attacker.arms["horses"] = 0.0

	var theirs := Force.of(holed_up, run.map, true, attacker)
	var mine := Force.of(attacker, run.map, false)
	assert_true(theirs > mine * 3.0,
		"twenty men in a fort on a mountain were worth %f against %f in the open"
			% [theirs, mine])


func test_terrain_and_fortification_appear_in_force_and_nowhere_else() -> void:
	# 🔒 **The acceptance line, and the double-count guard.** If either term is
	# ever applied a second time at resolution, it will be because somebody added
	# a **reader** outside this file — so this asks the codebase for call sites
	# rather than for the words.
	#
	# The authored figures themselves live where the thing is (#215): a terrain's
	# defence beside its yields, a fort's two figures beside its cost. Declaring
	# them there is not reading them, which is why the tokens below are the
	# qualified forms a caller writes and never the forms a definition does.
	var readers := PackedStringArray()
	for path in _sim_scripts():
		if path.ends_with("force.gd"):
			continue
		var code := _code_of(path)
		for token in ["Force.terrain_worth", "Force.fort_worth",
				"Terrain.defence_of", ".defence_for("]:
			if code.contains(token):
				readers.append("%s calls %s" % [path.get_file(), token])
	assert_empty(readers,
		"terrain or fortification is read outside force: %s" % ", ".join(readers))


## A script with its comments taken out.
##
## **The lock is about call sites, not prose.** `terrain.gd` says in its header
## that `Force.terrain_worth` is the only thing that asks for its figure, and a
## scan that counted the explanation would forbid explaining it.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _sim_scripts(at: String = "res://sim") -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := at.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_sim_scripts(path))
		elif entry.ends_with(".gd"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


# --- 🔒 Derived, never stored -----------------------------------------------

func test_losing_men_lowers_the_force_at_once() -> void:
	# §6's grind falls out of this: every loss lowers the loser's force and raises
	# the winner's ratio next month, and nothing schedules it.
	var run := _run()
	var company := _raise(run, 40, _arms(40))
	var before := Force.of(company, run.map)
	company.lose(0.5, &"mauled", _context(run))
	assert_true(Force.of(company, run.map) < before,
		"a company that lost half its men was as strong as before")


func test_a_company_stores_no_force_of_its_own() -> void:
	var company := Company.new(&"probe", 1)
	for entry in company.get_property_list():
		assert_false(String(entry["name"]).contains("force"),
			"a company carries '%s', which is a second answer to what it is worth"
				% entry["name"])


# --- Emitted where a reader can see it --------------------------------------

func test_raising_a_company_says_what_it_is_worth() -> void:
	# §5's acceptance asks that force ride along with a battle event so a letter
	# can describe a mismatch truthfully. Nothing fights yet, so the event that
	# exists carries it: arming a company is an allocation the PC paid for, and a
	# report that could only count heads could not tell him whether it mattered.
	var run := _run()
	_raise(run, 20, _arms(20))
	var raised := run.log.of_type(Company.EVENT_RAISED)
	assert_eq(raised.size(), 1)
	var parts: Dictionary = raised[0].payload.get("force", {})
	assert_true(float(parts.get("force", 0.0)) > 0.0,
		"the raising said nothing about what was raised: %s" % [parts])
	assert_has(parts, "arms", "the payload cannot say why it is worth that")
