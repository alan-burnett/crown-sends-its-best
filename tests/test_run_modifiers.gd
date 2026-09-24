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


# --- 🔒 A run starts from a fresh world, never from the last run ------------
#
# A knob is a static, and a static outlives the run that turned it. The game
# loads its content once and then goes from one run straight to the next, so a
# run that left a knob turned handed its quirks to whoever played next — and a
# save loaded after it inherited every knob it does not turn itself.

func _plain_run() -> RunState:
	var run := RunState.new_run(SEED)
	run.setup.perk = &""
	run.setup.quirks = PackedStringArray()
	return run


## Every static the game's own classes hold, as text, keyed `Class.name`.
##
## 🔒 **Read off the scripts rather than listed.** A list of knobs to check would
## be a second list of knobs to forget, and forgetting one is exactly the failure
## this is for: a knob added tomorrow is in here without anybody touching this
## file.
func _every_static() -> Dictionary:
	var out := {}
	for entry in ProjectSettings.get_global_class_list():
		var path := String(entry["path"])
		if path.begins_with("res://tests/") or path.begins_with("res://tools/"):
			continue
		var script := load(path) as Script
		if script == null:
			continue
		for property in script.get_property_list():
			if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var name := String(property["name"])
			out["%s.%s" % [entry["class"], name]] = var_to_str(script.get(name))
	return out


