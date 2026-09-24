extends TestCase

## Six intents and the table that moves a governor between them (#428,
## `docs/mechanics/governor-agendas.md` §2, §13).
##
## 🔒 **With every weight at one, the six towns §13 was checked against choose
## what it says they choose.** The cells are the Author's and tuning may move
## them; what this pins is that the table, read the way §13 reads it, answers the
## six questions the way §13 answers them.

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


## A governor who weighs every consideration at one.
func _even_handed(loyalty: float = 60.0) -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.relationship = Relationship.new(&"gov_ashmere", loyalty)
	for id in IntentConsiderations.ALL:
		contact.set_weight(StringName(id), 1.0)
	return contact


## A town of `people` workers at the middle of a map of plains `land` tiles
## across, in a sea — small enough and there is nothing left to claim.
func _world(town: Town, land: int, month: int = 48) -> DeliberationContext:
	var map := WorldMap.new(25, 25, &"ocean")
	var half := land / 2
	for y in range(12 - half, 12 - half + land):
		for x in range(12 - half, 12 - half + land):
			map.set_terrain(x, y, &"plains")
	var colony := Colony.new()
	colony.add(town)
	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	context.month = month
	context.state.month = month
	context.rng = RngStreams.new(4280).contact_stream("gov_ashmere")
	context.data = {
		"town": town,
		"colony": colony,
		"map": map,
		"territory": Territory.compute(map, colony.in_order()),
		"mandate": "",
		"urgings": town.urgings,
	}
	return context


func _town(people: int = 12_000, food_months: float = 6.0, gold: float = 10_000.0) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(12, 12))
	town.workers = people
	town.governor_id = &"gov_ashmere"
	town.quality_of_life = 0.95
	town.safety = 1.0
	town.store(&"food", town.mouths() * ColonyNeeds.per_head(&"food") * food_months)
	town.receive_gold(gold)
	return town


func _wants(town: Town, context: DeliberationContext, loyalty: float = 60.0) -> String:
	var candidates: Array = []
	for intent in GovernorIntent.IN_ORDER:
		candidates.append(Candidate.new(intent))
	var decision := Deliberation.choose(_even_handed(loyalty), candidates, context)
	return String(decision.chosen_id()) if decision.has_choice() else ""


# --- 🔒 The six towns ---------------------------------------------------------

func test_a_quiet_prosperous_town_goes_tall() -> void:
	var town := _town()
	assert_eq(_wants(town, _world(town, 5)), String(GovernorIntent.GO_TALL))


func test_a_crowded_hungry_town_goes_wide() -> void:
	var town := _town(200_000, 0.0)
	town.quality_of_life = 0.5
	assert_eq(_wants(town, _world(town, 5)), String(GovernorIntent.GO_WIDE))


func test_a_town_under_threat_goes_military() -> void:
	var town := _town()
	town.safety = 0.0
	assert_eq(_wants(town, _world(town, 5)), String(GovernorIntent.MILITARY))


func test_a_young_town_with_room_to_spare_goes_wide() -> void:
	var town := _town()
	assert_eq(_wants(town, _world(town, 25)), String(GovernorIntent.GO_WIDE))


func test_a_poor_content_town_goes_rich() -> void:
	var town := _town(12_000, 6.0, 0.0)
	assert_eq(_wants(town, _world(town, 5)), String(GovernorIntent.GET_RICH))


func test_a_governor_at_the_loyalty_floor_goes_for_rebellion() -> void:
	var town := _town()
	assert_eq(_wants(town, _world(town, 5), 5.0), String(GovernorIntent.SEDITION))


# --- 🔒 Education comes only from the Provost or the scholar ----------------------

func test_without_their_urging_nobody_ever_holds_education() -> void:
	# Across every world above, and with the PC himself asking for it: a filter,
	# not a weight, so nothing he could say reaches it.
	var worlds: Array = []
	for people in [12_000, 200_000]:
		for safety in [1.0, 0.0]:
			for land in [5, 25]:
				var town := _town(people)
				town.safety = safety
				town.urge(Urging.from_pc(GovernorIntent.EDUCATION, 48))
				worlds.append([town, _world(town, land)])
	for entry in worlds:
		assert_ne(_wants(entry[0], entry[1]), String(GovernorIntent.EDUCATION),
			"a governor nobody but the PC urged toward learning held education")


func test_a_fresh_urging_from_the_provost_can_bring_him_there() -> void:
	for author in GovernorIntent.EDUCATION_URGED_BY:
		var town := _town()
		town.urge(Urging.make(author, GovernorIntent.EDUCATION, 47))
		assert_eq(_wants(town, _world(town, 5)), String(GovernorIntent.EDUCATION),
			"a fresh urging from the %s did not open the way to learning" % author)


