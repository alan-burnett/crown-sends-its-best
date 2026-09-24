extends TestCase

## Experience: casualties inflicted, and what levels buy (#223,
## `docs/mechanics/commanders.md` §6).
##
## 🔒 **Casualties inflicted, and nothing else.** Not battles won, because
## `battles.md` §6 has no rout and no surrender — *winning* is not a quantity
## that exists, and a battle exchanges losses and that is all.
##
## It scales correctly on its own: **grinding a fort down over two years earns
## far more than a skirmish**, and a commander who has done nothing but garrison
## duty learns nothing.
##
## 🔒 **Every bonus is data naming a knob**, never a branch on a level number —
## so the Author can add a seventh without a code change, and a knob nothing
## reads is refused by the validator.
##
## 🔒 **They stack**, and a long-lived commander becomes genuinely formidable.
## That is intended: he is the one competent person in the PC's employ, and the
## PC cannot direct him.
##
## 🔒 **Husbandry reduces what is wanted and never adds.** A company only ever
## dwindles; arming more men with the same cargo is a change to the appetite, not
## a delivery.

const SEED: int = 6640

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


const MARCH: StringName = &"march_on_them"


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	return context


func _arms(size: int) -> Dictionary:
	var out: Dictionary = {}
	for resource in Company.armed_resources():
		out[String(resource)] = Population.amount_for(StringName(resource),
			Company.want_per_head(StringName(resource)), float(size * Population.THOUSAND))
	return out


func _raise(
	run: RunState,
	allegiance: StringName,
	size: int,
	at: Vector2i = Company.NOWHERE,
	arms: Dictionary = {},
	order: StringName = MARCH,
) -> Company:
	var town := run.colony.in_order()[0]
	# Fixture sizes are in thousands (#426): a company of `40` is 40,000 men.
	var company := run.companies.raise_company(
		allegiance, size * Population.THOUSAND, arms, town.id,
		town.at if at == Company.NOWHERE else at, _context(run), order)
	Commanders.take_command(company, town, run, _context(run))
	return company


## A company whose commander has risen this far, without fighting for it.
func _at_level(company: Company, level: int) -> Company:
	company.commander_level = level
	return company


# --- 🔒 Casualties inflicted, and nothing else -----------------------------

func test_a_commander_learns_from_what_his_company_inflicted() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 200, home)
	var theirs := _raise(run, Company.CROWN, 20, home + Vector2i(1, 0))

	Battle.resolve(mine, theirs, run.map, _context(run))
	assert_true(run.commanders.inflicted_by(mine.commander) > 0.0,
		"he fought a battle and learned nothing")


func test_both_sides_learn_because_both_inflicted_something() -> void:
	# A defender who ground down an assault has learned from it as surely as the
	# man who ordered it — there is no winner to be the only one who learns.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 60, home)
	var theirs := _raise(run, Company.CROWN, 60, home + Vector2i(1, 0))

	Battle.resolve(mine, theirs, run.map, _context(run))
	assert_true(run.commanders.inflicted_by(mine.commander) > 0.0)
	assert_true(run.commanders.inflicted_by(theirs.commander) > 0.0,
		"the man who was attacked learned nothing from it")


func test_it_is_casualties_and_not_battles() -> void:
	# 🔒 **The acceptance line, and the one a count of battles would pass.** Two
	# commanders, one battle each — and the man who destroyed a company has
	# learned more than the man who traded a scratch.
	#
	# `battles.md` §6 has no rout and no surrender, so *winning* is not a quantity
	# that exists. What exists is what you did to them.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var context := _context(run)

	var slaughter := _raise(run, Company.REBEL, 400, home)
	Battle.resolve(slaughter, _raise(run, Company.CROWN, 10,
		home + Vector2i(1, 0)), run.map, context)

	var skirmish := _raise(run, Company.REBEL, 20, home + Vector2i(0, 3))
	Battle.resolve(skirmish, _raise(run, Company.CROWN, 20,
		home + Vector2i(1, 3)), run.map, context)

	var butcher := run.commanders.inflicted_by(slaughter.commander)
	var scratched := run.commanders.inflicted_by(skirmish.commander)
	assert_true(butcher > scratched * 10.0, (
		"one battle taught them nearly the same: %f against %f — which is what a "
		+ "count of battles would say") % [butcher, scratched])


