extends TestCase

## The Chancellor warns, and he is delighted to (#268,
## `docs/mechanics/endings.md` §2, §3, SPEC §13.1).
##
## 🔒 **Every fail condition passes through a last-chance stage with a formal
## Chancellor warning, so defeat is never a surprise.**
##
## 🔒 **And it is not a mechanism.** No timer, no countdown, no stage object. The
## stage is the overlap of warnings that already exist — standing's ladder and
## the Marshal's staged withdrawal — and what was missing is the Chancellor
## noticing. He looks every month and the log is the whole of the memory.
##
## 🔒 **His tone runs opposite to his circumstance.** He writes `pleased` about
## ruin, whatever his loyalty and however urgent it is. A dev who "fixes" that to
## match the news has removed the joke the character exists to make.

const SEED: int = 9137

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


func _look(run: RunState, month: int) -> Dictionary:
	run.world.month = month
	return LastChance.look(
		run.colony, run.parties, run.companies, run.standing, run.contact(&"marshal"),
		run.world, run.log)


# --- 🔒 No timer, and no stage ----------------------------------------------

func test_no_countdown_exists_for_the_last_chance_stage() -> void:
	# 🔒 §2: *a dev who finds himself building a countdown for it has built a
	# third timer alongside two that were already running.* Asked of the file,
	# because it is the first thing anybody reaches for.
	var code := _code_of("res://sim/crown/last_chance.gd")
	var found := PackedStringArray()
	for token in ["countdown", "months_left", "turns_left", "deadline",
			"stage_began", "warned_month", "elapsed"]:
		if code.contains(token):
			found.append(token)
	assert_empty(found, "the last chance has a timer: %s" % ", ".join(found))


func test_it_holds_no_state_at_all() -> void:
	# The log is the memory. A field here recording that the stage had begun
	# would be a stage, and there is no stage.
	var fields := PackedStringArray()
	for entry in LastChance.new().get_property_list():
		var name := String(entry["name"])
		if name.begins_with("_") or name == "LastChance.gd" or name == "script" \
				or name == "Built-in script" or name == "RefCounted":
			continue
		if int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(name)
	assert_empty(fields, "the last chance carries state: %s" % ", ".join(fields))


func test_he_looks_every_month_moved_or_not() -> void:
	var run := _run()
	for month in range(1, 5):
		_look(run, month)
	assert_eq(run.log.of_type(LastChance.EVENT_LOOKED).size(), 4,
		"a month went by that nobody looked at")


# --- 🔒 As each condition flips ---------------------------------------------

func test_he_notices_a_condition_becoming_true() -> void:
	var run := _run()
	_look(run, 1)
	assert_empty(LastChance.newly_true(run.log, 1),
		"the first look reported a flip, with nothing to have flipped from")

	for town in run.colony.in_order():
		town.rebelling = true
	_look(run, 2)
	var flipped := LastChance.newly_true(run.log, 2)
	assert_eq(flipped.size(), 1, "the flip was reported as %s" % [flipped])
	assert_eq(String(flipped[0]), LastChance.EVERY_TOWN_REBELS)


func test_the_first_look_reports_nothing_however_bad_it_already_is() -> void:
	# 🔒 *Flipped* needs a before. And one of the four — no Crown soldiers on the
	# ground — is **true from the start of every run**, so without this he would
	# open every game by formally warning the player that it was nearly over.
	var run := _run()
	var flags := _look(run, 1)
	assert_true(LastChance.how_many_true(flags) > 0,
		"nothing was true on month one, so this proves nothing")
	assert_empty(LastChance.newly_true(run.log, 1))


func test_and_says_nothing_the_month_after() -> void:
	# 🔒 §3: *as each condition flips*, not while one holds. A letter every month
	# would be nagging, from the one contact whose comic value is that he turns
	# up rarely and at the worst possible moment.
	var run := _run()
	_look(run, 1)
	for town in run.colony.in_order():
		town.rebelling = true
	_look(run, 2)
	_look(run, 3)
	assert_empty(LastChance.newly_true(run.log, 3),
		"he wrote again about a condition that merely stayed true")


func test_his_letter_names_which_are_and_which_are_not() -> void:
	# The acceptance line. Both halves come from the same look, so they cannot
	# describe different months.
	var run := _run()
	for town in run.colony.in_order():
		town.rebelling = true
	var flags := _look(run, 4)

	var gone := IndependenceClause.phrase_for(flags, true)
	var standing := IndependenceClause.phrase_for(flags, false)
	assert_false(gone.is_empty(), "he named nothing that had gone wrong")
	assert_false(standing.is_empty(), "he named nothing still standing")
	assert_ne(gone, standing)


func test_every_condition_has_prose_beside_it() -> void:
	# 🔒 Otherwise an id reaches the player in the most formal letter of the run.
	assert_empty(IndependenceClause.missing(),
		"a condition has no phrase: %s" % ", ".join(IndependenceClause.missing()))


