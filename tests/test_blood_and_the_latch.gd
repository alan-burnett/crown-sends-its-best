extends TestCase

## Tribes: every offence counts toward the point of no return, villages can be
## attacked, and blood costs standing (#456, `natives.md` §2, §3, §11;
## `commanders.md` §3; `battles.md` §9).
##
## 🔒 One score: encroachment alone can carry a people past the point of no
## return, and then they go to war. 🔒 A colonial or Crown company whose foe is a
## tribe marches on its village and fights it as a town with no wall; a village
## emptied is gone and its land freed. 🔒 An attack on a tribe's people costs
## twice the share of the tribe killed, toward whoever did it. 🔒 An expedition on
## their ground costs standing by depth and draws their letter first.

const SEED: int = 456

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
	run.world.month = 30


func after_each() -> void:
	reset_world()
	content.free()


## One people of twenty thousand, in one village on dry ground near the capital.
func _natives(standing: float = 60.0) -> Village:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): standing, String(Tribe.CROWN_TROOPS): standing}
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test"
	village.tribe = tribe.id
	village.at = _dry_ground_near((run.colony.in_order()[0] as Town).at)
	village.people = 20_000
	village.stores = {"food": 5_000.0}
	natives.villages.append(village)
	run.tribes = natives
	return village


## Land five tiles or more from the capital, with land to its west for a company
## to stand on.
func _dry_ground_near(capital: Vector2i) -> Vector2i:
	for away in range(5, 12):
		for at in [capital + Vector2i(away, 0), capital + Vector2i(-away, 0),
				capital + Vector2i(0, away), capital + Vector2i(0, -away)]:
			var west: Vector2i = at + Vector2i(-1, 0)
			if run.map.in_bounds(at.x, at.y) and run.map.is_land(at.x, at.y) 					and run.map.in_bounds(west.x, west.y) and run.map.is_land(west.x, west.y):
				return at
	return capital + Vector2i(5, 0)


func _tribe() -> Tribe:
	return run.tribes.find(&"tribe_test")


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	context.natives = run.tribes
	return context


## A company of this side, beside the village.
func _company(allegiance: StringName, village: Village, size: int = 5_000) -> Company:
	var town: Town = run.colony.in_order()[0]
	var company := run.companies.raise_company(allegiance, size, {"guns": 5.0},
		town.id if allegiance == Company.COLONIAL else Company.SUPPORTED_ABROAD,
		village.at + Vector2i(-1, 0), _context(), StandingOrder.MARCH_ON_A_FOE, Company.MILITIA)
	return company


# --- 🔒 One score, and any offence can latch it ---------------------------------

func test_encroachment_alone_carries_them_over_and_they_go_to_war() -> void:
	var village := _natives(60.0)
	var tribe := _tribe()
	var colony := Colony.new()
	var town := Town.new(&"crowding", "Crowding", village.at)
	town.workers = 4_000
	colony.add(town)
	var territory := Territory.compute(run.map, colony.in_order())
	for month in 240:
		if tribe.is_irreconcilable_with(Tribe.COLONY):
			break
		TribeStanding.founding(village.at, run.tribes, _context())
		TribeStanding.exploitation(colony, run.tribes, territory, _context())
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY),
		"twenty years crowded off their land and they concluded nothing")

	village.decide(tribe, 12.0, _context(), true)
	assert_eq(String(village.objective), String(Village.DRIVE_THEM_OFF))
	Muster.run_month(run, _context())
	assert_false(run.log.of_type(Muster.EVENT_WAR_PARTY).is_empty(),
		"a people past the point of no return raised nobody")


# --- 🔒 By the blood spilled ------------------------------------------------------

func test_an_attack_costs_twice_the_share_killed_toward_whoever_did_it() -> void:
	var village := _natives(60.0)
	var tribe := _tribe()
	var colonists := _company(Company.COLONIAL, village)
	village.people -= 2_000
	TribeStanding.blood_spilled(colonists, VillageCompany.of(village, colonists), 2_000, _context())
	assert_almost_eq(tribe.standing_toward(Tribe.COLONY), 40.0, 0.0001,
		"a tenth of the tribe killed did not cost twenty")
	assert_almost_eq(tribe.standing_toward(Tribe.CROWN_TROOPS), 60.0, 0.0001,
		"the Crown's troops were blamed for what the colonists did")

	var soldiers := _company(Company.CROWN, village)
	village.people -= 1_800
	TribeStanding.blood_spilled(soldiers, VillageCompany.of(village, soldiers), 1_800, _context())
	assert_almost_eq(tribe.standing_toward(Tribe.CROWN_TROOPS), 40.0, 0.0001,
		"the Crown's soldiers killed a tenth of them and it cost them nothing")
	assert_almost_eq(tribe.standing_toward(Tribe.COLONY), 40.0, 0.0001)


