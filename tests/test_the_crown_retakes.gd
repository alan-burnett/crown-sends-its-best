extends TestCase

## The Crown retakes a rebel town by making rebellion miserable (#455,
## `battles.md` §9, `rebel-sentiment.md` §5, SPEC §12.3).
##
## 🔒 Crown troops sent to put down the rebellion march on rebel towns, not only
## on rebel companies. 🔒 There is no capture, and the Crown never destroys its
## own town: an attack that would take a rebel town's last people brings it back
## instead, and #230's garrison follows. A town is lost only to rivals or natives.

const SEED: int = 455

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


func _town() -> Town:
	return run.colony.in_order()[0]


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.contacts = run.contacts
	return context


## A rebel town, out since a year ago.
func _rebel() -> Town:
	var town := _town()
	town.rebelling = true
	town.rebelling_since = run.world.month - 12
	town.declared_quality = 0.5
	return town


## Crown troops sent to put down the rebellion, landed a few tiles off.
func _put_down_the_rebellion(at: Vector2i) -> Company:
	var company := run.companies.raise_company(Company.CROWN, 10_000, {"guns": 10.0}, Company.SUPPORTED_ABROAD,
		at, _context(), StandingOrder.MARCH_ON_A_FOE, Company.COMMANDED)
	company.raised_under = CrownTroops.PUT_DOWN_THE_REBELLION
	return company


func test_they_march_on_a_rebel_town_with_nobody_in_the_field() -> void:
	var town := _rebel()
	var company := _put_down_the_rebellion(town.at + Vector2i(4, 0))
	var foe := OrderRule.foe_of(company, null, _context())
	assert_true(foe != null, "a rebel town with no company in the field was out of their reach")
	if foe == null:
		return
	assert_true(foe is TownCompany, "they marched on something other than the town")
	assert_eq(foe.at, town.at)


func test_a_loyal_town_is_never_their_foe() -> void:
	var company := _put_down_the_rebellion(_town().at + Vector2i(4, 0))
	assert_true(OrderRule.foe_of(company, null, _context()) == null, "men sent against rebels marched on a loyal town")


func test_an_attack_that_would_empty_it_brings_it_back_instead() -> void:
	var town := _rebel()
	var people := town.population()
	var wall := TownCompany.of(town, _put_down_the_rebellion(town.at + Vector2i(1, 0)))
	var taken := wall._remove(people, &"stormed", _context())

	assert_eq(taken, 0, "the Crown took a rebel town's last people")
	assert_eq(town.population(), people, "the town came back with fewer than were left")
	assert_false(town.rebelling, "the Crown beat the town and it stayed out")
	assert_true(run.colony.by_id(town.id) != null, "the Crown destroyed its own town")
	assert_empty(run.log.of_type(Colony.EVENT_LOST), "a town was lost to the Crown")
	var returned: Array = run.log.of_type(Rebellion.EVENT_RETURNED)
	assert_eq(returned.size(), 1, "the garrison has nothing to follow")
	assert_eq(String(returned[0].payload.get("how", "")), String(Rebellion.RETAKEN))


func test_short_of_emptying_it_the_crown_takes_lives_as_anyone_does() -> void:
	var town := _rebel()
	var people := town.population()
	var wall := TownCompany.of(town, _put_down_the_rebellion(town.at + Vector2i(1, 0)))
	var taken := wall._remove(people / 2, &"stormed", _context())
	assert_true(taken > 0, "a Crown attack took nobody")
	assert_eq(town.population(), people - taken)
	assert_true(town.rebelling, "half a town lost, and it came back without its life falling")


func test_the_garrison_follows_a_town_retaken() -> void:
	var town := _rebel()
	TownCompany.of(town, _put_down_the_rebellion(town.at + Vector2i(1, 0)))._remove(town.population(), &"stormed", _context())
	run.world.month += 1
	CrownTroops.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	var garrisoned := false
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.garrisons == town.id:
			garrisoned = true
	assert_true(garrisoned, "a town retaken by force was not garrisoned")