func test_garrison_duty_earns_nothing() -> void:
	# 🔒 §6 says so in as many words. A company that stood in its town for a year
	# and never met anybody has learned nothing, and should not.
	var run := _run()
	var idle := _raise(run, Company.COLONIAL, 40, Company.NOWHERE, {},
		StandingOrder.DEFEND_THE_TOWN)
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders

	for month in 12:
		run.world.month = month
		driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_almost_eq(run.commanders.inflicted_by(idle.commander), 0.0, 0.0001,
		"a year of garrison duty taught him something")


func test_grinding_a_fort_down_earns_more_than_a_skirmish() -> void:
	# 🔒 §6's own ordering, and it falls out of the tally rather than needing a
	# rule: two years of a siege inflicts far more than one exchange does.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var besieger := _raise(run, Company.REBEL, 200, home)
	var held := _raise(run, Company.CROWN, 60, home + Vector2i(1, 0))
	var context := _context(run)

	Battle.resolve(besieger, held, run.map, context)
	var one_exchange := run.commanders.inflicted_by(besieger.commander)
	for month in 23:
		if held.is_empty():
			break
		Battle.resolve(besieger, held, run.map, context)
	assert_true(run.commanders.inflicted_by(besieger.commander) > one_exchange * 5.0,
		"two years of a siege taught him barely more than one month")


func test_a_headless_company_earns_nobody_anything() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var militia := _raise(run, Company.COLONIAL, 60, home, {},
		StandingOrder.DEFEND_THE_TOWN)
	var raiders := _raise(run, Company.RIVAL, 60, home + Vector2i(1, 0))

	assert_true(militia.is_headless())
	Battle.resolve(raiders, militia, run.map, _context(run))
	assert_empty(run.commanders.inflicted.keys().filter(
		func(id: String) -> bool: return id == String(militia.commander)),
		"a company with no commander put something on somebody's account")


# --- 🔒 The level is read from the tally, never stored ---------------------

func test_the_level_rises_with_the_tally() -> void:
	assert_eq(CommanderExperience.level_for(0.0), 1,
		"a man who has done nothing is not even untried")
	assert_true(CommanderExperience.level_for(1_000_000.0)
		> CommanderExperience.level_for(20_000.0),
		"a million men killed ranked no higher than twenty thousand")
	assert_eq(CommanderExperience.level_for(1_000_000_000.0),
		CommanderExperience.top_level(),
		"a level above the top of the table")


func test_nothing_stores_a_level_that_could_disagree_with_the_tally() -> void:
	# `CommanderBook` holds the tally and the level is derived, so retuning the
	# thresholds re-ranks a saved run rather than only the men raised afterwards.
	var book := CommanderBook.new()
	for entry in book.get_property_list():
		assert_false(String(entry["name"]).contains("level"),
			"the book carries '%s', which is a second answer" % entry["name"])


func test_a_killed_commander_leaves_nothing_behind() -> void:
	# 🔒 §7: his experience dies with him. Nothing to recover, nothing to inherit.
	var book := CommanderBook.new()
	book.record(&"commander_1", 400_000.0)
	assert_true(book.level_of(&"commander_1") > 1)
	book.he_died(&"commander_1")
	assert_almost_eq(book.inflicted_by(&"commander_1"), 0.0, 0.0001)
	assert_eq(book.level_of(&"commander_1"), CommanderExperience.level_for(0.0))


func test_the_tally_survives_the_save() -> void:
	var book := CommanderBook.new()
	book.record(&"commander_1", 137.5)
	var restored := CommanderBook.from_dict(book.to_dict())
	assert_almost_eq(restored.inflicted_by(&"commander_1"), 137.5, 0.0001)


func test_a_veteran_takes_the_next_command_at_the_level_he_left_at() -> void:
	# 🔒 §7, and the reason no resupply mechanic is needed: **the commander is
	# the thing that persists, not the company.**
	var run := _run()
	var first := _raise(run, Company.COLONIAL, 40)
	run.commanders.record(first.commander, 500_000.0)
	var earned := run.commanders.level_of(first.commander)
	assert_true(earned > 1, "the fixture did not actually promote him")

	first.lose(1.0, &"wiped_out", _context(run))
	run.companies.bury_the_dead()
	var second := _raise(run, Company.COLONIAL, 40)

	assert_eq(second.commander, first.commander, "a different man took it")
	assert_eq(second.commander_level, earned,
		"he began again as though he had never campaigned")


