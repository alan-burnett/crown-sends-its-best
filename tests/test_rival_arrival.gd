extends TestCase

## A duke arrives as the Squeeze's fourth dimension (#300,
## `docs/mechanics/rival-pressure.md` §6).
##
## 🔒 **Prospering does not attract rivals.** A duke arrives because the Squeeze
## has decided to put a new strain on the player, and that decision is already
## specified: `crown-demands.md` §6, dimension 4, *more hands out*. **There is no
## second schedule and no separate director.**
##
## 🔒 **Present as a contact and active in the world are not the same thing.**
## SPEC §8.4 makes rivals fixed contacts, so all three sit on the roster from
## month one and `all_in` finds them — and one of them ships at loyalty 30, which
## is inside the low band, so before this he parked men on the colony's fields in
## **month one of every run** and the governor wrote a desperate letter about
## foreign troops before the colony had done anything at all.
##
## It also wasted the moment. Losing worked tiles to a foreign duke should be a
## thing that happens *to* a colony that got itself noticed.

const SEED: int = 3607

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


func _growth(reach: int) -> DemandGrowth:
	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.REACH)] = reach
	return growth


## A run at a given stage of the Squeeze, with every duke pushed to the bottom so
## that anything that *can* park does.
func _run_at(reach: int) -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.demands = _growth(reach)
	for duke in RivalDuke.all_in(run):
		duke.relationship = Relationship.new(duke.id, 1.0)
	return run


func _park(run: RunState) -> void:
	run.territory_driver = TerritoryDriver.new(run.map, run.colony, run.knowledge)
	run.territory_driver.denied = run.denied
	run.territory_driver.on_phase(
		WorldPhase.TERRITORY, run.world, run.log, run.streams)
	RivalTileDriver.new(run).on_phase(
		WorldPhase.TERRITORY, run.world, run.log, run.streams)


# --- 🔒 Nobody is here at the start -----------------------------------------

func test_no_duke_has_arrived_before_the_third_hand_is_out() -> void:
	# 🔒 They want the PC paying and weak, and in month one he is neither — there
	# is nothing to be attracted to.
	for reach in range(0, DemandSchedule.ASKERS_FOR_RIVALS - 1):
		var growth := _growth(reach)
		assert_true(DemandSchedule.askers(growth) < DemandSchedule.ASKERS_FOR_RIVALS,
			"the fixture already has rivals asking at reach %d" % reach)
		assert_eq(RivalDuke.how_many_arrived(growth), 0,
			"a duke had turned up at reach %d, with %d hands out"
				% [reach, DemandSchedule.askers(growth)])


func test_a_duke_who_has_not_arrived_parks_nothing() -> void:
	# The bug, stated as a test. Every duke at the very bottom of the scale, and
	# still not one man on the colony's ground.
	var run := _run_at(0)
	for duke in RivalDuke.all_in(run):
		assert_eq(RivalDuke.band_of(duke.relationship.loyalty), RivalDuke.MINIMUM,
			"the fixture did not put %s at the bottom" % duke.id)

	_park(run)
	assert_empty(run.log.of_type(DeniedTiles.EVENT_PARKED),
		"a duke nobody had summoned parked men on the colony's fields")
	assert_eq(run.denied.count_for(&"rival_duke"), 0)


func test_he_is_not_latched_at_the_bottom_before_he_turns_up() -> void:
	# 🔒 A duke who has not arrived is still drifting like everyone else, and
	# latching him at the bottom before he appears would have him arrive already
	# at war.
	var run := _run_at(0)
	RivalDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_empty(run.log.of_type(RivalBook.EVENT_LATCHED),
		"a duke who had not arrived was recorded as having gone to war")


func test_the_governor_cannot_write_about_fields_nobody_is_standing_on() -> void:
	# The second acceptance line, through the condition the letter fires on rather
	# than through the letter, because the trigger reads the denial.
	var run := _run_at(0)
	_park(run)
	var town := run.colony.in_order()[0]
	var context := LetterContext.new(run.world, run.contact(town.governor_id))
	context.colony = run.colony
	context.town = town
	context.log = run.log
	context.measures = ColonyMeasures.for_contact(run, run.contact(town.governor_id))
	assert_false(ContentRegistry.test_condition("they_are_on_my_fields", {}, context),
		"a governor was ready to write about foreign troops nobody had sent")


# --- 🔒 And he behaves exactly as before once he is ------------------------

func test_a_duke_who_has_arrived_and_fallen_low_still_parks() -> void:
	# The third acceptance line. Nothing about what a duke *does* has changed.
	var run := _run_at(DemandSchedule.ASKERS_FOR_RIVALS)
	assert_true(RivalDuke.how_many_arrived(run.demands) > 0,
		"the fixture summoned nobody, so this proves nothing")

	_park(run)
	assert_not_empty(run.log.of_type(DeniedTiles.EVENT_PARKED),
		"a duke who had arrived and gone to the bottom left the fields alone")


func test_they_arrive_staggered_and_never_all_at_once() -> void:
	# 🔒 §6: one source enters per draw, so the colony faces one duke, then two,
	# then three across a run rather than three in one spring. It falls out of
	# `askers` rather than needing a schedule of its own.
	var arrived: Array = []
	for reach in range(0, 8):
		arrived.append(RivalDuke.how_many_arrived(_growth(reach)))

	assert_eq(arrived[0], 0, "a duke was here before the Squeeze had drawn one")
	for step in range(1, arrived.size()):
		var jump: int = int(arrived[step]) - int(arrived[step - 1])
		assert_true(jump >= 0, "the number of dukes went down, and no source withdraws")
		assert_true(jump <= 1,
			"two dukes arrived on one draw, so they bunched: %s" % [arrived])
	assert_true(int(arrived[arrived.size() - 1]) > 0,
		"no duke ever arrives however far the Squeeze goes")


func test_the_same_run_always_meets_the_same_duke_first() -> void:
	var first: Array = []
	for pass_index in 2:
		var run := _run_at(DemandSchedule.ASKERS_FOR_RIVALS)
		var arrived := RivalDuke.arrived_in(run, run.demands)
		first.append(String((arrived[0] as Contact).id))
	assert_eq(first[0], first[1], "two identical runs met different dukes first")


func test_arrival_reads_the_squeeze_and_keeps_no_state_of_its_own() -> void:
	# 🔒 §6: *there is no second schedule and no separate director.* A stored
	# arrival month would be a second place the truth lived, and the two would
	# disagree the first time a save was loaded.
	var run := _run_at(DemandSchedule.ASKERS_FOR_RIVALS)
	for duke in RivalDuke.all_in(run):
		for entry in duke.get_property_list():
			var name := String(entry["name"])
			assert_false(name.contains("arriv"),
				"%s carries an arrival field of his own: %s" % [duke.id, name])

	# And it survives a save because it is derived from something that does.
	var restored := DemandGrowth.from_dict(run.demands.to_dict())
	assert_eq(RivalDuke.how_many_arrived(restored),
		RivalDuke.how_many_arrived(run.demands),
		"how many dukes had arrived did not survive the save")
