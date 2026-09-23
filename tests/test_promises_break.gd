extends TestCase

## Promises break when the Crown refuses (#70, SPEC §9.5, §10.3).
##
## M1 built promise tracking against a Crown that always pays. Now it does not.
##
## **The cascade is the point**: broken promises lower loyalty, lower loyalty
## worsens compliance (§8.5), worse compliance raises rebel sentiment (§12.3).
## It should be possible to watch a run come apart through it, which is why the
## breadth of the collapse matters and why the injured parties write about it.

const SEED: int = 1649

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


func _contact(id: StringName) -> Contact:
	var contact := Contact.new(id, {})
	contact.display_name = String(id)
	contact.relationship = Relationship.new(id, 60.0)
	return contact


## A book owing gold to several people, plus one colony-fulfilled promise.
func _owing() -> Dictionary:
	var book := PromiseBook.new()
	var log := EventLog.new()
	var contacts: Dictionary = {}

	for id in ["marshal", "chancellor", "steward"]:
		contacts[id] = _contact(StringName(id))
		book.make(Promise.new(StringName(id), &"gold", {"amount": 300.0}, 1, 9), contacts[id], log, 1)

	# Sent from the colony's own stores. Not the Crown's to refuse.
	var colonys := Promise.new(&"governor_ashmere", &"resource", {"amount": 40.0, "resource": "wood"}, 1, 9)
	colonys.payer = Promise.PAYER_COLONY
	contacts["governor_ashmere"] = _contact(&"governor_ashmere")
	book.make(colonys, contacts["governor_ashmere"], log, 1)

	return {"book": book, "log": log, "contacts": contacts}


# --- 🔒 Everything outstanding, in the same month ---------------------------

func test_refusing_breaks_every_outstanding_gold_promise_at_once() -> void:
	# Not the ones that happen to fall due. When the Treasury stops, it stops
	# for all of them, and because the PC owes several people this lands as a
	# broad collapse rather than one penalty.
	var owing := _owing()
	var broken: Array = owing["book"].repudiate(owing["contacts"], owing["log"], 4)

	assert_eq(broken.size(), 3, "only %d of three gold promises broke" % broken.size())
	for promise in broken:
		assert_eq(String(promise.status), String(Promise.BROKEN))
		assert_eq(promise.settled_month, 4)


func test_a_colony_fulfilled_promise_is_untouched() -> void:
	# A governor sending resources to a neighbour is not the Crown's to refuse.
	var owing := _owing()
	owing["book"].repudiate(owing["contacts"], owing["log"], 4)

	var left: Array = owing["book"].outstanding()
	assert_eq(left.size(), 1, "the colony's own promise was repudiated too")
	assert_eq(String(left[0].payer), String(Promise.PAYER_COLONY))


func test_each_break_costs_loyalty_with_its_own_recipient() -> void:
	# Not a global penalty. Three people are each let down by the PC, separately.
	var owing := _owing()
	var contacts: Dictionary = owing["contacts"]
	var before: Dictionary = {}
	for id in contacts:
		before[id] = contacts[id].loyalty()

	owing["book"].repudiate(contacts, owing["log"], 4)

	for id in ["marshal", "chancellor", "steward"]:
		assert_true(contacts[id].loyalty() < float(before[id]),
			"%s was let down and thought no less of the PC" % id)
	assert_almost_eq(
		contacts["governor_ashmere"].loyalty(), float(before["governor_ashmere"]), 0.001,
		"a contact whose promise was never broken lost loyalty anyway",
	)


func test_each_break_emits_its_own_event() -> void:
	var owing := _owing()
	owing["book"].repudiate(owing["contacts"], owing["log"], 4)

	var events: Array = owing["log"].of_type(PromiseBook.EVENT_BROKEN)
	assert_eq(events.size(), 3)
	var named: Dictionary = {}
	for event in events:
		named[String(event.subject)] = true
	assert_eq(named.size(), 3, "the events do not name who was let down")


func test_leaving_refusal_does_not_repair_what_broke() -> void:
	var owing := _owing()
	owing["book"].repudiate(owing["contacts"], owing["log"], 4)
	# The Crown pays again. What was broken stays broken.
	owing["book"].settle_due(owing["contacts"], owing["log"], 9, true)

	# The colony's own promise still falls due and is still kept — it was never
	# the Crown's to refuse. What must not have happened is a repudiated one
	# being honoured after the fact.
	for event in owing["log"].of_type(PromiseBook.EVENT_KEPT):
		assert_ne(String(event.payload.get("payer", "")), String(Promise.PAYER_CROWN),
			"a promise the Crown had repudiated was honoured after the fact")

	for promise in owing["book"].all():
		if promise.payer == Promise.PAYER_CROWN:
			assert_eq(String(promise.status), String(Promise.BROKEN))