# --- 🔒 The bonuses stack, and are visible in the force --------------------

func test_bearing_is_visible_in_the_company_s_force() -> void:
	var run := _run()
	var green := _raise(run, Company.REBEL, 40, Company.NOWHERE, _arms(40))
	var veteran := _at_level(_raise(run, Company.REBEL, 40, Company.NOWHERE,
		_arms(40)), CommanderExperience.top_level())
	assert_true(Force.of(veteran, run.map) > Force.of(green, run.map),
		"a legend was worth no more than a man in his first season")


func test_marches_is_an_extra_move() -> void:
	var run := _run()
	var green := _raise(run, Company.REBEL, 20)
	var veteran := _at_level(_raise(run, Company.REBEL, 20),
		CommanderExperience.top_level())
	assert_true(veteran.tiles_this_month() > green.tiles_this_month(),
		"a veteran marched no further than a recruit")


func test_hardiness_is_less_attrition_while_unsupported() -> void:
	var run := _run()
	var green := _raise(run, Company.REBEL, 100)
	var veteran := _at_level(_raise(run, Company.REBEL, 100),
		CommanderExperience.top_level())
	assert_true(veteran.attrition_for_me() < green.attrition_for_me(),
		"a hardened company went without no better than a green one")
	assert_true(veteran.attrition_for_me() > 0.0,
		"a veteran company stopped bleeding altogether")


func test_husbandry_arms_more_men_with_the_same_cargo() -> void:
	# 🔒 §6: it reduces what a head wants. **A company still never resupplies.**
	var run := _run()
	var arms := _arms(40)
	var green := _raise(run, Company.REBEL, 40, Company.NOWHERE, arms)
	var veteran := _at_level(_raise(run, Company.REBEL, 40, Company.NOWHERE, arms),
		CommanderExperience.top_level())

	# Both hold the same cargo. Take a third of it off each.
	for company in [green, veteran]:
		for resource in Company.armed_resources():
			(company as Company).arms[String(resource)] = \
				float((company as Company).arms[String(resource)]) * 0.66

	assert_true(veteran.armed_share(&"guns") > green.armed_share(&"guns"),
		"the same muskets armed no more of the veteran's men")
	assert_true(veteran.wants_per_head(&"guns") < Company.want_per_head(&"guns"),
		"husbandry did not reduce what a head wants")
	assert_almost_eq(green.held(&"guns"), veteran.held(&"guns"), 0.001,
		"the veteran was handed muskets, which is a resupply")


func test_siegecraft_ignores_part_of_a_wall_and_never_all_of_it() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var held := _raise(run, Company.CROWN, 40, home + Vector2i(1, 0))
	run.map.improvements[run.map.index_of(held.at.x, held.at.y)] = "fort"

	var green := _raise(run, Company.REBEL, 40, home)
	var veteran := _at_level(_raise(run, Company.REBEL, 40, home),
		CommanderExperience.top_level())

	var against_green := Force.fortification_of(held, run.map, true, green)
	var against_veteran := Force.fortification_of(held, run.map, true, veteran)
	assert_true(against_veteran < against_green,
		"a siege engineer found the wall exactly as high")
	assert_true(against_veteran > 1.0,
		"he walked through it, and §5 says a fort is never ignored")


func test_country_is_one_terrain_and_only_his() -> void:
	var run := _run()
	var home := run.colony.in_order()[0].at
	var known := CommanderExperience.country_at(CommanderExperience.top_level())
	assert_false(String(known).is_empty(), "no level buys a country at all")

	var veteran := _at_level(_raise(run, Company.REBEL, 40, home),
		CommanderExperience.top_level())
	var green := _raise(run, Company.REBEL, 40, home)
	var attacker := _raise(run, Company.CROWN, 40, home + Vector2i(1, 0))
	attacker.arms["horses"] = 0.0

	run.map.set_terrain(home.x, home.y, known)
	assert_true(Force.terrain_of(veteran, run.map, true, attacker)
		> Force.terrain_of(green, run.map, true, attacker),
		"a man who knows this country held it no better")

	# Ground he does not know is ground like any other.
	var stranger := &"desert" if String(known) != "desert" else &"plains"
	run.map.set_terrain(home.x, home.y, stranger)
	assert_almost_eq(Force.terrain_of(veteran, run.map, true, attacker),
		Force.terrain_of(green, run.map, true, attacker), 0.001,
		"his specialism followed him onto ground he has never seen")


