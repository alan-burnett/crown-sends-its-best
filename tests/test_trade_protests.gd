extends TestCase

## A town refuses to deal in one resource (#75, SPEC §10.2,
## `docs/mechanics/trade-protests.md`).
##
## 🔒 **It is the people's decision.** A calculation crossing a threshold, not a
## deliberation — nothing here goes through the kernel, and #131 removed the
## decision kind so nothing can register a personality weight against it.
##
## 🔒 **A town trends toward one protest at a time. A resource does not.**
##
## 🔒 **Sentiment feeds protests; protests do not feed sentiment.** The links
## that look like feedback all run through the world instead, which is what keeps
## `rebel-sentiment.md`'s acyclicity intact.

const SEED: int = 7731

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


## A town wretched enough and angry enough to be on the edge of protesting.
func _town(id: StringName = &"ashmere", sentiment: float = 50.0, quality: float = 0.4) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 20
	town.governor_id = StringName("governor_%s" % id)
	town.rebel_sentiment = sentiment
	town.quality_of_life = quality
	town.receive_gold(2_000.0)
	return town


func _context(towns: Array, rates: Dictionary = {}) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var state := WorldValues.initial_state()
	for key in rates:
		state.values[TaxRates.key_for(StringName(key))] = float(rates[key])
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	return context


## Settle the familiar rate to whatever is being charged, so nothing reads as a
## rise. The starting point for every test that is not about a rise.
func _long_settled(context: ColonyContext) -> void:
	for id in ResourceCatalogue.ids():
		context.state.values[TradeProtest.FAMILIAR_PREFIX + id] = \
			TaxRates.rate_for(context.state, StringName(id))


func _total(town: Town, resource: StringName, context: ColonyContext) -> float:
	return float(TradeProtest.score(town, resource, context)["total"])


# --- 🔒 Scoped to one town and one resource ---------------------------------

func test_a_protest_stops_one_resource_in_one_town() -> void:
	var protesting := _town(&"ashmere")
	var quiet := _town(&"brackwater")
	var context := _context([protesting, quiet])
	protesting.protests.append("tea")

	assert_false(Trade.may_trade_with_crown(protesting, &"tea", context),
		"a town protesting tea traded tea")
	assert_true(Trade.may_trade_with_crown(protesting, &"rum", context),
		"a town protesting tea stopped trading everything")
	assert_true(Trade.may_trade_with_crown(quiet, &"tea", context),
		"one town's protest closed its neighbour's market")


func test_a_rebelling_town_refuses_everything() -> void:
	var town := _town()
	var context := _context([town])
	town.rebelling = true
	for id in ResourceCatalogue.ids():
		assert_false(Trade.may_trade_with_crown(town, StringName(id), context),
			"a rebelling town was still trading %s with the Crown" % id)


func test_a_protest_refuses_in_both_directions() -> void:
	var town := _town()
	var context := _context([town])
	town.protests.append("furs")
	town.store(&"furs", 400.0)

	var bought := Trade.buy(town, &"furs", 50.0, context)
	var sold := Trade.sell(town, &"furs", 50.0, context)
	assert_almost_eq(float(bought["received"]), 0.0, 0.0001, "a protesting town bought anyway")
	assert_almost_eq(float(sold["sold"]), 0.0, 0.0001, "a protesting town sold anyway")
	assert_almost_eq(town.held(&"furs"), 400.0, 0.0001, "the store moved during a protest")


# --- 🔒 All six inputs reach the score --------------------------------------

func test_rebel_sentiment_raises_the_score() -> void:
	var calm := _town(&"ashmere", 5.0)
	var angry := _town(&"brackwater", 60.0)
	var context := _context([calm, angry])
	_long_settled(context)
	assert_true(_total(angry, &"tea", context) > _total(calm, &"tea", context),
		"an angry town was no likelier to protest than a contented one")


func test_wretchedness_raises_the_score() -> void:
	var comfortable := _town(&"ashmere", 30.0, 0.95)
	var wretched := _town(&"brackwater", 30.0, 0.1)
	var context := _context([comfortable, wretched])
	_long_settled(context)
	assert_true(_total(wretched, &"tea", context) > _total(comfortable, &"tea", context),
		"quality of life did not reach the score")


