extends TestCase

## What it costs to keep a town's buildings running (#151).
##
## 🔒 **A squeeze, not a punishment.** A town that cannot pay keeps the building
## and loses the effect; it stands idle and switches back on the moment the town
## can afford it again, with no repair cost and no rebuilding. Everything here is
## about that distinction, because it is the whole design — a bad year costs a
## town its advantages temporarily rather than permanently.

const SEED: int = 1649

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


func _map() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(1, 6):
		for x in range(1, 6):
			map.set_terrain(x, y, &"plains")
	return map


func _town(gold: float, buildings: Array = []) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = 8
	town.receive_gold(gold)
	for id in buildings:
		town.add_building(StringName(id))
	return town


func _harness(town: Town) -> Dictionary:
	var map := _map()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return {"colony": colony, "context": context, "town": town, "map": map}


func _settle(harness: Dictionary) -> float:
	return Upkeep.settle(harness["town"], harness["context"])


# --- 🔒 It stands, and it stops working -------------------------------------

func test_a_town_that_cannot_pay_keeps_the_building_and_loses_the_effect() -> void:
	var broke := _town(0.0, ["sawmill"])
	var harness := _harness(broke)
	var lit := Building.yield_bonus_for(broke, &"wood")
	assert_true(lit > 0.0, "the fixture's sawmill does nothing even when paid for")

	_settle(harness)
	assert_true(broke.has_building(&"sawmill"),
		"the building was taken away, which is a punishment rather than a squeeze")
	assert_almost_eq(Building.yield_bonus_for(broke, &"wood"), 0.0, 0.0001,
		"a mill nobody is paying for went on milling")


func test_it_resumes_the_moment_the_town_can_pay() -> void:
	# **No repair cost and no rebuilding.** A bad year costs a town its
	# advantages temporarily and gives them back when things improve.
	var town := _town(0.0, ["sawmill"])
	var harness := _harness(town)
	_settle(harness)
	assert_almost_eq(Building.yield_bonus_for(town, &"wood"), 0.0, 0.0001)

	town.receive_gold(500.0)
	var paid := _settle(harness)
	assert_true(paid > 0.0, "a solvent town paid nothing")
	assert_true(Building.yield_bonus_for(town, &"wood") > 0.0,
		"the mill stayed dark after the town could afford it again")


func test_a_dark_building_is_announced_and_so_is_its_return() -> void:
	# 🔒 Town gold is hidden, so a governor writing is the **entire interface**
	# of this mechanic. A player left to infer it from numbers he cannot see has
	# been given a trap rather than a decision.
	var town := _town(0.0, ["sawmill"])
	var harness := _harness(town)
	_settle(harness)

	var context: ColonyContext = harness["context"]
	var went: Array = context.log.of_type(Upkeep.EVENT_DARK)
	assert_eq(went.size(), 1, "a mill went dark and nothing said so")
	assert_eq(String(went[0].payload["building"]), "sawmill")
	assert_true(not String(went[0].payload["name"]).is_empty(),
		"it named an id rather than something a letter could print")

	town.receive_gold(500.0)
	_settle(harness)
	assert_eq(context.log.of_type(Upkeep.EVENT_RELIT).size(), 1,
		"the mill came back and nothing said so")


func test_nothing_is_announced_twice_for_the_same_darkness() -> void:
	# A governor who wrote the same letter every month about the same idle mill
	# would be noise rather than news.
	var town := _town(0.0, ["sawmill"])
	var harness := _harness(town)
	_settle(harness)
	_settle(harness)
	assert_eq(harness["context"].log.of_type(Upkeep.EVENT_DARK).size(), 1,
		"the governor reported the same idle mill twice")


# --- 🔒 What goes dark first --------------------------------------------------

