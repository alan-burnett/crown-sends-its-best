extends TestCase

## The main menu and the hall of records (#353, #354; SPEC §15, §16.2, §14.3).
##
## 🔒 **Continue is absent, not greyed**, when there is no run and when there is
## one this build cannot load. A greyed control is a promise that it might work,
## and there is nothing here that could make it work.
##
## 🔒 **New Game destroys the run in progress**, which is the third irreversible
## act in the game — and it is confirmed in its own words, naming the colony and
## the year it reached, because a confirmation that reads like every other
## confirmation is one the player stops reading.
##
## 🔒 **A save from an older version is refused, not migrated** (`CLAUDE.md`),
## and this screen is the only place that has ever had anywhere to say so.
##
## 🔒 **The hall survives New Game.** §16.2's one-save rule is about the run;
## the hall is what is left of the ones before it, and deleting the save must not
## delete it — or the only record of a colony would be destroyed by founding the
## next one.
##
## **The screens themselves are not tested**, per `CLAUDE.md`. What is tested is
## what they read: peeking at a save without loading it, the settings that
## outlive a run, and the hall.

const SEED: int = 8812

## Scratch paths, so a test never touches the player's own files.
const SAVE: String = "user://test_menu.save"
const SETTINGS: String = "user://test_menu_settings.cfg"
const HALL: String = "user://test_menu_records.cfg"

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	_clear()


func after_each() -> void:
	_clear()
	reset_world()
	content.free()


func _clear() -> void:
	for path in [SAVE, SETTINGS, HALL]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


# --- 🔒 Peeking at a save, without loading it ------------------------------

func test_no_save_is_no_run_in_progress() -> void:
	var peeked := SaveGame.peek(SAVE)
	assert_eq(int(peeked["result"]), SaveGame.Result.NO_SAVE)
	assert_eq(String(peeked["colony"]), "")


func test_a_saved_run_says_its_colony_and_its_year() -> void:
	# The New Game confirmation names both, so both have to come out of a save
	# without building a whole `RunState` to read them.
	var run := _run()
	run.world.month = 30  # Two and a half years in.
	SaveGame.save(run, SAVE)

	var peeked := SaveGame.peek(SAVE)
	assert_eq(int(peeked["result"]), SaveGame.Result.OK)
	assert_eq(String(peeked["colony"]), run.colony.in_order()[0].display_name,
		"the save does not know what the colony is called")
	assert_eq(int(peeked["year"]), 3, "month 30 is in year %d" % peeked["year"])


func test_the_year_is_the_same_arithmetic_the_world_does() -> void:
	# Not a second opinion about when a year turns.
	var run := _run()
	for month in [0, 11, 12, 47]:
		run.world.month = month
		SaveGame.save(run, SAVE)
		assert_eq(int(SaveGame.peek(SAVE)["year"]), run.world.year_index(),
			"month %d read as a different year outside the run" % month)


func test_a_save_from_another_version_is_reported_and_not_loaded() -> void:
	# 🔒 `CLAUDE.md`: refused, not migrated. The menu is where that surfaces.
	var run := _run()
	SaveGame.save(run, SAVE)
	var data: Variant = _raw(SAVE)
	(data as Dictionary)["version"] = RunState.SAVE_VERSION + 7
	_write(SAVE, data)

	var peeked := SaveGame.peek(SAVE)
	assert_eq(int(peeked["result"]), SaveGame.Result.WRONG_VERSION)
	assert_true(String(peeked["message"]).contains(str(RunState.SAVE_VERSION + 7)),
		"the report does not say which version the save is: %s" % peeked["message"])
	assert_true(String(peeked["message"]).contains(str(RunState.SAVE_VERSION)),
		"the report does not say which version the game is")


func test_a_damaged_save_is_reported_not_crashed() -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("this is not a save")
	file.close()
	assert_eq(int(SaveGame.peek(SAVE)["result"]), SaveGame.Result.UNREADABLE)


func test_a_colony_with_no_towns_left_still_peeks() -> void:
	# A run can end with nothing standing, and the menu still has to draw.
	var run := _run()
	run.colony.towns.clear()
	SaveGame.save(run, SAVE)
	var peeked := SaveGame.peek(SAVE)
	assert_eq(int(peeked["result"]), SaveGame.Result.OK)
	assert_eq(String(peeked["colony"]), "")


# --- 🔒 What the menu does with it ------------------------------------------

func _menu(peeked: Dictionary) -> MainMenuScreen:
	var menu := MainMenuScreen.new()
	menu.save = peeked
	return menu


func test_continue_is_absent_when_there_is_no_run() -> void:
	var menu := _menu(SaveGame.peek(SAVE))
	assert_false(menu.can_continue(), "a menu with no save offered to continue")
	assert_false(menu.would_destroy_a_run(),
		"a new game with no save asked to destroy something")
	menu.free()


