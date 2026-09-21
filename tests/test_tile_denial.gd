extends TestCase

## Rival tile denial: soldiers on your ground, and no battle to report (#188,
## SPEC §11.2; `docs/mechanics/rival-pressure.md` §5).
##
## 🔒 **It is not combat.** Nothing is destroyed, nobody dies, no defeat is
## scored and **no optics debt is incurred**. The colony is merely poorer, month
## after month, for as long as he sits there.
##
## 🔒 **A denied tile is absent from Work's candidates, not scored at zero.** A
## tile nobody can reach is not a tile the town looked at and rejected.
##
## 🔒 **The only instrument is a letter with money in it.** No Order clears it;
## raising the duke's loyalty past the low band does, and nothing else.

const SEED: int = 3607

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
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.denied = run.denied
	context.territory = Territory.compute(run.map, run.colony.in_order())
	return context


## A duke deep enough in the low band to park men.
func _a_duke_at(run: RunState, loyalty: float) -> Contact:
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = loyalty
	return duke


func _park_on(run: RunState, duke: Contact) -> void:
	var driver := RivalTileDriver.new(run)
	run.territory_driver = TerritoryDriver.new(run.map, run.colony, run.knowledge)
	run.territory_driver.denied = run.denied
	run.territory_driver.on_phase(
		WorldPhase.TERRITORY, run.world, run.log, run.streams)
	driver.on_phase(WorldPhase.TERRITORY, run.world, run.log, run.streams)


# --- 🔒 Absent from the candidates, never scored at zero --------------------

func test_a_denied_tile_is_not_a_tile_the_town_can_work() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var before := context.tiles_of(town)
	assert_true(before.size() > 1, "the fixture town works nothing")

	run.denied.park(&"rival_duke", before[0], town.id, context)
	var after := context.tiles_of(town)

	assert_eq(after.size(), before.size() - 1,
		"a tile with a company standing on it was still offered to the ploughmen")
	assert_false(after.has(before[0]), "the denied tile is still in the list")


func test_the_town_keeps_every_other_field() -> void:
	# 🔒 "Yields fall by exactly what those tiles would have produced, and
	# nothing else changes."
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var before := context.tiles_of(town)
	run.denied.park(&"rival_duke", before[0], town.id, context)

	for at in context.tiles_of(town):
		assert_true(before.has(at), "denial invented a tile the town did not hold")
	assert_true(town.population() > 0, "denial cost the town people")


func test_a_colony_with_nobody_on_its_ground_is_untouched() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	assert_eq(context.tiles_of(town).size(),
		Territory.compute(run.map, run.colony.in_order()).tiles_of(town.id).size(),
		"an empty book took ground off a town anyway")


# --- 🔒 Nothing is destroyed and nobody is beaten ---------------------------

func test_denial_scores_no_defeat_and_costs_no_prestige() -> void:
	# 🔒 The heart of the mechanic. If this fired an optic, the spread between
	# asking for money and burning towns would have nothing in it again.
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var before := OpticsRegister.debt_in(run.log)

	for at in context.tiles_of(town).slice(0, 4):
		run.denied.park(&"rival_duke", at, town.id, context)

	assert_almost_eq(OpticsRegister.debt_in(run.log), before, 0.0001,
		"a company sitting in a field embarrassed the Crown at court")
	for event in run.log.of_type(DeniedTiles.EVENT_PARKED):
		assert_false(OpticsRegister.is_an_optic(event.type),
			"the parking event itself is priced by the court")
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 0, "a town was lost to it")
	assert_eq(run.log.of_type(OpticsRegister.EVENT_COMPANY_DESTROYED).size(), 0,
		"somebody was destroyed by men sitting still")


func test_nobody_dies_for_it() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var people := town.population()
	for at in context.tiles_of(town):
		run.denied.park(&"rival_duke", at, town.id, context)
	assert_eq(town.population(), people,
		"a town lost people to an army that did nothing but stand there")


# --- 🔒 Only a letter with money in it ends it ------------------------------

func test_a_duke_in_the_low_band_parks_men_and_one_above_it_does_not() -> void:
	var run := _run()
	var duke := _a_duke_at(run, RivalDuke.LOW_AT + 2.0)
	_park_on(run, duke)
	assert_true(run.denied.count_for(duke.id) > 0,
		"a duke past caring left the colony's best ground alone")

	# 🔒 Raising his loyalty past the band ends it, and nothing else does.
	duke.relationship.loyalty = RivalDuke.MEDIUM_AT + 5.0
	_park_on(run, duke)
	assert_eq(run.denied.count_for(duke.id), 0,
		"paying a duke back into the medium band left his men in the fields")


