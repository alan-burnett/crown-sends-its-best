class_name DeskScreen
extends Control

## The main screen (#21, #23). The incoming letter stack and the outgoing post.
##
## **🔒 Only the desk has decisions.** The map, the ledger and cutscenes show
## information only, which is why they are slots here and nothing more.
##
## **Portrait-first.** The desk is visible in portrait before a letter is opened;
## on desktop the same column sits in more visible desk. Every control is
## tap-sized and keyboard-reachable (SPEC §15).
##
## **Leaving is a desk decision** (#77, SPEC §13.2). It sits with the post rather
## than in a menu, and it is confirmed like sending is — the two irreversible
## things on this desk, with their own wording each, because a confirmation that
## reads like every other confirmation is one the player stops reading.

var run: RunState = null
var machine: TurnMachine = null
var content: ContentDatabase = null
var composer: Composer = null

var _stack: VBoxContainer = null
var _post_box: VBoxContainer = null
var _heading: Label = null
var _send: Button = null
var _send_reason: Label = null
var _letter_view: LetterView = null
var _confirm: ConfirmationDialog = null
var _compose: Button = null
var _retire: Button = null
var _retire_confirm: ConfirmationDialog = null
var _ended: Label = null
var _margins: MarginContainer = null


func begin(p_run: RunState, p_machine: TurnMachine, p_content: ContentDatabase) -> void:
	run = p_run
	machine = p_machine
	content = p_content
	composer = Composer.new(content)
	_build()
	refresh()


# --- Building --------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var desk := ColorRect.new()
	desk.color = DeskTheme.DESK_WOOD
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	# A single column that fills the screen in portrait and sits centred in more
	# visible desk on a wide one. **Centring is done with margins, not a
	# CenterContainer**: that sizes to its child's minimum, which collapses the
	# letter stack to nothing and is exactly the bug this replaced.
	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", DeskTheme.GAP)
	_margins.add_child(inner)

	_heading = DeskTheme.label("", DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	inner.add_child(_heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)

	var scrolled := VBoxContainer.new()
	scrolled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolled.add_theme_constant_override("separation", DeskTheme.GAP)
	scroll.add_child(scrolled)

	scrolled.add_child(DeskTheme.label("The post", DeskTheme.SIZE_LABEL, DeskTheme.PAPER))
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", DeskTheme.GAP)
	scrolled.add_child(_stack)

	scrolled.add_child(DeskTheme.spacer())
	scrolled.add_child(DeskTheme.label("Ready to send", DeskTheme.SIZE_LABEL, DeskTheme.PAPER))
	_post_box = VBoxContainer.new()
	_post_box.add_theme_constant_override("separation", DeskTheme.GAP)
	scrolled.add_child(_post_box)

	_compose = DeskTheme.button("Write a letter")
	_compose.pressed.connect(_open_compose)
	inner.add_child(_compose)

	# **Look, do not touch.** Both of these show information and neither has a
	# decision on it; only the desk does (SPEC §7).
	var elsewhere := HBoxContainer.new()
	elsewhere.add_theme_constant_override("separation", DeskTheme.GAP)
	inner.add_child(elsewhere)

	var map_button := DeskTheme.button("Map")
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_button.pressed.connect(_open_map)
	elsewhere.add_child(map_button)

	var ledger := DeskTheme.button("Ledger")
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger.pressed.connect(_open_ledger)
	elsewhere.add_child(ledger)

	_send_reason = DeskTheme.label("", DeskTheme.SIZE_SMALL, DeskTheme.PAPER)
	inner.add_child(_send_reason)

	_send = DeskTheme.button("Send the post")
	_send.pressed.connect(_ask_to_send)
	inner.add_child(_send)

	# **Leaving is a desk decision** (#77, SPEC §13.2), so it sits with the desk
	# and not in a menu — but **beneath the post and on its own line**, not in the
	# row with the map and the ledger. Two reasons: those two are look-and-don't-
	# touch and this is the most irreversible decision in the game, and a third
	# button in that row wraps its own label at phone width and takes the row with
	# it. It is always available and almost never what the player came here to do.
	_retire = DeskTheme.button("Ask to be relieved of the colony")
	_retire.add_theme_font_size_override("font_size", DeskTheme.SIZE_SMALL)
	_retire.pressed.connect(_ask_to_retire)
	inner.add_child(_retire)

	# **🔒 Irreversible actions are confirmed** (SPEC §15).
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Send the post"
	_confirm.ok_button_text = "Send it"
	_confirm.cancel_button_text = "Not yet"
	_confirm.confirmed.connect(_send_the_post)
	_fits_a_phone(_confirm)
	add_child(_confirm)

	# **The other irreversible action on this desk**, and the more irreversible of
	# the two. Its own dialog rather than a shared one, so the wording can be its
	# own — a confirmation that reads like every other confirmation is a
	# confirmation the player stops reading.
	_retire_confirm = ConfirmationDialog.new()
	_retire_confirm.title = "Ask to be relieved"
	_retire_confirm.ok_button_text = "Write the letter"
	_retire_confirm.cancel_button_text = "Stay on"
	_retire_confirm.confirmed.connect(_retire_from_the_desk)
	_fits_a_phone(_retire_confirm)
	add_child(_retire_confirm)

	_ended = DeskTheme.label("", DeskTheme.SIZE_LABEL, DeskTheme.PAPER)
	_ended.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_ended)

	_apply_measure()


