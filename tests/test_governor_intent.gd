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


func _town(intent: StringName = GovernorIntent.GET_RICH, stock: Dictionary = {}) -> Town:
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
		"urgings": town.urgings,
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
	assert_not_empty(traces[0].payload["candidates"])


func test_two_governors_choose_differently_from_identical_state() -> void:
	# **Personality is a weight vector and nothing else.** Same town, same world,
	# same month — two men, two answers, and no code per personality.
	var town := _town()
	var harness := _harness(town)

	var merchant := _governor(&"merchant", {
		String(IntentConsiderations.BASELINE): 6.0,
		String(IntentConsiderations.ROOM): 0.0,
	})
	var pioneer := _governor(&"pioneer", {
		String(IntentConsiderations.BASELINE): 0.0,
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
	var actor := _governor(&"governor_ashmere", {String(IntentConsiderations.BASELINE): 3.0})
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
		String(IntentConsiderations.BASELINE): 1.0,
	})

	harness["context"].state.month = 0
	var early := _decide(town, actor, harness, GovernorIntent.MILITARY)
	assert_eq(String(early.chosen_id()), String(GovernorIntent.MILITARY),
		"the Crown's Mandate did not reach the governor at all")

	harness["context"].state.month = 120
	var late := _decide(town, actor, harness, GovernorIntent.MILITARY)
	assert_ne(String(late.chosen_id()), String(GovernorIntent.MILITARY),
		"ten years on he is still doing what he was appointed to do")


func test_going_wide_is_never_ruled_out_for_want_of_land() -> void:
	# #428, `governor-agendas.md` §13: **go wide has no filter.** Its first move is
	# a scouting company to *find* land, so a colony whose border covers all it
	# can see may still intend to spread; an expedition still needs a site before
	# it leaves (`founding-towns.md` §5).
	var town := _town()
	var harness := _harness(town)
	# A colony whose border covers everything it can see has nowhere to go.
	var territory: Territory = harness["context"].territory
	for at in territory.visible:
		territory.border[at] = true
		territory.influence[at] = town.id

	var actor := _governor(&"expansionist", {String(IntentConsiderations.ROOM): 9.0})
	var decision := _decide(town, actor, harness)
	for entry in decision.entries:
		if String(entry.get("id", "")) == String(GovernorIntent.GO_WIDE):
			assert_false(entry.has("filtered_by"), "going wide was ruled out for want of land")


# --- 🔒 Objective: competence decides ---------------------------------------

func test_objective_selection_is_deterministic() -> void:
	var town := _town()
	var harness := _harness(town)
	var first := ObjectiveSelector.choose(town, GovernorIntent.GET_RICH, harness["context"])
	for _attempt in 4:
		var again := ObjectiveSelector.choose(town, GovernorIntent.GET_RICH, harness["context"])
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
	ObjectiveSelector.choose(town, GovernorIntent.GET_RICH, harness["context"])
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
		"six intents produced %d distinct objectives" % chosen.size())


func test_two_governors_with_the_same_intent_choose_the_same_objective() -> void:
	# 🔒 `governor-agendas.md` §3: **objective choice is personality-free.**
	# Two men of opposite temper set on going tall, in the same town, build the
	# same thing; arguing with the intent is the game.
	var harness := _harness(_town(GovernorIntent.GO_TALL))
	var context: ColonyContext = harness["context"]
	var bold := _town(GovernorIntent.GO_TALL)
	bold.governor_id = &"governor_bold"
	var timid := _town(GovernorIntent.GO_TALL)
	timid.governor_id = &"governor_timid"
	var one := ObjectiveSelector.choose(bold, GovernorIntent.GO_TALL, context)
	var two := ObjectiveSelector.choose(timid, GovernorIntent.GO_TALL, context)
	assert_eq(String(one["id"]), String(two["id"]))
	assert_eq(one["target"], two["target"])


