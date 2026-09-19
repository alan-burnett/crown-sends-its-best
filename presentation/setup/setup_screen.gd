class_name SetupScreen
extends Control

## The commission. Where a run is decided before it begins
## (#79, SPEC §5, §6.1, §15).
##
## **Portrait-first**, like the desk: one column that fills a phone and sits
## centred in more visible desk on a wide screen. Every control is tap-sized and
## keyboard-reachable.
##
## ## It reads as a document, not a form
##
## The whole game is paper, so this is the commission the PC is signing rather
## than a settings panel. Each decision is a line in it with the choices laid out
## beside, which is also what makes it work at phone width: a heading and a row
## of buttons stacks; a grid of labelled fields does not.
##
## ## The seed is shown, never hidden
##
## SPEC §16.1 locks seeded generation, so the seed is the run's name. A player
## who finds a colony he likes can write the number down and a player who wants
## a different one can ask for another — which costs nothing to offer and is the
## only way the guarantee is visible from inside the game.

signal begun(setup: RunSetup)

const MANDATE_NAMES: Dictionary = {
	GovernorIntent.ECONOMY: "Profit",
	GovernorIntent.DEFENCE: "A foothold",
	GovernorIntent.SETTLEMENT: "Settlement",
}

const MANDATE_NOTES: Dictionary = {
	GovernorIntent.ECONOMY: "The Crown wants a return, and wants it soon.",
	GovernorIntent.DEFENCE: "Hold the coast. Whatever else happens, hold it.",
	GovernorIntent.SETTLEMENT: "Put people in the ground and more towns after them.",
}

const SPLIT_NAMES: Dictionary = {
	RunSetup.SPLIT_PEOPLE: "In people",
	RunSetup.SPLIT_GOLD: "In gold",
	RunSetup.SPLIT_STORES: "In stores",
}

const SPLIT_NOTES: Dictionary = {
	RunSetup.SPLIT_PEOPLE: "More hands than the grant usually buys. They will want feeding.",
	RunSetup.SPLIT_GOLD: "Coin in the town's coffers, to buy what the ground will not give.",
	RunSetup.SPLIT_STORES: "Grain, timber and tools. The safe answer, and the dullest.",
}

const SITE_NAMES: Array[String] = ["The first landing", "The middle country", "The far shore"]

var setup: RunSetup = null

var _column: VBoxContainer = null
var _seed_label: Label = null
var _name_field: LineEdit = null
var _title_field: LineEdit = null
var _mandate_buttons: Array[Button] = []
var _split_buttons: Array[Button] = []
var _site_buttons: Array[Button] = []


func begin(p_setup: RunSetup) -> void:
	setup = p_setup
	_build()
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var desk := ColorRect.new()
	desk.color = DeskTheme.DESK_WOOD
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	# The same centring the desk uses: margins rather than a fixed width, so the
	# column fills a phone and is merely centred on a monitor.
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_right", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_top", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_bottom", DeskTheme.GUTTER)
	add_child(margins)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margins.add_child(scroll)

	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = DeskTheme.PAPER
	style.content_margin_left = DeskTheme.GUTTER
	style.content_margin_right = DeskTheme.GUTTER
	style.content_margin_top = DeskTheme.GUTTER
	style.content_margin_bottom = DeskTheme.GUTTER
	paper.add_theme_stylebox_override("panel", style)
	scroll.add_child(paper)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", DeskTheme.GAP)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_child(_column)

	_heading("YOUR COMMISSION")
	_note("His Majesty is pleased to appoint you. The particulars are yours to settle.")

	_rule()
	_heading("The appointment")
	_name_field = _field("Name", setup.pc_name)
	_title_field = _field("Style", setup.pc_title)

	_rule()
	_heading("The Crown's purpose")
	_note("What you are told the colony is for. Your first governor will believe it for a while.")
	_mandate_buttons = _choices(RunSetup.MANDATES, MANDATE_NAMES, MANDATE_NOTES, _on_mandate)

	_rule()
	_heading("The grant")
	_note("One grant. How you take it is your affair.")
	_split_buttons = _choices(RunSetup.SPLITS, SPLIT_NAMES, SPLIT_NOTES, _on_split)

	_rule()
	_heading("The ground")
	_note("Three charts came back from the survey. None of the surveyors agreed.")
	_site_buttons = _sites()

	_rule()
	_seed_label = _note("")
	var another := DeskTheme.button("Another chart")
	another.add_theme_color_override("font_color", DeskTheme.INK)
	another.add_theme_stylebox_override("normal", DeskTheme.panel(DeskTheme.PAPER_HANDLED))
	another.pressed.connect(_on_reseed)
	_column.add_child(another)

	_rule()
	var begin_button := DeskTheme.button("SIGN, AND SAIL")
	begin_button.add_theme_color_override("font_color", DeskTheme.PAPER)
	begin_button.add_theme_stylebox_override("normal", DeskTheme.panel(DeskTheme.SEAL))
	begin_button.add_theme_stylebox_override("hover", DeskTheme.panel(DeskTheme.SEAL))
	begin_button.pressed.connect(_on_begin)
	_column.add_child(begin_button)


# --- Pieces of the document -------------------------------------------------

func _heading(text: String) -> Label:
	var label := DeskTheme.label(text, DeskTheme.SIZE_HEADING, DeskTheme.INK)
	_column.add_child(label)
	return label


