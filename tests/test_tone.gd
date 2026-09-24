extends TestCase

## Tone is a consideration, weighted by vanity, mettle and pity (#260,
## SPEC §9.2; `docs/mechanics/tone.md` §4, §5).
##
## 🔒 **Inside the kernel, not on top of it.** Each tone is a consideration
## scoring zero unless the letter carries it, weighted by personality like every
## other. Built outside, every contact would react to a hateful letter
## identically and making one react differently would need a branch on who he is.
##
## 🔒 **Three traits, not five weights.** Five drawn independently produce a man
## who loves being flattered and also loves being threatened, which is a dice
## roll rather than a personality.
##
## 🔒 **A negative weight inverts that tone.** The bully needs no case of his
## own; he is two numbers below zero.
##
## 🔒 **And no branch anywhere tests which contact is reading.**

const SEED: int = 7731

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


## A contact of a given temperament, alike in every other respect.
func _man(traits: Dictionary, loyalty: float = 55.0) -> Contact:
	var contact := Contact.new(&"him", {
		"loyalty": 1.0,
		"cost_of_request": 1.0,
		"payment_offered": 1.0,
		"autonomy": 1.0,
		"order_clarity": 1.0,
		"against_his_judgement": 1.0,
	})
	contact.role = Contact.ROLE_GOVERNOR
	contact.traits = Temperament.from_record(traits)
	Temperament.write_into(contact.traits, contact)
	contact.relationship = Relationship.new(&"him", loyalty)
	return contact


## 🔒 **A directing letter, because tone reaches the six outcomes on directing
## and asking alone** (#261, `tone.md` §3).
##
## This fixture used to promise gold, which is *answering* — a man who wrote for
## money and was sent it does not then deliberate about whether to accept it — so
## every claim below was being measured against a decision that is not his to
## make.
##
## Directing rather than asking because it **costs him nothing**, and this file is
## about temperament. A two-hundred-man levy is answered by the size of the levy
## whatever the man's mettle, which is the cost consideration doing its job and
## drowning the one under test.
func _letter(tone: StringName, harsh: bool = false) -> Order:
	var order := Order.new(M1Registrations.ORDER_URGE_INTENT, &"him", {
		"intent": String(GovernorIntent.GET_RICH),
	})
	order.id = &"order_test"
	order.tone = tone
	order.harsh = harsh
	return order


## How he answers one letter.
func _answer(contact: Contact, order: Order) -> StringName:
	var run := RunState.new_run(SEED)
	var result := Compliance.resolve(
		order, contact, IntentBook.new(), run.world, run.log, run.streams)
	return StringName(result["outcome"])


## And what the kernel scored, for reading a decision rather than guessing at it.
func _totals(contact: Contact, order: Order) -> Dictionary:
	var run := RunState.new_run(SEED)
	var result := Compliance.resolve(
		order, contact, IntentBook.new(), run.world, run.log, run.streams)
	var out: Dictionary = {}
	for entry in (result["decision"] as Decision).entries:
		if entry.has("total"):
			out[String(entry["id"])] = float(entry["total"])
	return out


# --- 🔒 Five considerations, silent unless addressed ------------------------

func test_there_is_one_consideration_per_tone() -> void:
	var registered: Dictionary = {}
	for consideration in Deliberation.considerations_for(DecisionKind.ORDER_COMPLIANCE):
		registered[String(consideration.id)] = true

	for tone in Tone.ALL:
		assert_true(registered.has(String(ToneConsiderations.of(tone))),
			"there is no consideration for a letter written %s" % tone)
	assert_eq(ToneConsiderations.ids().size(), 5,
		"the five tones are not five considerations")


func test_a_tone_consideration_says_nothing_about_another_tone() -> void:
	# 🔒 One with an opinion about a letter written in some other manner would
	# shift every decision in the game by a constant, which is the difference
	# between a consideration and a thumb on the scale.
	var context := DeliberationContext.new(
		DecisionKind.ORDER_COMPLIANCE, WorldValues.initial_state(), EventLog.new())
	context.data = {"tone": String(Tone.HATEFUL)}

	var pleased := ToneConsiderations.Pleased.new(ToneConsiderations.of(Tone.PLEASED))
	for outcome in Compliance.OUTCOMES:
		assert_almost_eq(
			pleased.score(null, Candidate.new(outcome), context), 0.0, 0.0001,
			"the pleased consideration had a view on a hateful letter")

	var hateful := ToneConsiderations.Hateful.new(ToneConsiderations.of(Tone.HATEFUL))
	var said := 0.0
	for outcome in Compliance.OUTCOMES:
		said += absf(hateful.score(null, Candidate.new(outcome), context))
	assert_true(said > 0.0, "the hateful consideration had nothing to say either")


