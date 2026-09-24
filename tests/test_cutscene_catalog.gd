extends TestCase

## The cutscene catalog: what a caption is told, and what the validator refuses
## (#299, `docs/mechanics/cutscenes.md` §5).
##
## 🔒 **A cutscene is the engine reporting a moment as a record** — *the
## Commander led 2,400 men; he lost 300.* Every value is exact, from the event
## that earned the painting, written out as a name or a number with its
## thousands. And every cutscene the catalog ships can be shown: its images are
## registered by id so the art drops in, and its facts are supplied by every
## trigger that shows it.

const SEED: int = 2990

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


func _event(type: String, payload: Dictionary, month: int = 4, subject: StringName = &"somewhere") -> SimEvent:
	var log := EventLog.new()
	log.emit(StringName(type), subject, month, payload)
	return log.all()[0]


func _checked() -> ContentValidator:
	var validator := ContentValidator.new()
	validator.check_cutscenes(content)
	return validator


func _problems_text(validator: ContentValidator) -> String:
	var out: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func _cutscene_trigger(extra: Dictionary = {}) -> Dictionary:
	var record := {
		"id": "trigger.cutscene.t", "_source_file": "res://data/triggers/t.json",
		"cutscene": "the_first_blood", "kind": "first",
		"on": {"event_happened": {"event": "battle_fought"}},
		"params": {"date": {"from": "date"}},
	}
	record.merge(extra, true)
	return record


func _trigger_problems(extra: Dictionary) -> ContentValidator:
	var validator := ContentValidator.new()
	validator.validate_trigger(_cutscene_trigger(extra))
	return validator


# --- 🔒 The numbers are the engine's, written out --------------------------------

func test_a_head_count_is_written_as_the_people_it_stands_for() -> void:
	# The Author's figure: a company of 2.4 is 2,400 men.
	assert_eq(CutsceneParams.written(2.4, "people", null), "2,400")
	assert_eq(CutsceneParams.written(3, "people", null), "3,000")


func test_a_number_carries_its_thousands() -> void:
	assert_eq(CutsceneParams.with_thousands(0), "0")
	assert_eq(CutsceneParams.with_thousands(999), "999")
	assert_eq(CutsceneParams.with_thousands(1000), "1,000")
	assert_eq(CutsceneParams.with_thousands(1234567), "1,234,567")
	assert_eq(CutsceneParams.with_thousands(-2400), "-2,400")
	assert_eq(CutsceneParams.written(1250.4, "gold", null), "1,250")


func test_the_date_is_the_month_it_happened() -> void:
	var source := {"from": "date"}
	assert_eq(CutsceneParams.one(source, _event("x", {}, 0), null), "year 1, month 1")
	assert_eq(CutsceneParams.one(source, _event("x", {}, 14), null), "year 2, month 3")


func test_a_field_is_read_from_the_event_and_nested_fields_by_path() -> void:
	var event := _event("letter_dispatched", {"params": {"amount": 1500}})
	assert_eq(CutsceneParams.one({"from": "event", "field": "params.amount", "as": "gold"}, event, null), "1,500")


func test_a_value_nobody_could_find_is_a_visible_hole() -> void:
	# A placeholder caption with a hole in it is a hole somebody should see.
	var event := _event("battle_fought", {})
	for value in [
		CutsceneParams.one({"from": "event", "field": "attacker_men", "as": "people"}, event, null),
		CutsceneParams.one({"from": "nowhere"}, event, null),
	]:
		assert_true(String(value).begins_with("[") and String(value).ends_with("]"),
			"a missing value was hidden as '%s'" % value)


func test_a_side_is_named_the_way_the_player_hears_it() -> void:
	# CLAUDE.md: the player hears *duke*, never *rival*.
	var written := CutsceneParams.written("rival", "side", null)
	assert_false(written.contains("rival"), "a caption called a duke a rival: '%s'" % written)
	assert_true(written.contains("duke"), written)


func test_ids_are_written_as_the_names_the_player_knows() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town: Town = run.colony.in_order()[0]
	assert_eq(CutsceneParams.written(String(town.id), "town", run), town.display_name)
	var marshal := run.contact(&"marshal")
	assert_eq(CutsceneParams.written("marshal", "contact", run), marshal.display_name)
	var place := CutsceneParams.written(String(town.id), "place", run)
	assert_true(place.ends_with("at %s" % town.display_name),
		"a town's ground was not named by the town: '%s'" % place)


func test_a_trigger_supplies_every_param_it_declares() -> void:
	var supplied := CutsceneParams.supply({
		"men": {"from": "event", "field": "attacker_men", "as": "people"},
		"when": {"from": "date"},
	}, _event("battle_fought", {"attacker_men": 2}, 26), null)
	assert_eq(supplied, {"men": "2,000", "when": "year 3, month 3"})