## The statics that read differently between two readings, sorted.
func _moved(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key in before:
		if String(after.get(key, "")) != String(before[key]):
			out.append(String(key))
	out.sort()
	return out


func test_a_plain_run_after_a_distant_busy_one_is_back_at_home() -> void:
	# The case that was reported: *Distant colony* and *Busy patrons*, then New
	# Game. Read against a fresh process rather than against the figures, which
	# are M8's.
	var home_crossing := Crossing.months()
	var home_patrons := Patron.how_many()
	var home_room := DemandSchedule.room_for(DemandGrowth.SOURCE_PATRON)
	var quirked := RunState.new_run(SEED)
	quirked.setup.quirks = PackedStringArray(["distant_colony", "busy_patrons"])
	var plain := _plain_run()

	RunModifiers.apply_all(quirked, content)
	# Or the rest of this proves nothing.
	assert_ne(Crossing.months(), home_crossing, "Distant colony never turned the crossing")
	assert_ne(Patron.how_many(), home_patrons, "Busy patrons never turned the count")

	RunModifiers.apply_all(plain, content)
	assert_eq(Crossing.months(), home_crossing,
		"a New Game after a distant colony kept its extra month at sea")
	assert_eq(Patron.how_many(), home_patrons,
		"a New Game after busy patrons kept a seat at the desk for more of them")
	assert_eq(DemandSchedule.room_for(DemandGrowth.SOURCE_PATRON), home_room,
		"the Squeeze kept room for patrons the next run will never meet")


func test_no_run_leaves_a_knob_turned_for_the_next() -> void:
	# 🔒 Every perk in the file, each with every quirk, and then a run with none:
	# every static must read as a fresh process's does. **Every entry, not every
	# offered one** — a locked perk is still a run somebody will play.
	#
	# It catches both halves: a knob `RunModifiers.reset_knobs` never puts back,
	# and a reset that puts the knob back by clearing the table `load_resources`
	# loaded beside it, which would hand the next run an empty world.
	var quirks := PackedStringArray()
	for entry in RunModifiers.entries_in(content, RunModifiers.QUIRKS_RECORD):
		quirks.append(String((entry as Dictionary).get("id", "")))
	var turned: Array[RunState] = []
	for entry in RunModifiers.entries_in(content, RunModifiers.PERKS_RECORD):
		var run := RunState.new_run(SEED)
		run.setup.perk = StringName((entry as Dictionary).get("id", ""))
		run.setup.quirks = quirks
		turned.append(run)
	var plain := _plain_run()
	# Read once every run is made, because making one is not what is asked.
	var fresh := _every_static()

	assert_false(turned.is_empty(), "there are no perks, so this proves nothing")
	for run in turned:
		RunModifiers.apply_all(run, content)
		assert_false(_moved(fresh, _every_static()).is_empty(),
			"'%s' and every quirk turned nothing, so this proves nothing" % run.setup.perk)
		RunModifiers.apply_all(plain, content)
		var left := _moved(fresh, _every_static())
		assert_true(left.is_empty(),
			"a plain run after '%s' and every quirk did not start where a fresh process does: %s"
				% [run.setup.perk, ", ".join(left)])


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


## How many patrons a long Squeeze produces, drawn the way a run draws them.
##
## Through the draw rather than by writing the hands in, because the claim is
## that the quirk reaches the Squeeze: a count of patrons the draw could never
## fill would be a number in a file (#339).
func _patrons_after_a_long_squeeze() -> int:
	var growth := DemandGrowth.new()
	var streams := RngStreams.new(SEED)
	for month in 40 * 12:
		growth.advance(month / 12 + 1, streams, null, month)
	return Patron.how_many_arrived(growth)


func test_busy_patrons_lets_more_of_them_be_here_at_once() -> void:
	var few := _patrons_after_a_long_squeeze()
	assert_true(few > 0, "no patron arrived at all, so this proves nothing")

	_applied(func(run: RunState) -> void:
		run.setup.quirks = PackedStringArray(["busy_patrons"]))
	assert_true(_patrons_after_a_long_squeeze() > few,
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


# --- 🔒 Righteous: a drift term on one class of contact ---------------------

func _with_clergy(run: RunState) -> Contact:
	var town := run.colony.in_order()[0]
	town.add_building(&"church")
	ContactRoster.house_the_residents(run)
	return run.contacts.get(String(ContactRoster.resident_id(town, "clergyman")), null)


func test_righteous_warms_the_clergy_every_month() -> void:
	# 🔒 §2's own example of what naming a knob means: *Righteous is not +5 clergy
	# loyalty, it is a drift term on one class of contact.*
	var plain := _applied(func(r: RunState) -> void: r.setup.perk = &"")
	var priest := _with_clergy(plain)
	assert_true(priest != null, "the church brought nobody")
	var without := LoyaltyDrift.for_contact(
		priest, ColonyMeasures.for_contact(plain, priest))

	var blessed := _applied(func(r: RunState) -> void: r.setup.perk = &"righteous")
	var his_priest := _with_clergy(blessed)
	var with := LoyaltyDrift.for_contact(
		his_priest, ColonyMeasures.for_contact(blessed, his_priest))

	assert_true(with > without,
		"the Church decided to be pleased with the PC and nothing happened")


func test_righteous_warms_nobody_else() -> void:
	# Keyed by the kind of man, because four institutional contacts share one
	# role and a perk about the clergy must not warm the quartermaster.
	var run := _applied(func(r: RunState) -> void: r.setup.perk = &"righteous")
	var town := run.colony.in_order()[0]
	town.add_building(&"gunsmith")
	ContactRoster.house_the_residents(run)

	var quartermaster: Contact = run.contacts.get(
		String(ContactRoster.resident_id(town, "quartermaster")), null)
	assert_true(quartermaster != null, "the gunsmith brought nobody")
	assert_eq(LoyaltyDrift.favour_toward(quartermaster), 0.0,
		"a perk about the clergy warmed the man who makes the muskets")
	assert_eq(LoyaltyDrift.favour_toward(run.contact(&"steward")), 0.0,
		"a perk about the clergy warmed the Steward")


# --- 🔒 Good first impression -----------------------------------------------

func test_a_new_contact_starts_warmer() -> void:
	var run := _applied(func(r: RunState) -> void:
		r.setup.perk = &"good_first_impression")
	assert_true(Contact.first_impression() > 0.0, "nobody starts any warmer")

	var plain := Contact.generate(&"a_man", Contact.ROLE_GOVERNOR, run.streams,
		IntentConsiderations.ALL)
	assert_true(plain.loyalty() > Relationship.NEUTRAL_LOYALTY,
		"a man generated under the perk was no warmer than neutral")


func test_it_does_not_touch_the_crowns_fixed_officers() -> void:
	# 🔒 They are the same in every run (SPEC §8.1) and their loyalties are
	# characterisation — the Chancellor beginning very low is who he is.
	var run := _applied(func(r: RunState) -> void:
		r.setup.perk = &"good_first_impression")
	ContactRoster.load_into(run, content)
	var chancellor := run.contact(&"chancellor")
	assert_true(chancellor != null, "there is no Chancellor to ask about")

	# The same man loaded with the perk off. His regard is read from the file
	# either way, so the two must agree.
	Contact.reset()
	var fresh := RunState.new_run(SEED)
	ContactRoster.load_into(fresh, content)
	assert_eq(chancellor.loyalty(), fresh.contact(&"chancellor").loyalty(),
		"the perk warmed a Crown officer whose regard is authored")


# --- 🔒 Read between the lines ----------------------------------------------

func test_the_leans_bite_less_when_reporting_to_the_pc() -> void:
	# 🔒 They still deceive themselves; they present it more plainly. So the
	# perk turns the pipeline's scale and not anybody's `leans`.
	MeasureRegistry.register_linear("probe", 0.0, 1.0)
	var lean := -0.4
	var samples := [0.2, 0.35, 0.5, 0.65, 0.8, 0.95]

	var plain: Array = []
	for raw in samples:
		plain.append(Perception.rung("probe", float(raw), lean, 5))

	_applied(func(r: RunState) -> void: r.setup.perk = &"read_between_the_lines")
	assert_true(Perception.lean_scale() < 1.0, "the leans were not reduced at all")

	# **Never further from the truth anywhere, and nearer somewhere.** A halved
	# lean does not stop biting — it bites less — so asserting it lands exactly
	# on the truth would be asserting the perk cured him, which is the thing §3
	# says it does not do.
	var nearer := 0
	for index in samples.size():
		var raw := float(samples[index])
		var truth := Perception.truthful_rung("probe", raw, 5)
		var plainer := Perception.rung("probe", raw, lean, 5)
		assert_true(absi(truth - plainer) <= absi(truth - int(plain[index])),
			"reading between the lines put him further from the truth at %f" % raw)
		if absi(truth - plainer) < absi(truth - int(plain[index])):
			nearer += 1
	assert_true(nearer > 0,
		"a bleak reader was no plainer anywhere on the ladder")


func test_the_man_still_believes_what_he_believed() -> void:
	# 🔒 The lock. The Marshal still minimises every threat; he simply says so
	# more plainly. A perk that edited his `leans` would have changed the man.
	var run := _applied(func(r: RunState) -> void:
		r.setup.perk = &"read_between_the_lines")
	var priest := _with_clergy(run)
	assert_true(priest.lean_for(ColonyMeasures.POOREST_QUALITY_OF_LIFE) < 0.0,
		"the perk cured the clergyman of seeing the worst")


func test_without_it_the_leans_are_untouched() -> void:
	_applied(func(r: RunState) -> void: r.setup.perk = &"")
	assert_eq(Perception.lean_scale(), 1.0,
		"a run with no perk read its letters more plainly anyway")


# --- 🔒 A pious colony: both directions, and a drawback ---------------------

func test_a_pious_colony_makes_its_priests_loom_larger() -> void:
	var plain := _applied(func(r: RunState) -> void: r.setup.quirks = PackedStringArray())
	var ordinary := _with_clergy(plain).prominence()

	var pious := _applied(func(r: RunState) -> void:
		r.setup.quirks = PackedStringArray(["a_pious_colony"]))
	assert_true(_with_clergy(pious).prominence() > ordinary,
		"a colony that came for the freedom to worship listens no harder to its priest")


func test_it_cuts_both_ways_because_prominence_does() -> void:
	# 🔒 The whole reason one knob serves the benefit and the drawback: a
	# contented priest holds his town down harder and a slighted one carries it
	# out faster, and `rebel-sentiment.md` §4 scales his regard whichever way it
	# points.
	var run := _applied(func(r: RunState) -> void:
		r.setup.quirks = PackedStringArray(["a_pious_colony"]))
	var town := run.colony.in_order()[0]
	var priest := _with_clergy(run)
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony

	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)
	var contented := float(RebelSentiment.of(
		town, context, run.grievances, run.contacts)["contacts"])
	priest.relationship = Relationship.new(priest.id, Relationship.MIN_LOYALTY)
	var slighted := float(RebelSentiment.of(
		town, context, run.grievances, run.contacts)["contacts"])

	assert_true(slighted > contented,
		"a slighted priest in a pious colony carried his town nowhere")


func test_and_the_theatre_buys_less() -> void:
	# The drawback. They disapprove, so bread and circuses buy less, which closes
	# `quality-of-life.md` §8's rum trap from the other end.
	var run := _applied(func(r: RunState) -> void: r.setup.quirks = PackedStringArray())
	var town := run.colony.in_order()[0]
	town.add_building(&"theatre")
	var ordinary := float(Building.amusement_for(town)["served"])
	assert_true(ordinary > 0.0, "a theatre amused nobody, so this proves nothing")

	_applied(func(r: RunState) -> void:
		r.setup.quirks = PackedStringArray(["a_pious_colony"]))
	assert_true(float(Building.amusement_for(town)["served"]) < ordinary,
		"a pious colony enjoyed the theatre exactly as much as anybody else")


# --- 🔒 Good PR: every optic rings quieter, and none of them decays ---------

func test_good_pr_makes_every_optic_cost_less() -> void:
	var plain := OpticsRegister.price_of(Rebellion.EVENT_DECLARED)
	assert_true(plain > 0.0, "a rebellion costs nothing, so this proves nothing")

	_applied(func(r: RunState) -> void: r.setup.perk = &"good_pr")
	assert_true(OpticsRegister.price_of(Rebellion.EVENT_DECLARED) < plain,
		"the pamphlets were kind and the court minded exactly as much")


func test_it_reaches_the_debt_the_court_actually_tallies() -> void:
	# A scale nothing reads is a number in a file.
	var run := _applied(func(r: RunState) -> void: r.setup.perk = &"")
	run.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 4, {}, WorldPhase.COLONY_MONTH)
	var plain := OpticsRegister.debt_in(run.log)
	assert_true(plain > 0.0, "a rebellion left no debt at all")

	var kind := _applied(func(r: RunState) -> void: r.setup.perk = &"good_pr")
	kind.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 4, {}, WorldPhase.COLONY_MONTH)
	assert_true(OpticsRegister.debt_in(kind.log) < plain,
		"good press never reached the tally")


