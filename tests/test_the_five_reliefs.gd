extends TestCase

## The Squeeze's five reliefs (#399, `crown-demands.md` §10).
##
## Machinery, callable and tested; what pulls each is content, in #368. 🔒 None
## of them is the draw easing off on its own, and none touches the Crown's war.

const SEED: int = 399

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	run.world.month = 20


func after_each() -> void:
	reset_world()
	content.free()


# --- 1. A targeted break ----------------------------------------------------------

func test_a_break_lifts_his_regard_and_skips_his_next_demand() -> void:
	var steward := run.contact(&"steward")
	var before := steward.loyalty()
	CrownRelief.targeted_break(run, &"steward", run.world.month)
	assert_almost_eq(steward.loyalty(), minf(before + CrownRelief.BREAK_REGARD, Relationship.MAX_LOYALTY), 0.001)

	var book := run.demand_book
	var growth := DemandGrowth.new()
	var log := EventLog.new()
	assert_false(book.advance(DemandBook.FIRST_DEMAND_MONTH, growth, run.streams, log),
		"the Steward's demand arrived after he had been given a break")
	assert_eq(log.of_type(DemandBook.EVENT_SKIPPED).size(), 1)
	assert_false(book.is_pending(DemandBook.FIRST_DEMAND_MONTH), "a skipped demand was left waiting for an answer")

	var issued := false
	for month in range(DemandBook.FIRST_DEMAND_MONTH + 1, DemandBook.FIRST_DEMAND_MONTH + 12):
		if book.advance(month, growth, run.streams, log):
			issued = true
			break
	assert_true(issued, "the demand after the skipped one never came")
	assert_eq(String(book.asker), "steward")


func test_a_break_skips_a_patrons_next_ask_and_not_the_one_after() -> void:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, run.world.month)
	run.add_contact(patron)
	CrownRelief.targeted_break(run, patron.id, run.world.month)
	assert_true(patron.skips_next_ask)

	machine.director._fired_triggers(run)
	var skipped: Array = run.log.of_type(Director.EVENT_ASK_SKIPPED)
	assert_eq(skipped.size(), 1, "the patron's next ask was not the one skipped")
	assert_eq(String(skipped[0].subject), String(patron.id))
	assert_false(patron.skips_next_ask, "the break was not spent on the ask it skipped")

	run.world.month += 24
	machine.director._fired_triggers(run)
	assert_eq(run.log.of_type(Director.EVENT_ASK_SKIPPED).size(), 1, "a second ask was skipped as well")


# --- 2. Crown war relief ----------------------------------------------------------

func test_war_relief_reads_desperation_a_level_lower_for_a_year() -> void:
	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.DESPERATION)] = 2
	var lower := DemandGrowth.new()
	lower.levels[String(DemandGrowth.DESPERATION)] = 1
	var war := float(run.world.get_value(WorldValues.WAR, 0.0))
	run.demands = growth
	CrownRelief.war_relief(run, run.world.month)

	for month in range(run.world.month, run.world.month + CrownRelief.WAR_RELIEF_MONTHS):
		assert_almost_eq(DemandSchedule.refusal_cost(growth, month), DemandSchedule.refusal_cost(lower), 0.0001,
			"refusing in month %d cost more than a level lower" % month)
	assert_almost_eq(DemandSchedule.refusal_cost(growth, run.world.month + CrownRelief.WAR_RELIEF_MONTHS),
		DemandSchedule.refusal_cost(growth), 0.0001, "the relief outlasted its year")
	assert_eq(growth.level_of(DemandGrowth.DESPERATION), 2, "relief changed the axis itself")
	assert_almost_eq(float(run.world.get_value(WorldValues.WAR, 0.0)), war, 0.0001, "relief touched the Crown's war")


# --- 3. Pulling back a hand -------------------------------------------------------

