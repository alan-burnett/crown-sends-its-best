extends TestCase

## What a thing is worth, to whom (#136, `docs/mechanics/town-economy.md` §1).
##
## 🔒 **The value is in the making, not the material.** A thing is valuable to
## the natives when making it requires a craft they cannot do, and worthless when
## it does not. Cigars and rum are both made from what the land gives, but rum
## needs a still and a cigar needs a pair of hands — only one of those is a craft
## they lack. Iron at nothing and tools at everything says the same thing from
## the other end.
##
## The native table is **authored now and inert until M5**. Cutting the hole in
## the right shape is the point, so these tests exist before anything trades
## through it.

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


# --- 🔒 The craft rule ------------------------------------------------------

func test_iron_is_worth_nothing_to_them() -> void:
	# They cannot work it. Not "little" — nothing.
	assert_almost_eq(Valuation.natives(&"iron"), 0.0, 0.0001,
		"a tribe that cannot work iron offered something for it")


func test_what_they_cannot_make_at_all_is_worth_a_great_deal() -> void:
	for id in ["tools", "guns", "horses"]:
		assert_true(Valuation.natives(StringName(id)) > Valuation.crown(StringName(id)),
			"%s was worth no more to a tribe than to the Crown" % id)


func test_the_fruits_of_the_land_are_worth_little() -> void:
	# They are not short of land or its fruits.
	for id in ["food", "wood", "stone", "furs", "cotton", "sugar", "tobacco"]:
		assert_true(Valuation.natives(StringName(id)) < Valuation.crown(StringName(id)),
			"%s was worth more to a tribe than to the Crown, which has to buy it" % id)


func test_a_rolled_leaf_and_a_dried_leaf_are_still_leaves() -> void:
	# **The rule doing its job.** Cigars need a pair of hands, rum needs a still.
	# Tobacco and cigars sit together; rum stands apart from sugar.
	var tobacco := ResourceCatalogue.native_worth(&"tobacco")
	var cigars := ResourceCatalogue.native_worth(&"cigars")
	var sugar := ResourceCatalogue.native_worth(&"sugar")
	var rum := ResourceCatalogue.native_worth(&"rum")

	assert_true(absf(cigars - tobacco) < 0.4,
		"rolling a leaf was treated as a craft they lack")
	assert_true(rum > sugar * 2.0,
		"distilling was treated as no more of a craft than growing the cane")


func test_every_resource_has_been_valued() -> void:
	# A resource added without a native worth would silently be worth nothing to
	# them, which is the *answer for iron* and would be a bug for anything else.
	for id in ResourceCatalogue.ids():
		if String(id) == "iron":
			continue
		assert_true(ResourceCatalogue.native_worth(StringName(id)) > 0.0,
			"%s has no native valuation, so a tribe would give nothing for it" % id)


# --- 🔒 Their valuations can move -------------------------------------------

func test_a_tribe_at_war_can_want_guns_more() -> void:
	# **Not a fixed table with a hostility gate bolted on** — the valuations
	# themselves move (§12.5). Nothing drives this yet; the shape has to support
	# it before M5 rather than after.
	var at_peace := Valuation.natives(&"guns")
	var at_war := Valuation.natives(&"guns", {"guns": 2.5})
	assert_true(at_war > at_peace,
		"a tribe at war wanted guns no more than one at peace")


func test_an_appetite_it_does_not_name_changes_nothing() -> void:
	var quiet := Valuation.natives(&"tools")
	var elsewhere := Valuation.natives(&"tools", {"guns": 3.0})
	assert_almost_eq(elsewhere, quiet, 0.0001,
		"wanting guns changed what a tribe would give for tools")


# --- 🔒 The Crown's can move too --------------------------------------------