func test_the_walk_consults_no_personality_and_no_dice() -> void:
	# 🔒 The claim above, made about the code rather than one fixture: the walk
	# never reaches for a governor, a weight or a stream, so no fixture could
	# find two governors who disagree.
	for path in ["res://sim/colony/govern/agenda_menu.gd", "res://sim/colony/govern/objective_selector.gd"]:
		var code := FileAccess.get_file_as_string(path)
		for word in ["Deliberation", "IntentConsiderations", "streams", "stream(", "governor_id", "Contacts"]:
			assert_false(code.contains(word),
				"%s mentions '%s', so the objective is no longer the town's alone" % [path.get_file(), word])


func test_a_menu_edit_changes_what_a_town_builds() -> void:
	# 🔒 §12: **menus are data.** Moving one line changes the build, and no
	# code anywhere knows which building a go-tall town wants.
	var town := _town(GovernorIntent.GO_TALL)
	var harness := _harness(town)
	AgendaMenu.load_from({"intents": [{"id": "go_tall", "menu": [
		{"objective": "granary"}, {"objective": "church"},
	]}]})
	assert_eq(String(ObjectiveSelector.choose(town, GovernorIntent.GO_TALL, harness["context"])["id"]), "granary")

	AgendaMenu.load_from({"intents": [{"id": "go_tall", "menu": [
		{"objective": "church"}, {"objective": "granary"},
	]}]})
	assert_eq(String(ObjectiveSelector.choose(town, GovernorIntent.GO_TALL, harness["context"])["id"]), "church",
		"the menu was reordered and the town built what it built before")


func test_the_walk_takes_the_first_entry_that_passes_every_test() -> void:
	# 🔒 §3: wanted, reachable, placeable, not already built — failing any
	# one moves the walk on, and the first to pass all four is taken.
	var town := _town(GovernorIntent.GO_TALL)
	town.add_building(&"church")
	var harness := _harness(town)
	AgendaMenu.load_from({"intents": [{"id": "go_tall", "menu": [
		# Not wanted: its gate is shut.
		{"objective": "granary", "when": [{"is": "population_at_least", "n": 1_000_000}]},
		# Not reachable: nothing in reach grows iron, and there is no money.
		{"objective": "foundry"},
		# Not placeable: nothing was harvested, so nothing would add to it.
		{"objective": "improve_yield"},
		# Already built.
		{"objective": "church"},
		# Not reachable: the library stands on a theatre.
		{"objective": "library"},
		{"objective": "town_pasture"},
	]}]})
	town.spend_share(1.0)
	assert_false(ObjectiveSelector.can_obtain(town, &"iron", harness["context"]),
		"the fixture can get iron, so the foundry tests nothing")
	assert_eq(String(ObjectiveSelector.choose(town, GovernorIntent.GO_TALL, harness["context"])["id"]),
		"town_pasture")


## A town of `people` on a wide stretch of plains with no sea anywhere near it.
func _inland(people: int) -> Dictionary:
	var map := WorldMap.new(31, 31, &"plains")
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(15, 15))
	town.workers = people
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	context.companies = Companies.new()
	return {"town": town, "context": context}


