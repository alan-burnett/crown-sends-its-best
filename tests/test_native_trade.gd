extends TestCase

## Trade agreements: the tribe proposes, the governor accepts (#206,
## SPEC §10.1, §10.2, §11.3, §12.5; `docs/mechanics/natives.md` §5).
##
## 🔒 **The tribe proposes. The town never does.** There is no function that
## takes a town and produces an offer, and no path by which one could.
##
## 🔒 **No gold changes hands and no duty is charged.** Gold value sets the
## ratio and nothing else, and this never goes near `Trade` — so the exemption
## is a property of the code's shape rather than a rate somebody set to zero.
##
## 🔒 **The governor accepts, not the PC.** Towns run themselves. A governor may
## arm the people beside him and the PC reads about it next month, from a man who
## thought it a good bargain.

const SEED: int = 4409

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


func _map() -> WorldMap:
	var map := WorldMap.new(24, 24, &"ocean")
	for y in range(2, 22):
		for x in range(2, 22):
			map.set_terrain(x, y, &"plains")
	return map


func _context(map: WorldMap = null, colony: Colony = null) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	return context


func _tribe(standing: float = 70.0) -> Tribe:
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): standing}
	return tribe


func _village(food: float = 900.0, furs: float = 200.0) -> Village:
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = &"tribe_test"
	village.at = Vector2i(5, 5)
	village.people = 40
	village.stores = {"food": food, "furs": furs}
	village.objective = Village.GROW
	return village


func _town(at: Vector2i = Vector2i(5, 5)) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", at)
	town.workers = 40
	town.governor_id = &"gov_ashmere"
	town.intent = GovernorIntent.ECONOMY
	town.store(&"guns", 200.0)
	town.store(&"tools", 200.0)
	town.store(&"food", 40.0)
	return town


func _colony(town: Town) -> Colony:
	var colony := Colony.new()
	colony.add(town)
	return colony


func _desired(town: Town, colony: Colony) -> DesiredStock:
	return DesiredStock.for_town(town, ColonySnapshot.of(colony))


func _natives(tribe: Tribe, village: Village) -> Tribes:
	var natives := Tribes.new()
	natives.all.append(tribe)
	natives.villages.append(village)
	return natives


# --- 🔒 Only a tribe opens one, and only above a threshold ------------------

func test_a_people_who_do_not_trust_the_colony_offer_nothing() -> void:
	var town := _town()
	var colony := _colony(town)
	var offer := NativeTrade.propose(
		_tribe(TradeConsiderations.OPENS_ABOVE - 1.0), _village(), town,
		_desired(town, colony), _context(_map(), colony))
	assert_true(offer == null,
		"a people who think little of the colony brought it their winter stores")


func test_a_people_who_do_trust_it_come_with_something() -> void:
	var town := _town()
	var colony := _colony(town)
	var offer := NativeTrade.propose(
		_tribe(80.0), _village(), town, _desired(town, colony),
		_context(_map(), colony))
	assert_true(offer != null, "a people on good terms had nothing to say")
	assert_eq(offer.tribe, &"tribe_test")
	assert_eq(offer.town, &"ashmere")


func test_a_people_who_have_concluded_never_come_at_all() -> void:
	var tribe := _tribe(80.0)
	tribe.irreconcilable[String(Tribe.COLONY)] = true
	var town := _town()
	var colony := _colony(town)
	assert_true(NativeTrade.propose(
			tribe, _village(), town, _desired(town, colony),
			_context(_map(), colony)) == null,
		"a people past the point of no return came to barter")


func test_the_axis_names_something_the_village_actually_has() -> void:
	# 🔒 A filter and not a weight: offering a thing they do not hold is not a
	# worse bargain, it is not a bargain.
	var town := _town()
	var colony := _colony(town)
	var village := _village(900.0, 0.0)
	village.stores.erase("furs")

	var offer := NativeTrade.propose(
		_tribe(80.0), village, town, _desired(town, colony),
		_context(_map(), colony))
	assert_true(offer != null, "a village with a full granary offered nothing")
	assert_true(TradeConsiderations.spare_in(village, offer.they_give) > 0.0,
		"they offered %s, which they do not have" % offer.they_give)


