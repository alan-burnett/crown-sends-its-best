extends TestCase

## Harsh: the wizard step, the clause, and its one sentence (#263,
## `docs/mechanics/tone.md` §9, `docs/mechanics/contacts.md` §3).
##
## 🔒 **A second axis, not a sixth tone.** A yes-or-no the wizard asks after the
## tone is set, and the two are orthogonal: five tones times harsh-or-not is
## **ten registers.**
##
## 🔒 **Harsh and urgency are on opposite sides of the desk.** They sound alike
## and have nothing to do with each other — harsh is set by the **player** and
## travels **outbound**; urgency is set by the **trigger author** and is
## **inbound only**. A dev who wires either across the desk has joined two
## unrelated systems.

const SEED: int = 8812

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


func _wizard(letter_id: String) -> ReplyWizard:
	var letter := Letter.from_record(content.record("letters", letter_id))
	var outgoing := OutgoingLetter.new(letter_id, StringName(letter.sender))
	outgoing.id = StringName("out_%s" % letter_id)
	return ReplyWizard.new(letter, outgoing)


## The first letter whose options order something other than an answer.
func _a_directing_letter() -> String:
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", String(id)))
		if not letter.has_reply() or letter.steps().is_empty():
			continue
		if LetterKind.may_be_harsh(letter):
			return String(id)
	return ""


## And the first whose options only ever answer.
func _an_answering_letter() -> String:
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", String(id)))
		if not letter.has_reply() or letter.steps().is_empty():
			continue
		var orders := false
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				if not option.get(LetterSchema.KEY_EFFECT, {}).is_empty():
					orders = true
		if orders and not LetterKind.may_be_harsh(letter):
			return String(id)
	return ""


func _order(kind: StringName, tone: StringName, harsh: bool) -> Order:
	var order := Order.new(kind, &"marshal", {"amount": 100}, 0)
	order.id = &"order_harsh"
	order.tone = tone
	order.harsh = harsh
	return order


# --- 🔒 The wizard asks, and never when answering ---------------------------

func test_the_wizard_asks_on_a_letter_that_orders_something() -> void:
	var id := _a_directing_letter()
	assert_false(id.is_empty(), "the corpus has no letter that orders anything")

	var wizard := _wizard(id)
	assert_true(wizard.has_harsh_step(), "%s cannot be written harshly" % id)
	assert_false(wizard.harsh_prompt().is_empty(), "the question has no wording")
	assert_eq(wizard.harsh_options().size(), 2, "it is a yes-or-no")
	for option in wizard.harsh_options():
		assert_false(String(option["label"]).is_empty(),
			"an answer to the harsh question has no wording")


func test_it_is_never_asked_when_answering() -> void:
	# 🔒 §9: there is nothing to lean on. *You* are the one deciding, and *do it
	# or else* has no object.
	var id := _an_answering_letter()
	assert_false(id.is_empty(), "the corpus has no letter that only ever answers")

	var wizard := _wizard(id)
	assert_false(wizard.has_harsh_step(),
		"%s offered to lean on a man about a decision the PC had already made" % id)
	assert_true(wizard.harsh_prompt().is_empty())
	assert_true(wizard.harsh_options().is_empty())
	assert_false(wizard.choose_harsh(true),
		"an answering letter accepted a threat")
	assert_false(wizard.outgoing.harsh)


func test_a_letter_is_not_finished_until_he_has_said() -> void:
	# *Not yet asked* and *asked and declined* are different states. A wizard that
	# treated silence as no would never put the question at all.
	var id := _a_directing_letter()
	var wizard := _wizard(id)
	if wizard.has_tone_step():
		wizard.choose_tone(wizard.tone_options()[0]["tone"])
	for step in wizard.steps():
		wizard.choose(String(step["id"]),
			String(step[LetterSchema.KEY_OPTIONS][0].get("id", "")))

	assert_true(wizard.harsh_is_pending(),
		"the wizard never meant to put the harsh question at all")
	assert_false(wizard.is_complete(), "the letter was finished without asking")

	assert_true(wizard.choose_harsh(false))
	assert_false(wizard.harsh_is_pending())
	assert_true(wizard.is_complete(), "answering the question did not finish the letter")


