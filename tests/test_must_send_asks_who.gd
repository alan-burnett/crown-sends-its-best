extends TestCase

## Must-send letters still ask who would send them (#258, SPEC §8.1, §8.5;
## `docs/mechanics/the-director.md` §2).
##
## 🔒 **It bypasses pressure. It does not bypass the man.** A world event does
## not write to the PC; a person does, and whether he does depends on what he
## thinks of him.
##
## **Consulted, informed, bypassed** — one event, three entirely different
## months.
##
## 🔒 **And the silence is where the Diplomat earns his place.** A governor who
## says nothing has not hidden it from everybody. He is never replaced, so a PC
## who loses him goes blind to disloyalty.

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
	content.free()


## A run whose governor has just settled on a new course, at a given regard.
func _after_a_change(regard: float) -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	run.contact(town.governor_id).relationship = Relationship.new(
		town.governor_id, regard)
	run.log.emit(GovernorDriver.EVENT_INTENT_SET, town.governor_id, run.world.month, {
		"town": String(town.id),
		"governor": String(town.governor_id),
		"intent": String(GovernorIntent.DEFENCE),
		"was": String(GovernorIntent.ECONOMY),
		"crisis": false,
	}, WorldPhase.INTENT)
	return run


func _context_for(run: RunState, contact: Contact, town: Town) -> LetterContext:
	var context := LetterContext.new(run.world, contact)
	context.town = town
	context.colony = run.colony
	context.log = run.log
	context.measures = ColonyMeasures.for_contact(run, contact)
	return context


# --- 🔒 Consulted, informed, bypassed ---------------------------------------

func test_the_three_bands_are_a_band_and_never_a_figure() -> void:
	# SPEC §8.5 keeps loyalty off the player's screens. What reaches him is which
	# of three letters arrived, or none.
	assert_eq(Relationship.band_of(90.0), Relationship.HIGH)
	assert_eq(Relationship.band_of(45.0), Relationship.MEDIUM)
	assert_eq(Relationship.band_of(5.0), Relationship.LOW)

	var seen: Array = []
	for step in 101:
		var band := Relationship.band_of(float(step))
		if seen.is_empty() or seen[seen.size() - 1] != band:
			seen.append(band)
	assert_eq(seen, [Relationship.LOW, Relationship.MEDIUM, Relationship.HIGH],
		"the bands do not run once from the bottom to the top")


func test_a_man_who_likes_the_pc_asks_what_he_would_rather() -> void:
	var run := _after_a_change(Relationship.HIGH_AT + 10.0)
	var town := run.colony.in_order()[0]
	var context := _context_for(run, run.contact(town.governor_id), town)

	assert_true(ContentRegistry.test_condition("i_changed_my_intent", {"within": 2}, context),
		"the fixture did not change his mind")
	assert_true(ContentRegistry.test_condition(
		"my_regard_is", {"band": String(Relationship.HIGH)}, context),
		"a governor at high regard was not read as such")

	var letter := Letter.from_record(
		content.record("letters", "governor.i_have_settled_on_a_course"))
	assert_true(letter.has_reply(), "the consulted letter asks nothing")
	assert_false(letter.steps().is_empty(), "the consulted letter offers no choice")


func test_a_man_who_is_merely_obliged_tells_and_does_not_ask() -> void:
	var run := _after_a_change(Relationship.MEDIUM_AT + 4.0)
	var town := run.colony.in_order()[0]
	var context := _context_for(run, run.contact(town.governor_id), town)

	assert_true(ContentRegistry.test_condition(
		"my_regard_is", {"band": String(Relationship.MEDIUM)}, context),
		"a governor at middling regard was not read as such")

	var letter := Letter.from_record(
		content.record("letters", "governor.the_course_i_must_take"))
	assert_true(letter.steps().is_empty(),
		"the informed letter asks the PC something, which is the consulted one's job")


func test_a_man_who_does_not_care_for_the_pc_says_nothing() -> void:
	# 🔒 **Bypassed.** He changes his mind and does not mention it.
	var run := _after_a_change(Relationship.MEDIUM_AT - 10.0)
	var town := run.colony.in_order()[0]
	var context := _context_for(run, run.contact(town.governor_id), town)

	for band in [Relationship.HIGH, Relationship.MEDIUM]:
		assert_false(ContentRegistry.test_condition(
			"my_regard_is", {"band": String(band)}, context),
			"a governor at low regard answered to '%s'" % band)


