extends TestCase

## Expeditions travel as units and cannot fight (#176,
## `docs/mechanics/founding-towns.md` §6, §7).
##
## 🔒 **It never defends itself**, whatever it carries. Settlers with wagons of
## goods — and guns among the cargo — are no substitute for an army ready to
## fight. It is prey until it arrives.
##
## 🔒 **A deliberate exception to the one-at-a-time rule.** `CLAUDE.md` holds
## that no event of hardship costs a town more than one population. **A body of
## people in the open is not a town**: it has no walls, no neighbours and nobody
## to call on, and an ambush that takes a quarter of them is the correct fiction.
## A dev should not "fix" this to match the town rule.
##
## 🔒 **Two attacks and it turns back** — a setback rather than a catastrophe.
## The people come home, the remaining stores come home, and the months are gone.

const SEED: int = 3612

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


func _town(id: StringName = &"ashmere", at: Vector2i = Vector2i(2, 2)) -> Town:
	var town := Town.new(id, String(id).capitalize(), at)
	town.workers = 40
	return town


func _context(colony: Colony, parties: Array = []) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	context.colony = colony
	context.parties = parties
	return context


func _colony(towns: Array) -> Colony:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	return colony


## A party of twenty with stores and coin, standing at its parent's gate.
func _party(parent: StringName = &"ashmere", at: Vector2i = Vector2i(2, 2)) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"expedition_test"
	party.parent = parent
	party.people = 20
	party.experts = {"food": 2, "furs": 2}
	party.cargo = {"food": 400.0, "tools": 40.0, "guns": 8.0}
	party.gold = 600.0
	party.at = at
	party.destination = Vector2i(6, 2)
	return party


# --- 🔒 It travels as a unit ------------------------------------------------

func test_launching_puts_a_party_on_the_map() -> void:
	var town := _town()
	town.objective_cargo = {"food": 100.0}
	town.store(&"food", 400.0)
	town.receive_gold(900.0)
	var context := _context(_colony([town]))

	var party := Expedition.launch(town, context)
	assert_true(party != null, "the town sent an expedition and nothing set out")
	assert_eq(context.parties.size(), 1, "it never reached the map")
	assert_eq(party.at, town.at, "it started somewhere other than the town that sent it")
	assert_true(party.souls() > 0 and party.gold > 0.0,
		"it left with nobody and nothing")


func test_it_moves_a_step_a_month_and_does_not_teleport() -> void:
	var party := _party()
	var context := _context(_colony([_town()]))
	var began := party.at
	assert_false(party.advance(party.destination, context),
		"it crossed the whole country in one month")
	assert_true(party.at != began, "it did not move at all")
	assert_true(party.at.distance_squared_to(party.destination)
			< began.distance_squared_to(party.destination),
		"it moved away from where it was going")


func test_it_gets_there_eventually() -> void:
	var party := _party()
	var context := _context(_colony([_town()]))
	var arrived := false
	for month in 20:
		context.state.month = month
		if party.advance(party.destination, context):
			arrived = true
			break
	assert_true(arrived, "it never reached its site")
	assert_eq(party.at, party.destination)


func test_a_party_with_nowhere_to_go_waits() -> void:
	# 🔒 #177 gives it a destination. Until then it stands at the gate rather
	# than wandering, so that ticket sets a field and does not rewrite the
	# journey — and so the player never watches it go nowhere for no reason.
	var party := _party()
	party.destination = Vector2i(-1, -1)
	var driver := ExpeditionDriver.new()
	driver.colony = _colony([_town()])
	driver.parties = [party]
	var began := party.at

	for month in 6:
		driver.on_phase(WorldPhase.MOVEMENT, WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED))
	assert_eq(party.at, began, "a party with no site to go to wandered off")
	assert_eq(driver.parties.size(), 1, "it was quietly dropped")


func test_moving_is_on_the_record() -> void:
	var party := _party()
	var context := _context(_colony([_town()]))
	party.advance(party.destination, context)
	var moved: Array = context.log.of_type(ExpeditionParty.EVENT_MOVED)
	assert_eq(moved.size(), 1, "it crossed a county and the map heard nothing")
	assert_eq(String(moved[0].payload["town"]), "ashmere")
	assert_eq(int(moved[0].payload["souls"]), party.souls())


# --- 🔒 An attack takes a share of everything -------------------------------

func test_an_attack_takes_people_and_the_same_share_of_the_stores() -> void:
	# 🔒 §7. **A quarter of the people lost is a quarter of the stores lost with
	# them** — the wagons that were lost were carrying something.
	var party := _party()
	var context := _context(_colony([_town()]), [])
	var food := float(party.cargo["food"])
	var coin := party.gold

	party.attacked(0.25, "natives", context)
	assert_true(party.people < 20, "an ambush took nobody")
	assert_almost_eq(float(party.cargo["food"]), food * 0.75, 0.001,
		"the people were lost and the food walked home by itself")
	assert_almost_eq(party.gold, coin * 0.75, 0.001, "the coin survived the wagons")


func test_it_loses_more_than_one_person_which_a_town_never_would() -> void:
	# 🔒 The deliberate exception. `CLAUDE.md`'s rule protects a settled
	# population going about its business; a body of people in the open is not
	# that, and this test exists so nobody "fixes" it back.
	var party := _party()
	party.people = 40
	party.attacked(0.25, "natives", _context(_colony([_town()])))
	assert_true(40 - party.people > 1,
		"an ambush on forty people in the open took one of them, as if they were a town")