func test_a_caption_says_what_it_was_told_and_shows_what_it_was_not() -> void:
	var cutscene := Cutscene.from_data({
		"id": "t", "params": {"men": "people", "lost": "people"},
		"panels": [{"image": "cutscene.t.1", "text": "He led {param:men}; he lost {param:lost}."}],
	})
	assert_eq(cutscene.caption_at(0, {"men": "2,400"}), "He led 2,400; he lost [lost].")


# --- 🔒 The shipped catalog can all be shown -------------------------------------

func test_every_cutscene_image_is_registered_so_the_art_drops_in_by_id() -> void:
	var validator := _checked()
	assert_true(validator.ok(), _problems_text(validator))
	var assets: Dictionary = content.collection(AssetRegistry.COLLECTION)
	var cutscene: Dictionary = content.record(Cutscene.COLLECTION, "the_first_blood")
	assets.erase(String(cutscene["panels"][0]["image"]))
	assert_false(_checked().ok(), "a painting with no asset entry passed")


func test_a_caption_naming_a_fact_the_cutscene_does_not_declare_is_refused() -> void:
	var cutscene: Dictionary = content.record(Cutscene.COLLECTION, "the_first_blood")
	cutscene["panels"][0]["text"] = "The battle, and {param:the_weather}."
	assert_false(_checked().ok())


func test_a_trigger_that_leaves_out_a_declared_fact_is_refused() -> void:
	var trigger: Dictionary = content.collection("triggers")["trigger.cutscene.the_first_blood"]
	(trigger["params"] as Dictionary).erase("defender_lost")
	assert_false(_checked().ok(), "a painting would have shown [defender_lost] and nobody was told")


func test_a_trigger_naming_a_cutscene_that_does_not_exist_is_refused() -> void:
	var trigger: Dictionary = content.collection("triggers")["trigger.cutscene.the_first_blood"]
	trigger["cutscene"] = "the_battle_nobody_painted"
	assert_false(_checked().ok())


func test_a_recurrence_standing_aside_for_a_first_nobody_shows_is_refused() -> void:
	var trigger: Dictionary = content.collection("triggers")["trigger.cutscene.shots_exchanged"]
	trigger["after"] = "a_first_nobody_shows"
	assert_false(_checked().ok())


func test_there_must_be_an_opening() -> void:
	# SPEC §6.1 opens every run with one.
	content.collection(Cutscene.COLLECTION).erase(String(Cutscene.OPENING))
	assert_false(_checked().ok())


func test_a_well_formed_cutscene_trigger_passes() -> void:
	var validator := _trigger_problems({})
	assert_true(validator.ok(), _problems_text(validator))


func test_a_cutscene_trigger_is_refused_for_each_way_it_can_be_wrong() -> void:
	var wrong := {
		"an unknown kind": {"kind": "sometimes"},
		"an unknown condition": {"on": {"the_stars_are_right": {}}},
		"a condition missing its event": {"on": {"event_happened": {}}},
		"a param the condition does not take": {"on": {"event_happened": {"event": "x", "when": 3}}},
		"a where that is not an object": {"on": {"event_happened": {"event": "x", "where": "the church"}}},
		"a first that stands aside": {"after": "the_first_blood"},
		"an unknown source": {"params": {"men": {"from": "rumour"}}},
		"an event param naming no field": {"params": {"men": {"from": "event", "as": "people"}}},
		"an unknown kind of value": {"params": {"men": {"from": "event", "field": "size", "as": "legions"}}},
		"an unknown colony measure": {"params": {"men": {"from": "colony", "measure": "morale"}}},
	}
	for why in wrong:
		assert_false(_trigger_problems(wrong[why]).ok(), "passed with %s" % why)


# --- 🔒 The machine hands the painting its facts ---------------------------------

func test_a_run_that_retires_ends_on_its_own_painting_with_its_facts() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.begin_turn()
	assert_true(machine.retire())

	var ids := PackedStringArray()
	for due in run.cutscenes_due:
		ids.append(String(due["cutscene"]))
	assert_has(ids, "ending_retired", "retiring showed %s" % [ids])
	var due: Dictionary = run.cutscenes_due[ids.find("ending_retired")]
	var declared: Dictionary = content.record(Cutscene.COLLECTION, "ending_retired")["params"]
	for name in declared:
		var value := String((due["params"] as Dictionary).get(name, CutsceneParams.UNKNOWN))
		assert_ne(value, CutsceneParams.UNKNOWN, "the retirement painting was not told '%s'" % name)


func test_landfall_names_the_town_the_colony_landed_at() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var landfall: Dictionary = {}
	for turn in 3:
		machine.begin_turn()
		for due in run.cutscenes_due:
			if String(due["cutscene"]) == "landfall":
				landfall = due
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()
	assert_not_empty(landfall, "three turns and no landfall")
	var town: Town = run.colony.in_order()[0]
	assert_eq(String(landfall["params"]["town"]), town.display_name)
