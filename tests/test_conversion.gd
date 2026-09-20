extends TestCase

## Conversion of raw resources into processed ones (#64), SPEC §11.3 step 1.
##
## Seven of the nineteen resources could not come into existence before this, and
## one of them — **clothing** — is a need. A town with no gold could not clothe
## itself at all.
##
## ## A note on the fixtures
##
## Every town here is **fed and clothed unless the test is about going without**.
## A town short of food weights fishing above every forge on the board, which is
## correct and makes the phase look broken when it is merely being sensible. The
## first draft of these tests starved their towns and spent an hour proving that
## hungry people fish.

const SEED: int = 1649

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


# --- Fixtures ---------------------------------------------------------------

## A town on a spit of land in open water.
##
## **Deliberately barren**, so the choice is between a loom and what little the
## sea gives. Good ground beats every forge on the board, which is realistic and
## useless for testing whether a forge works at all.
func _barren() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	map.set_terrain(3, 3, &"desert")
	return map


## Ground worth working, for the tests about what a town chooses.
func _land() -> WorldMap:
	var map := WorldMap.new(7, 7, &"ocean")
	for y in range(2, 5):
		for x in range(2, 5):
			map.set_terrain(x, y, &"desert")
	return map


## Fed, clothed, and holding whatever the test puts in its hands.
func _town(stock: Dictionary = {}, workers: int = 4) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	town.store(&"food", 500.0)
	town.store(&"clothing", 200.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


## A town with nothing in the larder. Used only where that is the point.
func _destitute(stock: Dictionary = {}, workers: int = 4) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = workers
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _harness(town: Town, map: WorldMap = null) -> Dictionary:
	var ground := map if map != null else _barren()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), ground
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(ground, colony.in_order())

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


func _worked(harness: Dictionary) -> Dictionary:
	var events: Array = harness["context"].log.of_type(WorkPhase.EVENT_WORKED)
	return events[events.size() - 1].payload


# --- All six conversions ----------------------------------------------------

func test_every_conversion_the_spec_names_exists() -> void:
	# SPEC §10.1: ore to iron, furs or cotton to clothing, iron to tools and
	# guns, food to beer, sugar to rum, tobacco to cigars.
	var expected: Array = [
		["iron", "ore"], ["clothing", "furs"], ["clothing", "cotton"],
		["tools", "iron"], ["guns", "iron"],
		["beer", "food"], ["rum", "sugar"], ["cigars", "tobacco"],
	]
	var found: Dictionary = {}
	for recipe in Conversion.all():
		found[String(recipe.id())] = recipe

	for pair in expected:
		var id := "%s<-%s" % [pair[0], pair[1]]
		assert_has(found, id, "no recipe turns %s into %s" % [pair[1], pair[0]])
		if ResourceCatalogue.requires_building(StringName(pair[0])):
			# A gated recipe has no base terms on purpose (#150) — that absence
			# *is* the gate. What must be true is that something can perform it.
			assert_true(not Building.would_allow(StringName(id)).is_empty(),
				"%s is gated and no building in the tree can perform it" % id)
			continue
		assert_true(found[id].made > 0.0, "%s makes nothing" % id)
		assert_true(found[id].consumed > 0.0, "%s uses nothing up" % id)


func test_every_conversion_actually_produces_its_output() -> void:
	# Six workers on barren ground, with a heap of the input **and nothing of the
	# output**. If a recipe cannot happen here it cannot happen anywhere.
	#
	# Clearing the output is not the fixture being obliging. Since #135 a town
	# scores work at what it thinks the resources are worth, and a town holding a
	# year of cloth thinks cloth is worth very little — so it brews beer instead,
	# correctly. Leaving the standard 200 clothing in would have this test ask
	# whether a sated town bothers, which is a question about appetite rather than
	# about whether the recipe exists.
	for recipe in Conversion.all():
		var town := _town({String(recipe.input): 500.0}, 6)
		town.take(recipe.output, town.held(recipe.output))
		# A gated recipe needs whatever lets it happen at all (#150).
		for enabling in Building.would_allow(recipe.id()):
			town.add_building(StringName(enabling))
		var before := town.held(recipe.output)
		_run_month(_harness(town))
		assert_true(town.held(recipe.output) > before,
			"six workers with five hundred %s made no %s" % [recipe.input, recipe.output])


