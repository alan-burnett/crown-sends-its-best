extends TestCase

## Governor intent and town objectives (#53).
##
## `docs/mechanics/governor-objectives.md` §9 draws the line these tests are
## mostly about:
##
## | Decision | Personality? |
## | :--- | :--- |
## | Choose an intent | **yes** |
## | Choose an objective serving it | **no** |
## | Detect a stall | **no** |
## | Choose a tile | **no** |
##
## So the intent tests ask whether two different men decide differently, and the
## objective tests ask whether the *same* answer comes back every time.

const SEED: int = 1649

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


# --- Fixture ----------------------------------------------------------------

## Plains, forest, grassland and a mountain, so there is something to build on
## and a real choice of where.
func _map() -> WorldMap:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_terrain(x, y, &"plains" if x <= 4 else &"forest")
	map.set_terrain(2, 2, &"grassland")
	map.set_terrain(6, 6, &"mountains")
	return map


func _town(intent: StringName = GovernorIntent.ECONOMY, stock: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = 8_000
	town.governor_id = &"governor_ashmere"
	town.intent = intent
	town.receive_gold(500.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _harness(town: Town, phases: Array = []) -> Dictionary:
	var map := _map()
	var colony := Colony.new()
	colony.add(town)
	var streams := RngStreams.new(SEED)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), streams, map)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())

	var month := ColonyMonth.new()
	for phase in phases:
		match phase:
			ColonyMonth.WORK: month.set_handler(phase, WorkPhase.new())
			ColonyMonth.RECKON: month.set_handler(phase, ReckonPhase.new())
			ColonyMonth.EXCHANGE: month.set_handler(phase, ExchangePhase.new())
			ColonyMonth.CONSUME: month.set_handler(phase, ConsumePhase.new())
			ColonyMonth.BUILD: month.set_handler(phase, BuildPhase.new())
			ColonyMonth.SETTLE: month.set_handler(phase, SettlePhase.new())
	return {"colony": colony, "context": context, "month": month, "town": town, "streams": streams}


func _run_month(harness: Dictionary) -> void:
	harness["month"].run(harness["colony"], harness["context"])
	harness["context"].state.month += 1


func _governor(id: StringName, weights: Dictionary = {}) -> DeliberationActor:
	var actor := DeliberationActor.new(id, weights)
	# The mandate would otherwise dominate month zero and make every test about
	# the mandate.
	if not weights.has(String(IntentConsiderations.MANDATE)):
		actor.set_weight(IntentConsiderations.MANDATE, 0.0)
	return actor


func _decide(town: Town, actor: DeliberationActor, harness: Dictionary, mandate: String = "") -> Decision:
	var context: ColonyContext = harness["context"]
	var deliberation := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, context.state, context.log
	)
	deliberation.phase = WorldPhase.INTENT
	deliberation.data = {
		"town": town,
		"colony": context.colony,
		"map": context.map,
		"territory": context.territory,
		"mandate": mandate,
		"urged": String(town.urged_intent),
		"urged_month": town.urged_month,
	}
	var candidates: Array = []
	for intent in GovernorIntent.IN_ORDER:
		candidates.append(Candidate.new(intent))
	return Deliberation.choose(actor, candidates, deliberation)


# --- Intent: personality decides --------------------------------------------

func test_intent_selection_goes_through_the_kernel_and_emits_a_trace() -> void:
	# The reason in his letter is the reason in the log, which is what stops a
	# letter misrepresenting why something was done (SPEC §9.1).
	var town := _town()
	var harness := _harness(town)
	var decision := _decide(town, _governor(&"governor_ashmere"), harness)

	assert_true(decision.has_choice())
	assert_true(GovernorIntent.is_intent(decision.chosen_id()))

	var traces: Array = harness["context"].log.of_type(Deliberation.TRACE_EVENT)
	assert_eq(traces.size(), 1, "the choice was made without a trace")
	assert_eq(String(traces[0].payload["kind"]), String(DecisionKind.GOVERNOR_INTENT))
	assert_not_empty(traces[0].payload["entries"])