func _note(text: String) -> Label:
	var label := DeskTheme.label(text, DeskTheme.SIZE_SMALL, DeskTheme.INK_FADED)
	_column.add_child(label)
	return label


func _rule() -> void:
	var line := ColorRect.new()
	line.color = DeskTheme.INK_FADED
	line.custom_minimum_size.y = 1
	_column.add_child(line)


func _field(label_text: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", DeskTheme.INK_FADED)
	label.add_theme_font_size_override("font_size", DeskTheme.SIZE_LABEL)
	_column.add_child(label)

	var field := LineEdit.new()
	field.text = value
	field.custom_minimum_size.y = DeskTheme.TAP_HEIGHT
	# Written on the paper, not typed into a grey box. The desk's own controls
	# all sit on the page and a default-themed field would be the one thing on
	# this screen that looked like software.
	field.add_theme_color_override("font_color", DeskTheme.INK)
	field.add_theme_stylebox_override("normal", DeskTheme.panel(DeskTheme.PAPER_HANDLED))
	field.add_theme_stylebox_override("focus", DeskTheme.panel(DeskTheme.PAPER_HANDLED))
	_column.add_child(field)
	return field


## A row of choices, stacked so they read at phone width.
func _choices(ids: Array, names: Dictionary, notes: Dictionary, handler: Callable) -> Array[Button]:
	var made: Array[Button] = []
	for at in ids.size():
		var id: StringName = ids[at]
		var button := _choice("%s — %s" % [String(names.get(id, id)), String(notes.get(id, ""))])
		button.pressed.connect(handler.bind(at))
		made.append(button)
	return made


func _sites() -> Array[Button]:
	var made: Array[Button] = []
	var offered := RunSetup.sites_for(setup.seed_value)
	for at in offered.size():
		var button := _choice(_site_line(at, offered))
		button.pressed.connect(_on_site.bind(at))
		made.append(button)
	return made


## One option on the page.
##
## **Taken and untaken have to be unmistakable at a glance**, so the chosen one
## is inverted — ink with the words in paper — rather than a slightly different
## shade of the same cream. The first version made the selected option *lighter*
## than the rest, which put the one thing the player needed to see at the lowest
## contrast on the page.
func _choice(text: String) -> Button:
	var button := DeskTheme.button(text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.add_theme_color_override("font_color", DeskTheme.INK)
	button.add_theme_color_override("font_hover_color", DeskTheme.INK)
	button.add_theme_color_override("font_pressed_color", DeskTheme.PAPER)
	button.add_theme_color_override("font_hover_pressed_color", DeskTheme.PAPER)
	button.add_theme_color_override("font_focus_color", DeskTheme.INK)
	button.add_theme_stylebox_override("normal", DeskTheme.panel(DeskTheme.PAPER_HANDLED))
	button.add_theme_stylebox_override("hover", DeskTheme.panel(DeskTheme.PAPER_HANDLED))
	button.add_theme_stylebox_override("pressed", DeskTheme.panel(DeskTheme.INK))
	button.add_theme_stylebox_override("hover_pressed", DeskTheme.panel(DeskTheme.INK))
	_column.add_child(button)
	return button


func _site_line(at: int, offered: Array[Vector2i]) -> String:
	return "%s — %d leagues in, %d along the coast" % [
		SITE_NAMES[at] if at < SITE_NAMES.size() else "A fourth chart",
		offered[at].y, offered[at].x,
	]


# --- Choosing ---------------------------------------------------------------

func _on_mandate(at: int) -> void:
	setup.mandate = RunSetup.MANDATES[at]
	_refresh()


func _on_split(at: int) -> void:
	setup.split = RunSetup.SPLITS[at]
	_refresh()


func _on_site(at: int) -> void:
	setup.site_choice = at
	_refresh()


## A different world, and the charts with it.
##
## **The sites are a function of the seed**, so asking for another chart means
## asking for another world — which is honest about what a seed is rather than
## pretending the survey could have come back differently.
func _on_reseed() -> void:
	setup.seed_value = (setup.seed_value + 1) % 100_000_000
	var offered := RunSetup.sites_for(setup.seed_value)
	for at in _site_buttons.size():
		if at < offered.size():
			_site_buttons[at].text = _site_line(at, offered)
	setup.site_choice = 0
	_refresh()


func _on_begin() -> void:
	# Read the flavour at the last moment, so a player who is still typing when
	# he taps is not punished for it.
	setup.pc_name = _name_field.text.strip_edges()
	setup.pc_title = _title_field.text.strip_edges()
	if setup.pc_name.is_empty():
		setup.pc_name = "Ashcombe"
	begun.emit(setup)


func _refresh() -> void:
	# A toggled button shows the `pressed` stylebox, which is why taken and
	# untaken differ in colour rather than only in a border nobody sees.
	for at in _mandate_buttons.size():
		_mandate_buttons[at].button_pressed = setup.mandate == RunSetup.MANDATES[at]
	for at in _split_buttons.size():
		_split_buttons[at].button_pressed = setup.split == RunSetup.SPLITS[at]
	for at in _site_buttons.size():
		_site_buttons[at].button_pressed = setup.site_choice == at
	if _seed_label != null:
		_seed_label.text = "Chart no. %d. Write it down if you want this world again." \
			% setup.seed_value