func test_a_conversion_consumes_its_input() -> void:
	var town := _town({"ore": 500.0}, 6)
	_run_month(_harness(town))
	assert_true(town.held(&"ore") < 500.0, "iron was smelted out of nothing")


func test_clothing_can_be_woven_from_either_furs_or_cotton() -> void:
	# The two-input case. Whichever the town actually has will do.
	for source in ["furs", "cotton"]:
		var town := _town({source: 500.0}, 6)
		town.take(&"clothing", town.held(&"clothing"))
		_run_month(_harness(town))
		assert_true(town.held(&"clothing") > 0.0, "a town with %s wove nothing" % source)


# --- 🔒 A worker is in the fields or in the town, never both ---------------

func test_hands_are_split_and_never_exceed_the_population() -> void:
	for workers in [1, 3, 7]:
		var town := _town({"ore": 500.0, "furs": 500.0, "sugar": 500.0}, workers)
		var harness := _harness(town)
		_run_month(harness)
		var payload := _worked(harness)
		assert_true(int(payload["tiles_worked"]) + int(payload["converting"]) <= workers,
			"%d workers did %d tiles and %d conversions" % [
				workers, payload["tiles_worked"], payload["converting"]])


func test_converting_costs_a_worked_tile() -> void:
	# Two identical towns and the same number of hands. The one with ore to smelt
	# works **fewer tiles**, because the smelters came off the land.
	var plain := _town({}, 4)
	var forge := _town({"ore": 500.0}, 4)
	var one := _harness(plain)
	var other := _harness(forge)
	_run_month(one)
	_run_month(other)

	assert_true(int(_worked(other)["converting"]) > int(_worked(one)["converting"]),
		"the town with ore put no more hands to the forge")
	assert_true(int(_worked(other)["tiles_worked"]) < int(_worked(one)["tiles_worked"]),
		"the smelters were conjured out of nowhere rather than taken off the land")


# --- 🔒 The start-of-month stockpile ----------------------------------------

func test_conversion_draws_on_the_start_of_month_stockpile() -> void:
	# SPEC §11.3 step 1. **Ore bought from the Crown this month is smelted next
	# month**, so Exchange cannot be used as a same-month forge.
	#
	# The phase is run against a deliberately stale snapshot, which is exactly
	# the situation a mid-month purchase creates.
	var town := _town({"ore": 3.0}, 6)
	var harness := _harness(town)
	var before := ColonySnapshot.of(harness["colony"])

	# The ship docks. The snapshot does not know.
	town.store(&"ore", 500.0)
	WorkPhase.new().run(town, before, harness["context"])

	var smelted := town.held(&"iron")
	assert_true(smelted > 0.0, "the three ore it did have were never smelted")
	assert_true(smelted <= 3.0 / ResourceCatalogue.input_per_unit_of(&"iron") + 0.0001,
		"it made %f of iron, which is more than three of ore can yield" % smelted)
	assert_true(town.held(&"ore") > 490.0, "the new ore went into the furnace the day it landed")


func test_two_recipes_cannot_spend_the_same_stock_twice() -> void:
	# Tools and guns are both made of iron. Between them they may use what is
	# there and no more.
	var town := _town({"iron": 3.0}, 6)
	_run_month(_harness(town))

	assert_true(town.held(&"iron") >= -0.0001,
		"the town forged iron it did not have: %f left" % town.held(&"iron"))
	assert_true(town.held(&"tools") + town.held(&"guns") > 0.0, "nothing was forged at all")


# --- 🔒 The food-and-clothing lockstep --------------------------------------

func test_a_town_with_furs_and_hands_clothes_itself() -> void:
	# **The acceptance criterion this ticket exists for.** No gold, no Crown, no
	# Exchange phase — just furs and people.
	var town := _destitute({"furs": 100.0, "food": 500.0}, 4)
	var harness := _harness(town)
	_run_month(harness)

	assert_true(town.held(&"clothing") > 0.0, "a town with furs and spare hands stayed naked")
	assert_not_empty(harness["context"].log.of_type(WorkPhase.EVENT_CONVERTED))


