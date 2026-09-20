extends TestCase

## The colony-side jaw of the Squeeze (#71, SPEC §12.3,
## `docs/mechanics/rebel-sentiment.md`).
##
## 🔒 **Sentiment measures who is blamed, not how bad life is.** Suffering the
## Crown caused raises it; suffering the rebellion caused lowers it.
##
## That is not flavour. Without it a rebelling town's worsening life would drive
## it further away and **no town could ever come home**, which SPEC §12.3 locks
## as possible. Every other property here is ordinary; that one is the reason the
## rest of the rebellion mechanics can exist at all.

const SEED: int = 6143

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
	town.quality_of_life = 0.8
	return town


func _context(towns: Array, month: int = 4) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var state := WorldValues.initial_state()
	state.month = month
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	return context


## A taxed purchase on the books, the way Trade records one.
func _bought(context: ColonyContext, town: Town, tier: StringName, tax: float) -> void:
	context.log.emit(Trade.EVENT_BOUGHT, town.id, context.state.month, {
		"town": String(town.id), "resource": "food", "luxury": false,
		"wanted": 1.0, "quantity": 1.0, "unit_price": 1.0, "rate": 0.1,
		"gross": 1.0, "tax": tax, "spent": 1.0, "tier": String(tier),
	}, WorldPhase.COLONY_MONTH)


func _measure(context: ColonyContext, town: Town, grievances: Grievances = null,
		contacts: Dictionary = {}) -> Dictionary:
	return RebelSentiment.of(town, context, grievances, contacts)


# --- 🔒 Attribution: who is blamed ------------------------------------------

func test_misery_under_the_crown_raises_it() -> void:
	var wretched := _town()
	wretched.quality_of_life = 0.1
	var comfortable := _town()
	comfortable.quality_of_life = 0.95

	var context := _context([wretched])
	var other := _context([comfortable])
	assert_true(float(_measure(context, wretched)["total"])
		> float(_measure(other, comfortable)["total"]),
		"a wretched town under the Crown was no more rebellious than a comfortable one")


func test_misery_under_rebellion_lowers_it() -> void:
	# **The property the whole model exists for.** A rebel town starving with
	# trade gone and troops at the gate blames the rebellion, and that is the
	# PC's foothold — without it SPEC §12.3's peaceful return is decorative.
	var suffering := _town()
	suffering.rebelling = true
	suffering.quality_of_life = 0.1

	var thriving := _town()
	thriving.rebelling = true
	thriving.quality_of_life = 0.95

	assert_true(float(_measure(_context([suffering]), suffering)["quality"]) < 0.0,
		"a rebel town's suffering pushed it further from the Crown")
	assert_true(float(_measure(_context([suffering]), suffering)["quality"])
		< float(_measure(_context([thriving]), thriving)["quality"]),
		"grinding a rebel town down was no argument against rebelling")


func test_the_same_wretchedness_points_both_ways() -> void:
	# Stated as the one comparison that matters: one life, two allegiances.
	var loyal := _town()
	loyal.quality_of_life = 0.15
	var rebel := _town()
	rebel.rebelling = true
	rebel.quality_of_life = 0.15

	var under_crown := float(_measure(_context([loyal]), loyal)["quality"])
	var in_revolt := float(_measure(_context([rebel]), rebel)["quality"])
	assert_true(under_crown > 0.0 and in_revolt < 0.0,
		"the same misery read %f under the Crown and %f in rebellion" % [under_crown, in_revolt])


# --- 🔒 Tax is resented per transaction, by tier ----------------------------

func test_a_town_that_buys_nothing_resents_nothing() -> void:
	# §10.2: towns resent tax **as they pay it**, not as the rate is set.
	var town := _town()
	var context := _context([town])
	assert_almost_eq(float(_measure(context, town)["tax"]), 0.0, 0.0001,
		"a town that bought nothing all month resented the duty anyway")