func test_every_registered_condition_can_hold_and_can_fail() -> void:
	# 🔒 **A condition is an id into a switch, and an id the switch has no
	# branch for reads as a gate that is always shut** — so the building behind
	# it is never built, and nothing fails. Each id is checked both ways.
	var world := _inland(8_000)
	var town: Town = world["town"]
	var context: ColonyContext = world["context"]
	town.harvested = {"wood": 20.0}
	town.safety = 0.4
	town.quality_of_life = 0.4

	var coast := _town()
	var coastal: ColonyContext = _harness(coast)["context"]
	coast.at = Vector2i(1, 4)
	coastal.territory = Territory.compute(coastal.map, coastal.colony.in_order())

	# id -> [a condition that holds for `town`, one that does not]
	var cases := {
		"unexplored_within": [{"n": 14}, {"n": 0}],
		"companies_out_below": [{"n": 1}, {"n": 0}],
		"expeditions_launched_below": [{"n": 1}, {"n": 0}],
		"outgrows_the_colony": [{"offset": 2, "factor": 2}, {"offset": 50, "factor": 2}],
		"population_at_least": [{"n": 8_000}, {"n": 8_001}],
		"improvements_per_thousand_below": [{"n": 0.5}, {"n": 0}],
		"harvested_at_least": [{"resource": "wood", "n": 20}, {"resource": "wood", "n": 21}],
		"safety_below": [{"n": 0.5}, {"n": 0.3}],
		"quality_of_life_below": [{"n": 0.5}, {"n": 0.3}],
		"no_trade_protest_on": [{"resource": "beer"}, {"resource": "tea"}],
	}
	town.protests.append("tea")
	for id in AgendaMenu.CONDITIONS:
		if id == "coastal":
			assert_true(AgendaMenu.holds({"is": "coastal"}, coast, coastal), "a town on the shore is not coastal")
			assert_false(AgendaMenu.holds({"is": "coastal"}, town, context), "a town far inland is coastal")
			continue
		assert_true(cases.has(id), "the condition '%s' has no case here" % id)
		if not cases.has(id):
			continue
		var yes: Dictionary = cases[id][0].duplicate()
		var no: Dictionary = cases[id][1].duplicate()
		yes["is"] = id
		no["is"] = id
		assert_true(AgendaMenu.holds(yes, town, context), "%s never holds" % JSON.stringify(yes))
		assert_false(AgendaMenu.holds(no, town, context), "%s holds when it should not" % JSON.stringify(no))

	# An id nobody registered reads shut, never open.
	assert_false(AgendaMenu.holds({"is": "moon_is_full"}, town, context),
		"a condition nobody registered let the entry through")
	# Outgrowing counts the colony: a reach of one against a colony of one town.
	assert_false(AgendaMenu.holds({"is": "outgrows_the_colony", "offset": 7, "factor": 1}, town, context),
		"a town outgrew a colony exactly its own size")
	# And the improvements are counted: one farm among eight thousand people.
	context.map.build(15, 16, &"farm")
	assert_true(context.tiles_of(town).has(Vector2i(15, 16)), "the farm is not on the town's ground")
	assert_false(AgendaMenu.holds({"is": "improvements_per_thousand_below", "n": 0.1}, town, context),
		"a farm among eight thousand counted as no improvement at all")
	assert_true(AgendaMenu.holds({"is": "improvements_per_thousand_below", "n": 0.2}, town, context))

	# And the two that count what the town has sent out, with something out.
	context.companies.raise_company(Company.CROWN, 500, {}, town.id, town.at, context)
	assert_false(AgendaMenu.holds({"is": "companies_out_below", "n": 1}, town, context),
		"a town supporting a company counted none")
	town.expeditions_launched = 1
	assert_false(AgendaMenu.holds({"is": "expeditions_launched_below", "n": 1}, town, context),
		"a town that had sent an expedition counted none")


## #408's first parked test, rewritten against the menus (#429).
func test_a_military_town_reaches_its_defences() -> void:
	# A governor who answers a threat with a sugar plantation reads as broken
	# however sound his reasons. With no foe to raise a company against, no
	# country left to scout (#432) and no ground to improve, what a military town
	# builds is a wall.
	var town := _town()
	var harness := _harness(town)
	for y in harness["context"].map.height:
		for x in harness["context"].map.width:
			harness["context"].territory.visible[Vector2i(x, y)] = true
	var chosen := ObjectiveSelector.choose(town, GovernorIntent.MILITARY, harness["context"])
	var building := Building.find(StringName(chosen["id"]))
	assert_true(building != null and float(building.effect("defence", 0.0)) > 0.0,
		"a governor set on defence chose '%s'" % chosen["id"])


func test_the_governor_chooses_the_tile() -> void:
	# SPEC §11.4 locks it, and `tools/lint.gd` fails if anything outside sim/
	# writes a town's objective or its target. Here: an improvement objective
	# arrives with a tile already chosen, and it is one the town can reach.
	# **A month's work first**, because a tile is judged by what it gave (#430).
	# Two expeditions already sent, so going tall's thick expedition (#431) is
	# not what the walk reaches first.
	var town := _town()
	town.expeditions_launched = 2
	var harness := _harness(town, [ColonyMonth.WORK])
	_run_month(harness)
	var sited := ObjectiveSelector.choose(town, GovernorIntent.GO_TALL, harness["context"])
	assert_eq(Objective.kind_of(StringName(sited["id"])), Objective.IMPROVEMENT,
		"no improvement was ever on offer")
	assert_ne(sited["target"], Vector2i(-1, -1), "an improvement was chosen with no tile")
	assert_true(harness["context"].tiles_of(town).has(sited["target"]),
		"the chosen tile is outside the town's reach")


