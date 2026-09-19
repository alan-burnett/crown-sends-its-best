extends TestCase

## Determinism and the save round trip (#25).
##
## The two places `CLAUDE.md` makes tests mandatory, stated at the level of a
## whole run rather than a single class. **These are in scope precisely because
## the values are stable and silent breakage is expensive** — a determinism bug
## does not crash, it quietly makes a seed stop reproducing, and is found much
## later by somebody trying to follow a bug report.
##
## Nothing here asserts a balance value. Every assertion is "the same inputs give
## the same output", which stays true however the game is tuned.

const SEED: int = 20_260_918
const TURNS: int = 8
const PATH: String = "user://test_determinism.save"

var content: ContentDatabase = null


func before_each() -> void:
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	ResourceCatalogue.reset()
	Terrain.reset()
	M1Registrations.register_all()
	SaveGame.delete_save(PATH)
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	SaveGame.delete_save(PATH)
	Deliberation.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	content.free()


## A run driven by scripted decisions, so "the same decisions" is really the same.
func _play(seed_value: int, turns: int = TURNS) -> RunState:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	for turn in turns:
		machine.begin_turn()
		var index := 0
		for inbound in run.inbox:
			index += 1
			var letter := Letter.from_record(content.record("letters", inbound.letter_id))
			if not letter.has_reply() or (index + turn) % 3 != 0:
				inbound.status = InboundLetter.SET_ASIDE
				continue
			var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
			outgoing.in_reply_to = inbound.id
			outgoing.params = inbound.params.duplicate(true)
			var wizard := ReplyWizard.new(letter, outgoing)
			if wizard.has_tone_step() and not wizard.tone_options().is_empty():
				wizard.choose_tone(wizard.tone_options()[0]["tone"])
			for step in letter.steps():
				var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
				if not options.is_empty():
					wizard.choose(String(step.get("id", "")), String(options[0].get("id", "")))
			run.post.add(outgoing)
			inbound.status = InboundLetter.ANSWERED
		machine.send_post()
	return run


# --- Determinism -----------------------------------------------------------

func test_the_same_seed_and_decisions_give_an_identical_state_hash() -> void:
	assert_eq(_play(SEED).state_hash(), _play(SEED).state_hash())


func test_a_different_seed_gives_a_different_run() -> void:
	assert_ne(_play(SEED).state_hash(), _play(SEED + 1).state_hash())


func test_the_whole_run_reproduces_not_only_its_ending() -> void:
	# A hash that matched only at the end could still have diverged and come back.
	var first := _play(SEED)
	var second := _play(SEED)
	assert_eq(first.log.to_dict(), second.log.to_dict(), "the event logs diverged")
	assert_eq(first.intents.to_dict(), second.intents.to_dict())
	assert_eq(first.promises.to_dict(), second.promises.to_dict())


func test_streams_stay_independent() -> void:
	# The acceptance criterion: adding a draw to one system must not change
	# another system's sequence. This is the throwaway draw.
	var baseline := RngStreams.new(SEED)
	var expected: Array = []
	for i in 12:
		expected.append(baseline.stream("sim").randi())

	var perturbed := RngStreams.new(SEED)
	for i in 5:
		perturbed.stream("letters").randi()
		perturbed.stream("mapgen").randf()
		perturbed.contact_stream("somebody_new").randi()
	var actual: Array = []
	for i in 12:
		actual.append(perturbed.stream("sim").randi())

	assert_eq(actual, expected, "a draw elsewhere moved the sim stream")


func test_a_contact_reproduces_whatever_else_happened() -> void:
	var alone := RngStreams.new(SEED)
	var expected: Array = []
	for i in 6:
		expected.append(alone.contact_stream("marshal").randi())

	var busy := RngStreams.new(SEED)
	busy.stream("sim").randi()
	busy.contact_stream("chancellor").randi()
	busy.contact_stream("steward").randi()
	var actual: Array = []
	for i in 6:
		actual.append(busy.contact_stream("marshal").randi())

	assert_eq(actual, expected)


func test_nothing_depends_on_dictionary_insertion_order() -> void:
	# GDScript dictionaries preserve insertion order, so a hash taken over raw
	# order would encode the order things happened to be built in.
	var forwards := WorldState.new(3, {"a": 1, "b": 2.5, "c": "three"})
	var backwards := WorldState.new(3, {"c": "three", "b": 2.5, "a": 1})
	assert_eq(forwards.state_hash(), backwards.state_hash())


func test_the_hash_distinguishes_a_whole_number_from_a_fraction() -> void:
	# 1 and 1.0 are different values, and a save that silently changed one into
	# the other would be a bug this hash has to be able to see.
	assert_ne(
		WorldState.new(0, {"x": 1}).state_hash(),
		WorldState.new(0, {"x": 1.0}).state_hash(),
	)


# --- The save round trip ---------------------------------------------------

func test_a_played_run_survives_save_and_reload() -> void:
	var run := _play(SEED)
	var before := run.state_hash()

	assert_true(SaveGame.save(run, PATH))
	var loaded := SaveGame.load_run(PATH)
	assert_eq(loaded["result"], SaveGame.Result.OK, loaded["message"])
	assert_eq(loaded["run"].state_hash(), before)


func test_a_reloaded_run_carries_on_identically() -> void:
	# The real test of a save: not that it looks the same, but that the run
	# continues the same way out of it.
	var original := _play(SEED, 4)
	SaveGame.save(original, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	_continue(original, 4)
	_continue(restored, 4)
	assert_eq(restored.state_hash(), original.state_hash())


func _continue(run: RunState, turns: int) -> void:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	for turn in turns:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()


func test_a_mid_turn_save_keeps_a_partially_composed_post() -> void:
	var run := _play(SEED, 3)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.begin_turn()

	var half_written := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	half_written.tone = Tone.ANNOYED
	half_written.params = {"amount": 140, "resource": "iron"}
	run.post.add(half_written)

	var before := run.state_hash()
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	assert_eq(restored.state_hash(), before)
	assert_eq(restored.post.size(), 1)
	assert_eq(restored.post.all()[0].tone, Tone.ANNOYED)
	assert_empty(restored.post.all()[0].choices, "it was only half written, and stays that way")
	assert_eq(restored.inbox.size(), run.inbox.size())


func test_everything_the_run_is_made_of_survives() -> void:
	var run := _play(SEED)
	SaveGame.save(run, PATH)
	var restored: RunState = SaveGame.load_run(PATH)["run"]

	assert_eq(restored.streams.to_dict(), run.streams.to_dict(), "RNG streams")
	assert_eq(restored.intents.to_dict(), run.intents.to_dict(), "in-flight Intents")
	assert_eq(restored.promises.to_dict(), run.promises.to_dict(), "promises")
	assert_eq(restored.letters_sent, run.letters_sent, "what has already been sent")
	for id in run.contact_ids():
		assert_eq(restored.contacts[id].to_dict(), run.contacts[id].to_dict(), id)
