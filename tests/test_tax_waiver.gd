extends TestCase

## The clergy's tax holidays (#278, `docs/mechanics/institutional-contacts.md`
## §3).
##
## 🔒 **A rate that reverts on its own**, which nothing in SPEC §10.2 could
## express — rates there are standing, a base plus per-resource overrides, with
## nothing that expires.
##
## 🔒 **Nothing is scheduled in advance.** The Author's second ruling: the waiver
## begins the month the PC agrees. There is no scheduled-future-event mechanism
## here and there must not be one — a general scheduler standing up for a single
## caller is a system nobody asked for.
##
## 🔒 **A resource under protest keeps its duty.** The Author's third ruling, and
## nearly definitional: a protest is a town refusing the Crown's duty, so there is
## no duty flowing to waive. *A colony in protest does not get a holiday from the
## thing it is protesting.*

const SEED: int = 7714

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


func _state() -> WorldState:
	var state := WorldValues.initial_state()
	return state


func _context(state: WorldState, log: EventLog, colony: Colony = null) -> ColonyContext:
	var context := ColonyContext.new(state, log, RngStreams.new(SEED), null)
	context.colony = colony
	return context


func _town(id: StringName = &"ashmere") -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 12
	return town


func _colony(town: Town) -> Colony:
	var colony := Colony.new()
	colony.add(town)
	return colony


# --- 🔒 A duty set aside, and a duty that comes back ------------------------

func test_a_duty_is_charged_until_it_is_waived() -> void:
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)

	var authored := context.tax_rate(&"furs")
	assert_true(authored > 0.0, "nothing is taxed at all, so this proves nothing")

	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001,
		"the duty was set aside and the trade still paid it")


func test_it_reverts_on_its_own() -> void:
	# 🔒 The acceptance line, and the whole reason this is new machinery: a rate
	# in §10.2 is standing, and this one is not.
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)
	var authored := context.tax_rate(&"furs")

	TaxWaiver.grant(state, log, &"furs", 2)
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001)

	TaxWaiver.advance(state, log)
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001,
		"a two-month waiver was over after one")

	TaxWaiver.advance(state, log)
	assert_almost_eq(context.tax_rate(&"furs"), authored, 0.0001,
		"the duty never came back, so the waiver was a rate change")


func test_the_duty_coming_back_is_said_out_loud() -> void:
	# 🔒 Seam A. A duty returning is a rise the towns will feel
	# (`trade-protests.md` §3), and a rise nobody announced is the shape of a
	# colony being surprised by its own government.
	var state := _state()
	var log := EventLog.new()
	TaxWaiver.grant(state, log, &"furs", 1)
	TaxWaiver.advance(state, log)

	assert_eq(log.of_type(TaxWaiver.EVENT_ENDED).size(), 1,
		"a duty came back in silence")


func test_a_waiver_never_touches_a_trade_it_did_not_name() -> void:
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)
	var tea := context.tax_rate(&"tea")

	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	assert_almost_eq(context.tax_rate(&"tea"), tea, 0.0001,
		"a festival for furs relieved the tea trade as well")


# --- 🔒 The holy day is one key, not a loop --------------------------------

func test_a_holy_day_waives_everything() -> void:
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)

	TaxWaiver.grant(state, log, TaxWaiver.ALL, TaxWaiver.HOLY_DAY_MONTHS)
	for id in ResourceCatalogue.ids():
		assert_almost_eq(context.tax_rate(StringName(id)), 0.0, 0.0001,
			"the holy day did not reach %s" % id)


func test_a_holy_day_covers_a_resource_nobody_thought_of() -> void:
	# 🔒 **One key, and that is why.** A loop over the catalogue would cover
	# whatever was in it the day somebody wrote the loop; this covers a resource
	# added next year without anybody remembering to cover it.
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)
	TaxWaiver.grant(state, log, TaxWaiver.ALL, 1)

	assert_almost_eq(context.tax_rate(&"a_thing_nobody_has_invented_yet"), 0.0, 0.0001,
		"the holy day knows a list of resources, which is a list that will go stale")


func test_a_holy_day_ends_as_one_thing() -> void:
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)
	TaxWaiver.grant(state, log, TaxWaiver.ALL, 1)
	TaxWaiver.advance(state, log)

	assert_true(context.tax_rate(&"furs") > 0.0, "the holy day never ended")
	assert_eq(log.of_type(TaxWaiver.EVENT_ENDED).size(), 1,
		"ending one holy day took one event per resource in the catalogue")


# --- 🔒 A resource under protest keeps its duty -----------------------------

func test_a_protested_resource_keeps_its_duty_through_a_festival() -> void:
	var state := _state()
	var log := EventLog.new()
	var town := _town()
	town.protests = ["furs"]
	var context := _context(state, log, _colony(town))
	var authored := TaxRates.rate_for(state, &"furs")

	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	assert_almost_eq(context.tax_rate(&"furs"), authored, 0.0001,
		"a town refusing the duty was given relief from it")