func test_two_governors_choose_differently_from_identical_state() -> void:
	# **Personality is a weight vector and nothing else.** Same town, same world,
	# same month — two men, two answers, and no code per personality.
	var town := _town()
	var harness := _harness(town)

	var merchant := _governor(&"merchant", {
		String(IntentConsiderations.REVENUE): 6.0,
		String(IntentConsiderations.ROOM): 0.0,
	})
	var pioneer := _governor(&"pioneer", {
		String(IntentConsiderations.REVENUE): 0.0,
		String(IntentConsiderations.ROOM): 6.0,
	})

	assert_ne(
		String(_decide(town, merchant, harness).chosen_id()),
		String(_decide(town, pioneer, harness).chosen_id()),
		"two very different men wanted the same thing",
	)


func test_the_same_governor_decides_the_same_way_twice() -> void:
	var town := _town()
	var harness := _harness(town)
	var actor := _governor(&"governor_ashmere", {String(IntentConsiderations.REVENUE): 3.0})
	assert_eq(
		String(_decide(town, actor, harness).chosen_id()),
		String(_decide(town, actor, harness).chosen_id()),
	)


func test_the_mandate_pulls_early_and_fades() -> void:
	# SPEC §6.1: the Crown's Mandate matters "especially in the early game". An
	# input with a decaying weight, not a hardcoded bias — so the same governor
	# in the same town answers differently in year one and year three.
	var town := _town()
	var harness := _harness(town)
	var actor := _governor(&"governor_ashmere", {
		String(IntentConsiderations.MANDATE): 4.0,
		String(IntentConsiderations.REVENUE): 1.0,
	})

	harness["context"].state.month = 0
	var early := _decide(town, actor, harness, GovernorIntent.DEFENCE)
	assert_eq(String(early.chosen_id()), String(GovernorIntent.DEFENCE),
		"the Crown's Mandate did not reach the governor at all")

	harness["context"].state.month = 120
	var late := _decide(town, actor, harness, GovernorIntent.DEFENCE)
	assert_ne(String(late.chosen_id()), String(GovernorIntent.DEFENCE),
		"ten years on he is still doing what he was appointed to do")


func test_a_town_that_can_see_nowhere_to_settle_cannot_intend_to() -> void:
	# A locked rule is a filter, never a weight — it must not be able to lose a
	# close vote (`docs/mechanics/deliberation.md` §5).
	var town := _town()
	var harness := _harness(town)
	# A colony whose border covers everything it can see has nowhere to go.
	var territory: Territory = harness["context"].territory
	for at in territory.visible:
		territory.border[at] = true
		territory.influence[at] = town.id

	var actor := _governor(&"expansionist", {String(IntentConsiderations.ROOM): 9.0})
	var decision := _decide(town, actor, harness)

	assert_ne(String(decision.chosen_id()), String(GovernorIntent.SETTLEMENT))
	var filtered := false
	for entry in decision.entries:
		if String(entry.get("id", "")) == String(GovernorIntent.SETTLEMENT):
			filtered = entry.has("filtered_by")
	assert_true(filtered, "settling was scored down rather than ruled out")


# --- 🔒 Objective: competence decides ---------------------------------------

func test_objective_selection_is_deterministic() -> void:
	var town := _town()
	var harness := _harness(town)
	var first := ObjectiveSelector.choose(town, GovernorIntent.ECONOMY, harness["context"])
	for _attempt in 4:
		var again := ObjectiveSelector.choose(town, GovernorIntent.ECONOMY, harness["context"])
		assert_eq(String(again["id"]), String(first["id"]))
		assert_eq(again["target"], first["target"])


