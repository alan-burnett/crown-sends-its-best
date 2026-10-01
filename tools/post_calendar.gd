extends SceneTree

## Play a run headless and print **which letter arrived from whom, on which
## turn**, one line each: the calendar of the post rather than its prose.
##
##     godot --headless --script res://tools/post_calendar.gd -- 24
##     godot --headless --script res://tools/post_calendar.gd -- 24 seed=7 silent role=governor
##
## For the #368 audit: reading when each contact's letters arrive, and how many
## land together, to see where the opening months crowd the desk.
##
## - `N`         turns to play (default 24)
## - `seed=S`    the run seed (default `tools/play.gd`'s)
## - `silent`    answer nothing, rather than the first option of every letter
## - `role=R`    print only this sender role's letters (counts still cover all)
##
## Like `play.gd`, answering the first option is a reading, not play. Nothing here
## is a test.

const DEFAULT_TURNS: int = 24
const DEFAULT_SEED: int = 20_260_918


func _init() -> void:
	var turns := DEFAULT_TURNS
	var seed := DEFAULT_SEED
	var silent := false
	var only_role := ""
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			turns = argument.to_int()
		elif argument.begins_with("seed="):
			seed = argument.trim_prefix("seed=").to_int()
		elif argument == "silent":
			silent = true
		elif argument.begins_with("role="):
			only_role = argument.trim_prefix("role=")

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

	var run := RunState.new_run(seed)
	ContactRoster.load_into(run, content)

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	print("seed %d, %d turns, %s" % [seed, turns, "silent" if silent else "answering the first option"])
	for turn in turns:
		machine.begin_turn()
		var shown: Array[String] = []
		for inbound in run.inbox:
			var contact := run.contact(inbound.sender)
			var role := String(contact.role) if contact != null else "?"
			if only_role.is_empty() or role == only_role:
				var letter := Letter.from_record(content.record("letters", inbound.letter_id))
				shown.append("    %-11s %-16s %-44s %s%s" % [
					role,
					contact.display_name.left(16) if contact != null else String(inbound.sender),
					inbound.letter_id,
					String(letter.type),
					"" if letter.skippable else "  (must answer)",
				])
			if not silent:
				_answer_first(inbound, run, content)
			else:
				inbound.status = InboundLetter.SET_ASIDE
		print("turn %2d  y%d m%02d  %d letters" % [
			run.turn + 1, run.world.year_index(), run.world.month_of_year(), run.inbox.size(),
		])
		for line in shown:
			print(line)
		machine.send_post()

	content.free()
	quit(0)


func _answer_first(inbound: InboundLetter, run: RunState, content: ContentDatabase) -> void:
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
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
	inbound.status = InboundLetter.ANSWERED
	run.post.add(outgoing)
