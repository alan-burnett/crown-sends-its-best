extends TestCase

## The content validator (#8). Every one of these is a mistake that would
## otherwise reach a player.


func before_each() -> void:
	ContentRegistry.reset()
	MeasureRegistry.reset()
	M1Registrations.register_all()


func after_each() -> void:
	ContentRegistry.reset()
	MeasureRegistry.reset()


func _valid_record() -> Dictionary:
	return {
		"id": "marshal.test",
		"_source_file": "res://data/letters_en/marshal/test.json",
		"sender": "marshal",
		"type": "request",
		"params": {"amount": "integer"},
		"perception": {
			"larder": {"measure": "food_security", "ladder": ["starving", "hungry", "fed"]},
		},
		"body": [{"text": "I require {param:amount}, the larder being {perception:larder}."}],
	}


func _check(record: Dictionary) -> ContentValidator:
	var validator := ContentValidator.new()
	validator.validate_letter(record)
	return validator


func _problems_text(validator: ContentValidator) -> String:
	var out: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


# --- The valid case --------------------------------------------------------

func test_a_valid_letter_passes() -> void:
	var validator := _check(_valid_record())
	assert_true(validator.ok(), _problems_text(validator))


func test_a_letter_with_no_reply_is_valid() -> void:
	# Reports and news need no response.
	var record := _valid_record()
	record["type"] = "report"
	record.erase("reply")
	assert_true(_check(record).ok())


func test_the_real_data_tree_validates() -> void:
	var content := ContentDatabase.new()
	content.load_all("en")
	var validator := ContentValidator.new()
	validator.validate(content)
	validator.check_trigger_targets(content)
	assert_true(validator.ok(), _problems_text(validator))
	assert_true(validator.letters_checked > 0, "no letters were checked")
	content.free()


# --- What it catches -------------------------------------------------------

func test_catches_an_undeclared_param() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "I require {param:quantity}."}]
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("{param:quantity}"), _problems_text(validator))


func test_catches_an_unknown_tone_key() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "A line.", "only_tones": ["furious"]}]
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("furious"))


func test_catches_an_unregistered_effect() -> void:
	var record := _valid_record()
	record["reply"] = {"steps": [{"id": "s", "options": [
		{"id": "o", "label": "do it", "text": "It is done.", "effect": {"summon_a_dragon": {}}},
	]}]}
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("summon_a_dragon"))


func test_catches_an_effect_called_with_a_missing_param() -> void:
	var record := _valid_record()
	record["reply"] = {"steps": [{"id": "s", "options": [
		{"id": "o", "label": "grant", "text": "Granted.", "effect": {"promise_gold": {"to": "marshal"}}},
	]}]}
	assert_false(_check(record).ok())


func test_catches_a_dangling_insert() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "You shall have it entire{insert:barb}."}]
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("{insert:barb}"))


func test_catches_an_insert_defined_but_never_used() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "A plain line.", "insert": {"barb": {"annoyed": "sharply"}}}]
	assert_false(_check(record).ok())


func test_catches_an_unresolvable_sender_field() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "His loyalty is {sender:loyalty}."}]
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("{sender:loyalty}"))


func test_accepts_every_whitelisted_sender_field() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "{sender:name} {sender:title} {sender:town} {sender:months_silent}"}]
	assert_true(_check(record).ok())


func test_catches_an_unknown_type() -> void:
	var record := _valid_record()
	record["type"] = "ultimatum"
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("ultimatum"))


func test_catches_an_unknown_param_type() -> void:
	var record := _valid_record()
	record["params"] = {"amount": "quantity"}
	assert_false(_check(record).ok())


func test_catches_an_unknown_measure() -> void:
	var record := _valid_record()
	record["perception"] = {"larder": {"measure": "the_vibe", "ladder": ["bad", "good"]}}
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("the_vibe"))


func test_catches_a_ladder_that_is_too_short() -> void:
	var record := _valid_record()
	record["perception"] = {"larder": {"measure": "food_security", "ladder": ["hungry"]}}
	assert_false(_check(record).ok())


func test_catches_a_perception_slot_with_no_entry() -> void:
	var record := _valid_record()
	record["body"] = [{"text": "The larder is {perception:cellar}."}]
	assert_false(_check(record).ok())


func test_catches_a_tone_offered_twice() -> void:
	var record := _valid_record()
	record["reply"] = {"tone": {"text": "I am {choice}.", "options": [
		{"tone": "pleased", "text": "delighted"},
		{"tone": "pleased", "text": "also delighted"},
	]}}
	assert_false(_check(record).ok())


func test_catches_an_option_with_no_label() -> void:
	# Every choice's mechanical effect must be understandable from its wording,
	# which starts with there being wording.
	var record := _valid_record()
	record["reply"] = {"steps": [{"id": "s", "options": [{"id": "o", "text": "Done."}]}]}
	assert_false(_check(record).ok())


func test_catches_a_slot_reference_to_an_undeclared_param() -> void:
	var record := _valid_record()
	record["reply"] = {"steps": [{"id": "s", "options": [
		{"id": "o", "label": "send it", "text": "Sent.",
		 "effect": {"promise_gold": {"to": "marshal", "amount": "{purse}"}}},
	]}]}
	var validator := _check(record)
	assert_false(validator.ok())
	assert_true(_problems_text(validator).contains("purse"))


# --- Error quality ---------------------------------------------------------

func test_a_problem_names_the_file_the_path_and_the_token() -> void:
	# "Invalid letter" costs more to chase than the mistake cost to make.
	var record := _valid_record()
	record["body"] = [{"text": "I require {param:quantity}."}]
	var problem: ContentValidator.Problem = _check(record).problems[0]
	assert_true(problem.file.ends_with("test.json"), problem.file)
	assert_eq(problem.path, "body[0]")
	assert_true(problem.message.contains("{param:quantity}"), problem.message)


# --- Triggers --------------------------------------------------------------

func test_catches_an_unregistered_condition_in_a_trigger() -> void:
	var validator := ContentValidator.new()
	validator.validate_trigger({
		"id": "t", "_source_file": "res://data/triggers/t.json", "letter": "marshal.test",
		"conditions": [{"the_stars_are_right": {}}],
	})
	assert_false(validator.ok())


func test_catches_a_condition_called_with_a_missing_param() -> void:
	var validator := ContentValidator.new()
	validator.validate_trigger({
		"id": "t", "_source_file": "res://data/triggers/t.json", "letter": "marshal.test",
		"conditions": [{"world_value_above": {"key": "crown_war_intensity"}}],
	})
	assert_false(validator.ok())


func test_catches_a_trigger_naming_no_letter() -> void:
	var validator := ContentValidator.new()
	validator.validate_trigger({"id": "t", "_source_file": "res://data/triggers/t.json", "conditions": []})
	assert_false(validator.ok())


func test_a_well_formed_trigger_passes() -> void:
	var validator := ContentValidator.new()
	validator.validate_trigger({
		"id": "t", "_source_file": "res://data/triggers/t.json", "letter": "marshal.test",
		"conditions": [{"world_value_above": {"key": "crown_war_intensity", "value": 30}}],
	})
	assert_true(validator.ok(), _problems_text(validator))