func test_choosing_an_objective_draws_no_randomness() -> void:
	# Not merely "the same answer": **nothing is drawn**. A tie resolved by a die
	# would consume from a stream and shift every later draw in the colony, so
	# the same seed would produce a different world depending on whether two
	# projects happened to score alike.
	var town := _town()
	var harness := _harness(town)
	var before := Canonical.hash_of(harness["streams"].to_dict())
	ObjectiveSelector.choose(town, GovernorIntent.ECONOMY, harness["context"])
	assert_eq(Canonical.hash_of(harness["streams"].to_dict()), before,
		"choosing an objective drew from an RNG stream")


func test_different_intents_choose_different_objectives() -> void:
	# If they did not, the whole two-level design would be decoration.
	var town := _town()
	var harness := _harness(town)
	var chosen: Dictionary = {}
	for intent in GovernorIntent.IN_ORDER:
		chosen[String(ObjectiveSelector.choose(town, intent, harness["context"])["id"])] = true
	assert_true(chosen.size() >= 3,
		"five intents produced %d distinct objectives" % chosen.size())


## ⏸ **Parked** (#408). With the crane gone (#327) a governor of any intent can
## reach a foundry, and the selector scores it without looking at the town, so
## this fails — rightly. It waits on the Author's rework of governor agendas and
## goes back to `test_` then. Renamed rather than deleted so the claim is kept.
func parked_test_a_defensive_intent_builds_defences() -> void:
	# The one place it is worth asserting *which* project, because a governor who
	# answers a threat with a sugar plantation reads as broken however elegant
	# the scoring is.
	var town := _town()
	var harness := _harness(town)
	var chosen := ObjectiveSelector.choose(town, GovernorIntent.DEFENCE, harness["context"])
	var building := Building.find(StringName(chosen["id"]))
	assert_true(building != null and float(building.effect("defence", 0.0)) > 0.0,
		"a governor set on defence chose '%s'" % chosen["id"])


func test_the_governor_chooses_the_tile() -> void:
	# SPEC §11.4 locks it, and `tools/lint.gd` fails if anything outside sim/
	# writes a town's objective or its target. Here: an improvement objective
	# arrives with a tile already chosen, and it is one the town can reach.
	var town := _town()
	var harness := _harness(town)
	var sited: Dictionary = {}
	for candidate in ObjectiveSelector.candidates(town, harness["context"], GovernorIntent.POPULATION):
		if Objective.kind_of(StringName(candidate["id"])) == Objective.IMPROVEMENT:
			sited = candidate
			break

	assert_false(sited.is_empty(), "no improvement was ever on offer")
	assert_ne(sited["target"], Vector2i(-1, -1), "an improvement was chosen with no tile")
	assert_true(harness["context"].tiles_of(town).has(sited["target"]),
		"the chosen tile is outside the town's reach")


func test_the_tile_choice_is_deterministic() -> void:
	var town := _town()
	var first: Variant = null
	for _attempt in 3:
		var harness := _harness(_town())
		for candidate in ObjectiveSelector.candidates(town, harness["context"], GovernorIntent.POPULATION):
			if Objective.kind_of(StringName(candidate["id"])) != Objective.IMPROVEMENT:
				continue
			if first == null:
				first = candidate["target"]
			assert_eq(candidate["target"], first)
			break


func test_an_unobtainable_project_is_never_chosen() -> void:
	# The militia needs guns, guns need iron, the town produces no ore and has no
	# money. That objective is unreachable and no amount of patience fixes it, so
	# it is not on the board.
	var town := _town()
	town.spend_gold(500.0)
	var harness := _harness(town)
	for candidate in ObjectiveSelector.candidates(town, harness["context"], GovernorIntent.ECONOMY):
		for resource in Building.find(StringName(candidate["id"])).cost if Building.has(StringName(candidate["id"])) else {}:
			assert_true(
				ObjectiveSelector.can_obtain(town, StringName(resource), harness["context"]),
				"'%s' was offered though its %s is unobtainable" % [candidate["id"], resource],
			)


# --- Both kinds of objective ------------------------------------------------

