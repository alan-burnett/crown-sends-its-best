extends TestCase

## The reply wizard (#15) and composing new letters (#19).

const SEED: int = 1620

var run: RunState = null
var content: ContentDatabase = null
var composer: Composer = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()

	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	composer = Composer.new(content)


func after_each() -> void:
	reset_world()
	content.free()


func _letter(id: String) -> Letter:
	return Letter.from_record(content.record("letters", id))


func _wizard(letter_id: String, to: StringName) -> ReplyWizard:
	var outgoing := OutgoingLetter.new(letter_id, to)
	outgoing.params = {"amount": 200, "resource": "iron"}
	run.post.add(outgoing)
	return ReplyWizard.new(_letter(letter_id), outgoing)


func _context(to: StringName, params: Dictionary) -> LetterContext:
	var context := LetterContext.new(run.world, run.contact(to), &"")
	context.params = params
	context.measures = WorldValues.measures(run.world)
	return context


# --- Structure -------------------------------------------------------------

func test_the_tone_block_comes_before_the_steps() -> void:
	# The file reads top to bottom as the player's experience.
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	assert_true(wizard.has_tone_step())
	assert_eq(wizard.next_step_index(), 0, "the tone is asked first")

	wizard.choose_tone(Tone.DUTIFUL)
	assert_eq(wizard.next_step_index(), 0, "then the first step")
	assert_eq(wizard.step_prompt(0, _context(&"marshal", {})), "The supplies")


func test_each_letter_phrases_the_tone_question_in_its_own_words() -> void:
	# The tone id is the fixed global key; the wording is written fresh per letter.
	var marshal := _wizard("marshal.request_supplies", &"marshal")
	var chancellor := _wizard("chancellor.how_to_answer", &"chancellor")
	var to_marshal := _context(&"marshal", {})
	assert_ne(marshal.tone_prompt(to_marshal), chancellor.tone_prompt(_context(&"chancellor", {})))
	assert_not_empty(marshal.tone_prompt(to_marshal))


func test_the_tone_prompt_reads_as_a_blank_to_fill() -> void:
	# The insertion point is the mad-libs blank. The raw token must never reach
	# the player — it did, until somebody looked at the screen.
	var wizard := _wizard("chancellor.how_to_answer", &"chancellor")
	var prompt := wizard.tone_prompt(_context(&"chancellor", {}))
	assert_false(prompt.contains(LetterSchema.CHOICE_TOKEN), prompt)
	assert_true(prompt.contains(ReplyWizard.BLANK), prompt)


func test_a_letter_may_offer_any_subset_of_the_five() -> void:
	var marshal := _wizard("marshal.request_supplies", &"marshal")
	var chancellor := _wizard("chancellor.how_to_answer", &"chancellor")
	assert_eq(marshal.tone_options().size(), 4)
	assert_eq(chancellor.tone_options().size(), 2)

	# And a tone it does not offer is refused rather than silently accepted.
	assert_false(chancellor.choose_tone(Tone.PLEASED))
	assert_true(chancellor.choose_tone(Tone.ANNOYED))


func test_a_letter_with_no_reply_needs_none() -> void:
	# Reports and news.
	assert_false(_letter("steward.revenue_report").has_reply())


func test_the_wizard_knows_when_it_is_finished() -> void:
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	assert_false(wizard.is_complete())
	wizard.choose_tone(Tone.DUTIFUL)
	assert_false(wizard.is_complete(), "the steps are still unanswered")
	wizard.choose("grant", "full")
	assert_true(wizard.is_complete())
	assert_eq(wizard.next_step_index(), -1)


func test_an_option_the_letter_does_not_offer_is_refused() -> void:
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	assert_false(wizard.choose("grant", "burn_it_all"))
	assert_false(wizard.choose("no_such_step", "full"))


# --- Legibility ------------------------------------------------------------

## A context that can answer every param a letter declares, all with one value,
## so the only question left is whether a string is put through the renderer.
func _answering(letter: Letter) -> LetterContext:
	var params := {}
	for name in letter.params:
		params[name] = "Kettleburn"
	var context := _context(&"steward", params)
	context.tone = Tone.DUTIFUL
	return context