func test_the_tile_choice_is_deterministic() -> void:
	var first: Variant = null
	for _attempt in 3:
		var town := _town(GovernorIntent.GO_TALL)
		town.expeditions_launched = 2
		var harness := _harness(town, [ColonyMonth.WORK])
		_run_month(harness)
		var sited := ObjectiveSelector.choose(town, GovernorIntent.GO_TALL, harness["context"])
		assert_eq(Objective.kind_of(StringName(sited["id"])), Objective.IMPROVEMENT)
		if first == null:
			first = sited["target"]
		assert_eq(sited["target"], first)


func test_an_unobtainable_project_is_never_chosen() -> void:
	# The militia needs guns, guns need iron, the town produces no ore and has no
	# money. That objective is unreachable and no amount of patience fixes it, so
	# the walk passes over it.
	var town := _town()
	town.spend_gold(500.0)
	var harness := _harness(town)
	for intent in GovernorIntent.IN_ORDER:
		var chosen := StringName(ObjectiveSelector.choose(town, intent, harness["context"])["id"])
		var building := Building.find(chosen)
		if building == null:
			continue
		for resource in building.cost:
			assert_true(ObjectiveSelector.can_obtain(town, StringName(resource), harness["context"]),
				"%s chose '%s' though its %s is unobtainable" % [intent, chosen, resource])


# --- Both kinds of objective ------------------------------------------------

## #408's second parked test, rewritten against the menus (#429).
func test_a_project_is_chosen_carried_and_completed() -> void:
	var town := _town(GovernorIntent.GET_RICH, {
		"food": 200.0, "clothing": 50.0, "wood": 200.0, "stone": 200.0,
		"tools": 50.0, "iron": 50.0,
	})
	var harness := _harness(town, [
		ColonyMonth.RECKON, ColonyMonth.EXCHANGE, ColonyMonth.CONSUME,
		ColonyMonth.BUILD, ColonyMonth.SETTLE,
	])

	for _month in 8:
		_run_month(harness)

	assert_not_empty(harness["context"].log.of_type(ObjectiveSelector.EVENT_CHOSEN))
	# **A project, not specifically a building.** Which one is the menu's
	# business and the Author's to reorder. What this test is about is that
	# whatever the walk took got finished.
	assert_not_empty(harness["context"].log.of_type(BuildPhase.EVENT_COMPLETED),
		"eight months and a full timber yard finished nothing at all")


## #408's third parked test, rewritten against the menus (#429). The objective
## that is not a building is now the shared fallback itself.
func test_a_town_with_nothing_wanted_holds_no_building() -> void:
	# 🔒 §3: when nothing on the menu is taken, the objective is *no
	# building* — not a construction, and with no tile.
	AgendaMenu.load_from({"intents": [{"id": "go_tall", "menu": [
		{"objective": "granary", "when": [{"is": "population_at_least", "n": 1_000_000}]},
	]}]})
	var town := _town(GovernorIntent.GO_TALL, {"food": 200.0, "clothing": 50.0})
	var harness := _harness(town, [ColonyMonth.SETTLE])
	_run_month(harness)

	assert_eq(String(town.objective), String(AgendaMenu.NO_BUILDING))
	assert_eq(Objective.kind_of(town.objective), Objective.NO_BUILDING)
	assert_eq(town.objective_target, Vector2i(-1, -1), "the fallback was given a tile")
	assert_false(Objective.display_name(town.objective).is_empty(),
		"the fallback has no name a governor could write about")


