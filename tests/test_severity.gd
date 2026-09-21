extends TestCase

## Which letter: severity is not tone (#257, SPEC §9.1;
## `docs/mechanics/the-director.md` §7).
##
## A topic usually has several letters. *Give us a break* and *they cannot bear
## it* are **the same concern said at two different strengths**, and he sends the
## strongest whose bar the pressure clears.
##
## 🔒 **`urgency` is taken.** SPEC §9.1 makes it one of tone's three inputs and
## the director feeds it straight into `tone_for`. It cannot also select severity.
##
## 🔒 **Collapse severity and tone and every serious letter is also an angry
## one** — which costs the game its most useful character note: the people who
## like the PC are the ones who tell him how bad it is.

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	content.free()


## The clergyman's three letters from §7's worked example.
func _ladder() -> Array:
	return [
		{"id": "give_us_a_break", Severity.KEY: 20.0},
		{"id": "this_is_now_a_hardship", Severity.KEY: 50.0},
		{"id": "they_cannot_bear_it", Severity.KEY: 80.0},
	]


# --- 🔒 The strongest within reach ------------------------------------------

func test_he_sends_the_stronger_of_two_he_could_send() -> void:
	# §7's worked example. At 12% with a rise this month his pressure is 50: the
	# third letter is not true, the first two are, and fifty clears both bars.
	var at_hand := [_ladder()[0], _ladder()[1]]
	assert_eq(String(at_hand[Severity.strongest(at_hand, 50.0)]["id"]),
		"this_is_now_a_hardship",
		"he asked politely when he had a stronger letter within reach")


func test_a_letter_above_his_feeling_is_out_of_reach() -> void:
	var said := Severity.strongest(_ladder(), 25.0)
	assert_eq(String(_ladder()[said]["id"]), "give_us_a_break",
		"a mild complaint reached for the letter of a desperate man")
	assert_false(Severity.within_reach(_ladder()[2], 25.0),
		"a man mildly put out could say they cannot bear it")


func test_a_quiet_month_reaches_for_nothing() -> void:
	assert_eq(Severity.strongest(_ladder(), 5.0), -1,
		"a man with nothing much to say found a letter to say it in")


func test_a_letter_that_says_nothing_about_its_strength_is_always_at_hand() -> void:
	# **The field is an addition, not a migration.** Every letter authored before
	# it existed is the routine register, which is what it always was.
	assert_almost_eq(Severity.of({"id": "routine"}), Severity.MILDEST, 0.0001)
	assert_true(Severity.within_reach({"id": "routine"}, 0.0),
		"a letter nobody gave a strength cannot be sent at all")


func test_a_tie_is_broken_by_the_letter_and_not_by_the_order() -> void:
	var both := [
		{"id": "zzz", Severity.KEY: 40.0},
		{"id": "aaa", Severity.KEY: 40.0},
	]
	var reversed := [both[1], both[0]]
	assert_eq(String(both[Severity.strongest(both, 60.0)]["id"]),
		String(reversed[Severity.strongest(reversed, 60.0)]["id"]),
		"two equally strong letters were chosen between by the file order")


# --- 🔒 `urgency` is untouched ----------------------------------------------

func test_no_letter_declares_an_urgency() -> void:
	# 🔒 The acceptance. Urgency belongs to the trigger and feeds tone; a letter
	# carrying one would be trying to decide how it reads *and* whether it is
	# reached for.
	for id in content.ids("letters"):
		assert_false(content.record("letters", String(id)).has("urgency"),
			"%s declares an urgency, which is tone's input and not severity's" % id)


func test_every_trigger_still_carries_its_urgency() -> void:
	var with_urgency := 0
	for id in content.ids("triggers"):
		if content.record("triggers", String(id)).has("urgency"):
			with_urgency += 1
	assert_true(with_urgency > 0,
		"no trigger carries an urgency any more, so tone has lost an input")