func test_a_duty_on_what_a_town_cannot_do_without_bites_hardest() -> void:
	# **Taxation bites where a town is cornered, not where a rate is high.**
	var cornered := _town()
	var indulgent := _town()
	var one := _context([cornered])
	var two := _context([indulgent])
	# **A month's duty, not a fortune.** Four hundred gold of duty is forty times
	# what a town actually pays, so both tiers hit `TAX_CEILING` and read alike —
	# which is the cap doing its job and this test measuring nothing.
	_bought(one, cornered, Trade.TIER_NEED, 10.0)
	_bought(two, indulgent, Trade.TIER_WANT, 10.0)

	assert_true(float(_measure(one, cornered)["tax"]) > float(_measure(two, indulgent)["tax"]),
		"the same duty on bread and on rum was resented alike")


func test_the_luxury_rule_falls_out_rather_than_being_written() -> void:
	# SPEC §10.2 says luxury taxes cause much less sentiment. Nothing here knows
	# what a luxury is — it is simply bought in the wants tier and therefore
	# weighs least.
	assert_true(float(RebelSentiment.TIER_WEIGHT["want"])
		< float(RebelSentiment.TIER_WEIGHT["objective"]),
		"a comfort was resented as much as the governor's project")
	assert_true(float(RebelSentiment.TIER_WEIGHT["objective"])
		< float(RebelSentiment.TIER_WEIGHT["need"]),
		"the governor's project was resented as much as bread")


func test_one_enormous_month_cannot_rebel_a_town_on_its_own() -> void:
	var town := _town()
	var context := _context([town])
	_bought(context, town, Trade.TIER_NEED, 100_000.0)
	assert_true(float(_measure(context, town)["tax"]) <= RebelSentiment.TAX_CEILING + 0.001,
		"a single freakish month of trade carried a town straight to rebellion")


# --- 🔒 Grievances decay rather than expiring -------------------------------

func test_a_grievance_fades_instead_of_vanishing() -> void:
	# A sentiment that drops several points in one month for no visible reason is
	# confusing, and the Diplomat has to be able to describe a trend truthfully.
	var grievances := Grievances.new()
	grievances.add(&"ashmere", Grievances.REFUSED, 10, 12.0, 6)

	var readings: Array = []
	for month in range(10, 17):
		readings.append(grievances.weight_for(&"ashmere", month))

	for at in range(1, readings.size()):
		assert_true(float(readings[at]) <= float(readings[at - 1]) + 0.0001,
			"a grievance grew between month %d and %d" % [at - 1, at])
	assert_almost_eq(float(readings[0]), 12.0, 0.0001, "it did not start at its full weight")
	assert_almost_eq(float(readings[6]), 0.0, 0.0001, "it was still sore after it ran out")
	assert_true(float(readings[3]) > 0.0 and float(readings[3]) < 12.0,
		"it went straight from full to nothing instead of fading")


func test_grievances_stack() -> void:
	var grievances := Grievances.new()
	grievances.add(&"ashmere", Grievances.REFUSED, 10, 9.0, 12)
	var one := grievances.weight_for(&"ashmere", 10)
	grievances.add(&"ashmere", Grievances.PROMISE_BROKEN, 10, 14.0, 12)
	assert_true(grievances.weight_for(&"ashmere", 10) > one,
		"a second slight in the same month counted for nothing")


func test_a_town_can_say_what_it_is_sore_about() -> void:
	# Never a number, but the Diplomat has to be able to name the thing.
	var grievances := Grievances.new()
	grievances.add(&"ashmere", Grievances.REFUSED, 10, 9.0, 12)
	grievances.add(&"ashmere", Grievances.PROMISE_BROKEN, 12, 14.0, 12)
	var sore := grievances.active(&"ashmere", 13)
	assert_eq(sore.size(), 2, "the town had forgotten what it was angry about")
	assert_eq(String(sore[0]), String(Grievances.PROMISE_BROKEN),
		"it named the older slight first")


