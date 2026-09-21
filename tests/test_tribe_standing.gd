extends TestCase

## What moves a tribe's standing toward the colony (#204, SPEC §12.5, §11.4;
## `docs/mechanics/natives.md` §3).
##
## 🔒 **The asymmetry is the design.** Intrusion and exploitation accrue from
## simply existing next door and expanding; repair is slow and mostly requires
## doing nothing. A colony that grows is losing standing by default.
##
## 🔒 **Only colonist aggression reaches the point of no return.** Founding on
## their doorstep, working their fields and a governor set on driving them off
## grind a people down to the edge of the conclusion and never carry them over,
## however many years they run.

const SEED: int = 5107

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
	content.free()


func _map() -> WorldMap:
	var map := WorldMap.new(24, 24, &"ocean")
	for y in range(2, 22):
		for x in range(2, 22):
			map.set_terrain(x, y, &"plains")
	return map


func _context(map: WorldMap = null) -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)


## One people, living where they are put.
func _natives(where: Array = [Vector2i(10, 10)], standing: float = 60.0) -> Tribes:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): standing}
	natives.all.append(tribe)
	for index in where.size():
		var village := Village.new()
		village.id = StringName("village_test_%d" % index)
		village.tribe = tribe.id
		village.at = where[index]
		village.people = 30
		natives.villages.append(village)
	return natives


func _town(at: Vector2i = Vector2i(4, 4)) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", at)
	town.workers = 40
	town.governor_id = &"gov_ashmere"
	town.store(&"food", 600.0)
	return town


func _colony(town: Town) -> Colony:
	var colony := Colony.new()
	colony.add(town)
	return colony


# --- 🔒 In proportion to the intrusion --------------------------------------

func test_intrusion_is_deepest_where_they_live_and_nothing_far_away() -> void:
	var natives := _natives([Vector2i(10, 10)])
	var village: Village = natives.villages_in_order()[0]
	var reach := village.influence()

	assert_almost_eq(Intrusion.depth_at(Vector2i(10, 10), natives), 1.0, 0.0001,
		"a town on top of their houses was a border dispute")
	assert_true(Intrusion.depth_at(Vector2i(10 + reach, 10), natives)
			< Intrusion.depth_at(Vector2i(10, 10), natives) - 0.0001,
		"the edge of their land offended them as much as the middle")
	assert_almost_eq(
		Intrusion.depth_at(Vector2i(10 + reach + Intrusion.MARGIN + 1, 10), natives),
		0.0, 0.0001, "a town well clear of them still offended them")


func test_near_their_land_still_counts() -> void:
	# 🔒 SPEC §11.4 says "near **or** beyond". A cliff at the edge of their land
	# would make a town one field out perfectly innocent, and it is not — it is a
	# town they will be looking at every morning.
	var natives := _natives([Vector2i(10, 10)])
	var reach: int = (natives.villages_in_order()[0] as Village).influence()
	var just_outside := Intrusion.depth_at(Vector2i(10 + reach + 1, 10), natives)
	assert_true(just_outside > 0.0,
		"a town one field from their land cost nothing at all")
	assert_true(just_outside < Intrusion.AT_THE_BORDER,
		"standing outside their land was as bad as standing in it")


func test_a_founding_costs_in_proportion_to_how_far_in_it_sits() -> void:
	var deep := _natives([Vector2i(10, 10)])
	var edge := _natives([Vector2i(10, 10)])
	var reach: int = (deep.villages_in_order()[0] as Village).influence()

	TribeStanding.founding(Vector2i(10, 10), deep, _context())
	TribeStanding.founding(Vector2i(10 + reach + 1, 10), edge, _context())

	var lost_deep := 60.0 - (deep.in_order()[0] as Tribe).trust()
	var lost_edge := 60.0 - (edge.in_order()[0] as Tribe).trust()
	assert_true(lost_deep > lost_edge + 0.0001,
		"a town in the middle of their country cost no more than one beside it")
	assert_true(lost_edge > 0.0, "a town on their doorstep cost nothing")


func test_a_founding_nobody_can_see_offends_nobody() -> void:
	var natives := _natives([Vector2i(10, 10)])
	TribeStanding.founding(Vector2i(2, 2), natives, _context())
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), 60.0, 0.0001,
		"a people were offended by a town they could not find")