func test_it_does_not_make_an_optic_decay() -> void:
	# 🔒 **Nothing does.** A run with two rebellions in it is still a run with two
	# rebellions in it, and merely less ruinous — which is the difference between
	# a perk and a pardon.
	var run := _applied(func(r: RunState) -> void: r.setup.perk = &"good_pr")
	run.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 1, {}, WorldPhase.COLONY_MONTH)
	var owed := OpticsRegister.debt_in(run.log)

	run.world.month = 40
	assert_eq(OpticsRegister.debt_in(run.log), owed,
		"an optic faded with time, and prestige.md §4 says none of them does")

	run.log.emit(Rebellion.EVENT_DECLARED, &"gallows_end", 2, {}, WorldPhase.COLONY_MONTH)
	assert_true(OpticsRegister.debt_in(run.log) > owed,
		"a second rebellion cost nothing on top of the first")


# --- 🔒 My boss is a jerk: it matters whose treasury said no ----------------

func _let_down(perk: StringName, by_the_crown: bool) -> float:
	var run := _applied(func(r: RunState) -> void: r.setup.perk = perk)
	ContactRoster.load_into(run, content)
	var marshal := run.contact(&"marshal")
	var before := marshal.loyalty()

	var promise := Promise.new(&"marshal", &"gold", {"amount": 300.0}, 1, 2)
	var promises := PromiseBook.new()
	promises.make(promise, marshal, run.log, 1)
	if by_the_crown:
		promises.settle_due({"marshal": marshal}, run.log, 3, false)
	else:
		promises.break_promise(promise, marshal, run.log, 3, "the PC changed his mind")
	return before - marshal.loyalty()


