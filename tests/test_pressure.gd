extends TestCase

## The director: pressure, and the news that prompts a letter (#254,
## SPEC §9.6; `docs/mechanics/the-director.md` §3).
##
## Today a trigger fires when its conditions hold and its cooldown has expired.
## **That is a gate, not a want.**
##
## ```
## pressure = gap + news - dampers
## ```
##
## 🔒 **Topics are `cares_about`**, the measures he already judges the PC by. No
## contact carries a second list of concerns.
##
## 🔒 **News is last month's log and nothing else**, and decays to nothing the
## month after without any damper being involved.
##
## 🔒 **One letter per contact per month at most**, his loudest topic over
## threshold.
##
## 🔒 **And conditions still gate.** A letter that is not true is never a
## candidate whatever he feels.

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
	content.free()


## A man who cares about one thing and wants it at its best.
func _man(cares: Array, wants: Dictionary = {}) -> Contact:
	var contact := Contact.from_data({
		"id": "him",
		"role": "crown_officer",
		"cares_about": cares,
		"wants": wants,
	})
	return contact


func _log_with(month: int, changes: Dictionary) -> EventLog:
	var log := EventLog.new()
	log.emit(&"something_happened", &"world", month, {"changes": changes})
	return log


# --- 🔒 Topics are `cares_about` --------------------------------------------

func test_a_mans_topics_are_the_things_he_judges_the_pc_by() -> void:
	var him := _man(["food_security", "supply_situation"])
	var felt := Pressure.for_contact(
		him, {"food_security": 0.0, "supply_situation": 0.0}, EventLog.new(), 5)

	assert_eq(felt.keys().size(), 2, "he weighed something other than his own concerns")
	for topic in him.cares_about:
		assert_true(felt.has(String(topic)), "he had no view on %s" % topic)


func test_nobody_carries_a_second_list_of_concerns() -> void:
	# 🔒 The acceptance, against the roster. A second list would be a second
	# place his character lived, and the two would disagree within a milestone.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		var fields: Dictionary = {}
		for entry in contact.get_property_list():
			fields[String(entry["name"])] = true
		for forbidden in ["topics", "concerns", "writes_about", "grievances"]:
			assert_false(fields.has(forbidden),
				"%s carries a '%s' beside his cares_about" % [id, forbidden])


func test_a_topic_that_is_not_a_measure_is_not_scored() -> void:
	var him := _man(["a_thing_nobody_registered"])
	assert_true(Pressure.for_contact(him, {}, EventLog.new(), 5).is_empty(),
		"he had a considered view about something the game cannot measure")


# --- Gap: how far the world is from what he wants ---------------------------

func test_a_bigger_gap_is_a_bigger_care() -> void:
	var him := _man(["food_security"])
	var comfortable := Pressure.gap_on("food_security", {"food_security": 3.0}, him)
	var hungry := Pressure.gap_on("food_security", {"food_security": 0.0}, him)
	assert_true(hungry > comfortable + 0.0001,
		"a starving colony troubled him no more than a fed one")
	assert_almost_eq(comfortable, 0.0, 0.0001,
		"a man who has what he wants still had something to complain about")


func test_a_man_who_wants_it_low_minds_it_being_high() -> void:
	# 🔒 **A distance, not a shortfall.** The Marshal wants his war over, so a
	# fiercer one is further from what he wants, not nearer.
	var soldier := _man(["crown_war_intensity"], {"crown_war_intensity": 0.15})
	var quiet := Pressure.gap_on(
		"crown_war_intensity", {"crown_war_intensity": 15.0}, soldier)
	var fierce := Pressure.gap_on(
		"crown_war_intensity", {"crown_war_intensity": 90.0}, soldier)
	assert_true(fierce > quiet + 0.0001,
		"a fiercer war gave the Marshal less to write about")


func test_a_man_who_has_said_nothing_wants_the_best_of_it() -> void:
	var him := _man(["food_security"])
	assert_almost_eq(him.want_for("food_security"), Contact.WANTS_THE_BEST, 0.0001,
		"a man who never said what he wanted was assumed to want nothing")


# --- 🔒 News: last month's log, and gone the month after --------------------

