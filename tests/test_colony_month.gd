extends TestCase

## The colony month runner (#43) and the Governor (#52).

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


# --- Test doubles ----------------------------------------------------------

## Records what each town saw of every other town when its turn came.
class WatchingPhase:
	extends ColonyPhase

	var seen: Array[Dictionary] = []
	var resource: StringName = &"food"
	var takes: float = 0.0

	func _init(p_resource: StringName = &"food", p_takes: float = 0.0) -> void:
		resource = p_resource
		takes = p_takes

	func run(town: Town, before: ColonySnapshot, _context: ColonyContext) -> void:
		var view: Dictionary = {}
		for id in before.ids():
			view[id] = before.held(StringName(id), resource)
		seen.append({"town": String(town.id), "saw": view})
		if takes > 0.0:
			town.take(resource, takes)


## Notes the order phases ran in.
class OrderingPhase:
	extends ColonyPhase

	var log_of: Array[String] = []
	var phase_name: String = ""

	func _init(p_phase_name: String) -> void:
		phase_name = p_phase_name

	func run(town: Town, _before: ColonySnapshot, _context: ColonyContext) -> void:
		log_of.append("%s:%s" % [phase_name, town.id])


func _two_towns() -> Colony:
	var colony := Colony.new()
	for id in ["ashmere", "brightwater"]:
		var town := Town.new(StringName(id), id.capitalize(), Vector2i(3, 3))
		town.workers = 10
		town.store(&"food", 100.0)
		colony.add(town)
	return colony


func _context() -> ColonyContext:
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED))
	context.run_seed = SEED
	return context


# --- The locked ordering ---------------------------------------------------

func test_every_town_completes_a_phase_before_any_town_begins_the_next() -> void:
	# **🔒 SPEC §11.3.** Invisible with M2's one town; proved with two, because
	# retrofitting this onto eight phases written town-at-a-time is a rewrite.
	var colony := _two_towns()
	var month := ColonyMonth.new()
	var shared: Array[String] = []

	for phase in ColonyMonth.ORDER:
		var handler := OrderingPhase.new(String(phase))
		handler.log_of = shared
		month.set_handler(phase, handler)

	month.run(colony, _context())

	# Both towns appear under each phase before the next phase appears at all.
	var index := 0
	for phase in ColonyMonth.ORDER:
		var names: Array[String] = []
		for i in colony.size():
			names.append(shared[index])
			index += 1
		for entry in names:
			assert_true(entry.begins_with(String(phase) + ":"),
				"'%s' ran during %s" % [entry, phase])


func test_a_phase_reads_the_state_as_it_stood_when_the_phase_began() -> void:
	# The half that gets lost. Running every town through Work before anybody
	# starts Reckon is easy; making the second town's Work see the *pre-Work*
	# stockpile of the first takes a snapshot.
	var colony := _two_towns()
	var month := ColonyMonth.new()
	var watcher := WatchingPhase.new(&"food", 40.0)
	month.set_handler(ColonyMonth.WORK, watcher)

	month.run(colony, _context())

	assert_eq(watcher.seen.size(), 2)
	for record in watcher.seen:
		for id in record["saw"]:
			assert_almost_eq(float(record["saw"][id]), 100.0, 0.001,
				"%s saw %s holding %s, not the 100 it began the phase with" % [
					record["town"], id, str(record["saw"][id]),
				])

	# And the takings did happen — the snapshot is a view, not a freeze.
	for town in colony.in_order():
		assert_almost_eq(town.held(&"food"), 60.0)


func test_the_snapshot_cannot_be_written_through() -> void:
	var colony := _two_towns()
	var before := ColonySnapshot.of(colony)
	colony.by_id(&"ashmere").store(&"food", 500.0)
	assert_almost_eq(before.held(&"ashmere", &"food"), 100.0, 0.001,
		"the snapshot moved when the town did")


func test_the_nine_phases_run_in_order() -> void:
	# 🔒 **Convert sits between Consume and Build** (`town-economy.md` §11), which
	# is what stops a town brewing the grain its people have already eaten and
	# lets this month's ore reach this month's frame.
	assert_eq(ColonyMonth.ORDER, [
		ColonyMonth.WORK, ColonyMonth.RECKON, ColonyMonth.RELIEF, ColonyMonth.EXCHANGE,
		ColonyMonth.CONSUME, ColonyMonth.CONVERT, ColonyMonth.BUILD, ColonyMonth.SELL,
		ColonyMonth.SETTLE,
	])


