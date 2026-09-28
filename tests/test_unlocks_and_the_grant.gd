extends TestCase

## Each perk and quirk unlocks by its own condition, and the grant is a real split
## (#465, `perks-and-quirks.md` §1, `map.md` §5, SPEC §5, §6.1, §14.3).
##
## 🔒 A run that meets an option's condition makes it available to the next
## run's commission, and never before; the unlocks survive in the hall. 🔒 Every
## option but the first names one condition the registry knows. 🔒 Leaning the
## grant toward one pile gives it +45% and the other two −22.5% each; taken as it
## comes, it is the grant.

const SEED: int = 465
const HALL: String = "user://test_unlocks_and_the_grant.cfg"

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	Records.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HALL))


func after_each() -> void:
	Records.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HALL))
	reset_world()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## A run that ended this way, in this month.
func _ended(run: RunState, reason: StringName, month: int) -> RunState:
	run.world.month = month
	run.ending = RunEnding.end(reason, run.log, month)
	return run


# --- 🔒 A run unlocks what it earned, for the runs after it ---------------------

func test_a_run_that_meets_a_condition_unlocks_it_for_the_next_run_and_not_before() -> void:
	assert_false(RunModifiers.unlocked(content, RunModifiers.QUIRKS_RECORD, Records.unlocks(HALL))
		.has("distant_colony"), "a quirk was offered before any run had earned it")

	var short := _ended(_run(), RunEnding.RETIRED, 40)
	Records.remember(short, content, HALL)
	assert_false(Records.unlocks(HALL).has("distant_colony"), "a run of three years unlocked eight years' worth")

	var long := _ended(_run(), RunEnding.RETIRED, 8 * WorldState.MONTHS_PER_YEAR)
	Records.remember(long, content, HALL)
	assert_true(Records.unlocks(HALL).has("distant_colony"), "a run of eight years unlocked nothing")
	assert_true(RunModifiers.unlocked(content, RunModifiers.QUIRKS_RECORD, Records.unlocks(HALL))
		.has("distant_colony"), "what a run unlocked was not offered to the next")


func test_the_unlocks_survive_in_the_hall() -> void:
	var run := _ended(_run(), RunEnding.RETIRED, 100)
	run.log.emit(ConsumePhase.EVENT_FAMINE, &"ashmere", 12, {}, WorldPhase.COLONY_MONTH)
	Records.remember(run, content, HALL)
	Records.reset()
	var kept := Records.unlocks(HALL)
	assert_true(kept.has("distant_colony") and kept.has("it_could_be_worse"),
		"the hall forgot what a past run unlocked: %s" % ", ".join(kept))


func test_the_first_day_is_never_earned_because_it_is_never_locked() -> void:
	var run := _ended(_run(), RunEnding.RETIRED, 100)
	assert_false(UnlockConditions.unlocked_by(run, content).has(String(RunSetup.PERK_FIRST_DAY)))


# --- 🔒 Each by its own condition ------------------------------------------------------

func test_the_court_thinking_highly_of_him_is_all_three_of_them() -> void:
	var run := _ended(_run(), RunEnding.RETIRED, 30)
	var ids: Array = ["steward", "marshal", "chancellor"]
	for id in ids:
		run.contact(StringName(id)).relationship.loyalty = 90.0
	assert_true(UnlockConditions.unlocked_by(run, content).has("well_connected_at_court"))
	run.contact(&"marshal").relationship.loyalty = 20.0
	assert_false(UnlockConditions.unlocked_by(run, content).has("well_connected_at_court"),
		"two of the three thinking well of him was the whole court")


func test_surviving_a_refusal_counts_only_for_a_man_who_then_retires() -> void:
	var run := _ended(_run(), RunEnding.RETIRED, 30)
	assert_false(UnlockConditions.unlocked_by(run, content).has("my_boss_is_a_jerk"))
	run.log.emit(CrownRefusal.EVENT_REFUSING, &"crown", 20, {}, WorldPhase.RUN_END_CHECK)
	assert_true(UnlockConditions.unlocked_by(run, content).has("my_boss_is_a_jerk"))
	run.ending = RunEnding.end(RunEnding.FAILED, run.log, 30)
	assert_false(UnlockConditions.unlocked_by(run, content).has("my_boss_is_a_jerk"),
		"a man the Crown gave up on was counted as having survived it")


func test_every_option_but_the_first_names_a_condition_the_registry_knows() -> void:
	var validator := ContentValidator.new()
	validator.check_run_modifiers(content)
	assert_true(validator.ok(), "the perks and quirks do not all say what unlocks them: %s"
		% str(validator.problems))

	# The loaded record itself, so the check that reads it is the one the tool runs.
	(RunModifiers.entry(content, RunModifiers.PERKS_RECORD, "righteous") as Dictionary).erase(UnlockConditions.KEY)
	var broken := ContentValidator.new()
	broken.check_run_modifiers(content)
	assert_false(broken.ok(), "an option nothing could ever unlock passed the validator")


# --- 🔒 One grant, split ---------------------------------------------------------

func _town_of(split: StringName) -> Town:
	var setup := RunSetup.new()
	setup.seed_value = SEED
	setup.split = split
	return RunState.from_setup(setup).colony.in_order()[0]


func test_leaning_toward_a_pile_costs_the_other_two() -> void:
	var even := _town_of(RunSetup.SPLIT_BALANCED)
	assert_eq(even.workers, RunState.STARTING_WORKERS, "taken as it comes, the grant was not the grant")
	assert_almost_eq(even.held(&"food"), RunState.STARTING_FOOD, 0.001)

	var people := _town_of(RunSetup.SPLIT_PEOPLE)
	assert_eq(people.workers, int(roundf(RunState.STARTING_WORKERS * 1.45)))
	assert_almost_eq(people.held(&"food"), RunState.STARTING_FOOD * 0.775, 0.001,
		"leaning toward people cost the stores nothing")

	var stores := _town_of(RunSetup.SPLIT_STORES)
	assert_almost_eq(stores.held(&"food"), RunState.STARTING_FOOD * 1.45, 0.001)
	assert_eq(stores.workers, int(roundf(RunState.STARTING_WORKERS * 0.775)),
		"leaning toward stores cost the party nobody")
	assert_almost_eq(_town_of(RunSetup.SPLIT_GOLD)._gold, even._gold * 1.45, 0.001,
		"leaning toward gold brought no more gold")
	assert_almost_eq(people._gold, even._gold * 0.775, 0.001, "leaning toward people cost no gold")


func test_the_setup_offers_it_as_it_comes() -> void:
	assert_true(RunSetup.SPLITS.has(RunSetup.SPLIT_BALANCED))
	assert_eq(String(RunSetup.new().split), String(RunSetup.SPLIT_BALANCED))