func test_a_battle_is_what_spills_it() -> void:
	var village := _natives(60.0)
	var soldiers := _company(Company.CROWN, village, 20_000)
	var before := village.people
	var fought := Battle.resolve(soldiers, VillageCompany.of(village, soldiers), run.map, _context())
	assert_false(fought.is_empty(), "the Crown's men could not fight a village at war with them")
	assert_true(village.people < before, "the village lost nobody")
	assert_eq(run.log.of_type(TribeStanding.EVENT_AGGRESSION).size(), 1,
		"their people were killed and it was not held against anybody")


# --- 🔒 Villages can be attacked ------------------------------------------------------

func test_a_company_whose_foe_is_a_tribe_marches_on_its_village() -> void:
	var village := _natives(60.0)
	var colonists := _company(Company.COLONIAL, village)
	colonists.at = village.at + Vector2i(-4, 0)
	assert_true(OrderRule.foe_of(colonists, null, _context()) == null,
		"a company marched on a village at peace")

	_tribe().irreconcilable[String(Tribe.COLONY)] = true
	var foe := OrderRule.foe_of(colonists, null, _context())
	assert_true(foe is VillageCompany, "a company whose foe is a tribe did not march on its village")
	if foe != null:
		assert_eq(foe.at, village.at)


func test_a_tribe_with_men_in_the_field_is_at_war_whatever_it_has_concluded() -> void:
	var village := _natives(60.0)
	var colonists := _company(Company.COLONIAL, village)
	assert_false(VillageCompany.is_a_foe(village, colonists, _context()))
	var party := run.companies.raise_company(Company.NATIVE, 500, {}, Company.SUPPORTED_ABROAD,
		village.at, _context(), StandingOrder.MARCH_ON_A_FOE, Company.MILITIA)
	party.raised_by = village.id
	assert_true(VillageCompany.is_a_foe(village, colonists, _context()),
		"a tribe whose men were in the field was treated as at peace")


func test_a_village_at_war_is_in_front_of_him_and_one_at_peace_is_not() -> void:
	var village := _natives(60.0)
	var colonists := _company(Company.COLONIAL, village)
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.natives = run.tribes
	assert_true(driver._in_contact_with(colonists) == null, "a village at peace was in front of him")
	_tribe().irreconcilable[String(Tribe.COLONY)] = true
	assert_true(driver._in_contact_with(colonists) is VillageCompany,
		"a village at war beside him was not in front of him")


func test_in_the_month_he_falls_on_it_and_it_loses_people() -> void:
	# The whole of it, through an ordinary month: a militia marching on its foe
	# steps up to the village of a tribe at war with the colony and attacks it.
	var village := _natives(60.0)
	_tribe().irreconcilable[String(Tribe.COLONY)] = true
	var colonists := _company(Company.COLONIAL, village, 20_000)
	colonists.at = village.at + Vector2i(-2, 0)
	var before := village.people
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.natives = run.tribes
	for month in 3:
		run.world.month += 1
		driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_true(village.people < before, "a company marching on a tribe at war never fell on its village")
	assert_false(run.log.of_type(VillageCompany.EVENT_STRUCK).is_empty())


func test_a_village_emptied_is_gone_and_its_land_freed() -> void:
	var village := _natives(60.0)
	assert_eq(String(run.tribes.holder_of(village.at)), String(village.tribe))
	var colonists := _company(Company.COLONIAL, village)
	VillageCompany.of(village, colonists)._remove(village.people, &"stormed", _context())

	assert_false(run.tribes.villages.has(village), "a village with nobody in it still stands")
	assert_eq(String(run.tribes.holder_of(village.at)), "", "the land of a village that is gone is still held")
	assert_eq(run.log.of_type(Tribes.EVENT_VILLAGE_GONE).size(), 1)


# --- 🔒 An expedition on their ground ----------------------------------------------------

func test_an_expedition_on_their_ground_costs_standing_and_draws_their_letter() -> void:
	var village := _natives(60.0)
	var tribe := _tribe()
	var party := ExpeditionParty.new()
	party.id = &"party_crossing"
	party.parent = (run.colony.in_order()[0] as Town).id
	party.people = 3_000
	party.at = village.at + Vector2i(1, 0)
	run.parties.append(party)

	var driver := TribeGrievanceDriver.new(run)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	var after_one := tribe.trust()
	assert_true(after_one < 60.0, "an expedition crossing their country cost them nothing")
	var written := run.tribes.grievances.list.filter(func(g: TribeGrievance) -> bool:
		return g.act == TribeGrievance.EXPEDITION_ON_ITS_GROUND)
	assert_eq(written.size(), 1, "they did not write to the governor first")

	# **Noticed once while it stays**, not every month it stands there.
	run.world.month += 1
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_eq(run.log.of_type(TribeStanding.EVENT_EXPEDITION).size(), 1,
		"the same expedition offended them afresh every month")
