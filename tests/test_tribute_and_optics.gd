extends TestCase

## Tribute: the demand, its answers, and two optics (#210, SPEC §8.4, §12.3,
## §14.1; `docs/mechanics/rival-pressure.md` §4, `docs/mechanics/prestige.md` §4,
## `docs/mechanics/crown-demands.md` §6).
##
## 🔒 **A duke spawning is dimension 4 and nothing else.** There is no second
## clock: he arrives when the bucket says more sources are demanding, staggered
## because one dimension is drawn a year and unable to bunch because §7 caps that
## dimension at twice in four years.
##
## 🔒 **The money is not counted twice.** The gold a payment moves lands in
## `net_position` like any other spending; the optic is for the embarrassment
## alone, and it never decays.
##
## 🔒 **A rebel town has not left the colony** (§12.3). The only way out is
## `Colony.lost`, and it is what the lost-town optic fires on.

const SEED: int = 9154

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	return ColonyContext.new(run.world, run.log, run.streams, run.map)


## A growth book with dimension 4 pushed to a level.
func _growth(reach: int) -> DemandGrowth:
	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.REACH)] = reach
	return growth


func _letter_context(run: RunState, duke: Contact, growth: DemandGrowth) -> LetterContext:
	var context := LetterContext.new(run.world, duke)
	context.demands = growth
	context.measures = ColonyMeasures.for_contact(run, duke)
	context.log = run.log
	return context


# --- 🔒 Dimension 4, and no second clock ------------------------------------

func test_no_rival_writes_until_more_hands_are_out() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	assert_false(ContentRegistry.test_condition(
			"a_rival_has_a_hand_out", {}, _letter_context(run, duke, _growth(0))),
		"a foreign power wrote for tribute in the colony's first year")


func test_a_rival_writes_once_dimension_four_has_grown_enough() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	var grown := _growth(DemandSchedule.ASKERS_FOR_RIVALS)
	assert_true(DemandSchedule.rivals_are_asking(grown),
		"the fixture did not push the dimension far enough")
	assert_true(ContentRegistry.test_condition(
			"a_rival_has_a_hand_out", {}, _letter_context(run, duke, grown)),
		"more hands were out and none of them was a rival's")


func test_the_dukes_arrive_on_the_bucket_and_nothing_else() -> void:
	# 🔒 The acceptance: **no second clock anywhere.** Asserted on the content,
	# because a schedule of their own would be written in a trigger.
	for id in content.ids("triggers"):
		var trigger: Dictionary = content.record("triggers", String(id))
		if not String(trigger.get("letter", "")).begins_with("rival_duke"):
			continue
		var gates: PackedStringArray = PackedStringArray()
		for entry in trigger.get("conditions", []):
			for name in entry:
				gates.append(String(name))
		assert_true(gates.has("a_rival_has_a_hand_out"),
			"%s does not wait for the bucket at all" % id)

		# ⚠️ **`he_is_free_to_demand` is allowed, and it is not a second clock**
		# (#284). A clock is a timetable of the duke's own — he writes every so
		# often on his own schedule, and the bucket stops being what decides.
		# This is the opposite: it is **the player having acted**, once, through
		# a patron, and it says nothing about when he would otherwise write.
		# Afterwards the bucket is again the only thing deciding.
		#
		# Anything else here is a timetable, and the guard still refuses it.
		for gate in gates:
			assert_true(
				gate == "a_rival_has_a_hand_out" or gate == "he_is_free_to_demand",
				"%s decides for itself when a duke writes: %s" % [id, gate])


func test_the_marshal_is_asking_before_any_duke_is() -> void:
	# The order of §6's catalogue: Crown officers who were not asking before,
	# and then the sharpest version, a foreign power.
	assert_true(DemandSchedule.ASKERS_FOR_RIVALS > DemandBook.ASKERS_FOR_GOODS,
		"a run meets a rival duke before it meets a requisition")


# --- 🔒 What he asks for scales with his band -------------------------------

func test_a_duke_who_is_being_paid_asks_less_than_one_who_is_not() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	var grown := _growth(DemandSchedule.ASKERS_FOR_RIVALS)

	duke.relationship.loyalty = RivalDuke.HIGH_AT + 5.0
	var reasonable := int(ContentRegistry.supply_param(
		"tribute_amount", {}, _letter_context(run, duke, grown)))

	duke.relationship.loyalty = RivalDuke.MEDIUM_AT + 1.0
	var dearer := int(ContentRegistry.supply_param(
		"tribute_amount", {}, _letter_context(run, duke, grown)))

	assert_true(reasonable > 0, "a duke on good terms asked for nothing at all")
	assert_true(dearer > reasonable,
		"a duke who had stopped being paid asked no more than one who had not")


