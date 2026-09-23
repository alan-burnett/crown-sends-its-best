extends TestCase

## Slot resolution and assembly (#9).

var renderer: LetterRenderer = null
var sender: Contact = null


func before_each() -> void:
	reset_world()
	MeasureRegistry.register_linear("food_security", 0.0, 3.0)
	renderer = LetterRenderer.new()
	sender = Contact.from_data({
		"id": "marshal",
		"name": "Sir Aldous Vane",
		"title": "Marshal of the Crown",
		"town": "Penthwaite",
		"leans": {"food_security": -0.18},
	})


func after_each() -> void:
	reset_world()


func _letter(body: Array, extra: Dictionary = {}) -> Letter:
	var record: Dictionary = {
		"id": "marshal.test",
		"sender": "marshal",
		"type": "request",
		"params": {"amount": "integer", "resource": "resource"},
		"perception": {
			"larder": {"measure": "food_security", "ladder": ["starving", "hungry", "fed", "comfortable"]},
		},
		"body": body,
	}
	for key in extra:
		record[key] = extra[key]
	return Letter.from_record(record)


func _context(tone: StringName = &"dutiful") -> LetterContext:
	var context := LetterContext.new(WorldState.new(6, {}), sender, tone)
	context.params = {"amount": 200, "resource": "iron"}
	context.measures = {"food_security": 0.9}
	return context


# --- The four slot kinds ---------------------------------------------------

func test_param_resolves_exactly() -> void:
	var letter := _letter([{"text": "I require {param:amount} of {param:resource}."}])
	assert_eq(renderer.render_body(letter, _context()), "I require 200 of iron.")


func test_a_whole_number_renders_without_a_decimal_point() -> void:
	# Godot's JSON parser hands back every number as a float. "200.0" in front of
	# a player is the mistake the typed-params contract exists to prevent.
	var letter := _letter([{"text": "{param:amount} bushels."}])
	var context := _context()
	context.params["amount"] = 200.0
	assert_eq(renderer.render_body(letter, context), "200 bushels.")


func test_perception_resolves_through_the_senders_lean() -> void:
	# The Marshal leans -0.18 on food. The truth is "hungry"; he says "starving".
	var letter := _letter([{"text": "The men are {perception:larder}."}])
	assert_eq(renderer.render_body(letter, _context()), "The men are starving.")


func test_sender_fields_come_from_the_whitelist() -> void:
	var letter := _letter([{"text": "{sender:name}, {sender:title}, of {sender:town}."}])
	assert_eq(
		renderer.render_body(letter, _context()),
		"Sir Aldous Vane, Marshal of the Crown, of Penthwaite.",
	)


func test_months_silent_is_a_sender_field() -> void:
	sender.relationship.note_letter_sent(2)
	var letter := _letter([{"text": "{sender:months_silent} months."}])
	assert_eq(renderer.render_body(letter, _context()), "4 months.")


func test_an_unknown_slot_kind_does_not_reach_the_player() -> void:
	var letter := _letter([{"text": "A {bogus:thing} here."}])
	assert_false(renderer.render_body(letter, _context()).contains("bogus"))


func test_a_sender_field_off_the_whitelist_does_not_reach_the_player() -> void:
	# The whitelist is fixed so the validator can check it and renaming a field in
	# code cannot silently break hundreds of letter files.
	var letter := _letter([{"text": "Ask {sender:loyalty} of him."}])
	assert_false(renderer.render_body(letter, _context()).contains("loyalty"))


# --- Tone ------------------------------------------------------------------

func test_only_tones_omits_the_line_entirely() -> void:
	var letter := _letter([
		{"text": "The campaign drags on."},
		{"text": "Your predecessor understood.", "only_tones": ["annoyed", "hateful"]},
	])
	assert_eq(renderer.render_body(letter, _context(&"dutiful")), "The campaign drags on.")
	assert_eq(
		renderer.render_body(letter, _context(&"annoyed")),
		"The campaign drags on. Your predecessor understood.",
	)