func test_a_long_faded_urging_no_longer_stands() -> void:
	# Asked of the filter itself: whether education would win the vote depends
	# on everything else, and the question is only whether it is on the ballot.
	var town := _town()
	town.urge(Urging.make(&"provost", GovernorIntent.EDUCATION, 0))
	var filter := IntentConsiderations.OnlyWhenLearningIsUrged.new()
	var learning := Candidate.new(GovernorIntent.EDUCATION)
	assert_true(filter.permits(null, learning, _world(town, 5, 1)),
		"a fresh urging from the Provost did not put learning on the ballot")
	assert_false(filter.permits(null, learning, _world(town, 5, 240)),
		"an urging twenty years old still put learning on the ballot")


func test_an_expert_counts_a_thousand_when_the_town_reckons_its_wealth() -> void:
	# §13: a man of standing wants a great deal more than a labourer. Here only.
	var learned := Town.new(&"a", "A", Vector2i(0, 0))
	learned.workers = 1_000
	learned.add_experts(&"tobacco", 1)
	learned.receive_gold(60.0)
	var labouring := Town.new(&"b", "B", Vector2i(0, 0))
	labouring.workers = 2_000
	labouring.receive_gold(60.0)
	assert_almost_eq(learned.wealth_craving(60.0), labouring.wealth_craving(60.0), 0.0001,
		"one expert and a thousand labourers wanted what two thousand labourers wanted, or did not")
	assert_true(learned.wealth_craving(60.0) > 0.0, "the fixture is comfortable, so this proves nothing")


# --- 🔒 What the PC may ask for -----------------------------------------------------

func test_the_pcs_priority_step_offers_exactly_four() -> void:
	# `reply-vocabulary.md` §8: go tall, go wide, get rich and military. The
	# letters offer what the list offers, and nothing else.
	var offered: Dictionary = {}
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", String(id)))
		if not letter.has_reply():
			continue
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				var effect: Dictionary = option.get("effect", {})
				if effect.has("urge_intent"):
					offered[String(effect["urge_intent"].get("intent", ""))] = true
	var expected := [GovernorIntent.GET_RICH, GovernorIntent.GO_TALL, GovernorIntent.GO_WIDE, GovernorIntent.MILITARY]
	assert_eq(GovernorIntent.PC_URGES, expected)
	var keys: Array = offered.keys()
	keys.sort()
	assert_eq(keys, ["get_rich", "go_tall", "go_wide", "military"],
		"the letters offer the PC something other than the four")


func test_mandates_are_intents() -> void:
	# §2: a mandate *is* an intent the Crown names; rebellion never is.
	for mandate in RunSetup.MANDATES:
		assert_true(GovernorIntent.pc_may_urge(mandate), "'%s' is a mandate the PC could never urge" % mandate)


# --- 🔒 Nothing still names what is gone --------------------------------------------

func _checked() -> ContentValidator:
	var validator := ContentValidator.new()
	validator.check_agendas(content)
	return validator


func test_the_validator_refuses_a_letter_that_urges_learning() -> void:
	assert_true(_checked().ok(), "the shipped agendas do not validate")
	for id in content.ids("letters"):
		var letter: Dictionary = content.record("letters", String(id))
		for step in letter.get("reply", {}).get("steps", []):
			for option in step.get("options", []):
				var effect: Dictionary = option.get("effect", {})
				if effect.has("urge_intent"):
					effect["urge_intent"]["intent"] = String(GovernorIntent.EDUCATION)
					assert_false(_checked().ok(), "a letter let the PC urge education")
					return
	assert_true(false, "no letter urges anything, so this proves nothing")


func test_the_validator_refuses_a_cell_out_of_range_or_a_missing_row() -> void:
	var table: Dictionary = content.record("colony", "agendas")["considerations"]
	table["safety"]["military"] = 1.5
	assert_false(_checked().ok(), "a push of one and a half passed")
	table["safety"]["military"] = 1.0
	table.erase("loyalty")
	assert_false(_checked().ok(), "a table with no loyalty row passed")


func test_no_removed_intent_is_named_anywhere() -> void:
	# The village's own objective *drive them off* is not a governor's intent
	# (`natives.md`) and keeps its name.
	var gone := ["increase_economic_output", "grow_the_population", "strengthen_defences",
		"settle_a_new_town", "secure_survival", "GovernorIntent.SURVIVAL", "GovernorIntent.ECONOMY",
		"GovernorIntent.POPULATION", "GovernorIntent.DEFENCE", "GovernorIntent.SETTLEMENT",
		"GovernorIntent.DRIVE_OFF"]
	var found := PackedStringArray()
	for root in ["res://sim", "res://correspondence", "res://data"]:
		for path in _files_under(root):
			if path.begins_with("res://data/cutscenes_en"):
				continue
			var text := FileAccess.get_file_as_string(path)
			for token in gone:
				if text.contains(token):
					found.append("%s: %s" % [path, token])
	assert_empty(found, "a removed intent is still named: %s" % ", ".join(found))


func _files_under(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var path := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_files_under(path))
		elif name.ends_with(".gd") or name.ends_with(".json"):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return out