func test_the_two_are_read_from_different_places() -> void:
	# Severity from the letter, urgency from the trigger. A reader who found
	# both on one object would reasonably assume they were the same axis.
	var letters_with_severity := 0
	for id in content.ids("letters"):
		if content.record("letters", String(id)).has(Severity.KEY):
			letters_with_severity += 1
	assert_true(letters_with_severity > 0, "no letter declares a strength")

	for id in content.ids("triggers"):
		assert_false(content.record("triggers", String(id)).has(Severity.KEY),
			"%s declares a strength, which belongs to the letter it names" % id)


# --- 🔒 Conditions still gate -----------------------------------------------

func test_a_letter_whose_conditions_fail_is_never_sent() -> void:
	# However high the pressure. *They cannot bear it* at 12% is not a letter a
	# desperate man may reach for; it is untrue.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# Nothing whatever is wrong with the returns, so the arrears letter is false.
	run.world.values["colony_revenue"] = 400.0
	run.world.values[WorldValues.REVENUE_BASELINE] = 60.0
	for inbound in machine.director.compose_inbox(run):
		assert_ne(inbound.letter_id, "chancellor.how_to_answer",
			"an untrue letter arrived because the sender felt strongly enough")


# --- 🔒 The two vary independently ------------------------------------------

func test_severity_and_tone_both_move_across_a_run() -> void:
	# 🔒 The acceptance, and the character note it buys: a clergyman at the end
	# of his patience but fond of the PC sends the severe letter in a dutiful
	# register.
	var strengths: Dictionary = {}
	var registers: Dictionary = {}
	var by_letter: Dictionary = {}

	for index in 3:
		var run := RunState.new_run(index * 131 + 7)
		ContactRoster.load_into(run, content)
		var machine := TurnMachine.new(run)
		machine.use_content(content)
		machine.saves_on_send = false
		for _month in 30:
			machine.begin_turn()
			for inbound in run.inbox:
				var record: Dictionary = content.record("letters", inbound.letter_id)
				strengths["%.0f" % Severity.of(record)] = true
				registers[String(inbound.tone)] = true
				by_letter[inbound.letter_id] = by_letter.get(inbound.letter_id, {})
				(by_letter[inbound.letter_id] as Dictionary)[String(inbound.tone)] = true
				inbound.status = InboundLetter.SET_ASIDE
			machine.send_post()

	assert_true(strengths.size() > 2,
		"every letter in three runs spoke to the same pressure")
	assert_true(registers.size() > 1,
		"every letter in three runs arrived in the same register")

	var in_two_voices := 0
	for id in by_letter:
		if (by_letter[id] as Dictionary).size() > 1:
			in_two_voices += 1
	assert_true(in_two_voices > 0,
		"no letter ever arrived in two different registers, so tone is severity")


func test_a_strong_letter_is_reachable_without_being_first_in_the_alphabet() -> void:
	# The thing severity actually fixes. `governor.the_people_next_door` sorts
	# after `report_month`, `report_completed` and `report_shortage` — before
	# this it waited behind all three and arrived twice in forty-eight months.
	var run := RunState.new_run(8821)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = town.at + Vector2i(1, 0)
	village.people = 60

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# Counted rather than merely looked for. "At least once in three years" is
	# satisfied by luck — it arrived twice in forty-eight months under the old
	# rule, which is exactly the problem — so the assertion is on how often.
	var arrived := 0
	var stronger := 0
	for _month in 36:
		machine.begin_turn()
		for inbound in run.inbox:
			if inbound.letter_id == "governor.the_people_next_door":
				arrived += 1
			if inbound.letter_id == "governor.report_shortage":
				stronger += 1
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	assert_true(arrived >= 3,
		"a letter late in the alphabet arrived %d times in three years, which is luck rather than reach"
			% arrived)
	assert_true(stronger > arrived,
		"the strongest letter he had did not outnumber a milder one")