func test_nothing_the_wizard_shows_carries_a_raw_slot() -> void:
	# 🔒 #363. A step's prompt and an option's label are the same kind of
	# string, and only the label was ever rendered — so twelve prompts reached the
	# player as *What is to come first at {param:town}*, and eleven tone
	# questions the same way. **Every string the screen takes from the wizard,
	# over every letter that ships**, because the validator checks that a slot
	# resolves and has no way to know whether anything resolves it.
	var shown := 0
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", id))
		if not letter.has_reply():
			continue
		var wizard := ReplyWizard.new(letter, OutgoingLetter.new(id, &"steward"))
		var context := _answering(letter)
		var texts := PackedStringArray([wizard.tone_prompt(context)])
		for option in wizard.tone_options(context):
			texts.append(String(option["text"]))
		for index in wizard.steps().size():
			texts.append(wizard.step_prompt(index, context))
			for option in wizard.options_for(index, context):
				texts.append(String(option["label"]))
		for text in texts:
			shown += 1
			assert_empty(LetterSchema.slots_in(text), "'%s' shows a raw slot: %s" % [id, text])
	assert_true(shown > 100, "the sweep saw %d strings, so it read almost nothing" % shown)


func test_a_prompt_names_the_town_its_letter_is_about() -> void:
	# The acceptance line, on the letter that opens every run.
	var wizard := _wizard("governor.report_month", &"steward")
	var context := _context(&"steward", {"town": "Kettleburn"})
	var prompts := PackedStringArray()
	for index in wizard.steps().size():
		prompts.append(wizard.step_prompt(index, context))
	assert_true("".join(prompts).contains("Kettleburn"),
		"the governor's question does not name his town: %s" % prompts)


func test_every_options_effect_is_legible_from_its_label() -> void:
	# **🔒 Every choice's mechanical effect can be understood from its wording.**
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	var context := _context(&"marshal", {"amount": 200, "resource": "iron"})
	for option in wizard.options_for(0, context):
		assert_not_empty(String(option["label"]), "an option with no wording")
		assert_false(String(option["label"]).contains("{"), "a slot left in a label: %s" % option["label"])


func test_a_label_shows_the_real_figure() -> void:
	# Exact numbers may stay hidden, but the player is never misled about what he
	# is ordering.
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	var context := _context(&"marshal", {"amount": 200, "resource": "iron"})
	var labels: PackedStringArray = PackedStringArray()
	for option in wizard.options_for(0, context):
		labels.append(String(option["label"]))
	assert_true(", ".join(labels).contains("200"), "got %s" % labels)


func test_a_typical_reply_is_short_enough_to_answer_in_under_a_minute() -> void:
	# A design constraint on step and option count, not only on the UI.
	for id in content.ids("letters"):
		var letter := _letter(id)
		if not letter.has_reply():
			continue
		assert_true(letter.steps().size() <= 3, "%s asks %d questions" % [id, letter.steps().size()])
		for step in letter.steps():
			var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
			assert_true(options.size() <= 5, "%s offers %d options at one step" % [id, options.size()])


# --- Assembly --------------------------------------------------------------

func test_the_assembled_reply_is_continuous_prose() -> void:
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("grant", "full")

	var text := wizard.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"}))
	assert_false(text.contains("{"), "a slot survived into the reply: %s" % text)
	assert_false(text.contains("  "), "doubled space: %s" % text)
	assert_false(text.contains(" ."), "orphaned stop: %s" % text)
	assert_true(text.contains("200 of iron"), text)
	assert_true(text.contains("Your servant"), text)


func test_the_chosen_wording_drops_into_the_letters_own_phrasing() -> void:
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	wizard.choose_tone(Tone.PLEASED)
	wizard.choose("grant", "full")
	var text := wizard.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"}))
	assert_true(text.begins_with("Your letter finds me in the very best of humours."), text)


