extends TestCase

## Buildings that reach other towns (#415, `docs/mechanics/buildings.md` §3,
## §4 *Expansion*, *Comfort*; `quality-of-life.md` §4).
##
## 🔒 **There is no nearby, and colony-wide effects do not stack.** A cathedral
## comforts every town without a church, a fairgrounds amuses every town without
## one, and a printing press every town that has none — each town receiving each
## at most once, however many stand.

const SEED: int = 415

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


func _town(id: String, buildings: Array = []) -> Town:
	var town := Town.new(StringName(id), id.capitalize(), Vector2i(0, 0))
	town.workers = 12_000
	for building in buildings:
		town.add_building(StringName(building))
	return town


func _colony(towns: Array) -> Colony:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	return colony


func _amused(town: Town, colony: Colony) -> float:
	return float(Building.amusement_for(town, colony)["served"])


func test_a_cathedral_comforts_every_town_without_a_church_and_no_town_twice() -> void:
	var see := _town("see", ["church", "cathedral"])
	var bare := _town("bare")
	var chapel := _town("chapel", ["church"])
	var colony := _colony([see, bare, chapel])
	var alone := _colony([bare])
	assert_true(Building.perceived_safety_for(bare, {}, colony) > Building.perceived_safety_for(bare, {}, alone),
		"a town without a church felt nothing of the colony's cathedral")
	assert_true(_amused(bare, colony) > _amused(bare, alone))
	assert_almost_eq(Building.perceived_safety_for(chapel, {}, colony),
		Building.perceived_safety_for(chapel, {}, _colony([chapel])), 0.0001,
		"a town with its own church was comforted twice")


func test_a_second_fairgrounds_adds_nothing_more() -> void:
	var fair := _town("fair", ["fairgrounds"])
	var bare := _town("bare")
	var one := _amused(bare, _colony([fair, bare]))
	var none := _amused(bare, _colony([bare]))
	assert_true(one > none, "a town without a fairgrounds was not amused by the colony's")
	var other_fair := _town("other_fair", ["fairgrounds"])
	assert_almost_eq(_amused(bare, _colony([fair, other_fair, bare])), one, 0.0001,
		"a second fairgrounds amused a town that has none again")
	# And the fair town has its own, and nothing from the other.
	assert_almost_eq(_amused(fair, _colony([fair, other_fair])), _amused(fair, _colony([fair])), 0.0001)


func test_two_printing_presses_give_every_town_the_same_as_one() -> void:
	var bare := _town("bare")
	var one := _amused(bare, _colony([_town("press", ["printing_press"]), bare]))
	var two := _amused(bare, _colony([_town("press", ["printing_press"]), _town("second", ["printing_press"]), bare]))
	assert_true(one > _amused(bare, _colony([bare])))
	assert_almost_eq(two, one, 0.0001, "two presses amused the colony twice over")


func test_a_dark_cathedral_comforts_nobody_that_month() -> void:
	var see := _town("see", ["church", "cathedral"])
	see.dark_buildings = PackedStringArray(["cathedral"])
	var bare := _town("bare")
	assert_almost_eq(Building.perceived_safety_for(bare, {}, _colony([see, bare])),
		Building.perceived_safety_for(bare, {}, _colony([bare])), 0.0001,
		"a cathedral nobody paid for still comforted the colony")


## A colony month's context over these towns, with nobody hungry.
func _context(colony: Colony) -> ColonyContext:
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	context.colony = colony
	return context


func test_the_month_itself_feels_it() -> void:
	# Through Consume's record and the town's safety, not only the readers.
	var bare := _town("bare")
	var alone := _context(_colony([bare]))
	ConsumePhase.new().run(bare, ColonySnapshot.of(alone.colony), alone)
	var by_itself := float(alone.wellbeing["bare"]["luxury"])

	var with_press := _town("bare")
	var colony := _colony([_town("press", ["printing_press", "church", "cathedral"]), with_press])
	var reached := _context(colony)
	ConsumePhase.new().run(with_press, ColonySnapshot.of(colony), reached)
	assert_true(float(reached.wellbeing["bare"]["luxury"]) > by_itself,
		"the month's pleasure never heard of the colony's printing press")

	# Comfort only fills the gap a threat opens, so a war party at the gate.
	for context in [alone, reached]:
		context.companies = Companies.new()
		context.companies.raise_company(Company.NATIVE, 50_000, {}, Company.SUPPORTED_ABROAD,
			Vector2i(1, 0), context, StandingOrder.DEFEND_THE_TOWN, Company.MILITIA)
	assert_true(QualityOfLife.safety_of(bare, alone) < 1.0, "the fixture's war party frightens nobody")
	assert_true(QualityOfLife.safety_of(with_press, reached) > QualityOfLife.safety_of(bare, alone),
		"the town's safety never heard of the colony's cathedral")


func test_the_validator_refuses_a_reach_to_a_building_that_does_not_exist() -> void:
	var validator := ContentValidator.new()
	validator.check_colony_reach(content)
	assert_true(validator.ok(), "the shipped reaches do not validate")
	content.collection("buildings")["cathedral"]["effects"]["reaches_colony"]["towns_without"] = "kirk"
	validator = ContentValidator.new()
	validator.check_colony_reach(content)
	assert_false(validator.ok(), "a reach to towns without a kirk passed")
