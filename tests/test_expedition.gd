extends TestCase

## Lean and thick expeditions (#431, `docs/mechanics/founding-towns.md` §2,
## `governor-agendas.md` §6).
##
## 🔒 **Which intent sent it is the whole difference.** Go wide gathers for two
## months and sends a fifth of the town; go tall gathers for five and sends two
## fifths. While it gathers, the town holds back its wood, stone, tools and
## food; when it leaves, it takes all of them above the normal reserve, and
## never a building.

const SEED: int = 5507

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


func _town(id: StringName = &"ashmere", people: int = 10_000, stock: Dictionary = {},
		at: Vector2i = Vector2i(3, 3)) -> Town:
	var town := Town.new(id, String(id).capitalize(), at)
	town.workers = people
	town.receive_gold(1_000.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _context(towns: Array) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var map := WorldMap.new(21, 21, &"ocean")
	for y in range(1, 20):
		for x in range(1, 20):
			map.set_terrain(x, y, &"plains")
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return context


## Reckon then Build, which is all an expedition's gathering and leaving touch.
func _month(context: ColonyContext) -> void:
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.BUILD, BuildPhase.new())
	month.run(context.colony, context)
	context.state.month += 1


func _launched(context: ColonyContext) -> Array:
	return context.log.of_type(Expedition.EVENT_LAUNCHED)


func _lean_entry() -> Dictionary:
	for entry in AgendaMenu.menu_of(GovernorIntent.GO_WIDE):
		if String(entry.get("objective", "")) == "lean_expedition":
			return entry
	return {}


# --- 🔒 Lean and thick -------------------------------------------------------

func test_a_lean_expedition_leaves_two_months_after_it_is_chosen_with_a_fifth() -> void:
	var town := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0})
	var context := _context([town])
	town.objective = &"lean_expedition"

	_month(context)
	assert_empty(_launched(context), "a lean expedition left after one month")
	_month(context)
	var launched := _launched(context)
	assert_eq(launched.size(), 1, "a lean expedition had not left after two months")
	assert_eq(int(launched[0].payload["people"]), 2_000)
	assert_almost_eq(float(launched[0].payload["gold"]), 200.0, 0.01,
		"a fifth of the people left with something other than a fifth of the coin")
	assert_eq(town.population(), 8_000)
	assert_eq(String(town.objective), "", "the town went on gathering after it had gone")


func test_a_thick_expedition_gathers_five_months_and_takes_two_fifths() -> void:
	var town := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0})
	var context := _context([town])
	town.objective = &"thick_expedition"
	for _month_index in 4:
		_month(context)
	assert_empty(_launched(context), "a thick expedition left before its fifth month")
	assert_almost_eq(Objective.progress_fraction(town), 0.8, 0.0001)
	_month(context)
	assert_eq(_launched(context).size(), 1)
	assert_eq(int(_launched(context)[0].payload["people"]), 4_000)
	assert_almost_eq(float(_launched(context)[0].payload["gold"]), 400.0, 0.01)


# --- 🔒 What it gathers and what it takes --------------------------------------

func test_while_it_gathers_the_town_holds_back_what_it_will_carry() -> void:
	var gathering := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0, "clothing": 200.0})
	gathering.objective = &"thick_expedition"
	var idle := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0, "clothing": 200.0})
	var one := _context([gathering])
	var other := _context([idle])
	_month(one)
	_month(other)
	var held: Reckoning = one.reckonings["ashmere"]
	var usual: Reckoning = other.reckonings["ashmere"]

	assert_true(usual.spare_of(&"wood") > 0.0, "the fixture has no timber to spare, so this compares nothing")
	assert_almost_eq(held.spare_of(&"wood"), 0.0, 0.0001, "a town gathering an expedition sold its timber")
	assert_almost_eq(float(held.normal_reserve.get("wood", -1.0)), usual.reserve_of(&"wood"), 0.0001,
		"the reserve the expedition leaves behind is not the one the town keeps anyway")
	assert_almost_eq(held.spare_of(&"clothing"), usual.spare_of(&"clothing"), 0.0001,
		"gathering held back something an expedition never carries")


