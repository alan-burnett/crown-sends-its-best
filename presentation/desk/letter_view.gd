class_name LetterView
extends Control

## Reading a letter and answering it (#22).
##
## **Where the game is won or lost.** SPEC §9.2 targets under a minute to read
## and answer a letter, so the reply is never more than a tap away from the text
## it answers, and the assembled letter is shown back before it joins the post.
##
## ## One layout, two option placements
##
## | | |
## | :--- | :--- |
## | **Mobile, portrait** | Options overlay the bottom of the screen, covering part of the letter |
## | **Desktop** | The same portrait-sized letter column, options beside it, more desk visible |
##
## **Both come from this one scene**, not two implementations: the same nodes are
## reparented between a vertical and a horizontal container when the viewport
## crosses the threshold. A second implementation would drift, and the phone one
## would lose.

signal answered(outgoing: OutgoingLetter)
signal set_aside(inbound: InboundLetter)
signal closed

var inbound: InboundLetter = null
var letter: Letter = null
var wizard: ReplyWizard = null
var context: LetterContext = null

var _renderer := LetterRenderer.new()
var _split: Container = null
var _reading: Control = null
var _options_panel: PanelContainer = null
var _body_label: RichTextLabel = null
var _options_box: VBoxContainer = null
var _reading_margins: MarginContainer = null
var _was_portrait: bool = true


func open(p_inbound: InboundLetter, p_letter: Letter, p_context: LetterContext, p_wizard: ReplyWizard) -> void:
	inbound = p_inbound
	letter = p_letter
	context = p_context
	wizard = p_wizard
	_build()
	_refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	# **`set_anchors_and_offsets_preset`, not `set_anchors_preset`.** The latter
	# recomputes the offsets to preserve the current rect, and the current rect of
	# a freshly created Control is zero — so the whole view stayed nought wide and
	# every label wrapped to one letter per line.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = DeskTheme.DESK_WOOD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Swapped between a column and a row on resize. The children never change,
	# because two implementations would drift and the phone one would lose.
	_split = VBoxContainer.new()
	_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_split.add_theme_constant_override("separation", 0)
	add_child(_split)

	_reading = _build_reading()
	_options_panel = _build_options()
	_split.add_child(_reading)
	_split.add_child(_options_panel)

	_apply_placement(true)


## The letter itself: who wrote, and what it says.
##
## **No CenterContainer anywhere.** It sizes to its child's minimum, which
## collapses a scrolling letter to a sliver — the measure is capped with computed
## margins instead.
func _build_reading() -> Control:
	_reading_margins = MarginContainer.new()
	_reading_margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reading_margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading_margins.add_child(paper)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	paper.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", DeskTheme.GAP)
	column.add_child(heading)

	# Tone and presentation cues — seal, handwriting, a smudge — are stubbed in
	# M1 and arrive through the asset layer (SPEC §9.1, §16.3).
	var seal := ColorRect.new()
	seal.color = DeskTheme.SEAL
	seal.custom_minimum_size = Vector2(26, 26)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(seal)

	var sender := DeskTheme.label(_sender_line(), DeskTheme.SIZE_HEADING)
	sender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(sender)

	# **Long letters scroll comfortably**, and the options never cover the text
	# being chosen because they sit outside this box rather than over it.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = false
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("normal_font_size", DeskTheme.SIZE_BODY)
	_body_label.add_theme_color_override("default_color", DeskTheme.INK)
	scroll.add_child(_body_label)

	return _reading_margins


func _build_options() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER_HANDLED, 0))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", DeskTheme.GAP)
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_options_box)

	return panel


## 🔒 **`<Role> <name>` and then a qualifier** (`names.md` §2), which is
## what `Letterhead` is for.
##
## This read `display_name` and `title` and rendered *Corvyn Thrale, Steward of
## the Revenue* — and `contact.gd` carries a lock two lines long saying **no
## letter reads `title` and the letterhead must not**, because the first word is
## the role and it is there to be **scanned**. An experienced player should know
## what came in without opening anything, and a stack of *Governor. Commander.
## Patron.* tells him the month where a stack of styles tells him nothing.
##
## `Letterhead.of` existed, was tested, and nothing in `presentation/` called it.
func _sender_line() -> String:
	if context.sender == null:
		return String(inbound.sender)
	var head := Letterhead.of(context.sender)
	return head if not head.is_empty() else context.sender.display_name


# --- Layout ----------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _split != null:
		_apply_placement(false)