func test_a_letter_with_no_tone_at_all_moves_nothing() -> void:
	var context := DeliberationContext.new(
		DecisionKind.ORDER_COMPLIANCE, WorldValues.initial_state(), EventLog.new())
	context.data = {}
	for consideration in Deliberation.considerations_for(DecisionKind.ORDER_COMPLIANCE):
		if not ToneConsiderations.ids().has(String(consideration.id)):
			continue
		for outcome in Compliance.OUTCOMES:
			assert_almost_eq(
				consideration.score(null, Candidate.new(outcome), context), 0.0, 0.0001,
				"%s had an opinion about a letter with no manner in it" % consideration.id)


# --- 🔒 Three traits, and dutiful has none ----------------------------------

func test_every_contact_carries_the_three() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		for trait_id in Temperament.ALL:
			assert_true(contact.traits.has(String(trait_id)),
				"%s has no %s" % [id, trait_id])


func test_a_generated_man_has_one_drawn_with_the_rest_of_him() -> void:
	var ids := PackedStringArray(["loyalty", "harshness"])
	var once := Contact.generate(
		&"gov_test", Contact.ROLE_GOVERNOR, RngStreams.new(SEED), ids)
	var twice := Contact.generate(
		&"gov_test", Contact.ROLE_GOVERNOR, RngStreams.new(SEED), ids)
	for trait_id in Temperament.ALL:
		assert_almost_eq(
			float(once.traits[String(trait_id)]), float(twice.traits[String(trait_id)]),
			0.0001, "the same seed drew a different man's %s" % trait_id)


func test_dutiful_has_no_trait_and_no_weight_anywhere() -> void:
	# 🔒 The tell that the cut is right. Its identity is *costs nothing, buys
	# nothing*, so there is nothing in it for a personality to have a view about.
	var dutiful := String(ToneConsiderations.of(Tone.DUTIFUL))
	assert_false(Temperament.derived_ids().has(dutiful),
		"a trait decides how a man takes a dutiful letter")

	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for id in run.contact_ids():
		assert_false(run.contact(StringName(id)).weights.has(dutiful),
			"%s carries a weight on being written to dutifully" % id)


func test_mettle_scales_the_harsh_clause_as_well_as_the_hostile_tones() -> void:
	# 🔒 One trait for both: a man who resents being bullied resents the threat
	# and the contempt alike.
	var proud := _man({"vanity": 0.3, "mettle": 1.5, "pity": 0.3})
	var placid := _man({"vanity": 0.3, "mettle": 0.1, "pity": 0.3})

	for id in ["harshness", String(ToneConsiderations.of(Tone.ANNOYED)),
			String(ToneConsiderations.of(Tone.HATEFUL))]:
		assert_true(proud.weight_for(StringName(id)) > placid.weight_for(StringName(id)),
			"mettle does not decide '%s'" % id)
	assert_almost_eq(proud.weight_for(&"harshness"), 1.5, 0.0001,
		"harshness is weighted by something other than his mettle")


func test_a_trait_decides_exactly_the_weights_it_is_meant_to() -> void:
	var vain := _man({"vanity": 1.6, "mettle": 0.9, "pity": 0.9})
	var plain := _man({"vanity": 0.1, "mettle": 0.9, "pity": 0.9})
	assert_true(
		vain.weight_for(ToneConsiderations.of(Tone.PLEASED))
			> plain.weight_for(ToneConsiderations.of(Tone.PLEASED)),
		"vanity does not decide how flattery lands")
	assert_almost_eq(
		vain.weight_for(ToneConsiderations.of(Tone.DESPERATE)),
		plain.weight_for(ToneConsiderations.of(Tone.DESPERATE)), 0.0001,
		"vanity reached a tone it has no business with")


# --- 🔒 Two men, one letter, different answers ------------------------------

func test_two_men_alike_but_for_one_trait_answer_differently() -> void:
	# **The acceptance, and the whole point of the ticket.** Same loyalty, same
	# letter, same request — and the only difference between them is one number.
	var proud := _man({"vanity": 0.3, "mettle": 1.6, "pity": 0.3}, 40.0)
	var placid := _man({"vanity": 0.3, "mettle": -0.5, "pity": 0.3}, 40.0)
	var letter := _letter(Tone.HATEFUL)

	assert_true(_answer(proud, letter) != _answer(placid, letter),
		"a proud man and a placid one answered the same hateful letter the same way")


func test_a_hateful_letter_costs_a_proud_man_more_than_a_placid_one() -> void:
	var proud := _man({"vanity": 0.3, "mettle": 1.6, "pity": 0.3}, 40.0)
	var placid := _man({"vanity": 0.3, "mettle": 0.1, "pity": 0.3}, 40.0)
	var letter := _letter(Tone.HATEFUL)

	assert_true(
		float(_totals(proud, letter)[String(Compliance.REFUSE)])
			> float(_totals(placid, letter)[String(Compliance.REFUSE)]),
		"contempt drove the placid man to refusal as hard as the proud one")


