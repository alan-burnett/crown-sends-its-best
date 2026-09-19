extends TestCase

## Relief (#45).
##
## **M2 ships one town, so none of this happens in a real run.** It is tested
## with a multi-town fixture anyway: Relief is one of the eight locked phases,
## M4 brings the towns that would exercise it, and the resentment accumulator
## has to have been running before M3 wires it to rebel sentiment — a counter
## that starts at zero the month the rebellion system arrives explains nothing.

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


# --- Fixture ----------------------------------------------------------------
#
# Reckon and Relief only. No Work, so nothing is produced and every town's
# stores are exactly what the test put there.

func _town(id: StringName, workers: int, stock: Dictionary = {}) -> Town:
	var town := Town.new(id, String(id), Vector2i(0, 0))
	town.workers = workers
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _harness(towns: Array) -> Dictionary:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)

	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.RELIEF, ReliefPhase.new())
	return {"colony": colony, "context": context, "month": month}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])


func _gifts(harness: Dictionary) -> Array:
	return harness["context"].log.of_type(ReliefPhase.EVENT_GIVEN)


# --- Giving -----------------------------------------------------------------

func test_a_surplus_town_covers_a_deficit_towns_need() -> void:
	# Four mouths need four food and hold eight in reserve, so forty is plenty
	# spare. Six mouths holding nothing are six short.
	var giver := _town(&"alder", 4, {"food": 40.0})
	var taker := _town(&"brack", 6)
	var harness := _harness([giver, taker])

	_run_month(harness)

	assert_almost_eq(taker.held(&"food"), 6.0, 0.001, "the deficit town was not covered")
	assert_almost_eq(giver.held(&"food"), 34.0, 0.001, "the giving town lost the wrong amount")


func test_relief_is_free_and_lossless() -> void:
	# Not trade. Nothing is paid and nothing is lost on the road.
	var giver := _town(&"alder", 4, {"food": 40.0})
	var taker := _town(&"brack", 6)
	var harness := _harness([giver, taker])

	var before := giver.held(&"food") + taker.held(&"food")
	_run_month(harness)

	assert_almost_eq(giver.held(&"food") + taker.held(&"food"), before, 0.001,
		"food went missing between the towns")
	assert_false(giver.can_afford(0.01), "the giving town was paid for relief")


func test_a_town_keeps_its_own_reserve_before_it_gives() -> void:
	# Needs before wants applies to the giver too: it does not give away the
	# grain it is holding against the winter.
	var giver := _town(&"alder", 4, {"food": 12.0})  # need 4, reserve 8 — nothing spare
	var taker := _town(&"brack", 6)
	var harness := _harness([giver, taker])

	_run_month(harness)

	assert_almost_eq(giver.held(&"food"), 12.0, 0.001, "the giver dipped into its reserve")
	assert_empty(_gifts(harness))


# --- Needs before wants -----------------------------------------------------

func test_needs_are_covered_before_wants() -> void:
	# One giver with five spare, two takers: one that is hungry and one that is
	# building something out of food. **The hungry town gets all five.**
	Building.load_from([{"id": "granary_of_sorts", "months": 2, "cost": {"food": 20}}])

	var giver := _town(&"alder", 4, {"food": 17.0})  # need 4, reserve 8, spare 5
	var hungry := _town(&"brack", 5)
	var builder := _town(&"cowden", 4, {"food": 12.0})
	builder.objective = &"granary_of_sorts"
	var harness := _harness([giver, hungry, builder])

	_run_month(harness)

	assert_almost_eq(hungry.held(&"food"), 5.0, 0.001, "the hungry town was not served first")
	assert_almost_eq(builder.held(&"food"), 12.0, 0.001, "a want was served while a need went unmet")


func test_a_want_is_served_once_every_need_is_met() -> void:
	# Same shape, but with enough to go round. Wants are not forbidden, only
	# second.
	Building.load_from([{"id": "granary_of_sorts", "months": 2, "cost": {"food": 20}}])

	var giver := _town(&"alder", 4, {"food": 112.0})  # spare 100
	var hungry := _town(&"brack", 5)
	var builder := _town(&"cowden", 4, {"food": 12.0})
	builder.objective = &"granary_of_sorts"
	var harness := _harness([giver, hungry, builder])

	_run_month(harness)

	assert_almost_eq(hungry.held(&"food"), 5.0, 0.001)
	assert_true(builder.held(&"food") > 12.0, "nothing was ever given towards a want")


# --- Worst first ------------------------------------------------------------

func test_need_is_served_worst_first() -> void:
	# Enough for the deepest deficit and no more. The town in the worst trouble
	# is the one that gets it (SPEC §11.3).
	var giver := _town(&"alder", 2, {"food": 16.0})  # need 2, reserve 4, spare 10
	var bad := _town(&"brack", 10)   # ten short
	var worse := _town(&"cowden", 4)  # four short
	var harness := _harness([giver, bad, worse])

	_run_month(harness)

	assert_almost_eq(bad.held(&"food"), 10.0, 0.001, "the worst deficit was not served first")
	assert_almost_eq(worse.held(&"food"), 0.0, 0.001, "a lesser deficit was served ahead of a worse")