func test_a_founding_names_the_tribe_and_the_cause() -> void:
	var natives := _natives([Vector2i(10, 10)])
	var context := _context()
	TribeStanding.founding(Vector2i(10, 10), natives, context)

	var offended: Array = context.log.of_type(TribeStanding.EVENT_FOUNDING)
	assert_eq(offended.size(), 1, "a town was founded on their land in silence")
	assert_eq(String(offended[0].payload["tribe"]), "tribe_test")
	assert_true(bool(offended[0].payload["beyond_their_border"]),
		"a town among their houses was reported as merely nearby")
	# 🔒 The figure never leaves the sim (`natives.md` §1).
	assert_false(offended[0].payload.has("standing"),
		"the payload carries the standing, which a letter could then render")


# --- 🔒 Working their fields, every month it continues ----------------------

func test_working_their_fields_costs_every_month() -> void:
	var map := _map()
	var natives := _natives([Vector2i(5, 5)])
	var town := _town(Vector2i(5, 5))
	var colony := _colony(town)
	var territory := Territory.compute(map, colony.in_order())

	var trust := (natives.in_order()[0] as Tribe).trust()
	for _month in 4:
		TribeStanding.exploitation(colony, natives, territory, _context(map))
		var now := (natives.in_order()[0] as Tribe).trust()
		assert_true(now < trust - 0.0001,
			"a month of working their fields cost nothing")
		trust = now


func test_a_town_that_works_nobodys_fields_costs_nothing() -> void:
	var map := _map()
	var natives := _natives([Vector2i(19, 19)])
	var town := _town(Vector2i(4, 4))
	var colony := _colony(town)
	var territory := Territory.compute(map, colony.in_order())

	TribeStanding.exploitation(colony, natives, territory, _context(map))
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), 60.0, 0.0001,
		"a town four hundred miles off was accused of taking their land")


func test_a_bigger_town_cannot_grind_them_down_faster_without_limit() -> void:
	# The cap. A town's reach grows with its people, and without this a large
	# town beside a village would run through the whole scale in a year.
	var map := _map()
	var natives := _natives([Vector2i(5, 5)])
	var town := _town(Vector2i(5, 5))
	town.workers = 400
	var colony := _colony(town)
	var territory := Territory.compute(map, colony.in_order())

	TribeStanding.exploitation(colony, natives, territory, _context(map))
	assert_true(60.0 - (natives.in_order()[0] as Tribe).trust()
			<= TribeStanding.EXPLOITATION_CAP + 0.0001,
		"one month of one town cost more than a month of one town may cost")


func test_taking_their_land_names_the_tribe_the_town_and_how_many_fields() -> void:
	var map := _map()
	var natives := _natives([Vector2i(5, 5)])
	var colony := _colony(_town(Vector2i(5, 5)))
	var context := _context(map)
	TribeStanding.exploitation(
		colony, natives, Territory.compute(map, colony.in_order()), context)

	var taken: Array = context.log.of_type(TribeStanding.EVENT_EXPLOITATION)
	assert_eq(taken.size(), 1, "their fields were taken in silence")
	assert_eq(String(taken[0].payload["tribe"]), "tribe_test")
	assert_eq(String(taken[0].payload["town"]), "ashmere")
	assert_true(int(taken[0].payload["fields"]) > 0,
		"a town was reported taking no fields at all")


# --- 🔒 A governor's purpose, before anything is built ----------------------

func test_a_governor_who_means_to_drive_them_off_is_seen_doing_it() -> void:
	# 🔒 The acceptance: **visible before anything is built.** There is no hiding
	# a purpose from people who live next door.
	var natives := _natives([Vector2i(5, 5)])
	var town := _town(Vector2i(5, 5))
	town.intent = GovernorIntent.DRIVE_OFF
	town.intent_since = 0
	var context := _context(_map())

	TribeStanding.hostile_intent(_colony(town), natives, context)

	assert_true((natives.in_order()[0] as Tribe).trust() < 60.0 - 0.0001,
		"a governor said he meant to be rid of them and they did not notice")
	var seen: Array = context.log.of_type(TribeStanding.EVENT_HOSTILE_INTENT)
	assert_eq(seen.size(), 1, "a town turned against them in silence")
	assert_eq(String(seen[0].payload["town"]), "ashmere")


func test_an_ordinary_governor_is_not_treated_as_a_threat() -> void:
	var natives := _natives([Vector2i(5, 5)])
	var town := _town(Vector2i(5, 5))
	town.intent = GovernorIntent.ECONOMY
	TribeStanding.hostile_intent(_colony(town), natives, _context(_map()))
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), 60.0, 0.0001,
		"a man minding his own trade was taken for an enemy")