func test_the_bonuses_stack() -> void:
	var run := _run()
	var worth := PackedFloat32Array()
	for level in range(1, CommanderExperience.top_level() + 1):
		var company := _at_level(
			_raise(run, Company.REBEL, 40, Company.NOWHERE, _arms(40)), level)
		worth.append(Force.of(company, run.map))
	for index in range(1, worth.size()):
		assert_true(worth[index] >= worth[index - 1],
			"rising a level made him worse: %s" % [worth])
	assert_true(worth[worth.size() - 1] > worth[0],
		"a legend was worth no more than an untried man: %s" % [worth])


# --- 🔒 Sayable in a letter, and never a number ----------------------------

func test_every_level_has_a_name_a_letter_can_use() -> void:
	# 🔒 §6: *a commander should be able to tell the PC what he has become without
	# the prose reading like a character sheet.*
	for level in range(1, CommanderExperience.top_level() + 1):
		assert_false(String(CommanderExperience.rank_of(level)).is_empty(),
			"level %d has no name, so no letter could mention it" % level)


func test_the_rank_is_an_id_and_never_a_sentence() -> void:
	# The words live in `data/` like any other prose, so a second language is a
	# copied folder rather than a code change.
	for level in range(1, CommanderExperience.top_level() + 1):
		var named := String(CommanderExperience.rank_of(level))
		assert_false(named.contains(" "), "'%s' is prose written in code" % named)


# --- 🔒 What the validator refuses -----------------------------------------

func _said(validator: ContentValidator) -> String:
	var out := PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func test_the_shipped_experience_passes() -> void:
	var validator := ContentValidator.new()
	validator.check_commander_experience(content)
	assert_true(validator.ok(), _said(validator))


func test_a_bonus_naming_a_knob_nothing_reads_is_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(CommanderExperience.COLLECTION, CommanderExperience.RECORD)["bonuses"] \
		.append({"id": "wishful", "turns": {"siege_craft": 0.5}})
	var validator := ContentValidator.new()
	validator.check_commander_experience(db)
	assert_false(validator.ok(), "a misspelt knob passed")
	assert_true(_said(validator).contains("siege_craft"), _said(validator))
	db.free()


func test_a_bonus_that_turns_nothing_is_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(CommanderExperience.COLLECTION, CommanderExperience.RECORD)["bonuses"] \
		.append({"id": "merely_a_word"})
	var validator := ContentValidator.new()
	validator.check_commander_experience(db)
	assert_false(validator.ok(), "a bonus that does nothing passed")
	db.free()


func test_levels_that_run_backwards_are_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(CommanderExperience.COLLECTION, CommanderExperience.RECORD)["levels"] = [
		{"casualties": 100, "rank": "rank.a"},
		{"casualties": 10, "rank": "rank.b"},
	]
	var validator := ContentValidator.new()
	validator.check_commander_experience(db)
	assert_false(validator.ok(), "a level arriving before the one below it passed")
	db.free()


# --- 🔒 A man who rises says so (#299) -----------------------------------------

func test_a_commander_who_rises_says_so_and_only_then() -> void:
	# Seam A. The level was always refreshed after a battle; nothing downstream —
	# a painting, a letter — could see it happen until it was an event. Asked
	# battle by battle against fresh enemies, so it holds whatever the thresholds
	# are tuned to.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 400, home)
	var rose_at_all := false
	for fight in 30:
		var before := run.commanders.level_of(mine.commander)
		var seen := run.log.of_type(Battle.EVENT_ROSE).size()
		var theirs := _raise(run, Company.CROWN, 40, home + Vector2i(1, 0))
		Battle.resolve(mine, theirs, run.map, _context(run))
		var after := run.commanders.level_of(mine.commander)
		var rose := run.log.of_type(Battle.EVENT_ROSE)
		if after > before:
			rose_at_all = true
			assert_eq(rose.size(), seen + 1, "he rose and nobody heard")
			var event: SimEvent = rose[rose.size() - 1]
			assert_eq(String(event.payload["commander"]), String(mine.commander))
			assert_eq(String(event.payload["rank"]), String(CommanderExperience.rank_of(after)))
		else:
			assert_eq(rose.size(), seen, "a battle that raised nobody said somebody rose")
		if mine.is_empty() or after >= CommanderExperience.top_level():
			break
	assert_true(rose_at_all, "thirty battles and he never rose, so this proves nothing")