func test_they_ask_only_for_what_they_cannot_make() -> void:
	# SPEC §12.2, §10.1: guns, tools and horses. A people asking a colony for
	# stone would be a people with no reason to deal with it at all.
	var town := _town()
	town.store(&"stone", 5_000.0)
	town.store(&"wood", 5_000.0)
	var colony := _colony(town)

	for standing in [60.0, 75.0, 90.0]:
		var offer := NativeTrade.propose(
			_tribe(float(standing)), _village(), town, _desired(town, colony),
			_context(_map(), colony))
		assert_true(offer != null, "nobody came at standing %s" % standing)
		assert_true(
			ResourceCatalogue.native_worth(offer.we_give)
				>= TradeConsiderations.WORTH_ASKING_FOR,
			"they asked for %s, which they could make themselves" % offer.we_give)


func test_a_people_deaf_to_what_they_lack_still_do_not_ask_for_stone() -> void:
	# 🔒 **Why it is a filter and not a weight** (`deliberation.md` §5). Scoring
	# already leans toward the things they cannot make, so the filter looks
	# redundant — until a people with no weight at all on that consideration
	# stands in front of a town with a mountain of stone. A weight can lose a
	# close vote; this must not be reachable.
	var town := _town()
	town.store(&"stone", 20_000.0)
	town.store(&"wood", 20_000.0)
	var colony := _colony(town)

	var tribe := _tribe(80.0)
	tribe.set_weight(TradeConsiderations.WANT, 0.0)
	tribe.set_weight(TradeConsiderations.THEIRS, 4.0)

	var offer := NativeTrade.propose(
		tribe, _village(), town, _desired(town, colony), _context(_map(), colony))
	assert_true(offer != null, "a people who care only what a town has asked for nothing")
	assert_true(
		ResourceCatalogue.native_worth(offer.we_give)
			>= TradeConsiderations.WORTH_ASKING_FOR,
		"they asked a colony for %s, which they dig out of the ground themselves"
			% offer.we_give)


func test_a_frightened_people_ask_for_different_things() -> void:
	# `Valuation.natives` moves with their circumstances rather than a hostility
	# gate being bolted on. A village arming itself wants guns; one working more
	# land wants tools.
	var arming := _village()
	arming.objective = Village.ARM_OURSELVES
	var farming := _village()
	farming.objective = Village.WORK_MORE_LAND

	assert_true(
		Valuation.natives(&"guns", NativeTrade.appetite_of(arming))
			> Valuation.natives(&"guns", NativeTrade.appetite_of(farming)),
		"a people arming themselves wanted guns no more than a people farming")
	assert_true(
		Valuation.natives(&"tools", NativeTrade.appetite_of(farming))
			> Valuation.natives(&"tools", NativeTrade.appetite_of(arming)),
		"a people breaking new ground wanted tools no more than a people arming")


func test_a_proposal_leaves_its_scoring_trace() -> void:
	# 🔒 `deliberation.md` §5: `choose()` always emits its trace. Before #206,
	# `faction_posture` was a decision kind nothing had ever deliberated on.
	var town := _town()
	var colony := _colony(town)
	var context := _context(_map(), colony)
	NativeTrade.propose(_tribe(80.0), _village(), town, _desired(town, colony), context)

	var traces: Array = context.log.of_type(Deliberation.TRACE_EVENT)
	assert_true(traces.size() > 0, "a people chose what to offer and said nothing about why")
	assert_eq(String(traces[0].payload["kind"]), String(DecisionKind.FACTION_POSTURE))