func test_a_promise_the_crown_broke_costs_less_under_the_perk() -> void:
	var plain := _let_down(&"", true)
	assert_true(plain > 0.0, "the Crown repudiated a promise and nobody minded")
	var defused := _let_down(&"my_boss_is_a_jerk", true)
	assert_true(defused < plain,
		"they knew whose treasury said no and blamed the PC exactly as much")


func test_a_promise_the_pc_broke_himself_costs_what_it_always_did() -> void:
	# 🔒 The scale is on **who refused**, never on the promise. A PC who simply
	# went back on his word is not covered by his employer being difficult.
	var plain := _let_down(&"", false)
	var with_perk := _let_down(&"my_boss_is_a_jerk", false)
	assert_true(plain > 0.0, "breaking a promise cost nothing")
	assert_almost_eq(with_perk, plain, 0.0001,
		"the perk excused the PC a promise he broke himself")


# --- 🔒 Well connected at court ---------------------------------------------

func test_granting_a_crown_officers_demand_earns_more() -> void:
	var plain := _applied(func(r: RunState) -> void: r.setup.perk = &"")
	ContactRoster.load_into(plain, content)
	var ordinary := plain.contact(&"steward")
	var was := ordinary.loyalty()
	ordinary.relationship.record_deed(Relationship.GRANTED)
	var earned := ordinary.loyalty() - was

	var connected := _applied(func(r: RunState) -> void:
		r.setup.perk = &"well_connected_at_court")
	ContactRoster.load_into(connected, content)
	var steward := connected.contact(&"steward")
	RunModifiers.apply_all(connected, content)
	var before := steward.loyalty()
	steward.relationship.record_deed(Relationship.GRANTED)

	assert_true(earned > 0.0, "granting a demand earned nothing at all")
	assert_true(steward.loyalty() - before > earned,
		"a word from a well-connected PC went no further than anybody else's")


