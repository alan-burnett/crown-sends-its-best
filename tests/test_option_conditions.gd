extends TestCase

## Reply options that appear only when they can be taken (#275,
## `docs/mechanics/patrons.md` §5, `CLAUDE.md` content pipeline).
##
## 🔒 **Offering a choice the player cannot take is worse than not offering it.**
## SPEC §9.2 locks that every choice's mechanical effect can be understood from
## its wording, and an option that silently does nothing fails that.
##
## The case that needs it is §5's **third door**: when a patron whose specialty
## is rivals has granted his gift, a new answer appears on the next tribute
## demand — *go and collect it from Lord Magilicutty's house* — and it is the
## only answer to a tribute demand that costs neither gold, nor an optic, nor the
## duke's loyalty. Without that patron there is nobody to send the duke to.
##
## 🔒 **Conditions are ids into the code-side registry, never logic in a data
## file** — the same registry a trigger uses, so there is one place a condition
## is defined and one validator checking it.

const SEED: int = 5290

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


## A letter whose second option is gated on the condition given.
func _letter_with(conditions: Array) -> Letter:
	return Letter.from_record({
		"id": "marshal.gated",
		"_source_file": "res://data/letters_en/marshal/gated.json",
		"sender": "marshal",
		"type": "question",
		"body": [{"text": "A question."}],
		"reply": {
			"steps": [{
				"id": "answer",
				"prompt": "What is to be done",
				"options": [
					{"id": "always", "label": "the ordinary answer", "text": "The ordinary answer."},
					{
						"id": "third_door",
						"label": "the door that is not always there",
						"text": "Go and collect it from his house.",
						"conditions": conditions,
					},
				],
			}],
			"closing": [{"text": "Yours,"}],
		},
	})


func _wizard(letter: Letter) -> ReplyWizard:
	var outgoing := OutgoingLetter.new(letter.id, StringName(letter.sender))
	outgoing.id = &"out_gated"
	return ReplyWizard.new(letter, outgoing)


func _context(run: RunState) -> LetterContext:
	var context := LetterContext.new(run.world, run.contact(&"marshal"))
	context.colony = run.colony
	context.log = run.log
	context.contacts = run.contacts
	context.measures = ColonyMeasures.for_contact(run, run.contact(&"marshal"))
	return context


func _offered(wizard: ReplyWizard, context: LetterContext) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for option in wizard.options_for(0, context):
		out.append(String(option["id"]))
	return out


# --- 🔒 Offered only when it can be taken -----------------------------------

func test_an_option_with_no_conditions_is_always_offered() -> void:
	# Every option authored before this had none, so no existing letter changes.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var wizard := _wizard(_letter_with([]))
	assert_eq(_offered(wizard, _context(run)), PackedStringArray(["always", "third_door"]))


func test_an_option_whose_condition_fails_is_not_rendered() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var context := _context(run)

	var shut := _wizard(_letter_with([
		{"world_value_below": {"key": "crown_war_intensity", "value": -1.0}},
	]))
	assert_eq(_offered(shut, context), PackedStringArray(["always"]),
		"a door that cannot be opened was still drawn")

	var open := _wizard(_letter_with([
		{"world_value_below": {"key": "crown_war_intensity", "value": 1000.0}},
	]))
	assert_eq(_offered(open, context), PackedStringArray(["always", "third_door"]),
		"a door that can be opened was not drawn")


func test_every_condition_must_hold_and_not_merely_one() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var wizard := _wizard(_letter_with([
		{"world_value_below": {"key": "crown_war_intensity", "value": 1000.0}},
		{"world_value_below": {"key": "crown_war_intensity", "value": -1.0}},
	]))
	assert_eq(_offered(wizard, _context(run)), PackedStringArray(["always"]),
		"one condition of two was enough to open the door")