# --- 🔒 A duke asks for gold, and never for goods (SPEC §8.4, v3.0) ---------
#
# **Only the Crown trades with these colonies** (§10.1), so a duke paid in goods
# would mean his ships docking at a Crown wharf to collect them. The gold comes
# out of the Crown's purse, which is also why there is no governor in the loop:
# the Crown may ask for *resources* and that takes a second letter to a man who
# can refuse, but a duke asks for money the PC never had in his hands.

func test_nothing_in_the_post_lets_a_duke_name_a_resource() -> void:
	# 🔒 The guard. `tribute_resource` is gone, and a letter that asked for one
	# again would be a foreign hold at a Crown wharf.
	assert_false(ContentRegistry.has_param_source("tribute_resource"),
		"something still picks a resource for a duke to demand")

	for id in ["rival_duke.tribute_demand", "rival_duke_montargis.tribute_demand",
			"rival_duke_vasterholm.tribute_demand"]:
		var record: Dictionary = content.record("letters", id)
		assert_false(record.get("params", {}).has("resource"),
			"%s still declares a resource for the duke to ask for" % id)


func test_what_he_asks_for_is_gold_and_is_the_crowns_to_pay() -> void:
	# 🔒 It is an ordinary gold promise, so it lands on `net_position` and lowers
	# Crown Standing *and* prestige together (`rival-pressure.md` §4).
	var order := Order.new(
		M1Registrations.ORDER_PAY_TRIBUTE, &"rival_duke",
		{"amount": 400.0, "months": 9})

	var promise := PromiseBook.from_order(order, 3)
	assert_true(promise != null, "agreeing to pay a duke promised nobody anything")
	assert_eq(promise.kind, &"gold", "tribute was promised in something other than gold")
	assert_eq(promise.payer, Promise.PAYER_CROWN,
		"a governor was asked to find the money for a duke")


func test_the_figure_he_names_is_gold_and_not_a_count_of_goods() -> void:
	# It always was gold underneath — `tribute_amount` computed the Crown's own
	# demand scaled by his band and then divided it by a resource price on the
	# way out. The division is what is gone.
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = RivalDuke.HIGH_AT + 5.0
	var grown := _growth(DemandSchedule.ASKERS_FOR_RIVALS)

	var asked := float(ContentRegistry.supply_param(
		"tribute_amount", {}, _letter_context(run, duke, grown)))
	assert_almost_eq(asked,
		DemandSchedule.gold_target(grown) * RivalDuke.tribute_multiple(RivalDuke.HIGH),
		0.01,
		"the duke's ask is not the Crown's own demand scaled by his band")


# --- 🔒 Paying fires the optic once, and the money is not counted twice -----

func test_paying_fires_the_tribute_optic_exactly_once() -> void:
	var run := _run()
	var before := OpticsRegister.debt_in(run.log)

	var executor := TributeExecutor.new()
	var intent := Intent.new()
	intent.kind = TributeExecutor.KIND
	intent.data = {"to": "rival_duke", "resource": "iron", "amount": 60, "months": 9}
	executor.execute(intent, run.world, run.log)

	assert_eq(run.log.of_type(OpticsRegister.EVENT_TRIBUTE_PAID).size(), 1,
		"accepting a duke's demand embarrassed the Crown a number of times other than once")
	assert_almost_eq(
		OpticsRegister.debt_in(run.log) - before,
		OpticsRegister.price_of(OpticsRegister.EVENT_TRIBUTE_PAID), 0.0001,
		"the court charged something other than the price of the thing")


func test_the_optic_is_for_the_embarrassment_and_not_the_money() -> void:
	# 🔒 The gold already lands in `net_position` when it is spent. An optic that
	# scaled with the amount would charge the PC twice for one payment.
	var small := Intent.new()
	small.kind = TributeExecutor.KIND
	small.data = {"to": "rival_duke", "resource": "iron", "amount": 5, "months": 9}
	var large := Intent.new()
	large.kind = TributeExecutor.KIND
	large.data = {"to": "rival_duke", "resource": "iron", "amount": 5_000, "months": 9}

	var cheap := _run()
	TributeExecutor.new().execute(small, cheap.world, cheap.log)
	var dear := _run()
	TributeExecutor.new().execute(large, dear.world, dear.log)

	assert_almost_eq(
		OpticsRegister.debt_in(cheap.log), OpticsRegister.debt_in(dear.log), 0.0001,
		"a larger payment embarrassed the Crown more, which charges the gold twice")


