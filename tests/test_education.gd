extends TestCase

## What a town has worth teaching (#168, `docs/mechanics/the-provost.md` §3).
##
## 🔒 **A library turns expertise into more expertise.** An expert in an
## unlettered town teaches nobody; give the town a library and his presence
## becomes education, so a town that gets its first scholar finds the second
## easier. That compounding is the reason the library is expensive and sits where
## it does in the tree, and it is the only thing here that is not bookkeeping.
##
## 🔒 **Education gates natural growth only.** A town with none will never raise
## an expert of its own, but it can still be *sent* them — immigration brings
## experts on its own terms. An unlettered town is not shut out of expertise.

const SEED: int = 4021

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


func _town(id: StringName = &"ashmere", scholars: int = 0, buildings: Array = []) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 12
	town.receive_gold(5_000.0)  # so upkeep leaves its buildings lit (#151)
	if scholars > 0:
		town.add_experts(&"tobacco", scholars)
	for name in buildings:
		town.add_building(StringName(name))
	return town


func _context(towns: Array) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	return context


func _measure(town: Town, others: Array = []) -> float:
	return Education.of(town, _context([town] + others))


# --- 🔒 A library turns expertise into more expertise -----------------------

func test_an_expert_in_an_unlettered_town_teaches_nobody() -> void:
	var learned := _town(&"ashmere", 4)
	assert_almost_eq(_measure(learned), 0.0, 0.0001,
		"four scholars and nowhere to teach still raised the town's education")


func test_a_library_turns_residents_into_education() -> void:
	var without := _town(&"ashmere", 4)
	var with_library := _town(&"bellhaven", 4, ["theatre", "library"])
	var bare_library := _town(&"cawdor", 0, ["theatre", "library"])

	assert_true(_measure(with_library) > _measure(without),
		"a library taught nothing to a town full of scholars")
	assert_true(_measure(with_library) > _measure(bare_library),
		"the library was worth the same with four scholars as with none")


func test_the_second_scholar_is_easier_than_the_first() -> void:
	# The compounding engine, stated as the doc states it.
	var one := _town(&"ashmere", 1, ["theatre", "library"])
	var two := _town(&"bellhaven", 2, ["theatre", "library"])
	assert_true(_measure(two) > _measure(one),
		"a second scholar added nothing, so nothing compounds")


# --- 🔒 A college counts the colony's scholars ------------------------------

func test_a_college_counts_experts_elsewhere() -> void:
	var elsewhere := _town(&"bellhaven", 3)
	var collegiate := _town(&"ashmere", 1, ["theatre", "library", "college"])
	var alone := _town(&"cawdor", 1, ["theatre", "library", "college"])

	assert_true(_measure(collegiate, [elsewhere]) > _measure(alone),
		"three scholars in the next town over counted for nothing at a college")


func test_a_library_alone_does_not_reach_the_next_town() -> void:
	var elsewhere := _town(&"bellhaven", 3)
	var lettered := _town(&"ashmere", 1, ["theatre", "library"])
	assert_almost_eq(_measure(lettered, [elsewhere]), _measure(lettered), 0.0001,
		"a library read the whole colony's scholars, which is the college's trick")


# --- Bookkeeping ------------------------------------------------------------

func test_buildings_contribute_on_their_own() -> void:
	var plain := _town()
	var lettered := _town(&"bellhaven", 0, ["theatre"])
	assert_true(_measure(lettered) > _measure(plain),
		"a theatre taught nobody anything")


func test_an_unpaid_building_teaches_nothing() -> void:
	# It stands idle like every other effect (#151).
	var broke := _town(&"ashmere", 4, ["theatre", "library"])
	var context := _context([broke])
	assert_true(_measure(broke) > 0.0, "the fixture was already dark")

	broke.spend_gold(5_000.0)
	Upkeep.settle(broke, context)
	assert_almost_eq(Education.of(broke, context), 0.0, 0.0001,
		"a library nobody is paying for went on teaching")


func test_it_survives_save_and_reload() -> void:
	var town := _town(&"ashmere", 4, ["theatre", "library"])
	Education.settle(town, _context([town]))
	assert_true(town.education > 0.0, "the fixture never learned anything")
	assert_almost_eq(Town.from_dict(town.to_dict()).education, town.education, 0.0001,
		"a reloaded town forgot everything it knew")


func test_it_says_so_when_it_moves() -> void:
	# Seam A: the sim emits, it does not merely mutate.
	var town := _town(&"ashmere", 4, ["theatre", "library"])
	var context := _context([town])
	Education.settle(town, context)

	var said: Array = context.log.of_type(Education.EVENT_MEASURED)
	assert_eq(said.size(), 1, "a town's education moved and nothing said so")
	assert_true(bool(said[0].payload["rising"]), "it reported a rise as a fall")


func test_it_says_nothing_when_it_does_not_move() -> void:
	var town := _town(&"ashmere", 4, ["theatre", "library"])
	var context := _context([town])
	Education.settle(town, context)
	Education.settle(town, context)
	assert_eq(context.log.of_type(Education.EVENT_MEASURED).size(), 1,
		"a town reported the same education twice")


func test_the_curriculum_seam_is_cut_and_open() -> void:
	# **Nothing writes it yet** (#173). Reading it now costs nothing and means the
	# Provost's knob is a data change rather than a change to this file.
	var town := _town()
	var context := _context([town])
	var before := Education.of(town, context)
	context.state.values[Education.CURRICULUM_KEY] = 2.0
	assert_true(Education.of(town, context) > before,
		"the curriculum has nowhere to press, so the Provost's knob will need this file")