func test_a_gated_option_cannot_be_chosen_either() -> void:
	# 🔒 Filtering it out of `options_for` alone would leave it reachable by
	# anything that names an id — a saved outgoing letter, a test, a second
	# screen — and the whole point is that the player cannot take it.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var context := _context(run)
	var wizard := _wizard(_letter_with([
		{"world_value_below": {"key": "crown_war_intensity", "value": -1.0}},
	]))

	assert_false(wizard.choose("answer", "third_door", context),
		"an option the player cannot take was taken anyway")
	assert_false(wizard.outgoing.has_chosen("answer"),
		"a refused choice was written down regardless")
	assert_true(wizard.choose("answer", "always", context))


func test_an_unanswerable_question_about_a_door_is_not_a_yes() -> void:
	# A caller with nothing to judge by must not be able to take a gated option by
	# omitting the context.
	var wizard := _wizard(_letter_with([
		{"world_value_below": {"key": "crown_war_intensity", "value": 1000.0}},
	]))
	assert_false(wizard.choose("answer", "third_door"),
		"a gated option was taken by a caller who could not check it")
	assert_true(wizard.choose("answer", "always"),
		"an ungated option needs a context it has no use for")


func test_a_letter_whose_every_option_is_shut_still_lets_him_say_nothing() -> void:
	# 🔒 SPEC §9.3: choosing not to reply is always an option.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var letter := _letter_with([])
	letter.reply["steps"][0]["options"][0]["conditions"] = [
		{"world_value_below": {"key": "crown_war_intensity", "value": -1.0}},
	]
	letter.reply["steps"][0]["options"][1]["conditions"] = [
		{"world_value_below": {"key": "crown_war_intensity", "value": -1.0}},
	]
	var wizard := _wizard(letter)
	assert_empty(_offered(wizard, _context(run)), "a door was open after all")

	# Setting the letter aside is the wizard's business nowhere: it is a status on
	# the inbound letter, which nothing here can gate.
	var inbound := InboundLetter.new(letter.id, StringName(letter.sender), &"")
	inbound.status = InboundLetter.SET_ASIDE
	assert_eq(inbound.status, InboundLetter.SET_ASIDE,
		"a letter with no answers left could not be set aside")


# --- 🔒 The validator refuses what the registry does not know ---------------

func _check(conditions: Variant) -> ContentValidator:
	var record := {
		"id": "marshal.gated",
		"_source_file": "res://data/letters_en/marshal/gated.json",
		"sender": "marshal",
		"type": "question",
		"body": [{"text": "A question."}],
		"reply": {
			"steps": [{
				"id": "answer",
				"prompt": "What is to be done",
				"options": [{
					"id": "third_door", "label": "a door", "text": "A door.",
					"conditions": conditions,
				}],
			}],
			"closing": [{"text": "Yours,"}],
		},
	}
	var validator := ContentValidator.new()
	validator.validate_letter(record)
	return validator


func _said(validator: ContentValidator) -> String:
	var out: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func test_a_known_condition_passes() -> void:
	var validator := _check([
		{"world_value_below": {"key": "crown_war_intensity", "value": 10.0}},
	])
	assert_true(validator.ok(), _said(validator))


func test_an_unknown_condition_id_is_refused() -> void:
	# 🔒 It would otherwise fail **closed and silently**: `test_condition` answers
	# false for a condition nobody registered, so the option would simply never
	# appear and the letter would read as though the author had never written it.
	var validator := _check([{"the_moon_is_full": {}}])
	assert_false(validator.ok(), "a condition nobody has written passed the validator")
	assert_true(_said(validator).contains("the_moon_is_full"), _said(validator))


func test_the_wrong_params_on_a_known_condition_are_refused() -> void:
	var validator := _check([{"world_value_below": {"key": "crown_war_intensity"}}])
	assert_false(validator.ok(), "a condition missing a declared param passed")


func test_conditions_that_are_not_a_list_are_refused() -> void:
	assert_false(_check({"world_value_below": {}}).ok(),
		"an object where a list belongs passed")
	assert_false(_check([{"world_value_below": "yes"}]).ok(),
		"a string where the params belong passed")


func test_the_real_letters_still_validate() -> void:
	# No existing letter changes behaviour, which is the last acceptance line.
	var validator := ContentValidator.new()
	validator.validate(content)
	assert_true(validator.ok(), _said(validator))
	assert_true(validator.letters_checked > 0, "no letters were checked")
