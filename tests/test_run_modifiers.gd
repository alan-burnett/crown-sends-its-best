extends TestCase

## Perks and quirks as data, and the knobs they name (#286,
## `docs/mechanics/perks-and-quirks.md` §1, §2).
##
## 🔒 **A perk names a knob. It never adds a number.** *Righteous* is not `+5
## clergy loyalty`; it is a drift term on one class of contact — a knob that
## already exists, turned. That is what keeps perks out of the engine, lets the
## Author add one without a code change, and **stops forty of them becoming forty
## special cases**.
##
## 🔒 **Perks are about you; quirks are about the world.** A fact about you is
## yours, so a perk is pure benefit and there is one per run. A fact about the
## world cuts both ways, so a quirk carries a drawback and a run may hold any
## number.
##
## `run_setup.gd`'s header promised all of this and none of it existed: the one
## perk was a constant in the file and there was no `data/run/` at all.

const SEED: int = 4823

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
	content.free()


func _applied(setup_run: Callable) -> RunState:
	var run := RunState.new_run(SEED)
	setup_run.call(run)
	RunModifiers.apply_all(run, content)
	return run


# --- 🔒 Data, with no per-perk branch anywhere ------------------------------

func test_the_first_day_is_an_entry_in_a_file_and_not_a_constant() -> void:
	# The acceptance line, and the reason the ticket exists.
	assert_true(RunModifiers.offered(content, RunModifiers.PERKS_RECORD)
			.has("its_my_first_day"),
		"the only perk in the game is not in the offered list")
	assert_true(content.has_record(RunModifiers.PERKS, RunModifiers.PERKS_RECORD),
		"there is no perks file")
	assert_true(content.has_record(RunModifiers.PERKS, RunModifiers.QUIRKS_RECORD),
		"there is no quirks file, so adding a quirk means adding a file")


func test_adding_an_entry_adds_it_to_the_offered_list() -> void:
	# 🔒 The code knows how to apply the ids it finds, and nothing else. This is
	# the property the whole framework is for, so it is asked directly.
	var db := ContentDatabase.new()
	db.load_all("en")
	var record: Dictionary = db.record(RunModifiers.PERKS, RunModifiers.PERKS_RECORD)
	record["entries"].append({
		"id": "a_perk_nobody_has_written",
		"name": "A perk nobody has written",
		"modifiers": [{"crown_grace": {}}],
	})
	assert_true(RunModifiers.offered(db, RunModifiers.PERKS_RECORD)
			.has("a_perk_nobody_has_written"),
		"a perk added to the file was not offered")
	db.free()


func test_an_entry_may_be_withheld_from_the_list_without_being_deleted() -> void:
	# SPEC §14.3's meta-progression unlocks them, so a file that could only hold
	# what is currently offered would have nowhere to keep the rest.
	var db := ContentDatabase.new()
	db.load_all("en")
	var record: Dictionary = db.record(RunModifiers.PERKS, RunModifiers.PERKS_RECORD)
	record["entries"].append({"id": "locked", "offered": false, "modifiers": []})
	assert_false(RunModifiers.offered(db, RunModifiers.PERKS_RECORD).has("locked"),
		"a locked perk was offered at game start")
	db.free()


func test_no_modifier_is_named_that_nothing_turns() -> void:
	for record in [RunModifiers.PERKS_RECORD, RunModifiers.QUIRKS_RECORD]:
		for entry in RunModifiers.entries_in(content, record):
			for modifier in (entry as Dictionary).get("modifiers", []):
				for id in modifier:
					assert_true(RunModifiers.is_modifier(String(id)),
						"'%s' names the knob '%s', which nothing turns"
							% [(entry as Dictionary).get("id", ""), id])


# --- 🔒 A perk names a knob -------------------------------------------------

func test_the_perk_turns_its_knob_and_no_perk_leaves_it_alone() -> void:
	var granted := _applied(func(_run: RunState) -> void: pass)
	assert_true(granted.refusal.has_grace,
		"the perk the run was given did nothing")

	var without := _applied(func(run: RunState) -> void: run.setup.perk = &"")
	assert_false(without.refusal.has_grace,
		"a run with no perk got one anyway")


