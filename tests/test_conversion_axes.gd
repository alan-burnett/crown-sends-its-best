extends TestCase

## What a conversion building is worth to a governor (#311,
## `docs/mechanics/buildings.md` §6).
##
## 🔒 **A governor could not want a foundry.** `_building_axes` read thirteen
## effect keys and not `conversions`, so a foundry — which halves the ore-to-iron
## ratio and doubles throughput — reached him only through its `reserve_months`.
## He could want it as a shed that holds two months of ore. He could not want it
## as a foundry. Over three seeds and five years a town raised thirteen buildings
## and not one of the nine that convert anything.
##
## 🔒 **The axis follows the output, and the output already knows what it is.**
## Nothing in the scoring names a resource.
##
## 🔒 **And this is the third time**, after amusement and per-resource reserves.
## The last test in this file is the one that makes the fourth a failing test
## rather than a five-year harness run.

var _content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	_content = ContentDatabase.new()
	_content.load_all("en")
	M1Registrations.load_resources(_content)


func after_each() -> void:
	reset_world()
	_content.free()


## Every building that improves a conversion, found rather than listed.
func _conversion_buildings() -> Array:
	var out: Array = []
	for id in Building.ids():
		var building := Building.find(StringName(id))
		if building == null:
			continue
		for recipe in building.effect("conversions", {}):
			var terms := building.conversion_terms(StringName(recipe))
			if terms.is_empty():
				continue
			# The town hall sets the base terms for everything ungated, so it is
			# not an improvement on anything.
			if not is_equal_approx(
					float(terms["ratio"]), Building.base_ratio_for(StringName(recipe))):
				out.append(StringName(id))
				break
	return out


func _worth_to(id: StringName, intent: StringName) -> float:
	var axes := ObjectiveSelector.building_axes(id)
	var total := 0.0
	for axis in GovernorIntent.AXES:
		total += float(axes.get(axis, 0.0)) * GovernorIntent.value_of(intent, axis)
	return total


# --- 🔒 A governor can want a foundry ---------------------------------------

func test_the_corpus_actually_has_conversion_buildings_to_score() -> void:
	# Named as a test so the ones below cannot pass by finding nothing.
	assert_true(_conversion_buildings().size() >= 8,
		"there are too few conversion buildings for this file to mean anything: %s"
			% [_conversion_buildings()])


func test_every_conversion_building_is_worth_something() -> void:
	for id in _conversion_buildings():
		var axes := ObjectiveSelector.building_axes(id)
		var most := 0.0
		for axis in GovernorIntent.AXES:
			most = maxf(most, absf(float(axes.get(axis, 0.0))))
		assert_true(most > 0.0,
			"%s is worth nothing on any axis, so no governor can ever choose it" % id)


func test_a_foundry_is_worth_more_than_a_shed_that_holds_two_months_of_ore() -> void:
	# The bug, stated as a test. Before this the foundry reached a governor only
	# through its `reserve_months`, which the granary has more of.
	var foundry := ObjectiveSelector.building_axes(&"foundry")
	var granary := ObjectiveSelector.building_axes(&"granary")
	assert_true(float(foundry.get("capacity", 0.0)) > float(granary.get("capacity", 0.0)),
		"a foundry is worth no more to a governor than a granary: %s against %s"
			% [foundry, granary])
	assert_true(float(foundry.get("trade", 0.0)) > 0.0,
		"a foundry produces nothing sellable, which is what a foundry is for")


func test_a_governor_after_profit_prefers_the_chain_to_the_mine_alone() -> void:
	# §5 claims the mineworks → foundry → toolworks chain pays for itself in
	# construction. A governor can only act on that if the chain outscores the
	# first link.
	var mine := _worth_to(&"mineworks", GovernorIntent.GET_RICH)
	for id in [&"foundry", &"toolworks"]:
		assert_true(_worth_to(id, GovernorIntent.GET_RICH) > mine,
			"%s is worth less to a governor after profit than the mine feeding it"
				% id)


# --- 🔒 The axis follows the output ------------------------------------------

