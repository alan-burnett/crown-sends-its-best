extends TestCase

## Where and which (#430, `docs/mechanics/governor-agendas.md` §5, §8, §9).
##
## The walk decides *that* a town improves its ground or builds a conversion;
## these ask whether it picks the tile and the building the doc says, and that
## the rules the doc locks — a farm only where food grew, no plantation on
## improve yield, no pasture without stock, no still without sugar, native land
## discounted — hold whatever the prices happen to be.

const SEED: int = 430

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


# --- Fixture ----------------------------------------------------------------

## Plains with forest to the east, wide enough for two alike tiles a village can
## tell apart.
func _map() -> WorldMap:
	var map := WorldMap.new(15, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 14):
			map.set_terrain(x, y, &"plains" if x <= 10 else &"forest")
	map.set_terrain(9, 2, &"desert")
	map.set_terrain(6, 6, &"grassland")
	return map


## Twenty-four thousand people reach three rings: x 5 to 11 around (8, 4).
func _town(intent: StringName) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(8, 4))
	town.workers = 24_000
	town.intent = intent
	town.receive_gold(5_000.0)
	return town


func _context(town: Town, natives: Tribes = null) -> ColonyContext:
	var map := _map()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	context.companies = Companies.new()
	context.natives = natives
	return context


## As though Work had harvested `gave` off each of these tiles last month.
func _worked(town: Town, gave: Dictionary) -> void:
	town.harvested_at = {}
	town.harvested = {}
	for at in gave:
		town.harvested_at["%d,%d" % [at.x, at.y]] = gave[at].duplicate()
		for resource in gave[at]:
			town.harvested[resource] = float(town.harvested.get(resource, 0.0)) + float(gave[at][resource])


## A small village on `at`: its own tile deep in their land, three tiles of
## margin around it.
func _village_at(at: Vector2i) -> Tribes:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = tribe.id
	village.at = at
	village.people = 300
	natives.villages.append(village)
	return natives


func _place(town: Town, intent: StringName, entry: Dictionary, context: ColonyContext) -> Dictionary:
	return SlotScorers.place(town, intent, entry, context)


# --- 🔒 A farm only where food grew (§5) --------------------------------------

func test_a_farm_goes_only_on_a_tile_that_harvested_food() -> void:
	# Two plains tiles alike. The north-western one was worked for timber, so
	# without the rule it would win the tie.
	var town := _town(GovernorIntent.GO_WIDE)
	var context := _context(town)
	var entry := {"objective": "improvement", "choose": "wide"}
	_worked(town, {Vector2i(6, 4): {"wood": 3.0}, Vector2i(7, 4): {"food": 3.0}})
	var farm := _place(town, GovernorIntent.GO_WIDE, entry, context)
	assert_eq(String(farm.get("id", "")), "farm")
	assert_eq(farm.get("target"), Vector2i(7, 4), "the farm went on a tile that grew no food")

	_worked(town, {Vector2i(6, 4): {"wood": 3.0}})
	assert_true(_place(town, GovernorIntent.GO_WIDE, entry, context).is_empty(),
		"a farm was placed where no tile grew any food")


func test_a_tile_nobody_worked_adds_nothing_whatever_is_built_on_it() -> void:
	var town := _town(GovernorIntent.GO_WIDE)
	var context := _context(town)
	_worked(town, {Vector2i(7, 4): {"food": 3.0}})
	var farm := Improvement.find(&"farm")
	assert_not_empty(SlotScorers.added_by(town, farm, Vector2i(7, 4), context))
	assert_empty(SlotScorers.added_by(town, farm, Vector2i(6, 4), context),
		"an idle field was counted as adding to this month's harvest")


# --- 🔒 Improve yield (§5) ------------------------------------------------------

func test_improve_yield_never_offers_a_plantation() -> void:
	# A plantation is get rich's own slot.
	for id in SlotScorers.IMPROVE_YIELD_IMPROVEMENTS:
		assert_false(String(id).begins_with("plantation"), "improve yield offers %s" % id)
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {Vector2i(6, 4): {"food": 3.0}, Vector2i(7, 4): {"food": 3.0}})
	var chosen := _place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context)
	assert_false(chosen.is_empty(), "nothing was worth doing, so this proves nothing")
	assert_false(String(chosen.get("id", "")).begins_with("plantation"))


