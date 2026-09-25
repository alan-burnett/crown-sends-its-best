extends TestCase

## Tribes notice what the colony does and write to the governor first; he answers
## (#435, `docs/mechanics/natives.md` §11).
##
## 🔒 **They always write first.** Before a village takes a hostile objective
## against a town, its tribe has written to that town's governor in an earlier
## month. **The governor answers through the kernel** and emits its trace; the
## answer lands the month after, and only then does the tribe take it.

const SEED: int = 435

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


## The first village, moved in next door to the first town, and every other one
## sent far away so there is no question whose ground is whose.
func _neighbours() -> Village:
	var villages := run.tribes.villages_in_order()
	for index in villages.size():
		(villages[index] as Village).at = Vector2i(-100 - index * 20, -100)
	var village: Village = villages[0]
	village.at = _town().at + Vector2i(4, 0)
	village.people = 2 * Population.THOUSAND
	return village


## A tile of theirs, between the town and the village.
func _their_field(village: Village) -> Vector2i:
	return village.at + Vector2i(-2, 0)


func _driver() -> TribeGrievanceDriver:
	return TribeGrievanceDriver.new(run)


func _phase(phase: StringName) -> void:
	_driver().on_phase(phase, run.world, run.log, run.streams)


func _written(act: StringName = &"") -> Array:
	var out: Array = []
	for grievance in run.tribes.grievances.list:
		if String(act).is_empty() or grievance.act == act:
			out.append(grievance)
	return out


## Phase 2 of the month after: the answer lands.
func _land() -> void:
	run.world.month += 1
	var executor := TribeAnswerExecutor.new()
	executor.run = run
	IntentExecutor.run_month([executor], run.intents, run.world, run.log)


func _answer_with(grievance: TribeGrievance, answer: StringName, gift: Dictionary = {}) -> void:
	grievance.answer = answer
	run.intents.commit(Intent.new(&"", TribeGrievanceDriver.ANSWER_KIND, _town().governor_id, grievance.id, 1, {
		"grievance": String(grievance.id), "answer": String(answer), "gift": gift,
	}), run.log, run.world.month)


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.territory = Territory.compute(run.map, run.colony.in_order())
	return context


# --- 🔒 What a tribe notices ------------------------------------------------------------

func test_land_worked_is_noticed_once_until_it_stops_and_starts_again() -> void:
	var village := _neighbours()
	var field := _their_field(village)
	var town := _town()
	town.harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	assert_eq(_written(TribeGrievance.LAND_WORKED).size(), 1, "a town worked their field and they said nothing")
	var first: TribeGrievance = _written(TribeGrievance.LAND_WORKED)[0]
	assert_eq(String(first.governor), String(town.governor_id), "the letter went to somebody other than the town's governor")
	assert_eq(String(first.tribe), String(village.tribe))

	run.world.month += 1
	_phase(WorldPhase.RECKONING)
	assert_eq(_written(TribeGrievance.LAND_WORKED).size(), 1, "the same field was written about twice")

	run.world.month += 1
	town.harvested_at = {}
	_phase(WorldPhase.RECKONING)
	run.world.month += 1
	town.harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	assert_eq(_written(TribeGrievance.LAND_WORKED).size(), 2, "a field worked again after a pause went unnoticed")


func test_an_improvement_a_founding_and_a_company_on_their_ground_are_noticed() -> void:
	var village := _neighbours()
	var field := _their_field(village)
	var town := _town()
	run.log.emit(&"improvement_built", town.id, run.world.month, {"improvement": "farm", "at": field})
	run.log.emit(&"town_founded", &"x", run.world.month, {"at": [field.x, field.y + 1], "from": String(town.id)})
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.companies = run.companies
	run.companies.raise_company(Company.COLONIAL, 2_000, {}, town.id, field + Vector2i(0, -1), context,
		StandingOrder.EXPLORE, Company.MILITIA)
	_phase(WorldPhase.RECKONING)
	for act in [TribeGrievance.IMPROVEMENT_BUILT, TribeGrievance.TOWN_FOUNDED, TribeGrievance.COMPANY_ON_ITS_GROUND]:
		assert_eq(_written(act).size(), 1, "'%s' on their ground went unnoticed" % act)


