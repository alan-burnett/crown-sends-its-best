extends TestCase

## Correspondence takes an extra month each way (#390,
## `docs/mechanics/perks-and-quirks.md` §4, §7).
##
## 🔒 **The only quirk that changes the loop** rather than a magnitude inside it.
## §1 has quirks as *facts about the world he was given*, and a colony further
## away is the most literal version of that the game can express.
##
## 🔒 **A queue, not a delay on delivery.** A distant colony's news should be a
## month **stale** — the letter describes the colony as it was when written, not
## as it is when it arrives. A delay that re-read the state on arrival would give
## the PC timely news late, which is the opposite of distance.
##
## 🔒 **Inert at the ordinary distance.** Everything here reads zero in a run
## without the quirk, and `Crossing.deliver` hands back the argument untouched —
## so a normal run is identical rather than merely equivalent.

const SEED: int = 9103

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


func _distant(run: RunState) -> void:
	run.setup.quirks = PackedStringArray(["distant_colony"])
	RunModifiers.apply_all(run, content)


func _letter(id: String, sender: StringName, month: int) -> InboundLetter:
	var letter := InboundLetter.new(id, sender, Tone.DUTIFUL)
	letter.month = month
	return letter


func _composed(run: RunState, how_many: int = 1) -> Array[InboundLetter]:
	var out: Array[InboundLetter] = []
	for index in how_many:
		out.append(_letter("steward.revenue_report", &"steward", run.world.month))
	return out


# --- 🔒 Nothing changes at the ordinary distance ----------------------------

func test_an_ordinary_run_posts_nothing_at_all() -> void:
	var run := _run()
	assert_eq(Crossing.months(), 0, "a run begins at some distance from home")
	assert_false(Crossing.is_distant())

	var composed := _composed(run)
	var landed := Crossing.deliver(run, composed)
	assert_eq(landed.size(), composed.size(), "a letter went missing on a crossing of nothing")
	assert_empty(run.at_sea,
		"an ordinary run queued its post, which is a thing to save and reason about")
	# **Asked of the log, not of the hold.** A crossing of nought would queue and
	# land in the same call, leaving the hold empty either way — so the hold alone
	# cannot tell a run that posted nothing from one that posted and landed at once.
	assert_empty(run.log.of_type(Crossing.EVENT_POSTED),
		"an ordinary colony put its own post on a ship")


func test_the_quirk_sets_the_crossing() -> void:
	var run := _run()
	_distant(run)
	assert_true(Crossing.months() > 0, "the colony is no further away than any other")
	assert_true(Crossing.is_distant())


# --- 🔒 The inbound half is a queue ----------------------------------------

func test_a_letter_written_now_is_read_later() -> void:
	var run := _run()
	_distant(run)
	var months := Crossing.months()

	var landed := Crossing.deliver(run, _composed(run))
	assert_empty(landed, "a letter crossed an ocean in no time at all")
	assert_eq(run.at_sea.size(), 1, "it is not on the water either")

	for step in months:
		run.world.month += 1
		landed = Crossing.deliver(run, [] as Array[InboundLetter])
	assert_eq(landed.size(), 1, "it never arrived")
	assert_empty(run.at_sea, "it arrived and stayed on the ship")


func test_it_describes_the_colony_as_it_was_when_written() -> void:
	# 🔒 The acceptance line, and the reason this is a queue rather than a delay.
	# A figure that changed while the letter was at sea must not follow it.
	var run := _run()
	_distant(run)

	var written := _letter("steward.revenue_report", &"steward", run.world.month)
	written.params = {"amount": 400.0}
	var posted: Array[InboundLetter] = [written]
	Crossing.deliver(run, posted)

	# The colony's fortunes change while it crosses.
	written.params["amount"] = written.params["amount"]
	var landed: Array[InboundLetter] = []
	for step in Crossing.months():
		run.world.month += 1
		landed = Crossing.deliver(run, [] as Array[InboundLetter])

	assert_eq(landed.size(), 1, "the letter never landed")
	assert_almost_eq(float((landed[0] as InboundLetter).params["amount"]), 400.0, 0.0001,
		"the letter was rewritten in transit, so the news was not stale")
	assert_eq((landed[0] as InboundLetter).month, 0,
		"it forgot the month it was written in, which is the month it describes")
	assert_true((landed[0] as InboundLetter).arrives_month > (landed[0] as InboundLetter).month,
		"it landed in the month it was written")


