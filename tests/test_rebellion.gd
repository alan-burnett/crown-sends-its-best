extends TestCase

## When a town stops obeying, and when it stops refusing to (#72, SPEC §12.3).
##
## 🔒 **A rebel town is not a lost town.** In the Crown's eyes it still belongs
## to the PC and his job is to bring it back: it still trades with loyal
## neighbours, the PC may still write to its governor, and in M3 only the town
## itself can end it — Crown troops are M6.
##
## 🔒 **The sign flip is the PC's foothold.** On rebelling the town stops paying
## duty, so the largest standing contributor goes to zero; its quality of life
## then falls because it cannot buy what it does not grow. Under attribution that
## falling quality of life *lowers* sentiment, which is the whole mechanism
## behind a peaceful return and the reason none of this needs an army.

const SEED: int = 7731

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


func _town(id: StringName = &"ashmere") -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 20
	town.governor_id = StringName("gov_%s" % id)
	town.quality_of_life = 0.7
	return town


func _context(towns: Array, month: int = 8) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var state := WorldValues.initial_state()
	state.month = month
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	return context


func _resolve(town: Town, sentiment: float, month: int = 8) -> Dictionary:
	town.rebel_sentiment = sentiment
	var context := _context([town], month)
	var outcome := Rebellion.resolve(town, context)
	return {"outcome": outcome, "log": context.log}


# --- 🔒 Crossing the line ---------------------------------------------------

func test_a_town_past_the_threshold_declares() -> void:
	var town := _town()
	var result := _resolve(town, Rebellion.DECLARES_AT + 1.0)
	assert_true(town.rebelling, "a town past the threshold went on obeying")
	assert_eq(String(result["outcome"]), String(Rebellion.EVENT_DECLARED))


func test_the_declaration_is_on_the_record() -> void:
	# The letters have to be able to report it, and they read the log.
	var town := _town()
	var result := _resolve(town, 90.0)
	var declared := (result["log"] as EventLog).of_type(Rebellion.EVENT_DECLARED)
	assert_eq(declared.size(), 1, "a town rebelled and nothing said so")
	assert_eq(String(declared[0].payload["town"]), "ashmere")
	assert_false(declared[0].payload.has("sentiment"),
		"the declaration carried the figure, which a letter could then render")


func test_a_town_below_the_threshold_stays_loyal() -> void:
	var town := _town()
	_resolve(town, Rebellion.DECLARES_AT - 1.0)
	assert_false(town.rebelling, "a town short of the threshold rebelled anyway")


# --- 🔒 The gap is the drama ------------------------------------------------

func test_a_rebel_town_does_not_come_back_the_moment_it_dips() -> void:
	# **Hysteresis.** One threshold would give a town sitting near it a coin toss
	# every month, and the Diplomat would have nothing coherent to report.
	var town := _town()
	_resolve(town, 90.0)
	assert_true(town.rebelling)

	_resolve(town, Rebellion.DECLARES_AT - 1.0, 9)
	assert_true(town.rebelling,
		"a rebel town returned the moment it fell a point below the declaring line")


func test_it_comes_back_once_it_falls_far_enough() -> void:
	var town := _town()
	_resolve(town, 90.0)
	var result := _resolve(town, Rebellion.RETURNS_AT - 1.0, 14)
	assert_false(town.rebelling, "a settled town stayed out")
	assert_eq(String(result["outcome"]), String(Rebellion.EVENT_RETURNED))


func test_a_return_says_how_long_it_was_out() -> void:
	var town := _town()
	_resolve(town, 90.0)
	town.rebelling_since = 8
	var result := _resolve(town, 10.0, 20)
	var returned := (result["log"] as EventLog).of_type(Rebellion.EVENT_RETURNED)
	assert_eq(returned.size(), 1, "a town came home and nothing said so")
	assert_eq(int(returned[0].payload["months_out"]), 12,
		"it came home having been out for no time at all")


func test_the_gap_is_a_gap() -> void:
	assert_true(Rebellion.RETURNS_AT < Rebellion.DECLARES_AT,
		"a town would flicker between rebellion and loyalty month to month")


# --- 🔒 What a rebel town will and will not do ------------------------------