func test_it_does_not_reach_a_governor() -> void:
	# The perk is about the court. A governor is not at it.
	var run := _applied(func(r: RunState) -> void:
		r.setup.perk = &"well_connected_at_court")
	ContactRoster.load_into(run, content)
	RunModifiers.apply_all(run, content)

	var governor := run.contact(run.colony.in_order()[0].governor_id)
	assert_true(governor != null, "there is no governor to ask about")
	assert_almost_eq(governor.relationship.scale_for(Relationship.GRANTED), 1.0, 0.0001,
		"a perk about the court reached a man in the colony")


# --- 🔒 Hard to say no to: it wins close arguments, never a hopeless one ----

func _urging_at(perk: StringName, months_later: int, raw: bool = false) -> float:
	var run := _applied(func(r: RunState) -> void: r.setup.perk = perk)
	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, run.world, EventLog.new())
	context.month = months_later
	context.data = {
		"urgings": [Urging.from_pc(GovernorIntent.ECONOMY, 0, Tone.DUTIFUL)],
	}
	var urging := IntentConsiderations.CrownUrging.new()
	var candidate := Candidate.new(GovernorIntent.ECONOMY, {})
	# `scored` is the kernel's own `[-1, +1]` guard, so asking it what the
	# consideration is worth would hide a consideration that shouts. `raw` asks the
	# consideration directly, which is the only way to see that.
	if raw:
		return urging.score(null, candidate, context)
	return urging.scored(null, candidate, context)


func test_a_letter_from_him_is_still_scoring_when_another_mans_has_faded() -> void:
	# Not the accessor — what a governor actually reads off the letter a year on.
	var plain := _urging_at(&"", 12)
	assert_true(plain > 0.0, "a year-old urging scored nothing at all, so this proves nothing")
	assert_true(_urging_at(&"hard_to_say_no_to", 12) > plain,
		"the PC is no harder to say no to than anybody else")