## Keep a dialog inside a portrait phone (SPEC §15).
##
## **A `ConfirmationDialog` sizes itself to its longest line**, which on a phone
## means a confirmation whose text runs off both edges — and the one screen that
## must be read before it is agreed to is the one screen that must not be cut
## off. Wrapping, and capped a gutter in from each side.
func _fits_a_phone(dialog: ConfirmationDialog) -> void:
	dialog.dialog_autowrap = true
	dialog.max_size = Vector2i(DeskTheme.LETTER_MEASURE, 0)


## Open the map over the desk, and put the desk back when it closes.
##
## **The outgoing post is not disturbed.** The map is laid over the desk rather
## than replacing it, so an answered letter waiting to go is still waiting when
## the player comes back.
func _open_map() -> void:
	var screen := MapScreen.new()
	add_child(screen)
	screen.begin(run.knowledge, refresh, run.colony)


## Open the Ledger over the desk, and put the desk back when it closes.
##
## **Read off the event log every time it is opened** rather than kept
## alongside it: a second running tally would be a second thing to keep in step,
## and the first month the two disagreed the player would be reading a lie about
## their own money.
func _open_ledger() -> void:
	var screen := LedgerScreen.new()
	add_child(screen)
	screen.begin(Ledger.of(run.log), refresh)


## Keep the letter column readable: full width on a phone, capped and centred on
## anything wider. **Text is the main medium**, and a line running the full width
## of a desktop window is harder to read, not easier.
func _apply_measure() -> void:
	if _margins == null:
		return
	var side: int = maxi(DeskTheme.GUTTER, int((size.x - float(DeskTheme.LETTER_MEASURE)) * 0.5))
	_margins.add_theme_constant_override("margin_left", side)
	_margins.add_theme_constant_override("margin_right", side)
	_margins.add_theme_constant_override("margin_top", DeskTheme.GUTTER)
	_margins.add_theme_constant_override("margin_bottom", DeskTheme.GUTTER)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_measure()


# --- The stack -------------------------------------------------------------

## Redraw the stack, the post, and whether the post may go.
func refresh() -> void:
	_heading.text = "Year %d, month %d" % [run.world.year_index(), run.world.month_of_year()]

	for child in _stack.get_children():
		child.queue_free()
	for inbound in run.inbox:
		_stack.add_child(_stack_entry(inbound))
	if run.inbox.is_empty():
		_stack.add_child(DeskTheme.label("No letters this month.", DeskTheme.SIZE_SMALL, DeskTheme.PAPER))

	for child in _post_box.get_children():
		child.queue_free()
	for outgoing in run.post.all():
		_post_box.add_child(_post_entry(outgoing))
	if run.post.is_empty():
		_post_box.add_child(DeskTheme.label("Nothing written yet.", DeskTheme.SIZE_SMALL, DeskTheme.PAPER))

	var permission := machine.can_send()
	_send.disabled = not bool(permission["ok"])
	# A send button that silently does nothing is worse than one that explains.
	_send_reason.text = String(permission["reason"])

	# 🔒 **An ended run does not become a desk again** (SPEC §16.2). The summary
	# and the epitaph are #78; until then the desk says plainly that it is over
	# and stops offering anything that would carry on.
	var over := machine.is_over()
	_retire.disabled = over
	# **Nothing that would carry the run on.** The post already refuses; writing a
	# letter nobody will ever send is worse than not offering to.
	_compose.disabled = over
	_send.disabled = _send.disabled or over
	_ended.visible = over
	if over:
		_ended.text = (
			"You asked to be relieved, in year %d. The desk is closed; what the court "
			+ "made of you is not yours to read."
		) % [run.world.year_index()]

	# 🔒 **The turn in progress is kept** (#464, SPEC §16.2). The desk is
	# redrawn after everything the player does to it — a letter answered or set
	# aside, one composed, the desk first opened — so it is saved as it changes.
	machine.save_now()


