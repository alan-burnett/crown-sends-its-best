extends TestCase

## Colony Overrun waits for the Crown to give up (#470, `endings.md` §1, §2,
## `founding-towns.md` §3, SPEC §13.1).
##
## 🔒 **Losing the last town is not yet the end.** With no town and nobody
## walking, the Chancellor writes his formal warning and the Provost offers a
## town by sea in the same month's post, and the run goes on.
##
## 🔒 **Overrun comes when the Crown will commit no more**: it is refusing
## payments, or the PC let the offer go by arguing against it or leaving it
## unanswered. A town the Crown is paying for, on its way, keeps the run alive.
##
## 🔒 **No Overrun arrives before the warning, nor, while the Crown pays, before
## the offer.**

const SEED: int = 470

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _machine(run: RunState) -> TurnMachine:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	return machine


## Every town the colony holds taken by the natives, and nobody walking.
func _taken(run: RunState) -> void:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	for town in run.colony.in_order().duplicate():
		run.colony.lost(town, Company.NATIVE, "stormed", context, WorldPhase.MOVEMENT)
	run.parties.clear()


## A turn at the desk: every letter set aside but the one answered, if any, and
## the post sent. Returns the letters that were on the desk.
func _turn(machine: TurnMachine, answering: String = "", option: String = "") -> PackedStringArray:
	var run := machine.run
	machine.begin_turn()
	var desk := PackedStringArray()
	for inbound in run.inbox:
		desk.append(inbound.letter_id)
		inbound.status = InboundLetter.SET_ASIDE
		if inbound.letter_id != answering:
			continue
		inbound.status = InboundLetter.ANSWERED
		var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
		outgoing.params = inbound.params.duplicate()
		var wizard := ReplyWizard.new(Letter.from_record(content.record("letters", inbound.letter_id)), outgoing)
		wizard.choose_tone(Tone.DUTIFUL)
		wizard.choose("founding", option)
		run.post.add(outgoing)
	machine.send_post()
	return desk


## The colony falls in the month the post resolves, so the next desk is the one
## the last chance arrives on.
func _falls(machine: TurnMachine) -> void:
	machine.begin_turn()
	for inbound in machine.run.inbox:
		inbound.status = InboundLetter.SET_ASIDE
	_taken(machine.run)
	machine.send_post()


func _is_overrun(run: RunState) -> bool:
	return run.ending != null and run.ending.is_over() and run.ending.how == RunEndCheck.OVERRUN


# --- 🔒 The last chance arrives, and the run goes on --------------------------

func test_losing_the_last_town_brings_the_warning_and_the_offer_together() -> void:
	var run := _run()
	# Old enough that the Provost's ordinary proposal could be made too, and a
	# man who always asks, so that the proposal is not settled out of sight.
	run.world.month = 30
	Consultation.load_from({"always_above": -1.0})
	var machine := _machine(run)
	# A month with people in it, so a colony at nobody has fallen from somewhere.
	_turn(machine)
	_falls(machine)
	assert_false(machine.is_over(), "the colony fell and the run ended before anybody wrote")
	assert_eq(run.log.of_type(RunEndDriver.EVENT_FALLEN).size(), 1)

	# He last proposed a founding long ago, so nothing but the fall stops him now.
	run.letters_sent.erase(Director.sent_key("provost.propose_a_founding", &"provost"))
	machine.begin_turn()
	var desk := PackedStringArray()
	for inbound in run.inbox:
		desk.append(inbound.letter_id)
	assert_true(desk.has("chancellor.the_colony_has_fallen"), "the Chancellor's formal warning did not come")
	assert_true(desk.has(RunEndDriver.OFFER), "the Provost did not offer a town by sea")
	assert_false(desk.has("provost.propose_a_founding"),
		"the Provost offered two foundings in one post")
	assert_false(desk.has("chancellor.colony_dwindling"),
		"the Chancellor counted nobody as a colony dwindling")


## The Crown content with the PC, whatever an empty colony's books say. Held
## here because the acceptance is *with the Crown paying*: a colony with nobody
## in it returns nothing, and standing is left to fall as it will elsewhere.
func _content(run: RunState) -> void:
	run.standing.standing = CrownStanding.MAXIMUM
	run.standing.band = CrownStanding.BAND_CONTENT


func test_accepting_founds_a_new_town_and_the_run_goes_on() -> void:
	var run := _run()
	var machine := _machine(run)
	_falls(machine)
	_content(run)
	_turn(machine, RunEndDriver.OFFER, "meanly")
	for month in CrownFounding.MONTHS_AT_SEA + 2:
		assert_false(machine.is_over(), "a town was on its way and the run ended in month %d" % month)
		if machine.is_over() or not run.colony.is_empty():
			break
		_content(run)
		_turn(machine)
	assert_false(run.colony.is_empty(), "the PC paid for a town by sea and none arrived")
	assert_eq(run.log.of_type(CrownFounding.EVENT_ARRIVED).size(), 1)
	assert_false(machine.is_over(), "the town arrived and the run ended all the same")


# --- 🔒 Overrun comes when the Crown will commit no more ----------------------

func test_letting_the_offer_go_ends_the_run_at_the_next_resolution() -> void:
	var run := _run()
	var machine := _machine(run)
	_falls(machine)
	var desk := _turn(machine, RunEndDriver.OFFER, "let_it_go")
	assert_true(desk.has(RunEndDriver.OFFER))
	assert_true(_is_overrun(run), "the PC let the recovery go and the run went on")


