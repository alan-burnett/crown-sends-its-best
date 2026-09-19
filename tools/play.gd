extends SceneTree

## Play a run headless and print the letters.
##
##     godot --headless --script res://tools/play.gd -- 12
##
## The Author's way to **read the correspondence** without a screen, and the
## quickest check that the whole pipeline hangs together: triggers fire, params
## are supplied, perception resolves, prose assembles, replies produce Orders,
## compliance resolves them, and the next month acknowledges it.
##
## It answers the first option of every letter it can, which is not play — it is
## a reading. Nothing here is a test; `tools/run_tests.gd` is.

const DEFAULT_TURNS: int = 12
const SEED: int = 20_260_918


func _init() -> void:
	var turns := DEFAULT_TURNS
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			turns = argument.to_int()

	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()

	var content := ContentDatabase.new()
	if not content.load_all("en"):
		print(content.error_report())
		content.free()
		quit(1)
		return

	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var renderer := LetterRenderer.new()

	for turn in turns:
		machine.begin_turn()
		print("\n================ Turn %d — year %d, month %d ================" % [
			run.turn + 1, run.world.year_index(), run.world.month_of_year(),
		])
		print("  the war %.0f · supply %.0f · revenue %.0f" % [
			run.world.get_value(StubWorld.WAR, 0.0),
			run.world.get_value(StubWorld.SUPPLY, 0.0),
			run.world.get_value(StubWorld.REVENUE, 0.0),
		])

		if run.inbox.is_empty():
			print("\n  (no letters)")

		for inbound in run.inbox:
			_read(inbound, run, content, renderer, machine)

		var permission := machine.can_send()
		if not bool(permission["ok"]):
			print("\n  cannot send: %s" % permission["reason"])
		machine.send_post()

	print("\n---- after %d turns ----" % turns)
	print("intents: %d live, %d resolved" % [run.intents.live().size(), run.intents.resolved().size()])
	print("promises: %d outstanding" % run.promises.outstanding().size())
	for id in run.contact_ids():
		print("  %-12s loyalty %5.1f" % [id, run.contacts[id].loyalty()])
	if not machine.director.unacknowledged.is_empty():
		print("unacknowledged outcomes: %s" % ", ".join(machine.director.unacknowledged))

	content.free()
	quit(0)


func _read(
	inbound: InboundLetter,
	run: RunState,
	content: ContentDatabase,
	renderer: LetterRenderer,
	_machine: TurnMachine,
) -> void:
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
	var contact := run.contact(inbound.sender)

	var context := LetterContext.new(run.world, contact, inbound.tone)
	context.diff = run.last_diff
	context.params = inbound.params
	context.measures = inbound.measures

	print("\n  --- from %s (%s) ---" % [contact.display_name, inbound.tone])
	print("  %s" % renderer.render_body(letter, context).replace("\n", "\n  "))

	if not letter.has_reply():
		inbound.status = InboundLetter.SET_ASIDE
		return

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

	print("  > %s" % wizard.assemble(context).replace("\n", "\n  > "))
	inbound.status = InboundLetter.ANSWERED
	run.post.add(outgoing)
