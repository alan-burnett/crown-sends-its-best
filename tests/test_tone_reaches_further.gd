extends TestCase

## Tone reaches the director and the score (#264, `docs/mechanics/tone.md` §4,
## §6; `docs/mechanics/prestige.md` §4).
##
## 🔒 **Pleased increasing his desire to write is a cost, not a benefit.** More
## letters from him is more of a capped desk spent on him — being kind gives you
## a chattier morning's post.
##
## 🔒 **And hateful's major decrease is the other kind of cost.** A man written to
## contemptuously stops consulting the PC, and a man who has stopped consulting
## him does what *he* wants instead. **That is Seam C, arrived at by insult.**
##
## 🔒 **The Crown does not care whether the PC flatters or abuses his subjects.
## It minds very much that he looked weak in front of them.** Cruelty is free and
## desperation is not.

const SEED: int = 9204

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


## A man who has been written to this way a dozen times.
func _written_to(tone: StringName, times: int = 12) -> Contact:
	var contact := Contact.new(&"him", {"loyalty": 1.0})
	contact.role = Contact.ROLE_GOVERNOR
	contact.relationship = Relationship.new(&"him", 55.0)
	for round in times:
		contact.relationship.record_tone(tone)
	return contact


# --- 🔒 Desire to write again -----------------------------------------------

func test_the_two_that_move_it_and_the_three_that_do_not() -> void:
	assert_eq(float(Relationship.EAGERNESS_WEIGHT[Tone.DUTIFUL]), 0.0,
		"the plain register bought a keener correspondent")
	assert_eq(float(Relationship.EAGERNESS_WEIGHT[Tone.DESPERATE]), 0.0,
		"pleading changed how apt he was to write, which is not what it costs")
	assert_true(float(Relationship.EAGERNESS_WEIGHT[Tone.PLEASED]) > 0.0,
		"kindness did not make him keener to write")
	assert_true(float(Relationship.EAGERNESS_WEIGHT[Tone.ANNOYED]) < 0.0,
		"being grumbled at did not put him off writing")
	assert_true(
		float(Relationship.EAGERNESS_WEIGHT[Tone.HATEFUL])
			< float(Relationship.EAGERNESS_WEIGHT[Tone.ANNOYED]),
		"contempt put him off no more than peevishness, so there is no major decrease")


func test_a_kind_pc_pays_for_it_in_desk() -> void:
	# 🔒 It is a cost. SPEC §9.6's budget is a ceiling, so a chattier man is more
	# of a fixed desk spent on him.
	var kind := _written_to(Tone.PLEASED)
	var plain := _written_to(Tone.DUTIFUL)
	assert_true(Threshold.for_contact(kind, 0) < Threshold.for_contact(plain, 0),
		"a man written to kindly for a year was no readier to write back")


func test_a_cruel_pc_pays_for_it_by_not_being_consulted() -> void:
	# 🔒 The other kind of cost, and it compounds with #259: a man who has stopped
	# writing is a man who settles things himself. Seam C, arrived at by insult.
	var hated := _written_to(Tone.HATEFUL)
	var plain := _written_to(Tone.DUTIFUL)
	assert_true(Threshold.for_contact(hated, 0) > Threshold.for_contact(plain, 0),
		"a man abused for a year wrote as freely as one treated plainly")
	assert_true(
		Threshold.for_contact(hated, 0) > Threshold.for_contact(_written_to(Tone.ANNOYED), 0),
		"contempt cost no more than peevishness")


func test_it_never_silences_him_and_never_floods_the_desk() -> void:
	# Never nought and never unbounded: a man he has abused should be very nearly
	# silent without becoming unreachable, because an unreachable contact is an
	# ending rather than a silence.
	for tone in Tone.ALL:
		var contact := _written_to(tone, 200)
		assert_true(contact.relationship.eagerness >= Relationship.LEAST_EAGER,
			"two hundred %s letters put him past the floor" % tone)
		assert_true(contact.relationship.eagerness <= Relationship.MOST_EAGER,
			"two hundred %s letters put him past the ceiling" % tone)
		assert_true(Threshold.for_contact(contact, 0) > 0.0,
			"a man written to %s two hundred times has no bar at all" % tone)


func test_it_is_measurable_over_a_run_and_not_over_one_letter() -> void:
	# One letter should barely tell. A year of them should.
	var once := _written_to(Tone.HATEFUL, 1)
	var plain := _written_to(Tone.DUTIFUL, 1)
	var often := _written_to(Tone.HATEFUL, 12)

	var one_letter := Threshold.for_contact(once, 0) - Threshold.for_contact(plain, 0)
	var a_year := Threshold.for_contact(often, 0) - Threshold.for_contact(plain, 0)
	assert_true(a_year > one_letter * 3.0,
		"a year of contempt told barely more than a single letter (%.2f against %.2f)"
			% [a_year, one_letter])


func test_it_survives_the_save() -> void:
	# Ironman, one save per run (SPEC §16.2). A contact who forgot how he had been
	# treated would quietly recover every time the player closed the game.
	var hated := _written_to(Tone.HATEFUL)
	var restored := Relationship.from_dict(hated.relationship.to_dict())
	assert_almost_eq(restored.eagerness, hated.relationship.eagerness, 0.0001,
		"his desire to write did not survive the save")