# --- Driven from the refusal machine ----------------------------------------

func _run_to_refusal() -> Dictionary:
	var owing := _owing()
	var promises := PromiseDriver.new(owing["book"])
	promises.contacts = owing["contacts"]

	var standing := CrownStanding.new()
	standing.standing = 0.0
	standing.band = CrownStanding.band_of(0.0)

	var refusal := CrownRefusal.new()
	var driver := CrownStandingDriver.new(standing, refusal)
	driver.promises = promises

	var state := WorldValues.initial_state()
	for month in range(1, 2 + CrownRefusal.WARNING_TURNS + 1):
		state.month = month
		standing.standing = 0.0
		standing.band = CrownStanding.band_of(0.0)
		driver.on_phase(WorldPhase.RUN_END_CHECK, state, owing["log"], RngStreams.new(SEED))

	owing["refusal"] = refusal
	return owing


func test_entering_refusal_repudiates_without_anybody_asking() -> void:
	var owing := _run_to_refusal()
	assert_eq(String(owing["refusal"].state), String(CrownRefusal.REFUSING))
	assert_eq(owing["log"].of_type(PromiseBook.EVENT_BROKEN).size(), 3,
		"the faucet shut and the promises were left standing")


func test_nothing_breaks_during_the_window() -> void:
	# **The window is the point.** Promises are honoured throughout it.
	var owing := _owing()
	var promises := PromiseDriver.new(owing["book"])
	promises.contacts = owing["contacts"]

	var standing := CrownStanding.new()
	standing.standing = 0.0
	standing.band = CrownStanding.band_of(0.0)
	var driver := CrownStandingDriver.new(standing, CrownRefusal.new())
	driver.promises = promises

	var state := WorldValues.initial_state()
	state.month = 1
	driver.on_phase(WorldPhase.RUN_END_CHECK, state, owing["log"], RngStreams.new(SEED))

	assert_empty(owing["log"].of_type(PromiseBook.EVENT_BROKEN),
		"a promise broke during the warning window")


func test_the_refusal_event_names_who_was_let_down() -> void:
	# So the grievances #71 reads are already on the record, and nothing has to
	# be reconstructed later.
	var owing := _run_to_refusal()
	var events: Array = owing["log"].of_type(CrownRefusal.EVENT_REFUSING)
	var with_names: Array = []
	for event in events:
		if event.payload.has("let_down"):
			with_names.append(event)

	assert_not_empty(with_names, "nothing recorded who the Crown let down")
	var named: PackedStringArray = with_names[0].payload["let_down"]
	assert_eq(named.size(), 3)
	assert_eq(int(with_names[0].payload["repudiated"]), 3)


# --- The injured party writes about it --------------------------------------

func test_a_contact_let_down_has_something_to_write_about() -> void:
	# A loyalty drop nobody mentions is a number moving in the dark.
	var contact := _contact(&"marshal")
	var context := LetterContext.new(WorldValues.initial_state(), contact, &"")
	context.month = 5

	assert_false(ColonyConditions.i_was_let_down({"within": 2}, context),
		"a contact who was never let down had a grievance")

	contact.relationship.settle_promise("promise_0", false, 4)
	assert_true(ColonyConditions.i_was_let_down({"within": 2}, context))

	# Old news is not news.
	context.month = 40
	assert_false(ColonyConditions.i_was_let_down({"within": 2}, context),
		"a contact was still writing about it three years later")


func test_the_letters_exist_and_are_not_forced_on_the_player() -> void:
	for id in ["marshal.let_down", "chancellor.let_down"]:
		var letter := Letter.from_record(content.record("letters", id))
		assert_true(letter != null, "there is no '%s'" % id)
		assert_true(letter.skippable,
			"'%s' cannot be set aside, and a run coming apart would bury the desk" % id)


func test_being_let_down_is_remembered_across_a_reload() -> void:
	var contact := _contact(&"marshal")
	contact.relationship.settle_promise("promise_0", false, 4)

	var restored := Relationship.from_dict(contact.relationship.to_dict())
	assert_eq(restored.promises_broken, 1)
	assert_eq(restored.last_promise_broken_month, 4)