func test_a_per_line_tone_override_replaces_that_tone_only() -> void:
	var line := {
		"text": "Your servant,",
		"tone": {"pleased": "Your most affectionate servant,", "hateful": "Do not write again."},
	}
	assert_eq(renderer.render_body(_letter([line]), _context(&"pleased")), "Your most affectionate servant,")
	assert_eq(renderer.render_body(_letter([line]), _context(&"hateful")), "Do not write again.")
	assert_eq(renderer.render_body(_letter([line]), _context(&"dutiful")), "Your servant,")


func test_an_insert_fills_for_its_tone() -> void:
	var line := {
		"text": "You shall have it entire{insert:barb}.",
		"insert": {"barb": {"annoyed": ", though it beggars the colony to do it"}},
	}
	assert_eq(
		renderer.render_body(_letter([line]), _context(&"annoyed")),
		"You shall have it entire, though it beggars the colony to do it.",
	)


func test_an_empty_insert_renders_as_nothing_not_as_a_literal() -> void:
	# The seam where a fragment was is exactly where prose stops flowing.
	var line := {
		"text": "You shall have it entire{insert:barb}.",
		"insert": {"barb": {"annoyed": ", though it beggars the colony"}},
	}
	var rendered := renderer.render_body(_letter([line]), _context(&"dutiful"))
	assert_eq(rendered, "You shall have it entire.")
	assert_false(rendered.contains("insert"))
	assert_false(rendered.contains("{"))


func test_an_insert_with_no_block_at_all_renders_as_nothing() -> void:
	var rendered := renderer.render_body(_letter([{"text": "Nothing here{insert:absent}."}]), _context())
	assert_eq(rendered, "Nothing here.")


# --- Assembly --------------------------------------------------------------

func test_lines_join_into_flowing_prose() -> void:
	var letter := _letter([
		{"text": "The campaign drags on."},
		{"text": "I require {param:amount} of {param:resource}."},
	])
	assert_eq(
		renderer.render_body(letter, _context()),
		"The campaign drags on. I require 200 of iron.",
	)


func test_punctuation_survives_a_vanished_slot_mid_sentence() -> void:
	var line := {
		"text": "The colony can spare nothing {insert:when}, and I am sorry for it.",
		"insert": {"desperate": {"annoyed": "this season"}},
	}
	var rendered := renderer.render_body(_letter([line]), _context(&"dutiful"))
	assert_false(rendered.contains("  "), "no doubled spaces: %s" % rendered)
	assert_false(rendered.contains(" ,"), "no orphaned comma: %s" % rendered)


func test_tidy_closes_the_gaps() -> void:
	assert_eq(LetterRenderer.tidy("You shall have it entire ."), "You shall have it entire.")
	assert_eq(LetterRenderer.tidy("a  b   c"), "a b c")
	assert_eq(LetterRenderer.tidy("nothing , and sorry"), "nothing, and sorry")
	assert_eq(LetterRenderer.tidy("spare nothing, , and sorry"), "spare nothing, and sorry")


func test_rendering_is_deterministic() -> void:
	var letter := _letter([{"text": "I require {param:amount} of {param:resource}, {perception:larder}."}])
	assert_eq(renderer.render_body(letter, _context()), renderer.render_body(letter, _context()))


# --- The letter model ------------------------------------------------------

func test_a_letter_with_no_reply_is_valid() -> void:
	# Reports and news need no response.
	var letter := _letter([{"text": "Merely for your information."}])
	assert_false(letter.has_reply())
	assert_false(letter.has_tone_step())


func test_silence_is_derived_from_type_not_authored() -> void:
	# SPEC §9.3. A request ignored is a rude refusal; a question ignored means the
	# sender decides for himself; a report ignored costs nothing.
	assert_true(Letter.from_record({"type": "request"}).silence_is_refusal())
	assert_true(Letter.from_record({"type": "question"}).silence_is_a_decision())
	assert_false(Letter.from_record({"type": "report"}).silence_is_refusal())
	assert_false(Letter.from_record({"type": "report"}).silence_is_a_decision())


func test_a_letter_may_offer_a_subset_of_the_tones() -> void:
	var letter := _letter([], {"reply": {"tone": {"text": "I am {choice}.", "options": [
		{"tone": "pleased", "text": "delighted"},
		{"tone": "annoyed", "text": "vexed"},
	]}}})
	assert_eq(letter.offered_tones().size(), 2)
	assert_true(letter.has_tone_step())