func test_when_it_leaves_it_takes_everything_of_the_four_above_the_normal_reserve() -> void:
	var town := _town(&"ashmere", 10_000, {
		"food": 900.0, "wood": 400.0, "stone": 80.0, "tools": 50.0, "clothing": 200.0,
	})
	var context := _context([town])
	town.objective = &"lean_expedition"
	_month(context)
	_month(context)

	var cargo: Dictionary = _launched(context)[0].payload["cargo"]
	var reckoning: Reckoning = context.reckonings["ashmere"]
	for resource in cargo:
		assert_true(Expedition.GATHERS.has(String(resource)), "it carried %s" % resource)
	var before := {"food": 900.0, "wood": 400.0, "stone": 80.0, "tools": 50.0}
	for resource in before:
		var keep := float(reckoning.normal_reserve.get(resource, 0.0))
		assert_almost_eq(town.held(StringName(resource)), minf(float(before[resource]), keep), 0.001,
			"the town kept something other than its normal reserve of %s" % resource)
	assert_true(float(cargo.get("wood", 0.0)) > 0.0, "four hundred timber and it took none")
	assert_almost_eq(town.held(&"clothing"), 200.0, 0.001, "it took clothing, which it never gathers")


func test_a_new_town_starts_with_nothing_built_but_its_hall() -> void:
	# Resources only, never buildings (§2). The parent's church stays home.
	var town := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0})
	town.add_building(&"church")
	var context := _context([town])
	town.objective = &"lean_expedition"
	_month(context)
	_month(context)

	var party: ExpeditionParty = context.parties[0]
	party.at = Vector2i(12, 12)
	var founded := party.found(&"newhaven", "Newhaven", context)
	assert_true(founded != null, "the party founded nothing")
	assert_eq(Array(founded.buildings), [String(Building.BASE)],
		"a new town began with more than its hall: %s" % [founded.buildings])


# --- 🔒 Scouts send it out better found (#413) --------------------------

## Launch a lean expedition from a town alike in every way but its scouts.
func _launch_from(with_scouts: bool) -> Dictionary:
	var town := _town(&"ashmere", 10_000, {"food": 900.0, "wood": 400.0, "stone": 80.0, "tools": 50.0})
	if with_scouts:
		town.add_building(&"scouts")
	var context := _context([town])
	town.objective = &"lean_expedition"
	_month(context)
	_month(context)
	return {"payload": _launched(context)[0].payload, "town": town}


func test_scouts_double_the_stores_and_add_ten_tools() -> void:
	# `founding-towns.md` §2, Author's ruling on #413. Lean and thick alike.
	var bare := _launch_from(false)
	var scouted := _launch_from(true)
	var plain: Dictionary = bare["payload"]
	var found: Dictionary = scouted["payload"]
	var without: Dictionary = plain["cargo"]
	var with: Dictionary = found["cargo"]
	assert_false(without.is_empty(), "the fixture sent nothing, so this compares nothing")
	for resource in Expedition.GATHERS:
		var expected := 2.0 * float(without.get(resource, 0.0)) + (10.0 if resource == "tools" else 0.0)
		assert_almost_eq(float(with.get(resource, 0.0)), expected, 0.001,
			"%s: scouts sent %s where %s was due" % [resource, with.get(resource, 0.0), expected])
	assert_eq(int(found["people"]), int(plain["people"]), "scouts changed who went")
	# **The same share of the purse.** Not the same sum: the scouts' post has
	# upkeep of its own, so the purse it takes a share of is smaller.
	for pair in [[plain, bare["town"]], [found, scouted["town"]]]:
		var took := float(pair[0]["gold"])
		var left: float = (pair[1] as Town).spend_share(1.0)
		assert_almost_eq(took / (took + left), 0.2, 0.0001, "scouts changed the share of the purse it took")


func test_the_extra_comes_from_the_wild_and_not_from_the_town() -> void:
	var plain: Town = _launch_from(false)["town"]
	var scouted: Town = _launch_from(true)["town"]
	for resource in Expedition.GATHERS:
		assert_almost_eq(scouted.held(StringName(resource)), plain.held(StringName(resource)), 0.001,
			"a town with scouts gave more %s than one without" % resource)