func test_every_cargo_line_loses_the_same_share() -> void:
	var party := _party()
	var before := party.cargo.duplicate()
	party.attacked(0.5, "natives", _context(_colony([_town()])))
	for resource in before:
		assert_almost_eq(float(party.cargo[resource]), float(before[resource]) * 0.5, 0.001,
			"'%s' came through an ambush better than the rest of the wagons" % resource)


func test_the_attack_says_what_it_cost() -> void:
	var party := _party()
	var context := _context(_colony([_town()]))
	party.attacked(0.25, "natives", context)
	var hit: Array = context.log.of_type(ExpeditionParty.EVENT_ATTACKED)
	assert_eq(hit.size(), 1, "it was ambushed and nothing was written down")
	assert_true(int(hit[0].payload["lost_people"]) > 0)
	assert_false(Dictionary(hit[0].payload["lost_cargo"]).is_empty(),
		"the event does not say what the wagons were carrying")
	assert_eq(String(hit[0].payload["cause"]), "natives")


func test_it_never_returns_fire() -> void:
	# 🔒 §7. Settlers with guns in the cargo are **not** an army. There is no
	# defence here and nowhere to put one, and this test is the statement of
	# that: the guns it carries change nothing about what an ambush costs.
	var armed := _party()
	armed.cargo["guns"] = 500.0
	var unarmed := _party()
	unarmed.cargo["guns"] = 0.0
	var context := _context(_colony([_town()]))

	armed.attacked(0.25, "natives", context)
	unarmed.attacked(0.25, "natives", context)
	assert_eq(armed.people, unarmed.people,
		"a wagon of muskets defended the party, which is exactly what it must not do")


# --- 🔒 Two attacks and it turns back ---------------------------------------

func test_the_second_attack_turns_it_back() -> void:
	var party := _party()
	var context := _context(_colony([_town()]))
	party.attacked(0.2, "natives", context)
	assert_false(party.turning_back, "one ambush and it gave up")
	party.attacked(0.2, "natives", context)
	assert_true(party.turning_back, "two ambushes and it pressed on regardless")
	assert_not_empty(context.log.of_type(ExpeditionParty.EVENT_TURNED_BACK))


func test_it_comes_home_with_what_is_left() -> void:
	# **A setback rather than a catastrophe.** The people come home, the
	# remaining stores come home, and the months are gone — the months being the
	# actual loss.
	var town := _town()
	var before_people := town.population()
	var party := _party()
	party.turning_back = true
	party.at = Vector2i(5, 2)

	var driver := ExpeditionDriver.new()
	driver.colony = _colony([town])
	driver.parties = [party]
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	for month in 12:
		state.month = month
		driver.on_phase(WorldPhase.MOVEMENT, state, log, RngStreams.new(SEED))

	assert_true(driver.parties.is_empty(), "it never got home")
	assert_true(town.population() > before_people, "the people did not rejoin the town")
	assert_true(town.held(&"food") > 0.0, "the stores did not come back with them")
	assert_not_empty(log.of_type(ExpeditionParty.EVENT_CAME_HOME))


func test_the_experts_come_home_too() -> void:
	var town := _town()
	var party := _party()
	party.turning_back = true
	party.at = town.at
	var context := _context(_colony([town]))
	party.come_home(town, context)
	assert_eq(town.expert_count(&"food"), 2, "the skilled men did not come back")


# --- 🔒 Destroyed is the extreme of the same rule ---------------------------

func test_a_party_with_nobody_left_is_destroyed_rather_than_turning_back() -> void:
	# §11.4 is not a separate case: an expedition small enough, hit hard enough,
	# has nobody left to turn back.
	var party := _party()
	party.people = 3
	party.experts = {}
	var context := _context(_colony([_town()]))
	party.attacked(1.0, "natives", context)

	assert_true(party.is_empty(), "everybody died and somebody was still walking")
	assert_not_empty(context.log.of_type(ExpeditionParty.EVENT_DESTROYED))
	assert_empty(context.log.of_type(ExpeditionParty.EVENT_TURNED_BACK),
		"a party with nobody in it turned for home")


func test_a_destroyed_party_leaves_the_map() -> void:
	var party := _party()
	party.people = 0
	party.experts = {}
	var driver := ExpeditionDriver.new()
	driver.colony = _colony([_town()])
	driver.parties = [party]
	driver.on_phase(
		WorldPhase.MOVEMENT, WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED))
	assert_true(driver.parties.is_empty(), "an empty party was still crossing the country")


# --- The save ----------------------------------------------------------------

func test_a_party_survives_a_save() -> void:
	# Months of a town's people and stores are walking about outside it. Losing
	# them to a reload would lose the town's investment with them.
	var party := _party()
	party.attacks = 1
	party.turning_back = true
	var restored := ExpeditionParty.from_dict(party.to_dict())

	assert_eq(restored.souls(), party.souls())
	assert_eq(restored.at, party.at)
	assert_eq(restored.destination, party.destination)
	assert_eq(restored.attacks, 1)
	assert_true(restored.turning_back)
	assert_almost_eq(restored.gold, party.gold, 0.001)
	assert_almost_eq(float(restored.cargo["food"]), float(party.cargo["food"]), 0.001)
