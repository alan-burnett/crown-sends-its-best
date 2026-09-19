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
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
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
	# A constant is a function with no inputs. Starting it effectively fixed and
	# adding drivers later costs nothing; declaring it immovable would have to be
	# undone — and when it does move it is news the Steward can write about.
	var state := WorldValues.initial_state()
	assert_almost_eq(Valuation.crown(&"furs", state), Valuation.crown(&"furs"), 0.0001,
		"the Crown's price already depends on something, undocumented")
	assert_true(Valuation.crown(&"furs") > 0.0)


func test_trade_goes_through_the_crowns_dictionary() -> void:
	# Not through a price table read directly, or a failed harvest at home would
	# move the letters and not the trade.
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 10
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
	assert_almost_eq(float(bought[0].payload["unit_price"]), Valuation.crown(&"food"), 0.0001,
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