func test_the_validator_refuses_outfitting_it_cannot_read() -> void:
	# A misspelt resource would add nothing, and nothing would say so.
	var validator := ContentValidator.new()
	validator.check_expedition_outfitting(content)
	assert_true(validator.ok(), "the shipped scouts do not validate")
	var effects: Dictionary = content.collection("buildings")["scouts"]["effects"]
	effects["expedition_stores"]["add"] = {"muskets": 10}
	validator = ContentValidator.new()
	validator.check_expedition_outfitting(content)
	assert_false(validator.ok(), "an expedition was outfitted with something it never carries")


# --- 🔒 When go wide sends one (§7) ---------------------------------------------

func test_going_wide_sends_one_while_the_town_outgrows_the_colony() -> void:
	# `(population ÷ 1000 − 2) × 2 > towns + expeditions on their way`, and no
	# per-town cap. A town of 3,000 alone: 2 > 1.
	var entry := _lean_entry()
	assert_false(entry.is_empty(), "go wide's menu names no lean expedition")
	var alone := _town(&"ashmere", 3_000, {"food": 200.0})
	var context := _context([alone])
	assert_true(AgendaMenu.wanted(entry, alone, context), "a town of three thousand, alone, sent nobody")
	assert_true(Expedition.may_launch(alone, &"lean_expedition"))
	alone.objective = &"lean_expedition"
	_month(context)
	_month(context)
	assert_eq(_launched(context).size(), 1)
	assert_eq(int(_launched(context)[0].payload["people"]), 600)

	# Six towns and one expedition out: 7. A town of 5,000 makes 6; of 6,000, 8.
	for pair in [[5_000, false], [6_000, true]]:
		var towns: Array = [_town(&"ashmere", int(pair[0]))]
		for index in 5:
			towns.append(_town(StringName("other_%d" % index), 1_000, {}, Vector2i(4 + index * 3, 15)))
		var crowded := _context(towns)
		crowded.parties.append(ExpeditionParty.new())
		assert_eq(AgendaMenu.wanted(entry, towns[0], crowded), bool(pair[1]),
			"a town of %d among six, one expedition out" % pair[0])


## A colony that has seen every tile, so no scouting party is ever wanted.
func _explored(towns: Array) -> ColonyContext:
	var context := _context(towns)
	for y in context.map.height:
		for x in context.map.width:
			context.territory.visible[Vector2i(x, y)] = true
	return context


func test_the_walk_takes_the_expedition_its_intent_sends() -> void:
	# Lean for go wide, thick for go tall (§6), each through its menu. The
	# country is all explored, so no scouting party comes first.
	var wide := _town(&"ashmere", 3_000, {"food": 200.0})
	var context := _explored([wide])
	assert_eq(String(ObjectiveSelector.choose(wide, GovernorIntent.GO_WIDE, context)["id"]), "lean_expedition")

	var tall := _town(&"ashmere", 8_000, {"food": 200.0})
	var grown := _explored([tall])
	assert_eq(String(ObjectiveSelector.choose(tall, GovernorIntent.GO_TALL, grown)["id"]), "thick_expedition")
	tall.expeditions_launched = 2
	assert_ne(String(ObjectiveSelector.choose(tall, GovernorIntent.GO_TALL, grown)["id"]), "thick_expedition",
		"a town that had sent two thick expeditions sent a third")


# --- 🔒 Rebel towns never found towns ---------------------------------------

func test_a_rebel_town_never_takes_it() -> void:
	# SPEC §11.4, and a filter rather than a weight — a very expansionist rebel
	# governor must not be able to outvote it.
	var rebel := _town(&"ashmere", 40_000, {"food": 900.0})
	rebel.rebelling = true
	for id in Objective.expedition_ids():
		assert_false(Expedition.may_launch(rebel, StringName(id)), "a town at war with the Crown went colonising")
	for intent in [GovernorIntent.GO_WIDE, GovernorIntent.GO_TALL]:
		var chosen := ObjectiveSelector.choose(rebel, intent, _context([rebel]))
		assert_false(Objective.is_expedition(StringName(chosen["id"])), "a rebel town took an expedition")


func test_the_gathering_survives_save_and_reload() -> void:
	var town := _town(&"ashmere", 10_000)
	town.objective = &"thick_expedition"
	town.objective_progress = 3
	var restored := Town.from_dict(town.to_dict())
	assert_eq(String(restored.objective), "thick_expedition")
	assert_almost_eq(Objective.progress_fraction(restored), 0.6, 0.0001,
		"a reloaded town forgot how long it had been gathering")