func test_the_tribute_optic_never_decays() -> void:
	# `prestige.md` §4: an optic is scored once when it happens and never fades.
	var run := _run()
	var intent := Intent.new()
	intent.kind = TributeExecutor.KIND
	intent.data = {"to": "rival_duke", "resource": "iron", "amount": 60, "months": 9}
	TributeExecutor.new().execute(intent, run.world, run.log)

	var owed := OpticsRegister.debt_in(run.log)
	run.world.month += 240
	assert_almost_eq(OpticsRegister.debt_in(run.log), owed, 0.0001,
		"twenty years put a payment to a foreigner out of the court's mind")


func test_refusing_fires_nothing() -> void:
	# 🔒 It costs the duke's loyalty and nothing at court. A PC who refuses is
	# not embarrassing anybody; he is making an enemy.
	var run := _run()
	var before := OpticsRegister.debt_in(run.log)
	var duke: Contact = RivalDuke.all_in(run)[0]
	var was := duke.relationship.loyalty
	duke.relationship.record_deed(Relationship.REFUSED)

	assert_true(duke.relationship.loyalty < was,
		"refusing a duke cost him nothing")
	assert_almost_eq(OpticsRegister.debt_in(run.log), before, 0.0001,
		"refusing a foreigner embarrassed the Crown")


# --- 🔒 A town lost, and the only way out of the colony ---------------------

func test_a_rebel_town_has_not_left_the_colony() -> void:
	# 🔒 SPEC §12.3: in the Crown's eyes it still belongs to the PC, and his job
	# is to bring it back into line. An optic worth three thousand gold must not
	# fire on a thing the spec says has not happened.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.rebel_sentiment = Rebellion.DECLARES_AT + 5.0
	Rebellion.resolve(town, _context(run))

	assert_true(town.rebelling, "the fixture did not rebel")
	assert_true(run.colony.by_id(town.id) != null,
		"a town that declared rebellion was struck off the colony")
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 0,
		"a rebellion was scored at court as a town lost")


func test_losing_a_town_fires_its_optic_once_on_leaving() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var before := OpticsRegister.debt_in(run.log)

	assert_true(run.colony.lost(town, &"rival_duke", "taken", _context(run)),
		"a town could not be taken")
	assert_true(run.colony.by_id(town.id) == null, "a taken town is still the PC's")
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 1,
		"a town was lost a number of times other than once")
	assert_almost_eq(
		OpticsRegister.debt_in(run.log) - before,
		OpticsRegister.price_of(OpticsRegister.EVENT_TOWN_LOST), 0.0001,
		"losing a town cost the Crown's face something other than its price")

	assert_false(run.colony.lost(town, &"rival_duke", "taken again", _context(run)),
		"a town already gone was lost a second time")
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 1,
		"losing a town twice was scored twice")


func test_there_is_exactly_one_way_out_of_the_colony() -> void:
	# 🔒 The day a dev makes rebellion remove a town from the list, an optic
	# worth three thousand gold starts firing on something that has not happened.
	var removers: PackedStringArray = PackedStringArray()
	var inherited: Dictionary = {}
	for entry in RefCounted.new().get_method_list():
		inherited[String(entry["name"])] = true
	for entry in Colony.new().get_method_list():
		var name := String(entry["name"])
		if name.begins_with("_") or inherited.has(name):
			continue
		for taking in ["lost", "remove", "erase", "drop", "leave", "secede"]:
			if name.contains(taking):
				removers.append(name)
	assert_eq(removers, PackedStringArray(["lost"]),
		"the colony has more than one way to stop holding a town: %s"
			% ", ".join(removers))


func test_the_optic_says_who_took_it() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	run.colony.lost(town, &"tribe_test", "burned", _context(run))

	var lost: Array = run.log.of_type(Colony.EVENT_LOST)
	assert_eq(String(lost[0].payload["to"]), "tribe_test",
		"a town was lost to nobody in particular")
	assert_eq(String(lost[0].payload["town"]), String(town.id))


# --- 🔒 The rival specialty: a third door that costs nothing (#284) ---------

func _duke(run: RunState) -> Contact:
	return RivalDuke.all_in(run)[0]