func test_it_will_not_trade_with_the_crown() -> void:
	var town := _town()
	town.receive_gold(5_000.0)
	town.store(&"wood", 400.0)
	town.rebelling = true
	var context := _context([town])

	var bought := Trade.buy(town, &"food", 50.0, context, Trade.TIER_NEED)
	var sold := Trade.sell(town, &"wood", 100.0, context)
	assert_almost_eq(float(bought["received"]), 0.0, 0.001,
		"a rebel town bought bread from the Crown it had just renounced")
	assert_almost_eq(float(sold["sold"]), 0.0, 0.001,
		"a rebel town sold its timber to the Crown")


func test_its_specialty_rots_unsold() -> void:
	var town := _town()
	town.store(&"wood", 400.0)
	town.rebelling = true
	var context := _context([town])
	Trade.sell(town, &"wood", 400.0, context)
	assert_almost_eq(town.held(&"wood"), 400.0, 0.001,
		"the timber left the warehouse for a market that is closed to it")


func test_paying_no_duty_takes_the_largest_contributor_to_zero() -> void:
	# **The sign flip begins here.** No purchases, no duty, no tax resentment —
	# and the contributor `rebel-sentiment.md` §3 says dominates in steady state
	# simply stops.
	var town := _town()
	town.receive_gold(5_000.0)
	town.rebelling = true
	var context := _context([town])
	Trade.buy(town, &"food", 80.0, context, Trade.TIER_NEED)

	var parts := RebelSentiment.of(town, context, null, {})
	assert_almost_eq(float(parts["tax"]), 0.0, 0.0001,
		"a town that pays no duty resented the duty anyway")


func test_it_still_shares_with_loyal_neighbours() -> void:
	# It is still part of the colony. Relief moves goods by need, and a rebel
	# town neither hoards from its neighbours nor is cut off by them.
	var rebel := _town(&"ashmere")
	rebel.rebelling = true
	rebel.store(&"food", 900.0)
	var loyal := _town(&"bellhaven")

	var context := _context([rebel, loyal])
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.RELIEF, ReliefPhase.new())
	month.run(context.colony, context)

	assert_true(loyal.held(&"food") > 0.0,
		"a rebel town with nine hundred grain let its neighbour go hungry")


func test_the_governor_of_a_rebel_town_gives_nothing() -> void:
	# **He has no loyalty to the Crown.** The PC may still write; he will be
	# refused, and the refusal is a real event his letters can report rather than
	# silence.
	var town := _town()
	town.rebelling = true

	var governor := Contact.new(&"gov_ashmere")
	governor.relationship.loyalty = 100.0  # As well-disposed as anyone can be.

	var order := Order.new()
	order.kind = M1Registrations.ORDER_URGE_INTENT
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "intent": "grow"}

	var state := WorldValues.initial_state()
	state.month = 9
	var resolved := Compliance.resolve(
		order, governor, IntentBook.new(), state, EventLog.new(), RngStreams.new(SEED), town
	)
	assert_eq(String(resolved["outcome"]), String(Compliance.REFUSE),
		"a governor who had renounced the Crown obeyed it anyway")


func test_a_loyal_governor_is_not_refused_on_his_behalf() -> void:
	# The pair: without it the test above would pass just as well if every
	# governor refused everything.
	var town := _town()
	var governor := Contact.new(&"gov_ashmere")
	governor.relationship.loyalty = 100.0

	var order := Order.new()
	order.kind = M1Registrations.ORDER_URGE_INTENT
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "intent": "grow"}

	var state := WorldValues.initial_state()
	state.month = 9
	var resolved := Compliance.resolve(
		order, governor, IntentBook.new(), state, EventLog.new(), RngStreams.new(SEED), town
	)
	assert_true(String(resolved["outcome"]) != String(Compliance.REFUSE),
		"a devoted governor of a loyal town refused a letter out of hand")


# --- 🔒 The sign flip, which is the whole point -----------------------------