func test_improve_yield_offers_a_pasture_only_to_a_town_with_stock_to_graze() -> void:
	# Nothing was harvested, so no farm, mine or yield building is worth anything
	# and the pasture stands or falls on the herd alone.
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {})
	town.add_livestock(&"sheep", 3_000)
	var fed := _place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context)
	assert_eq(String(fed.get("id", "")), "pasture",
		"a town feeding three thousand sheep on grain was offered no pasture")

	town.add_livestock(&"sheep", -3_000)
	assert_true(_place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context).is_empty(),
		"a town with nothing to graze was offered a pasture")


func test_a_pasture_goes_on_idle_ground_before_a_working_field() -> void:
	# §5: *yield lost* is what the tile gave, less what a pasture would. The
	# grassland carries the most head, so without that term it would win.
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {Vector2i(6, 6): {"food": 3.0}})
	town.add_livestock(&"sheep", 6_000)
	var fed := _place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context)
	assert_eq(String(fed.get("id", "")), "pasture")
	assert_ne(fed.get("target"), Vector2i(6, 6), "the sheep were put on the town's grain")


func test_a_town_cutting_timber_is_offered_a_sawmill() -> void:
	# A yield building is worth what its bonus would have added to this month's
	# harvest. Nothing else here gave anything a farm, mine or pasture could use.
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {Vector2i(11, 4): {"wood": 20.0}})
	assert_eq(String(_place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context).get("id", "")),
		"sawmill")


func test_improve_yield_stops_offering_improvements_at_one_per_thousand() -> void:
	var town := _town(GovernorIntent.GO_TALL)
	town.workers = 2_000
	var context := _context(town)
	_worked(town, {Vector2i(7, 4): {"food": 3.0}})
	assert_eq(String(_place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context).get("id", "")), "farm")
	context.map.build(8, 5, &"farm")
	context.map.build(9, 5, &"farm")
	assert_true(_place(town, GovernorIntent.GO_TALL, {"objective": "improve_yield"}, context).is_empty(),
		"a town of two thousand with two farms was offered a third")


func test_going_tall_looks_to_ore_where_no_tile_gains_food() -> void:
	# §8 *tall*: the largest gain in food, then ore. Desert, because a mine on
	# a mountain adds no ore to what the mountain already gives (reported on #430).
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {Vector2i(9, 2): {"ore": 1.0, "stone": 3.0}})
	var mine := _place(town, GovernorIntent.GO_TALL, {"objective": "improvement", "choose": "tall"}, context)
	assert_eq(String(mine.get("id", "")), "mine")
	assert_eq(mine.get("target"), Vector2i(9, 2))


# --- 🔒 Get rich (§9) --------------------------------------------------------------

func test_a_town_that_harvested_no_sugar_never_chooses_a_distillery() -> void:
	var town := _town(GovernorIntent.GET_RICH)
	var context := _context(town)
	var entry := {"objective": "trade_conversion", "choose": "worth", "input_at_least": 6}
	_worked(town, {Vector2i(7, 4): {"furs": 20.0}})
	assert_ne(String(_place(town, GovernorIntent.GET_RICH, entry, context).get("id", "")), "distillery",
		"a town that grew no sugar built a still")

	_worked(town, {Vector2i(7, 4): {"sugar": 20.0}})
	assert_eq(String(_place(town, GovernorIntent.GET_RICH, entry, context).get("id", "")), "distillery",
		"a town with twenty sugar and nothing else built no still")

	_worked(town, {Vector2i(7, 4): {"sugar": 5.0}})
	assert_ne(String(_place(town, GovernorIntent.GET_RICH, entry, context).get("id", "")), "distillery",
		"five sugar, short of the six the menu asks, built a still")


func test_a_get_rich_town_reaches_a_conversion_it_has_the_input_for() -> void:
	# #408's intent, rewritten against the menus (#429): the walk itself, not
	# the slot alone. No tile was worked, so the improvement slot above it has
	# nothing to place.
	var town := _town(GovernorIntent.GET_RICH)
	var context := _context(town)
	town.harvested = {"sugar": 20.0}
	town.harvested_at = {}
	var chosen := ObjectiveSelector.choose(town, GovernorIntent.GET_RICH, context)
	assert_eq(String(chosen["id"]), "distillery")


