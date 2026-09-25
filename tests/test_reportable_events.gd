extends TestCase

## Reporting letters: events a letter can read (#398, `the-director.md` §2, §8).
##
## 🔒 **A letter can report what happened, to whom it happened, and name what it
## carried** — the tribe, the town, the duke — through a param, never by
## re-deriving it (SPEC §9.1). And it can only point at an event
## `ReportableEvents` understands.

const SEED: int = 3980

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


## A colony of two towns, each with its governor, and the run's tribes.
func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := Town.new(&"kettleburn", "Kettleburn", Vector2i(6, 6))
	town.workers = 12
	run.colony.add(town)
	var governor := Governor.generate(town, run.streams)
	town.governor_id = governor.id
	run.add_contact(governor)
	if run.tribes == null or run.tribes.all.is_empty():
		run.tribes = Tribes.generate(run.streams)
	return run


func _context(run: RunState, sender: Contact, town: Town, month: int) -> LetterContext:
	var state := run.world
	state.month = month
	var context := LetterContext.new(state, sender, Tone.DUTIFUL)
	context.month = month
	context.town = town
	context.colony = run.colony
	context.contacts = run.contacts
	context.natives = run.tribes
	context.log = run.log
	return context


func _asks(event: String, within: int, concerning: String) -> Dictionary:
	return {"event": event, "within": within, "concerning": concerning}


# --- 🔒 Every row is an event the sim really emits --------------------------

func test_every_reportable_event_is_one_the_sim_emits() -> void:
	# A row naming an event nothing emits is a letter that can never fire, and it
	# would pass every other check. The constants are the sim's own names.
	var emitted := [
		NativeHelp.EVENT_GAVE, NativeHelp.EVENT_JOINED, TradeAgreement.EVENT_CLOSED,
		ExpeditionParty.EVENT_FOUNDED, ExpeditionParty.EVENT_ATTACKED,
		ExpeditionParty.EVENT_TURNED_BACK, RivalBook.EVENT_LATCHED,
		OpticsRegister.EVENT_TRIBUTE_PAID, Company.EVENT_DESTROYED,
		UrgeIntentExecutor.EVENT_PRESSED, BackRebellionExecutor.EVENT_BACKED,
	]
	var names := PackedStringArray()
	for event in emitted:
		names.append(String(event))
	for event in ReportableEvents.TABLE:
		assert_true(names.has(String(event)), "'%s' is not an event the sim emits" % event)


# --- 🔒 Scoped to the man or the town it concerns ---------------------------

func test_a_gift_to_his_town_is_his_to_report_and_names_the_tribe() -> void:
	var run := _run()
	var kettleburn := run.colony.by_id(&"kettleburn")
	var capital := run.colony.in_order()[0] as Town
	var tribe: Tribe = run.tribes.in_order()[0]
	run.log.emit(NativeHelp.EVENT_GAVE, kettleburn.id, 5, {
		"tribe": String(tribe.id), "town": String(kettleburn.id), "given": {},
	})

	var his := _context(run, run.contact(kettleburn.governor_id), kettleburn, 6)
	assert_true(ReportableEvents.it_happened(_asks("natives_gave", 3, "his_town"), his),
		"a tribe gave to Kettleburn and its governor could not say so")
	assert_eq(String(ReportableEvents.what_happened(
		{"event": "natives_gave", "within": 3, "concerning": "his_town", "field": "tribe"}, his)),
		tribe.display_name, "he could not name the tribe that helped")
	assert_eq(String(ReportableEvents.what_happened(
		{"event": "natives_gave", "within": 3, "concerning": "his_town", "field": "town"}, his)),
		"Kettleburn", "he named the town by its id")

	if capital != kettleburn:
		var other := _context(run, run.contact(capital.governor_id), capital, 6)
		assert_false(ReportableEvents.it_happened(_asks("natives_gave", 3, "his_town"), other),
			"a governor reported a gift made to another man's town as his own")
	assert_true(ReportableEvents.it_happened(_asks("natives_gave", 3, "the_colony"), his))


func test_a_dukes_latch_is_his_and_nobody_elses() -> void:
	var run := _run()
	var dukes := RivalDuke.all_in(run)
	assert_true(dukes.size() >= 2, "the fixture has fewer than two dukes, so this proves nothing")
	run.log.emit(RivalBook.EVENT_LATCHED, dukes[0].id, 7, {
		"rival": String(dukes[0].id), "name": dukes[0].display_name,
	})
	assert_true(ReportableEvents.it_happened(_asks("rival_reached_minimum", 4, "him"),
		_context(run, dukes[0], null, 8)))
	assert_false(ReportableEvents.it_happened(_asks("rival_reached_minimum", 4, "him"),
		_context(run, dukes[1], null, 8)), "one duke wrote about another's war as his own")


func test_an_old_event_is_not_news() -> void:
	var run := _run()
	var kettleburn := run.colony.by_id(&"kettleburn")
	run.log.emit(TradeAgreement.EVENT_CLOSED, kettleburn.id, 2, {
		"tribe": String((run.tribes.in_order()[0] as Tribe).id), "town": String(kettleburn.id),
		"why": "angered",
	})
	var context := _context(run, run.contact(kettleburn.governor_id), kettleburn, 9)
	assert_false(ReportableEvents.it_happened(_asks("native_trade_closed", 3, "his_town"), context),
		"a trade closed seven months ago was reported as this month's news")
	assert_true(ReportableEvents.it_happened(_asks("native_trade_closed", 0, "his_town"), context),
		"with no limit it had still happened")


func test_nothing_is_named_when_nothing_happened() -> void:
	var run := _run()
	var kettleburn := run.colony.by_id(&"kettleburn")
	var context := _context(run, run.contact(kettleburn.governor_id), kettleburn, 6)
	assert_false(ReportableEvents.it_happened(_asks("expedition_attacked", 6, "his_town"), context))
	assert_eq(int(ReportableEvents.what_happened({"event": "expedition_attacked", "within": 6,
		"concerning": "his_town", "field": "lost_people"}, context)), 0)


# --- 🔒 The validator keeps a report honest ---------------------------------

func _problems(params: Dictionary, conditions: Array) -> PackedStringArray:
	var validator := ContentValidator.new()
	validator.validate_trigger({
		"id": "trigger.test.report", "letter": "governor.report_month",
		"params": params, "conditions": conditions,
	})
	var out := PackedStringArray()
	for problem in validator.problems:
		out.append(problem.message)
	return out


func test_a_report_without_its_gate_is_refused() -> void:
	var reading := {"tribe": {"from": "what_happened", "event": "natives_gave",
		"within": 3, "concerning": "his_town", "field": "tribe"}}
	assert_not_empty(_problems(reading, [{"always": {}}]),
		"a letter could name a tribe for a gift that never happened")
	assert_empty(_problems(reading, [{"it_happened": _asks("natives_gave", 3, "his_town")}]))


func test_an_event_nobody_understands_is_refused() -> void:
	assert_not_empty(_problems({}, [{"it_happened": _asks("town_lived", 3, "his_town")}]),
		"a letter pointed at an event whose payload it does not understand")
	assert_not_empty(_problems({}, [{"it_happened": _asks("rival_reached_minimum", 3, "his_town")}]),
		"a duke's latch was asked about as though it happened to a town")
	assert_not_empty(_problems(
		{"x": {"from": "what_happened", "event": "natives_gave", "within": 3,
			"concerning": "his_town", "field": "given"}},
		[{"it_happened": _asks("natives_gave", 3, "his_town")}]),
		"a field no letter may print was read")