func test_no_town_can_open_one() -> void:
	# 🔒 The lock, asserted on the shape of the code. There is no function here
	# that takes a town and produces an agreement, so a dev who wanted one would
	# have to add it and argue with this test.
	var found := false
	for entry in NativeTrade.new().get_method_list():
		var name := String(entry["name"])
		if name.begins_with("_"):
			continue
		if name.contains("request") or name.contains("ask") or name.contains("open"):
			found = true
	assert_false(found,
		"NativeTrade grew a way for a town to ask for an agreement")


# --- 🔒 No gold, no duty, surplus for surplus -------------------------------

func test_a_month_of_trade_moves_no_gold_and_pays_no_duty() -> void:
	var town := _town()
	var village := _village()
	var colony := _colony(town)
	var context := _context(_map(), colony)

	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	deal.town = town.id
	deal.they_give = &"food"
	deal.we_give = &"tools"

	# **The purse is checked by spending it**, because a town's gold has no getter
	# (SPEC §11.3 — it is invisible to the player and the lint keeps it that way).
	town.receive_gold(500.0)
	var duty := context.crown_tax
	var got := deal.run(town, village, 0.0, context)

	assert_true(got > 0.0, "a standing agreement moved nothing at all")
	assert_almost_eq(town.spend_gold(1_000_000.0), 500.0, 0.0001,
		"coin changed hands")
	assert_almost_eq(context.crown_tax, duty, 0.0001, "the Crown took a duty on it")
	var ran: Array = context.log.of_type(TradeAgreement.EVENT_TRADED)
	assert_eq(ran.size(), 1, "a month of trade went unrecorded")
	assert_almost_eq(float(ran[0].payload["duty"]), 0.0, 0.0001)
	assert_almost_eq(float(ran[0].payload["gold"]), 0.0, 0.0001)


func test_what_moves_is_fair_value_at_the_gold_ratio() -> void:
	# §10.2: if food is worth two and tools twelve, six food buys one tool.
	var town := _town()
	var village := _village()
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	deal.town = town.id
	deal.they_give = &"food"
	deal.we_give = &"tools"

	var had := town.held(&"tools")
	var received := deal.run(town, village, 0.0, _context(_map(), colony))
	var given := had - town.held(&"tools")

	assert_true(received > 0.0 and given > 0.0, "nothing moved either way")
	assert_almost_eq(
		received * Valuation.crown(&"food"),
		given * Valuation.crown(&"tools"),
		0.01, "one side was cheated")


func test_neither_side_trades_away_what_it_needs() -> void:
	# A town does not sell the grain it is going to eat, and a people do not
	# trade their winter away.
	var town := _town()
	var village := _village(1.0, 0.0)
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	deal.town = town.id
	deal.they_give = &"food"
	deal.we_give = &"tools"

	assert_almost_eq(deal.run(town, village, 0.0, _context(_map(), colony)), 0.0, 0.0001,
		"a starving village sold its last grain")

	village.stores["food"] = 5_000.0
	var held := town.held(&"tools")
	assert_almost_eq(
		deal.run(town, village, held, _context(_map(), colony)), 0.0, 0.0001,
		"a town traded away tools Reckon had reserved")


func test_an_agreement_is_dropped_when_they_go_cold() -> void:
	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	assert_true(deal.still_stands(_tribe(60.0)), "a good bargain was abandoned in a good year")
	assert_false(deal.still_stands(_tribe(TradeAgreement.CLOSES_BELOW - 1.0)),
		"a people who had gone cold went on trading")
	assert_eq(deal.why_it_ended(_tribe(TradeAgreement.CLOSES_BELOW - 1.0)),
		TradeAgreement.STANDING_FELL)


func test_an_agreement_survives_a_bad_month_but_not_a_bad_year() -> void:
	# 🔒 It closes below where it opens, so a bargain struck in a good year does
	# not flicker open and shut on one month's resentment.
	assert_true(TradeAgreement.CLOSES_BELOW < TradeConsiderations.OPENS_ABOVE,
		"an agreement closes at the standing it opens at, so it will flicker")