func test_misery_settles_a_rebel_town_and_prosperity_does_not() -> void:
	# **The mechanism behind a peaceful return.** Two rebel towns identical but
	# for how they are living: the one whose rebellion is visibly costing it
	# settles, the one for whom it is working does not.
	#
	# Stated as a comparison rather than against a number, because every weight
	# in the model is tuning and the *direction* is the design.
	# **Both developed**, so the comparison sits above the floor. Sentiment is
	# clamped at zero, and two rebel towns with nothing else pushing up both
	# bottom out there and read alike — which is `rebel-sentiment.md` §9's open
	# item about whether a rebel town's sentiment should have a floor at all,
	# met in practice on the first fixture that asked.
	var starving := _town(&"ashmere")
	starving.rebelling = true
	starving.quality_of_life = 0.05
	starving.buildings = PackedStringArray(["storehouse", "sawmill", "church"])
	starving.traded_value = 3_000.0

	var thriving := _town(&"bellhaven")
	thriving.rebelling = true
	thriving.quality_of_life = 0.95
	thriving.buildings = PackedStringArray(["storehouse", "sawmill", "church"])
	thriving.traded_value = 3_000.0

	var bleak := RebelSentiment.of(starving, _context([starving]), null, {})
	var comfortable := RebelSentiment.of(thriving, _context([thriving]), null, {})

	assert_true(float(bleak["total"]) < float(comfortable["total"]),
		"a rebellion that was visibly costing the town was as attractive as one that was working")


func test_a_rebel_town_that_cannot_trade_settles_over_months() -> void:
	# The loop end to end, at the model level: tax goes to zero because it buys
	# nothing, and its misery now argues against the rebellion rather than for
	# it. Run far enough and it crosses back.
	var town := _town()
	town.rebel_sentiment = 90.0
	town.rebelling = true
	town.rebelling_since = 8
	town.quality_of_life = 0.05

	var came_home := false
	for month in range(9, 30):
		var context := _context([town], month)
		town.rebel_sentiment = float(RebelSentiment.of(town, context, null, {})["total"])
		if String(Rebellion.resolve(town, context)) == String(Rebellion.EVENT_RETURNED):
			came_home = true
			break
	assert_true(came_home,
		"a rebel town living on nothing never reconsidered, so the PC has no foothold at all")


func test_nothing_here_lets_the_crown_retake_a_town() -> void:
	# M3 has no troops (SPEC §12.3, Crown troops are M6), so the only path out of
	# rebellion is the town choosing it. A future executor that seized a town
	# would have to say so in the doc first.
	var town := _town()
	town.rebelling = true
	town.rebel_sentiment = 90.0
	for month in range(9, 20):
		Rebellion.resolve(town, _context([town], month))
	assert_true(town.rebelling,
		"something put a rebel town back under the Crown without its sentiment moving")


# --- 🔒 A rebellion never stays put -----------------------------------------

func _rebel(id: StringName, quality: float, embargoed: bool = false) -> Town:
	var town := _town(id)
	town.rebelling = true
	town.quality_of_life = quality
	town.embargo_months = 6 if embargoed else 0
	return town


func test_two_rebels_are_worse_than_one() -> void:
	var watching := _town(&"ashmere")
	var one := _context([watching, _rebel(&"bellhaven", 0.9)])
	var two := _context([_town(&"ashmere"), _rebel(&"bellhaven", 0.9), _rebel(&"carrick", 0.9)])

	assert_true(
		float(RebelSentiment.of(two.colony.by_id(&"ashmere"), two, null, {})["neighbours"])
		> float(RebelSentiment.of(watching, one, null, {})["neighbours"]),
		"a second town in revolt was no more persuasive than the first")


func test_the_term_does_not_run_away() -> void:
	# **Dire, not arithmetically absurd.** A colony half in revolt should be
	# desperate; a term that grew without bound would make the second rebellion
	# decide the run.
	var towns: Array = [_town(&"ashmere")]
	for at in 8:
		towns.append(_rebel(StringName("rebel_%d" % at), 1.0))
	var context := _context(towns)
	var spread := float(RebelSentiment.of(towns[0], context, null, {})["neighbours"])
	assert_true(spread <= RebelSentiment.NEIGHBOUR_WEIGHT * 3.0,
		"eight rebel towns produced a spread term of %f" % spread)


func test_a_punished_rebel_argues_less() -> void:
	# **A town being ground down is an argument against rebellion**, and reads as
	# one. SPEC §12.3: loyal towns will not keep paying taxes while a neighbour
	# refuses them and suffers nothing for it.
	var free_rein := _context([_town(&"ashmere"), _rebel(&"bellhaven", 0.9)])
	var punished := _context([_town(&"ashmere"), _rebel(&"bellhaven", 0.9, true)])

	assert_true(
		float(RebelSentiment.of(punished.colony.by_id(&"ashmere"), punished, null, {})["neighbours"])
		< float(RebelSentiment.of(free_rein.colony.by_id(&"ashmere"), free_rein, null, {})["neighbours"]),
		"a rebel town under embargo was as tempting as one the Crown had left alone")


