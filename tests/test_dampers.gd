extends TestCase

## The two dampers, and why the topic one is counted in writings (#256,
## `docs/mechanics/the-director.md` §6).
##
## | | Damps | Means |
## | :--- | :--- | :--- |
## | **Topic** | that concern alone | *I have said this* |
## | **Contact** | every concern he has | *I shall not pester the Crown* |
##
## 🔒 **Counted in his own writings, not in months.** The topic damper should
## last about as long as it takes him to say everything else he has to say, so
## rotation falls out instead of being enforced — and **nothing tracks which
## topics he has used.**
##
## 🔒 **Per individual contact, never per role.** Ending a policy six churches
## cared about brings six letters, and that is correct.

const SEED: int = 4013

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


func _man(cares: Array, id: String = "him") -> Contact:
	return Contact.from_data({"id": id, "role": "governor", "cares_about": cares})


## Everything he cares about, as badly wrong as it goes.
func _all_wrong(contact: Contact) -> Dictionary:
	var out: Dictionary = {}
	for topic in contact.cares_about:
		out[String(topic)] = 0.0
	return out


## What he writes about, month after month.
func _sequence(contact: Contact, months: int, measures: Dictionary = {}) -> PackedStringArray:
	var book := WritingBook.new()
	var world := measures if not measures.is_empty() else _all_wrong(contact)
	var out: PackedStringArray = PackedStringArray()
	for month in months:
		var felt := Pressure.for_contact(contact, world, EventLog.new(), month, book)
		var loudest := Pressure.loudest(felt, Threshold.for_contact(contact, 0))
		if loudest.is_empty():
			out.append("")
			continue
		out.append(String(loudest["topic"]))
		book.record(contact.id, String(loudest["topic"]), month)
	return out


# --- 🔒 Rotation falls out --------------------------------------------------

func test_a_man_with_five_concerns_works_through_all_five() -> void:
	# 🔒 The acceptance, and the failure the ticket names: a clergyman
	# alternating between the same two complaints for a year while never
	# mentioning his other three.
	var him := _man(["colony_revenue", "crown_war_intensity", "food_security",
		"quality_of_life", "supply_situation"])
	var said := _sequence(him, 10)

	var distinct: Dictionary = {}
	for topic in said:
		if not String(topic).is_empty():
			distinct[String(topic)] = true
	assert_eq(distinct.size(), 5,
		"he raised %d of his five concerns in ten letters: %s" % [distinct.size(), said])


func test_he_comes_round_again_rather_than_stopping() -> void:
	var him := _man(["colony_revenue", "food_security", "supply_situation"])
	var said := _sequence(him, 9)
	assert_eq(String(said[0]), String(said[3]),
		"he did not come back round to his first concern: %s" % said)
	assert_eq(String(said[1]), String(said[4]),
		"his rotation is not a rotation: %s" % said)


func test_two_genuinely_equal_concerns_do_alternate() -> void:
	# 🔒 **And that is not a fault** (§6). The man really does have two problems,
	# and the gap regenerates from the world every month — so alternating is what
	# a famine and a plague actually look like.
	var him := _man(["food_security", "supply_situation"])
	var said := _sequence(him, 6)
	assert_ne(String(said[0]), String(said[1]),
		"he raised the same concern twice running: %s" % said)
	assert_eq(String(said[0]), String(said[2]),
		"two equally urgent concerns did not alternate: %s" % said)


func test_a_single_minded_man_holds_his_tongue_between_letters() -> void:
	# The floor. Without it a man with one concern is undamped the moment he has
	# written and says the same thing for ever.
	#
	# **At a middling grievance**, because a catastrophe is reported every month
	# and that is right: a governor whose people are starving writes about the
	# starvation, and no damper should talk him out of it. My first version of
	# this put his one concern at its worst and then complained that he kept
	# mentioning it.
	var him := _man(["food_security"])
	var said := _sequence(him, 8, {"food_security": 1.8})
	var silent := 0
	for topic in said:
		if String(topic).is_empty():
			silent += 1
	assert_true(silent > 0,
		"a man with one middling grievance wrote about it every month: %s" % said)
	assert_true(silent < said.size(),
		"he never wrote about it at all: %s" % said)


func test_a_catastrophe_is_reported_every_month() -> void:
	# The other half, and the reason the damper is a subtraction rather than a
	# silence: the gap regenerates from the world, so a famine keeps re-raising
	# its own pressure over anything having been said about it.
	var him := _man(["food_security"])
	var said := _sequence(him, 5)
	for topic in said:
		assert_false(String(topic).is_empty(),
			"a starving colony's governor went quiet about the starving: %s" % said)


# --- 🔒 Nothing tracks which topics he has used -----------------------------

func test_the_book_records_when_he_spoke_and_not_what_is_left() -> void:
	# 🔒 §6. Rotation *falls out* — a book that held a list of unused topics
	# would be enforcing it, and would be a second place his character lived.
	var book := WritingBook.new()
	book.record(&"him", "food_security", 3)
	var saved := book.to_dict()

	for forbidden in ["unused", "remaining", "pending", "queue", "rotation"]:
		assert_false(str(saved).contains(forbidden),
			"the book keeps a '%s', which would be enforcing the rotation" % forbidden)

	var source := FileAccess.get_file_as_string(
		"res://correspondence/director/writing_book.gd")
	assert_not_empty(source, "the book could not be read")
	for forbidden in ["func unused", "func remaining", "func next_topic"]:
		assert_false(source.contains(forbidden),
			"the book answers '%s', which is a plan rather than a record" % forbidden)