func test_an_agreement_is_dropped_when_neither_side_has_anything_spare() -> void:
	var town := _town()
	var village := _village(1.0, 0.0)
	var colony := _colony(town)
	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	deal.town = town.id
	deal.they_give = &"food"
	deal.we_give = &"tools"

	for _month in TradeAgreement.PATIENCE:
		deal.run(town, village, 0.0, _context(_map(), colony))
	assert_false(deal.still_stands(_tribe(80.0)),
		"a bargain neither side could keep went on for ever")
	assert_eq(deal.why_it_ended(_tribe(80.0)), TradeAgreement.NOTHING_SPARE)


# --- 🔒 The governor accepts, not the PC ------------------------------------

func test_a_governor_may_arm_the_people_beside_him() -> void:
	var town := _town()
	town.intent = GovernorIntent.ECONOMY
	town.store(&"guns", 4_000.0)
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.they_give = &"food"
	deal.we_give = &"guns"
	assert_true(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"a governor with more guns than he can use and no grain refused a bargain")


func test_and_a_governor_told_to_see_to_his_defences_will_not() -> void:
	# 🔒 **The PC's one instrument, a month early** (§11.3). He cannot forbid the
	# bargain; he can be the reason the man was in a different frame of mind.
	var town := _town()
	town.store(&"guns", 4_000.0)
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.they_give = &"food"
	deal.we_give = &"guns"

	town.intent = GovernorIntent.ECONOMY
	assert_true(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"the fixture's bargain was refused for some other reason")

	town.intent = GovernorIntent.DEFENCE
	assert_false(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"a governor seeing to his defences handed his guns to the neighbours")


func test_a_governor_set_on_driving_them_off_does_not_deal_with_them_at_all() -> void:
	var town := _town()
	town.intent = GovernorIntent.DRIVE_OFF
	town.store(&"tools", 4_000.0)
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.they_give = &"food"
	deal.we_give = &"tools"
	assert_false(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"a man who meant to be rid of them sat down to barter with them")


func test_a_governor_refuses_a_bargain_that_does_not_pay() -> void:
	# **Per gold traded**, which is the only question a fair exchange leaves. A
	# town swimming in grain and with nothing to wear does not hand over its last
	# cloth for more grain, however civil the people asking.
	var town := _town()
	town.store(&"food", 50_000.0)
	town.take(&"clothing", town.held(&"clothing"))
	town.store(&"clothing", 1.0)
	var colony := _colony(town)

	var deal := TradeAgreement.new()
	deal.they_give = &"food"
	deal.we_give = &"clothing"
	assert_false(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"a town swimming in grain gave away its last cloth for more of it")

	# And the same bargain the other way round is one he takes.
	town.take(&"food", town.held(&"food") - 1.0)
	town.store(&"clothing", 5_000.0)
	deal.they_give = &"food"
	deal.we_give = &"clothing"
	assert_true(NativeTrade.would_accept(deal, town, _desired(town, colony)),
		"a town with cloth to spare and no grain refused grain for cloth")


# --- 🔒 Natives before the Crown, through the call that already existed -----