func test_a_cold_town_leaves_good_ground_to_weave() -> void:
	# Clothing is not a tile yield, so before this the survival check could only
	# ever act on food and the lockstep was half a rule.
	#
	# One worker, ground worth working, and furs in the store. The cold town goes
	# to the loom and the clothed one goes to the fields.
	var cold := _destitute({"furs": 100.0, "food": 500.0}, 1)
	var clothed := _destitute({"furs": 100.0, "food": 500.0, "clothing": 200.0}, 1)
	var one := _harness(cold, _land())
	var other := _harness(clothed, _land())
	_run_month(one)
	_run_month(other)

	assert_true(cold.held(&"clothing") > 0.0, "a cold town with furs worked the fields")
	assert_eq(int(_worked(one)["converting"]), 1, "a cold town with furs worked the fields")

	# **Asked of the cloth, not of the hands.** The clothed town has 500 of grain
	# it will never eat and no rum in the cellar, so it brews — which is a hand
	# converting, and the right one. What this test is about is that it does not
	# put that hand on the loom.
	assert_almost_eq(clothed.held(&"clothing"), 200.0, 0.0001,
		"a well-clothed town wove anyway")


func test_a_hungry_town_does_not_brew_its_grain() -> void:
	# The recipe subtracts what it consumes, so this falls out of the scoring
	# rather than out of a rule about beer.
	var hungry := _destitute({"food": 2.0}, 4)
	_run_month(_harness(hungry))
	assert_almost_eq(hungry.held(&"beer"), 0.0, 0.0001,
		"a town with two days of grain turned it into drink")


func test_a_town_swimming_in_grain_brews() -> void:
	var fed := _town({}, 4)
	_run_month(_harness(fed))
	assert_true(fed.held(&"beer") > 0.0, "a town with five hundred of grain brewed nothing")


# --- Making against buying --------------------------------------------------

func test_a_town_with_sugar_makes_rum_and_one_without_cannot() -> void:
	var planter := _town({"sugar": 200.0}, 6)
	var without := _town({}, 6)
	_run_month(_harness(planter))
	_run_month(_harness(without))

	assert_true(planter.held(&"rum") > 0.0, "a town with sugar distilled nothing")
	assert_almost_eq(without.held(&"rum"), 0.0, 0.0001,
		"a town with no sugar produced rum from somewhere")


# --- Experts and buildings (SPEC §12.2) -------------------------------------

func test_experts_multiply_processed_yields_too() -> void:
	# "Each expert increases all of a town's yield of that particular resource,
	# **including processed resources**."
	var plain := _town({"ore": 500.0}, 6)
	var skilled := _town({"ore": 500.0}, 6)
	skilled.add_experts(&"iron", 2)

	_run_month(_harness(plain))
	_run_month(_harness(skilled))

	assert_true(skilled.held(&"iron") > plain.held(&"iron"),
		"two ironmasters smelted no more than nobody: %f against %f" % [
			skilled.held(&"iron"), plain.held(&"iron")])


func test_a_building_that_helps_a_conversion_helps_it() -> void:
	var plain := _town({"ore": 500.0}, 6)
	var equipped := _town({"ore": 500.0}, 6)
	equipped.add_building(&"smithy")  # a yield bonus on iron

	_run_month(_harness(plain))
	_run_month(_harness(equipped))

	assert_true(equipped.held(&"iron") > plain.held(&"iron"), "the smithy smelted no better")


# --- Determinism ------------------------------------------------------------

func test_the_labour_split_is_deterministic() -> void:
	var first: String = ""
	for _attempt in 4:
		var town := _town({"ore": 60.0, "furs": 60.0, "sugar": 60.0}, 5)
		_run_month(_harness(town))
		var shape := Canonical.hash_of(town.stockpile)
		if first.is_empty():
			first = shape
		assert_eq(shape, first, "the same town worked a different month the second time")


func test_recipes_come_back_in_a_stable_order() -> void:
	var ids: PackedStringArray = PackedStringArray()
	for recipe in Conversion.all():
		ids.append(String(recipe.id()))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(Array(ids), Array(sorted), "recipes came back in an unstable order")


# --- 🔒 A building defines a conversion; it does not multiply one (#152) ----

