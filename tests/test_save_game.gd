extends TestCase

## Snapshot save/load, ironman, version stamp (#6).
##
## One of the few places `CLAUDE.md` makes tests mandatory. Ironman means a
## corrupt save is a lost run.

const SEED: int = 4815
const PATH: String = "user://test_run.save"


var content: ContentDatabase = null


func before_each() -> void:
	SaveGame.delete_save(PATH)
	reset_world()
	# A run carries a map, and a map needs its terrain, so the save test loads
	# the world it is going to round-trip.
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	SaveGame.delete_save(PATH)
	reset_world()
	content.free()


func _run_with_history() -> RunState:
	var run := RunState.new_run(SEED)
	run.add_contact(Contact.generate(
		&"marshal", Contact.ROLE_CROWN_OFFICER, run.streams, PackedStringArray(["revenue", "threat"])
	))
	run.contact(&"marshal").relationship.record_deed(Relationship.GRANTED)
	run.contact(&"marshal").relationship.add_promise("promise_1")
	run.contact(&"marshal").relationship.note_letter_sent(1)

	# An Intent mid-flight, with months still to run.
	run.intents.commit(Intent.new(
		&"", WorldValueExecutor.KIND, &"marshal", WorldValues.SUPPLY, 4, {"per_month": 3.0}
	), run.log, run.world.month)

	# Draw from a couple of streams so their state is somewhere non-initial.
	run.streams.stream("sim").randi()
	run.streams.stream("letters").randi()

	run.turn = 3
	return run


func test_a_round_trip_preserves_whole_numbers() -> void:
	# JSON has no integer type, so a save written as JSON turns every 4 into 4.0.
	# That changes the state hash without changing the state, and would make the
	# determinism test fail for a reason unrelated to determinism.
	var run := _run_with_history()
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]
	var intent := restored.intents.live()[0]
	assert_eq(typeof(intent.months_required), TYPE_INT)
	assert_eq(typeof(restored.log.all()[0].payload["months_required"]), TYPE_INT,
		"an int nested in an event payload has to survive too")


func test_save_and_reload_produces_an_identical_state_hash() -> void:
	var run := _run_with_history()
	var before := run.state_hash()

	assert_true(SaveGame.save(run, PATH))
	var loaded := SaveGame.load_run(PATH)

	assert_eq(loaded["result"], SaveGame.Result.OK, loaded["message"])
	assert_eq(loaded["run"].state_hash(), before)


func test_in_flight_intents_survive() -> void:
	var run := _run_with_history()
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	var intent := restored.intents.live()[0]
	assert_eq(intent.months_required, 4)
	assert_true(intent.is_live())
	assert_eq(intent.target, StringName(WorldValues.SUPPLY))


func test_rng_streams_survive_and_resume_mid_sequence() -> void:
	var run := _run_with_history()
	var expected: Array = []
	var reference := RngStreams.from_dict(run.streams.to_dict())
	for i in 5:
		expected.append(run.streams.stream("sim").randi())

	var replayed := RngStreams.from_dict(reference.to_dict())
	var actual: Array = []
	for i in 5:
		actual.append(replayed.stream("sim").randi())

	assert_eq(actual, expected, "a reloaded stream must not restart")


func test_relationship_and_promises_survive() -> void:
	var run := _run_with_history()
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	var relationship := restored.contact(&"marshal").relationship
	assert_eq(relationship.deed_count(Relationship.GRANTED), 1)
	assert_eq(relationship.outstanding_promises.size(), 1)
	assert_eq(relationship.months_silent(5), 4)


func test_a_mid_turn_save_restores_the_outgoing_post_exactly() -> void:
	# Suspend and resume: the player may quit at any time and continue later, and
	# a turn in progress including its outgoing post is kept (SPEC §16.2).
	var run := _run_with_history()
	run.phase = TurnMachine.DESK

	var finished := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	finished.tone = Tone.DUTIFUL
	finished.choose("grant", "full")
	finished.params = {"amount": 200, "resource": "iron"}
	run.post.add(finished)

	# A half-written letter is a normal state and has to survive too.
	var partial := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	partial.tone = Tone.ANNOYED
	run.post.add(partial)

	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DESPERATE)
	inbound.id = &"inbound_1"
	inbound.status = InboundLetter.SET_ASIDE
	run.inbox.append(inbound)

	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	assert_eq(restored.post.size(), 2)
	assert_eq(restored.phase, TurnMachine.DESK)
	assert_eq(restored.turn, 3)

	var restored_finished := restored.post.all()[0]
	assert_eq(restored_finished.tone, Tone.DUTIFUL)
	assert_eq(restored_finished.chosen_for("grant"), "full")
	assert_eq(restored_finished.params["amount"], 200)

	var restored_partial := restored.post.all()[1]
	assert_eq(restored_partial.tone, Tone.ANNOYED)
	assert_empty(restored_partial.choices, "a partially composed letter stays partial")

	assert_eq(restored.inbox.size(), 1)
	assert_eq(restored.inbox[0].status, InboundLetter.SET_ASIDE)


func test_an_older_save_is_refused_with_a_clear_message() -> void:
	# During development a stale save is refused rather than migrated.
	var run := _run_with_history()
	SaveGame.save(run, PATH)

	var reader := FileAccess.open(PATH, FileAccess.READ)
	var data: Dictionary = reader.get_var(false)
	reader.close()
	data["version"] = RunState.SAVE_VERSION - 1
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_var(data, false)
	file.close()

	var loaded := SaveGame.load_run(PATH)
	assert_eq(loaded["result"], SaveGame.Result.WRONG_VERSION)
	assert_true(loaded["run"] == null)
	assert_true(String(loaded["message"]).contains("cannot be continued"), loaded["message"])


func test_a_damaged_save_is_reported_not_crashed() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("this is not a save")
	file.close()

	var loaded := SaveGame.load_run(PATH)
	assert_eq(loaded["result"], SaveGame.Result.UNREADABLE)
	assert_true(loaded["run"] == null)


func test_no_save_is_its_own_answer() -> void:
	assert_eq(SaveGame.load_run(PATH)["result"], SaveGame.Result.NO_SAVE)
	assert_false(SaveGame.has_save(PATH))


func test_the_map_survives() -> void:
	var run := _run_with_history()
	assert_true(run.map.land_count() > 0, "the run has no map to save")
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]
	assert_eq(restored.map.map_hash(), run.map.map_hash())
	assert_eq(restored.starting_site, run.starting_site)


func test_the_event_log_survives() -> void:
	var run := _run_with_history()
	var before := run.log.to_dict()
	SaveGame.save(run, PATH)
	assert_eq(SaveGame.load_run(PATH)["run"].log.to_dict(), before)