## **Handled letters are visibly distinct from unread**, by paper colour and by
## what the line says, not by colour alone.
func _stack_entry(inbound: InboundLetter) -> Control:
	var handled := inbound.is_handled()
	var button := DeskTheme.button("%s — %s%s" % [
		_sender_name(inbound.sender),
		_summary(inbound),
		"" if not handled else ("  (answered)" if inbound.status == InboundLetter.ANSWERED else "  (set aside)"),
	])
	button.add_theme_color_override("font_color", DeskTheme.INK)
	button.add_theme_stylebox_override("normal", DeskTheme.panel(
		DeskTheme.PAPER_HANDLED if handled else DeskTheme.PAPER
	))
	button.pressed.connect(func() -> void: _open_letter(inbound))
	return button


## Every outgoing letter can be **reopened and rewritten, or discarded
## entirely**, right up until the post is sent.
func _post_entry(outgoing: OutgoingLetter) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DeskTheme.GAP)

	var open := DeskTheme.button("To %s" % _sender_name(outgoing.addressed_to))
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.pressed.connect(func() -> void: _reopen(outgoing))
	row.add_child(open)

	var discard := DeskTheme.button("Discard")
	discard.pressed.connect(func() -> void:
		run.post.discard(outgoing.id)
		refresh())
	row.add_child(discard)

	return row


func _sender_name(id: StringName) -> String:
	var contact := run.contact(id)
	return contact.display_name if contact != null else String(id)


func _summary(inbound: InboundLetter) -> String:
	if not content.has_record("letters", inbound.letter_id):
		return inbound.letter_id
	return String(content.record("letters", inbound.letter_id).get(LetterSchema.KEY_TYPE, ""))


# --- Opening letters -------------------------------------------------------

func _open_letter(inbound: InboundLetter) -> void:
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
	var outgoing := run.post.reply_to(inbound.id)
	if outgoing == null:
		outgoing = OutgoingLetter.new(inbound.letter_id, inbound.sender)
		outgoing.in_reply_to = inbound.id
		outgoing.params = inbound.params.duplicate(true)

	var context := LetterContext.new(run.world, run.contact(inbound.sender), inbound.tone)
	context.diff = run.last_diff
	context.params = inbound.params
	context.measures = inbound.measures

	var wizard: ReplyWizard = null
	if letter.has_reply():
		wizard = ReplyWizard.new(letter, outgoing)

	_present(inbound, letter, context, wizard, outgoing)


func _reopen(outgoing: OutgoingLetter) -> void:
	var inbound := run.inbound(outgoing.in_reply_to)
	if inbound != null:
		_open_letter(inbound)
		return

	# An unprompted letter has no inbound to go back to, so it reopens on its own.
	var letter := Letter.from_record(content.record("letters", outgoing.letter_id))
	var context := LetterContext.new(run.world, run.contact(outgoing.addressed_to), outgoing.tone)
	context.params = outgoing.params
	var placeholder := InboundLetter.new(outgoing.letter_id, outgoing.addressed_to, outgoing.tone)
	_present(placeholder, letter, context, ReplyWizard.new(letter, outgoing), outgoing)


func _present(
	inbound: InboundLetter,
	letter: Letter,
	context: LetterContext,
	wizard: ReplyWizard,
	_outgoing: OutgoingLetter,
) -> void:
	if _letter_view != null:
		_letter_view.queue_free()

	_letter_view = LetterView.new()
	add_child(_letter_view)
	_letter_view.open(inbound, letter, context, wizard)

	_letter_view.answered.connect(func(written: OutgoingLetter) -> void:
		if run.post.letter(written.id) == null:
			run.post.add(written))
	_letter_view.closed.connect(func() -> void:
		_letter_view.queue_free()
		_letter_view = null
		refresh())


func _open_compose() -> void:
	var offered := composer.purposes(run)
	if offered.is_empty():
		return

	# **Purpose first, then recipient** (#19). With one purpose authored so far
	# this is a short menu; the shape is what matters.
	var menu := PopupMenu.new()
	add_child(menu)
	var pairs: Array = []
	for purpose in offered:
		for recipient in purpose["recipients"]:
			menu.add_item("%s — %s" % [purpose["purpose"], _sender_name(recipient)])
			pairs.append([purpose["letter_id"], recipient])
	menu.id_pressed.connect(func(index: int) -> void:
		var pair: Array = pairs[index]
		var wizard := composer.begin(run, String(pair[0]), StringName(pair[1]))
		menu.queue_free()
		if wizard != null:
			_reopen(wizard.outgoing))
	menu.popup_centered()


# --- Sending ---------------------------------------------------------------