func test_raising_the_tax_on_a_crop_moves_the_next_plantation_off_it() -> void:
	# Other things equal. Whichever crop wins, taxing it at the whole of its
	# price moves the plantation to another.
	var town := _town(GovernorIntent.GET_RICH)
	var context := _context(town)
	var entry := {"objective": "improvement", "choose": "worth"}
	_worked(town, {Vector2i(6, 4): {"food": 3.0}, Vector2i(7, 4): {"food": 3.0}})
	var first := String(_place(town, GovernorIntent.GET_RICH, entry, context).get("id", ""))
	assert_true(first.begins_with("plantation_"), "the fixture's best worth is '%s', not a plantation" % first)

	var crop := StringName(first.trim_prefix("plantation_"))
	context.state.values[TaxRates.key_for(crop)] = TaxRates.MAX_RATE
	var second := String(_place(town, GovernorIntent.GET_RICH, entry, context).get("id", ""))
	assert_ne(second, first, "%s taxed at the whole of its price was still the crop planted" % crop)


# --- 🔒 Native land (§8, #422) ---------------------------------------------------

func test_a_go_tall_town_keeps_off_native_land_while_an_equal_tile_outside_qualifies() -> void:
	var town := _town(GovernorIntent.GO_TALL)
	var entry := {"objective": "improvement", "choose": "tall"}
	_worked(town, {Vector2i(6, 4): {"food": 3.0}, Vector2i(10, 4): {"food": 3.0}})
	var open := _place(town, GovernorIntent.GO_TALL, entry, _context(town))
	assert_eq(open.get("target"), Vector2i(6, 4),
		"with nobody living there the north-western tile does not win, so this compares nothing")

	var natives := _village_at(Vector2i(5, 4))
	assert_true(Intrusion.depth_at(Vector2i(6, 4), natives) > 0.5, "the fixture's village does not reach the tile")
	assert_almost_eq(Intrusion.depth_at(Vector2i(10, 4), natives), 0.0, 0.0001)
	var settled := _place(town, GovernorIntent.GO_TALL, entry, _context(town, natives))
	assert_eq(settled.get("target"), Vector2i(10, 4),
		"a go-tall town farmed their land with an equal field outside it")


func test_every_intent_that_improves_reads_its_own_aversion() -> void:
	assert_almost_eq(AgendaMenu.aversion_of(GovernorIntent.GO_TALL), 1.0, 0.0001)
	assert_true(AgendaMenu.aversion_of(GovernorIntent.GET_RICH) < AgendaMenu.aversion_of(GovernorIntent.GO_TALL))
	assert_almost_eq(AgendaMenu.aversion_of(GovernorIntent.MILITARY), 0.0, 0.0001,
		"a military town minded whose ground its fort stands on")


# --- Military (§8) ------------------------------------------------------------------

func test_a_fort_faces_the_nearest_threat_and_goes_nowhere_without_one() -> void:
	var town := _town(GovernorIntent.MILITARY)
	var context := _context(town)
	var entry := {"objective": "improvement", "choose": "military"}
	assert_true(_place(town, GovernorIntent.MILITARY, entry, context).is_empty(),
		"a fort was sited with nothing to face")

	# The colony's own men to the west are nobody to build a wall against.
	context.companies.raise_company(Company.COLONIAL, 500, {}, town.id, Vector2i(5, 4), context)
	assert_true(_place(town, GovernorIntent.MILITARY, entry, context).is_empty(),
		"a fort was sited against the town's own militia")
	context.companies.raise_company(Company.NATIVE, 500, {}, &"", Vector2i(13, 4), context)
	var fort := _place(town, GovernorIntent.MILITARY, entry, context)
	assert_eq(String(fort.get("id", "")), "fort")
	assert_eq(fort.get("target"), Vector2i(11, 4), "the fort does not face the war party")


# --- 🔒 Deterministic ------------------------------------------------------------------

func test_choosing_draws_no_randomness_and_answers_the_same_twice() -> void:
	var town := _town(GovernorIntent.GO_TALL)
	var context := _context(town)
	_worked(town, {Vector2i(6, 4): {"food": 3.0}, Vector2i(7, 4): {"food": 3.0}, Vector2i(9, 2): {"ore": 2.0}})
	town.add_livestock(&"sheep", 3_000)
	var before := Canonical.hash_of(context.streams.to_dict())
	for entry in [
		{"objective": "improve_yield"},
		{"objective": "improvement", "choose": "tall"},
		{"objective": "improvement", "choose": "wide"},
	]:
		var first := _place(town, GovernorIntent.GO_TALL, entry, context)
		var again := _place(town, GovernorIntent.GO_TALL, entry, context)
		assert_eq(String(first.get("id", "")), String(again.get("id", "")))
		assert_eq(first.get("target"), again.get("target"))
	assert_eq(Canonical.hash_of(context.streams.to_dict()), before, "a scorer drew from an RNG stream")
