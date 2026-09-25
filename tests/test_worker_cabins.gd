extends TestCase

## Worker cabins (#412, `docs/mechanics/tiles-and-improvements.md` §4, §5,
## `buildings.md` §4 *Expansion*).
##
## 🔒 **Improvements build faster, and cost no upkeep while the cabins are
## paid for.** Nothing that speeds buildings speeds improvements, and the cabins
## do not speed buildings.

const SEED: int = 412

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


func _town(cabins: bool, gold: float = 0.0) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(5, 5))
	town.workers = 12_000
	town.intent = GovernorIntent.GO_WIDE
	town.receive_gold(gold)
	if cabins:
		town.add_building(&"scouts")
		town.add_building(&"worker_cabins")
	return town


## Plains all round, with three farms on the town's ground.
func _context(town: Town) -> ColonyContext:
	var map := WorldMap.new(11, 11, &"plains")
	for x in [4, 5, 6]:
		map.build(x, 4, &"farm")
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return context


func _improvement_upkeep() -> float:
	return 3.0 * Improvement.find(&"farm").upkeep


# --- 🔒 Faster, for improvements only -------------------------------------------

func test_an_improvement_goes_up_faster_and_a_building_does_not() -> void:
	var plain := _town(false)
	var housed := _town(true)
	plain.objective = &"farm"
	housed.objective = &"farm"
	assert_true(Objective.build_capacity(housed) > Objective.build_capacity(plain),
		"worker cabins built a farm no faster")
	plain.objective = &"granary"
	housed.objective = &"granary"
	assert_almost_eq(Objective.build_capacity(housed), Objective.build_capacity(plain), 0.0001,
		"worker cabins sped a building")


# --- 🔒 No improvement upkeep while the cabins are paid for --------------------------

func test_a_town_with_worker_cabins_pays_no_improvement_upkeep() -> void:
	var plain := _town(false, 100.0)
	var housed := _town(true, 100.0)
	var paid_plain := Upkeep.settle(plain, _context(plain))
	var housed_context := _context(housed)
	var paid_housed := Upkeep.settle(housed, housed_context)
	assert_true(_improvement_upkeep() > 0.0, "the fixture's farms cost nothing, so this proves nothing")
	assert_almost_eq(paid_plain, Building.upkeep_for(plain) + _improvement_upkeep(), 0.0001)
	assert_almost_eq(paid_housed, Building.upkeep_for(housed), 0.0001,
		"a town with worker cabins paid for its farms")
	for x in [4, 5, 6]:
		assert_false(housed_context.map.is_idle(x, 4), "a farm went idle in a town whose cabins carry it")


func test_when_the_cabins_go_dark_the_improvement_upkeep_returns() -> void:
	# Enough for the farms and not for the cabins: the cabins go dark and the
	# farms are billed again, and paid.
	var town := _town(true, _improvement_upkeep() + Building.upkeep_for(_town(false)))
	var paid := Upkeep.settle(town, _context(town))
	assert_true(town.dark_buildings.has("worker_cabins"), "the fixture could afford its cabins")
	assert_almost_eq(paid, _improvement_upkeep() + Building.upkeep_for(_town(false)), 0.0001,
		"with the cabins dark, the farms were not billed")