func test_one_event_produces_three_different_months() -> void:
	# The acceptance, through the director. The same intent change, three
	# regards, and what arrives is a question, a report, or nothing.
	var arrived: Dictionary = {}
	for regard in [Relationship.HIGH_AT + 10.0, Relationship.MEDIUM_AT + 4.0,
			Relationship.MEDIUM_AT - 10.0]:
		var run := _after_a_change(float(regard))
		var machine := TurnMachine.new(run)
		machine.use_content(content)
		machine.saves_on_send = false
		var said := ""
		for inbound in machine.director.compose_inbox(run):
			if inbound.letter_id.begins_with("governor.i_have_settled") \
					or inbound.letter_id.begins_with("governor.the_course"):
				said = inbound.letter_id
		arrived["%.0f" % regard] = said

	var distinct: Dictionary = {}
	for regard in arrived:
		distinct[String(arrived[regard])] = true
	assert_eq(distinct.size(), 3,
		"one event produced the same month at three regards: %s" % arrived)
	assert_true(arrived.has("%.0f" % (Relationship.MEDIUM_AT - 10.0)))
	assert_eq(String(arrived["%.0f" % (Relationship.MEDIUM_AT - 10.0)]), "",
		"a governor who does not care for the PC told him anyway")


# --- 🔒 A must-send ignores both dampers and is never culled ----------------

func test_the_intent_letters_are_must_sends() -> void:
	for id in ["governor.i_have_settled_on_a_course", "governor.the_course_i_must_take"]:
		assert_false(bool(content.record("letters", id).get("skippable", true)),
			"%s is skippable, so the most consequential thing a governor does "
				% id + "waits behind his routine post")


func test_a_must_send_arrives_though_he_wrote_last_month() -> void:
	# 🔒 Both dampers ignored. He has just had his say about everything else and
	# it makes no difference: the natives have attacked, or he has changed what
	# his town is for.
	var run := _after_a_change(Relationship.HIGH_AT + 10.0)
	var town := run.colony.in_order()[0]
	run.writings.record(town.governor_id, "food_security", run.world.month)
	run.writings.record(town.governor_id, "quality_of_life", run.world.month)

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var arrived := false
	for inbound in machine.director.compose_inbox(run):
		if inbound.letter_id == "governor.i_have_settled_on_a_course":
			arrived = true
	assert_true(arrived,
		"a man who had lately written held back the one thing he had to say")


# --- 🔒 The Diplomat, and the silence ---------------------------------------

func test_he_reports_the_gap_between_what_was_asked_and_what_was_done() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]

	# The PC urged one thing; the man settled on another afterwards.
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 2
	town.intent = GovernorIntent.DEFENCE
	town.intent_since = 4
	run.world.month = 5

	var context := _context_for(run, run.contact(&"diplomat"), null)
	assert_true(ContentRegistry.test_condition("he_did_otherwise", {"within": 6}, context),
		"the Diplomat missed a governor doing the opposite of what he was asked")

	var found := ColonyConditions.diverged({"within": 6}, context)
	assert_eq(String(found["asked"]), String(GovernorIntent.ECONOMY))
	assert_eq(String(found["did"]), String(GovernorIntent.DEFENCE))


func test_he_names_the_thing_as_a_letter_would_name_it() -> void:
	# 🔒 Never an id. *he continues at prepare_for_rebellion* is a bug report.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 2
	town.intent = GovernorIntent.DEFENCE
	town.intent_since = 4
	run.world.month = 5

	var context := _context_for(run, run.contact(&"diplomat"), null)
	var said := String(ContentRegistry.supply_param(
		"divergence", {"field": "did", "fallback": "the work"}, context))
	assert_false(said.contains("_"), "he named an intent by its id: '%s'" % said)
	assert_false(said.is_empty(), "he named nothing at all")