func test_a_governor_they_have_never_met_is_nothing_to_them() -> void:
	var natives := _natives([Vector2i(19, 19)])
	var town := _town(Vector2i(4, 4))
	town.intent = GovernorIntent.DRIVE_OFF
	TribeStanding.hostile_intent(_colony(town), natives, _context(_map()))
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), 60.0, 0.0001,
		"a people heard a man three weeks' walk away change his mind")


func test_a_man_with_nobody_to_drive_off_cannot_want_to() -> void:
	# 🔒 A filter and not a weight (`deliberation.md` §5). A governor four hundred
	# miles from the nearest village adopting *drive them off* is not a close
	# vote, it is nonsense.
	var map := _map()
	var town := _town(Vector2i(4, 4))
	var colony := _colony(town)
	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	context.data = {
		"town": town,
		"colony": colony,
		"map": map,
		"territory": Territory.compute(map, colony.in_order()),
		"natives": _natives([Vector2i(19, 19)]),
	}
	var filter := IntentConsiderations.SomebodyToDriveOff.new()
	assert_false(filter.permits(null, Candidate.new(GovernorIntent.DRIVE_OFF), context),
		"a governor with no neighbours could intend to be rid of them")
	assert_true(filter.permits(null, Candidate.new(GovernorIntent.ECONOMY), context),
		"the filter turned down an intent that has nothing to do with it")

	context.data["natives"] = _natives([Vector2i(5, 5)])
	assert_true(filter.permits(null, Candidate.new(GovernorIntent.DRIVE_OFF), context),
		"a governor with a village in his fields could not intend anything about it")


# --- 🔒 Only aggression reaches the point of no return ----------------------

func test_a_lifetime_of_intrusion_never_carries_them_over() -> void:
	# 🔒 The acceptance, and the design. Forty years of being crowded, farmed over
	# and glowered at by a hostile governor, and they are still a people who could
	# in principle be talked round.
	var map := _map()
	var natives := _natives([Vector2i(5, 5)], 60.0)
	var town := _town(Vector2i(5, 5))
	town.intent = GovernorIntent.DRIVE_OFF
	var colony := _colony(town)
	var territory := Territory.compute(map, colony.in_order())

	for _month in 480:
		var context := _context(map)
		TribeStanding.founding(town.at, natives, context)
		TribeStanding.exploitation(colony, natives, territory, context)
		TribeStanding.hostile_intent(colony, natives, context)

	var tribe: Tribe = natives.in_order()[0]
	assert_false(tribe.is_irreconcilable_with(Tribe.COLONY),
		"being crowded off their land for forty years was treated as being attacked")
	assert_almost_eq(tribe.trust(), Tribe.IRRECONCILABLE_BELOW, 0.0001,
		"they stopped somewhere other than the edge of the conclusion")


func test_aggression_is_the_one_thing_that_does() -> void:
	var natives := _natives([Vector2i(5, 5)], Tribe.IRRECONCILABLE_BELOW + 1.0)
	var tribe: Tribe = natives.in_order()[0]
	var context := _context()

	TribeStanding.aggression(tribe, 4.0, "a village burned", context)

	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY),
		"colonists burned a village and the people concluded nothing")
	var attacked: Array = context.log.of_type(TribeStanding.EVENT_AGGRESSION)
	assert_eq(attacked.size(), 1, "colonists attacked them in silence")
	assert_true(bool(attacked[0].payload["concluded"]),
		"the event did not say the people had reached a conclusion")


func test_the_clamp_holds_at_the_line_rather_than_at_the_floor() -> void:
	# 🔒 A latch at zero would be a floor with a different name. The point is that
	# there is a stretch of very bad standing a people can still be talked out of.
	var natives := _natives([Vector2i(5, 5)], 40.0)
	var tribe: Tribe = natives.in_order()[0]
	tribe.move(Tribe.COLONY, -400.0, "everything at once", _context(), false)
	assert_almost_eq(tribe.trust(), Tribe.IRRECONCILABLE_BELOW, 0.0001,
		"a mover that may not conclude took them to the floor")
	assert_true(Tribe.IRRECONCILABLE_BELOW > Tribe.MINIMUM,
		"the line and the floor are the same place, so the latch means nothing")


# --- Time, and being left alone ---------------------------------------------

func test_a_quiet_month_helps_a_people_who_were_wronged() -> void:
	var natives := _natives([Vector2i(5, 5)], 20.0)
	var context := _context()
	TribeStanding.left_alone(natives, {}, context)
	assert_true((natives.in_order()[0] as Tribe).trust() > 20.0,
		"a year of being left in peace did nothing for them")
	assert_eq(context.log.of_type(TribeStanding.EVENT_LEFT_ALONE).size(), 1,
		"a people's opinion improved and nothing said so")