func test_it_never_shouts_louder_than_the_contract_allows() -> void:
	# 🔒 §3: *it never overrides him.* A consideration scores in `[-1, +1]`, and
	# one that breaks out of that drowns the weight vector — personality stops
	# meaning anything and the perk has become a command. So the month the letter
	# lands, when the pull is already at the ceiling, the perk buys nothing; what
	# it buys is the tail.
	assert_almost_eq(_urging_at(&"", 0, true), 1.0, 0.0001,
		"a fresh urging was not at the ceiling, so the test below shows nothing")
	assert_almost_eq(_urging_at(&"hard_to_say_no_to", 0, true), 1.0, 0.0001,
		"a fresh urging under the perk scored outside the range every consideration shares")


func test_it_is_one_consideration_among_nine_and_not_a_command() -> void:
	# The other half of the same lock: a perk turns a knob, it does not add or
	# remove something a governor weighs.
	_applied(func(r: RunState) -> void: r.setup.perk = &"hard_to_say_no_to")
	assert_true(IntentConsiderations.ALL.has("crown_urging"),
		"the urging is no longer a consideration at all")
	assert_eq(IntentConsiderations.ALL.size(), 9,
		"the perk changed how many things a governor weighs")

# --- 🔒 It could be worse: the curve flattens both ways ---------------------

func test_misery_hurts_less_and_comfort_helps_less() -> void:
	var wretched := QualityOfLife.combine(0.1, 0.0)
	var thriving := QualityOfLife.combine(0.9, 0.0)
	assert_true(thriving > wretched, "the measure did not distinguish them at all")

	_applied(func(r: RunState) -> void: r.setup.quirks = [&"it_could_be_worse"])
	assert_true(QualityOfLife.combine(0.1, 0.0) > wretched,
		"a wretched town read exactly as wretched, so misery did not hurt less")
	assert_true(QualityOfLife.combine(0.9, 0.0) < thriving,
		"a thriving town read exactly as thriving, so comfort still helped as much")


func test_it_narrows_the_measure_rather_than_lowering_it() -> void:
	# 🔒 **Both ways, and that is the quirk.** A damper that only took the top off
	# would be a straight penalty, and a player would simply never choose it.
	var spread := QualityOfLife.combine(0.9, 0.0) - QualityOfLife.combine(0.1, 0.0)
	_applied(func(r: RunState) -> void: r.setup.quirks = [&"it_could_be_worse"])
	var narrowed := QualityOfLife.combine(0.9, 0.0) - QualityOfLife.combine(0.1, 0.0)
	assert_true(narrowed < spread,
		"the distance between a good life here and a bad one did not close")
	assert_true(narrowed > 0.0,
		"the quirk erased the difference, and a colony nobody can improve is not a game")


func test_the_poorest_are_read_through_it_too() -> void:
	# The clergyman's regard answers to this figure and his letters report it, and
	# *fewer complaints* is half of what the quirk buys.
	var parts := {"health": 0.1, "safety": 0.1, "means": 0.1, "hope": 0.1}
	var plain := QualityOfLife.from_below(parts)
	_applied(func(r: RunState) -> void: r.setup.quirks = [&"it_could_be_worse"])
	assert_true(QualityOfLife.from_below(parts) > plain,
		"the poorest were read exactly as poorly, so the priest complains as much")


func test_it_does_not_touch_what_actually_happened_to_the_town() -> void:
	# 🔒 **On the measure, never on the five components.** The food really did run
	# out, and `town.safety` — which the Diplomat asks to be moved on — is a fact
	# about danger rather than a judgement about comfort.
	var parts := {"health": 0.2, "safety": 0.3, "means": 0.2, "hope": 0.1}
	var substance := QualityOfLife.substance_of(parts)
	_applied(func(r: RunState) -> void: r.setup.quirks = [&"it_could_be_worse"])
	assert_almost_eq(QualityOfLife.substance_of(parts), substance, 0.0001,
		"the quirk changed what happened to the town rather than what was made of it")


