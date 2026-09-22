extends TestCase

## Death, the coin flip, and the waiting veteran (#224,
## `docs/mechanics/commanders.md` §7).
##
## 🔒 **When a company is destroyed, its commander does not automatically die.**
## A draw from a named stream: killed with his men, or alive and injured in the
## town that dispatched him, at the level he left at.
##
## 🔒 **Destroyed is not disbanded.** A company that stood down on its timer
## needs no flip — a man who marched his militia home has not been shot.
##
## 🔒 **A killed commander leaves nothing behind.** His experience dies with him:
## nothing to recover and nothing to inherit.
##
## 🔒 **And no path reinforces or re-equips a company.** The commander is the
## thing that persists, not the company — which is what makes reinforcement
## unnecessary rather than merely forbidden.

const SEED: int = 3377

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
	CommanderExperience.reset()
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
	CommanderExperience.reset()
	content.free()


const MARCH: StringName = &"march_on_them"


func _run(seed_value: int = SEED) -> RunState:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	return context


func _raise(
	run: RunState, size: int = 20, order: StringName = MARCH
) -> Company:
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		Company.COLONIAL, size, {}, town.id, town.at, _context(run), order)
	Commanders.take_command(company, town, run, _context(run))
	return company


## Destroy a company to the last man.
func _wipe_out(run: RunState, company: Company) -> void:
	company.lose(1.0, &"wiped_out", _context(run))


# --- 🔒 The coin flip -------------------------------------------------------

func test_a_destroyed_company_settles_its_commander_one_way_or_the_other() -> void:
	var run := _run()
	var company := _raise(run)
	_wipe_out(run, company)

	var killed := run.log.of_type(CommanderFate.EVENT_KILLED).size()
	var lived := run.log.of_type(CommanderFate.EVENT_SURVIVED).size()
	assert_eq(killed + lived, 1,
		"a company was destroyed and its commander's fate was reported %d times"
			% (killed + lived))


func test_the_same_seed_kills_the_same_men() -> void:
	# The acceptance line: **deterministic on the seed.**
	var fates := PackedStringArray()
	for pass_index in 3:
		var run := _run()
		var company := _raise(run)
		_wipe_out(run, company)
		fates.append("dead" if run.contact(company.commander).is_dead else "alive")
	for index in range(1, fates.size()):
		assert_eq(fates[index], fates[0],
			"the same seed settled him differently: %s" % [fates])


func test_it_is_not_the_same_answer_for_everybody() -> void:
	# 🔒 **A flip, and not a rule.** A version that always killed, or always
	# spared, would pass every test above — so this sweeps seeds and asks for
	# both outcomes to occur at all.
	var seen: Dictionary = {}
	for seed_value in range(500, 540):
		var run := _run(seed_value)
		var company := _raise(run)
		_wipe_out(run, company)
		seen[run.contact(company.commander).is_dead] = true
	assert_eq(seen.size(), 2,
		"forty destroyed companies produced one outcome: %s" % [seen.keys()])


func test_his_own_stream_decides_and_not_a_shared_one() -> void:
	# 🔒 `hash(run_seed, contact_id)` (`CLAUDE.md`), so the same seed yields the
	# same men however much else happened first — and two commanders lost in one
	# month are not decided by one draw.
	var run := _run()
	var first := _raise(run)
	var second := _raise(run)
	assert_ne(first.commander, second.commander)

	_wipe_out(run, first)
	_wipe_out(run, second)
	assert_eq(run.log.of_type(CommanderFate.EVENT_KILLED).size()
		+ run.log.of_type(CommanderFate.EVENT_SURVIVED).size(), 2,
		"two companies lost and fewer than two fates settled")


# --- 🔒 The survivor --------------------------------------------------------

func _a_survivor(run: RunState) -> Contact:
	# Sweep until this seed's man lives, so the tests below are about what
	# happens to him rather than about the flip.
	for attempt in 40:
		var company := _raise(run)
		run.commanders.record(company.commander, 200.0)
		company.commander_level = run.commanders.level_of(company.commander)
		_wipe_out(run, company)
		var man := run.contact(company.commander)
		if not man.is_dead:
			return man
	return null


func test_a_survivor_keeps_his_level_and_waits_in_his_town() -> void:
	var run := _run()
	var man := _a_survivor(run)
	assert_true(man != null, "nobody survived in forty tries, which is not a flip")

	assert_false(man.is_dead)
	assert_eq(man.town, run.colony.in_order()[0].display_name,
		"he did not go back to the town that dispatched him")
	assert_true(run.commanders.level_of(man.id) > 1,
		"a veteran came home having forgotten his campaigns")
	assert_false(run.companies.is_commanding(man.id),
		"he is still leading the company that was destroyed")


