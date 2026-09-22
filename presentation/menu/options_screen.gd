class_name OptionsScreen
extends Control

## Options (#353, SPEC §15).
##
## ## 🔒 There is no save management here, because there is nothing to manage
##
## §15 asks that *"the options and save-management screens share a single UI"*.
## Under Ironman (§16.2) there are no slots, no loading and no naming — **the
## only save operation that exists is discarding the run in progress by starting
## another**, and that belongs on the confirmation that does it rather than on a
## screen the player has to go and find.
##
## So this is options, and the New Game confirmation is the save management. If
## the Author wants §15's line amended that is his; nothing here depends on it.
##
## ## What goes in it beyond these is open
##
## §15 says *"we will add more to this"*. Sound and text size are what exist to
## set today; each is three lines here and three in `Settings`.
##
## ## 🔒 It takes effect as it is changed, and it is written when you leave
##
## A player dragging the text size wants to see the text change, not to press
## Apply and find out. The file is written on the way out, once, because a
## setting file rewritten on every pixel of a drag is a setting file that
## eventually gets written while the disk is busy.

signal closed

## How coarse each control is. Fine enough to find a size that suits, coarse
## enough to be draggable with a thumb.
const TEXT_STEP: float = 0.05
const VOLUME_STEP: float = 0.05

var sound: SoundEngine = null

var _sample: Label = null


func begin(p_sound: SoundEngine = null) -> void:
	sound = p_sound
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var desk := ColorRect.new()
	desk.color = DeskTheme.DESK_WOOD
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, DeskTheme.GUTTER)
	add_child(margins)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margins.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	scroll.add_child(column)

	var heading := DeskTheme.label("Options", DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_add_slider(column, "Text size", Settings.TEXT_SCALE_MIN, Settings.TEXT_SCALE_MAX,
		TEXT_STEP, Settings.text_scale(), _on_text_scale)

	# **A line at the size it will actually be**, so the control shows its own
	# effect rather than a number the player has to imagine.
	var sample := PanelContainer.new()
	sample.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))
	_sample = DeskTheme.label(
		"I have the honour to report that the harvest was thin again.",
		DeskTheme.SIZE_BODY)
	sample.add_child(_sample)
	column.add_child(sample)

	_add_slider(column, "Music", 0.0, 1.0, VOLUME_STEP,
		Settings.music_volume(), _on_music)
	_add_slider(column, "Sound", 0.0, 1.0, VOLUME_STEP,
		Settings.sound_volume(), _on_sound)

	column.add_child(DeskTheme.spacer())
	var back := DeskTheme.button("Back")
	back.pressed.connect(_leave)
	column.add_child(back)
	_focus(back)


## A labelled slider. **Focusable and keyboard-steppable**, because every screen
## works with touch and with mouse and keyboard (SPEC §15) and a slider that only
## answers a drag answers only one of the three.
func _add_slider(
	column: VBoxContainer,
	name: String,
	low: float,
	high: float,
	step: float,
	value: float,
	on_change: Callable,
) -> void:
	column.add_child(DeskTheme.label(name, DeskTheme.SIZE_LABEL, DeskTheme.PAPER))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, DeskTheme.scaled(DeskTheme.TAP_HEIGHT))
	slider.focus_mode = Control.FOCUS_ALL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	column.add_child(slider)


func _on_text_scale(value: float) -> void:
	Settings.set_text_scale(value)
	if _sample != null:
		_sample.add_theme_font_size_override(
			"font_size", DeskTheme.scaled(DeskTheme.SIZE_BODY))


func _on_music(value: float) -> void:
	Settings.set_music_volume(value)
	_apply_volumes()


func _on_sound(value: float) -> void:
	Settings.set_sound_volume(value)
	_apply_volumes()


## 🔒 **Volume is a bus, not a layer** (`beats.md` §2). Setting it here must not
## become a fourth thing that decides what is playing — the bed, the beats and
## the feedback each go on doing exactly what they did, more or less loudly.
func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _as_db(Settings.sound_volume()))


static func _as_db(level: float) -> float:
	return -80.0 if level <= 0.0 else linear_to_db(clampf(level, 0.0, 1.0))


## Written once, on the way out.
func _leave() -> void:
	Settings.save_settings()
	closed.emit()


## Focus the first control, **once it is actually on screen**.
##
## A caller that builds the screen before adding it, and a `--script` run that
## never processes a frame, both reach here with the button outside the tree —
## and focus is a courtesy to the keyboard player, never a thing worth an error
## for.
static func _focus(node: Button) -> void:
	if node != null and node.is_inside_tree():
		node.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		accept_event()