func test_the_order_is_stable_across_runs() -> void:
	# Two towns short by exactly the same amount. Whichever is served first, it
	# must be the same one every time — a tie broken by dictionary order would
	# make the same seed produce different colonies.
	var first: String = ""
	for _attempt in 3:
		var giver := _town(&"alder", 2, {"food": 10.0})
		var harness := _harness([giver, _town(&"brack", 6), _town(&"cowden", 6)])
		_run_month(harness)
		var gifts := _gifts(harness)
		assert_not_empty(gifts)
		if first.is_empty():
			first = String(gifts[0].payload["to"])
		assert_eq(String(gifts[0].payload["to"]), first, "the serving order moved between runs")


# --- Luxuries ---------------------------------------------------------------

func test_luxuries_are_never_given_as_relief() -> void:
	# A town short of rum is not in distress, and a town sending its rum away has
	# not helped anybody. Even as a want, it does not move.
	Building.load_from([{"id": "tavern", "months": 2, "cost": {"rum": 20}}])

	var giver := _town(&"alder", 4, {"food": 40.0, "rum": 80.0})
	var taker := _town(&"brack", 4, {"food": 40.0})
	taker.objective = &"tavern"
	var harness := _harness([giver, taker])

	_run_month(harness)

	assert_almost_eq(giver.held(&"rum"), 80.0, 0.001, "a luxury was given as relief")
	assert_almost_eq(taker.held(&"rum"), 0.0, 0.001)


# --- The resentment accumulator ---------------------------------------------

func test_the_imbalance_accumulates_per_town() -> void:
	# **Valued, not counted** — a cart of cattle is a larger favour than a cart
	# of grain, and the resentment should know it.
	var giver := _town(&"alder", 4, {"food": 40.0})
	var taker := _town(&"brack", 6)
	var harness := _harness([giver, taker])

	_run_month(harness)

	var value := 6.0 * ResourceCatalogue.price_of(&"food")
	assert_almost_eq(giver.relief_balance, value, 0.001, "the giver's imbalance is wrong")
	assert_almost_eq(taker.relief_balance, -value, 0.001, "the receiver's imbalance is wrong")


func test_the_imbalance_persists_across_months() -> void:
	var giver := _town(&"alder", 4, {"food": 400.0})
	var taker := _town(&"brack", 6)
	var harness := _harness([giver, taker])

	_run_month(harness)
	var after_one := giver.relief_balance
	assert_true(after_one > 0.0)

	# The receiver eats nothing in this fixture, so month two tops it back up to
	# the same need. What matters is that the total is cumulative.
	taker.take(&"food", 99.0)
	harness["context"].state.month += 1
	_run_month(harness)

	assert_true(giver.relief_balance > after_one, "the imbalance was reset rather than accumulated")


func test_the_imbalance_survives_save_and_reload() -> void:
	# Ironman means a corrupt save is a lost run, and a counter M3 depends on
	# that quietly failed to serialise would be found in M3.
	var giver := _town(&"alder", 4, {"food": 40.0})
	var harness := _harness([giver, _town(&"brack", 6)])
	_run_month(harness)

	var restored := Town.from_dict(giver.to_dict())
	assert_almost_eq(restored.relief_balance, giver.relief_balance, 0.001)


# --- One town ---------------------------------------------------------------

func test_with_one_town_the_phase_is_a_clean_no_op() -> void:
	# It still happens and the month still records that it happened — but it
	# says nothing, because nothing occurred. A line reading "relief complete,
	# nothing given" every month is an absence dressed as a finding.
	var alone := _town(&"alder", 6, {"food": 400.0})
	var harness := _harness([alone])

	_run_month(harness)

	assert_almost_eq(alone.held(&"food"), 400.0, 0.001)
	assert_almost_eq(alone.relief_balance, 0.0, 0.001)
	assert_empty(_gifts(harness), "a lone town gave relief to somebody")
	assert_empty(harness["context"].log.of_type(ReliefPhase.EVENT_SUMMARY))

	# The phase itself is still on the record, in order.
	var phases: Array = harness["context"].log.of_type(ColonyMonth.EVENT_PHASE)
	var names: Array = []
	for event in phases:
		names.append(String(event.payload["phase"]))
	assert_true(names.has("relief"), "relief did not run at all")


func test_a_town_never_relieves_itself() -> void:
	# Its own spare is not relief. Without the guard, a town flush with one thing
	# and short of another would appear at both ends of its own transfer.
	var giver := _town(&"alder", 4, {"food": 40.0})
	var taker := _town(&"brack", 6, {"food": 0.0})
	var harness := _harness([giver, taker])
	_run_month(harness)

	var gifts := _gifts(harness)
	assert_not_empty(gifts, "nothing was given, so the guard was never exercised")
	for gift in gifts:
		assert_ne(String(gift.payload["from"]), String(gift.payload["to"]),
			"a town gave relief to itself")
