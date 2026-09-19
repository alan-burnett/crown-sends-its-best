extends SceneTree

## Play a scripted run and print its state hash.
##
##     godot --headless --script res://tools/determinism.gd -- [seed] [turns]
##
## **Same seed plus the same decisions must produce an identical state hash**
## (SPEC §16.1). The in-process half of that is `tests/test_determinism.gd`;
## this is the across-processes half, which a test cannot do for itself. CI runs
## it twice and compares the two lines.
##
## The decisions are scripted rather than random, because "the same decisions"
## is half the claim.

const DEFAULT_SEED: int = 20_260_918
const DEFAULT_TURNS: int = 12


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var seed_value: int = int(arguments[0]) if arguments.size() > 0 else DEFAULT_SEED
	var turns: int = int(arguments[1]) if arguments.size() > 1 else DEFAULT_TURNS

	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()

	var content := ContentDatabase.new()
	if not content.load_all("en"):
		print(content.error_report())
		content.free()
		quit(2)
		return
	M1Registrations.load_resources(content)

	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	for turn in turns:
		machine.begin_turn()
		_decide(run, content, turn)
		machine.send_post()

	print("seed=%d turns=%d hash=%s" % [seed_value, turns, run.state_hash()])
	content.free()
	quit(0)


## The scripted decisions. Every third letter is answered with its first option,
## the rest are set aside — enough to exercise orders, compliance, promises and
## silence without any of it being a coin flip.
func _decide(run: RunState, content: ContentDatabase, turn: int) -> void:
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