func test_exchange_buys_from_the_natives_before_the_crown() -> void:
	# SPEC §11.3, through `_buy_from_natives` — the seam M2 cut in the right
	# place, so nothing else in Exchange had to change.
	var map := _map()
	var town := _town()
	town.take(&"food", town.held(&"food"))
	var village := _village(5_000.0, 0.0)
	var colony := _colony(town)

	var book := TradeBook.new()
	var deal := TradeAgreement.new()
	deal.tribe = &"tribe_test"
	deal.town = town.id
	deal.they_give = &"food"
	deal.we_give = &"tools"
	book.deals.append(deal)

	var context := _context(map, colony)
	context.native_trade = book
	context.natives = _natives(_tribe(80.0), village)
	context.territory = Territory.compute(map, colony.in_order())

	town.receive_gold(500.0)
	# **Through Reckon first**, because Exchange buys against what Reckon worked
	# out this town needs — a phase run on its own has nothing to shop for.
	var before := ColonySnapshot.of(colony)
	WorkPhase.new().run(town, before, context)
	ReckonPhase.new().run(town, before, context)
	ExchangePhase.new().run(town, before, context)

	assert_true(town.held(&"food") > 0.0,
		"a starving town beside a full granary bought nothing from it")
	var ran: Array = context.log.of_type(TradeAgreement.EVENT_TRADED)
	assert_eq(ran.size(), 1, "the food came from somewhere other than the agreement")
	assert_true(float(ran[0].payload["received"]) > 0.0,
		"the agreement was consulted and brought nothing")
	# 🔒 **No duty on this**, whatever the town also bought from the Crown in the
	# same month. The exemption is that this path never goes near `Trade`, so the
	# figure on the exchange itself is nought by construction.
	assert_almost_eq(float(ran[0].payload["duty"]), 0.0, 0.0001,
		"the Crown took a duty on what the neighbours brought")
	assert_almost_eq(float(ran[0].payload["gold"]), 0.0, 0.0001,
		"the town paid its neighbours in coin")


func test_a_town_with_no_agreement_buys_from_nobody_next_door() -> void:
	var map := _map()
	var town := _town()
	var colony := _colony(town)
	var context := _context(map, colony)
	context.native_trade = TradeBook.new()
	context.natives = _natives(_tribe(80.0), _village(5_000.0, 0.0))
	context.territory = Territory.compute(map, colony.in_order())

	ExchangePhase.new().run(town, ColonySnapshot.of(colony), context)
	assert_eq(context.log.of_type(TradeAgreement.EVENT_TRADED).size(), 0,
		"a town with no agreement helped itself to a village's stores")


# --- The book, and the save --------------------------------------------------

func test_a_town_holds_one_agreement_at_a_time() -> void:
	var book := TradeBook.new()
	var context := _context()
	for axis in [[&"food", &"tools"], [&"furs", &"guns"]]:
		var deal := TradeAgreement.new()
		deal.tribe = &"tribe_test"
		deal.town = &"ashmere"
		deal.they_give = axis[0]
		deal.we_give = axis[1]
		book.open(deal, context)

	assert_eq(book.in_order().size(), 1,
		"a town ran two standing agreements at once and escaped the monopoly twice")


func test_the_agreements_survive_a_save() -> void:
	var run := RunState.new_run(SEED)
	var deal := TradeAgreement.new()
	deal.tribe = run.tribes.in_order()[0].id
	deal.town = run.colony.in_order()[0].id
	deal.they_give = &"food"
	deal.we_give = &"tools"
	deal.opened_month = 7
	deal.idle_months = 2
	run.native_trade.deals.append(deal)

	var restored := RunState.from_dict(run.to_dict())
	var same := restored.native_trade.of_town(deal.town)
	assert_true(same != null, "a bargain vanished in the save")
	assert_eq(same.they_give, &"food")
	assert_eq(same.we_give, &"tools")
	assert_eq(same.opened_month, 7)
	assert_eq(same.idle_months, 2)


func test_a_peoples_temperament_survives_a_save() -> void:
	# `Tribe` is a `DeliberationActor` now, so what one of them offers comes out
	# of a weight vector — and a reload that dropped it would make the same seed
	# a different people.
	var run := RunState.new_run(SEED)
	var tribe: Tribe = run.tribes.in_order()[0]
	tribe.set_weight(TradeConsiderations.WANT, 1.44)

	var same := RunState.from_dict(run.to_dict()).tribes.find(tribe.id)
	assert_almost_eq(same.weight_for(TradeConsiderations.WANT), 1.44, 0.0001,
		"a reload gave them a different temperament")