func test_a_duke_at_the_bottom_will_not_be_paid_off() -> void:
	# 🔒 The latch. There is nothing left to buy.
	var run := _run()
	var duke := _a_duke_at(run, 1.0)
	RivalDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)
	_park_on(run, duke)
	assert_true(run.denied.count_for(duke.id) > 0, "the fixture parked nobody")

	duke.relationship.loyalty = 100.0
	_park_on(run, duke)
	assert_true(run.denied.count_for(duke.id) > 0,
		"a duke who had gone to war was bought out of the fields")


func test_deeper_into_the_band_is_more_ground() -> void:
	# **Proportionate**, which is what makes it a pressure rather than an event.
	var shallow := _run()
	_park_on(shallow, _a_duke_at(shallow, RivalDuke.MEDIUM_AT - 1.0))
	var deep := _run()
	_park_on(deep, _a_duke_at(deep, RivalDuke.LOW_AT + 0.5))

	assert_true(deep.denied.held.size() > shallow.denied.held.size(),
		"a duke on the edge of war took no more ground than one merely unpaid")


func test_no_order_the_pc_can_write_clears_a_field() -> void:
	# 🔒 "The PC cannot order it cleared." Asserted against the whole table of
	# Order effects, because that is where such a thing would have to be.
	for kind in TurnMachine.order_effects():
		assert_false(String(kind).contains("denial"),
			"there is an Order that clears a rival off the colony's fields")
		assert_false(String(kind).contains("evict"),
			"there is an Order that evicts a rival")


# --- 🔒 Visible, and the victim writes --------------------------------------

func test_the_map_shows_which_ground_is_not_the_colonys_to_work() -> void:
	# 🔒 SPEC §11.2 is satisfied without an exception: a denied tile is inside
	# the colony's own influence, so it is ground the colony is looking at.
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var at := context.tiles_of(town)[0]
	run.denied.park(&"rival_duke", at, town.id, context)

	var driver := TerritoryDriver.new(run.map, run.colony, run.knowledge)
	driver.denied = run.denied
	driver.on_phase(WorldPhase.TERRITORY, run.world, run.log, run.streams)

	assert_eq(run.knowledge.denied_at(at), "rival_duke",
		"the colony could not see a company standing in its own field")


func test_the_governor_is_how_the_pc_finds_out() -> void:
	# `contacts.md` §6 and §5: **the victim writes.** There is no blockade
	# bulletin — the man whose fields they are asks the PC to deal with them, and
	# the ask is how the player learns money is the only answer.
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	run.denied.park(&"rival_duke", context.tiles_of(town)[0], town.id, context)

	var letter := LetterContext.new(run.world, run.contact(town.governor_id))
	letter.town = town
	letter.log = run.log
	assert_true(ContentRegistry.test_condition("they_are_on_my_fields", {}, letter),
		"a governor with a company in his fields had nothing to say about it")
	assert_eq(int(ContentRegistry.supply_param("denied_fields", {}, letter)), 1,
		"he could not count the fields he had lost")


func test_a_governor_with_clear_fields_says_nothing() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var letter := LetterContext.new(run.world, run.contact(town.governor_id))
	letter.town = town
	letter.log = run.log
	assert_false(ContentRegistry.test_condition("they_are_on_my_fields", {}, letter),
		"a governor wrote home about soldiers nobody had sent")


func test_no_duke_announces_it_himself() -> void:
	# There is no blockade bulletin. He does not write to say he has done it.
	for id in content.ids("letters"):
		var record: Dictionary = content.record("letters", String(id))
		if not String(record.get("sender", "")).begins_with("rival_duke"):
			continue
		for line in record.get("body", []):
			var text := String(line.get("text", "")).to_lower()
			assert_false(text.contains("your fields") or text.contains("my soldiers"),
				"%s has a duke announcing the blockade himself" % id)


# --- The save, and determinism ----------------------------------------------

func test_a_save_mid_denial_restores_the_same_tiles() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := _context(run)
	var taken: Array[Vector2i] = []
	for at in context.tiles_of(town).slice(0, 3):
		run.denied.park(&"rival_duke", at, town.id, context)
		taken.append(at)

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.denied.held.size(), run.denied.held.size(),
		"a reload cleared the fields")
	for at in taken:
		assert_true(restored.denied.is_denied(at),
			"a reload moved a company off %s" % at)
		assert_eq(String(restored.denied.denied_by(at)), "rival_duke",
			"a reload forgot whose men they were")


func test_the_same_seed_parks_the_same_men_on_the_same_ground() -> void:
	var once := _run()
	_park_on(once, _a_duke_at(once, RivalDuke.LOW_AT + 2.0))
	var twice := _run()
	_park_on(twice, _a_duke_at(twice, RivalDuke.LOW_AT + 2.0))

	assert_eq(once.denied.in_order(), twice.denied.in_order(),
		"the same seed and the same decisions put his men in different fields")
	assert_eq(once.state_hash(), twice.state_hash(),
		"two identical runs disagree about the state of the world")