## Move the same two panels between a column and a row.
func _apply_placement(force: bool) -> void:
	if _split == null or _options_panel == null:
		return

	var portrait := DeskTheme.is_portrait(size)
	if portrait != _was_portrait or force:
		_was_portrait = portrait
		var replacement: Container = VBoxContainer.new() if portrait else HBoxContainer.new()
		replacement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		replacement.add_theme_constant_override("separation", 0)

		_split.remove_child(_reading)
		_split.remove_child(_options_panel)
		_split.queue_free()
		_split = replacement
		add_child(_split)
		_split.add_child(_reading)
		_split.add_child(_options_panel)

	if portrait:
		# **Options overlay the bottom**, covering part of the letter. Capped so
		# they stay reachable one-handed and the letter is still readable above.
		_options_panel.custom_minimum_size = Vector2(0, clampf(size.y * 0.40, 200.0, 380.0))
		_options_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_options_panel.size_flags_vertical = Control.SIZE_FILL
		_reading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		# **The same portrait-sized letter column, options beside it.**
		_options_panel.custom_minimum_size = Vector2(clampf(size.x * 0.34, 280.0, 420.0), 0)
		_options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_options_panel.size_flags_horizontal = Control.SIZE_FILL
		_reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_measure(portrait)


## Cap the letter's measure, so it never runs the full width of a desktop.
func _apply_measure(portrait: bool) -> void:
	if _reading_margins == null:
		return
	var available: float = size.x if portrait else size.x - _options_panel.custom_minimum_size.x
	var side: int = maxi(DeskTheme.GUTTER, int((available - float(DeskTheme.LETTER_MEASURE)) * 0.5))
	_reading_margins.add_theme_constant_override("margin_left", side)
	_reading_margins.add_theme_constant_override("margin_right", side)
	_reading_margins.add_theme_constant_override("margin_top", DeskTheme.GUTTER)
	_reading_margins.add_theme_constant_override("margin_bottom", DeskTheme.GAP)


# --- The wizard ------------------------------------------------------------

func _refresh() -> void:
	_body_label.text = _renderer.render_body(letter, context)
	_show_step()


func _show_step() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	if wizard == null:
		_add_set_aside("Nothing is asked of you.")
		return

	if wizard.has_tone_step() and wizard.outgoing.tone.is_empty():
		_add_prompt(wizard.tone_prompt(context))
		for option in wizard.tone_options(context):
			var tone: StringName = option["tone"]
			_add_option(String(option["text"]), func() -> void:
				wizard.choose_tone(tone)
				_show_step())
		_add_set_aside("Set aside without replying")
		return

	var index := wizard.next_step_index()
	if index >= 0:
		_add_prompt(wizard.step_prompt(index, context))
		for option in wizard.options_for(index, context):
			var step_id := String(wizard.steps()[index].get("id", ""))
			var option_id := String(option["id"])
			_add_option(String(option["label"]), func() -> void:
				wizard.choose(step_id, option_id)
				_show_step())
		_add_set_aside("Set aside without replying")
		return

	_show_assembled()


## **The assembled reply is shown to the player before it joins the post.**
func _show_assembled() -> void:
	_add_prompt("You write:")

	var quoted := PanelContainer.new()
	quoted.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))
	_options_box.add_child(quoted)
	var written := DeskTheme.label(wizard.assemble(context), DeskTheme.SIZE_LABEL)
	quoted.add_child(written)

	var send := DeskTheme.button("Add to the post")
	send.pressed.connect(func() -> void:
		inbound.status = InboundLetter.ANSWERED
		answered.emit(wizard.outgoing)
		closed.emit())
	_options_box.add_child(send)
	send.grab_focus()

	var rewrite := DeskTheme.button("Write it again")
	rewrite.pressed.connect(func() -> void:
		wizard.outgoing.tone = &""
		wizard.outgoing.choices.clear()
		_show_step())
	_options_box.add_child(rewrite)


func _add_prompt(text: String) -> void:
	if text.is_empty():
		return
	_options_box.add_child(DeskTheme.label(text, DeskTheme.SIZE_LABEL, DeskTheme.INK_FADED))


func _add_option(text: String, on_press: Callable) -> void:
	var button := DeskTheme.button(text)
	button.pressed.connect(on_press)
	_options_box.add_child(button)
	if _options_box.get_child_count() == 2:
		button.call_deferred("grab_focus")


## **Choosing not to reply is always an option** (SPEC §9.3), so it is always on
## the screen rather than hidden behind a back gesture.
func _add_set_aside(text: String) -> void:
	_options_box.add_child(DeskTheme.spacer())
	var button := DeskTheme.button(text)
	button.pressed.connect(func() -> void:
		inbound.status = InboundLetter.SET_ASIDE
		set_aside.emit(inbound)
		closed.emit())
	_options_box.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		accept_event()