func test_no_letter_ever_speaks_to_more_than_its_sender_feels() -> void:
	# 🔒 The invariant, and the one my other tests could not see. A contented
	# roster never clears its *threshold*, so severity is never consulted at all
	# — removing the reach check broke nothing until this asked the question
	# directly, of every letter that actually arrived.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var overreached: PackedStringArray = PackedStringArray()
	var checked := 0
	for _month in 24:
		# What each man feels this month, worked out the way the director does
		# and *before* the post records anything.
		var felt: Dictionary = {}
		var ranks := Threshold.ranks_in(run.contacts)
		for id in run.contact_ids():
			var contact := run.contact(StringName(id))
			var loudest := Pressure.loudest(
				Pressure.for_contact(contact, ColonyMeasures.for_contact(run, contact),
					run.log, run.world.month, run.writings),
				Threshold.for_contact(contact, int(ranks.get(String(id), 0))))
			felt[String(id)] = 0.0 if loudest.is_empty() else float(loudest["pressure"])

		machine.begin_turn()
		for inbound in run.inbox:
			var record: Dictionary = content.record("letters", inbound.letter_id)
			if bool(record.get("skippable", true)):
				checked += 1
				if Severity.of(record) > float(felt.get(String(inbound.sender), 0.0)) + 0.0001:
					overreached.append(inbound.letter_id)
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	assert_true(checked > 10, "too few letters arrived to tell")
	assert_eq(overreached, PackedStringArray(),
		"letters arrived speaking to more than their senders felt: %s" % overreached)


func test_a_contented_man_does_not_reach_for_a_strong_letter() -> void:
	# 🔒 The director's half of *within reach*. `Severity.strongest` refusing a
	# letter above his feeling proves nothing about the post unless the post
	# asks it — my first version tested the function and left the director free
	# to send whatever it liked.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# Everything the roster cares about, exactly as each man would have it.
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		var measures := ColonyMeasures.for_contact(run, contact)
		var wants: Dictionary = {}
		for topic in contact.cares_about:
			wants[String(topic)] = MeasureRegistry.normalize(
				String(topic), float(measures.get(String(topic), 0.0)))
		contact.wants = wants

	# **The month their wants were set to**, and no further. A month later the
	# world has moved, and news adds pressure whether or not a man is content —
	# which is the point of news and would make a six-month version of this test
	# a test of something else.
	var reached_too_far: PackedStringArray = PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		var record: Dictionary = content.record("letters", inbound.letter_id)
		if bool(record.get("skippable", true)) 				and Severity.of(record) > Severity.MILDEST:
			reached_too_far.append(inbound.letter_id)

	assert_eq(reached_too_far, PackedStringArray(),
		"a roster with everything it wanted still reached for letters of hardship: %s"
			% reached_too_far)


# --- The content itself ------------------------------------------------------

func test_no_must_send_declares_a_strength() -> void:
	# 🔒 A must-send bypasses pressure entirely, so a strength on one is a figure
	# nothing will ever read — and a reader would assume it did something.
	for id in content.ids("letters"):
		var record: Dictionary = content.record("letters", String(id))
		if bool(record.get("skippable", true)):
			continue
		assert_false(record.has(Severity.KEY),
			"%s is unskippable and declares a strength nothing will read" % id)


func test_a_sender_has_letters_at_more_than_one_strength() -> void:
	# A topic said at two strengths is the whole point. A sender whose letters
	# all spoke to the same pressure would have a ladder with one rung.
	var by_sender: Dictionary = {}
	for id in content.ids("letters"):
		var record: Dictionary = content.record("letters", String(id))
		if not bool(record.get("skippable", true)):
			continue
		var sender := String(record.get("sender", ""))
		by_sender[sender] = by_sender.get(sender, {})
		(by_sender[sender] as Dictionary)["%.0f" % Severity.of(record)] = true

	var laddered := 0
	for sender in by_sender:
		if (by_sender[sender] as Dictionary).size() > 1:
			laddered += 1
	assert_true(laddered > 0,
		"no sender in the game has anything to say at two different strengths")