func test_what_is_spent_is_forgotten() -> void:
	var grievances := Grievances.new()
	grievances.add(&"ashmere", Grievances.REFUSED, 1, 9.0, 4)
	grievances.forget_spent(20)
	assert_empty(Array(grievances.active(&"ashmere", 20)),
		"a fifty-year run would carry every slight it ever had")


# --- 🔒 One rule for every resident contact ---------------------------------

## **With a role, the way the roster builds them.** Prominence is derived from
## it (§4), so a fixture that left it blank would be testing a man the town has
## never heard of.
func _contact(
	id: StringName,
	loyalty: float,
	town_name: String = "",
	role: StringName = Contact.ROLE_INSTITUTIONAL,
) -> Contact:
	var contact := Contact.new(id)
	contact.role = role
	contact.relationship.loyalty = loyalty
	contact.town = town_name
	return contact


func test_a_slighted_governor_pushes_his_town_towards_rebellion() -> void:
	var town := _town()
	var context := _context([town])
	var loved := {"gov_ashmere": _contact(&"gov_ashmere", 95.0)}
	var loathing := {"gov_ashmere": _contact(&"gov_ashmere", 5.0)}

	assert_true(float(_measure(context, town, null, loathing)["contacts"])
		> float(_measure(context, town, null, loved)["contacts"]),
		"how the governor feels about the PC made no difference to his town")


func test_a_well_kept_governor_is_a_brake() -> void:
	var town := _town()
	var context := _context([town])
	var loved := {"gov_ashmere": _contact(&"gov_ashmere", 100.0)}
	assert_true(float(_measure(context, town, null, loved)["contacts"]) < 0.0,
		"a devoted governor did nothing to hold his town")


func test_everyone_else_weighs_lightly_and_by_the_same_rule() -> void:
	# Being a jerk to the clergyman is mechanically dangerous, which is as it
	# should be — but he is not the governor.
	var town := _town()
	var context := _context([town])
	var governor := {"gov_ashmere": _contact(&"gov_ashmere", 5.0)}
	var clergyman := {"clergy": _contact(&"clergy", 5.0, town.display_name)}

	var from_clergy := float(_measure(context, town, null, clergyman)["contacts"])
	assert_true(from_clergy > 0.0, "a resentful clergyman counted for nothing at all")
	assert_true(from_clergy < float(_measure(context, town, null, governor)["contacts"]),
		"the clergyman weighed as heavily as the governor")


func test_the_crowns_officers_push_nobody() -> void:
	# They are an ocean away and name no town. A Chancellor the PC has insulted
	# does not rebel anybody's colonists.
	var town := _town()
	var context := _context([town])
	var chancellor := {"chancellor": _contact(&"chancellor", 0.0)}
	assert_almost_eq(float(_measure(context, town, null, chancellor)["contacts"]), 0.0, 0.0001,
		"the Chancellor's opinion reached a town he has never seen")


# --- 🔒 Tall and wide fail differently --------------------------------------

## The same town, developed and not, with the same thing driving it.
func _with_stakes(buildings: Array, trade: float, loyalty: float) -> Dictionary:
	var town := _town()
	town.buildings = PackedStringArray(buildings)
	town.traded_value = trade
	var contacts := {"gov_ashmere": _contact(&"gov_ashmere", loyalty, "", Contact.ROLE_GOVERNOR)}
	return _measure(_context([town]), town, null, contacts)


func test_development_raises_the_stakes_rather_than_the_sentiment() -> void:
	# 🔒 **Building a granary does not make a town want independence.** It makes
	# the town matter more, so whatever is already driving it drives it harder.
	var hamlet := _with_stakes([], 0.0, 5.0)
	var grand := _with_stakes(["granary", "sawmill", "church"], 4000.0, 5.0)

	assert_almost_eq(float(hamlet["contacts"]), float(grand["contacts"]), 0.0001,
		"development changed what the governor's regard was worth, which is not what it does")
	assert_true(float(grand["stakes"]) > float(hamlet["stakes"]),
		"a town with three buildings and heavy trade had no more at stake than a hamlet")
	assert_true(float(grand["total"]) > float(hamlet["total"]),
		"the same slighted governor moved a developed town no further than a hamlet")