func test_a_man_nobody_has_written_to_is_unmoved() -> void:
	var fresh := Relationship.new(&"him", 55.0)
	assert_eq(fresh.eagerness, Relationship.EAGER_AT_FIRST)
	assert_eq(Relationship.from_dict({"contact_id": "him"}).eagerness,
		Relationship.EAGER_AT_FIRST,
		"a relationship restored from a save with no such field started keen or cowed")


# --- 🔒 Desperate costs prestige, permanently -------------------------------

func test_each_desperate_letter_emits_one_optic_and_no_other_tone_emits_any() -> void:
	var emitted: Dictionary = {}
	for tone in Tone.ALL:
		var run := RunState.new_run(SEED)
		ContactRoster.load_into(run, content)
		var machine := TurnMachine.new(run)
		machine.use_content(content)
		machine.saves_on_send = false
		machine.begin_turn()

		var wrote := 0
		for inbound in run.inbox:
			var letter := Letter.from_record(content.record("letters", inbound.letter_id))
			if not letter.has_tone_step():
				continue
			var offers := false
			for option in letter.reply[LetterSchema.KEY_TONE].get(LetterSchema.KEY_OPTIONS, []):
				if StringName(option.get(LetterSchema.KEY_TONE, "")) == tone:
					offers = true
			if not offers:
				continue
			var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
			outgoing.in_reply_to = inbound.id
			outgoing.params = inbound.params.duplicate(true)
			var wizard := ReplyWizard.new(letter, outgoing)
			wizard.choose_tone(tone)
			for step in wizard.steps():
				wizard.choose(String(step["id"]),
					String(step[LetterSchema.KEY_OPTIONS][0].get("id", "")))
			if wizard.harsh_is_pending():
				wizard.choose_harsh(false)
			inbound.status = InboundLetter.ANSWERED
			run.post.add(outgoing)
			wrote += 1

		# Everything he did not answer travels as silence, or the post refuses to
		# go at all and the tally is of an empty desk.
		for inbound in run.inbox:
			if inbound.status != InboundLetter.ANSWERED:
				inbound.status = InboundLetter.SET_ASIDE
		assert_true(machine.send_post(), "the post would not go: %s"
			% machine.can_send()["reason"])
		emitted[String(tone)] = {
			"wrote": wrote,
			"marks": run.log.of_type(OpticsRegister.EVENT_DESPERATE_LETTER).size(),
		}

	var desperate: Dictionary = emitted[String(Tone.DESPERATE)]
	assert_true(int(desperate["wrote"]) > 0,
		"no letter in the corpus offers a desperate reply, so nothing was measured")
	assert_eq(int(desperate["marks"]), int(desperate["wrote"]),
		"the marks did not match the pleas, one for one: %s" % emitted)

	for tone in Tone.ALL:
		if tone == Tone.DESPERATE:
			continue
		assert_eq(int((emitted[String(tone)] as Dictionary)["marks"]), 0,
			"a %s letter cost the Crown its face: %s" % [tone, emitted])


func test_cruelty_is_free_and_desperation_is_not() -> void:
	# 🔒 The sharpest expression of §14.1's lock that prestige measures **only how
	# the Crown benefits.** Hateful carries no prestige cost at all, and should
	# not — it costs loyalty and it costs being consulted, which are the colony's
	# currencies rather than the court's.
	assert_true(OpticsRegister.is_an_optic(OpticsRegister.EVENT_DESPERATE_LETTER),
		"looking weak in front of the colony is not something the court hears about")
	assert_true(OpticsRegister.price_of(OpticsRegister.EVENT_DESPERATE_LETTER) > 0.0)

	for tone in Tone.ALL:
		if tone == Tone.DESPERATE:
			continue
		assert_false(OpticsRegister.is_an_optic(StringName("%s_letter" % tone)),
			"writing %s is an optic, so cruelty is not free" % tone)


func test_one_plea_is_small_and_a_run_of_them_tells() -> void:
	# 🔒 The figure the ticket says decides whether desperate is a tool or the
	# answer to everything. Small enough to be worth paying once; large enough
	# that a run of them tells at retirement.
	var one := OpticsRegister.price_of(OpticsRegister.EVENT_DESPERATE_LETTER)
	assert_true(one < OpticsRegister.price_of(TradeProtest.EVENT_DECLARED),
		"one plea embarrassed the Crown more than a resource it stopped selling")
	assert_true(one * 40.0 > OpticsRegister.price_of(Rebellion.EVENT_DECLARED),
		"forty pleas still weighed less than one rebellion, so a run of them tells nothing")


func test_the_mark_never_decays() -> void:
	# 🔒 §4: optics never decay. Something that made the Crown look bad in year
	# one counts against the PC in year forty, undiminished — which is what makes
	# the retirement decision real.
	var log := EventLog.new()
	log.emit(OpticsRegister.EVENT_DESPERATE_LETTER, &"marshal", 1, {}, WorldPhase.DISPATCH)
	var after_a_year := OpticsRegister.debt_in(log)

	log.emit(OpticsRegister.EVENT_DESPERATE_LETTER, &"marshal", 480, {}, WorldPhase.DISPATCH)
	assert_almost_eq(OpticsRegister.debt_in(log), after_a_year * 2.0, 0.0001,
		"a plea from forty years ago had faded, so waiting heals something")
	assert_almost_eq(after_a_year,
		OpticsRegister.price_of(OpticsRegister.EVENT_DESPERATE_LETTER), 0.0001)