func test_a_month_they_were_wronged_in_is_not_a_quiet_one() -> void:
	var natives := _natives([Vector2i(5, 5)], 20.0)
	TribeStanding.left_alone(natives, {"tribe_test": true}, _context())
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), 20.0, 0.0001,
		"a people were consoled in the month their fields were taken")


func test_time_carries_them_back_to_civil_and_no_further() -> void:
	# Liking the colony is something the colony has to earn (#206, #207). Doing
	# nothing buys forgiveness, never friendship.
	var natives := _natives([Vector2i(5, 5)], 20.0)
	for _month in 400:
		TribeStanding.left_alone(natives, {}, _context())
	assert_almost_eq((natives.in_order()[0] as Tribe).trust(), Tribe.NEUTRAL, 1.0,
		"doing nothing for thirty years made them fond of the colony")


func test_a_town_beside_them_outruns_every_quiet_month_it_allows() -> void:
	# 🔒 The asymmetry, measured rather than described: a colony that grows is
	# **losing standing by default**, and doing nothing does not get it back fast
	# enough to keep up. That is what makes trade (#206) the only real answer.
	#
	# Against outcomes rather than against the constants, because the constants
	# are tuning and this claim is not.
	var map := _map()
	var natives := _natives([Vector2i(5, 5)], 40.0)
	var colony := _colony(_town(Vector2i(5, 5)))
	var territory := Territory.compute(map, colony.in_order())
	var tribe: Tribe = natives.in_order()[0]

	var before := tribe.trust()
	TribeStanding.exploitation(colony, natives, territory, _context(map))
	var damage := before - tribe.trust()

	var quiet := _natives([Vector2i(5, 5)], 40.0)
	var at_peace: Tribe = quiet.in_order()[0]
	var rested := at_peace.trust()
	TribeStanding.left_alone(quiet, {}, _context())
	var repair := at_peace.trust() - rested

	assert_true(damage > repair + 0.0001,
		"a town on their fields costs less in a month than a quiet month returns")


# --- Through the turn loop ---------------------------------------------------

func test_a_founding_reaches_the_tribes_without_the_founder_telling_them() -> void:
	# 🔒 Seam A. The driver consumes the founding event, so a founding path added
	# later is picked up for free rather than having to remember.
	var run := RunState.new_run(SEED)
	var natives := run.tribes
	var village: Village = natives.villages_in_order()[0]
	var tribe := natives.find(village.tribe)
	var before := tribe.trust()

	var driver := StandingDriver.new()
	driver.colony = run.colony
	driver.natives = natives
	driver.map = run.map
	run.log.emit(&"town_founded", &"town_new", run.world.month, {
		"town": "town_new",
		"at": [village.at.x, village.at.y],
	}, WorldPhase.MOVEMENT)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)

	assert_true(tribe.trust() < before - 0.0001,
		"a town appeared in their village and nobody told them")


func test_the_colony_reads_the_angriest_of_them_as_its_danger() -> void:
	# `natives.md` §1: a governor writing about "the natives" has no more idea
	# than the PC which of three peoples the men on the ridge belong to.
	var run := RunState.new_run(SEED)
	var driver := StandingDriver.new()
	driver.colony = run.colony
	driver.natives = run.tribes
	driver.map = run.map

	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	var calm := float(run.world.get_value(WorldValues.NATIVE_THREAT, -1.0))
	assert_true(calm >= 0.0, "nobody ever worked out what the colony had to fear")

	run.tribes.the_angriest().standing[String(Tribe.COLONY)] = 2.0
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_true(float(run.world.get_value(WorldValues.NATIVE_THREAT, 0.0)) > calm,
		"a people who had come to hate the colony read as no more dangerous")


func test_a_run_moves_the_neighbours_at_all() -> void:
	# The whole ticket, through the real loop: three years of a colony going
	# about its business, and the people next door have an opinion about it.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var before: Array = []
	for tribe in run.tribes.in_order():
		before.append((tribe as Tribe).trust())

	for _month in 36:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	var moved := 0
	for index in run.tribes.in_order().size():
		if not is_equal_approx((run.tribes.in_order()[index] as Tribe).trust(), float(before[index])):
			moved += 1
	assert_true(moved > 0,
		"three years of colony and not one people changed its mind about it")