func _ask_to_send() -> void:
	var permission := machine.can_send()
	if not bool(permission["ok"]):
		return
	_confirm.dialog_text = (
		"%d letter%s will go aboard, and cannot be called back.\n\nSend the post?"
		% [run.post.size(), "" if run.post.size() == 1 else "s"]
	)
	_confirm.popup_centered()


## Ask to be relieved. **Cancelling changes nothing at all** (SPEC §15).
##
## Available from any desk phase, including with letters unread and a post
## half-written — a man who has decided to go does not owe the Crown his
## correspondence first.
func _ask_to_retire() -> void:
	if machine.is_over():
		return
	_retire_confirm.dialog_text = (
		"You will write to the Crown asking to be relieved of the colony, and the "
		+ "post will carry it.

"
		+ "There is no coming back to this desk, and no later month in which to "
		+ "do better.

"
		+ "Ask to be relieved?"
	)
	_retire_confirm.popup_centered()


## 🔒 **The run ends here and the save is closed out.** Ironman means there is no
## coming back to it (SPEC §16.2).
func _retire_from_the_desk() -> void:
	if not machine.retire():
		return
	refresh()
	# 🔒 **The run ends on its own painting, then the summary** (#299).
	_show_the_cutscenes(0, _open_the_summary)


## The last screen of the run (#78), laid over the closed desk.
##
## **Reached from retirement now, and structured so M6's fail conditions plug in
## unchanged**: it reads the ending rather than being told which one it is.
func _open_the_summary() -> void:
	var screen := SummaryScreen.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	screen.begin(run, content)


## **Sending commits every decision in it and saves the game. There is no going
## back.** Cancelling changes nothing at all.
func _send_the_post() -> void:
	# Where the month about to be run begins in the log, so what it emitted is
	# exactly what the map plays back.
	var mark := run.log.next_seq()
	if not machine.send_post():
		refresh()
		return
	# 🔒 **A month that ended the run** goes straight to its ending's painting
	# and the summary (#299). There is no next turn to open.
	if machine.is_over():
		refresh()
		_show_the_cutscenes(0, _open_the_summary)
		return
	machine.begin_turn()
	refresh()
	_play_back_the_month(run.log.since(mark))


## 🔒 **The map plays back the month at the start of a turn** (#296,
## `beats.md` §6), over the desk, and hands the desk back when it closes.
##
## A month in which nothing the colony could see happened plays nothing, and the
## player goes straight to his post.
func _play_back_the_month(events: Array[SimEvent]) -> void:
	if machine.is_over():
		return
	if run.knowledge == null:
		_show_the_cutscenes()
		return
	var towns: Dictionary = {}
	for town in run.colony.in_order():
		towns[String((town as Town).id)] = (town as Town).at
	var villages: Dictionary = {}
	if run.tribes != null:
		for village in run.tribes.villages_in_order():
			villages[String(village.id)] = village.at
	var beats := MonthPlayback.select(events, run.log, run.knowledge, towns, villages)
	if beats.is_empty():
		_show_the_cutscenes()
		return
	var screen := MapScreen.new()
	add_child(screen)
	screen.begin(run.knowledge, _after_the_map, run.colony)
	screen.play(beats, get_node_or_null(^"/root/Assets") as AssetRegistry)


func _after_the_map() -> void:
	refresh()
	_show_the_cutscenes()


## 🔒 **Then the month's cutscenes, then the desk** (#298, `cutscenes.md` §4).
##
## Every one the month earned, one after another in the order it happened. The
## paintings are punctuation on the month rather than title cards for it: shown
## after the map, they are what the player is left holding when he sits down to
## his post. One whose panels have not been written yet is passed over.
##
## `then` is what follows — the desk by default, the summary when the run ended.
func _show_the_cutscenes(from: int = 0, then: Callable = Callable()) -> void:
	for index in range(from, run.cutscenes_due.size()):
		var due: Dictionary = run.cutscenes_due[index]
		var id := String(due.get("cutscene", ""))
		if content == null or not content.has_record(Cutscene.COLLECTION, id):
			continue
		var cutscene := Cutscene.from_data(content.record(Cutscene.COLLECTION, id))
		if cutscene.is_empty():
			continue
		var screen := CutsceneScreen.new()
		add_child(screen)
		screen.finished.connect(func() -> void:
			screen.queue_free()
			_show_the_cutscenes(index + 1, then))
		screen.values = due.get("params", {})
		screen.assets = get_node_or_null(^"/root/Assets") as AssetRegistry
		screen.sound = get_node_or_null(SoundEngine.AUTOLOAD_PATH) as SoundEngine
		screen.begin(cutscene, screen.assets)
		return
	refresh()
	if then.is_valid():
		then.call()