func test_nothing_far_from_them_is_noticed() -> void:
	_neighbours()
	var town := _town()
	var far := town.at + Vector2i(-40, 0)
	town.harvested_at = {"%d,%d" % [far.x, far.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	assert_empty(_written(), "a tribe complained about ground nowhere near it")


# --- 🔒 The governor answers through the kernel --------------------------------------------

func test_the_governor_answers_the_month_after_through_the_kernel_with_its_trace() -> void:
	# Below neutral, so he answers himself rather than asking the PC first (#436).
	run.contact(_town().governor_id).relationship.loyalty = Relationship.NEUTRAL_LOYALTY - 10.0
	var village := _neighbours()
	var field := _their_field(village)
	_town().harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	var grievance: TribeGrievance = _written()[0]
	_phase(WorldPhase.INTENT)
	assert_false(grievance.is_answered(), "he answered in the month he was written to")

	run.world.month += 1
	_phase(WorldPhase.INTENT)
	assert_true(grievance.is_answered(), "he never answered")
	assert_true(TribeGrievance.ANSWERS.has(grievance.answer))
	var traced := false
	for event in run.log.of_type(Deliberation.TRACE_EVENT):
		traced = traced or String(event.payload.get("kind", "")) == String(DecisionKind.TRIBE_GRIEVANCE)
	assert_true(traced, "his answer left no scoring trace")
	assert_eq(grievance.answered_month, -1, "the answer landed in the month it was given")


func test_a_town_cannot_yield_its_founding_nor_give_what_it_does_not_hold() -> void:
	var town := _town()
	var founding := TribeGrievance.new()
	founding.act = TribeGrievance.TOWN_FOUNDED
	var context := DeliberationContext.new(DecisionKind.TRIBE_GRIEVANCE, run.world, run.log)
	context.data = {"town": town, "grievance": founding, "gift": {}}
	var yield_filter := GrievanceConsiderations.OnlyWhatCanBeYielded.new()
	var gift_filter := GrievanceConsiderations.OnlyWhatHeHasToGive.new()
	assert_false(yield_filter.permits(null, Candidate.new(TribeGrievance.YIELD), context), "a town yielded its founding")
	assert_false(gift_filter.permits(null, Candidate.new(TribeGrievance.GIFT), context), "a town gave what it did not hold")
	founding.act = TribeGrievance.LAND_WORKED
	assert_true(yield_filter.permits(null, Candidate.new(TribeGrievance.YIELD), context))


# --- 🔒 What the answer does ------------------------------------------------------------------

func test_a_town_that_yields_stops_working_the_tile_the_next_month_and_the_improvement_stays() -> void:
	var village := _neighbours()
	var field := _their_field(village)
	var town := _town()
	run.map.set_terrain(field.x, field.y, &"plains")
	run.map.build(field.x, field.y, &"farm")
	var before := _context().tiles_of(town)
	assert_true(before.has(field), "the fixture's field is not the town's to work")
	town.harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	_answer_with(_written()[0], TribeGrievance.YIELD)
	assert_true(_context().tiles_of(town).has(field), "the town stopped working the field before the answer landed")
	_land()
	assert_false(_context().tiles_of(town).has(field), "a town that yielded went on working the field")
	assert_eq(String(run.map.improvement_at(field.x, field.y)), "farm", "yielding tore down what stood on the field")


func test_a_gift_goes_from_the_town_to_the_village() -> void:
	var village := _neighbours()
	var field := _their_field(village)
	var town := _town()
	town.store(&"tools", 50.0)
	town.harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	var grievance: TribeGrievance = _written()[0]
	var gift := GrievanceConsiderations.gift_for(grievance, town, village, run.map)
	assert_false(gift.is_empty(), "a town holding tools had nothing to give")
	var had := town.held(StringName(gift["resource"]))
	_answer_with(grievance, TribeGrievance.GIFT, gift)
	_land()
	assert_true(town.held(StringName(gift["resource"])) < had, "the gift never left the town")
	assert_true(float(village.stores.get(String(gift["resource"]), 0.0)) > 0.0, "the gift never reached the village")


func test_the_tribe_takes_the_answer_when_it_arrives_and_silence_is_a_refusal() -> void:
	var village := _neighbours()
	var tribe := run.tribes.find(village.tribe)
	var field := _their_field(village)
	_town().harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	var yielded: TribeGrievance = _written()[0]
	_answer_with(yielded, TribeGrievance.YIELD)
	_land()
	var standing := tribe.trust()
	_phase(WorldPhase.RECKONING)
	assert_true(yielded.taken_month >= 0, "the tribe never took the answer")
	assert_true(tribe.trust() > standing, "yielding won back nothing")

	# A letter nobody answers, for as long as they wait, is taken as a refusal.
	var ignored := run.tribes.grievances.write(tribe.id, _town(), TribeGrievance.IMPROVEMENT_BUILT, field, &"",
		run.log, run.world.month)
	run.world.month += TribeGrievanceDriver.WAITS
	var before := tribe.trust()
	_driver()._take_the_answers(_context())
	assert_eq(String(ignored.answer), String(TribeGrievance.REFUSE), "silence was not taken as a refusal")
	assert_true(tribe.trust() < before, "a refusal cost them nothing")


func test_a_threat_to_the_weaker_costs_nothing_and_to_the_stronger_more_than_refusing() -> void:
	var village := _neighbours()
	var tribe := run.tribes.find(village.tribe)
	var field := _their_field(village)
	var driver := _driver()
	var threat := run.tribes.grievances.write(tribe.id, _town(), TribeGrievance.IMPROVEMENT_BUILT, field, &"",
		run.log, run.world.month)
	threat.answer = TribeGrievance.THREATEN
	village.people = 1_000
	assert_almost_eq(driver._standing_for(threat), 0.0, 0.0001, "a weak people did not back down")
	village.people = 5_000_000
	var refusal := run.tribes.grievances.write(tribe.id, _town(), TribeGrievance.IMPROVEMENT_BUILT, field, &"",
		run.log, run.world.month)
	refusal.answer = TribeGrievance.REFUSE
	assert_true(driver._standing_for(threat) < driver._standing_for(refusal),
		"threatening a stronger people cost no more than refusing them")


# --- 🔒 They always write first ------------------------------------------------------------------

func test_a_people_who_have_concluded_write_before_they_drive_anybody_off() -> void:
	var village := _neighbours()
	var tribe := run.tribes.find(village.tribe)
	tribe.irreconcilable[String(Tribe.COLONY)] = true
	var villages := VillageDriver.new(run.tribes, run.map)
	villages.colony = run.colony
	villages.on_phase(WorldPhase.COLONY_MONTH, run.world, run.log, run.streams)
	assert_ne(String(village.objective), String(Village.DRIVE_THEM_OFF),
		"a village took up arms against a town its tribe had never written to")
	var warnings := _written(TribeGrievance.WE_WILL_DRIVE_YOU_OFF)
	assert_eq(warnings.size(), 1, "they meant to drive the town off and never said so")
	assert_eq(String((warnings[0] as TribeGrievance).governor), String(_town().governor_id))

	run.world.month += 1
	villages.on_phase(WorldPhase.COLONY_MONTH, run.world, run.log, run.streams)
	assert_eq(String(village.objective), String(Village.DRIVE_THEM_OFF),
		"having written, a people who had concluded still did nothing")


func test_a_letter_written_this_month_does_not_let_a_second_village_strike_this_month() -> void:
	# "At least a month earlier": two villages of one people beside one town. The
	# first says what they will do; the second may not act on that letter in the
	# month it was written.
	var first := _neighbours()
	var tribe := run.tribes.find(first.tribe)
	tribe.irreconcilable[String(Tribe.COLONY)] = true
	var second: Village = null
	for entry in run.tribes.villages_in_order():
		if entry != first:
			second = entry
			break
	second.tribe = first.tribe
	second.at = _town().at + Vector2i(0, 4)
	second.people = 2 * Population.THOUSAND
	var villages := VillageDriver.new(run.tribes, run.map)
	villages.colony = run.colony
	villages.on_phase(WorldPhase.COLONY_MONTH, run.world, run.log, run.streams)
	for village in [first, second]:
		assert_ne(String((village as Village).objective), String(Village.DRIVE_THEM_OFF),
			"%s struck in the month its people first wrote" % (village as Village).id)


func test_over_many_seeds_no_hostile_objective_without_an_earlier_letter() -> void:
	# 🔒 The acceptance line, asked of the whole month: every village that turns to
	# driving the colony off has a letter from its tribe to that town's governor
	# from an earlier month.
	var checked := 0
	for seed_value in [11, 22, 33, 44]:
		after_each()
		reset_world()
		M1Registrations.register_all()
		content = ContentDatabase.new()
		content.load_all("en")
		M1Registrations.load_resources(content)
		run = RunState.new_run(seed_value)
		ContactRoster.load_into(run, content)
		for tribe in run.tribes.in_order():
			(tribe as Tribe).irreconcilable[String(Tribe.COLONY)] = true
		var machine := TurnMachine.new(run)
		machine.use_content(content)
		machine.saves_on_send = false
		for _month in 4:
			machine.month_runner.run(run.world, run.log)
		for event in run.log.of_type(Village.EVENT_OBJECTIVE):
			if String(event.payload.get("now", "")) != String(Village.DRIVE_THEM_OFF):
				continue
			var village: Village = null
			for entry in run.tribes.villages_in_order():
				if (entry as Village).id == StringName(event.payload.get("village", "")):
					village = entry
			var target := TribeGrievanceDriver.nearest_town(run.colony, village.at)
			checked += 1
			assert_true(run.tribes.grievances.has_written_before(village.tribe, target.id, event.month),
				"seed %d: %s turned on %s in month %d with no letter before it" % [
					seed_value, village.id, target.id, event.month])
	assert_true(checked > 0, "no village ever turned on the colony, so this proved nothing")


# --- Saving ---------------------------------------------------------------------------------------

func test_letters_and_yielded_fields_survive_the_save() -> void:
	var village := _neighbours()
	var field := _their_field(village)
	var town := _town()
	town.harvested_at = {"%d,%d" % [field.x, field.y]: {"food": 3.0}}
	_phase(WorldPhase.RECKONING)
	town.yield_tile(field, village.tribe)
	var tribes := Tribes.from_dict(run.tribes.to_dict())
	assert_eq(tribes.grievances.list.size(), run.tribes.grievances.list.size())
	assert_eq(tribes.grievances.ongoing.size(), run.tribes.grievances.ongoing.size(),
		"a reload forgot which acts were still going on, and would write about them again")
	var restored := Town.from_dict(town.to_dict())
	assert_true(restored.has_yielded(field), "a reload handed the field back")