func test_the_governors_regard_reaches_the_score() -> void:
	var loyal := _town(&"ashmere", 30.0)
	var slighted := _town(&"brackwater", 30.0)
	var context := _context([loyal, slighted])
	_long_settled(context)
	context.contacts["governor_ashmere"] = _governor(&"governor_ashmere", 95.0)
	context.contacts["governor_brackwater"] = _governor(&"governor_brackwater", 5.0)

	assert_true(_total(slighted, &"tea", context) > _total(loyal, &"tea", context),
		"a slighted governor's town was no likelier to protest than a well-kept one")


func test_a_standing_duty_raises_the_score() -> void:
	var cheap := _context([_town(&"ashmere")], {"tea": 0.05})
	var dear := _context([_town(&"brackwater")], {"tea": 0.6})
	_long_settled(cheap)
	_long_settled(dear)
	assert_true(_total(dear.colony.in_order()[0], &"tea", dear)
			> _total(cheap.colony.in_order()[0], &"tea", cheap),
		"a punishing standing duty was resented no more than a nominal one")


func test_a_rise_counts_for_more_than_the_level_it_rose_to() -> void:
	# 🔒 §2's asymmetry. A town living with a punishing rate for two years is
	# angrier than one just raised to half of it, and **less likely to act**.
	var settled := _town(&"ashmere")
	var provoked := _town(&"brackwater")

	var long_suffering := _context([settled], {"tea": 0.60})
	_long_settled(long_suffering)

	var just_raised := _context([provoked], {"tea": 0.30})
	_long_settled(just_raised)
	just_raised.state.values[TaxRates.key_for(&"tea")] = 0.40

	assert_true(_total(provoked, &"tea", just_raised) > _total(settled, &"tea", long_suffering),
		"a duty raised to forty per cent provoked less than a settled sixty")


func test_getting_used_to_it_spends_the_grievance() -> void:
	var town := _town()
	var context := _context([town], {"tea": 0.3})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"tea")] = 0.6
	var fresh := _total(town, &"tea", context)

	for _year in 24:
		TradeProtest.settle_familiarity(context)
	assert_true(_total(town, &"tea", context) < fresh,
		"two years on, the town was as provoked by the rise as the month it landed")


# --- 🔒 Luxuries and needs are weighted opposite ----------------------------

func test_a_luxury_is_likelier_than_a_staple_and_a_staple_than_a_need() -> void:
	assert_true(TradeProtest.appetite_for(&"tea") > TradeProtest.appetite_for(&"wood"),
		"a town found tea no easier to give up than timber")
	assert_true(TradeProtest.appetite_for(&"wood") > TradeProtest.appetite_for(&"food"),
		"a town found grain as easy to give up as timber")


func test_the_cheapest_pleasure_is_the_softest_place_to_tax() -> void:
	# 🔒 §4, and the reason tea comes first without being named: **the cheapest
	# pleasure is the one least is lost by giving up.** Nothing in the model
	# knows what tea is — it knows what things cost.
	assert_true(TradeProtest.appetite_for(&"tea") > TradeProtest.appetite_for(&"rum"),
		"a town gave up rum at eleven as readily as tea at six")


func test_a_town_holds_on_to_what_it_sells() -> void:
	# §5: a town that buys a resource goes without it; a town that **sells** it
	# loses the income, and that bites far harder than giving up rum. It is also
	# the other half of why tea leads — nobody anywhere can make it.
	var trapping := _town()
	var context := _context([trapping])
	trapping.store(&"cotton", 500.0)
	assert_true(
		TradeProtest.appetite_for(&"clothing", _town(&"brackwater"), context)
			> TradeProtest.appetite_for(&"clothing", trapping, context),
		"a town at the loom refused its own cloth as readily as a town that buys it")


func test_a_town_can_be_driven_to_protest_its_own_bread() -> void:
	# 🔒 **Weighted opposite, not excluded.** Things can get bad enough that a
	# town would rather starve than pay, and it must be reachable — rare, late,
	# and read as a catastrophe rather than a tactic.
	var desperate := _town(&"ashmere", 64.0, 0.02)
	var context := _context([desperate], {"food": 0.95})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"food")] = 1.0
	context.contacts["governor_ashmere"] = _governor(&"governor_ashmere", 0.0)

	TradeProtest.resolve(desperate, context)
	assert_true(TradeProtest.is_protesting(desperate, &"food"),
		"no colony however wretched could ever refuse the Crown's grain")


# --- 🔒 The runway is per town ----------------------------------------------

