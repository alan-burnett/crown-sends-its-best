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
		assert_eq(gates, PackedStringArray(["a_rival_has_a_hand_out"]),
			"%s decides for itself when a duke writes" % id)


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


func test_each_duke_asks_for_the_same_thing_all_run() -> void:
	# Off the sender rather than a die, so the player learns what each of them
	# wants rather than being handed a fresh surprise every time.
	var run := _run()
	var wanted: Dictionary = {}
	for duke in RivalDuke.all_in(run):
		var context := _letter_context(
			run, duke, _growth(DemandSchedule.ASKERS_FOR_RIVALS))
		var first := String(ContentRegistry.supply_param(
			"tribute_resource", {"fallback": "iron"}, context))
		var again := String(ContentRegistry.supply_param(
			"tribute_resource", {"fallback": "iron"}, context))
		assert_eq(first, again, "%s wanted two different things in one month" % duke.id)
		wanted[String(duke.id)] = first


func test_no_duke_asks_for_a_comfort() -> void:
	# A man idling his captains through a long season is not writing about tea.
	var run := _run()
	for duke in RivalDuke.all_in(run):
		var asked := StringName(ContentRegistry.supply_param(
			"tribute_resource", {"fallback": "iron"},
			_letter_context(run, duke, _growth(DemandSchedule.ASKERS_FOR_RIVALS))))
		assert_false(ResourceCatalogue.is_luxury(asked),
			"%s demanded %s as tribute" % [duke.id, asked])
		assert_false(ResourceCatalogue.is_livestock(asked),
			"%s demanded livestock as tribute" % duke.id)


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