func _company_of(run: RunState, duke: Contact) -> Company:
	var context := _context(run)
	var landed := run.companies.raise_company(
		Company.RIVAL, 40, {"guns": 40.0}, Company.SUPPORTED_ABROAD,
		Vector2i(3, 3), context)
	landed.raised_by = duke.id
	return landed


func _arrivals(run: RunState) -> void:
	SabotageDriver.new(run).on_phase(
		WorldPhase.ARRIVALS, run.world, run.log, run.streams)


# --- Sabotage ----------------------------------------------------------------

func test_the_gift_applies_to_one_named_rival_and_no_other() -> void:
	var run := _run()
	var dukes := RivalDuke.all_in(run)
	assert_true(dukes.size() >= 2, "a run with fewer than two dukes proves nothing")
	var chosen: Contact = dukes[0]
	var spared: Contact = dukes[1]

	assert_true(SabotageDriver.arrange(chosen, run.world, run.log, 4),
		"the patron could not arrange anything")
	assert_true(SabotageDriver.is_sabotaged(run.world, chosen.id, 5),
		"the duke the patron named is having a perfectly good year")
	assert_false(SabotageDriver.is_sabotaged(run.world, spared.id, 5),
		"a patron interfered with a duke nobody named")


func test_it_lasts_a_year_and_then_stops() -> void:
	var run := _run()
	var duke := _duke(run)
	SabotageDriver.arrange(duke, run.world, run.log, 4)

	assert_true(SabotageDriver.is_sabotaged(run.world, duke.id, 4 + 11),
		"his bad year was over inside the year")
	assert_false(SabotageDriver.is_sabotaged(run.world, duke.id, 4 + SabotageDriver.MONTHS),
		"his bad year never ended")


func test_a_sabotaged_company_fights_worse() -> void:
	# 🔒 §5: *they inflict less and they break sooner.* One figure does both,
	# because `Force` is what a company inflicts and what it survives.
	var run := _run()
	var duke := _duke(run)
	var company := _company_of(run, duke)

	var whole := Force.of(company, run.map)
	company.sabotaged = true
	var ruined := Force.of(company, run.map)

	assert_true(whole > 0.0, "the company was worth nothing to begin with")
	assert_true(ruined < whole,
		"a year of a patron's interference cost the duke's men nothing")


func test_the_driver_marks_his_men_and_nobody_elses() -> void:
	var run := _run()
	var dukes := RivalDuke.all_in(run)
	var mine := _company_of(run, dukes[0])
	var theirs := _company_of(run, dukes[1])

	run.world.month = 4
	SabotageDriver.arrange(dukes[0], run.world, run.log, 4)
	run.world.month = 5
	_arrivals(run)

	assert_true(mine.sabotaged, "the duke's own men were untouched")
	assert_false(theirs.sabotaged, "another duke's men were caught up in it")


func test_a_company_raised_during_the_bad_year_is_in_it_too() -> void:
	# It is the duke's affairs that are in disarray, not one body of men.
	var run := _run()
	var duke := _duke(run)
	run.world.month = 4
	SabotageDriver.arrange(duke, run.world, run.log, 4)

	var late := _company_of(run, duke)
	run.world.month = 9
	_arrivals(run)
	assert_true(late.sabotaged,
		"men raised in the ninth month of a ruined year were in fine order")


func test_the_men_recover_when_the_year_is_out() -> void:
	var run := _run()
	var duke := _duke(run)
	var company := _company_of(run, duke)
	run.world.month = 4
	SabotageDriver.arrange(duke, run.world, run.log, 4)
	run.world.month = 5
	_arrivals(run)
	assert_true(company.sabotaged)

	run.world.month = 4 + SabotageDriver.MONTHS
	_arrivals(run)
	assert_false(company.sabotaged, "his men never got over it")


func test_it_survives_the_save() -> void:
	var company := Company.new(&"c1", 1)
	company.sabotaged = true
	assert_true(Company.from_dict(company.to_dict()).sabotaged,
		"a sabotaged year did not survive the save")


# --- 🔒 It cannot undo the latch --------------------------------------------

