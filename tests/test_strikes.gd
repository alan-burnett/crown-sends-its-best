extends TestCase

## Enemies strike expeditions in the open (#417, `docs/mechanics/founding-towns.md`
## §7).
##
## 🔒 **It cannot fight.** A native war party or a duke's company in contact with
## an expedition may fall on it — the commander's choice, through the kernel —
## and it takes `LETHALITY × striker's force ÷ party's force` of the people and
## the same share of the stores, capped at the whole party. The striker loses
## nobody. Rebels never strike one.

const SEED: int = 417

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


## A run with an expedition of `people` in open plains, well away from any town.
func _run(people: int) -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town: Town = run.colony.in_order()[0]
	var at := town.at + Vector2i(8, 0)
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if run.map.in_bounds(at.x + dx, at.y + dy):
				run.map.set_terrain(at.x + dx, at.y + dy, &"plains")
	var party := ExpeditionParty.new()
	party.id = &"expedition_test"
	party.parent = town.id
	party.people = people
	party.cargo = {"food": 100.0, "wood": 40.0}
	party.at = at
	party.region = at + Vector2i(5, 0)
	run.parties.append(party)
	return run


func _party(run: RunState) -> ExpeditionParty:
	return run.parties[0]


func _raiders(run: RunState, allegiance: StringName, size: int) -> Company:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	var company := run.companies.raise_company(
		allegiance, size, {}, Company.SUPPORTED_ABROAD, _party(run).at + Vector2i(1, 0), context,
		StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	company.raised_by = &"rival_duke_montargis" if allegiance == Company.RIVAL else &"village_test"
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
	driver.parties = run.parties
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	run.world.month += 1


# --- 🔒 The share, and the same share of the stores -----------------------------

func test_a_war_party_in_contact_strikes_and_takes_the_same_share_of_people_and_stores() -> void:
	var run := _run(8_000)
	var raiders := _raiders(run, Company.NATIVE, 4_000)
	var party := _party(run)
	_month(run)

	var struck: Array = run.log.of_type(ExpeditionParty.EVENT_ATTACKED)
	assert_eq(struck.size(), 1, "a war party beside an expedition did not fall on it")
	var share := float(struck[0].payload["share"])
	assert_true(share > 0.0 and share < 1.0, "the fixture's strike took %f" % share)
	assert_eq(String(struck[0].payload["cause"]), "native")
	assert_almost_eq(float(party.cargo["food"]), 100.0 * (1.0 - share), 0.001,
		"the stores did not lose the share the people did")
	assert_eq(raiders.size, 4_000, "the striker lost men to a party that cannot fight")


func test_a_big_enough_blow_empties_a_small_party_and_a_small_band_barely_dents_a_thick_one() -> void:
	var small := _run(500)
	_raiders(small, Company.RIVAL, 60_000)
	_month(small)
	assert_true(_party(small).is_empty(), "a duke's army left a lean party standing")
	var lost: Array = small.log.of_type(ExpeditionParty.EVENT_DESTROYED)
	assert_eq(lost.size(), 1)
	assert_eq(String(lost[0].payload["cause"]), "rival")

	var thick := _run(40_000)
	_raiders(thick, Company.NATIVE, 300)
	_month(thick)
	var struck: Array = thick.log.of_type(ExpeditionParty.EVENT_ATTACKED)
	assert_eq(struck.size(), 1)
	assert_true(float(struck[0].payload["share"]) < 0.01, "a small band mauled a thick expedition")


func test_two_strikes_turn_it_back() -> void:
	var run := _run(20_000)
	_raiders(run, Company.NATIVE, 2_000)
	_month(run)
	assert_false(_party(run).turning_back)
	_month(run)
	assert_true(_party(run).turning_back, "struck twice, it pressed on")


func test_rebels_never_strike_an_expedition() -> void:
	# SPEC §12.3: an expedition is a loyal town's people.
	var run := _run(8_000)
	_raiders(run, Company.REBEL, 20_000)
	_month(run)
	assert_empty(run.log.of_type(ExpeditionParty.EVENT_ATTACKED), "rebels fell on the colony's settlers")


func test_the_runs_first_lost_expedition_is_painted_for_who_did_it() -> void:
	var run := _run(500)
	_raiders(run, Company.NATIVE, 60_000)
	_month(run)
	var triggers: Array = []
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if record.has("cutscene"):
			triggers.append(record)
	var shown := CutsceneTriggers.ids_of(
		CutsceneTriggers.fired(triggers, run.log.of_type(ExpeditionParty.EVENT_DESTROYED), {}))
	assert_true(shown.has("they_do_not_return_natives"), "a party lost to a war party was not painted: %s" % [shown])


func test_the_rebels_painting_is_gone() -> void:
	# It could never fire: nobody but natives and dukes strikes an expedition.
	assert_false(FileAccess.file_exists("res://data/cutscenes_en/they_do_not_return_rebels.json"))
