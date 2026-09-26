extends TestCase

## The turn in progress is kept (#464, SPEC §16.2, `CLAUDE.md` *Saving*).
##
## 🔒 *The player can quit at any time and continue later. A turn in progress,
## including its outgoing post, is kept.* A new run is saved as soon as its desk
## opens, and a turn with letters answered, set aside and composed but not sent
## comes back exactly as it was.

const SEED: int = 464
const PATH: String = "user://test_turn_is_kept.save"

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	SaveGame.delete_save(PATH)
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.save_path = PATH


func after_each() -> void:
	SaveGame.delete_save(PATH)
	reset_world()
	content.free()


func _loaded() -> RunState:
	var loaded := SaveGame.load_run(PATH)
	assert_eq(loaded["result"], SaveGame.Result.OK, String(loaded["message"]))
	return loaded["run"]


func test_a_new_run_is_saved_as_its_desk_opens() -> void:
	machine.begin_turn()
	assert_true(machine.save_now(), "a new run was not saved")
	var restored := _loaded()
	assert_eq(restored.state_hash(), run.state_hash(), "the new run did not come back as it was")
	assert_eq(restored.inbox.size(), run.inbox.size())


func test_a_turn_with_unsent_drafts_comes_back_as_it_was() -> void:
	machine.begin_turn()
	assert_true(run.inbox.size() >= 2, "too few letters this month to prove anything")
	run.inbox[0].status = InboundLetter.SET_ASIDE
	# A reply written to the second, and not sent.
	var inbound: InboundLetter = run.inbox[1]
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
	var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
	outgoing.in_reply_to = inbound.id
	outgoing.params = inbound.params.duplicate(true)
	outgoing.tone = Tone.ANNOYED
	for step in letter.steps():
		var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
		if not options.is_empty():
			outgoing.choose(String(step.get("id", "")), String(options[0].get("id", "")))
	run.post.add(outgoing)
	inbound.status = InboundLetter.ANSWERED
	machine.save_now()

	var restored := _loaded()
	assert_eq(restored.state_hash(), run.state_hash(), "the turn in progress did not come back as it was")
	assert_eq(restored.inbox[0].status, InboundLetter.SET_ASIDE)
	assert_eq(restored.inbox[1].status, InboundLetter.ANSWERED)
	assert_eq(restored.post.size(), 1, "the unsent reply was lost")
	assert_eq(restored.post.all()[0].choices, outgoing.choices, "the unsent reply lost its answers")
	assert_eq(restored.post.all()[0].tone, Tone.ANNOYED)


func test_an_ended_run_is_not_saved_again() -> void:
	machine.begin_turn()
	machine.retire()
	assert_false(machine.save_now(), "an ended run was saved again")
	assert_false(SaveGame.has_save(PATH), "the ended run's save survived")