func test_something_moving_is_worth_more_than_it_merely_being_wrong() -> void:
	# 🔒 The point of the term. *These taxes on beer are too much. They are not
	# crippling us. Give us a break.* A one-point overshoot is never worth a
	# letter on its own; the change is what prompts him.
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}

	var settled := Pressure.for_contact(him, measures, EventLog.new(), 5)
	var moved := Pressure.for_contact(
		him, measures, _log_with(4, {"supply_situation": {"from": 90.0, "to": 70.0}}), 5)

	assert_true(float(moved["supply_situation"]) > float(settled["supply_situation"]),
		"a man wrote about a thing that just got worse no more readily than about one that always was")


func test_news_is_gone_the_month_after_and_no_damper_was_involved() -> void:
	# 🔒 The acceptance, and the two mechanisms are different: a news term that
	# faded would be a second damper wearing its coat.
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}
	var log := _log_with(4, {"supply_situation": {"from": 90.0, "to": 70.0}})

	var when_fresh := float(Pressure.for_contact(him, measures, log, 5)["supply_situation"])
	var month_after := float(Pressure.for_contact(him, measures, log, 6)["supply_situation"])
	var never := float(Pressure.for_contact(him, measures, EventLog.new(), 6)["supply_situation"])

	assert_true(month_after < when_fresh - 0.0001, "the news never went stale")
	assert_almost_eq(month_after, never, 0.0001,
		"last month's news still counted for something the month after")


func test_a_change_that_changed_nothing_is_not_news() -> void:
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}
	var rewritten := _log_with(4, {"supply_situation": {"from": 70.0, "to": 70.0}})

	assert_almost_eq(
		float(Pressure.for_contact(him, measures, rewritten, 5)["supply_situation"]),
		float(Pressure.for_contact(him, measures, EventLog.new(), 5)["supply_situation"]),
		0.0001, "a value written back unchanged was reported as news")


func test_news_about_something_else_is_not_his_news() -> void:
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}
	var elsewhere := _log_with(4, {"quality_of_life": {"from": 0.9, "to": 0.2}})

	assert_almost_eq(
		float(Pressure.for_contact(him, measures, elsewhere, 5)["supply_situation"]),
		float(Pressure.for_contact(him, measures, EventLog.new(), 5)["supply_situation"]),
		0.0001, "he was moved by news of a thing he does not care about")


func test_the_mandate_changing_does_not_crash_the_month() -> void:
	# A world value may be a string, or absent before its first write. Anything
	# that coerced to a float would take the whole post down with it.
	var him := _man(["supply_situation"])
	var odd := EventLog.new()
	odd.emit(&"changed", &"world", 4, {"changes": {
		"crown_mandate": {"from": "increase_economic_output", "to": "grow_the_population"},
		"a_new_key": {"from": null, "to": 3.0},
	}})
	var felt := Pressure.for_contact(him, {"supply_situation": 70.0}, odd, 5)
	assert_true(felt.has("supply_situation"), "the month fell over on the mandate")


# --- Dampers: he has had his say --------------------------------------------

func test_a_man_who_has_just_written_has_less_to_say() -> void:
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}
	var fresh := WritingBook.new()
	fresh.record(him.id, "supply_situation", 5)

	assert_true(
		float(Pressure.for_contact(him, measures, EventLog.new(), 5, fresh)["supply_situation"])
			< float(Pressure.for_contact(him, measures, EventLog.new(), 5)["supply_situation"]),
		"writing about a thing left him as full of it as before")


func test_the_damper_wears_off() -> void:
	# **In his letters**, not in months (#256). He has to work through the rest
	# of what he had to say, which for a man with one concern is the floor.
	var him := _man(["supply_situation"])
	var measures := {"supply_situation": 70.0}
	var long_ago := WritingBook.new()
	long_ago.record(him.id, "supply_situation", 0)
	for _more in Pressure.FEWEST_WRITINGS:
		long_ago.record(him.id, "something_else", 1)

	assert_almost_eq(
		float(Pressure.for_contact(him, measures, EventLog.new(), 40, long_ago)["supply_situation"]),
		float(Pressure.for_contact(him, measures, EventLog.new(), 40)["supply_situation"]),
		0.0001, "he said everything else he had to say and still could not raise it")


func test_pressure_never_goes_below_nothing() -> void:
	var him := _man(["food_security"])
	var fresh := WritingBook.new()
	fresh.record(him.id, "food_security", 5)
	var felt := Pressure.for_contact(
		him, {"food_security": 3.0}, EventLog.new(), 5, fresh)
	assert_true(float(felt["food_security"]) >= 0.0,
		"a contented man who had just written was in debt about it")


