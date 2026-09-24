extends TestCase

## Cutscene triggers: firsts, recurrences, and every one a turn earned (#298,
## `docs/mechanics/cutscenes.md` §2, §3, §4).
##
## 🔒 **As many as the month earned, in the order they happened.** No budget, no
## deferral, no expiry. A first fires once a run; a recurrence once a turn, and
## never in the turn its first did. Nothing here names a real catalog entry — the
## catalog is #299's and the Author's to cut — so the fixtures are triggers
## written here, over events emitted here.

const SEED: int = 2980

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


func _first(cutscene: String, event: String) -> Dictionary:
	return {"cutscene": cutscene, "kind": "first", "on": {"event_happened": {"event": event}}}


func _recurring(cutscene: String, event: String, after: String = "") -> Dictionary:
	return {"cutscene": cutscene, "kind": "recurring", "after": after,
		"on": {"event_happened": {"event": event}}}


## A month's events, in the order given.
func _month(types: Array) -> Array[SimEvent]:
	var log := EventLog.new()
	for type in types:
		log.emit(StringName(type), &"somewhere", 4, {})
	return log.all()


func _fired(triggers: Array, types: Array, seen: Dictionary = {}) -> PackedStringArray:
	return CutsceneTriggers.ids_of(CutsceneTriggers.fired(triggers, _month(types), seen))


# --- 🔒 Every one it earned, in order --------------------------------------------

func test_a_turn_that_triggered_four_plays_four_in_the_order_they_happened() -> void:
	var triggers := [
		_first("a_landfall", "town_founded"),
		_first("b_natives", "village_seen"),
		_first("c_works", "building_completed"),
		_first("d_refused", "order_refused"),
	]
	# The desk's own refusal is in the same log as the world's events (§2).
	var played := _fired(triggers,
		["order_refused", "building_completed", "town_founded", "village_seen"])
	assert_eq(played, PackedStringArray(["d_refused", "c_works", "a_landfall", "b_natives"]),
		"the turn's cutscenes were not shown in the order things happened")


func test_a_turn_that_triggered_none_plays_none() -> void:
	assert_empty(_fired([_first("a_landfall", "town_founded")], ["crown_purchase", "town_grew"]))


func test_a_first_fires_once_a_run() -> void:
	var triggers := [_first("a_landfall", "town_founded")]
	var seen: Dictionary = {}
	var due := CutsceneTriggers.fired(triggers, _month(["town_founded"]), seen)
	CutsceneTriggers.record(due, seen, 3)
	assert_eq(seen.get("a_landfall", -1), 3, "the first was not remembered against its turn")
	assert_empty(_fired(triggers, ["town_founded"], seen),
		"a first of the run fired a second time")


func test_a_first_fires_once_however_many_times_it_happened_that_month() -> void:
	assert_eq(_fired([_first("a_landfall", "town_founded")],
		["town_founded", "town_founded", "town_founded"]).size(), 1)


# --- 🔒 Recurrences ---------------------------------------------------------------

func test_a_recurrence_is_once_a_turn() -> void:
	# One protest painting, however many towns protest.
	var played := _fired([_recurring("protest", "trade_protest_declared")],
		["trade_protest_declared", "trade_protest_declared", "trade_protest_declared"])
	assert_eq(played, PackedStringArray(["protest"]))


func test_a_recurrence_never_fires_in_its_firsts_turn() -> void:
	# *The First Blood* and *Shots Exchanged* are the same event seen twice.
	var triggers := [
		_first("first_blood", "battle_fought"),
		_recurring("shots_exchanged", "battle_fought", "first_blood"),
	]
	var seen: Dictionary = {}
	var due := CutsceneTriggers.fired(triggers, _month(["battle_fought", "battle_fought"]), seen)
	assert_eq(CutsceneTriggers.ids_of(due), PackedStringArray(["first_blood"]),
		"the recurrence followed its own first in the same turn")
	CutsceneTriggers.record(due, seen, 2)

	assert_eq(_fired(triggers, ["battle_fought"], seen), PackedStringArray(["shots_exchanged"]),
		"after its first's turn the recurrence did not fire")


func test_only_the_kinds_named_fire_and_bookends_are_not_this() -> void:
	var triggers := [
		{"cutscene": "your_appointment", "kind": "bookend",
			"on": {"event_happened": {"event": "town_founded"}}},
		{"cutscene": "nonsense", "kind": "first", "on": {"no_such_condition": {}}},
	]
	assert_empty(_fired(triggers, ["town_founded"]),
		"a bookend or an unknown condition fired from the event log")


# --- 🔒 In the save, and the same every time ------------------------------------

func test_the_firsts_already_shown_survive_a_save() -> void:
	var run := RunState.new_run(SEED)
	run.cutscenes_seen = {"a_landfall": 1, "first_blood": 7}
	run.cutscenes_due = PackedStringArray(["first_blood"])
	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.cutscenes_seen, run.cutscenes_seen,
		"a reload forgot which firsts had been shown, so they would be painted again")
	assert_eq(restored.cutscenes_due, run.cutscenes_due)


func test_the_same_seed_earns_the_same_cutscenes_in_the_same_order() -> void:
	# Through the turn machine, which works them out as the month resolves.
	var first := _earned(SEED)
	assert_eq(first, _earned(SEED), "two identical runs earned different cutscenes")
	var any := false
	for turn in first:
		any = any or not (turn as PackedStringArray).is_empty()
	assert_true(any, "six months earned nothing, so this proves nothing")

	# And the machine remembers what it showed: a first of the run appears in one
	# turn at most, however often its event recurs.
	var turns_shown: Dictionary = {}
	for turn in first:
		for id in (turn as PackedStringArray):
			turns_shown[id] = int(turns_shown.get(id, 0)) + 1
	for id in ["new_arrivals", "the_first_works", "a_man_who_knows_his_trade"]:
		assert_true(int(turns_shown.get(id, 0)) <= 1,
			"'%s' was shown as a first in %d turns" % [id, turns_shown.get(id, 0)])


func _earned(seed_value: int) -> Array:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.cutscene_triggers = [
		_first("new_arrivals", "settlers_arrived"),
		_first("the_first_works", "building_completed"),
		_first("a_man_who_knows_his_trade", "expert_appeared"),
		_recurring("the_markets", "crown_purchase"),
	]
	var earned: Array = []
	for turn in 6:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()
		earned.append(run.cutscenes_due)
	return earned
