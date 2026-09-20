extends TestCase

## Settle, and Quality of Life (#50).
##
## `docs/mechanics/quality-of-life.md` §5 carries a worked table. Reproducing it
## exactly is most of the value here: it is the PO's statement of what the model
## *means*, and a formula that no longer produces those five rows has changed the
## design rather than the arithmetic.

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


# --- The worked table (`quality-of-life.md` §5) -----------------------------

func _parts(health: float, safety: float, means: float, hope: float) -> Dictionary:
	return {"health": health, "safety": safety, "means": means, "hope": hope}


func test_the_worked_examples_from_the_mechanics_doc() -> void:
	# The doc's §5 table, at the interim weights of #117: safety is pinned at
	# 1.0 until M5, so it is excluded and the other three are renormalised.
	# Same relative balance, and the full range reachable instead of a floor of
	# 0.25 under every town in the game.
	#
	# | Town | health | means | hope | pleasure | substance | QoL |
	var rows: Array = [
		["thriving",           1.00, 0.8, 0.70, 0.9, 0.85, 0.91],
		["struggling",         0.35, 0.2, 0.05, 0.0, 0.21, 0.21],
		["starving and drunk", 0.10, 0.5, 0.10, 1.0, 0.21, 0.56],
	]
	# Compared at the doc's own precision. It quotes two decimal places, so two
	# decimal places is the claim being checked.
	for row in rows:
		var parts := _parts(float(row[1]), 1.0, float(row[2]), float(row[3]))
		var substance := QualityOfLife.substance_of(parts)
		var quality := QualityOfLife.combine(substance, float(row[4]))
		assert_almost_eq(snappedf(substance, 0.01), float(row[5]), 0.0001,
			"%s: substance came out %f" % [row[0], substance])
		assert_almost_eq(snappedf(quality, 0.01), float(row[6]), 0.0001,
			"%s: quality of life came out %f" % [row[0], quality])


func test_the_interim_weights_keep_the_balance_between_what_is_left() -> void:
	# **Excluding a component changes the range, not the balance.** Health is
	# still worth more than hope, which is still worth more than means, in the
	# same proportions the doc gives.
	assert_almost_eq(QualityOfLife.effective_weight(QualityOfLife.W_HEALTH), 0.400, 0.001)
	assert_almost_eq(QualityOfLife.effective_weight(QualityOfLife.W_HOPE), 0.333, 0.001)
	assert_almost_eq(QualityOfLife.effective_weight(QualityOfLife.W_MEANS), 0.267, 0.001)

	var shares := (
		QualityOfLife.effective_weight(QualityOfLife.W_HEALTH)
		+ QualityOfLife.effective_weight(QualityOfLife.W_HOPE)
		+ QualityOfLife.effective_weight(QualityOfLife.W_MEANS)
	)
	assert_almost_eq(shares, 1.0, 0.001, "the live weights do not add up to a whole")


func test_there_is_no_longer_a_floor_under_every_town() -> void:
	# **What #117 is for.** A quarter of the formula was a constant, so nothing
	# could score below 0.25 however badly it was going, and the bottom rungs of
	# every quality-of-life ladder were unreachable for the whole milestone.
	var wretched := QualityOfLife.combine(
		QualityOfLife.substance_of(_parts(0.0, 1.0, 0.0, 0.0)), 0.0
	)
	assert_almost_eq(wretched, 0.0, 0.001,
		"a town with nothing at all still scored %f" % wretched)


func test_a_raid_costs_nothing_while_safety_is_inert() -> void:
	# Stated rather than discovered. Safety is excluded until M5, so the doc's
	# two raided rows currently read the same as their unraided ones — and the
	# day that changes, this test changes with it.
	assert_true(QualityOfLife.SAFETY_IS_INERT,
		"safety has come alive and this test is now the wrong one")
	assert_almost_eq(
		QualityOfLife.substance_of(_parts(1.0, 1.0, 0.8, 0.7)),
		QualityOfLife.substance_of(_parts(1.0, 0.3, 0.8, 0.7)),
		0.0001,
		"safety moved something while it is supposed to be inert",
	)