func test_a_hand_pulled_back_stops_asking_until_a_later_draw() -> void:
	var growth := DemandGrowth.new()
	growth.sources = PackedStringArray(["crown", "patron"])
	run.demands = growth
	var book := DemandBook.new()
	var asked_for_goods := false
	for month in range(3, 120):
		book.answer()
		if book.advance(month, growth, run.streams, EventLog.new()) and book.kind == DemandBook.KIND_RESOURCE:
			asked_for_goods = true
	assert_true(asked_for_goods, "the needy officer never asked for goods, so this proves nothing")

	assert_true(CrownRelief.pull_back_a_hand(run, run.world.month))
	assert_eq(growth.sources, PackedStringArray(["patron"]), "a patron's hand was pulled back, or the officer's was not")
	book = DemandBook.new()
	for month in range(3, 120):
		book.answer()
		if book.advance(month, growth, run.streams, EventLog.new()):
			assert_eq(String(book.kind), String(DemandBook.KIND_GOLD), "the withdrawn kind was demanded")
	assert_true(growth.sources_of(DemandGrowth.SOURCE_CROWN) < DemandSchedule.room_for(DemandGrowth.SOURCE_CROWN),
		"a later draw could not turn him needy again")
	assert_false(CrownRelief.pull_back_a_hand(run, run.world.month), "a duke or patron was pulled back")


# --- 4. Goodwill ------------------------------------------------------------------

func test_goodwill_holds_standing_up_and_is_never_gold() -> void:
	var with_it := CrownStanding.new()
	var without := CrownStanding.new()
	with_it.bank_goodwill(15.0)
	for _month in 24:
		with_it.advance(10.0, 500.0)
		without.advance(10.0, 500.0)
	assert_true(with_it.value() >= 15.0, "goodwill of 15 did not keep standing at 15")
	assert_almost_eq(with_it.net_position, without.net_position, 0.0001, "goodwill moved the books")
	assert_eq(String(with_it.band), String(CrownStanding.band_of(with_it.value())), "the band does not read the sum")

	var mid := CrownStanding.new()
	mid.standing = 10.0
	mid.bank_goodwill(15.0)
	assert_eq(String(mid.band), String(CrownStanding.BAND_ALARM), "ten on the books and fifteen of goodwill is not twenty-five")
	# Every way the band moves reads the sum: a month that breaks even, and a
	# judgement of five against him.
	mid.advance(100.0, 100.0)
	assert_eq(String(mid.band), String(CrownStanding.BAND_ALARM), "a month's reckoning forgot the goodwill")
	mid.adjust(-5.0)
	assert_eq(String(mid.band), String(CrownStanding.BAND_ALARM), "a judgement forgot the goodwill")
	mid.bank_goodwill(500.0)
	assert_almost_eq(mid.value(), CrownStanding.MAXIMUM, 0.0001, "the sum was not capped")


# --- 5. Tax forgiveness -----------------------------------------------------------

func _buy_rum(state: WorldState) -> SimEvent:
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 4 * Population.THOUSAND
	town.receive_gold(10_000.0)
	Trade.buy(town, &"rum", 20.0, context)
	return context.log.of_type(Trade.EVENT_BOUGHT)[0]


func test_the_colony_pays_the_forgiven_rate_and_the_crown_books_the_full_one() -> void:
	var state := WorldValues.initial_state()
	state.values[TaxRates.key_for(&"rum")] = 0.12
	var log := EventLog.new()
	TaxRates.forgive(state, log, &"rum")
	assert_almost_eq(TaxRates.colony_rate(state, &"rum"), 0.07, 0.0001)
	assert_almost_eq(TaxRates.rate_for(state, &"rum"), 0.12, 0.0001, "forgiveness moved the Crown's rate")

	var bought := _buy_rum(state)
	var gross := float(bought.payload["gross"])
	assert_almost_eq(float(bought.payload["colony_rate"]), 0.07, 0.0001)
	assert_almost_eq(float(bought.payload["tax"]), gross * 0.12, 0.001, "the Crown did not book its full duty")
	assert_almost_eq(float(bought.payload["colony_tax"]), gross * 0.07, 0.001, "the town did not pay the forgiven rate")
	assert_almost_eq(float(bought.payload["spent"]), gross * 1.07, 0.001)

	TaxRates.forgive(state, log, &"rum")
	assert_almost_eq(TaxRates.colony_rate(state, &"rum"), 0.02, 0.0001, "a second forgiveness did not stack")
	TaxRates.forgive(state, log, &"rum")
	assert_almost_eq(TaxRates.colony_rate(state, &"rum"), 0.0, 0.0001, "the colony saw below nought")
	assert_eq(log.of_type(TaxRates.EVENT_FORGIVEN).size(), 3)