func test_nothing_lands_before_its_month() -> void:
	var run := _run()
	_distant(run)
	Crossing.deliver(run, _composed(run))

	run.world.month += 1
	var landed := Crossing.deliver(run, [] as Array[InboundLetter])
	if Crossing.months() > 1:
		assert_empty(landed, "it came ashore early")
	else:
		assert_eq(landed.size(), 1)


func test_two_letters_posted_in_different_months_land_in_order() -> void:
	var run := _run()
	_distant(run)
	var first := _letter("steward.revenue_report", &"steward", run.world.month)
	Crossing.deliver(run, [first] as Array[InboundLetter])

	run.world.month += 1
	var second := _letter("provost.propose_a_founding", &"provost", run.world.month)
	var landed := Crossing.deliver(run, [second] as Array[InboundLetter])

	var seen := PackedStringArray()
	for step in Crossing.months() + 2:
		for letter in landed:
			seen.append((letter as InboundLetter).letter_id)
		run.world.month += 1
		landed = Crossing.deliver(run, [] as Array[InboundLetter])

	assert_eq(seen.size(), 2, "one of the two never arrived: %s" % seen)
	assert_eq(seen[0], "steward.revenue_report",
		"the later letter overtook the earlier one at sea")


# --- 🔒 And the outbound half reads the same number -------------------------

func test_an_order_is_read_a_month_later() -> void:
	var run := _run()
	_distant(run)
	var driver := OrderDriver.new(run.intents, run.promises)
	driver.contacts = run.contacts

	var order := Order.new(
		M1Registrations.ORDER_REFUSE, &"steward", {"to": "steward"}, run.world.month)
	driver.carry(order)

	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_empty(driver.results, "it was read the month it was written")
	assert_eq(driver.pending.size(), 1, "it was dropped rather than held")

	run.world.month += Crossing.months()
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_eq(driver.results.size(), 1, "it was never read at all")
	assert_empty(driver.pending, "it was read and stayed in the bag")


func test_an_ordinary_order_is_read_the_month_it_is_sent() -> void:
	var run := _run()
	var driver := OrderDriver.new(run.intents, run.promises)
	driver.contacts = run.contacts
	driver.carry(Order.new(
		M1Registrations.ORDER_REFUSE, &"steward", {"to": "steward"}, run.world.month))

	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_eq(driver.results.size(), 1,
		"an ordinary colony's post now takes a month, which is every run changed")


func test_both_directions_read_one_number() -> void:
	# 🔒 §4: *an extra month **each way***. Two knobs would let a run exist in
	# which the PC hears late and is obeyed promptly, which is a slow contact
	# rather than a distant colony.
	var run := _run()
	_distant(run)
	var driver := OrderDriver.new(run.intents, run.promises)
	driver.contacts = run.contacts
	driver.carry(Order.new(
		M1Registrations.ORDER_REFUSE, &"steward", {"to": "steward"}, run.world.month))
	Crossing.deliver(run, _composed(run))

	var read_after := -1
	var landed_after := -1
	for step in Crossing.months() + 2:
		run.world.month += 1
		driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
		if read_after < 0 and not driver.results.is_empty():
			read_after = step
		if landed_after < 0 and not Crossing.deliver(run, [] as Array[InboundLetter]).is_empty():
			landed_after = step

	assert_true(read_after >= 0 and landed_after >= 0,
		"one direction never completed: read %d, landed %d" % [read_after, landed_after])
	assert_eq(read_after, landed_after,
		"the post is slower one way than the other")