# --- 🔒 Boom town: the same sentence is the benefit and the cost ------------

func _boom_town(quality: float = 0.9) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 12_000
	town.quality_of_life = quality
	town.receive_gold(5_000.0)
	return town


func _boom_context(town: Town) -> ColonyContext:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	return context


func _arriving(quirk: StringName, quality: float = 0.9) -> float:
	_with_quirk(quirk)
	var town := _boom_town(quality)
	var due := Immigration.due(town, _boom_context(town))
	return float(due["workers"]) + float(due["experts"])


## A run carrying one quirk, or none when the id is empty.
func _with_quirk(quirk: StringName) -> RunState:
	var carried: Array[StringName] = []
	if not String(quirk).is_empty():
		carried.append(quirk)
	return _applied(func(r: RunState) -> void: r.setup.quirks = carried)


func test_more_of_them_come() -> void:
	var plain := _arriving(&"")
	assert_true(plain > 0.0, "nobody came to a thriving town, so this proves nothing")
	assert_true(_arriving(&"boom_town") > plain, "the boom brought no one extra")


func test_a_wretched_town_still_draws_nobody() -> void:
	# 🔒 **On the flow, not on the appeal.** The quirk multiplies the reasons a
	# town has earned; it never invents one. A player who cannot hold a colony
	# gets to the cliff faster rather than being handed a colony.
	assert_almost_eq(_arriving(&"boom_town", 0.1), 0.0, 0.0001,
		"people crossed an ocean to a place nobody would live in")


func test_the_stakes_run_higher_with_them() -> void:
	# The other half of the same sentence: `immigration.md` §9's chain — growth is
	# the engine of prosperity and the engine of rebellion at once.
	var town := _boom_town()
	town.buildings.append("granary")
	town.buildings.append("chapel")
	town.traded_value = 4_000.0
	var plain := RebelSentiment.stakes_for(town)
	assert_true(plain > 1.0, "a developed town had nothing at stake, so this proves nothing")

	_with_quirk(&"boom_town")
	assert_true(RebelSentiment.stakes_for(town) > plain,
		"the town filled up and had no more to lose")


func test_a_hamlet_with_nothing_at_stake_is_still_placid() -> void:
	# 🔒 **It amplifies both directions and cannot by itself put a town anywhere.**
	# The multiplier's floor is one, and a quirk that lifted it would say that
	# arriving in a boom country makes a shed want independence.
	var hamlet := _boom_town()
	_with_quirk(&"boom_town")
	assert_almost_eq(RebelSentiment.stakes_for(hamlet), 1.0, 0.0001,
		"a town with nothing built and nothing traded was driven harder for it")


# --- 🔒 Restless country: stronger, not merely grumpier ---------------------

func test_the_tribes_begin_further_down() -> void:
	var plain := Tribes.generate(RngStreams.new(SEED))
	var was: Array = []
	for tribe in plain.all:
		was.append((tribe as Tribe).standing_toward(Tribe.COLONY))

	_with_quirk(&"restless_country")
	var restless := Tribes.generate(RngStreams.new(SEED))
	assert_eq(restless.all.size(), was.size(), "the quirk changed how many there are")
	for index in restless.all.size():
		var tribe: Tribe = restless.all[index]
		assert_true(tribe.standing_toward(Tribe.COLONY) < float(was[index]),
			"a tribe met the colony exactly as warmly as in a quiet country")


func _standing_spread(tribes: Tribes) -> float:
	var lowest := 200.0
	var highest := -200.0
	for entry in tribes.all:
		var standing: float = (entry as Tribe).standing_toward(Tribe.COLONY)
		lowest = minf(lowest, standing)
		highest = maxf(highest, standing)
	return highest - lowest


func test_they_are_still_three_peoples_and_not_one_in_triplicate() -> void:
	# 🔒 **A shift on the band, not a narrowing of it.** The spread between a
	# tribe that will deal and one that will not is what makes three neighbours
	# three characters.
	var spread := _standing_spread(Tribes.generate(RngStreams.new(SEED)))
	assert_true(spread > 0.0, "the three already start identical, so this proves nothing")

	_with_quirk(&"restless_country")
	assert_almost_eq(_standing_spread(Tribes.generate(RngStreams.new(SEED))), spread, 0.0001,
		"they all start lower and they no longer differ by as much")