## The eight the town hall is responsible for.
func _base_terms() -> Dictionary:
	var hall := Building.find(Building.BASE)
	assert_true(hall != null, "no town hall in the building data")
	return hall.effect("conversions", {})


func test_every_town_has_a_town_hall_from_the_moment_it_is_founded() -> void:
	# Not built, not chosen, not optional. A town without one could convert
	# nothing at all, because there would be nothing to say on what terms.
	var fresh := Town.new(&"newfoundland", "Newfoundland", Vector2i(1, 1))
	assert_true(fresh.buildings.has(String(Building.BASE)),
		"a town was founded without a town hall")


func test_the_town_hall_defines_every_conversion_there_is() -> void:
	# **The base case must not be a special case.** If a recipe existed that no
	# building spoke for, code would need a fallback, and the uniform rule — the
	# best building the town has for a conversion sets its terms — would stop
	# being uniform.
	var terms := _base_terms()
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if ResourceCatalogue.requires_building(recipe.output):
			# **Gated, and the gate is this absence** (#150). The flag on the
			# resource is what says the omission is deliberate rather than a line
			# somebody dropped.
			assert_true(not terms.has(String(recipe.id())),
				"%s is gated but the town hall defines it, so every town can make it"
					% recipe.id())
			continue
		assert_has(terms, String(recipe.id()),
			"no building defines terms for %s, so the base case is a branch in code" % recipe.id())


func test_ratio_and_throughput_are_both_the_buildings_to_set() -> void:
	# The two dials, and the reason there are two: efficiency and volume are
	# different things and a single bonus could only move them together.
	var terms := _base_terms()
	for id in terms:
		var entry: Dictionary = terms[id]
		assert_true(float(entry.get("ratio", 0.0)) > 0.0, "%s has no ratio" % id)
		assert_true(float(entry.get("throughput", 0.0)) > 0.0, "%s has no throughput" % id)


func test_a_better_building_supersedes_the_hall_for_that_one_conversion() -> void:
	# **And leaves the rest alone.** A smithy is shipped more ore than a village
	# blacksmith and wastes less of it; it has nothing to say about brewing.
	var plain := _town({"ore": 500.0, "food": 500.0}, 6)
	var smithing := _town({"ore": 500.0, "food": 500.0}, 6)
	smithing.add_building(&"smithy")

	for entry in Conversion.all():
		var recipe: Conversion = entry
		var mine: float = recipe.made_by(plain)
		var theirs: float = recipe.made_by(smithing)
		var takes: float = recipe.consumes_for(plain)
		var takes_more: float = recipe.consumes_for(smithing)
		if String(recipe.id()) == "iron<-ore" or String(recipe.id()) == "tools<-iron":
			assert_true(theirs > mine, "the smithy did not improve %s" % recipe.id())
			assert_true(takes_more > takes,
				"the smithy improved %s without putting more through, so there is one dial again"
					% recipe.id())
		else:
			assert_almost_eq(theirs, mine, 0.0001,
				"the smithy changed %s, which is none of its business" % recipe.id())


func test_no_building_raises_a_processed_resource_with_a_yield_bonus() -> void:
	# 🔒 **The thing #152 replaces, asserted where it can actually be broken.**
	# A bonus raises output while input stays fixed, so the ratio improves as a
	# side effect of throughput and neither can be authored on its own. The smithy
	# and the armoury both carried one; they carry conversion terms now.
	#
	# Asked of the data rather than of a fixture, because a fixture can only test
	# the buildings that exist today and the rule is about the ones that do not
	# yet. Tile yields are a separate question and `yield_bonus` is still theirs.
	var processed := ResourceCatalogue.processed()
	for id in Building.ids():
		var building := Building.find(StringName(id))
		var bonuses: Dictionary = building.effect("yield_bonus", {})
		for resource in bonuses:
			assert_true(not processed.has(String(resource)),
				"%s raises %s with a yield bonus, and %s is made by conversion" % [
					id, resource, resource])


# --- 🔒 Nothing is gated, except guns (#150) --------------------------------