func test_a_new_company_offers_him_the_command_before_making_anybody() -> void:
	# 🔒 §7: **a veteran waits in his town and takes the next command raised
	# there, at the level he left at.**
	var run := _run()
	var man := _a_survivor(run)
	assert_true(man != null)
	var before := Commanders.all_in(run).size()
	var earned := run.commanders.level_of(man.id)

	var fresh := _raise(run)
	assert_eq(fresh.commander, man.id, "a new man was made while a veteran sat idle")
	assert_eq(Commanders.all_in(run).size(), before, "somebody new was generated")
	assert_eq(fresh.commander_level, earned,
		"he took the new command having forgotten the old one")


func test_the_survivor_is_reported_so_a_letter_could_find_him() -> void:
	# §7's letter is the instrument — *a general without a command is a standing
	# argument for raising another company, made by the man himself.* The letter
	# itself is blocked (#361); what exists is the event it would fire on.
	var run := _run()
	var man := _a_survivor(run)
	assert_true(man != null)
	var told := run.log.of_type(CommanderFate.EVENT_SURVIVED)
	assert_false(told.is_empty())
	assert_eq(String(told[told.size() - 1].payload.get("commander", "")), String(man.id))
	assert_has(told[told.size() - 1].payload, "town",
		"the report does not say where he is waiting")


# --- 🔒 The killed leave nothing behind ------------------------------------

func _a_casualty(run: RunState) -> Contact:
	for attempt in 40:
		var company := _raise(run)
		run.commanders.record(company.commander, 200.0)
		_wipe_out(run, company)
		var man := run.contact(company.commander)
		if man.is_dead:
			return man
	return null


func test_a_killed_commander_leaves_nothing() -> void:
	var run := _run()
	var man := _a_casualty(run)
	assert_true(man != null, "nobody died in forty tries, which is not a flip")

	assert_true(man.is_dead)
	assert_almost_eq(run.commanders.inflicted_by(man.id), 0.0, 0.0001,
		"his experience outlived him")
	assert_empty(Commanders.waiting_in(run.colony.in_order()[0], run).filter(
		func(other: Contact) -> bool: return other.id == man.id),
		"a dead man is waiting for a command")


func test_a_new_company_does_not_offer_the_command_to_a_dead_man() -> void:
	var run := _run()
	var man := _a_casualty(run)
	assert_true(man != null)
	var fresh := _raise(run)
	assert_ne(fresh.commander, man.id, "the command went to a corpse")


# --- 🔒 Destroyed is not disbanded -----------------------------------------

func test_a_company_that_stood_down_needs_no_flip() -> void:
	# 🔒 §7: a commander whose company disbands on its timer simply goes home and
	# waits. A man who marched his militia home has not been shot.
	var run := _run()
	var militia := _raise(run, 20, StandingOrder.DEFEND_THE_TOWN)
	assert_true(militia.is_headless(), "the fixture gave the militia a commander")

	militia.stand_down(run.colony.in_order()[0], _context(run))
	assert_empty(run.log.of_type(CommanderFate.EVENT_KILLED))
	assert_empty(run.log.of_type(CommanderFate.EVENT_SURVIVED))


func test_a_commander_who_decided_to_disband_is_not_shot_for_it() -> void:
	var run := _run()
	var company := _raise(run)
	company.stand_down(run.colony.in_order()[0], _context(run))
	assert_true(company.is_empty())
	assert_empty(run.log.of_type(CommanderFate.EVENT_KILLED),
		"a man who stood his company down was killed for it")
	assert_false(run.contact(company.commander).is_dead)


func test_a_headless_company_destroyed_settles_nobody() -> void:
	var run := _run()
	var militia := _raise(run, 20, StandingOrder.DEFEND_THE_TOWN)
	_wipe_out(run, militia)
	assert_empty(run.log.of_type(CommanderFate.EVENT_KILLED))
	assert_empty(run.log.of_type(CommanderFate.EVENT_SURVIVED))


# --- 🔒 No path reinforces or re-equips a company --------------------------

func test_nothing_anywhere_reinforces_a_company() -> void:
	# 🔒 §7: **a dev who reaches for reinforcement to make veterans durable has
	# solved a problem this already solves.** Asked of the codebase, because the
	# temptation arrives later and looks reasonable at the time.
	var found := PackedStringArray()
	for path in _scripts_in("res://sim/battle"):
		var code := _code_of(path)
		for token in ["reinforce", "resupply", "recruit", "rearm", "re_equip",
				"reequip", "replenish"]:
			if code.contains(token):
				found.append("%s has %s" % [path.get_file(), token])
	assert_empty(found, "something reinforces a company: %s" % ", ".join(found))


func test_a_company_never_grows_however_its_commander_rises() -> void:
	var run := _run()
	var company := _raise(run, 30)
	var had := company.size
	var held := company.held(&"guns")
	run.commanders.record(company.commander, 1_000.0)
	company.commander_level = run.commanders.level_of(company.commander)

	assert_eq(company.size, had, "a promotion put men in the ranks")
	assert_almost_eq(company.held(&"guns"), held, 0.0001,
		"a promotion put muskets in their hands")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _scripts_in(at: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			out.append(at.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	assert_false(out.is_empty(), "no scripts were found under %s to check" % at)
	return out