# --- 🔒 One sentence, and nothing else --------------------------------------

func test_saying_no_adds_nothing_at_all() -> void:
	var id := _a_directing_letter()
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)

	var gentle := _wizard(id)
	var letter := gentle.letter
	var context := LetterContext.new(run.world, run.contact(StringName(letter.sender)))
	if gentle.has_tone_step():
		gentle.choose_tone(gentle.tone_options()[0]["tone"])
	for step in gentle.steps():
		gentle.choose(String(step["id"]),
			String(step[LetterSchema.KEY_OPTIONS][0].get("id", "")))
	gentle.choose_harsh(false)
	var mild := gentle.assemble(context)

	gentle.choose_harsh(true)
	var leaned := gentle.assemble(context)

	assert_true(leaned.length() > mild.length(),
		"leaning on him added nothing to the letter")
	assert_true(leaned.contains(HarshClause.sentence(gentle.outgoing.tone)),
		"the harsh letter does not contain the sentence it is supposed to add")
	assert_false(mild.contains(HarshClause.sentence(gentle.outgoing.tone)),
		"a letter he declined to lean on carried the threat anyway")


func test_the_sentence_is_keyed_by_tone_which_is_what_makes_ten_registers() -> void:
	# 🔒 The same flag reads as velvet from a pleased PC and as a threat from an
	# annoyed one. Five identical sentences would make harsh a sixth tone.
	var said: Dictionary = {}
	for tone in Tone.ALL:
		var sentence := HarshClause.sentence(tone)
		assert_false(sentence.is_empty(), "no harsh sentence for a %s letter" % tone)
		said[sentence] = true
	assert_eq(said.size(), Tone.ALL.size(),
		"two tones lean on a man in the same words, so harsh is a sixth tone")


func test_a_letter_with_no_tone_still_leans_in_the_plain_register() -> void:
	# The default is not an error case: a letter with no tone step is still a
	# letter that can lean on a man.
	assert_eq(HarshClause.sentence(&""), HarshClause.sentence(Tone.DUTIFUL),
		"a letter with no manner in it leaned in some manner of its own")


# --- 🔒 What it buys and what it costs --------------------------------------

func test_it_pulls_toward_comply_and_toward_partial() -> void:
	# 🔒 §9. Partial used to sit below zero on the reasoning that it is a sideways
	# answer like the rest — a man leaned on does **at least some of it** rather
	# than none, and half a levy raised under a threat is the commonest thing a
	# threat actually gets you.
	var pull: Dictionary = ComplianceConsiderations.HarshnessConsideration.PULL
	assert_true(float(pull[Compliance.COMPLY]) > 0.0, "a threat does not ask for the thing")
	assert_true(float(pull[Compliance.PARTIAL]) > 0.0,
		"leaning on a man pushed him away from doing part of it")
	for sideways in [Compliance.DELAY, Compliance.REINTERPRET,
			Compliance.REFUSE, Compliance.ACT_ALONE]:
		assert_true(float(pull[sideways]) < 0.0,
			"a threat invited him to answer %s" % sideways)


func test_leaning_on_him_makes_the_half_measure_larger() -> void:
	# 🔒 §9, on asking letters. And it multiplies the tone's share rather than
	# replacing it, so the two axes stay two.
	for tone in Tone.ALL:
		var mild := Compliance.partial_share(
			_order(M1Registrations.ORDER_REQUEST_TROOPS, tone, false))
		var leaned := Compliance.partial_share(
			_order(M1Registrations.ORDER_REQUEST_TROOPS, tone, true))
		assert_true(leaned > mild,
			"a threat bought no more of a %s letter than asking nicely" % tone)
		assert_true(leaned <= Compliance.HARSHEST_PARTIAL,
			"a partial under threat became the whole of it, at %s" % tone)

	# The tone still decides how generous he is underneath the threat.
	assert_true(
		Compliance.partial_share(
			_order(M1Registrations.ORDER_REQUEST_TROOPS, Tone.PLEASED, true))
			> Compliance.partial_share(
				_order(M1Registrations.ORDER_REQUEST_TROOPS, Tone.HATEFUL, true)),
		"under a threat the manner stopped mattering, so the axes collapsed to one")