func test_a_running_protest_raises_this_towns_bar_and_no_other() -> void:
	var loud := _town(&"ashmere")
	var quiet := _town(&"brackwater")
	var context := _context([loud, quiet])
	var bar := TradeProtest.threshold_for(quiet)
	loud.protests.append("tea")

	assert_true(TradeProtest.threshold_for(loud) > bar,
		"a town that had already protested found the next one just as easy")
	assert_almost_eq(TradeProtest.threshold_for(quiet), bar, 0.0001,
		"one town's protest raised its neighbour's bar")


func test_a_town_over_the_line_on_everything_protests_one_thing() -> void:
	# It has made its point. The colony keeps trading with an unruly town rather
	# than watching every resource shut at once like a gate.
	var town := _town(&"ashmere", 64.0, 0.02)
	var context := _context([town], {"tax.base": 0.0})
	for id in ResourceCatalogue.ids():
		context.state.values[TaxRates.key_for(StringName(id))] = 0.9
	_long_settled(context)
	context.contacts["governor_ashmere"] = _governor(&"governor_ashmere", 0.0)

	TradeProtest.resolve(town, context)
	assert_eq(town.protests.size(), 1,
		"a town shut %d markets in one month, which is a gate rather than a protest"
			% town.protests.size())

	# And the one it picked is the one it feels most, not the first in the
	# catalogue — otherwise the alphabet is deciding.
	var loudest := ""
	var most := 0.0
	for id in ResourceCatalogue.ids():
		var total := float(TradeProtest.score(town, StringName(id), context)["total"])
		if total > most:
			most = total
			loudest = id
	assert_eq(String(town.protests[0]), loudest,
		"the town protested %s while feeling strongest about %s" % [town.protests[0], loudest])


func test_a_colony_wide_duty_lights_up_the_whole_coast() -> void:
	# The other half of the pair: a town's patience is its own, but the PC's
	# decision arrives everywhere he rules at once. **That is agency** — he did
	# that, on purpose, with one letter.
	var towns: Array = []
	for name in ["ashmere", "brackwater", "coldharbour"]:
		towns.append(_town(StringName(name), 55.0, 0.25))
	var context := _context(towns, {"tea": 0.2})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"tea")] = 0.75

	for town in towns:
		TradeProtest.resolve(town, context)
	var protesting := 0
	for town in towns:
		if TradeProtest.is_protesting(town, &"tea"):
			protesting += 1
	assert_eq(protesting, towns.size(),
		"a colony-wide duty rise shut %d of three markets, not all of them" % protesting)


# --- 🔒 Hysteresis, and no minimum duration ---------------------------------

func test_the_quickest_way_to_end_a_protest_is_to_give_them_what_they_want() -> void:
	# **No minimum duration.** A player who reads the letter, understands it and
	# acts immediately has earned the result.
	var town := _town(&"ashmere", 55.0, 0.25)
	var context := _context([town], {"tea": 0.2})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"tea")] = 0.8
	TradeProtest.resolve(town, context)
	assert_true(TradeProtest.is_protesting(town, &"tea"), "the fixture never protested")

	context.state.values[TaxRates.key_for(&"tea")] = 0.0
	TradeProtest.resolve(town, context)
	assert_false(TradeProtest.is_protesting(town, &"tea"),
		"a duty cut to nothing the following month did not end the protest")


func test_a_protest_does_not_flicker_on_the_threshold() -> void:
	# The gap between declaring and lifting, for the same reason rebellion has
	# one: a town that changes its mind every month is noise, not drama.
	assert_true(TradeProtest.LIFTS_AT < TradeProtest.DECLARES_AT,
		"a protest lifts at the same score it declares at, which is a coin toss")


# --- 🔒 Protests do not feed sentiment --------------------------------------

func test_a_protest_is_not_a_term_in_rebel_sentiment() -> void:
	# 🔒 `trade-protests.md` §7. Everything that looks like a link runs through
	# the world instead: a clothing protest leaves people cold, quality of life
	# falls, and sentiment rises **because quality of life is a contributor** —
	# not because a protest is.
	var quiet := _town(&"ashmere", 40.0, 0.4)
	var protesting := _town(&"ashmere", 40.0, 0.4)
	protesting.protests.append("tea")
	protesting.protests.append("rum")

	var context := _context([quiet])
	var before := float(RebelSentiment.of(quiet, context, Grievances.new(), {})["total"])
	var after := float(RebelSentiment.of(protesting, context, Grievances.new(), {})["total"])
	assert_almost_eq(after, before, 0.0001,
		"a protest moved rebel sentiment directly, which makes the model cyclic")