func test_no_building_takes_a_menu_item_the_first_settle_its_gate_opens() -> void:
	# 🔒 §3: *no building* **does not hold.** The menu is walked again every
	# Settle, and the month a gate opens is the month the town takes it.
	AgendaMenu.load_from({"intents": [{"id": "go_tall", "menu": [
		{"objective": "granary", "when": [{"is": "population_at_least", "n": 50_000}]},
	]}]})
	var town := _town(GovernorIntent.GO_TALL, {"food": 400.0, "clothing": 100.0})
	var harness := _harness(town, [ColonyMonth.SETTLE])
	_run_month(harness)
	_run_month(harness)
	assert_eq(String(town.objective), String(AgendaMenu.NO_BUILDING))
	assert_eq(harness["context"].log.of_type(ObjectiveSelector.EVENT_CHOSEN).size(), 1,
		"a second month of the fallback was reported as a fresh choice")

	town.workers = 50_000
	_run_month(harness)
	assert_eq(String(town.objective), "granary", "the gate opened and the town went on idling")


func test_no_building_is_walked_again_and_a_building_is_held() -> void:
	var town := _town(GovernorIntent.GO_TALL)
	town.objective = AgendaMenu.NO_BUILDING
	town.objective_intent = GovernorIntent.GO_TALL
	assert_eq(String(Reconsideration.verdict(town)), String(Reconsideration.OPEN),
		"the fallback was held like a project")

	town.objective = &"granary"
	assert_eq(String(Reconsideration.verdict(town)), String(Reconsideration.NONE),
		"a project was reopened while its intent stood")

	town.intent = GovernorIntent.MILITARY
	assert_eq(String(Reconsideration.verdict(town)), String(Reconsideration.INTENT_CHANGED),
		"a project outlived the intent it stood for")


# --- 🔒 Held until complete, the intent changes, or it stalls ---------------

func test_a_town_does_not_oscillate() -> void:
	# A town making progress simply carries on, so months of running produce no
	# abandoned projects at all.
	# **Iron is a build cost since `buildings.md` §5.** Without it in the stores
	# a town with "everything it needed" could not finish anything it chose, and
	# this test would be measuring that instead of oscillation.
	var town := _town(GovernorIntent.GET_RICH, {
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
	# A town buying its tools a few at a time is getting somewhere, and the idle
	# count a letter reads says so.
	var town := _town(GovernorIntent.GET_RICH)
	town.objective = &"granary"
	town.objective_intent = GovernorIntent.GET_RICH
	town.store(&"wood", 10.0)
	var harness := _harness(town, [ColonyMonth.BUILD])

	_run_month(harness)
	assert_eq(town.objective_idle_months, 0, "a month that put ten of timber in was called idle")

	_run_month(harness)
	assert_eq(town.objective_idle_months, 1, "a month that put nothing in was not counted")


## A build with `share` of its materials already in the frame.
##
## **Materials, not months** (#148): the materials *are* the progress, so
## investing everything makes a finished build rather than a half-raised one.
func _part_built(objective: StringName, share: float) -> Town:
	var town := _town(GovernorIntent.GET_RICH)
	town.objective = objective
	town.objective_intent = GovernorIntent.GET_RICH
	var building := Building.find(objective)
	for resource in building.costed_resources():
		var cost := building.cost_of(StringName(resource))
		town.store(StringName(resource), cost)
		town.invest(StringName(resource), cost * share)
	town.objective_progress = 1
	return town


## Part-built, with nothing to put into the rest: the stores hold none of it
## and the purse is empty.
func _stranded(objective: StringName, share: float) -> Town:
	var town := _part_built(objective, share)
	for resource in town.stocked():
		town.take(StringName(resource), town.held(StringName(resource)))
	town.spend_share(1.0)
	return town


func test_a_change_of_intent_ends_even_a_project_most_of_the_way_up() -> void:
	# 🔒 §3: held until complete **or the intent changes**. There is no
	# sunk-cost exception, and the timber already in the frame is lost.
	var town := _part_built(&"church", 0.9)
	AgendaMenu.load_from({"intents": [
		{"id": "get_rich", "menu": [{"objective": "church"}]},
		{"id": "military", "menu": [{"objective": "stockade"}]},
	]})
	var harness := _harness(town, [ColonyMonth.SETTLE])
	town.intent = GovernorIntent.MILITARY
	_run_month(harness)

	var events: Array = harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED)
	assert_eq(events.size(), 1, "a change of intent left the project standing")
	assert_eq(String(events[0].payload["reason"]), String(Reconsideration.INTENT_CHANGED))
	assert_eq(String(town.objective), "stockade")


func test_a_new_intent_that_wants_the_same_building_carries_on_with_it() -> void:
	# Both menus name the granary. Tearing down a frame to raise the same frame
	# would forfeit the timber for nothing, so the town keeps building and the
	# project now serves the new intent (assumption recorded on #429).
	var town := _part_built(&"granary", 0.5)
	AgendaMenu.load_from({"intents": [
		{"id": "get_rich", "menu": [{"objective": "granary"}]},
		{"id": "go_tall", "menu": [{"objective": "granary"}]},
	]})
	var invested := town.invested(&"wood")
	var harness := _harness(town, [ColonyMonth.SETTLE])
	town.intent = GovernorIntent.GO_TALL
	_run_month(harness)

	assert_eq(String(town.objective), "granary")
	assert_eq(String(town.objective_intent), String(GovernorIntent.GO_TALL))
	assert_almost_eq(town.invested(&"wood"), invested, 0.001, "the frame was torn down and begun again")
	assert_empty(harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED))


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


