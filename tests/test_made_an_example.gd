extends TestCase

## A Crown commander may make an example of a rebel town (#457,
## `commanders.md` §5, `rebel-sentiment.md` §4, SPEC §12.3).
##
## 🔒 Only a Crown commander putting down the rebellion has the choice, and only
## at a rebel town. 🔒 Punishing it burns its fields, strikes its expeditions and
## sits on its ground, for as long as he holds it. 🔒 He asks the PC first and
## acts on the answer, or he acts on his own and writes after. 🔒 A town made an
## example of persuades its neighbours only a quarter as much, for a year.

const SEED: int = 457

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
	run.world.month = 20


func after_each() -> void:
	reset_world()
	content.free()


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	context.commanders = run.commanders
	return context


func _rebel() -> Town:
	var town: Town = run.colony.in_order()[0]
	town.rebelling = true
	town.rebelling_since = run.world.month - 12
	town.declared_quality = 0.5
	return town


## Crown troops sent to put down the rebellion, beside the town, under a man who
## thinks this well of the PC.
func _sent(town: Town, loyalty: float = 90.0) -> Company:
	var company := run.companies.raise_company(Company.CROWN, 10_000, {"guns": 10.0},
		Company.SUPPORTED_ABROAD, town.at + Vector2i(1, 0), _context(),
		StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	company.raised_under = CrownTroops.PUT_DOWN_THE_REBELLION
	var man := Commanders.take_command(company, null, run, _context())
	man.relationship = Relationship.new(man.id, loyalty)
	return company


func _driver() -> CompanyDriver:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.book = run.intents
	driver.run = run
	driver.parties = run.parties
	driver.denied = run.denied
	return driver


## A farm of the town's beside the company, and the tile it stands on.
func _a_farm_beside(company: Company) -> Vector2i:
	var at := company.at + Vector2i(0, 1)
	run.map.improvements[run.map.index_of(at.x, at.y)] = "farm"
	return at


## An expedition of the town's, in the open beside the company.
func _an_expedition_of(town: Town, company: Company) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"party_out"
	party.parent = town.id
	party.people = 4_000
	party.at = company.at + Vector2i(1, 0)
	run.parties.append(party)
	return party


func _post() -> PackedStringArray:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	var post := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		post.append(inbound.letter_id)
	return post


# --- 🔒 Whose choice it is, and where ------------------------------------------

func test_only_troops_sent_against_the_rebellion_may_punish_and_only_a_rebel_town() -> void:
	var town := run.colony.in_order()[0] as Town
	var company := _sent(town)
	assert_true(MakingAnExample.town_within_reach(company, run.colony) == null,
		"men sent against rebels could punish a loyal town")
	_rebel()
	assert_true(MakingAnExample.town_within_reach(company, run.colony) == town,
		"men sent against a rebel town could not punish it")
	company.raised_under = &"to_defend_the_colony"
	assert_true(MakingAnExample.town_within_reach(company, run.colony) == null,
		"men sent for something else could make an example of a town")


func test_he_weighs_it_with_everything_else_and_takes_it_when_it_is_best() -> void:
	# A man who weighs nothing but what the PC urged, urged toward it: the kernel
	# offers it among his options and he takes it — asking first, as a loyal man
	# does, through the ordinary month.
	var town := _rebel()
	var company := _sent(town, 90.0)
	var man := run.contact(company.commander)
	for id in CommanderConsiderations.ALL:
		man.weights[String(id)] = 0.0
	man.weights["the_crowns_urging"] = 1.0
	company.urge(CommanderConsiderations.PUNISH, Tone.DUTIFUL, run.world.month)

	_driver().on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_eq(run.log.of_type(MakingAnExample.EVENT_PROPOSED).size(), 1,
		"urged toward it with nothing against it, he never chose to punish the town")


# --- 🔒 What punishing does ------------------------------------------------------

func test_punishing_burns_its_fields_strikes_its_expeditions_and_sits_on_its_ground() -> void:
	var town := _rebel()
	var company := _sent(town)
	var farm := _a_farm_beside(company)
	var party := _an_expedition_of(town, company)
	var souls := party.souls()

	_driver()._punish(company, town, true, _context())

	assert_eq(String(run.map.improvement_at(farm.x, farm.y)), "", "the town's farm was not burnt")
	assert_true(party.souls() < souls, "the town's expedition in the open was not struck")
	assert_true(run.denied.is_denied(farm), "his men did not sit on the town's fields")
	# 🔒 **And the town cannot work it**, as it cannot a field a duke's men sit on.
	var context := _context()
	context.territory = Territory.compute(run.map, run.colony.in_order())
	context.denied = run.denied
	assert_true(context.territory.tiles_of(town.id).has(farm), "the fixture's field is not the town's")
	assert_false(context.tiles_of(town).has(farm), "the town worked a field the Crown's men sat on")
	assert_true(town.is_made_an_example(), "a punished town was not made an example of")
	assert_eq(run.log.of_type(MakingAnExample.EVENT_PUNISHED).size(), 1)


func test_they_leave_its_fields_when_he_stops() -> void:
	var town := _rebel()
	var company := _sent(town)
	var farm := _a_farm_beside(company)
	var driver := _driver()
	driver._punish(company, town, true, _context())
	assert_true(run.denied.is_denied(farm))

	company.size = 0
	run.world.month += 1
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)
	assert_false(run.denied.is_denied(farm), "his men sat on the fields after he had gone")