func test_every_phase_emits_even_before_its_ticket_lands() -> void:
	# The order is observable before the work is.
	var context := _context()
	ColonyMonth.new().run(_two_towns(), context)

	var emitted: PackedStringArray = PackedStringArray()
	for event in context.log.of_type(ColonyMonth.EVENT_PHASE):
		emitted.append(String(event.payload["phase"]))
		assert_eq(event.phase, WorldPhase.COLONY_MONTH)
	assert_eq(emitted.size(), ColonyMonth.ORDER.size())


func test_tie_breaking_is_fixed_by_the_seed_and_stable() -> void:
	var colony := _two_towns()
	var first := colony.simulation_order(SEED)
	var second := colony.simulation_order(SEED)
	assert_eq(first[0].id, second[0].id, "the same seed must give the same order")

	# And it is the seed doing it, not the alphabet.
	var differs := false
	for seed_value in range(SEED, SEED + 40):
		if colony.simulation_order(seed_value)[0].id != first[0].id:
			differs = true
			break
	assert_true(differs, "no seed changed the order, so it is not seeded at all")


func test_an_unhandled_phase_still_happens() -> void:
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.BUILD, OrderingPhase.new("build"))
	var context := _context()
	month.run(_two_towns(), context)
	assert_eq(context.log.of_type(ColonyMonth.EVENT_PHASE).size(), ColonyMonth.ORDER.size())


func test_a_phase_name_that_is_not_one_of_the_nine_is_refused() -> void:
	var month := ColonyMonth.new()
	month.set_handler(&"harvest_festival", OrderingPhase.new("x"))
	assert_false(month.handlers.has(&"harvest_festival"))


# --- The driver and the seam -----------------------------------------------

func test_the_colony_driver_runs_in_phase_four_and_nowhere_else() -> void:
	var colony := _two_towns()
	var driver := ColonyDriver.new(colony, null, SEED)
	var watcher := WatchingPhase.new()
	driver.month.set_handler(ColonyMonth.WORK, watcher)

	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var streams := RngStreams.new(SEED)

	for phase in WorldPhase.ORDER:
		if phase == WorldPhase.COLONY_MONTH:
			continue
		driver.on_phase(phase, state, log, streams)
	assert_empty(watcher.seen, "the colony month ran outside phase 4")

	driver.on_phase(WorldPhase.COLONY_MONTH, state, log, streams)
	assert_eq(watcher.seen.size(), 2)


func test_the_stub_world_is_gone() -> void:
	# #43's acceptance criterion. What replaced it: the Crown's month keeps the
	# Crown's war, because that was never the colony's to run, and the colony
	# month takes phase 4.
	assert_false(ClassDB.class_exists("StubWorld"))
	assert_true(FileAccess.file_exists("res://sim/world/crown_affairs.gd"))
	assert_true(FileAccess.file_exists("res://sim/colony/colony_driver.gd"))
	assert_false(FileAccess.file_exists("res://sim/world/stub_world.gd"))


func test_correspondence_cannot_tell_the_difference() -> void:
	# It reads events and the world diff, and both keep arriving in the same
	# shapes they did when a stub produced them.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	machine.begin_turn()
	assert_not_empty(run.inbox, "the director found nothing to say about the new world")
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	machine.send_post()

	assert_false(run.last_diff.is_empty(), "a month passed and nothing changed")
	assert_not_empty(run.log.of_type(ColonyMonth.EVENT_PHASE))
	assert_not_empty(run.log.of_type(CrownAffairs.EVENT_WAR_MOVED))


func test_the_world_still_moves_month_to_month() -> void:
	# The reason the drifting placeholder exists at all: a static world makes the
	# playtest worthless, which is the failure #20 warns about.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var seen: Dictionary = {}
	for turn in 8:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()
		seen[Canonical.hash_of(WorldValues.measures(run.world))] = true
	assert_eq(seen.size(), 8, "eight months produced %d distinct situations" % seen.size())


# --- The first town --------------------------------------------------------

func test_a_run_begins_with_one_town_on_the_map() -> void:
	var run := RunState.new_run(SEED)
	assert_eq(run.colony.size(), 1)
	var town := run.colony.in_order()[0]
	assert_eq(town.at, run.starting_site)
	assert_true(run.map.is_land(town.at.x, town.at.y))
	assert_true(town.workers > 0, "a town with nobody in it is not a town")
	assert_true(town.held(&"food") > 0.0)