func test_and_it_holds_a_contented_town_down_harder() -> void:
	# The other direction, which an additive term could never do. **If the famous
	# men of a town are all loyal to the Crown there is not much rebel sentiment
	# in it** — and there is least of all in a town with everything to lose.
	var hamlet := _with_stakes([], 0.0, 100.0)
	var grand := _with_stakes(["granary", "sawmill", "church"], 4000.0, 100.0)
	assert_true(float(grand["contacts"]) < 0.0, "the fixture's governor is not devoted")
	assert_true(float(grand["total"]) <= float(hamlet["total"]),
		"development made a contented town restless, so it is a contributor again")


# --- 🔒 A neighbour in rebellion --------------------------------------------

func test_a_prosperous_rebel_neighbour_is_an_advertisement() -> void:
	var quiet := _town(&"ashmere")
	var thriving_rebel := _town(&"bellhaven")
	thriving_rebel.rebelling = true
	thriving_rebel.quality_of_life = 0.95

	var crushed_rebel := _town(&"bellhaven")
	crushed_rebel.rebelling = true
	crushed_rebel.quality_of_life = 0.05

	var watching := _context([quiet, thriving_rebel])
	var other := _context([_town(&"ashmere"), crushed_rebel])

	assert_true(float(_measure(watching, quiet)["neighbours"]) > 0.0,
		"a rebel next door was no encouragement at all")
	assert_true(float(_measure(watching, quiet)["neighbours"])
		> float(_measure(other, other.colony.by_id(&"ashmere"))["neighbours"]),
		"a rebellion being ground down was as tempting as one that is working")


func test_a_rebel_town_is_not_encouraged_by_itself() -> void:
	var rebel := _town()
	rebel.rebelling = true
	rebel.quality_of_life = 0.9
	assert_almost_eq(float(_measure(_context([rebel]), rebel)["neighbours"]), 0.0, 0.0001,
		"a rebel town talked itself further into rebellion")


# --- 🔒 Fresh each month, and it survives a reload --------------------------

func test_it_is_computed_fresh_with_no_carry_over() -> void:
	# §3: no base-and-modifier machinery and no carry-over term. Two towns in
	# identical circumstances agree, whatever either of them was last month.
	var settled := _town()
	settled.rebel_sentiment = 0.0
	var seething := _town()
	seething.rebel_sentiment = 95.0

	assert_almost_eq(
		float(_measure(_context([seething]), seething)["total"]),
		float(_measure(_context([settled]), settled)["total"]),
		0.0001,
		"last month's figure was still in this month's answer")


func test_grievances_survive_a_reload() -> void:
	# Ironman means there is no second chance to notice, and a reload that forgot
	# them would hand the player a colony that had forgiven everything.
	var grievances := Grievances.new()
	grievances.add(&"ashmere", Grievances.REFUSED, 6, 9.0, 12)
	grievances.add(&"bellhaven", Grievances.PROMISE_BROKEN, 7, 14.0, 20)

	var restored := Grievances.from_dict(grievances.to_dict())
	for month in range(6, 30):
		assert_almost_eq(restored.weight_for(&"ashmere", month),
			grievances.weight_for(&"ashmere", month), 0.0001,
			"Ashmere came back with a different memory in month %d" % month)
		assert_almost_eq(restored.weight_for(&"bellhaven", month),
			grievances.weight_for(&"bellhaven", month), 0.0001,
			"Bellhaven came back with a different memory in month %d" % month)


func test_the_same_town_twice_gives_the_same_answer() -> void:
	var town := _town()
	var context := _context([town])
	_bought(context, town, Trade.TIER_NEED, 90.0)
	var contacts := {"gov_ashmere": _contact(&"gov_ashmere", 30.0)}
	assert_almost_eq(
		float(_measure(context, town, null, contacts)["total"]),
		float(_measure(context, town, null, contacts)["total"]),
		0.0001, "the same month measured twice came out differently")


