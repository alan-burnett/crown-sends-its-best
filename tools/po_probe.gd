extends SceneTree

## THROWAWAY. PO analysis probe — dumps the event log by month so cutscene
## triggers can be checked against a real run. Not project code; delete after.

const SEED: int = 20_260_918


func _init() -> void:
	var turns := 12
	var seed_value := SEED
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]).is_valid_int():
		turns = String(args[0]).to_int()
	if args.size() > 1 and String(args[1]).is_valid_int():
		seed_value = String(args[1]).to_int()

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
	M1Registrations.load_resources(content)

	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	for _turn in turns:
		machine.begin_turn()
		for inbound in run.inbox:
			_answer(inbound, run, content)
		machine.send_post()

	var WATCH := ["order_issued", "order_refused", "contact_acted_alone",
		"order_delayed", "intent_overtaken", "rival_parked_on_our_ground",
		"letter_dispatched", "colony_settled"]
	print("=== DETAIL, months 0-2 ===")
	for event in run.log.all():
		if event.month > 2:
			continue
		if not WATCH.has(String(event.type)):
			continue
		print("  m%d seq%-5d %-28s subject=%-14s %s" % [
			event.month, event.seq, String(event.type), String(event.subject),
			JSON.stringify(event.payload)])
	quit(0)


func _answer(inbound: InboundLetter, run: RunState, content: ContentDatabase) -> void:
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
	if not letter.has_reply():
		inbound.status = InboundLetter.SET_ASIDE
		return
	var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
	outgoing.in_reply_to = inbound.id
	outgoing.params = inbound.params.duplicate(true)
	var wizard := ReplyWizard.new(letter, outgoing)
	if wizard.has_tone_step() and not wizard.tone_options().is_empty():
		wizard.choose_tone(wizard.tone_options()[wizard.tone_options().size() - 1]["tone"])
	for step in letter.steps():
		var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
		if not options.is_empty():
			wizard.choose(String(step.get("id", "")), String(options[options.size() - 1].get("id", "")))
	inbound.status = InboundLetter.ANSWERED
	run.post.add(outgoing)