func test_a_directing_letter_has_no_half_measure_to_enlarge() -> void:
	for harsh in [true, false]:
		assert_eq(
			Compliance.partial_share(
				_order(M1Registrations.ORDER_URGE_INTENT, Tone.ANNOYED, harsh)),
			Compliance.PARTIAL_SHARE,
			"a threat moved the magnitude of a letter that has none")


func test_it_always_costs_loyalty() -> void:
	# 🔒 Whatever the outcome: the deed is the PC's and not his. Being written to
	# that way is what stings, not whether he then did it.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var moved: Dictionary = {}
	for harsh in [false, true]:
		var contact := run.contact(&"marshal")
		contact.relationship = Relationship.new(&"marshal", 60.0)
		Compliance.resolve(
			_order(M1Registrations.ORDER_URGE_INTENT, Tone.DUTIFUL, harsh),
			contact, run.intents, run.world, run.log, run.streams)
		moved[harsh] = contact.loyalty()
	assert_true(float(moved[true]) < float(moved[false]),
		"being commanded cost him nothing: %s" % moved)


# --- 🔒 The grievance lands only where the town bore it ---------------------

func test_the_town_holds_it_against_the_crown_only_if_it_bore_the_order() -> void:
	# 🔒 A refusal is news the moment it is written; a harsh order is only a
	# grievance once it lands. A governor who refuses to strip his own stores has
	# spared his people, and they have nothing to hold against the Crown — his
	# loyalty pays for that instead, which is the trade the compliance model
	# exists to make.
	var driver := GrievanceDriver.new()
	var borne: Dictionary = {}
	for outcome in Compliance.OUTCOMES:
		borne[String(outcome)] = driver.callv(
			"_was_borne", [Compliance.OUTCOME_EVENTS[outcome]])

	assert_true(bool(borne[String(Compliance.COMPLY)]), "doing it is not bearing it")
	assert_true(bool(borne[String(Compliance.PARTIAL)]), "doing part of it is not bearing it")
	for spared in [Compliance.DELAY, Compliance.REINTERPRET, Compliance.REFUSE]:
		assert_false(bool(borne[String(spared)]),
			"a town that never carried the order resented it anyway: %s" % spared)


# --- 🔒 Opposite sides of the desk ------------------------------------------

func test_a_contact_never_sets_harshness_and_the_pc_never_sets_urgency() -> void:
	# 🔒 They sound alike and have nothing to do with each other. A dev who wires
	# either across the desk has joined two unrelated systems.
	for id in content.ids("letters"):
		var record := content.record("letters", String(id))
		assert_false(record.has("urgency"),
			"%s declares urgency, which belongs to the trigger" % id)

	# And nothing a trigger carries reaches an Order.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	for inbound in machine.director.compose_inbox(run):
		assert_false(inbound.params.has("harsh"),
			"%s arrived carrying harshness, which only the PC sets" % inbound.letter_id)


func test_an_npc_intent_can_never_carry_a_threat() -> void:
	# 🔒 #71: harsh is set in the loop over the PC's outgoing post and nowhere
	# else, so Seam C's will-to-Intent path cannot produce one however the content
	# is authored.
	var order := Order.new(M1Registrations.ORDER_URGE_INTENT, &"marshal", {}, 0)
	assert_false(order.harsh,
		"an Order is born leaning on the man it is addressed to")
	assert_false(Order.from_dict(
		{"kind": "urge_intent", "addressed_to": "marshal"}).harsh,
		"an Order restored from nothing carries a threat")