func test_it_stays_inside_its_bounds() -> void:
	var furious := _town()
	furious.quality_of_life = 0.0
	furious.buildings = PackedStringArray(["a", "b", "c", "d", "e", "f"])
	furious.traded_value = 90_000.0
	var context := _context([furious])
	_bought(context, furious, Trade.TIER_NEED, 90_000.0)
	var loathing := {"gov_ashmere": _contact(&"gov_ashmere", 0.0)}

	var total := float(_measure(context, furious, null, loathing)["total"])
	assert_true(total <= RebelSentiment.MAXIMUM and total >= RebelSentiment.MINIMUM,
		"sentiment reached %f, outside its own bounds" % total)


# --- 🔒 Harsh orders (§4) ---------------------------------------------------

## Put the compliance event on the log the way the order driver does, run the
## grievance driver over it, and return what the town now holds.
##
## **Through `emit`, because there is no other way in.** My first version called
## `log.append`, which does not exist — so nothing reached the log, the three
## negative assertions passed against an empty one, and only the positive case
## gave the game away. A test that cannot fail is worse than no test.
func _grieve(kind: StringName, harsh: bool, outcome: StringName, payment: Variant = null) -> float:
	var town := _town()
	var context := _context([town])
	var params: Dictionary = {"resource": "iron", "amount": 20}
	if payment != null:
		params["payment"] = payment
	var order := Order.new(kind, &"gov_ashmere", params, context.state.month)
	order.harsh = harsh

	context.log.emit(
		Compliance.OUTCOME_EVENTS[outcome], &"gov_ashmere", context.state.month,
		{"order": order.to_dict(), "outcome": String(outcome)}, WorldPhase.RECKONING
	)

	var grievances := Grievances.new()
	var driver := GrievanceDriver.new(context.colony, grievances)
	driver.on_phase(WorldPhase.RECKONING, context.state, context.log, RngStreams.new(SEED))
	return grievances.weight_for(town.id, context.state.month)


func test_a_harsh_order_the_town_bore_is_a_grievance() -> void:
	# **The gap this closes.** `harsh_order` has carried a weight and a duration
	# since #71 and nothing anywhere raised it, so a contributor the doc names was
	# inert — the same shape as the building effects nothing weighed.
	assert_true(
		_grieve(M1Registrations.ORDER_SHIP_RESOURCE, true, Compliance.COMPLY) > 0.0,
		"a town stripped by command held nothing against the Crown")


func test_the_same_order_written_as_a_request_is_not() -> void:
	assert_almost_eq(
		_grieve(M1Registrations.ORDER_SHIP_RESOURCE, false, Compliance.COMPLY), 0.0, 0.0001,
		"a governor asked politely still left his town resenting the Crown")


func test_a_harsh_order_refused_costs_the_town_nothing() -> void:
	# 🔒 **A refusal is news the moment it is written; a harsh order is only a
	# grievance once it lands.** A governor who refuses to strip his own stores
	# has spared his people — his loyalty pays for that instead.
	assert_almost_eq(
		_grieve(M1Registrations.ORDER_SHIP_RESOURCE, true, Compliance.REFUSE), 0.0, 0.0001,
		"a town resented an order its governor never carried out")


func test_a_harsh_order_partly_borne_still_counts() -> void:
	assert_true(
		_grieve(M1Registrations.ORDER_SHIP_RESOURCE, true, Compliance.PARTIAL) > 0.0,
		"half the stores went and the town minded none of it")


func test_it_is_the_harshness_and_not_the_payment() -> void:
	# Declared by the letter, never inferred from the order: an unpaid shipment
	# the PC asked for politely is a poor bargain, not a command.
	assert_almost_eq(
		_grieve(M1Registrations.ORDER_SHIP_RESOURCE, false, Compliance.COMPLY, 0), 0.0, 0.0001,
		"an unpaid shipment was read as a command because of its price")