func test_the_four_are_the_ones_the_check_decides_on() -> void:
	# 🔒 A second reading of *has the Crown lost confidence* would be a second
	# place the answer lived, and the Chancellor would start writing about a
	# condition the check did not believe in.
	var run := _run()
	var flags := LastChance.conditions_of(
		run.colony, run.companies, run.standing, run.contact(&"marshal"), run.world)
	assert_eq(flags.size(), 4)
	for name in LastChance.CONDITIONS:
		assert_has(flags, name)

	# All four true is exactly what `RunEndCheck` calls Independence.
	for town in run.colony.in_order():
		town.rebelling = true
	var all_true := LastChance.how_many_true(LastChance.conditions_of(
		run.colony, run.companies, run.standing, run.contact(&"marshal"), run.world)) == 4
	assert_eq(all_true, RunEndCheck.is_independent(
		run.colony, run.companies, run.standing, run.contact(&"marshal"), run.world),
		"the four the Chancellor names and the four the check decides on disagree")


# --- 🔒 On a falling population ---------------------------------------------

func test_he_writes_as_the_colony_dwindles_and_again_as_it_worsens() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	town.experts = {}

	var wrote := 0
	var month := 1
	for people in [200_000, 38_000, 37_000, 24_000, 14_000, 7_000, 2_000]:
		town.workers = people
		_look(run, month)
		if LastChance.newly_dire(run.log, month):
			wrote += 1
		month += 1
	assert_eq(wrote, LastChance.DIRE_AT.size(),
		"he wrote %d times on the way down through %d rungs"
			% [wrote, LastChance.DIRE_AT.size()])


func test_and_never_twice_about_the_same_figure() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	town.experts = {}

	town.workers = 200_000
	_look(run, 1)
	town.workers = 20_000
	_look(run, 2)
	assert_true(LastChance.newly_dire(run.log, 2))

	# It recovers a little and falls back to the same rung.
	town.workers = 30_000
	_look(run, 3)
	town.workers = 20_000
	_look(run, 4)
	assert_false(LastChance.newly_dire(run.log, 4),
		"a town that lost a man and took in another set him writing twice")


func test_a_healthy_colony_is_on_no_rung_at_all() -> void:
	assert_eq(LastChance.rung_for(10_000_000), -1)
	assert_true(LastChance.rung_for(1) >= 0)


# --- 🔒 No ending fires without a warning having preceded it -----------------

func test_no_ending_fires_in_a_month_he_was_not_shown() -> void:
	# 🔒 SPEC §13.1: *defeat is never a surprise.* The ordering is structural —
	# the look is in `RunEndDriver` above the check, so there is no arrangement of
	# the driver list that could put an ending in a month he did not see.
	var run := _run()
	var driver := RunEndDriver.new(run)
	for town in run.colony.in_order().duplicate():
		run.colony.towns.erase(town)

	run.world.month = 9
	driver.on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)

	var lost := run.log.of_type(RunEndDriver.EVENT_LOST)
	assert_eq(lost.size(), 1, "the run did not end, so this proves nothing")
	assert_false(LastChance.latest(run.log, lost[0].month).is_empty(),
		"a run ended in a month the Chancellor was shown nothing")


func test_the_look_comes_before_the_decision_in_the_same_file() -> void:
	# Asserted on the source, because it is an ordering and not a value: a driver
	# of its own could be reordered in the list and nothing would notice.
	var code := _code_of("res://sim/crown/run_end_driver.gd")
	var looked := code.find("LastChance.look")
	var decided := code.find("RunEndCheck.reason_for")
	assert_true(looked >= 0 and decided > looked,
		"the ending is decided before the Chancellor is shown anything")


# --- 🔒 He is delighted ------------------------------------------------------

func test_he_writes_pleased_about_ruin_whatever_his_loyalty() -> void:
	# 🔒 §3, and the acceptance line. Every other contact's tone compresses
	# loyalty and urgency into something that matches the news; his inverts it.
	var run := _run()
	var chancellor := run.contact(&"chancellor")
	assert_true(chancellor != null, "there is no Chancellor")

	for loyalty in [0.0, 12.0, 50.0, 100.0]:
		chancellor.relationship = Relationship.new(chancellor.id, loyalty)
		for urgency in [0.0, 0.5, 1.0]:
			assert_eq(Director.tone_for(chancellor, urgency), Tone.PLEASED,
				"at loyalty %f and urgency %f he wrote %s"
					% [loyalty, urgency, Director.tone_for(chancellor, urgency)])


func test_and_he_is_the_only_one() -> void:
	# A fixed tone is a fact about a person, and exactly one person has it. If a
	# second contact ever gets one it is a design decision and not a tuning one.
	var run := _run()
	var fixed := PackedStringArray()
	var ids: PackedStringArray = PackedStringArray(run.contacts.keys())
	ids.sort()
	for id in ids:
		var contact: Contact = run.contacts[id]
		if contact != null and not String(contact.writes_in).is_empty():
			fixed.append(String(contact.id))
	assert_eq(fixed, PackedStringArray(["chancellor"]),
		"more than the Chancellor writes in a fixed tone: %s" % [fixed])


func test_everybody_else_still_writes_as_the_spec_says() -> void:
	var run := _run()
	var marshal := run.contact(&"marshal")
	marshal.relationship = Relationship.new(marshal.id, 5.0)
	assert_eq(Director.tone_for(marshal, 0.0), Tone.HATEFUL,
		"the fixed tone leaked onto somebody who has not earned it")


func test_nothing_fixes_his_tone_to_match_the_news() -> void:
	# 🔒 §3: *a dev who "fixes" his tone to match the news has removed the joke
	# the character exists to make.* Asked of the director, because the fix looks
	# like a bug report.
	var code := _code_of("res://correspondence/director/director.gd")
	assert_false(code.contains("chancellor"),
		"the director branches on the Chancellor by name rather than on a field")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