func test_a_town_propped_up_by_one_thing_collapses_when_it_goes() -> void:
	# **The acceptance criterion, and the reason substance is a sum rather than a
	# product.** Both towns lose the same absolute health. The thriving one slips
	# and carries on; the struggling one, for which health was most of what it
	# had, falls off a cliff.
	#
	# Demonstrated on health rather than safety, because safety cannot move.
	var thriving := QualityOfLife.substance_of(_parts(1.0, 1.0, 0.8, 0.7))
	var thriving_hurt := QualityOfLife.substance_of(_parts(0.3, 1.0, 0.8, 0.7))
	var struggling := QualityOfLife.substance_of(_parts(0.7, 1.0, 0.1, 0.05))
	var struggling_hurt := QualityOfLife.substance_of(_parts(0.0, 1.0, 0.1, 0.05))

	assert_almost_eq(thriving - thriving_hurt, struggling - struggling_hurt, 0.005,
		"the fixture did not cost both towns the same health")

	var lost_by_thriving := (
		QualityOfLife.combine(thriving, 0.9) - QualityOfLife.combine(thriving_hurt, 0.9)
	)
	var lost_by_struggling := (
		QualityOfLife.combine(struggling, 0.0) - QualityOfLife.combine(struggling_hurt, 0.0)
	)
	assert_true(lost_by_struggling > lost_by_thriving,
		"the same loss cost the struggling town %f and the thriving one %f" % [
			lost_by_struggling, lost_by_thriving])


func test_a_starving_drunk_town_outscores_a_struggling_sober_one() -> void:
	# **Correct and deliberate** (doc §5). Pleasure masks rather than adds, and
	# its power is greatest when life is worst — which is human nature, and the
	# rum trap the satire depends on.
	var drunk := QualityOfLife.combine(QualityOfLife.substance_of(_parts(0.1, 0.3, 0.5, 0.1)), 1.0)
	var sober := QualityOfLife.combine(QualityOfLife.substance_of(_parts(0.35, 1.0, 0.2, 0.05)), 0.0)
	assert_true(drunk > sober, "the drink did not do its work: %f against %f" % [drunk, sober])


func test_pleasure_lifts_most_when_life_is_worst() -> void:
	var wretched := QualityOfLife.combine(0.1, 1.0) - QualityOfLife.combine(0.1, 0.0)
	var comfortable := QualityOfLife.combine(0.9, 1.0) - QualityOfLife.combine(0.9, 0.0)
	assert_true(wretched > comfortable * 3.0,
		"rum was worth %f to a wretched town and %f to a comfortable one" % [wretched, comfortable])


# --- A town living a month --------------------------------------------------

func _map() -> WorldMap:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_terrain(x, y, &"plains" if x <= 4 else &"forest")
	return map