func test_a_perk_nobody_has_written_turns_nothing() -> void:
	# It must not crash and must not silently grant the last perk's knob.
	var stranger := _applied(func(run: RunState) -> void:
		run.setup.perk = &"a_perk_nobody_has_written")
	assert_false(stranger.refusal.has_grace,
		"an unknown perk granted the grace anyway")


func test_applying_twice_is_the_same_as_applying_once() -> void:
	# A modifier is a fact about the run rather than a thing that happens in it.
	var run := RunState.new_run(SEED)
	for round in 3:
		RunModifiers.apply_all(run, content)
	assert_true(run.refusal.has_grace)


func test_a_run_with_no_content_loaded_is_still_a_valid_run() -> void:
	# Most fixtures assemble a run without content. It must not crash, and it
	# must not get a perk it was never offered.
	var run := RunState.new_run(SEED)
	RunModifiers.apply_all(run, null)
	assert_false(run.refusal.has_grace)


# --- 🔒 One perk, any number of quirks --------------------------------------

func test_a_run_carries_one_perk_and_any_number_of_quirks() -> void:
	var run := RunState.new_run(SEED)
	assert_eq(typeof(run.setup.perk), TYPE_STRING_NAME,
		"a run carries more than one perk")
	run.setup.quirks = PackedStringArray(["a", "b", "c"])
	assert_eq(run.setup.quirks.size(), 3, "a run cannot carry three quirks")


func test_the_perk_and_the_quirks_survive_the_save() -> void:
	# Ironman, one save per run (SPEC §16.2). A run that forgot what it was given
	# would quietly become a different run.
	var setup := RunSetup.new()
	setup.perk = &"its_my_first_day"
	setup.quirks = PackedStringArray(["rich_soil", "distant_colony"])
	var restored := RunSetup.from_dict(setup.to_dict())
	assert_eq(restored.perk, setup.perk, "the perk did not survive the save")
	assert_eq(restored.quirks, setup.quirks, "the quirks did not survive the save")


func test_the_quirks_are_applied_in_a_fixed_order() -> void:
	# 🔒 Determinism: the same seed and the same choices reproduce the run, so two
	# quirks that touch one knob must not depend on how the list was assembled.
	var one := _applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["b", "a"]))
	var other := _applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["a", "b"]))
	assert_eq(one.refusal.has_grace, other.refusal.has_grace,
		"the order the quirks were listed in changed the run")


# --- 🔒 What the validator refuses ------------------------------------------

func _said(validator: ContentValidator) -> String:
	var out: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func test_the_shipped_perks_pass() -> void:
	var validator := ContentValidator.new()
	validator.check_run_modifiers(content)
	assert_true(validator.ok(), _said(validator))


func test_a_knob_nothing_turns_is_refused() -> void:
	# 🔒 It would apply **nothing**, so a perk the player chose would be a perk he
	# did not get — and the offered list would go on offering it.
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(RunModifiers.PERKS, RunModifiers.PERKS_RECORD)["entries"].append({
		"id": "wishful", "modifiers": [{"just_win": {}}],
	})
	var validator := ContentValidator.new()
	validator.check_run_modifiers(db)
	assert_false(validator.ok(), "a perk naming a knob nothing turns passed")
	assert_true(_said(validator).contains("just_win"), _said(validator))
	db.free()


func test_two_entries_with_one_id_are_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(RunModifiers.PERKS, RunModifiers.PERKS_RECORD)["entries"].append({
		"id": "its_my_first_day", "modifiers": [],
	})
	var validator := ContentValidator.new()
	validator.check_run_modifiers(db)
	assert_false(validator.ok(), "the same perk declared twice passed")
	db.free()


func test_a_missing_file_is_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.collection(RunModifiers.PERKS).erase(RunModifiers.QUIRKS_RECORD)
	var validator := ContentValidator.new()
	validator.check_run_modifiers(db)
	assert_false(validator.ok(),
		"a missing quirks file passed, so adding a quirk means adding a file")
	db.free()