func test_a_town_without_a_gunsmith_cannot_make_guns_at_any_rate() -> void:
	# **Not "makes fewer" — cannot.** Guns arm the militia and SPEC §10.1 makes
	# them what the natives covet most, so a colony that could arm itself without
	# investing in the means to would have skipped a decision that ought to cost
	# something.
	var plain := _town({"iron": 500.0}, 6)
	_run_month(_harness(plain))
	assert_almost_eq(plain.held(&"guns"), 0.0, 0.0001,
		"a town with no gunsmith forged muskets out of nothing but iron")


func test_and_a_town_with_one_can() -> void:
	# The other half, or the test above passes on a town that could not make guns
	# for some entirely different reason.
	var armed := _town({"iron": 500.0}, 6)
	for enabling in Building.would_allow(&"guns<-iron"):
		armed.add_building(StringName(enabling))
	_run_month(_harness(armed))
	assert_true(armed.held(&"guns") > 0.0,
		"a town with a gunsmith and five hundred iron forged nothing")


func test_no_other_conversion_is_gated() -> void:
	# 🔒 A town with no smithy still forges tools. The exception is one recipe,
	# and the data says which.
	var bare := _town({}, 6)
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if ResourceCatalogue.requires_building(recipe.output):
			continue
		assert_true(recipe.available_to(bare),
			"%s needs a building, and only guns are supposed to" % recipe.id())


func test_only_one_resource_is_gated_at_all() -> void:
	# The Author settled on exactly one. A second would be a design decision
	# rather than a data edit, so it should be noticed.
	var gated: PackedStringArray = PackedStringArray()
	for id in ResourceCatalogue.ids():
		if ResourceCatalogue.requires_building(StringName(id)):
			gated.append(id)
	assert_eq(",".join(gated), "guns",
		"the gated resources are now %s, which is a decision rather than a data edit" % gated)


func test_every_conversion_has_a_building_that_improves_it() -> void:
	# Each recipe gets a building that improves **the ratio and the rate**. A
	# recipe nothing can ever improve is a dead end in the tree — the town would
	# make it at the same terms forever, whatever it built.
	for entry in Conversion.all():
		var recipe: Conversion = entry
		var better := false
		for id in Building.ids():
			if id == String(Building.BASE):
				continue
			var building := Building.find(StringName(id))
			var terms: Dictionary = building.conversion_terms(recipe.id())
			if terms.is_empty():
				continue
			var equipped := _town({}, 6)
			equipped.add_building(StringName(id))
			if recipe.made_by(equipped) > recipe.made_by(_town({}, 6)) \
					and recipe.consumes_for(equipped) >= recipe.consumes_for(_town({}, 6)):
				better = true
		assert_true(better, "nothing in the building tree improves %s" % recipe.id())


func test_a_town_that_cannot_make_guns_says_so() -> void:
	# **Seam A.** A town sitting on iron it cannot forge is the whole cost of the
	# gate, and a sim that merely declined to convert would leave the map showing
	# idle hands with nothing able to say why.
	var plain := _town({"iron": 500.0}, 6)
	var harness := _harness(plain)
	_run_month(harness)

	var context: ColonyContext = harness["context"]
	var said := context.log.of_type(WorkPhase.EVENT_CANNOT_CONVERT)
	assert_true(said.size() > 0, "a town holding five hundred iron and no gunsmith said nothing")
	assert_eq(String(said[0].payload["output"]), "guns")
	assert_true(not PackedStringArray(said[0].payload["needs"]).is_empty(),
		"it said it could not, without saying what would let it")


func test_a_town_with_a_gunsmith_says_nothing_of_the_kind() -> void:
	var armed := _town({"iron": 500.0}, 6)
	for enabling in Building.would_allow(&"guns<-iron"):
		armed.add_building(StringName(enabling))
	var harness := _harness(armed)
	_run_month(harness)
	assert_eq(harness["context"].log.of_type(WorkPhase.EVENT_CANNOT_CONVERT).size(), 0,
		"a town that can forge muskets complained that it could not")


func test_a_town_with_no_iron_is_not_being_denied_anything() -> void:
	var empty := _town({}, 6)
	var harness := _harness(empty)
	_run_month(harness)
	assert_eq(harness["context"].log.of_type(WorkPhase.EVENT_CANNOT_CONVERT).size(), 0,
		"a town with no iron at all was told it could not forge muskets")
