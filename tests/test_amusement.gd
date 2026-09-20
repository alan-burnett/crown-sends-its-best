extends TestCase

## Buildings that provide pleasure without trade (#153).
##
## **It is not just another quality-of-life number.** Beer and rum arrive through
## Exchange and can be cut off by a trade protest, a blockade, a rebellion, or
## simply no gold. A theatre cannot be embargoed — so a town with amusement has a
## floor of contentment underneath its luxuries, and the PC can build that floor
## permanently into a colony he cannot feed.
##
## `quality-of-life.md` §4 establishes that pleasure *masks* the shortfall and
## that its power is greatest when life is worst. **Amusement makes bread and
## circuses buildable**, which is SPEC §3.2's satire working exactly as intended
## and should not be balanced away.

const SEED: int = 1649

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


## Every building in the data that amuses anybody.
func _amusements() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in Building.ids():
		if float(Building.find(StringName(id)).effect("amusement", 0.0)) > 0.0:
			out.append(id)
	out.sort()
	return out


## **Funded unless the test is about not being funded** (#151). A colony month
## settles upkeep before its phases, so a penniless town's theatre is dark before
## anybody can enjoy it — which is correct, and would make every test here a test
## of upkeep.
func _town(gold: float, stock: Dictionary = {}, buildings: Array = []) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 10
	town.receive_gold(gold)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	for id in buildings:
		town.add_building(StringName(id))
	return town


## Run Consume and return the town's quality of life.
func _live(town: Town) -> Dictionary:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	month.run(colony, context)
	return QualityOfLife.of(town, context)


# --- 🔒 The same path as a consumed luxury ----------------------------------

func test_there_is_something_in_the_data_that_amuses_people() -> void:
	# The rest of this file proves nothing if nothing carries the effect.
	assert_true(not _amusements().is_empty(),
		"no building in the tree provides amusement, so #153 is a field nobody uses")


func test_amusement_feeds_pleasure_and_not_a_term_of_its_own() -> void:
	# 🔒 It joins `luxury` and `luxury_kinds`, which is what makes it masking
	# rather than an addition — and what makes the variety bonus treat a theatre
	# as another thing to enjoy rather than as a separate sum.
	var bare := Building.amusement_for(_town(0.0))
	assert_almost_eq(float(bare["served"]), 0.0, 0.0001)

	var amused := Building.amusement_for(_town(0.0, {}, [_amusements()[0]]))
	assert_true(float(amused["served"]) > 0.0, "the amusement entertains nobody")
	assert_eq(int(amused["kinds"]), 1, "it did not count as something to enjoy")


func test_a_town_with_amusement_and_no_drink_is_more_content() -> void:
	var dull := _live(_town(5_000.0))
	var amused := _live(_town(5_000.0, {}, _amusements()))
	assert_true(float(amused["pleasure"]) > float(dull["pleasure"]),
		"a town with a theatre and no cellar felt no better than one with neither")
	assert_true(float(amused["quality_of_life"]) > float(dull["quality_of_life"]),
		"and it did not reach quality of life at all")


# --- 🔒 Nothing that interrupts commerce touches it -------------------------

func test_no_gold_no_trade_and_open_rebellion_leave_it_untouched() -> void:
	# The whole strategic point: **a theatre cannot be embargoed.**
	var cut_off := _town(5_000.0, {}, _amusements())
	cut_off.rebelling = true
	cut_off.embargo_months = 6
	var amused := _live(cut_off)

	var dull := _town(5_000.0)
	dull.rebelling = true
	dull.embargo_months = 6
	assert_true(float(amused["pleasure"]) > float(_live(dull)["pleasure"]),
		"a rebelling town under embargo lost the use of a building it already owns")


# --- 🔒 But upkeep does -----------------------------------------------------

func test_an_amusement_nobody_pays_for_amuses_nobody() -> void:
	# The counterweight #151 exists to be: a town too poor to pay watches its
	# amusements go dark in the same month its larder empties.
	var broke := _town(0.0, {}, _amusements())
	var colony := Colony.new()
	colony.add(broke)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony

	assert_true(float(Building.amusement_for(broke)["served"]) > 0.0,
		"the fixture's amusements were already dark")
	Upkeep.settle(broke, context)
	assert_almost_eq(float(Building.amusement_for(broke)["served"]), 0.0, 0.0001,
		"a theatre nobody is paying for went on putting plays on")


# --- 🔒 Bread and circuses --------------------------------------------------

func test_a_starving_town_with_ample_amusement_reports_good_spirits() -> void:
	# **Truthfully.** `quality-of-life.md` makes pleasure mask the shortfall and
	# makes its power greatest when life is worst, so a colony the PC cannot feed
	# can be given something to watch and the people will be measurably content
	# about it. That is the satire, and it should not be balanced away.
	var starving := _town(5_000.0)
	var entertained := _town(5_000.0, {}, _amusements())

	var wretched := _live(starving)
	var distracted := _live(entertained)
	assert_true(float(distracted["quality_of_life"]) > float(wretched["quality_of_life"]),
		"a starving town with a theatre was no happier than a starving town without")
	assert_almost_eq(float(distracted["health"]), float(wretched["health"]), 0.0001,
		"the amusement fed somebody, which is not what masking means")