func test_a_duke_at_minimum_is_unaffected_by_any_of_it() -> void:
	# 🔒 `rival-pressure.md` §3: a duke at minimum is there for the run. **A
	# patron may help the PC survive that; nothing brings a duke back from open
	# war**, and the refusal is at the grant so it can be a letter rather than a
	# gift that quietly does nothing.
	var run := _run()
	var duke := _duke(run)
	duke.relationship = Relationship.new(duke.id, Relationship.MIN_LOYALTY)
	assert_eq(RivalDuke.band_of(duke.loyalty()), RivalDuke.MINIMUM,
		"the fixture duke is not at minimum, so this proves nothing")

	assert_false(SabotageDriver.arrange(duke, run.world, run.log, 4),
		"a patron interfered with a duke already at open war")
	assert_false(SabotageDriver.is_sabotaged(run.world, duke.id, 5),
		"a refused arrangement was arranged anyway")


# --- 🔒 The third door ------------------------------------------------------

func test_the_reply_option_appears_only_while_the_gift_is_live() -> void:
	var run := _run()
	var duke := _duke(run)
	var context := LetterContext.new()
	context.sender = duke
	context.state = run.world
	run.world.month = 5

	var door := {"conditions": [{"a_patron_can_deflect_him": {}}]}
	assert_false(ReplyWizard.may_take(door, context),
		"the third door was open with no patron behind it")

	SabotageDriver.arrange(duke, run.world, run.log, 4)
	assert_true(ReplyWizard.may_take(door, context),
		"the patron arranged it and the door stayed shut")


func test_the_door_is_on_that_dukes_demand_and_no_other() -> void:
	var run := _run()
	var dukes := RivalDuke.all_in(run)
	run.world.month = 5
	SabotageDriver.arrange(dukes[0], run.world, run.log, 4)

	var door := {"conditions": [{"a_patron_can_deflect_him": {}}]}
	var other := LetterContext.new()
	other.sender = dukes[1]
	other.state = run.world
	assert_false(ReplyWizard.may_take(door, other),
		"one patron's arrangement opened a door on a different duke's letter")


func test_taking_it_costs_no_gold_no_loyalty_and_no_optic() -> void:
	# 🔒 **The only answer to a tribute demand that costs nothing.** Pay costs
	# gold and an undecaying optic; refuse costs his loyalty. This costs neither.
	var run := _run()
	var duke := _duke(run)
	var before := duke.loyalty()
	var debt := OpticsRegister.debt_in(run.log)

	var intent := Intent.new()
	intent.kind = DeflectionExecutor.KIND
	intent.data = {"to": String(duke.id)}
	DeflectionExecutor.new().execute(intent, run.world, run.log)

	assert_eq(duke.loyalty(), before,
		"sending the duke to collect elsewhere cost the PC his regard")
	assert_eq(OpticsRegister.debt_in(run.log), debt,
		"the court heard about a thing the patron covered up entirely")
	assert_empty(run.log.of_type(OpticsRegister.EVENT_TRIBUTE_PAID),
		"a deflected demand was recorded as tribute paid")


func test_it_makes_a_gold_promise_of_nothing() -> void:
	# The pay door promises gold; this door promises nothing at all.
	var order := Order.new(
		M1Registrations.ORDER_DEFLECT_TRIBUTE, &"rival_duke", {})
	assert_eq(PromiseBook.from_order(order, 3), null,
		"the third door committed the Crown to something")


func test_he_skips_the_next_demand_and_the_one_after_is_normal() -> void:
	var run := _run()
	var duke := _duke(run)
	var context := LetterContext.new()
	context.sender = duke
	context.state = run.world

	run.world.month = 5
	assert_true(ColonyConditions.he_is_free_to_demand({}, context),
		"he was holding off before anybody deflected anything")

	var intent := Intent.new()
	intent.kind = DeflectionExecutor.KIND
	intent.data = {"to": String(duke.id)}
	DeflectionExecutor.new().execute(intent, run.world, run.log)

	run.world.month = 6
	assert_false(ColonyConditions.he_is_free_to_demand({}, context),
		"he wrote again the month after being sent to collect")

	run.world.month = 5 + DeflectionExecutor.DEMAND_CYCLE
	assert_true(ColonyConditions.he_is_free_to_demand({}, context),
		"the demand after the skipped one never came")


func test_a_skipped_demand_is_not_a_deferred_attack() -> void:
	# 🔒 Two keys. `TributeExecutor` writes `quiet_until` when the PC **pays**,
	# which is about whether he comes; this is about whether he writes. One name
	# for two things is how paying a man quietly came to mean he had stopped
	# asking.
	assert_ne(DeflectionExecutor.SKIPPED_PREFIX, TributeExecutor.DEFERRED_PREFIX,
		"a skipped demand and a deferred attack share a world value")