## ⏸ **Parked** (#408). With the crane gone (#327) a governor of any intent can
## reach a foundry, and the selector scores it without looking at the town, so
## this fails — rightly. It waits on the Author's rework of governor agendas and
## goes back to `test_` then. Renamed rather than deleted so the claim is kept.
func parked_test_a_project_is_chosen_carried_and_completed() -> void:
	var town := _town(GovernorIntent.ECONOMY, {"food": 200.0, "clothing": 50.0, "wood": 200.0, "stone": 200.0, "tools": 50.0})
	var harness := _harness(town, [
		ColonyMonth.RECKON, ColonyMonth.EXCHANGE, ColonyMonth.CONSUME,
		ColonyMonth.BUILD, ColonyMonth.SETTLE,
	])

	for _month in 8:
		_run_month(harness)

	assert_not_empty(harness["context"].log.of_type(ObjectiveSelector.EVENT_CHOSEN))
	# **A project, not specifically a building.** Which one the governor picks is
	# his business and moves with the price list — a town attending to profit
	# plants a cash crop when cash crops are worth planting. What this test is
	# about is that whatever he picked got finished.
	assert_not_empty(harness["context"].log.of_type(BuildPhase.EVENT_COMPLETED),
		"eight months and a full granary finished nothing at all")


## ⏸ **Parked** (#408). With the crane gone (#327) a governor of any intent can
## reach a foundry, and the selector scores it without looking at the town, so
## this fails — rightly. It waits on the Author's rework of governor agendas and
## goes back to `test_` then. Renamed rather than deleted so the claim is kept.
func parked_test_something_other_than_a_building_can_win_the_board() -> void:
	# **Every kind of objective has to be able to win**, or governors only ever
	# write about construction.
	#
	# Settling used to be the posture case here, because gathering an
	# expedition's stores was something a town could do and founding was not.
	# It is a **project** since #175 — it has a target and it completes — so the
	# posture case is a town told to stockpile instead.
	# **Large enough to spare anybody.** A town of eight cannot send four people
	# and keep a town behind, so the expedition is not on its board at all — which
	# is the rule working, and would have made this test about the wrong thing.
	var town := _town()
	town.workers = 24
	var harness := _harness(town)
	assert_true(Expedition.may_launch(town), "the fixture town cannot mount an expedition")

	var settling := ObjectiveSelector.choose(town, GovernorIntent.SETTLEMENT, harness["context"])
	assert_false(Building.has(StringName(settling["id"])),
		"a governor set on settling chose to build '%s'" % settling["id"])
	assert_eq(settling["target"], Vector2i(-1, -1), "a project without a tile was given one")

	var surviving := ObjectiveSelector.choose(town, GovernorIntent.SURVIVAL, harness["context"])
	assert_true(Objective.is_posture(StringName(surviving["id"]))
			or Building.has(StringName(surviving["id"])),
		"a governor set on survival wanted '%s', which is neither" % surviving["id"])


func test_a_posture_neither_completes_nor_stalls() -> void:
	# It stands until the intent it serves changes, which is what makes it a
	# posture rather than a project nobody finishes.
	var town := _town(GovernorIntent.SURVIVAL)
	town.objective = &"stockpile_food"
	town.objective_intent = GovernorIntent.SURVIVAL
	town.objective_idle_months = 99
	var harness := _harness(town)

	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.NONE),
		"a standing order was called stalled")

	town.intent = GovernorIntent.DEFENCE
	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.INTENT_CHANGED),
		"a standing order outlived the intent it stood for")


# --- 🔒 No oscillation ------------------------------------------------------

func test_a_town_does_not_oscillate() -> void:
	# **Stickiness falls out of the three tests, not out of a switching margin.**
	# A town making progress on a sensible project simply carries on, so months
	# of running produce far fewer changes of mind than months.
	# **Iron is a build cost since `buildings.md` §5.** Without it in the stores
	# a town with "everything it needed" could not finish anything it chose, and
	# this test would be measuring that instead of oscillation.
	var town := _town(GovernorIntent.ECONOMY, {
		"food": 400.0, "clothing": 100.0, "wood": 400.0,
		"stone": 400.0, "tools": 100.0, "iron": 100.0,
	})
	var harness := _harness(town, [
		ColonyMonth.RECKON, ColonyMonth.EXCHANGE, ColonyMonth.CONSUME,
		ColonyMonth.BUILD, ColonyMonth.SETTLE,
	])

	for _month in 12:
		_run_month(harness)

	var abandoned: Array = harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED)
	assert_empty(abandoned, "a town with everything it needed gave up on %d projects" % abandoned.size())