func test_continue_is_absent_for_a_save_this_build_cannot_load() -> void:
	# 🔒 **Loadable, not merely present.** Offering it would be offering a load
	# that fails.
	var menu := _menu({
		"result": SaveGame.Result.WRONG_VERSION, "colony": "Ashmere", "year": 4,
		"version": 0, "message": "from another version",
	})
	assert_false(menu.can_continue(), "a stale save was offered as a run in progress")
	assert_true(menu.would_destroy_a_run(),
		"starting over on top of a stale save was treated as destroying nothing")
	menu.free()


func test_new_game_confirms_in_its_own_words_naming_the_colony_and_the_year() -> void:
	# 🔒 The acceptance line. **A confirmation that reads like every other
	# confirmation is one the player stops reading.**
	var run := _run()
	run.world.month = 8 * 12
	SaveGame.save(run, SAVE)

	var menu := _menu(SaveGame.peek(SAVE))
	var words := menu.confirmation_text()
	assert_true(words.contains(run.colony.in_order()[0].display_name),
		"the confirmation does not name the colony: %s" % words)
	assert_true(words.contains("ninth"), "it does not say which year: %s" % words)
	assert_true(words.to_lower().contains("destroy"),
		"it does not say what happens: %s" % words)
	menu.free()


func test_a_nameless_colony_is_still_confirmed() -> void:
	var menu := _menu({
		"result": SaveGame.Result.OK, "colony": "", "year": 2,
		"version": RunState.SAVE_VERSION, "message": "",
	})
	assert_false(menu.confirmation_text().is_empty(),
		"a run with no readable name was thrown away without asking")
	menu.free()


func test_nothing_is_confirmed_when_there_is_nothing_to_lose() -> void:
	var menu := _menu(SaveGame.peek(SAVE))
	assert_eq(menu.confirmation_text(), "",
		"a first launch was asked to confirm destroying nothing")
	menu.free()


# --- 🔒 Settings outlive the run -------------------------------------------

func test_the_text_size_survives_a_run_being_thrown_away() -> void:
	# A player who set the text larger because he needs it larger must not have
	# to do it again because he started a new colony.
	Settings.ensure_loaded(SETTINGS)
	Settings.set_text_scale(1.4)
	Settings.save_settings(SETTINGS)

	SaveGame.delete_save(SAVE)
	Settings.reset()
	Settings.ensure_loaded(SETTINGS)
	assert_almost_eq(Settings.text_scale(), 1.4, 0.001,
		"the text size was lost with the run")


func test_a_missing_settings_file_is_the_defaults() -> void:
	Settings.ensure_loaded(SETTINGS)
	assert_almost_eq(Settings.text_scale(), Settings.TEXT_SCALE_DEFAULT, 0.001)
	assert_almost_eq(Settings.music_volume(), Settings.VOLUME_DEFAULT, 0.001)


func test_a_setting_cannot_be_set_outside_its_range() -> void:
	# A scale that produced a two-pixel font would be a setting that broke the
	# game rather than one that made it easier to read.
	Settings.set_text_scale(99.0)
	assert_almost_eq(Settings.text_scale(), Settings.TEXT_SCALE_MAX, 0.001)
	Settings.set_text_scale(-4.0)
	assert_almost_eq(Settings.text_scale(), Settings.TEXT_SCALE_MIN, 0.001)
	Settings.set_music_volume(50.0)
	assert_almost_eq(Settings.music_volume(), 1.0, 0.001)


func test_the_text_size_reaches_every_label_and_every_button() -> void:
	# 🔒 One place, so every screen moves together — the setting is not one a
	# screen honours, it is what the two theme helpers draw at.
	Settings.set_text_scale(1.0)
	var plain := DeskTheme.scaled(DeskTheme.SIZE_BODY)
	Settings.set_text_scale(Settings.TEXT_SCALE_MAX)
	assert_true(DeskTheme.scaled(DeskTheme.SIZE_BODY) > plain,
		"turning the text size up drew the same size")
	assert_true(DeskTheme.scaled(DeskTheme.TAP_HEIGHT) > DeskTheme.TAP_HEIGHT,
		"the words grew and the thing to press did not")


func test_the_version_is_the_projects_and_not_a_constant() -> void:
	# A version in two places is a version that disagrees with itself the first
	# time somebody bumps one.
	assert_false(Settings.game_version().is_empty())


# --- 🔒 The hall of records -------------------------------------------------

func _ended(reason: StringName, how: StringName = &"", month: int = 60) -> RunState:
	var run := _run()
	run.world.month = month
	run.ending = RunEnding.new()
	run.ending.reason = reason
	run.ending.how = how
	run.ending.month = month
	return run