# --- 🔒 Set together, decaying independently --------------------------------

func test_writing_sets_both() -> void:
	var him := _man(["food_security", "supply_situation"])
	var book := WritingBook.new()
	var before := Pressure.damper_on(him, "food_security", 5, book)
	book.record(him.id, "food_security", 5)

	assert_almost_eq(before, 0.0, 0.0001, "a man who has never written was damped")
	assert_true(Pressure.topic_damper(him, "food_security", book) > 0.0,
		"having said a thing did not damp it")
	assert_true(Pressure.contact_damper(him, 5, book) > 0.0,
		"having written at all did not damp him")


func test_the_contact_damper_reaches_a_concern_he_has_not_raised() -> void:
	# **This is why a man writes one letter and not five.** He picks his loudest,
	# writes it, and the rest go below the line for a while.
	var him := _man(["food_security", "supply_situation"])
	var book := WritingBook.new()
	book.record(him.id, "food_security", 5)

	assert_almost_eq(Pressure.topic_damper(him, "supply_situation", book), 0.0, 0.0001,
		"writing about the harvest damped the supplies as a topic")
	assert_true(Pressure.damper_on(him, "supply_situation", 5, book) > 0.0,
		"a man who has just written is as ready to write again as one who has not")


func test_they_decay_on_different_clocks() -> void:
	# 🔒 One is counted in months and the other in his letters, which is the whole
	# reason there are two of them.
	var him := _man(["food_security", "supply_situation"])
	var book := WritingBook.new()
	book.record(him.id, "food_security", 5)

	# Months pass and he writes nothing. The contact damper goes; the topic one
	# does not, because he has not worked through the rest of what he had to say.
	var months_later := 5 + Pressure.CONTACT_MONTHS + 2
	assert_almost_eq(Pressure.contact_damper(him, months_later, book), 0.0, 0.0001,
		"a man who has written nothing for half a year is still holding his tongue")
	assert_true(Pressure.topic_damper(him, "food_security", book) > 0.0,
		"time alone made him keen to repeat himself")

	# And now he writes about something else, twice. The topic damper goes.
	book.record(him.id, "supply_situation", months_later)
	book.record(him.id, "supply_situation", months_later + 1)
	assert_almost_eq(Pressure.topic_damper(him, "food_security", book), 0.0, 0.0001,
		"he said everything else he had to say and still could not raise the first")


func test_a_mans_damper_is_his_own() -> void:
	# 🔒 Per individual contact, never per role. Ending a policy six churches
	# cared about brings six letters, and that is correct.
	var first := _man(["food_security"], "first")
	var second := _man(["food_security"], "second")
	var book := WritingBook.new()
	book.record(first.id, "food_security", 5)

	assert_true(Pressure.damper_on(first, "food_security", 5, book) > 0.0,
		"the man who wrote was not damped")
	assert_almost_eq(Pressure.damper_on(second, "food_security", 5, book), 0.0, 0.0001,
		"one church writing quieted the church next door")


# --- 🔒 A must-send bypasses both -------------------------------------------

func test_a_must_send_is_not_recorded_as_having_had_his_say() -> void:
	# §2 and §6. A governor reporting that the natives have attacked has not
	# thereby said what he meant to say, and next month he can still raise it.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# Counted across a run rather than one month, because whether a must-send
	# happens to be true in month zero is the fixture's luck. What is asserted is
	# the rule: **a man's writings are his skippable letters and nothing else.**
	var skippable_sent: Dictionary = {}
	var must_sends := 0
	for _month in 18:
		# **Through `begin_turn`, and read off the inbox.** Calling the director
		# directly composes a second post the player never sees — and records a
		# second set of writings for it, which had this test comparing thirty
		# writings against seventeen letters.
		machine.begin_turn()
		for inbound in run.inbox:
			var id := String(inbound.sender)
			if bool(content.record("letters", inbound.letter_id).get("skippable", true)):
				skippable_sent[id] = int(skippable_sent.get(id, 0)) + 1
			else:
				must_sends += 1
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	assert_true(must_sends > 0,
		"no must-send arrived in eighteen months, so the bypass proves nothing")
	for id in run.contact_ids():
		assert_eq(run.writings.writings_by(StringName(id)),
			int(skippable_sent.get(String(id), 0)),
			"%s's writings do not match the letters he chose to send" % id)


# --- The save ----------------------------------------------------------------

func test_what_he_has_said_survives_a_save() -> void:
	var run := RunState.new_run(SEED)
	run.writings.record(&"chancellor", "colony_revenue", 7)
	run.writings.record(&"chancellor", "supply_situation", 9)

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.writings.writings_by(&"chancellor"), 2,
		"a reload forgot how much he had written")
	assert_eq(restored.writings.months_since(&"chancellor", 12),
		run.writings.months_since(&"chancellor", 12),
		"a reload forgot when he last wrote")
	assert_eq(restored.writings.writings_since(&"chancellor", "colony_revenue"),
		run.writings.writings_since(&"chancellor", "colony_revenue"),
		"a reload gave him back a topic he had already raised")


func test_a_man_who_never_wrote_is_not_damped() -> void:
	var book := WritingBook.new()
	assert_eq(book.writings_by(&"nobody"), 0)
	assert_eq(book.months_since(&"nobody", 40), -1)
	assert_eq(book.writings_since(&"nobody", "food_security"), -1)
	assert_almost_eq(
		Pressure.damper_on(_man(["food_security"]), "food_security", 40, book),
		0.0, 0.0001, "a man who has never written was holding his tongue")
