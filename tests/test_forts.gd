extends TestCase

## Dukes raise forts, and a fort can fall (#419,
## `docs/mechanics/tiles-and-improvements.md` §6).
##
## 🔒 A fort records who built it; its walls serve whoever stands in it. A
## manned fort falls with its last defender, an empty one to a month of razing,
## and either way it is one event naming the owner.

const SEED: int = 419

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


## A run with open plains well away from the colony's towns.
func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var field := _field(run)
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			if run.map.in_bounds(field.x + dx, field.y + dy):
				run.map.set_terrain(field.x + dx, field.y + dy, &"plains")
				run.map.clear_improvement(field.x + dx, field.y + dy)
	return run


func _field(run: RunState) -> Vector2i:
	return run.colony.in_order()[0].at + Vector2i(10, 0)


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	context.commanders = run.commanders
	return context


func _raise(run: RunState, allegiance: StringName, size: int, at: Vector2i) -> Company:
	var context := _context(run)
	var company := run.companies.raise_company(
		allegiance, size, {}, Company.SUPPORTED_ABROAD, at, context,
		StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	company.raised_by = &"rival_duke_montargis" if allegiance == Company.RIVAL else &""
	Commanders.take_command(company, null, run, context)
	return company


func _month(run: RunState) -> void:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.run = run
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	run.world.month += 1


## A duke's fort on `at`, as though his men had raised it.
func _dukes_fort(run: RunState, at: Vector2i) -> void:
	run.map.build(at.x, at.y, &"fort", null, 0, &"rival_duke_montargis", Company.RIVAL)


# --- 🔒 A duke raises one -----------------------------------------------------------

func test_a_dukes_company_in_the_field_raises_a_fort_and_it_fights_from_it() -> void:
	var run := _run()
	var at := _field(run)
	var men := _raise(run, Company.RIVAL, 5_000, at)
	var bare := Force.of(men, run.map, true)
	_month(run)
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "fort", "a duke's men in the field built nothing")
	var owner := run.map.fort_owner(at.x, at.y)
	assert_eq(String(owner["by"]), "rival_duke_montargis", "the fort does not say it is the duke's")
	assert_eq(String(owner["side"]), String(Company.RIVAL))
	assert_true(Force.of(men, run.map, true) > bare, "the walls do nothing for the men in them")


func test_a_tribe_never_fortifies() -> void:
	var run := _run()
	var at := _field(run)
	_raise(run, Company.NATIVE, 5_000, at)
	_month(run)
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "", "a war party raised a fort")


# --- 🔒 How it falls ------------------------------------------------------------------

func test_a_manned_fort_falls_with_its_last_defender() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	var garrison := _raise(run, Company.RIVAL, 10, at)
	var storm := _raise(run, Company.COLONIAL, 2_000_000, at + Vector2i(1, 0))
	Battle.resolve(storm, garrison, run.map, _context(run))
	assert_true(garrison.is_empty(), "the fixture's assault did not destroy the garrison")
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "", "the fort outlived its last defender")
	var fell: Array = run.log.of_type(Forts.EVENT_FELL)
	assert_eq(fell.size(), 1)
	assert_eq(String(fell[0].payload["owner"]), "rival_duke_montargis")
	assert_eq(String(fell[0].payload["how"]), String(Forts.STORMED))
	assert_eq(String(fell[0].payload["brought_down_by"]), String(Company.COLONIAL))


func test_an_empty_fort_falls_to_a_month_of_razing_and_burns_no_farm() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	# The colony's men stand on a road beside it, so walls of their own are not
	# on offer and the fort is the thing to hand.
	var beside := at + Vector2i(1, 0)
	run.map.build(beside.x, beside.y, &"road")
	_raise(run, Company.COLONIAL, 2_000, beside)
	_month(run)
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "", "an empty fort stood a month beside the colony's men")
	var fell: Array = run.log.of_type(Forts.EVENT_FELL)
	assert_eq(fell.size(), 1)
	assert_eq(String(fell[0].payload["how"]), String(Forts.RAZED))
	assert_empty(run.log.of_type(Company.EVENT_RAZED), "a fallen fort was reported as a burnt farm")


func test_a_manned_fort_is_not_razed() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	_raise(run, Company.RIVAL, 5_000, at)
	var beside := at + Vector2i(2, 0)
	run.map.build(beside.x, beside.y, &"road")
	assert_false(Forts.is_manned(beside, run.companies))
	assert_true(Forts.is_manned(at, run.companies))


func test_marching_out_leaves_it_standing() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	var men := _raise(run, Company.RIVAL, 5_000, at)
	men.step_toward(at + Vector2i(3, 0))
	assert_eq(String(run.map.improvement_at(at.x, at.y)), "fort", "a fort fell because its men walked out")
	assert_false(Forts.is_manned(at, run.companies))


func test_whose_fort_it_is_survives_the_save() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	var restored := WorldMap.from_dict(run.map.to_dict())
	assert_eq(String(restored.fort_owner(at.x, at.y).get("by", "")), "rival_duke_montargis")


func test_the_runs_first_fall_of_a_dukes_fort_shows_the_fort_falls() -> void:
	var run := _run()
	var at := _field(run)
	_dukes_fort(run, at)
	var garrison := _raise(run, Company.RIVAL, 10, at)
	Battle.resolve(_raise(run, Company.COLONIAL, 2_000_000, at + Vector2i(1, 0)), garrison, run.map, _context(run))
	var triggers: Array = []
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if record.has("cutscene"):
			triggers.append(record)
	var shown := CutsceneTriggers.ids_of(CutsceneTriggers.fired(triggers, run.log.of_type(Forts.EVENT_FELL), {}))
	assert_true(shown.has("the_fort_falls"), "a duke's fort fell and nothing was painted: %s" % [shown])