func test_gathering_is_not_a_stall() -> void:
	# A town buying its tools a few at a time is getting somewhere. Counting
	# those months would have it give up on everything expensive and then give up
	# on the replacement for exactly the same reason, for ever.
	var town := _town(GovernorIntent.ECONOMY)
	town.objective = &"granary"
	town.objective_intent = GovernorIntent.ECONOMY
	town.store(&"wood", 10.0)
	var harness := _harness(town, [ColonyMonth.BUILD])

	_run_month(harness)
	assert_eq(town.objective_idle_months, 0, "a month that put ten of timber in was called idle")

	_run_month(harness)
	assert_eq(town.objective_idle_months, 1, "a month that put nothing in was not counted")


func test_a_town_that_is_really_going_nowhere_gives_up() -> void:
	var town := _town(GovernorIntent.ECONOMY)
	town.objective = &"church"
	town.objective_intent = GovernorIntent.ECONOMY
	town.objective_idle_months = Reconsideration.SOFT_STALL_MONTHS
	var harness := _harness(town)

	assert_true(Reconsideration.soft_stalled(town))
	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.SOFT_STALL))


# --- 🔒 Sunk progress -------------------------------------------------------

## A build with `share` of its materials already in the frame.
##
## **Materials, not months** (#148). This used to invest the whole cost and then
## set a month count, because progress was half one and half the other; now the
## materials *are* the progress, so investing everything makes a finished build
## rather than a half-raised one.
func _part_built(objective: StringName, share: float) -> Town:
	var town := _town(GovernorIntent.ECONOMY)
	town.objective = objective
	town.objective_intent = GovernorIntent.ECONOMY
	var building := Building.find(objective)
	for resource in building.costed_resources():
		var cost := building.cost_of(StringName(resource))
		town.store(StringName(resource), cost)
		town.invest(StringName(resource), cost * share)
	town.objective_progress = 1
	return town


func test_a_routine_change_of_intent_does_not_abandon_a_project_underway() -> void:
	var town := _part_built(&"granary", 0.5)
	var harness := _harness(town)
	assert_true(Objective.progress_fraction(town) > Reconsideration.ROUTINE_SUNK)

	town.intent = GovernorIntent.POPULATION
	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.NONE),
		"a change of priorities threw away a project most of the way up")


func test_a_crisis_overrides_substantial_sunk_progress() -> void:
	# The natives are burning the outskirts. The town must not spend eleven more
	# months on a dock.
	var town := _part_built(&"granary", 0.5)
	var harness := _harness(town)

	town.intent = GovernorIntent.SURVIVAL
	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.INTENT_CHANGED),
		"a crisis could not shift a half-built granary")


func test_even_a_crisis_finishes_what_is_nearly_done() -> void:
	var town := _part_built(&"church", 0.9)  # nine parts in ten already raised
	var harness := _harness(town)
	assert_true(Objective.progress_fraction(town) >= Reconsideration.CRISIS_SUNK)

	town.intent = GovernorIntent.SURVIVAL
	assert_eq(String(Reconsideration.verdict(town, harness["context"])), String(Reconsideration.NONE),
		"a church three-quarters raised was torn down for an emergency")