func _gathered(quirk: StringName) -> float:
	_with_quirk(quirk)
	var map := WorldMap.new(24, 24, &"ocean")
	for y in range(2, 22):
		for x in range(2, 22):
			map.set_terrain(x, y, &"plains")

	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.standing = {String(Tribe.COLONY): 70.0}

	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = &"tribe_test"
	village.at = Vector2i(10, 10)
	village.people = 30_000
	village.stores = {"food": 400.0}

	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	var before := float(village.stores.get("food", 0.0))
	village.live(tribe, context)
	return float(village.stores.get("food", 0.0)) - before


func test_their_villages_take_more_off_the_same_ground() -> void:
	var plain := _gathered(&"")
	assert_true(_gathered(&"restless_country") > plain,
		"the ground fed them no better in a restless country")


func test_the_ground_itself_is_the_ground_the_colony_farms() -> void:
	# 🔒 **On what they gather, never on the map.** A quirk that moved `yield_at`
	# would quietly hand the PC richer tiles as well, which is the opposite of the
	# quirk.
	var plain := WorldMap.new(24, 24, &"plains").yield_at(10, 10, &"food")
	assert_true(plain > 0.0, "plains grew nothing, so this proves nothing")
	_with_quirk(&"restless_country")
	assert_almost_eq(
		WorldMap.new(24, 24, &"plains").yield_at(10, 10, &"food"), plain, 0.0001,
		"the colony's own fields got better because the neighbours were angry")


func test_their_war_parties_are_more_numerous() -> void:
	var people := 30_000
	var plain := _marching(people)
	_with_quirk(&"restless_country")
	assert_true(_marching(people) > plain, "the same men marched out")


func test_a_village_still_keeps_enough_to_come_home_to() -> void:
	# 🔒 `VILLAGE_KEEPS` holds whatever sort of country this is. A village that
	# emptied itself would win one battle and then cease to exist, and the point
	# of the quirk is neighbours who last.
	_with_quirk(&"restless_country")
	# **Small enough that the floor is what binds**, not the share. A village big
	# enough to spare its share freely would satisfy this either way.
	var people := 12_000
	assert_true(_marching(people) > 0, "nobody marched at all, so this proves nothing")
	assert_true(_marching(people) <= people - Muster.VILLAGE_KEEPS,
		"the whole village marched and left nothing behind it")


## How many of a village of this size would go out with a war party.
##
## Through `Muster` itself. A helper that recomputed the arithmetic would be a
## second copy of the rule, and mutating the real one would leave it passing.
func _marching(people: int) -> int:
	var village := Village.new()
	village.id = &"village_test_0"
	village.people = people
	return Muster.going_from(village)


func test_their_agreements_move_more_of_the_winter() -> void:
	var village := Village.new()
	village.id = &"village_test_0"
	village.people = 40_000
	var plain := TradeAgreement.kept_back_by(village)
	assert_true(plain > 0.0, "they kept nothing back at all, so this proves nothing")

	_with_quirk(&"restless_country")
	assert_true(TradeAgreement.kept_back_by(village) < plain,
		"they held back exactly as much, so nothing more reaches the town")


func test_what_they_keep_is_the_winter_and_not_a_musket() -> void:
	# 🔒 *Months of eating for food and nothing for the rest*, which is what the
	# function always said and did not do: a village trading hides held back a
	# quantity of hides equal to two months of everyone's grain.
	var village := Village.new()
	village.id = &"village_test_0"
	village.people = 40_000
	assert_true(TradeAgreement.kept_back_by(village) > 0.0,
		"they will trade away the winter's food")
	assert_almost_eq(TradeAgreement.kept_back_by(village, &"furs"), 0.0, 0.0001,
		"they kept back furs against a hungry month")