func test_a_building_going_nowhere_for_three_months_is_given_up() -> void:
	# 🔒 §3, the Author's ruling (#467): *a building or an improvement stalls.*
	# Three months running with nothing committed, and the town gives it up,
	# takes back exactly what it had put in, and walks its menu that same month.
	var town := _stranded(&"church", 0.5)
	AgendaMenu.load_from({"intents": [
		{"id": "get_rich", "menu": [{"objective": "church"}, {"objective": "granary"}]},
	]})
	var sunk := town.objective_invested.duplicate()
	var harness := _harness(town, [ColonyMonth.BUILD, ColonyMonth.SETTLE])

	for _month in Reconsideration.STALL_MONTHS - 1:
		_run_month(harness)
	assert_eq(String(town.objective), "church", "a town gave up before three idle months")
	assert_empty(harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED))

	_run_month(harness)
	var events: Array = harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED)
	assert_eq(events.size(), 1, "three months of nothing did not stall the church")
	if events.size() != 1:
		return
	assert_eq(String(events[0].payload["reason"]), String(Reconsideration.STALLED))
	assert_eq(events[0].payload["returned"], sunk, "the stall did not name what it returned")
	for resource in sunk:
		assert_almost_eq(town.held(StringName(resource)), float(sunk[resource]), 0.001,
			"the %s in the frame did not come back to the stockpile" % resource)
	assert_eq(String(town.objective), "granary", "the town did not walk its menu the month it stalled")
	var chosen: Array = harness["context"].log.of_type(ObjectiveSelector.EVENT_CHOSEN)
	assert_eq(String(chosen[-1].payload["after"]), String(Reconsideration.STALLED))


func test_a_stalled_objective_is_passed_over_for_a_year() -> void:
	var town := _stranded(&"church", 0.5)
	AgendaMenu.load_from({"intents": [
		{"id": "get_rich", "menu": [{"objective": "church"}, {"objective": "granary"}]},
	]})
	var harness := _harness(town)
	var context: ColonyContext = harness["context"]
	var stalled_in := context.state.month
	Reconsideration.stall(town, context)

	for month in range(stalled_in, stalled_in + Reconsideration.PASS_OVER_MONTHS):
		context.state.month = month
		assert_eq(String(AgendaMenu.walk(town, town.intent, context)["id"]), "granary",
			"the stalled church was taken back %d months later" % (month - stalled_in))
	context.state.month = stalled_in + Reconsideration.PASS_OVER_MONTHS
	assert_eq(String(AgendaMenu.walk(town, town.intent, context)["id"]), "church",
		"the church was still passed over after a year")


func test_a_month_with_something_committed_keeps_the_objective() -> void:
	# Two idle months, then ten of timber into the frame: the count starts
	# again, and the church is still the church.
	var town := _stranded(&"church", 0.5)
	town.objective_idle_months = Reconsideration.STALL_MONTHS - 1
	town.store(&"wood", 10.0)
	var harness := _harness(town, [ColonyMonth.BUILD, ColonyMonth.SETTLE])
	_run_month(harness)

	assert_eq(String(town.objective), "church")
	assert_eq(town.objective_idle_months, 0)
	assert_empty(harness["context"].log.of_type(Reconsideration.EVENT_ABANDONED))