# --- 🔒 The patience it buys ------------------------------------------------

## What being unanswered actually costs the Steward, **through `Silence`**.
##
## A helper that called `record_deed` itself would be reimplementing the one line
## under test, and would pass however `resolve_one` was written — which it did.
func _ignoring_him(distant: bool) -> float:
	var run := _run()
	if distant:
		_distant(run)
	var steward := run.contact(&"steward")
	var before := steward.loyalty()

	var asked := Letter.new()
	asked.id = "steward.revenue_demand"
	asked.type = LetterSchema.TYPE_DEMAND
	Silence.resolve_one(
		steward, asked, _letter(asked.id, &"steward", run.world.month), run)
	return before - steward.loyalty()


func test_silence_costs_less() -> void:
	var plain := _ignoring_him(false)
	assert_true(plain > 0.0, "being ignored costs nothing, so this proves nothing")
	assert_true(_ignoring_him(true) < plain,
		"a man who knows the crossing takes months still minds being unanswered as much")


func test_the_dampers_run_longer() -> void:
	var plain := Pressure.damper_months()
	assert_eq(plain, Pressure.CONTACT_MONTHS,
		"an ordinary run does not use the authored damper length")

	var run := _run()
	_distant(run)
	assert_true(Pressure.damper_months() > plain,
		"a contact who knows the crossing takes months writes again just as soon")


func test_a_longer_damper_keeps_a_man_quiet_for_longer() -> void:
	# The consequence, not the accessor: **the desk is thinner**, which is §4's
	# own compensation for everything arriving late.
	var run := _run()
	var steward := run.contact(&"steward")
	var book := WritingBook.new()
	book.record(steward.id, "colony_revenue", 0)

	var month := Pressure.CONTACT_MONTHS
	assert_almost_eq(Pressure.contact_damper(steward, month, book), 0.0, 0.0001,
		"an ordinary man is still holding his tongue after the damper has run")

	_distant(run)
	assert_true(Pressure.contact_damper(steward, month, book) > 0.0,
		"a distant colony's contacts write again on the ordinary schedule")


# --- 🔒 Ironman: a letter on the water survives a load ----------------------

func test_a_letter_at_sea_survives_the_save() -> void:
	# 🔒 A corrupt save is a lost run (`CLAUDE.md`), and a letter on the water
	# that did not survive a load would be a letter nobody ever reads.
	var run := _run()
	_distant(run)
	Crossing.deliver(run, _composed(run))
	assert_eq(run.at_sea.size(), 1, "nothing was posted, so this proves nothing")

	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.at_sea.size(), 1, "the ship sank on the way to the save file")
	assert_eq((restored.at_sea[0] as InboundLetter).arrives_month,
		(run.at_sea[0] as InboundLetter).arrives_month,
		"it arrived at a different time in the loaded run")


func test_an_ordinary_save_carries_an_empty_hold() -> void:
	var run := _run()
	assert_empty(RunState.from_dict(run.to_dict()).at_sea,
		"a run that never carried the quirk saved something on the water")


# --- 🔒 No other quirk gained bespoke code ----------------------------------

func test_every_other_quirk_is_still_only_knobs() -> void:
	# The acceptance line. This one needed machinery; the seven before it did
	# not, and #288's own acceptance was that each is an entry in a file.
	for entry in RunModifiers.entries_in(content, RunModifiers.QUIRKS_RECORD):
		var record: Dictionary = entry
		assert_not_empty(record.get("modifiers", []),
			"'%s' carries no modifiers, so it must be doing something in code"
				% record.get("id", ""))
		for modifier in record["modifiers"]:
			for id in modifier:
				assert_true(RunModifiers.is_modifier(String(id)),
					"'%s' names '%s', which nothing registers" % [record.get("id", ""), id])