# --- 🔒 He asks first, or he says so after --------------------------------------

func test_a_loyal_commander_asks_first_and_acts_on_the_answer() -> void:
	var town := _rebel()
	var company := _sent(town, 90.0)
	var driver := _driver()
	driver._punish_or_ask(company, _context())

	assert_eq(run.log.of_type(MakingAnExample.EVENT_PROPOSED).size(), 1, "he did not ask")
	assert_false(town.is_made_an_example(), "he asked and began before the answer came")
	assert_true(_post().has("commander.may_i_make_an_example"), "he asked and no letter came")

	run.world.month += 1
	assert_false(MakingAnExample.may_punish(company, town, run.log, run.world.month),
		"he asked and did not wait for the answer")

	# The PC's yes, landed as an urging through compliance.
	run.world.month += 2
	company.urge(CommanderConsiderations.PUNISH, Tone.DUTIFUL, run.world.month)
	assert_true(MakingAnExample.may_punish(company, town, run.log, run.world.month))
	driver._punish_or_ask(company, _context())
	assert_true(town.is_made_an_example(), "the PC said yes and he did not act on it")
	assert_empty(run.log.of_type(MakingAnExample.EVENT_ACTED_ALONE), "he had leave and said he had not")


func test_the_letter_offers_yes_as_an_urging_toward_it() -> void:
	var record := content.record("letters", "commander.may_i_make_an_example")
	var urged := PackedStringArray()
	for option in record["reply"]["steps"][0]["options"]:
		urged.append(String(option["effect"]["urge_company"]["order"]))
	assert_true(urged.has(String(CommanderConsiderations.PUNISH)), "the PC cannot say yes")
	assert_eq(urged.size(), 2)


func test_any_other_answer_spares_the_town_for_a_year() -> void:
	var town := _rebel()
	var company := _sent(town, 90.0)
	var asked := run.world.month
	_driver()._punish_or_ask(company, _context())

	var spared_until := asked + MakingAnExample.ANSWER_MONTHS + MakingAnExample.SPARED_MONTHS
	assert_false(MakingAnExample.may_punish(company, town, run.log, asked + MakingAnExample.ANSWER_MONTHS + 1),
		"the PC did not say yes and he punished the town anyway")
	assert_false(MakingAnExample.may_punish(company, town, run.log, spared_until))
	assert_true(MakingAnExample.may_punish(company, town, run.log, spared_until + 1),
		"a town once spared was spared for ever")


func test_a_man_who_no_longer_asks_acts_and_writes_after() -> void:
	Consultation.load_from({"always_above": 101.0, "floor_chance": 0.0, "at_bottom": 101.0})
	var town := _rebel()
	var company := _sent(town, 10.0)
	var driver := _driver()
	driver._punish_or_ask(company, _context())

	assert_empty(run.log.of_type(MakingAnExample.EVENT_PROPOSED), "a man past asking asked")
	assert_eq(run.log.of_type(MakingAnExample.EVENT_ACTED_ALONE).size(), 1)
	assert_true(town.is_made_an_example(), "he said he would do it and did not")
	assert_true(_post().has("commander.i_made_an_example"), "he acted alone and never wrote to say so")

	# **Going on is not beginning again**: he does not write every month.
	run.world.month += 1
	driver._punish_or_ask(company, _context())
	assert_eq(run.log.of_type(MakingAnExample.EVENT_ACTED_ALONE).size(), 1)
	assert_eq(run.log.of_type(MakingAnExample.EVENT_PUNISHED).size(), 2)


# --- 🔒 Made an example of ------------------------------------------------------

func test_a_punished_towns_example_persuades_a_quarter_as_much_for_a_year() -> void:
	var town := _rebel()
	town.quality_of_life = 0.8
	var full := RebelSentiment.argument_of(town)
	_driver()._punish(_sent(town), town, true, _context())
	assert_almost_eq(RebelSentiment.argument_of(town), full * RebelSentiment.PUNISHED_SHARE, 0.0001,
		"a town made an example of argued for rebellion as loudly as ever")

	# **Forgotten a month at a time**, in the Colony Month, as an embargo runs down.
	var context := _context()
	context.grievances = Grievances.new()
	for month in MakingAnExample.MONTHS:
		assert_true(town.is_made_an_example(), "it was forgotten after %d months" % month)
		run.world.month += 1
		SettlePhase.new()._take_the_temperature(town, context)
	assert_false(town.is_made_an_example(), "a town made an example of was remembered for ever")


func test_it_survives_a_save() -> void:
	var town := _rebel()
	var company := _sent(town)
	var farm := _a_farm_beside(company)
	_driver()._punish(company, town, true, _context())
	assert_true(DeniedTiles.from_dict(run.denied.to_dict()).is_denied(farm), "a reload lifted the occupation")
	assert_eq(Town.from_dict(town.to_dict()).example_months, town.example_months)