func test_the_crowns_valuation_is_a_function_of_the_world() -> void:
	# A constant is a function with no inputs. This one has inputs now (#141): the
	# Crown's war, and a shortage at home. **When it moves it is news the Steward
	# can write about**, which is what the shape was reserved for.
	#
	# A colony begins with a war already running, so the authored price and the
	# quoted price differ from the first month of every run — and a resource with
	# no appetite still quotes exactly what the table says.
	var state := WorldValues.initial_state()
	assert_true(Valuation.crown(&"furs", state) > Valuation.crown(&"furs"),
		"a war is running and the Crown quotes the peacetime price for furs")

	state.values[WorldValues.WAR] = 0.0
	assert_almost_eq(Valuation.crown(&"furs", state), Valuation.crown(&"furs"), 0.0001,
		"a quiet year quotes something other than the authored price")
	assert_true(Valuation.crown(&"furs") > 0.0)


func test_trade_goes_through_the_crowns_dictionary() -> void:
	# Not through a price table read directly, or a failed harvest at home would
	# move the letters and not the trade.
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 10_000
	town.receive_gold(1_000.0)

	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(11), null
	)
	context.colony = colony

	var deal := Trade.buy(town, &"food", 10.0, context, Trade.TIER_NEED)
	var bought := context.log.of_type(Trade.EVENT_BOUGHT)
	assert_eq(bought.size(), 1, "the purchase did not reach the log")
	# Asked with the state the purchase was made in, because the dictionary is a
	# function of the world (#141) and quoting it without one asks a different
	# question.
	assert_almost_eq(float(bought[0].payload["unit_price"]),
		Valuation.crown(&"food", context.state), 0.0001,
		"the town paid a price the Crown's dictionary never quoted")
	assert_true(float(deal["received"]) > 0.0)


# --- 🔒 The tea rule survives ------------------------------------------------

func test_no_luxury_the_colony_can_make_is_cheaper_than_tea() -> void:
	# #113 stated as a rule rather than an ordering, because a price change can
	# honour an ordering by accident. Restated here because §1 makes prices
	# movable, and a rule that only held for one table would not be a rule.
	var tea := Valuation.crown(&"tea")
	for id in ResourceCatalogue.luxuries():
		if Valuation.crown(StringName(id)) >= tea:
			continue
		assert_true(ResourceCatalogue.is_producible(StringName(id)),
			"%s is cheaper than tea and the colony cannot make it" % id)


# --- 🔒 The PC has no lever -------------------------------------------------

func test_no_effect_moves_anybody_s_prices() -> void:
	# SPEC §10.2 locks that the PC's gold is not a wallet and §8.1 gives him no
	# lever on terms of trade. Prices move because the world moves, never because
	# he asked — so no letter may carry an effect that touches a valuation.
	for id in ContentRegistry.effect_ids():
		var name := String(id)
		assert_false(name.contains("price") or name.contains("valuation"),
			"the effect '%s' would let the PC move a price" % name)


# --- 🔒 The town, and why `base` is its own table ---------------------------
#
# §3 makes a town's valuation `base + need`. Everything below is about the first
# half of that being **authored and independent of the Crown's price**, which is
# the one thing about #135 that cannot be recovered if it is ever quietly
# derived: the mercantile pattern in §1 stops being a consequence and becomes a
# coincidence.

func _town(stock: Dictionary = {}, workers: int = 6) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	# Fixture sizes are in thousands (#426).
	town.workers = workers * Population.THOUSAND
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _wants(town: Town) -> DesiredStock:
	var colony := Colony.new()
	colony.add(town)
	return DesiredStock.for_town(town, ColonySnapshot.of(colony))


## What the town thinks a unit is worth, holding what it holds.
func _worth(town: Town, resource: StringName) -> float:
	return Valuation.town(resource, _wants(town), town.held(resource))


func test_the_town_dictionary_is_not_the_crowns_in_disguise() -> void:
	# **Both directions, or it is a multiple.** A table that were `price` times
	# anything could not put furs below the Crown and tools above it at once, and
	# §1's whole table is built on it doing exactly that.
	assert_true(ResourceCatalogue.town_base(&"furs") < Valuation.crown(&"furs"),
		"a colony swimming in furs valued them as highly as London did")
	assert_true(ResourceCatalogue.town_base(&"tools") > Valuation.crown(&"tools"),
		"a colony that manufactures nothing valued tools no higher than the Crown")