func test_flattery_works_on_a_vain_man_and_bounces_off_a_plain_one() -> void:
	var vain := _man({"vanity": 1.6, "mettle": 0.5, "pity": 0.5})
	var plain := _man({"vanity": 0.1, "mettle": 0.5, "pity": 0.5})
	var letter := _letter(Tone.PLEASED)

	assert_true(
		float(_totals(vain, letter)[String(Compliance.COMPLY)])
			> float(_totals(plain, letter)[String(Compliance.COMPLY)]),
		"flattery moved the two of them alike")


func test_a_desperate_letter_reaches_a_decent_man() -> void:
	var decent := _man({"vanity": 0.5, "mettle": 0.5, "pity": 1.6}, 40.0)
	var cold := _man({"vanity": 0.5, "mettle": 0.5, "pity": 0.0}, 40.0)
	var letter := _letter(Tone.DESPERATE)

	assert_true(
		float(_totals(decent, letter)[String(Compliance.COMPLY)])
			> float(_totals(cold, letter)[String(Compliance.COMPLY)]),
		"need reached a man who has none of it as readily as a decent one")


# --- 🔒 The bully is two numbers below zero ---------------------------------

func test_a_negative_trait_inverts_that_tone_for_him() -> void:
	# 🔒 He takes courtesy for weakness and responds to force, and he falls out
	# of the same machinery rather than needing a case of his own.
	var bully := _man({"vanity": -0.6, "mettle": -0.5, "pity": 0.2}, 50.0)
	var ordinary := _man({"vanity": 0.9, "mettle": 0.9, "pity": 0.2}, 50.0)

	var courteous := _letter(Tone.PLEASED)
	assert_true(
		float(_totals(bully, courteous)[String(Compliance.COMPLY)])
			< float(_totals(ordinary, courteous)[String(Compliance.COMPLY)]),
		"a courteous letter moved the bully the way it moves an ordinary man")

	var forceful := _letter(Tone.HATEFUL)
	assert_true(
		float(_totals(bully, forceful)[String(Compliance.REFUSE)])
			< float(_totals(ordinary, forceful)[String(Compliance.REFUSE)]),
		"being shouted at drove the bully toward refusal, as it does an ordinary man")


func test_the_bully_actually_occurs_among_generated_men() -> void:
	# 🔒 "He is two numbers below zero" is only true if a drawn man can *be* two
	# numbers below zero. A floor at the ordinary weight minimum would leave the
	# archetype describable in a fixture and unreachable in a run, which is the
	# same as not having it.
	assert_true(Temperament.TRAIT_MIN < 0.0,
		"no man drawn in this game can read courtesy as weakness")

	var inverted := 0
	for index in 200:
		var man := Contact.generate(
			StringName("gov_%d" % index), Contact.ROLE_GOVERNOR,
			RngStreams.new(SEED + index), PackedStringArray(["loyalty", "harshness"]))
		if float(man.traits[String(Temperament.VANITY)]) < 0.0:
			inverted += 1
	assert_true(inverted > 0,
		"two hundred governors and not one of them took courtesy for weakness")


func test_nothing_had_to_be_written_for_him() -> void:
	# 🔒 **No branch anywhere tests which contact is reading.** The lint keeps
	# bespoke behaviour out of `sim/`; this keeps it out of the kernel's inputs,
	# which is where it would actually be tempting to put.
	var source := FileAccess.get_file_as_string(
		"res://correspondence/compliance/tone_considerations.gd")
	assert_not_empty(source, "the tone considerations could not be read")
	for name in ["bully", "proud man", "timid", "contact.id", "actor.id"]:
		assert_false(source.to_lower().contains(name.to_lower()),
			"the tone considerations name '%s' instead of scoring a table" % name)


# --- The save ----------------------------------------------------------------

func test_a_temperament_survives_a_save() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var before := run.contact(&"marshal")

	var after := RunState.from_dict(run.to_dict()).contact(&"marshal")
	for trait_id in Temperament.ALL:
		assert_almost_eq(
			float(after.traits[String(trait_id)]),
			float(before.traits[String(trait_id)]), 0.0001,
			"a reload gave the Marshal a different %s" % trait_id)
	assert_almost_eq(after.weight_for(&"harshness"), before.weight_for(&"harshness"),
		0.0001, "a reload changed how he takes being leaned on")


func test_the_named_men_were_written_rather_than_rolled() -> void:
	# A named character's temperament is authored; only the anonymous ones are
	# drawn. A roster where everybody sat at the middle would be one where the
	# authoring never happened.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var distinct: Dictionary = {}
	for id in ["steward", "chancellor", "marshal", "provost", "diplomat"]:
		var contact := run.contact(StringName(id))
		if contact == null:
			continue
		distinct["%.2f" % float(contact.traits[String(Temperament.METTLE)])] = true
	assert_true(distinct.size() > 1,
		"every officer of the Crown takes being leaned on identically")