func test_tone_changes_the_wording_throughout_not_only_the_opening() -> void:
	var context := _context(&"marshal", {"amount": 200, "resource": "iron"})

	var dutiful := _wizard("marshal.request_supplies", &"marshal")
	dutiful.choose_tone(Tone.DUTIFUL)
	dutiful.choose("grant", "full")
	var dutiful_text := dutiful.assemble(context)

	var annoyed := _wizard("marshal.request_supplies", &"marshal")
	annoyed.choose_tone(Tone.ANNOYED)
	annoyed.choose("grant", "full")
	var annoyed_text := annoyed.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"}))

	assert_ne(dutiful_text, annoyed_text)
	# The insert in the middle of the letter fills only for the annoyed reading.
	assert_true(annoyed_text.contains("beggars the colony"), annoyed_text)
	assert_false(dutiful_text.contains("beggars the colony"), dutiful_text)


func test_the_closing_has_its_own_per_tone_override() -> void:
	var pleased := _wizard("marshal.request_supplies", &"marshal")
	pleased.choose_tone(Tone.PLEASED)
	pleased.choose("grant", "full")
	assert_true(pleased.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"}))
		.contains("most affectionate servant"))


func test_choosing_a_different_option_changes_the_prose_and_the_effect() -> void:
	var context := _context(&"marshal", {"amount": 200, "resource": "iron"})

	var granting := _wizard("marshal.request_supplies", &"marshal")
	granting.choose_tone(Tone.DUTIFUL)
	granting.choose("grant", "full")

	var refusing := _wizard("marshal.request_supplies", &"marshal")
	refusing.choose_tone(Tone.DUTIFUL)
	refusing.choose("grant", "none")

	assert_ne(granting.assemble(context), refusing.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"})))

	var granted := granting.options_for(0, context)[0]
	var refused := granting.options_for(0, context)[1]
	assert_true(granted["effect"].has("promise_resource"))
	assert_true(refused["effect"].has("refuse"))


func test_a_letter_without_a_tone_block_still_assembles() -> void:
	# Not every outgoing letter has a tone.
	var letter := _letter("marshal.request_supplies")
	letter.reply.erase(LetterSchema.KEY_TONE)
	var outgoing := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	outgoing.params = {"amount": 200, "resource": "iron"}
	var wizard := ReplyWizard.new(letter, outgoing)

	assert_false(wizard.has_tone_step())
	wizard.choose("grant", "full")
	assert_true(wizard.is_complete())
	assert_not_empty(wizard.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"})))


func test_the_wizard_never_writes_sim_state() -> void:
	var before := run.world.to_dict()
	var wizard := _wizard("marshal.request_supplies", &"marshal")
	wizard.choose_tone(Tone.ANNOYED)
	wizard.choose("grant", "full")
	wizard.assemble(_context(&"marshal", {"amount": 200, "resource": "iron"}))
	assert_eq(run.world.to_dict(), before)


# --- Composing (#19) -------------------------------------------------------

func test_a_composable_letter_is_a_reply_minus_the_body() -> void:
	# One format, not two.
	var letter := _letter("pc.request_troops")
	assert_true(letter.is_composable())
	assert_empty(letter.body)
	assert_true(letter.has_reply())
	assert_not_empty(letter.purpose)


func test_only_purposes_valid_for_the_state_are_offered() -> void:
	# **Stated as membership, not as position.** This used to assert on
	# `offered[0]`, which made adding any composable letter look like a
	# regression — the order of the list is not what the test is about.
	var offered := composer.purposes(run)
	assert_not_empty(offered)

	var ids: PackedStringArray = PackedStringArray()
	for entry in offered:
		ids.append(String(entry["letter_id"]))
		assert_not_empty(String(entry["purpose"]),
			"%s is offered with nothing to describe it" % entry["letter_id"])
	assert_true(ids.has("pc.request_troops"),
		"the troop request was not offered at all: %s" % ", ".join(ids))


func test_only_recipients_valid_for_the_purpose_are_offered() -> void:
	# Asking the purpose first is what lets the game offer only the recipients it
	# makes sense for, rather than hiding invalid pairings after the fact.
	var letter := _letter("pc.request_troops")
	var trigger: Dictionary = content.record("triggers", "trigger.pc.request_troops")

	var recipients := composer.recipients_for(letter, run, trigger)
	assert_true(recipients.has(&"marshal"), "got %s" % [recipients])

	# The Chancellor's loyalty begins below the trigger's threshold, so he is not
	# offered even though his role fits.
	assert_false(recipients.has(&"chancellor"),
		"the Chancellor should be out of reach at his starting loyalty")


func test_the_role_filter_excludes_the_wrong_sort_of_contact() -> void:
	run.add_contact(Contact.from_data({
		"id": "governor_ashmere", "name": "Governor", "role": "governor", "loyalty": 80,
	}))
	var letter := _letter("pc.request_troops")
	var trigger: Dictionary = content.record("triggers", "trigger.pc.request_troops")
	assert_false(composer.recipients_for(letter, run, trigger).has(&"governor_ashmere"))


func test_composing_uses_the_same_wizard_as_replying() -> void:
	# No duplicated code path: `begin` hands back a ReplyWizard.
	var wizard := composer.begin(run, "pc.request_troops", &"marshal")
	assert_true(wizard is ReplyWizard)
	assert_true(wizard.has_tone_step())
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("troops", "garrison")
	# Asking for troops is an asking letter, so the wizard also puts the harsh
	# question (#263, `tone.md` §9) — and *not yet asked* is not *declined*.
	assert_false(wizard.is_complete(), "the letter finished without putting the question")
	wizard.choose_harsh(false)
	assert_true(wizard.is_complete())


func test_a_composed_letter_takes_its_values_at_the_moment_of_writing() -> void:
	var wizard := composer.begin(run, "pc.ask_for_a_policy", &"marshal")
	assert_true(wizard.outgoing.params.has("cost"))
	assert_eq(typeof(wizard.outgoing.params["cost"]), TYPE_INT,
		"a declared gold param must be a whole number")
	assert_eq(wizard.outgoing.params["to"], "marshal")


func test_a_composed_letter_joins_the_post_and_can_be_rewritten_or_discarded() -> void:
	var wizard := composer.begin(run, "pc.request_troops", &"marshal")
	assert_eq(run.post.size(), 1)

	wizard.choose("troops", "garrison")
	wizard.choose("troops", "nothing")
	assert_eq(wizard.outgoing.chosen_for("troops"), "nothing")

	assert_true(run.post.discard(wizard.outgoing.id))
	assert_true(run.post.is_empty())


func test_a_composed_letter_answers_nothing() -> void:
	var wizard := composer.begin(run, "pc.request_troops", &"marshal")
	assert_eq(wizard.outgoing.in_reply_to, &"")


func test_a_composed_letter_assembles_like_any_other() -> void:
	var wizard := composer.begin(run, "pc.request_troops", &"marshal")
	wizard.choose_tone(Tone.DESPERATE)
	wizard.choose("troops", "garrison")

	var context := _context(&"marshal", wizard.outgoing.params)
	var text := wizard.assemble(context)
	assert_false(text.contains("{"), text)
	assert_true(text.begins_with("I write to you in some want of help."), text)


func test_an_unprompted_letter_reaches_the_contact_it_was_addressed_to() -> void:
	# Unprompted letters affect the Relationship, per SPEC §8.5 — which starts
	# with the Order being addressed to the right person.
	var wizard := composer.begin(run, "pc.request_troops", &"marshal")
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("troops", "garrison")

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	machine.send_post()

	assert_not_empty(machine.issued_orders)
	var order: Order = machine.issued_orders[0]
	# 🔒 **Troops are a standing policy** (#420): the letter enacts one.
	assert_eq(order.kind, M1Registrations.ORDER_ENACT_POLICY)
	assert_eq(String(order.get_param("effect", "")), String(PolicyEffects.CROWN_TROOPS))
	assert_eq(order.addressed_to, &"marshal")
	assert_true(int(order.get_param("cost", 0)) > 0)