func test_a_protest_removes_the_duty_it_was_about() -> void:
	# The feedback that is intended, and it needs no protest term: a town that
	# stops buying stops paying, and `RebelSentiment._tax` reads the duty
	# actually collected. **Protesting relieves the pressure that caused it.**
	var town := _town()
	var context := _context([town], {"tea": 0.5})
	Trade.buy(town, &"tea", 20.0, context)
	var paid := 0.0
	for event in context.log.of_type(Trade.EVENT_BOUGHT):
		paid += float(event.payload.get("tax", 0.0))
	assert_true(paid > 0.0, "the fixture town never paid any duty to stop paying")

	town.protests.append("tea")
	var after := _context([town], {"tea": 0.5})
	Trade.buy(town, &"tea", 20.0, after)
	assert_empty(after.log.of_type(Trade.EVENT_BOUGHT),
		"a protesting town went on paying the duty it was protesting")


# --- The record, and the save -----------------------------------------------

func test_a_declaration_is_on_the_record_with_what_drove_it() -> void:
	# **Calm enough that only the rise pushes it over**, so the declaration under
	# test is about the duty rather than about the town being generally wretched.
	var town := _town(&"ashmere", 20.0, 0.8)
	var context := _context([town], {"tea": 0.2})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"tea")] = 0.8
	TradeProtest.resolve(town, context)

	var declared: Array = context.log.of_type(TradeProtest.EVENT_DECLARED)
	assert_eq(declared.size(), 1, "a town refused the Crown and nothing said so")
	assert_eq(String(declared[0].payload["town"]), "ashmere")
	assert_eq(String(declared[0].payload["resource"]), "tea")
	assert_eq(String(declared[0].payload["loudest"]), "rise",
		"the Steward would name the wrong reason for a duty that had just doubled")
	# 🔒 Prestige is one-off, at declaration (§8). #76 reads this; nothing else
	# charges it, and there is deliberately no ongoing drain.
	assert_true(bool(declared[0].payload["prestige"]),
		"a public refusal of the Crown's duty was not a headline")


func test_protests_survive_a_save() -> void:
	var town := _town()
	town.protests.append("tea")
	town.protests.append("furs")
	var restored := Town.from_dict(town.to_dict())
	assert_eq(",".join(TradeProtest.running_in(restored)), "furs,tea",
		"a reload ended the protests, which is a way to cheat ironman")


func test_what_a_town_is_used_to_survives_a_save() -> void:
	var town := _town()
	var context := _context([town], {"tea": 0.4})
	TradeProtest.settle_familiarity(context)
	var restored := WorldState.from_dict(context.state.to_dict())
	assert_almost_eq(
		TradeProtest.familiar_rate(restored, &"tea"),
		TradeProtest.familiar_rate(context.state, &"tea"), 0.0001,
		"a reload made the colony forget what it was used to paying")


# --- The Steward reports it (SPEC §8.1) --------------------------------------

func test_the_steward_hears_about_a_protest_and_can_name_it() -> void:
	# **Asked of the colony, not of a town.** He is an ocean away and has no town
	# of his own; what reaches him is the news that a market has shut.
	var town := _town(&"ashmere", 55.0, 0.25)
	var context := _context([town], {"tea": 0.2})
	_long_settled(context)
	context.state.values[TaxRates.key_for(&"tea")] = 0.8
	context.state.month = 4
	TradeProtest.resolve(town, context)

	var letter := LetterContext.new(context.state, null, &"")
	letter.log = context.log
	letter.month = 4

	assert_true(ColonyConditions.a_town_began_a_protest({"within": 2}, letter),
		"a town refused the Crown and the Steward never heard")
	assert_eq(String(ColonyParamSources.protest({"field": "town", "within": 2}, letter)), "ashmere")
	assert_eq(String(ColonyParamSources.protest({"field": "resource", "within": 2}, letter)), "tea")
	assert_eq(int(ColonyParamSources.protest({"field": "rate", "within": 2}, letter)), 80,
		"the Steward would misquote the duty he is complaining about")

	# Last season's news is not this season's.
	letter.month = 40
	assert_false(ColonyConditions.a_town_began_a_protest({"within": 2}, letter),
		"the Steward is still writing about a protest three years old")


func _governor(id: StringName, loyalty: float) -> Contact:
	var contact := Contact.new(id)
	contact.role = Contact.ROLE_GOVERNOR
	contact.relationship.loyalty = loyalty
	return contact
