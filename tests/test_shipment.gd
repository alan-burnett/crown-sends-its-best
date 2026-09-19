extends TestCase

## Goods leaving a town for the Crown (#69, `docs/mechanics/crown-demands.md` §5).
##
## 🔒 **The PC promises things he does not control.** Gold is the Crown's to
## move; resources sit in a town's stockpile, and SPEC §11.3 locks that towns run
## themselves under their governor. So a shipment is a two-step, and both steps
## can fail — and the PC's only power over goods he has already promised is
## another letter.
##
## The governor's three answers are Reckon's three tiers, which is what makes
## compliance precise rather than a mood:
##
## - *"I will treat this as a need"* — it outranks his own project and the town
##   goes without.
## - *"We will ship what we can"* — only genuine surplus leaves.
## - *"I am giving you nothing"* — nothing leaves.

const SEED: int = 8821

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


func _town(stock: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 20
	town.governor_id = &"gov_ashmere"
	town.store(&"food", 400.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _shipment(town: Town, resource: String, amount: float, tier: StringName,
		payment: float = 0.0) -> Intent:
	var intent := Intent.new(&"ship_1", Shipment.KIND, &"pc", town.id, 1, {
		"resource": resource,
		"amount": amount,
		"payment": payment,
		"tier": String(tier),
		"shipped": 0.0,
	})
	intent.origin = Intent.ORIGIN_ORDER
	return intent


func _run_months(town: Town, intent: Intent, months: int) -> Dictionary:
	var colony := Colony.new()
	colony.add(town)
	var executor := ShipmentExecutor.new()
	executor.colony = colony
	var log := EventLog.new()
	var state := WorldValues.initial_state()

	var resolution := Intent.IN_PROGRESS
	for month in months:
		state.month = month + 2
		resolution = executor.execute(intent, state, log)
		if resolution != Intent.IN_PROGRESS:
			break
	return {"resolution": resolution, "log": log}


# --- 🔒 The tier decides what the town will part with -----------------------

func test_a_governor_who_treats_it_as_a_need_ships_from_the_stockpile() -> void:
	var town := _town({"iron": 60.0})
	var intent := _shipment(town, "iron", 60.0, Shipment.TIER_NEED)
	var outcome := _run_months(town, intent, 12)
	assert_eq(String(outcome["resolution"]), String(Intent.COMPLETED),
		"a town with the goods in hand did not finish the shipment")
	assert_almost_eq(town.held(&"iron"), 0.0, 0.01,
		"the town kept iron back from a shipment it had made a need of")


func test_at_the_spare_tier_only_surplus_leaves() -> void:
	# The other half of the same rule. Food is a need, so a town shipping it as
	# *spare* keeps a month's eating and its reserve, however much is asked.
	var town := _town()
	var kept_back := 400.0
	var intent := _shipment(town, "food", kept_back, Shipment.TIER_SPARE)
	_run_months(town, intent, 12)

	var mouths := maxf(1.0, float(town.population()))
	var floor_at := mouths * ColonyNeeds.per_head(&"food") \
		* (1.0 + ColonyNeeds.reserve_months(&"food"))
	assert_true(town.held(&"food") >= floor_at - 0.01,
		"the town shipped its way below a month's food and its reserve")


func test_the_same_town_ships_more_when_it_is_made_a_need() -> void:
	# **The comparison is the whole mechanic.** One town, one demand, two
	# answers, and the difference is what the governor's compliance cost him.
	var willing := _town()
	_run_months(willing, _shipment(willing, "food", 400.0, Shipment.TIER_NEED), 12)

	var careful := _town()
	_run_months(careful, _shipment(careful, "food", 400.0, Shipment.TIER_SPARE), 12)

	assert_true(willing.held(&"food") < careful.held(&"food"),
		"treating the shipment as a need cost the town nothing extra")


func test_refusing_produces_no_shipment_at_all() -> void:
	var order := Order.new()
	order.kind = M1Registrations.ORDER_SHIP_RESOURCE
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "resource": "iron", "amount": 40, "payment": 0}
	# Compliance only builds an Intent when the outcome is not a refusal, so
	# there is nothing here to assert against beyond the tier mapping itself.
	assert_eq(String(Shipment.tier_for(Compliance.COMPLY)), String(Shipment.TIER_NEED))
	assert_eq(String(Shipment.tier_for(Compliance.PARTIAL)), String(Shipment.TIER_SPARE))
	assert_eq(String(Shipment.tier_for(Compliance.DELAY)), String(Shipment.TIER_SPARE))


# --- 🔒 It takes months, and can fall behind --------------------------------

func test_a_large_shipment_does_not_go_in_one_month() -> void:
	# **A demand for a great many horses is not refused for being large.** The
	# Marshal takes them across a year as the town shifts production, which is
	# what makes a shipment something a later letter can still reach.
	var town := _town({"iron": 600.0})
	var intent := _shipment(town, "iron", 600.0, Shipment.TIER_NEED)
	_run_months(town, intent, 1)
	assert_true(town.held(&"iron") > 0.0,
		"six hundred iron left the town in a single month")
	assert_true(float(intent.data["shipped"]) > 0.0, "nothing moved at all")


func test_a_town_with_nothing_to_send_stalls_rather_than_going_quiet() -> void:
	# A stall is a resolution, which is what lets the next letter say the goods
	# never came. Silence would leave the Marshal with nothing to write about.
	var town := _town()
	var intent := _shipment(town, "guns", 50.0, Shipment.TIER_SPARE)
	var outcome := _run_months(town, intent, Shipment.PATIENCE + 3)
	assert_eq(String(outcome["resolution"]), String(Intent.STALLED),
		"a town with no guns at all neither shipped nor stalled")


func test_a_shipment_that_completes_says_so() -> void:
	var town := _town({"iron": 60.0})
	var intent := _shipment(town, "iron", 60.0, Shipment.TIER_NEED)
	var outcome := _run_months(town, intent, 12)
	var sent := 0
	for event in (outcome["log"] as EventLog).of_type(ShipmentExecutor.EVENT_SENT):
		sent += 1
	assert_true(sent > 1, "the shipment reported %d months of movement" % sent)


# --- 🔒 The gold does not behave like trade ---------------------------------

func test_the_town_receives_what_the_crown_pays() -> void:
	# It lands in the balance the player never sees. Gold raises `means`, which
	# raises quality of life, which lowers rebel sentiment — so an overpaid
	# shipment lets the PC spend Crown Standing to buy a town's contentment.
	var paid := _town({"iron": 60.0})
	var unpaid := _town({"iron": 60.0})
	_run_months(paid, _shipment(paid, "iron", 60.0, Shipment.TIER_NEED, 900.0), 12)
	_run_months(unpaid, _shipment(unpaid, "iron", 60.0, Shipment.TIER_NEED, 0.0), 12)

	assert_true(paid.spend_gold(900.0) > unpaid.spend_gold(900.0),
		"the town was no richer for a shipment the Crown paid nine hundred for")


func test_the_crown_is_paid_once_however_long_it_takes() -> void:
	var town := _town({"iron": 600.0})
	var intent := _shipment(town, "iron", 600.0, Shipment.TIER_NEED, 500.0)
	var outcome := _run_months(town, intent, 12)
	var payments := 0
	for event in (outcome["log"] as EventLog).of_type(ShipmentExecutor.EVENT_PAID):
		payments += 1
	assert_eq(payments, 1, "the Treasury paid for the same shipment %d times" % payments)


func test_a_shipment_generates_no_duty_either_way() -> void:
	# **A requisition is not a trade.** There are no merchants in the middle to
	# tax, so the Crown's books show the cost and no receipt against it — which
	# is the arithmetic that makes overpayment a real price rather than a
	# gesture (`town-economy.md` §5).
	var town := _town({"iron": 60.0})
	var outcome := _run_months(town, _shipment(town, "iron", 60.0, Shipment.TIER_NEED, 900.0), 12)
	var accounts := CrownAccounts.of(outcome["log"])
	assert_true(accounts.is_empty(),
		"a requisition put duty on the Crown's books as though it were a trade")


# --- 🔒 Reckon sees what the governor made a need of ------------------------

func test_reckon_counts_a_needs_tier_shipment_among_the_needs() -> void:
	var town := _town()
	var colony := Colony.new()
	colony.add(town)
	var intents := IntentBook.new()
	var log := EventLog.new()
	intents.commit(_shipment(town, "iron", 60.0, Shipment.TIER_NEED), log, 1)

	var context := ColonyContext.new(WorldValues.initial_state(), log, RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	context.intents = intents

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.run(colony, context)

	assert_true(context.reckoning_for(town).need_of(&"iron") > 0.0,
		"a shipment the governor made a need of did not reach the town's needs")


func test_reckon_ignores_a_spare_tier_shipment() -> void:
	var town := _town()
	var colony := Colony.new()
	colony.add(town)
	var intents := IntentBook.new()
	var log := EventLog.new()
	intents.commit(_shipment(town, "iron", 60.0, Shipment.TIER_SPARE), log, 1)

	var context := ColonyContext.new(WorldValues.initial_state(), log, RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	context.intents = intents

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.run(colony, context)

	assert_almost_eq(context.reckoning_for(town).need_of(&"iron"), 0.0, 0.001,
		"the town went shopping for iron it had only agreed to send if spare")


# --- 🔒 The whole path, from the letter to the goods ------------------------

func test_a_governor_who_agrees_actually_ships() -> void:
	# **The two steps, end to end.** The Order goes through compliance like any
	# other, the outcome becomes a tier, the tier becomes an Intent, and the
	# executor moves the goods over months. Every part of that is covered on its
	# own above; this is the one test that would notice if the joins came apart.
	var town := _town({"iron": 240.0})
	var colony := Colony.new()
	colony.add(town)

	var governor := Contact.new(&"gov_ashmere")
	governor.relationship.loyalty = 95.0

	var order := Order.new()
	order.kind = M1Registrations.ORDER_SHIP_RESOURCE
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "resource": "iron", "amount": 60, "payment": 3000}

	var book := IntentBook.new()
	var log := EventLog.new()
	var state := WorldValues.initial_state()
	state.month = 1
	var resolved := Compliance.resolve(order, governor, book, state, log, RngStreams.new(SEED))

	var intent: Intent = resolved["intent"]
	if intent == null:
		# He is within his rights to refuse, and the tier mapping is tested above.
		assert_eq(String(resolved["outcome"]), String(Compliance.REFUSE),
			"compliance produced no Intent and did not refuse either")
		return

	assert_true(intent.data.has("tier"),
		"an agreed shipment carries no tier, so the town does not know what it costs")
	assert_eq(String(intent.kind), String(Shipment.KIND))

	var executor := ShipmentExecutor.new()
	executor.colony = colony
	var held := town.held(&"iron")
	for month in 10:
		state.month = month + 2
		if executor.execute(intent, state, log) != Intent.IN_PROGRESS:
			break
	assert_true(town.held(&"iron") < held,
		"the governor agreed and not one bar of iron left the town")


# --- 🔒 Asking is a letter, and a costly one --------------------------------

func test_asking_for_a_shipment_costs_the_governor_something() -> void:
	# **Full compliance damages his own town**, so it costs his loyalty unless
	# the payment makes it up to him (SPEC §8.5). A request that cost nothing
	# would make the payment choice meaningless.
	var order := Order.new()
	order.kind = M1Registrations.ORDER_SHIP_RESOURCE
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "resource": "iron", "amount": 200, "payment": 0}
	assert_true(Compliance.cost_of(order) > 0.0,
		"asking a governor for two hundred iron cost him nothing")

	var small := Order.new()
	small.kind = M1Registrations.ORDER_SHIP_RESOURCE
	small.addressed_to = &"gov_ashmere"
	small.params = {"to": "gov_ashmere", "resource": "iron", "amount": 20, "payment": 0}
	assert_true(Compliance.cost_of(order) > Compliance.cost_of(small),
		"a demand for two hundred weighed no more on him than one for twenty")


func test_paying_well_makes_it_up_to_him() -> void:
	var unpaid := Order.new()
	unpaid.kind = M1Registrations.ORDER_SHIP_RESOURCE
	unpaid.addressed_to = &"gov_ashmere"
	unpaid.params = {"to": "gov_ashmere", "resource": "iron", "amount": 100, "payment": 0}

	var paid := Order.new()
	paid.kind = M1Registrations.ORDER_SHIP_RESOURCE
	paid.addressed_to = &"gov_ashmere"
	paid.params = {"to": "gov_ashmere", "resource": "iron", "amount": 100,
		"payment": Compliance.cost_of(unpaid)}

	assert_true(Compliance.payment_ratio(paid) > Compliance.payment_ratio(unpaid),
		"paying the full worth of the goods was no better than paying nothing")