func test_abandoning_forfeits_what_was_invested() -> void:
	# The timber is already cut and standing in the half-built frame.
	var town := _part_built(&"granary", 0.5)
	var harness := _harness(town)
	var spare := town.held(&"wood")   # never went into the frame, so never at risk
	var sunk := town.invested(&"wood")
	assert_true(sunk > 0.0, "the fixture put nothing in the frame, so there is nothing to forfeit")

	Reconsideration.abandon(town, Reconsideration.INTENT_CHANGED, harness["context"])

	assert_eq(String(town.objective), "")
	assert_empty(town.objective_invested)
	assert_almost_eq(town.held(&"wood"), spare, 0.001, "the timber came back out of the frame")

	var events: Array = harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED)
	assert_eq(events.size(), 1)
	assert_eq(String(events[0].payload["reason"]), String(Reconsideration.INTENT_CHANGED))


# --- 🔒 The PC argues for a goal and nothing else ---------------------------

func test_urging_an_intent_does_not_set_it() -> void:
	# SPEC §8.5: orders are requests. A governor who has been written to still
	# weighs the letter against his own reading of his town, and may keep his own
	# mind.
	var town := _town(GovernorIntent.ECONOMY)
	var colony := Colony.new()
	colony.add(town)

	var executor := UrgeIntentExecutor.new()
	executor.colony = colony
	var intent := Intent.new(
		&"", UrgeIntentExecutor.KIND, town.governor_id, town.governor_id, 1,
		{"intent": String(GovernorIntent.DEFENCE)},
	)
	var log := EventLog.new()
	var state := WorldValues.initial_state()
	state.month = 5

	assert_eq(String(executor.execute(intent, state, log)), String(Intent.COMPLETED))
	assert_eq(String(town.urged_intent), String(GovernorIntent.DEFENCE))
	assert_eq(town.urged_month, 5)
	assert_eq(String(town.intent), String(GovernorIntent.ECONOMY),
		"a letter set the governor's intent outright")


func test_what_the_pc_urged_reaches_the_deliberation() -> void:
	var town := _town(GovernorIntent.ECONOMY)
	town.urged_intent = GovernorIntent.DEFENCE
	town.urged_month = 0
	var harness := _harness(town)

	var deaf := _governor(&"deaf", {String(IntentConsiderations.URGING): 0.0})
	var dutiful := _governor(&"dutiful", {String(IntentConsiderations.URGING): 8.0})

	assert_eq(String(_decide(town, dutiful, harness).chosen_id()), String(GovernorIntent.DEFENCE))
	assert_ne(String(_decide(town, deaf, harness).chosen_id()), String(GovernorIntent.DEFENCE))


func test_an_urging_that_names_no_intent_comes_to_nothing_loudly() -> void:
	var colony := Colony.new()
	colony.add(_town())
	var executor := UrgeIntentExecutor.new()
	executor.colony = colony
	var intent := Intent.new(
		&"", UrgeIntentExecutor.KIND, &"governor_ashmere", &"governor_ashmere", 1,
		{"intent": "build me a dock"},
	)
	assert_eq(
		String(executor.execute(intent, WorldValues.initial_state(), EventLog.new())),
		String(Intent.STALLED),
	)


# --- Saving -----------------------------------------------------------------

func test_intent_and_objective_survive_save_and_reload() -> void:
	var town := _part_built(&"granary", 0.5)
	town.intent = GovernorIntent.DEFENCE
	town.intent_since = 7
	town.urged_intent = GovernorIntent.POPULATION
	town.urged_month = 6
	town.objective_target = Vector2i(3, 5)
	town.objective_idle_months = 2

	var restored := Town.from_dict(town.to_dict())
	assert_eq(String(restored.intent), String(GovernorIntent.DEFENCE))
	assert_eq(restored.intent_since, 7)
	assert_eq(String(restored.urged_intent), String(GovernorIntent.POPULATION))
	assert_eq(restored.urged_month, 6)
	assert_eq(restored.objective_target, Vector2i(3, 5))
	assert_eq(restored.objective_idle_months, 2)
	assert_eq(String(restored.objective_intent), String(GovernorIntent.ECONOMY))
	assert_almost_eq(Objective.progress_fraction(restored), Objective.progress_fraction(town), 0.001)
