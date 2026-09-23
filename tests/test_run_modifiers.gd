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
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
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


# --- 🔒 Scarce iron, and the asymmetry that is the whole quirk --------------

const SCARCE_IRON: String = "scarce_iron"


func _with_scarce_iron() -> RunState:
	return _applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray([SCARCE_IRON]))


## 🔒 **Every one of these asks a real tile or a real price**, never the knob's
## own accessor. A scale nothing reads still sets the accessor, so a test on
## `yield_scale_of` passes with the knob entirely disconnected — which is the
## exact failure this design exists to prevent, and it was caught by mutation
## before it reached the branch.
func test_scarce_iron_raises_what_a_town_pays_the_crown_for_iron() -> void:
	var run := _applied(func(r: RunState) -> void: r.setup.quirks = PackedStringArray())
	var plain: Dictionary = {}
	for resource in ["iron", "tools", "guns"]:
		plain[resource] = Valuation.crown(StringName(resource), run.world)
		assert_true(float(plain[resource]) > 0.0,
			"%s is free, so this proves nothing" % resource)

	var scarce := _with_scarce_iron()
	for resource in ["iron", "tools", "guns"]:
		assert_true(Valuation.crown(StringName(resource), scarce.world)
				> float(plain[resource]),
			"%s cost a town no more, so the quirk never reached the economy"
				% resource)


func test_scarce_iron_lowers_what_a_mountain_gives_of_ore() -> void:
	var mountains := Terrain.get_terrain(&"mountains")
	var before := mountains.yield_of(&"ore")
	assert_true(before > 0.0, "mountains yield no ore, so this proves nothing")

	_with_scarce_iron()
	assert_true(Terrain.get_terrain(&"mountains").yield_of(&"ore") < before,
		"a mountain gave as much ore as ever in a colony short of it")


func test_it_does_not_dock_a_resource_it_never_named() -> void:
	# A quirk about iron is not a quirk about food, and a blanket scale would be
	# a different and much larger thing than the one the file describes.
	var before := Terrain.get_terrain(&"plains").yield_of(&"food")
	assert_true(before > 0.0)
	_with_scarce_iron()
	assert_eq(Terrain.get_terrain(&"plains").yield_of(&"food"), before,
		"scarce iron reached the harvest")


func test_the_price_rises_by_more_than_the_yield_falls() -> void:
	# 🔒 **The asymmetry is the whole quirk** (`perks-and-quirks.md` §4). Buying
	# your way out has to stop working while digging your own still does — so
	# this is the shape the design requires rather than a magnitude, and it must
	# hold whatever M8 tunes the two figures to.
	var run := _applied(func(r: RunState) -> void: r.setup.quirks = PackedStringArray())
	var plain_price := Valuation.crown(&"iron", run.world)
	var plain_yield := Terrain.get_terrain(&"mountains").yield_of(&"ore")

	var scarce := _with_scarce_iron()
	var dearer := Valuation.crown(&"iron", scarce.world) / plain_price - 1.0
	var poorer := 1.0 - Terrain.get_terrain(&"mountains").yield_of(&"ore") / plain_yield

	assert_true(dearer > 0.0, "iron is no dearer, so half the quirk does nothing")
	assert_true(poorer > 0.0, "the ore is no poorer, so half the quirk does nothing")
	assert_true(dearer > poorer,
		"the price rose %.2f and the yield fell %.2f, so buying your way out is still the answer"
			% [dearer, poorer])


func test_a_run_without_it_trades_and_digs_as_authored() -> void:
	var plain_yield := Terrain.get_terrain(&"mountains").yield_of(&"ore")
	var run := _applied(func(r: RunState) -> void: r.setup.quirks = PackedStringArray())
	assert_eq(Valuation.crown(&"iron", run.world),
		ResourceCatalogue.price_of(&"iron") * CrownPrices.war_lift(run.world, &"iron"),
		"a colony with no quirk paid a scarcity price")
	assert_eq(Terrain.get_terrain(&"mountains").yield_of(&"ore"), plain_yield,
		"a colony with no quirk had its ore docked")


func test_a_yield_scale_never_goes_below_nothing() -> void:
	# Ground that owes the colony ore is not a thing the economy can express.
	Terrain.scale_yields({"ore": -3.0})
	assert_eq(Terrain.get_terrain(&"mountains").yield_of(&"ore"), 0.0,
		"a tile was made to yield a negative quantity")


# --- 🔒 Commando commanders, and Busy patrons -------------------------------

func test_commando_commanders_arrive_knowing_their_trade() -> void:
	# 🔒 Asked of the book that ranks a man, not of the knob. A level is *read
	# from casualties inflicted and never stored*, so the credit has to arrive
	# through that reading or a commander is green on the day he is commissioned
	# however the file reads.
	var book := CommanderBook.new()
	var green := book.level_of(&"nobody")

	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["commando_commanders"]))
	assert_true(CommanderBook.new().level_of(&"nobody") > green,
		"a commander who has killed nobody is still ranked as if he had")


func test_the_credit_is_read_and_never_written_into_the_tally() -> void:
	# 🔒 The book says what a man has done and the letters read that book. A
	# starting credit written into `inflicted` would be a lie in it.
	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["commando_commanders"]))
	assert_eq(CommanderBook.new().inflicted_by(&"nobody"), 0.0,
		"a man who has killed nobody is recorded as having killed somebody")


func test_commando_commanders_are_likelier_to_die_with_their_men() -> void:
	# The cost, and the half that makes it a quirk rather than a perk.
	var even := CommanderFate.survives()
	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["commando_commanders"]))
	assert_true(CommanderFate.survives() < even,
		"veterans were bred and none of them were buried any faster")


func test_busy_patrons_lets_more_of_them_be_here_at_once() -> void:
	# A court with every hand out, so the ceiling is the only thing capping it.
	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.REACH)] = 99
	var few := Patron.how_many_arrived(growth)
	assert_true(few > 0, "no patron arrived at all, so this proves nothing")

	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["busy_patrons"]))
	assert_true(Patron.how_many_arrived(growth) > few,
		"a court full of interested men produced no more patrons")


func test_quirks_compose_and_each_still_lands() -> void:
	# 🔒 §1: a run may carry any number. Two that touch different knobs must both
	# arrive — a loop that stopped at the first entry would look exactly like a
	# working one for a run that carried a single quirk.
	var plain_yield := Terrain.get_terrain(&"mountains").yield_of(&"ore")
	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["scarce_iron", "commando_commanders"]))

	assert_true(Terrain.get_terrain(&"mountains").yield_of(&"ore") < plain_yield,
		"the first quirk of two did nothing")
	assert_true(CommanderFate.survives() < 0.5,
		"the second quirk of two did nothing")


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