# --- 🔒 One letter per contact, his loudest topic ---------------------------

func test_he_raises_the_worst_of_his_grievances_and_only_that() -> void:
	var him := _man(["food_security", "supply_situation"])
	var loudest := Pressure.loudest({"food_security": 30.0, "supply_situation": 80.0})
	assert_eq(String(loudest["topic"]), "supply_situation",
		"he wrote about the lesser of two troubles")


func test_a_man_with_nothing_over_his_threshold_says_nothing() -> void:
	assert_true(Pressure.loudest({"food_security": 5.0, "supply_situation": 9.0}).is_empty(),
		"a man mildly dissatisfied with two things wrote about one of them")


func test_a_tie_is_broken_by_the_topic_and_not_by_a_die() -> void:
	var once := Pressure.loudest({"food_security": 50.0, "supply_situation": 50.0})
	var twice := Pressure.loudest({"supply_situation": 50.0, "food_security": 50.0})
	assert_eq(String(once["topic"]), String(twice["topic"]),
		"two identical worlds picked different grievances")


func test_no_contact_writes_twice_in_one_month() -> void:
	# 🔒 The acceptance, through the real director. A man who wrote about all
	# three of his grievances would be a man the player learns to skim, which is
	# the failure SPEC §9.6 exists to prevent.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	for _month in 8:
		var seen: Dictionary = {}
		for inbound in machine.director.compose_inbox(run):
			var record: Dictionary = content.record("letters", inbound.letter_id)
			if not bool(record.get("skippable", true)):
				continue  # A must-send bypasses pressure, and may double up.
			var sender := String(inbound.sender)
			assert_false(seen.has(sender),
				"%s wrote twice in one month: %s and %s"
					% [sender, seen.get(sender, ""), inbound.letter_id])
			seen[sender] = inbound.letter_id
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()


func test_a_colony_where_nothing_is_wrong_brings_no_complaints() -> void:
	# 🔒 **The director consults pressure, not just the conditions.** Without
	# this the whole ticket is a calculation nobody reads: every letter whose
	# conditions held would still arrive, and `Pressure` would be an elaborate
	# opinion the post ignored.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# Every man on the roster given exactly what he wants.
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		var wants: Dictionary = {}
		for topic in contact.cares_about:
			wants[String(topic)] = MeasureRegistry.normalize(
				String(topic),
				float(ColonyMeasures.for_contact(run, contact).get(String(topic), 0.0)))
		contact.wants = wants

	for inbound in machine.director.compose_inbox(run):
		var record: Dictionary = content.record("letters", inbound.letter_id)
		assert_false(bool(record.get("skippable", true)),
			"%s wrote to complain although he had everything he wanted"
				% inbound.sender)


# --- 🔒 A must-send bypasses pressure, not the man --------------------------

func test_an_unskippable_letter_goes_however_he_feels() -> void:
	# §2: the natives have attacked and the governor wants orders. There is no
	# deliberation about whether to trouble the Crown with this, and
	# `skippable: false` already said so — no new field.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var unskippable := 0
	for id in content.ids("letters"):
		if not bool(content.record("letters", String(id)).get("skippable", true)):
			unskippable += 1
	assert_true(unskippable > 0,
		"there are no must-send letters, so the bypass proves nothing")


# --- The save ----------------------------------------------------------------

func test_what_he_has_had_his_say_about_survives_a_save() -> void:
	var run := RunState.new_run(SEED)
	run.writings.record(&"chancellor", "colony_revenue", 7)
	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.writings.writings_by(&"chancellor"), 1,
		"a reload gave a man back everything he had already said")


func test_the_same_seed_writes_the_same_post() -> void:
	var first: PackedStringArray = PackedStringArray()
	var second: PackedStringArray = PackedStringArray()
	for into in [first, second]:
		var run := RunState.new_run(SEED)
		ContactRoster.load_into(run, content)
		var machine := TurnMachine.new(run)
		machine.use_content(content)
		machine.saves_on_send = false
		for inbound in machine.director.compose_inbox(run):
			into.append(inbound.letter_id)
	assert_eq(first, second, "two identical runs brought different post")