func test_expeditions_companies_and_no_building_never_stall() -> void:
	# They can leave with nothing but their share of the town's people (#467).
	var town := _town(GovernorIntent.GET_RICH)
	town.objective_intent = GovernorIntent.GET_RICH
	town.objective_idle_months = 120
	for objective in [&"lean_expedition", &"thick_expedition", &"scouting_company", &"big_company"]:
		town.objective = objective
		assert_eq(String(Reconsideration.verdict(town)), String(Reconsideration.NONE),
			"%s stalled" % objective)
	town.objective = AgendaMenu.NO_BUILDING
	assert_eq(String(Reconsideration.verdict(town)), String(Reconsideration.OPEN))


func test_what_a_stall_passes_over_survives_a_save() -> void:
	var town := _stranded(&"church", 0.5)
	var harness := _harness(town)
	Reconsideration.stall(town, harness["context"])
	var restored := Town.from_dict(bytes_to_var(var_to_bytes(town.to_dict())))
	assert_eq(restored.passed_over, town.passed_over)
	assert_true(restored.is_passing_over(&"church", harness["context"].state.month),
		"a reload forgot what the town had just given up")


# --- 🔒 The PC argues for a goal and nothing else ---------------------------

func test_urging_an_intent_does_not_set_it() -> void:
	# SPEC §8.5: orders are requests. A governor who has been written to still
	# weighs the letter against his own reading of his town, and may keep his own
	# mind.
	var town := _town(GovernorIntent.GET_RICH)
	var colony := Colony.new()
	colony.add(town)

	var executor := UrgeIntentExecutor.new()
	executor.colony = colony
	var intent := Intent.new(
		&"", UrgeIntentExecutor.KIND, town.governor_id, town.governor_id, 1,
		{"intent": String(GovernorIntent.MILITARY)},
	)
	var log := EventLog.new()
	var state := WorldValues.initial_state()
	state.month = 5

	assert_eq(String(executor.execute(intent, state, log)), String(Intent.COMPLETED))
	assert_eq(String(town.urging_by().target), String(GovernorIntent.MILITARY))
	assert_eq(town.urging_by().month, 5)
	assert_eq(String(town.intent), String(GovernorIntent.GET_RICH),
		"a letter set the governor's intent outright")


func test_what_the_pc_urged_reaches_the_deliberation() -> void:
	var town := _town(GovernorIntent.GET_RICH)
	town.urge(Urging.from_pc(GovernorIntent.MILITARY, 0))
	var harness := _harness(town)

	var deaf := _governor(&"deaf", {String(IntentConsiderations.URGING): 0.0})
	var dutiful := _governor(&"dutiful", {String(IntentConsiderations.URGING): 8.0})

	assert_eq(String(_decide(town, dutiful, harness).chosen_id()), String(GovernorIntent.MILITARY))
	assert_ne(String(_decide(town, deaf, harness).chosen_id()), String(GovernorIntent.MILITARY))


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
	town.intent = GovernorIntent.MILITARY
	town.intent_since = 7
	town.urge(Urging.from_pc(GovernorIntent.GO_TALL, 6))
	town.objective_target = Vector2i(3, 5)
	town.objective_idle_months = 2

	var restored := Town.from_dict(town.to_dict())
	assert_eq(String(restored.intent), String(GovernorIntent.MILITARY))
	assert_eq(restored.intent_since, 7)
	assert_eq(String(restored.urging_by().target), String(GovernorIntent.GO_TALL))
	assert_eq(restored.urging_by().month, 6)
	assert_eq(restored.objective_target, Vector2i(3, 5))
	assert_eq(restored.objective_idle_months, 2)
	assert_eq(String(restored.objective_intent), String(GovernorIntent.GET_RICH))
	assert_almost_eq(Objective.progress_fraction(restored), Objective.progress_fraction(town), 0.001)