func test_an_output_that_feeds_construction_reads_as_capacity() -> void:
	# 🔒 **Derived, never asserted.** A toolworks reads as capacity because tools
	# appear in the cost of half the tree, which the scoring asks the tree — so a
	# building priced in a new resource tomorrow makes that resource capacity
	# without anybody editing the selector.
	# A toolworks and a brewhouse are the same building twice over: both hold two
	# months of their input and both halve a 2:1 conversion. The only difference
	# is that tools appear in the cost of half the tree and **beer appears in
	# nothing**, so the whole of the gap between them is this rule.
	var toolworks := ObjectiveSelector.building_axes(&"toolworks")
	var brewhouse := ObjectiveSelector.building_axes(&"brewhouse")
	assert_true(float(toolworks.get("capacity", 0.0)) > float(brewhouse.get("capacity", 0.0)),
		"a toolworks is no more capacity than a brewhouse, so nothing reads the costs: "
			+ "%s against %s" % [toolworks, brewhouse])

	# And the brewhouse's capacity is its store and nothing else — the conversion
	# adds none, because beer builds nothing.
	assert_true(float(brewhouse.get("trade", 0.0)) > 0.0,
		"the fixture's brewhouse improves no conversion at all")


func test_a_luxury_reads_as_comfort_and_a_staple_does_not() -> void:
	assert_true(ResourceCatalogue.is_luxury(&"rum"), "the fixture is wrong about rum")
	assert_false(ResourceCatalogue.is_luxury(&"iron"), "the fixture is wrong about iron")

	assert_true(float(ObjectiveSelector.building_axes(&"distillery").get("comfort", 0.0)) > 0.0,
		"a distillery is no comfort to anybody, though the town drinks what it makes")
	assert_eq(float(ObjectiveSelector.building_axes(&"foundry").get("comfort", 0.0)), 0.0,
		"iron is a comfort, which would make every axis every axis")


func test_one_building_can_score_on_more_than_one_axis() -> void:
	# §6: *rum is a luxury and a cash crop, and a distillery should be wanted for
	# both reasons by governors who want different things.*
	var distillery := ObjectiveSelector.building_axes(&"distillery")
	assert_true(float(distillery.get("trade", 0.0)) > 0.0, "rum is not sellable")
	assert_true(float(distillery.get("comfort", 0.0)) > 0.0, "rum is no comfort")
	assert_true(_worth_to(&"distillery", GovernorIntent.GET_RICH)
			!= _worth_to(&"distillery", GovernorIntent.GO_TALL),
		"two governors who want different things want a distillery equally")


func test_the_worse_the_conversion_the_more_the_building_is_worth() -> void:
	# §6: *the worst conversions improve most.* Ore to iron quadruples its output;
	# the 3:1 chains merely triple theirs. It falls out of the rule rather than
	# being designed, and it is the right shape — the expensive chains are the ones
	# worth investing in.
	var foundry := ObjectiveSelector.building_axes(&"foundry")
	var toolworks := ObjectiveSelector.building_axes(&"toolworks")
	assert_true(float(foundry.get("capacity", 0.0)) > float(toolworks.get("capacity", 0.0)),
		"improving a 10:1 conversion bought no more than improving a 3:1 one")


func test_the_base_terms_are_not_an_improvement_on_themselves() -> void:
	# The town hall performs every ungated conversion at the worst terms in the
	# tree, which is the definition of the base. It must not therefore read as
	# nine conversion buildings in one.
	var hall := ObjectiveSelector.building_axes(&"town_hall")
	assert_eq(float(hall.get("trade", 0.0)), 0.0,
		"the town hall scores as though it improved every conversion in the game")

	# And it is not scored **at all** on the axes a conversion touches, rather
	# than scored and reading zero. A building that improves nothing has nothing
	# to say about trade, and saying it quietly is a different claim from not
	# saying it — which is what stops a governor's trace listing seven conversions
	# the town hall did not improve.
	# `trade` is the axis to ask, because it is the one only a conversion or a
	# yield bonus ever sets — `comfort`, `capacity` and `defence` are written for
	# every building whether or not it has anything to say on them.
	assert_false(hall.has("trade"),
		"the town hall carries a trade axis for conversions it merely performs")


# --- 🔒 The fourth time is a failing test ------------------------------------

func test_no_building_effect_goes_unread() -> void:
	# 🔒 **An effect `_building_axes` is not told about is an effect no governor
	# can pursue, and nothing fails when it happens.** Three times now: amusement,
	# per-resource reserves, and conversions. Each was found by a five-year
	# harness run; this is what makes the fourth cost a test run instead.
	var used: Dictionary = {}
	for id in Building.ids():
		var building := Building.find(StringName(id))
		if building == null:
			continue
		for key in building.effects:
			used[String(key)] = true

	var unread: PackedStringArray = PackedStringArray()
	for key in used:
		if not ObjectiveSelector.EFFECTS_READ.has(String(key)):
			unread.append(String(key))
	unread.sort()
	assert_empty(unread, (
		"the building data uses effects the governor's scoring has never heard "
		+ "of, so no governor can pursue them: %s"
	) % ", ".join(unread))
	assert_false(used.is_empty(), "no building has any effects, so this checked nothing")