func test_lumber_trades_in_neither_direction() -> void:
	# §1's row that no derived table can produce. A town holding what it wants of
	# timber neither buys nor sells it: there is no margin in carrying a thing
	# across an ocean to sell it for what it was worth where it started.
	var town := _town()
	var timber := _worth(town, &"wood")
	assert_true(timber <= Valuation.crown(&"wood") * 1.1,
		"a town that wanted no more timber would still have paid to import it")
	assert_true(timber >= Valuation.crown(&"wood") * 0.9,
		"a town that wanted no more timber would have shipped it home at a loss")


func test_a_shortage_raises_it_and_a_surplus_collapses_it() -> void:
	var short := _town({"food": 0.0})
	var full := _town({"food": 900.0})
	assert_true(_worth(short, &"food") > ResourceCatalogue.town_base(&"food"),
		"an empty granary did not raise what grain was worth to the town")
	assert_true(_worth(full, &"food") < ResourceCatalogue.town_base(&"food"),
		"a year of grain in store did not lower what more of it was worth")


func test_a_surplus_collapses_to_the_same_place_whatever_it_is() -> void:
	# 🔒 **The floor is absolute, not a share of `base`.** A share is not a
	# collapse: it preserves the markup, so a town drowning in furs and drowning
	# in cloth still rates cloth four times the furs and spends the month at the
	# loom turning one surplus it does not want into another.
	var town := _town({"furs": 900.0, "clothing": 900.0, "wood": 900.0})
	for id in ["furs", "clothing", "wood"]:
		assert_almost_eq(_worth(town, StringName(id)), Valuation.SURPLUS_FLOOR, 0.0001,
			"a surplus of %s was still worth more than a surplus of anything else" % id)


# --- 🔒 The objective raises it, and finishing lowers it again --------------

func test_a_town_raising_a_church_wants_its_materials() -> void:
	# **The acceptance criterion for #135, in one pair of assertions.** The same
	# town, the same stores, differing only in whether it has a build under way.
	var idle := _town()
	var building := _town()
	building.objective = &"granary"
	building.objective_target = Vector2i(3, 3)

	var costed := Objective.costed_resources(building)
	assert_true(not costed.is_empty(), "a granary costs nothing to build")
	var material := StringName(costed[0])
	assert_true(_worth(building, material) > _worth(idle, material),
		"a town raising a building valued its materials no higher than one with no plans")


# --- 🔒 One valuation, and it answers the trade questions too ---------------

func _context() -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(7),
		WorldMap.new(5, 5, &"plains")
	)


func test_a_town_buys_what_it_is_short_of_and_not_what_it_has() -> void:
	# **The same gap, read twice.** Nothing here consults a second table or a
	# tier: what a town buys and what it sells are both the distance between its
	# own valuation and the Crown's price, and the duty is inside that distance.
	var context := _context()
	var hungry := _town({"food": 0.0})
	var fed := _town({"food": 900.0})

	assert_true(Valuation.worth_buying(&"food", _wants(hungry), 0.0, context),
		"a town with an empty granary would not buy grain at any price")
	assert_false(Valuation.worth_buying(&"food", _wants(fed), 900.0, context),
		"a town with a year of grain went shopping for more")
	assert_true(Valuation.worth_selling(&"food", _wants(fed), 900.0, context),
		"a town with a year of grain would not part with any of it")
	assert_false(Valuation.worth_selling(&"food", _wants(hungry), 0.0, context),
		"a town with an empty granary was willing to sell grain")


func test_a_duty_high_enough_closes_the_trade() -> void:
	# §2: the Steward can be genuinely wrong about a rate rather than merely
	# greedy. A rate that makes the landed cost exceed what the town thinks the
	# thing is worth ends the trade, and no tier overrides it.
	var context := _context()
	var short := _town({"food": 6.0})
	var wants := _wants(short)
	assert_true(Valuation.worth_buying(&"food", wants, 6.0, context),
		"a short town would not buy grain at the standing duty")

	context.state.values[TaxRates.key_for(&"food")] = 4.0
	assert_false(Valuation.worth_buying(&"food", wants, 6.0, context),
		"a town went on importing grain at five times its landed worth")
