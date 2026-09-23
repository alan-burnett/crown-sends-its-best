extends TestCase

## Leaving the desk for good (#77, SPEC §13.2, §15, §16.2).
##
## 🔒 **Scored from the state at that moment**, not from a running total.
## Prestige reflects the Crown's current view and can fall, which is what makes
## the timing a decision rather than a formality.
##
## 🔒 **Ironman: a retired run cannot be resumed.** The save is closed out.
##
## **This is the first milestone in which a run can end at all** — fail
## conditions are M6, so retirement is the only exit there is.

const SEED: int = 4409

var content: ContentDatabase = null
var _save_path: String = ""


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	_save_path = "user://test_retirement_%d.save" % Time.get_ticks_usec()


func after_each() -> void:
	SaveGame.delete_save(_save_path)
	reset_world()
	content.free()


func _machine(seed_value: int = SEED) -> TurnMachine:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.save_path = _save_path
	return machine


## Gold onto the Crown's books, through the events `CrownAccounts` reduces.
func _received(run: RunState, month: int, amount: float) -> void:
	run.log.emit(Trade.EVENT_SOLD, &"ashmere", month, {
		"town": "ashmere", "resource": "furs", "sold": 1.0,
		"earned": amount, "tax": amount, "rate": 0.1,
	}, WorldPhase.COLONY_MONTH)


func _paid(run: RunState, month: int, amount: float) -> void:
	run.log.emit(PolicyBook.EVENT_BILLED, &"crown", month, {
		"policy": "curriculum", "crown_paid": amount,
	}, WorldPhase.CROWNS_MONTH)


# --- 🔒 Reachable at any time, and it ends the run --------------------------

func test_a_run_is_not_over_until_it_is() -> void:
	var machine := _machine()
	assert_false(machine.is_over(), "a run began already finished")
	assert_false(machine.run.ending.is_over())


func test_retiring_ends_the_run() -> void:
	var machine := _machine()
	machine.begin_turn()
	assert_true(machine.retire(), "the desk refused to let the PC go")
	assert_true(machine.is_over())
	assert_eq(String(machine.run.ending.reason), String(RunEnding.RETIRED))
	assert_eq(machine.run.ending.month, machine.run.world.month)


func test_it_is_reachable_with_the_post_half_written() -> void:
	# **Mid-post counts.** A man who has decided to go does not owe the Crown his
	# correspondence first, and a retire control that waited for an empty desk
	# would be unreachable in exactly the months a player most wants it.
	var machine := _machine()
	machine.begin_turn()
	assert_false(bool(machine.can_send()["ok"]),
		"the fixture had nothing unanswered, so this tests nothing")
	assert_true(machine.retire(), "the desk refused to let him go with letters unread")


func test_retiring_twice_changes_nothing() -> void:
	var machine := _machine()
	machine.begin_turn()
	machine.retire()
	var month := machine.run.ending.month
	var score := machine.run.ending.score
	assert_false(machine.retire(), "the run ended a second time")
	assert_eq(machine.run.ending.month, month, "the second retirement moved the date")
	assert_almost_eq(machine.run.ending.score, score, 0.0001, "and rescored him")


# --- 🔒 Ironman: it cannot be resumed ---------------------------------------

func test_the_save_is_closed_out() -> void:
	var machine := _machine()
	machine.begin_turn()
	SaveGame.save(machine.run, _save_path)
	assert_true(SaveGame.has_save(_save_path), "the fixture never saved")

	machine.retire()
	assert_false(SaveGame.has_save(_save_path),
		"a retired run was still sitting there to be resumed")


func test_an_ended_run_that_somehow_survived_still_says_so() -> void:
	# Belt and braces: the ending is part of the state, so even a save that
	# outlived the deletion reloads as finished rather than quietly continuing.
	var machine := _machine()
	machine.begin_turn()
	machine.retire()

	var restored := RunState.from_dict(machine.run.to_dict())
	assert_true(restored.ending.is_over(), "a reloaded retired run was open for business")
	assert_eq(String(restored.ending.reason), String(RunEnding.RETIRED))
	assert_almost_eq(restored.ending.score, machine.run.ending.score, 0.0001)


func test_the_post_cannot_be_sent_after_retiring() -> void:
	var machine := _machine()
	machine.begin_turn()
	machine.retire()
	assert_false(bool(machine.can_send()["ok"]), "an ended run was still sending post")
	assert_false(machine.send_post(), "an ended run sent its post")


# --- 🔒 Scored from the state at that moment --------------------------------

func test_the_score_is_the_one_he_was_standing_on() -> void:
	var machine := _machine()
	_received(machine.run, 0, 5_000.0)
	machine.begin_turn()
	machine.retire()
	assert_almost_eq(machine.run.ending.score,
		float(Prestige.of(machine.run.log)["total"]), 0.0001,
		"the run scored something other than the state it ended in")


func test_retiring_from_a_deteriorating_position_beats_carrying_on() -> void:
	# 🔒 **The whole reason the control exists** (SPEC §13.2). Two identical runs;
	# one leaves at the top, the other stays through two years of honouring
	# promises a failing colony cannot repay, and a town going out.
	var leaves := _machine()
	var stays := _machine(SEED + 1)
	for run in [leaves.run, stays.run]:
		for month in 24:
			_received(run, month, 400.0)

	leaves.begin_turn()
	leaves.retire()

	# The colony comes apart. Gold drains and the court hears about it.
	for month in range(24, 48):
		_paid(stays.run, month, 500.0)
	stays.run.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 30, {
		"town": "ashmere", "population": 40, "governor": "governor_ashmere",
	}, WorldPhase.COLONY_MONTH)
	stays.begin_turn()
	stays.retire()

	assert_true(leaves.run.ending.score > stays.run.ending.score,
		"hanging on through collapse scored at least as well as getting out, so the timing is not a decision")


func test_waiting_never_heals_the_black_marks() -> void:
	# The other half of §8: the reason to leave is never that waiting mends
	# anything. It is that waiting accrues new damage.
	var machine := _machine()
	machine.run.log.emit(Rebellion.EVENT_DECLARED, &"ashmere", 1, {
		"town": "ashmere", "population": 40, "governor": "governor_ashmere",
	}, WorldPhase.COLONY_MONTH)
	var owed := float(Prestige.of(machine.run.log)["optics_debt"])

	for month in range(2, 200):
		_received(machine.run, month, 10.0)
	machine.begin_turn()
	machine.retire()
	assert_almost_eq(machine.run.ending.optics_debt, owed, 0.0001,
		"sixteen years of quiet work talked the court out of a rebellion")


# --- The record --------------------------------------------------------------

func test_the_ending_is_on_the_record_without_the_figure() -> void:
	# 🔒 SPEC §14.1 keeps prestige off the player's screens, and that does not
	# stop being true because the run is over.
	var machine := _machine()
	_received(machine.run, 0, 9_000.0)
	machine.begin_turn()
	machine.retire()

	var ended: Array = machine.run.log.of_type(RunEnding.EVENT_ENDED)
	assert_eq(ended.size(), 1, "the run ended and the record says nothing")
	assert_eq(String(ended[0].payload["reason"]), String(RunEnding.RETIRED))
	assert_false(ended[0].payload.has("score"),
		"the payload carries the score, which a screen could render")
	assert_false(ended[0].payload.has("prestige"),
		"the payload carries the score, which a screen could render")