func test_the_town_holds_together_across_a_month() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var before := run.colony.in_order()[0].to_dict()

	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	machine.send_post()

	var after := run.colony.in_order()[0]
	assert_eq(after.id, StringName(before["id"]))
	assert_eq(after.at, before["at"])
	assert_true(after.workers > 0)


# --- The Governor (#52) ----------------------------------------------------

func test_the_first_town_has_a_governor() -> void:
	var run := RunState.new_run(SEED)
	var town := run.colony.in_order()[0]
	assert_not_empty(String(town.governor_id))

	var governor := run.contact(town.governor_id)
	assert_true(governor != null, "the town's governor is not among the contacts")
	assert_eq(governor.role, Governor.ROLE)
	assert_ne(governor.role, Contact.ROLE_CROWN_OFFICER, "he is a colony contact")


func test_the_same_seed_yields_the_same_governor() -> void:
	var first := RunState.new_run(SEED)
	var second := RunState.new_run(SEED)
	var a := first.contact(first.colony.in_order()[0].governor_id)
	var b := second.contact(second.colony.in_order()[0].governor_id)

	assert_eq(a.display_name, b.display_name)
	assert_eq(a.weights, b.weights)
	assert_eq(a.leans, b.leans)
	assert_almost_eq(a.loyalty(), b.loyalty())


func test_different_seeds_yield_different_governors() -> void:
	var names: Dictionary = {}
	for seed_value in range(SEED, SEED + 12):
		var run := RunState.new_run(seed_value)
		names[run.contact(run.colony.in_order()[0].governor_id).display_name] = true
	assert_true(names.size() > 1, "every run produced the same man")


func test_he_is_drawn_from_his_own_stream() -> void:
	# So adding a second governor in M4 changes nothing about the first.
	var quiet := RngStreams.new(SEED)
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(2, 2))
	var expected := Governor.generate(town, quiet)

	var busy := RngStreams.new(SEED)
	busy.stream("sim").randi()
	busy.contact_stream("marshal").randi()
	Governor.generate(Town.new(&"brightwater", "Brightwater", Vector2i(5, 5)), busy)
	var actual := Governor.generate(Town.new(&"ashmere", "Ashmere", Vector2i(2, 2)), busy)

	assert_eq(actual.display_name, expected.display_name)
	assert_eq(actual.weights, expected.weights)


func test_his_leans_are_about_his_own_town() -> void:
	# The player's picture of the colony is filtered through one man's
	# temperament — that is what makes him a lens rather than a readout.
	var run := RunState.new_run(SEED)
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	assert_not_empty(governor.leans)
	for topic in Governor.LEANED:
		assert_true(governor.leans.has(topic), "no lean on '%s'" % topic)


func test_two_governors_describe_the_same_harvest_differently() -> void:
	MeasureRegistry.register_linear("food_security", 0.0, 3.0)
	var ladder := PackedStringArray(["starving", "hungry", "fed", "comfortable", "handsomely fed"])

	var words: Dictionary = {}
	for seed_value in range(SEED, SEED + 25):
		var run := RunState.new_run(seed_value)
		var governor := run.contact(run.colony.in_order()[0].governor_id)
		words[Perception.word("food_security", 1.4, governor.lean_for("food_security"), ladder)] = true
	assert_true(words.size() > 1, "every governor described the same harvest identically")


func test_orders_to_him_resolve_through_compliance() -> void:
	var run := RunState.new_run(SEED)
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	var order := Order.new(M1Registrations.ORDER_SET_POLICY, governor.id, {
		"to": String(governor.id), "policy": "objective", "value": "fortify",
	}, run.world.month)

	var result := Compliance.resolve(
		order, governor, run.intents, run.world, run.log, run.streams
	)
	assert_true(Compliance.OUTCOMES.has(StringName(result["outcome"])))
	assert_not_empty(run.log.of_type(Deliberation.TRACE_EVENT), "no trace for his decision")


func test_he_survives_a_round_trip() -> void:
	var run := RunState.new_run(SEED)
	var restored := RunState.from_dict(run.to_dict())
	var town := restored.colony.in_order()[0]
	var governor := restored.contact(town.governor_id)

	assert_true(governor != null)
	assert_eq(governor.to_dict(), run.contact(town.governor_id).to_dict())