func test_the_ledger_shows_the_crowns_full_duty() -> void:
	var state := WorldValues.initial_state()
	state.values[TaxRates.key_for(&"rum")] = 0.12
	TaxRates.forgive(state, EventLog.new(), &"rum")
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 4 * Population.THOUSAND
	town.receive_gold(10_000.0)
	var deal := Trade.buy(town, &"rum", 20.0, context)
	var ledger := Ledger.of(context.log)
	assert_almost_eq(ledger.page(state.month).received(), float(deal["tax"]), 0.001)
	assert_almost_eq(float(deal["tax"]), float(context.log.of_type(Trade.EVENT_BOUGHT)[0].payload["gross"]) * 0.12, 0.001)


func test_the_town_resents_and_protests_at_the_rate_it_sees() -> void:
	var state := WorldValues.initial_state()
	state.values[TaxRates.key_for(&"rum")] = 0.12
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	var forgiven := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	forgiven.log.emit(Trade.EVENT_BOUGHT, town.id, state.month,
		{"tier": "want", "tax": 12.0, "colony_tax": 7.0}, WorldPhase.COLONY_MONTH)
	var plain := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	plain.log.emit(Trade.EVENT_BOUGHT, town.id, state.month,
		{"tier": "want", "tax": 7.0}, WorldPhase.COLONY_MONTH)
	assert_almost_eq(RebelSentiment._tax(town, forgiven), RebelSentiment._tax(town, plain), 0.0001,
		"the town resented the duty the Crown booked, not the one it paid")

	TaxRates.forgive(state, EventLog.new(), &"rum")
	assert_almost_eq(TradeProtest.familiar_rate(state, &"rum"), 0.07, 0.0001,
		"a protest measured the rate the town does not pay")


# --- 6. Saved -----------------------------------------------------------------

func test_all_five_survive_a_save() -> void:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, run.world.month)
	run.add_contact(patron)
	CrownRelief.targeted_break(run, &"steward", run.world.month)
	CrownRelief.targeted_break(run, patron.id, run.world.month)
	run.demands.sources = PackedStringArray(["crown"])
	CrownRelief.war_relief(run, run.world.month)
	CrownRelief.goodwill(run, run.world.month)
	CrownRelief.forgive(run, &"rum")

	var path := "user://test_the_five_reliefs.save"
	assert_true(SaveGame.save(run, path))
	var loaded := SaveGame.load_run(path)
	SaveGame.delete_save(path)
	assert_eq(loaded["result"], SaveGame.Result.OK, String(loaded["message"]))
	var restored: RunState = loaded["run"]
	assert_true(restored.demand_book.skipping.has("steward"), "the Steward's skipped demand was forgotten")
	assert_true(restored.contact(patron.id).skips_next_ask, "the patron's skipped ask was forgotten")
	assert_eq(restored.demands.war_relief_until, run.demands.war_relief_until)
	assert_almost_eq(restored.standing.goodwill, CrownRelief.GOODWILL, 0.0001)
	assert_almost_eq(TaxRates.forgiven(restored.world, &"rum"), TaxRates.FORGIVENESS, 0.0001)
	assert_eq(restored.state_hash(), run.state_hash())
