class_name RecordsScreen
extends Control

## The hall of records (#354, SPEC §14.3, §15).
##
## > *A hall of records of past runs and their epitaphs is part of the meta
## > layer.*
##
## A run ends, an epitaph is written, and until now nothing kept it. This is
## where past runs live, and **it is the only place meta-progression is
## visible** — a player who never sees his past runs has no way to know what he
## is playing toward.
##
## ## 🔒 A row is the colony, how it ended, the year, and the epitaph
##
## **No score.** `prestige.md` §10 flags that a long run almost always out-scores
## a short one, so a raw total invites the hall to be read as a high-score table
## and played for length. `Records` does not write the field; this could not show
## it if it wanted to.
##
## ## 🔒 Empty says so
##
## A first launch shows a sentence rather than a blank panel, because a screen
## that is empty and silent reads as broken rather than as new.

signal closed

const NOTHING_YET: String = (
	"No colony has yet been given up, lost or handed back. "
	+ "When one is, what became of it will be written here."
)

var content: ContentDatabase = null


func begin(p_content: ContentDatabase = null) -> void:
	content = p_content
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

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", DeskTheme.GAP)
	margins.add_child(frame)

	var heading := DeskTheme.label(
		"Hall of records", DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	scroll.add_child(column)

	var runs := Records.all()
	if runs.is_empty():
		var empty := DeskTheme.label(NOTHING_YET, DeskTheme.SIZE_BODY, DeskTheme.PAPER)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(empty)
	else:
		for entry in runs:
			column.add_child(_row(entry as Dictionary))

	var back := DeskTheme.button("Back")
	back.pressed.connect(_leave)
	frame.add_child(back)
	_focus(back)


## One run, on a leaf of paper.
func _row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", DeskTheme.GAP / 2)
	panel.add_child(lines)

	var colony := String(entry.get(Records.FIELD_COLONY, ""))
	lines.add_child(DeskTheme.label(
		colony if not colony.is_empty() else "A colony with no name left",
		DeskTheme.SIZE_BODY))

	lines.add_child(DeskTheme.label(
		"%s, in its %s year" % [
			Records.how_it_ended(entry),
			MainMenuScreen._ordinal(int(entry.get(Records.FIELD_YEAR, 1))),
		],
		DeskTheme.SIZE_LABEL, DeskTheme.INK_FADED))

	var epitaph := String(entry.get(Records.FIELD_EPITAPH, ""))
	if not epitaph.is_empty():
		lines.add_child(DeskTheme.spacer(DeskTheme.GAP / 2))
		lines.add_child(DeskTheme.label(epitaph, DeskTheme.SIZE_LABEL))
	return panel


func _leave() -> void:
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