func test_a_colony_in_protest_gets_no_holiday_from_what_it_protests() -> void:
	# 🔒 The Author's third ruling, in the case it actually bites. A holy day
	# waives everything *else*.
	var state := _state()
	var log := EventLog.new()
	var town := _town()
	town.protests = ["tea"]
	var context := _context(state, log, _colony(town))
	var authored := TaxRates.rate_for(state, &"tea")

	TaxWaiver.grant(state, log, TaxWaiver.ALL, TaxWaiver.HOLY_DAY_MONTHS)
	assert_almost_eq(context.tax_rate(&"tea"), authored, 0.0001,
		"the colony got a holiday from the very thing it was protesting")
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001,
		"one protest cancelled the holy day for everything else too")


func test_the_exemption_is_the_colony_s_and_not_one_town_s() -> void:
	# §10.2: there are no per-town rates, so one town's protest exempts the
	# resource everywhere. A per-town answer would be a per-town rate wearing a
	# different name.
	var state := _state()
	var log := EventLog.new()
	var protesting := _town(&"ashmere")
	protesting.protests = ["furs"]
	var colony := _colony(protesting)
	colony.add(_town(&"kettleburn"))
	var context := _context(state, log, colony)

	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	assert_true(context.tax_rate(&"furs") > 0.0,
		"the waiver reached furs because a second town was not protesting")


func test_a_waiver_still_reaches_a_colony_that_protests_nothing() -> void:
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log, _colony(_town()))
	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001,
		"a quiet colony was refused its festival")


# --- 🔒 What a town is used to paying is not what it paid this month --------

func test_a_waiver_does_not_reset_what_the_towns_are_used_to() -> void:
	# 🔒 **The trap.** `TradeProtest` measures a rise against the rate a town has
	# got used to. If a three-month holiday reset that, the duty coming back
	# would read as a rise on every trade at once and the colony would protest
	# its way out of a gift.
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log, _colony(_town()))
	var familiar := TradeProtest.familiar_rate(state, &"furs")

	TaxWaiver.grant(state, log, &"furs", TaxWaiver.FESTIVAL_MONTHS)
	TradeProtest.settle_familiarity(context)

	assert_almost_eq(TradeProtest.familiar_rate(state, &"furs"), familiar, 0.0001,
		"a tax holiday taught the colony to expect one")


# --- 🔒 Nothing is scheduled --------------------------------------------

func test_it_begins_the_month_it_is_granted() -> void:
	# The Author's second ruling. There is no start date anywhere in this, and a
	# waiver that could begin later would be the scheduler he ruled out.
	var state := _state()
	var log := EventLog.new()
	var context := _context(state, log)
	TaxWaiver.grant(state, log, &"furs", 1)
	assert_almost_eq(context.tax_rate(&"furs"), 0.0, 0.0001,
		"the waiver was granted and did not take effect until some later month")


func test_nothing_in_the_waiver_names_a_month_to_start() -> void:
	var file := FileAccess.open("res://sim/economy/tax_waiver.gd", FileAccess.READ)
	assert_true(file != null, "the waiver is gone")
	var source := file.get_as_text()
	file.close()
	# **Identifiers, not prose.** The file says the word *scheduled* several times,
	# explaining at length that there is no scheduler; what would betray one is a
	# field holding a month it has not reached yet.
	for forbidden in ["starts_month", "begins_month", "start_month", "from_month"]:
		assert_false(source.contains(forbidden),
			"`%s` is a scheduled-future-event mechanism, which §3 rules out" % forbidden)
	assert_false(source.contains("var _pending"),
		"the waiver holds something not yet in effect, which is a scheduler")


# --- 🔒 The longer of two wins ---------------------------------------------

func test_a_second_festival_does_not_cut_the_first_short() -> void:
	var state := _state()
	var log := EventLog.new()
	TaxWaiver.grant(state, log, &"furs", 3)
	TaxWaiver.grant(state, log, &"furs", 1)
	assert_eq(TaxWaiver.months_left(state, &"furs"), 3,
		"a shorter grant replaced a longer one already running")


func test_a_longer_one_extends_it() -> void:
	var state := _state()
	var log := EventLog.new()
	TaxWaiver.grant(state, log, &"furs", 1)
	TaxWaiver.grant(state, log, &"furs", 4)
	assert_eq(TaxWaiver.months_left(state, &"furs"), 4)


# --- 🔒 It survives the save -----------------------------------------------

func test_a_running_waiver_survives_the_save() -> void:
	# 🔒 Why this lives in `WorldState.values` rather than a structure of its
	# own: it serialises with the save and appears in the world diff, and there
	# is no second place that could disagree about what is running.
	var run := RunState.new_run(SEED)
	TaxWaiver.grant(run.world, run.log, &"furs", 2)

	var restored := WorldState.from_dict(run.world.to_dict())
	assert_eq(TaxWaiver.months_left(restored, &"furs"), 2,
		"the festival was forgotten by loading the game")