func test_a_first_launch_has_an_empty_hall() -> void:
	Records.ensure_loaded(HALL)
	assert_true(Records.is_empty(HALL))
	assert_empty(Records.all(HALL))


func test_a_finished_run_is_recorded_with_what_became_of_it() -> void:
	var run := _ended(RunEnding.RETIRED)
	assert_true(Records.remember(run, content, HALL))

	var kept := Records.all(HALL)
	assert_eq(kept.size(), 1)
	var entry: Dictionary = kept[0]
	assert_eq(String(entry[Records.FIELD_COLONY]),
		run.colony.in_order()[0].display_name)
	assert_eq(int(entry[Records.FIELD_YEAR]), 6, "sixty months is year six")
	assert_eq(String(entry[Records.FIELD_REASON]), String(RunEnding.RETIRED))


func test_both_endings_and_retirement_are_distinguishable() -> void:
	# `endings.md`: both ways of losing are FAILED and cost the same, so without
	# `how` the hall could not tell them apart — and those are the two stories a
	# player most wants to remember apart.
	var said := PackedStringArray()
	for pair in [
		[RunEnding.RETIRED, &""],
		[RunEnding.TERM_EXPIRED, &""],
		[RunEnding.FAILED, RunEndCheck.OVERRUN],
		[RunEnding.FAILED, RunEndCheck.INDEPENDENCE],
	]:
		said.append(Records.how_it_ended({
			Records.FIELD_REASON: String(pair[0]),
			Records.FIELD_HOW: String(pair[1]),
		}))
	var seen: Dictionary = {}
	for line in said:
		seen[line] = true
	assert_eq(seen.size(), 4, "four endings read as %d things: %s" % [seen.size(), said])


func test_the_epitaph_is_kept_rather_than_looked_up_again() -> void:
	# A later change to `data/epitaphs_en/` must not rewrite what the hall says
	# about a colony that fell two years ago.
	var run := _ended(RunEnding.FAILED, RunEndCheck.OVERRUN)
	Records.remember(run, content, HALL)
	var entry: Dictionary = Records.all(HALL)[0]
	assert_true(entry.has(Records.FIELD_EPITAPH),
		"the run was recorded without its epitaph")


func test_recording_the_same_run_twice_records_it_once() -> void:
	# It reaches the hall from retiring and from the end-of-run check, and the
	# screens that show an ending may be opened more than once.
	var run := _ended(RunEnding.RETIRED)
	assert_true(Records.remember(run, content, HALL))
	assert_false(Records.remember(run, content, HALL),
		"the same run went into the hall twice")
	assert_eq(Records.all(HALL).size(), 1)


func test_a_run_still_in_progress_is_not_recorded() -> void:
	assert_false(Records.remember(_run(), content, HALL),
		"a run that had not ended was written into the hall")


func test_the_hall_survives_the_save_being_destroyed() -> void:
	# 🔒 The acceptance line. New Game destroys the save and must not destroy
	# this, or founding a colony would delete the record of the last one.
	var run := _ended(RunEnding.FAILED, RunEndCheck.INDEPENDENCE)
	SaveGame.save(run, SAVE)
	Records.remember(run, content, HALL)

	SaveGame.delete_save(SAVE)
	Records.reset()

	assert_false(FileAccess.file_exists(SAVE), "the save was not destroyed")
	assert_eq(Records.all(HALL).size(), 1, "the hall went with the run")


func test_the_hall_is_a_different_file_from_the_save() -> void:
	assert_ne(Records.PATH, SaveGame.SAVE_PATH,
		"the hall is kept in the save, which New Game deletes")


func test_the_most_recent_run_is_first() -> void:
	for month in [24, 48, 72]:
		Records.remember(_ended(RunEnding.RETIRED, &"", month), content, HALL)
	var kept := Records.all(HALL)
	assert_eq(kept.size(), 3)
	assert_eq(int((kept[0] as Dictionary)[Records.FIELD_YEAR]), 7,
		"the oldest run was at the top")


func test_no_score_is_written_into_the_hall() -> void:
	# 🔒 `prestige.md` §10: a long run almost always out-scores a short one, so a
	# raw total invites the hall to be read as a high-score table and played for
	# length. **Absent rather than hidden**, so turning it on is a decision.
	var run := _ended(RunEnding.RETIRED)
	run.ending.score = 4_500.0
	Records.remember(run, content, HALL)
	var entry: Dictionary = Records.all(HALL)[0]
	for key in entry:
		assert_false(String(key).contains("score"),
			"the hall carries '%s'" % key)
		assert_false(String(key).contains("prestige"),
			"the hall carries '%s'" % key)


func _raw(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Variant = file.get_var(false)
	file.close()
	return data


func _write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(data, false)
	file.close()