func test_it_keeps_what_the_governor_values_and_lets_the_rest_go() -> void:
	# A man on a military intent keeps the armoury lit and lets the church go
	# dark. That comes from the same axes the objective selector scores a
	# building on, rather than from a second opinion about what a building is for.
	# **The two cost the same on purpose.** Give them different upkeeps and the
	# purse alone decides which is affordable, and the test passes whatever order
	# the governor would have chosen — which is how the first version of it
	# passed while testing nothing.
	var church := Building.find(&"church").upkeep
	var wall := Building.find(&"palisade").upkeep
	assert_almost_eq(church, wall, 0.0001,
		"the fixture's two buildings cost different amounts, so the purse decides and not the man")

	var soldier := _town(wall, ["church", "palisade"])
	soldier.intent = GovernorIntent.DEFENCE
	var harness := _harness(soldier)
	_settle(harness)

	assert_false(soldier.dark_buildings.has("palisade"),
		"a governor bent on defence let his wall go dark and kept the church lit")
	assert_true(soldier.dark_buildings.has("church"),
		"he paid for both on a purse that covers one")


# --- 🔒 Before Work, so effects and payment agree within a month --------------

func test_upkeep_settles_before_the_months_phases() -> void:
	# Buildings reach Work through yields, Reckon through reserves and Build
	# through speed, so a town paying afterwards would get a free month of
	# effects from something it cannot afford.
	var broke := _town(0.0, ["sawmill"])
	var rich := _town(5_000.0, ["sawmill"])
	var poor_wood := _run_a_month(broke)
	var rich_wood := _run_a_month(rich)
	assert_true(rich_wood > poor_wood,
		"a town that could not pay for its mill cut as much timber as one that could")


func _run_a_month(town: Town) -> float:
	var harness := _harness(town)
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	month.run(harness["colony"], harness["context"])
	return town.held(&"wood")


# --- 🔒 An idle improvement reverts its tile ---------------------------------

func test_a_disabled_improvement_reverts_its_tile() -> void:
	var town := _town(0.0)
	var harness := _harness(town)
	var map: WorldMap = harness["map"]
	map.build(3, 3, &"farm", harness["context"].log, 0, town.id)

	var improved := map.yield_at(3, 3, &"food")
	_settle(harness)
	var idle := map.yield_at(3, 3, &"food")
	assert_true(idle < improved,
		"a farm nobody is paying to work yielded as though somebody were")
	assert_eq(String(map.improvement_at(3, 3)), "farm",
		"the farm was taken away rather than left standing idle")

	town.receive_gold(500.0)
	_settle(harness)
	assert_almost_eq(map.yield_at(3, 3, &"food"), improved, 0.0001,
		"the farm never came back")


func test_upkeep_survives_save_and_reload() -> void:
	# Ironman means a corrupt save is a lost run, and a town whose mills all lit
	# themselves on load would be found by a player rather than by a test.
	var town := _town(0.0, ["sawmill"])
	_settle(_harness(town))
	var restored := Town.from_dict(town.to_dict())
	assert_eq(",".join(restored.dark_buildings), ",".join(town.dark_buildings))
	assert_almost_eq(Building.yield_bonus_for(restored, &"wood"), 0.0, 0.0001,
		"a reloaded town lit every mill it could not pay for")


# --- 🔒 And the governor writes about it ------------------------------------

func test_a_dark_building_puts_a_letter_on_the_desk() -> void:
	# **The mechanic's entire interface.** SPEC §11.3 makes town gold invisible,
	# so without this the player watches yields fall and quality of life slip for
	# reasons he has no way to account for.
	var context := LetterContext.new()
	var town := _town(0.0, ["sawmill"])
	_settle(_harness(town))
	context.town = town

	assert_true(ContentRegistry.test_condition("town_has_an_idle_building", {}, context),
		"a town with a shut mill does not qualify for the letter that says so")

	var named: Variant = ContentRegistry.supply_param("idle_building", {}, context)
	assert_eq(String(named), Building.find(&"sawmill").display_name,
		"the letter would have printed an id at the player")


func test_a_solvent_town_has_nothing_to_report() -> void:
	var context := LetterContext.new()
	var town := _town(5_000.0, ["sawmill"])
	_settle(_harness(town))
	context.town = town
	assert_false(ContentRegistry.test_condition("town_has_an_idle_building", {}, context),
		"a town paying its way wrote to complain that it was not")