func _town(stock: Dictionary = {}, gold: float = 400.0, workers: int = 12) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = workers
	town.governor_id = &"governor_ashmere"
	town.intent = GovernorIntent.ECONOMY
	town.receive_gold(gold)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _harness(town: Town) -> Dictionary:
	var map := _map()
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	month.set_handler(ColonyMonth.SETTLE, SettlePhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


func _lived(harness: Dictionary) -> Dictionary:
	var events: Array = harness["context"].log.of_type(SettlePhase.EVENT_LIVED)
	return {} if events.is_empty() else events[events.size() - 1].payload


# --- 🔒 Memoryless -----------------------------------------------------------

func test_there_is_no_carry_over_term() -> void:
	# **The formula's stability must come from its inputs, not from itself.** Two
	# identical towns, one remembering a golden age and one a catastrophe, must
	# settle on exactly the same number.
	var content_town := _town({"food": 200.0, "clothing": 40.0})
	content_town.quality_of_life = 0.95
	var wretched := _town({"food": 200.0, "clothing": 40.0})
	wretched.quality_of_life = 0.05

	var first := _harness(content_town)
	var second := _harness(wretched)
	_run_month(first)
	_run_month(second)

	assert_almost_eq(content_town.quality_of_life, wretched.quality_of_life, 0.0001,
		"last month's quality of life leaked into this month's")


func test_it_is_a_pure_function_of_the_month() -> void:
	var town := _town({"food": 200.0, "clothing": 40.0})
	var harness := _harness(town)
	_run_month(harness)
	var once := town.quality_of_life

	var again := _town({"food": 200.0, "clothing": 40.0})
	var second := _harness(again)
	_run_month(second)
	assert_almost_eq(again.quality_of_life, once, 0.0001)


# --- Health -----------------------------------------------------------------

func test_a_full_larder_is_worth_more_than_eating_exactly_enough() -> void:
	# Measured against a reserve, not against this month's consumption: eating
	# just enough every month is not the same as being secure.
	var hand_to_mouth := _town({"food": 12.0, "clothing": 40.0})
	var stocked := _town({"food": 200.0, "clothing": 40.0})
	_run_month(_harness(hand_to_mouth))
	_run_month(_harness(stocked))

	assert_true(stocked.quality_of_life > hand_to_mouth.quality_of_life,
		"a full granary was worth nothing")


func test_livestock_count_towards_the_larder() -> void:
	# **What makes a herd matter before M4 brings pastures**: a town that would
	# otherwise go hungry eats them, so they are food that has not been eaten yet.
	var bare := _town({"food": 40.0, "clothing": 40.0})
	var herded := _town({"food": 40.0, "clothing": 40.0})
	herded.add_livestock(&"cows", 12)

	var harness := _harness(herded)
	_run_month(_harness(bare))
	_run_month(harness)

	assert_true(herded.quality_of_life > bare.quality_of_life,
		"twelve head of cattle made no difference to how safe the town felt")


func test_clothing_is_read_from_what_consume_found() -> void:
	# A well-clothed town ends the month holding none, because Consume ran first.
	# Reading the stockpile would score every town at zero.
	var clothed := _town({"food": 200.0, "clothing": 40.0})
	var ragged := _town({"food": 200.0})
	_run_month(_harness(clothed))
	_run_month(_harness(ragged))

	assert_almost_eq(clothed.held(&"clothing"), 38.2, 0.5, "the fixture is not testing what it thinks")
	assert_true(clothed.quality_of_life > ragged.quality_of_life,
		"having clothing was worth nothing to the town that had it")


# --- Means ------------------------------------------------------------------

func test_gold_is_perceptible_only_as_a_judgement() -> void:
	# **The only route by which hidden town gold becomes perceptible** (SPEC
	# §11.3). The player never sees the number; they see a governor who sounds
	# comfortable or pinched.
	var rich := _town({"food": 200.0, "clothing": 40.0}, 5000.0)
	var poor := _town({"food": 200.0, "clothing": 40.0}, 0.0)
	_run_month(_harness(rich))
	_run_month(_harness(poor))

	assert_true(rich.quality_of_life > poor.quality_of_life)
	assert_almost_eq(rich.prosperity(QualityOfLife.COMFORTABLE_PURSE), 1.0, 0.001)
	assert_almost_eq(poor.prosperity(QualityOfLife.COMFORTABLE_PURSE), 0.0, 0.001)


# --- Hope -------------------------------------------------------------------

func test_hope_forgives_slow_work_on_the_right_problem() -> void:
	# **Fitness weighs more than progress.** A town judges its governor by what he
	# is trying to do, not by how fast he is doing it.
	assert_true(QualityOfLife.FITNESS_SHARE > QualityOfLife.PROGRESS_SHARE)

	var right := QualityOfLife.FITNESS_SHARE * 1.0 + QualityOfLife.PROGRESS_SHARE * 0.0
	var fast := QualityOfLife.FITNESS_SHARE * 0.0 + QualityOfLife.PROGRESS_SHARE * 1.0
	assert_true(right > fast, "fast work on the wrong problem beat slow work on the right one")


func test_a_stalled_project_has_less_hope_than_an_advancing_one() -> void:
	# The doc's own comparison: four months stuck at eighty per cent against one
	# month in at twenty.
	var stuck := _town({"wood": 0.0})
	stuck.objective = &"church"
	stuck.objective_intent = GovernorIntent.ECONOMY
	stuck.objective_progress = 3
	stuck.objective_idle_months = 4
	for resource in Building.find(&"church").costed_resources():
		stuck.store(StringName(resource), Building.find(&"church").cost_of(StringName(resource)))
		stuck.invest(StringName(resource), Building.find(&"church").cost_of(StringName(resource)))

	var moving := _town()
	moving.objective = &"granary"
	moving.objective_intent = GovernorIntent.ECONOMY
	moving.store(&"wood", 12.0)
	moving.invest(&"wood", 12.0)

	assert_true(QualityOfLife.progress_of(moving) > QualityOfLife.progress_of(stuck),
		"a town stuck at %f outscored one advancing at %f" % [
			QualityOfLife.progress_of(stuck), QualityOfLife.progress_of(moving)])


func test_a_starving_town_building_cannons_has_no_hope() -> void:
	var farming := _town({"clothing": 40.0})
	farming.objective = &"stockpile_food"
	var arming := _town({"clothing": 40.0})
	arming.objective = &"palisade"

	var one := _harness(farming)
	var other := _harness(arming)
	_run_month(one)
	_run_month(other)

	assert_true(
		float(_lived(one)["hope"]) > float(_lived(other)["hope"]),
		"a starving town raising a palisade had as much hope as one growing grain",
	)


func test_adopting_the_right_intent_raises_hope_before_anything_is_built() -> void:
	# **The fastest lever the PC has.** Objective fitness responds the month a
	# governor adopts a new goal, well before anything is finished.
	var indifferent := _town({"clothing": 40.0})
	indifferent.intent = GovernorIntent.ECONOMY
	var caring := _town({"clothing": 40.0})
	caring.intent = GovernorIntent.SURVIVAL

	var one := _harness(indifferent)
	var other := _harness(caring)
	_run_month(one)
	_run_month(other)

	assert_true(
		float(_lived(other)["hope"]) > float(_lived(one)["hope"]),
		"a governor turning to his people's survival changed nothing about how they felt",
	)


# --- Pleasure ---------------------------------------------------------------

func test_variety_is_worth_something() -> void:
	var one_kind := QualityOfLife.pleasure_of({"luxury": 1.0, "luxury_kinds": 1})
	var three_kinds := QualityOfLife.pleasure_of({"luxury": 1.0, "luxury_kinds": 3})
	assert_true(three_kinds > one_kind,
		"beer, rum and tea together were worth no more than beer alone")
	assert_almost_eq(three_kinds, 1.0, 0.001)


func test_no_luxuries_is_no_pleasure() -> void:
	assert_almost_eq(QualityOfLife.pleasure_of({"luxury": 0.0, "luxury_kinds": 0}), 0.0, 0.001)


# --- Population (SPEC §12.1) ------------------------------------------------

func test_growth_is_slow_at_low_population_and_compounds() -> void:
	# "It starts slowly but grows with population and can snowball."
	var small := _town({"food": 2000.0, "clothing": 400.0}, 5000.0, 10)
	var large := _town({"food": 20000.0, "clothing": 4000.0}, 50000.0, 400)
	var one := _harness(small)
	var other := _harness(large)

	for _month in 12:
		_run_month(one)
		_run_month(other)

	var small_growth := float(small.population() - 10) / 10.0
	var large_growth := float(large.population() - 400) / 400.0
	assert_true(large.population() > 400, "a town of four hundred had no children in a year")
	assert_true(large_growth > small_growth,
		"growth did not compound: %f against %f" % [large_growth, small_growth])


func test_a_town_with_nothing_reads_as_having_nothing() -> void:
	var town := _town({}, 0.0)
	var harness := _harness(town)
	for _month in 6:
		_run_month(harness)

	assert_true(town.quality_of_life < 0.35,
		"a town with no food, no clothes and no money scored %f" % town.quality_of_life)


func test_a_miserable_town_has_fewer_children_than_a_happy_one() -> void:
	var thriving := _town({"food": 4000.0, "clothing": 800.0, "beer": 400.0, "rum": 400.0, "tea": 400.0}, 9000.0, 60)
	var bleak := _town({"food": 700.0}, 0.0, 60)
	var one := _harness(thriving)
	var other := _harness(bleak)

	for _month in 12:
		_run_month(one)
		_run_month(other)

	assert_true(thriving.quality_of_life > bleak.quality_of_life, "the fixture is not testing anything")
	assert_true(thriving.population() > bleak.population(),
		"a thriving town of sixty grew to %d and a bleak one to %d" % [
			thriving.population(), bleak.population()])


# --- 🔒 What Settle does not do ---------------------------------------------

func test_sentiment_does_not_feed_back_into_quality_of_life() -> void:
	# **The one-way street.** Quality of life feeds rebel sentiment
	# (`rebel-sentiment.md` §4), so sentiment must not feed back within a month
	# or the two chase each other and neither means anything.
	#
	# This used to be stated as "nothing writes sentiment", which was true while
	# M3 was unbuilt and stopped being true the month #71 landed. The property it
	# was protecting is this one.
	var settled := _town({"food": 200.0, "clothing": 40.0})
	settled.rebel_sentiment = 0.0
	var seething := _town({"food": 200.0, "clothing": 40.0})
	seething.rebel_sentiment = 90.0

	var calm := _harness(settled)
	var angry := _harness(seething)
	for _month in 4:
		_run_month(calm)
		_run_month(angry)

	assert_almost_eq(seething.quality_of_life, settled.quality_of_life, 0.0001,
		"a seething town lived differently from a contented one for no other reason")


func test_choosing_the_objective_is_delegated() -> void:
	# Settle asks; it does not decide. What it lands on must be exactly what the
	# selector would have said on its own.
	var town := _town({"food": 200.0, "clothing": 40.0})
	var harness := _harness(town)
	var expected := ObjectiveSelector.choose(town, town.intent, harness["context"])

	_run_month(harness)
	assert_eq(String(town.objective), String(expected["id"]))
	assert_eq(town.objective_target, expected["target"])


# --- The event a letter reads -----------------------------------------------

func test_it_emits_the_direction_and_rough_magnitude() -> void:
	var town := _town({"food": 400.0, "clothing": 80.0})
	var harness := _harness(town)
	_run_month(harness)

	var payload := _lived(harness)
	for key in ["quality_of_life", "was", "change", "direction", "health", "safety", "means", "hope", "pleasure"]:
		assert_has(payload, key, "the month's living did not record '%s'" % key)
	assert_eq(String(payload["direction"]), "better",
		"a town going from nothing to comfortable did not report improving")


func test_a_town_whose_fortunes_turn_says_so() -> void:
	var town := _town({"food": 400.0, "clothing": 80.0})
	var harness := _harness(town)
	_run_month(harness)

	# The larder empties and the purse with it.
	town.take(&"food", 10_000.0)
	town.take(&"clothing", 10_000.0)
	town.spend_gold(10_000.0)
	_run_month(harness)

	assert_eq(String(_lived(harness)["direction"]), "worse")


func test_quality_of_life_survives_save_and_reload() -> void:
	var town := _town({"food": 200.0, "clothing": 40.0})
	var harness := _harness(town)
	_run_month(harness)

	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(restored.quality_of_life, town.quality_of_life, 0.0001)
	assert_almost_eq(restored.growth_accrued, town.growth_accrued, 0.0001)