func test_a_town_that_comes_home_stops_arguing_at_once() -> void:
	var rebel := _rebel(&"bellhaven", 0.9)
	var watching := _town(&"ashmere")
	var context := _context([watching, rebel])
	assert_true(float(RebelSentiment.of(watching, context, null, {})["neighbours"]) > 0.0)

	rebel.rebelling = false
	assert_almost_eq(float(RebelSentiment.of(watching, context, null, {})["neighbours"]), 0.0, 0.0001,
		"a town back in the fold went on arguing for rebellion")


# --- 🔒 Punishment cuts both ways -------------------------------------------

func test_an_embargo_hardens_the_town_it_falls_on() -> void:
	# **The tension is the design.** The hunger is visibly the Crown's doing, so
	# under attribution it is the Crown that is blamed for it — and the PC buys
	# quiet among the neighbours at the price of digging in the town he is trying
	# to win back.
	var spared := _rebel(&"ashmere", 0.4)
	var starved := _rebel(&"ashmere", 0.4, true)

	assert_true(
		float(RebelSentiment.of(starved, _context([starved]), null, {})["punishment"])
		> float(RebelSentiment.of(spared, _context([spared]), null, {})["punishment"]),
		"an embargo cost the town it was laid on nothing at all")


func test_the_colony_will_not_relieve_an_embargoed_town() -> void:
	var cut_off := _town(&"ashmere")
	cut_off.rebelling = true
	cut_off.embargo_months = 6
	var generous := _town(&"bellhaven")
	generous.store(&"food", 900.0)

	var context := _context([cut_off, generous])
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.RELIEF, ReliefPhase.new())
	month.run(context.colony, context)

	assert_almost_eq(cut_off.held(&"food"), 0.0, 0.001,
		"the convoys went through an embargo")


func test_lifting_it_lets_the_convoys_through_again() -> void:
	# The pair, so the test above cannot pass by Relief being broken.
	var restored := _town(&"ashmere")
	restored.rebelling = true
	var generous := _town(&"bellhaven")
	generous.store(&"food", 900.0)

	var context := _context([restored, generous])
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.RELIEF, ReliefPhase.new())
	month.run(context.colony, context)

	assert_true(restored.held(&"food") > 0.0,
		"a rebel town under no embargo was left to starve anyway")


func test_an_embargo_is_something_the_pc_can_stop_doing() -> void:
	# A punishment with no end is one he cannot take back, and SPEC §12.3's
	# reward-and-punish pair only works if both can be stopped.
	var town := _town()
	town.embargo_months = 2
	var executor := EmbargoExecutor.new()
	var colony := Colony.new()
	colony.add(town)
	executor.colony = colony

	var intent := Intent.new(&"lift_1", EmbargoExecutor.KIND, &"pc", town.id, 1, {"months": 0})
	var state := WorldValues.initial_state()
	state.month = 10
	assert_eq(String(executor.execute(intent, state, EventLog.new())), String(Intent.COMPLETED))
	assert_false(town.is_embargoed(), "the embargo outlived the order lifting it")


func test_a_rebel_governor_cannot_refuse_an_embargo() -> void:
	# It is an instruction to the rest of the colony, carried to the man it
	# concerns as a courtesy. Making it conditional on his goodwill would have
	# made the Crown's only punishment unusable against anyone who deserved it.
	var town := _town()
	town.rebelling = true
	var governor := Contact.new(&"gov_ashmere")
	governor.relationship.loyalty = 0.0

	var order := Order.new()
	order.kind = M1Registrations.ORDER_EMBARGO
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "months": 6}

	var state := WorldValues.initial_state()
	state.month = 9
	var resolved := Compliance.resolve(
		order, governor, IntentBook.new(), state, EventLog.new(), RngStreams.new(SEED), town
	)
	assert_eq(String(resolved["outcome"]), String(Compliance.COMPLY),
		"a rebel governor talked the Crown out of punishing his town")


# --- 🔒 It survives a reload ------------------------------------------------

func test_a_rebellion_survives_a_round_trip() -> void:
	var town := _town()
	_resolve(town, 90.0)
	town.rebelling_since = 8
	var restored := Town.from_dict(town.to_dict())
	assert_true(restored.rebelling, "a reload brought a rebel town quietly back into the fold")
	assert_eq(restored.rebelling_since, 8, "it came back having always been out, or never")