func test_a_man_who_has_not_answered_yet_has_not_refused() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 6
	town.intent = GovernorIntent.DEFENCE
	# He settled on this *before* the PC wrote, so he has not yet answered.
	town.intent_since = 3
	run.world.month = 7

	var context := _context_for(run, run.contact(&"diplomat"), null)
	assert_false(ContentRegistry.test_condition("he_did_otherwise", {"within": 6}, context),
		"a governor who has not yet answered was reported as having refused")


func test_an_old_urging_is_not_reported_for_ever() -> void:
	# `urged_intent` is never cleared, so without a window the Diplomat would
	# report the same four-year-old disobedience every five months until the run
	# ended. He is reporting news, not keeping a grudge.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 2
	town.intent = GovernorIntent.DEFENCE
	town.intent_since = 4

	run.world.month = 2 + 6
	var context := _context_for(run, run.contact(&"diplomat"), null)
	assert_true(ContentRegistry.test_condition("he_did_otherwise", {"within": 6}, context),
		"the window shut early, so a fresh divergence went unreported")

	run.world.month = 2 + 7
	context = _context_for(run, run.contact(&"diplomat"), null)
	assert_false(ContentRegistry.test_condition("he_did_otherwise", {"within": 6}, context),
		"he was still reporting an urging the PC sent seven months ago")


func test_nothing_at_all_diverges_in_an_obedient_colony() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 2
	town.intent = GovernorIntent.ECONOMY
	town.intent_since = 4
	run.world.month = 5

	var context := _context_for(run, run.contact(&"diplomat"), null)
	assert_false(ContentRegistry.test_condition("he_did_otherwise", {"within": 6}, context),
		"a governor who did as he was asked was reported for it")


## A run where one governor has quietly done the opposite of what he was told.
func _after_a_silence(run: RunState) -> Town:
	var town: Town = run.colony.in_order()[0]
	run.contact(town.governor_id).relationship = Relationship.new(
		town.governor_id, Relationship.MEDIUM_AT - 10.0)
	town.urged_intent = GovernorIntent.ECONOMY
	town.urged_month = 2
	town.intent = GovernorIntent.DEFENCE
	town.intent_since = 4
	run.world.month = 5
	return town


func _inbox_of(run: RunState) -> Array:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var ids: Array = []
	for inbound in machine.director.compose_inbox(run):
		ids.append(String(inbound.letter_id))
	return ids


func test_his_office_does_not_wait_on_his_grievances() -> void:
	# 🔒 §8.1: telling the PC what the post does not is **a different job from
	# reporting the world**, so it is a must-send. Gated behind his own pressure
	# it waited on his feelings about quality of life, which have nothing to do
	# with a governor ignoring an order — and in a contented colony he never felt
	# enough about anything to mention it at all.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	_after_a_silence(run)

	var felt := Pressure.for_contact(run.contact(&"diplomat"),
		ColonyMeasures.for_contact(run, run.contact(&"diplomat")),
		run.log, run.world.month, run.writings)
	assert_true(Pressure.loudest(felt, Threshold.for_contact(
		run.contact(&"diplomat"), 0)).is_empty(),
		"the fixture gave the Diplomat a grievance, so this proves nothing")

	assert_true(_inbox_of(run).has("diplomat.he_did_otherwise"),
		"the Diplomat had nothing to complain of and so said nothing about "
			+ "the one thing he is kept there to say")


func test_without_a_diplomat_the_silence_reaches_nobody() -> void:
	# 🔒 §8.1: he is never replaced, so a PC who loses him **goes blind to
	# disloyalty.** Every governor who has quietly stopped writing becomes one he
	# knows nothing about — which is what prices the Diplomat's death.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := _after_a_silence(run)
	run.log.emit(GovernorDriver.EVENT_INTENT_SET, town.governor_id, 4, {
		"town": String(town.id),
		"governor": String(town.governor_id),
		"intent": String(GovernorIntent.DEFENCE),
	}, WorldPhase.INTENT)
	run.contacts.erase("diplomat")

	for id in _inbox_of(run):
		assert_false(id.begins_with("governor.i_have_settled"),
			"a governor at low regard consulted the PC after all")
		assert_false(id.begins_with("governor.the_course"),
			"a governor at low regard informed the PC after all")
		assert_false(id.begins_with("diplomat."),
			"a Diplomat who is not on the roster wrote a letter")