func test_leaving_the_offer_unanswered_ends_the_run_at_the_next_resolution() -> void:
	var run := _run()
	var machine := _machine(run)
	_falls(machine)
	var desk := _turn(machine)
	assert_true(desk.has(RunEndDriver.OFFER) and desk.has("chancellor.the_colony_has_fallen"),
		"the run could end without the warning and the offer reaching the player")
	assert_true(_is_overrun(run), "the offer went unanswered and the run went on")


## The check alone, month by month, with the letters of each month's post
## recorded as the director would record them.
func _check(run: RunState, month: int) -> void:
	run.world.month = month
	RunEndDriver.new(run).on_phase(WorldPhase.RUN_END_CHECK, run.world, run.log, run.streams)


func _posted(run: RunState, letter: String) -> void:
	run.log.emit(Director.EVENT_DISPATCHED, &"crown", run.world.month, {"letter": letter}, WorldPhase.DISPATCH)


func _a_town_at_sea(run: RunState) -> void:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	run.foundings.append(CrownFounding.proposed(&"provost", "meanly", &"", &"", &"", context))


func test_the_crown_refusing_payments_breaks_a_town_at_sea_and_ends_it() -> void:
	var run := _run()
	_check(run, 8)
	_taken(run)
	_check(run, 9)
	_posted(run, "chancellor.the_colony_has_fallen")
	_posted(run, RunEndDriver.OFFER)
	_a_town_at_sea(run)
	# **A town on its way outlasts the offer let go**: the PC need not buy a
	# second when the first is at sea.
	run.log.emit(TurnMachine.EVENT_SET_ASIDE, &"provost", 9, {"letter": RunEndDriver.OFFER}, WorldPhase.DISPATCH)
	_check(run, 10)
	assert_false(run.ending.is_over(), "a town was at sea and the Crown paying, and the run ended")

	run.refusal.state = CrownRefusal.REFUSING
	_check(run, 11)
	assert_true(_is_overrun(run), "the Crown refused payments with the colony empty and the run went on")


func test_a_fall_the_crown_could_not_pay_for_has_no_offer_and_ends_after_the_warning() -> void:
	var run := _run()
	var machine := _machine(run)
	run.refusal.state = CrownRefusal.REFUSING
	_check(run, 8)
	_taken(run)
	_check(run, 9)
	assert_false(run.ending.is_over(), "the colony fell and the run ended before the Chancellor could write")
	var desk := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		desk.append(inbound.letter_id)
	assert_true(desk.has("chancellor.the_colony_has_fallen"), "the run ended without his formal warning")
	assert_false(desk.has(RunEndDriver.OFFER), "the Provost offered a town the Crown would not pay for")

	# 🔒 **Even should the Treasury reopen**: there was no offer to wait on.
	run.refusal.state = CrownRefusal.SOLVENT
	_check(run, 10)
	assert_true(_is_overrun(run), "a fall the Crown could not pay for held the run open")


# --- 🔒 The offer reaches the player whatever the Provost thinks of him ----------

func test_the_provost_asks_whatever_his_regard() -> void:
	# A man who never consults the PC settles every offer himself (§10). Not this
	# one: the ending waits on the answer.
	Consultation.load_from({"always_above": 101.0, "floor_chance": 0.0, "at_bottom": 101.0})
	var run := _run()
	var machine := _machine(run)
	_check(run, 8)
	_taken(run)
	_check(run, 9)
	var desk := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		desk.append(inbound.letter_id)
	assert_true(desk.has(RunEndDriver.OFFER), "a Provost past consulting settled the last chance himself")


func test_arguing_against_another_founding_is_not_letting_the_recovery_go() -> void:
	var run := _run()
	_check(run, 8)
	_taken(run)
	_check(run, 9)
	_posted(run, "chancellor.the_colony_has_fallen")
	run.log.emit(TurnMachine.EVENT_ORDER_ISSUED, &"provost", 9, {
		"kind": String(M1Registrations.ORDER_DISSUADE_FOUNDING), "addressed_to": "provost",
		TurnMachine.ANSWERS_KEY: "provost.propose_a_founding",
	}, WorldPhase.DISPATCH)
	_check(run, 10)
	assert_false(run.ending.is_over(), "the PC argued against a botanist and lost the colony for it")


func test_a_colony_that_stood_again_and_fell_again_is_offered_again() -> void:
	var run := _run()
	_check(run, 8)
	var towns := run.colony.in_order().duplicate()
	_taken(run)
	_check(run, 9)
	var first := RunEndDriver.the_fall(run.log)
	assert_true(first != null)
	_posted(run, "chancellor.the_colony_has_fallen")

	var again := Town.new(&"again", "Again", (towns[0] as Town).at)
	again.workers = 1_000
	run.colony.add(again)
	_check(run, 10)
	assert_true(RunEndDriver.the_fall(run.log) == null, "a colony standing again was still fallen")
	_taken(run)
	# The Crown has given up this time, and the warning of the first fall does
	# not stand for a warning of this one.
	run.refusal.state = CrownRefusal.REFUSING
	_check(run, 11)
	var second := RunEndDriver.the_fall(run.log)
	assert_true(second != null and second.month == 11, "the second fall opened no last chance")
	assert_false(run.ending.is_over(), "the second fall ended the run on the first fall's warning")
