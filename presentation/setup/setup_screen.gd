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
	GovernorIntent.GET_RICH: "Profit",
	GovernorIntent.MILITARY: "A foothold",
	GovernorIntent.GO_WIDE: "Settlement",
}

const MANDATE_NOTES: Dictionary = {
	GovernorIntent.GET_RICH: "The Crown wants a return, and wants it soon.",
	GovernorIntent.MILITARY: "Hold the coast. Whatever else happens, hold it.",
	GovernorIntent.GO_WIDE: "Put people in the ground and more towns after them.",
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

## 🔒 **What the colony is for, not where it goes** (#273, `map.md` §4, §5).
##
## The player states a purpose and the map answers. He never sees the site and
## never approves it — showing him invites re-rolling until the chart looks
## pretty, which is choosing a tile by the back door.
const REQUEST_NAMES: Dictionary = {
	SiteRequest.QUICK_GROWTH: "Quick growth",
	SiteRequest.ECONOMIC_OPPORTUNITY: "Economic opportunity",
	SiteRequest.LONG_TERM_CULTIVATION: "Long-term cultivation",
	SiteRequest.DEFENSIVE_POSITION: "A defensible position",
}

## 🔒 **Who is over the next ridge, not how many there are** (#274, `map.md` §8).
const PROXIMITY_NAMES: Dictionary = {
	RunSetup.PROXIMITY_NEAR: "Settle close to them",
	RunSetup.PROXIMITY_APART: "Keep our distance",
}

const PROXIMITY_NOTES: Dictionary = {
	RunSetup.PROXIMITY_NEAR:
		"Trade within reach early, and their people may join yours. Your expansion offends sooner.",
	RunSetup.PROXIMITY_APART:
		"A ridge between us. Slower to know them, and slower to give offence.",
}

const REQUEST_NOTES: Dictionary = {
	SiteRequest.QUICK_GROWTH:
		"Put them on a shore with ships in it. What grows quickest also lies most open.",
	SiteRequest.ECONOMIC_OPPORTUNITY:
		"Timber and ore, and something to sell that is not grain.",
	SiteRequest.LONG_TERM_CULTIVATION:
		"Open country. Slow to start, and it does not stop.",
	SiteRequest.DEFENSIVE_POSITION:
		"High ground under the town. You will not be consulted about what surrounds it.",
}

var setup: RunSetup = null

## Where the perks and quirks are read from (#465). Null in a harness that has
## none, which offers the first-day perk and nothing else.
var content: ContentDatabase = null

var _column: VBoxContainer = null
var _seed_label: Label = null
var _name_field: LineEdit = null
var _title_field: LineEdit = null
var _complaint: Label = null
var _mandate_buttons: Array[Button] = []
var _split_buttons: Array[Button] = []
var _request_buttons: Array[Button] = []
var _proximity_buttons: Array[Button] = []
var _perks: PackedStringArray = PackedStringArray()
var _quirks: PackedStringArray = PackedStringArray()
var _perk_buttons: Array[Button] = []
var _quirk_buttons: Array[Button] = []
var _portrait_buttons: Array[Button] = []
var _colour_buttons: Array[Button] = []


func begin(p_setup: RunSetup, p_content: ContentDatabase = null) -> void:
	setup = p_setup
	content = p_content
	# 🔒 **Only what is unlocked** (#465, SPEC §5).
	var unlocks := Records.unlocks()
	_perks = RunModifiers.unlocked(content, RunModifiers.PERKS_RECORD, unlocks)
	if _perks.is_empty():
		_perks = PackedStringArray([String(RunSetup.PERK_FIRST_DAY)])
	_quirks = RunModifiers.unlocked(content, RunModifiers.QUIRKS_RECORD, unlocks)
	if not _perks.has(String(setup.perk)):
		setup.perk = StringName(_perks[0])
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
	# 🔒 **Both fields arrive filled in** (#358, `names.md` §1). The name is
	# drawn from the **aristocrats'** bag, which is the pool his patrons come from
	# and the right one for a minor royal.
	_name_field = _field("Name", setup.suggested_name())
	_name_field.max_length = RunSetup.NAME_MAX
	_title_field = _field("Style", setup.pc_title)
	_title_field.max_length = RunSetup.TITLE_MAX
	_complaint = _note("")
	_complaint.add_theme_color_override("font_color", DeskTheme.SEAL)
	_complaint.visible = false

	_rule()
	_heading("Your likeness")
	_note("How the court will remember you, and the colours your letters go under.")
	_portrait_buttons = _choices(
		RunSetup.PORTRAITS, _likenesses(), {}, _on_portrait)
	_colour_buttons = _swatches()

	_rule()
	_heading("What you bring")
	_note("One thing about you the court has noticed. More come with a name at court.")
	_perk_buttons = _choices(Array(_perks), _names_of(RunModifiers.PERKS_RECORD, _perks),
		_blurbs_of(RunModifiers.PERKS_RECORD, _perks), _on_perk)

	_rule()
	_heading("The world you are given")
	if _quirks.is_empty():
		_note("Nothing out of the ordinary, yet. Colonies of note come to those who have held one.")
	else:
		_note("Any, all or none. Each is a fact about the place, and cuts both ways.")
		_quirk_buttons = _choices(Array(_quirks), _names_of(RunModifiers.QUIRKS_RECORD, _quirks),
			_blurbs_of(RunModifiers.QUIRKS_RECORD, _quirks), _on_quirk)

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
	_note("Say what the place is for. The surveyors will find it; you will not be shown it.")
	_request_buttons = _choices(
		SiteRequest.ALL, REQUEST_NAMES, REQUEST_NOTES, _on_request)

	_rule()
	_heading("The neighbours")
	_note("There are people there already. How close do we settle to them?")
	_proximity_buttons = _choices(
		RunSetup.PROXIMITIES, PROXIMITY_NAMES, PROXIMITY_NOTES, _on_proximity)

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


## A perk's or quirk's name, by id, from the data.
func _names_of(record: String, ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for id in ids:
		out[StringName(id)] = String(RunModifiers.entry(content, record, id).get("name", id))
	return out


func _blurbs_of(record: String, ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for id in ids:
		out[StringName(id)] = String(RunModifiers.entry(content, record, id).get("blurb", ""))
	return out


## The likenesses, named for the page. The art is the asset's; these are its
## captions.
func _likenesses() -> Dictionary:
	var out: Dictionary = {}
	for at in RunSetup.PORTRAITS.size():
		out[StringName(RunSetup.PORTRAITS[at])] = "Likeness %s" % ["I", "II", "III", "IV", "V"][mini(at, 4)]
	return out


## One button per colour, filled with it.
func _swatches() -> Array[Button]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DeskTheme.GAP)
	_column.add_child(row)
	var made: Array[Button] = []
	for at in RunSetup.COLOURS.size():
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.custom_minimum_size = Vector2(DeskTheme.TAP_HEIGHT, DeskTheme.TAP_HEIGHT)
		swatch.tooltip_text = "Colour %d" % (at + 1)
		swatch.add_theme_stylebox_override("normal", DeskTheme.panel(RunSetup.COLOURS[at]))
		swatch.add_theme_stylebox_override("hover", DeskTheme.panel(RunSetup.COLOURS[at]))
		swatch.add_theme_stylebox_override("pressed", DeskTheme.panel(RunSetup.COLOURS[at].darkened(0.4)))
		swatch.pressed.connect(_on_colour.bind(at))
		row.add_child(swatch)
		made.append(swatch)
	return made


# --- Choosing ---------------------------------------------------------------

func _on_portrait(at: int) -> void:
	setup.portrait = RunSetup.PORTRAITS[at]
	_refresh()


func _on_colour(at: int) -> void:
	setup.colour = RunSetup.COLOURS[at]
	_refresh()


## 🔒 **One perk** (SPEC §5).
func _on_perk(at: int) -> void:
	setup.perk = StringName(_perks[at])
	_refresh()


## 🔒 **Any number of quirks** (SPEC §5): each toggles on its own.
func _on_quirk(at: int) -> void:
	var id := _quirks[at]
	var chosen := setup.quirks.duplicate()
	if chosen.has(id):
		chosen.remove_at(chosen.find(id))
	else:
		chosen.append(id)
	chosen.sort()
	setup.quirks = chosen
	_refresh()

func _on_mandate(at: int) -> void:
	setup.mandate = RunSetup.MANDATES[at]
	_refresh()


func _on_split(at: int) -> void:
	setup.split = RunSetup.SPLITS[at]
	_refresh()


func _on_request(at: int) -> void:
	setup.request = SiteRequest.ALL[at]
	_refresh()


func _on_proximity(at: int) -> void:
	setup.proximity = RunSetup.PROXIMITIES[at]
	_refresh()


## A different world.
##
## **The request is not a function of the seed**, so it survives a reseed — the
## player has said what he wants of a colony, and asking for another world does
## not change what he wants of it.
func _on_reseed() -> void:
	setup.seed_value = (setup.seed_value + 1) % 100_000_000
	_refresh()


func _on_begin() -> void:
	# Read the flavour at the last moment, so a player who is still typing when
	# he taps is not punished for it.
	var complaint := RunSetup.what_is_wrong_with(
		_title_field.text, _name_field.text)
	if not complaint.is_empty():
		# 🔒 **Refused, not quietly corrected.** The old code substituted
		# *Ashcombe* for an empty name, which meant a player who cleared the field
		# and tapped sailed as somebody else without being told. A field he typed
		# into is a field he meant.
		_complaint.text = complaint
		_complaint.visible = true
		return

	setup.pc_name = _name_field.text.strip_edges()
	setup.pc_title = _title_field.text.strip_edges()
	# And the name he sailed under is not a name a patron may also carry.
	setup.settle_the_name(setup.seed_value)
	begun.emit(setup)


func _refresh() -> void:
	# A toggled button shows the `pressed` stylebox, which is why taken and
	# untaken differ in colour rather than only in a border nobody sees.
	for at in _mandate_buttons.size():
		_mandate_buttons[at].button_pressed = setup.mandate == RunSetup.MANDATES[at]
	for at in _split_buttons.size():
		_split_buttons[at].button_pressed = setup.split == RunSetup.SPLITS[at]
	for at in _request_buttons.size():
		_request_buttons[at].button_pressed = setup.request == SiteRequest.ALL[at]
	for at in _proximity_buttons.size():
		_proximity_buttons[at].button_pressed = setup.proximity == RunSetup.PROXIMITIES[at]
	for at in _perk_buttons.size():
		_perk_buttons[at].button_pressed = String(setup.perk) == _perks[at]
	for at in _quirk_buttons.size():
		_quirk_buttons[at].button_pressed = setup.quirks.has(_quirks[at])
	for at in _portrait_buttons.size():
		_portrait_buttons[at].button_pressed = setup.portrait == RunSetup.PORTRAITS[at]
	for at in _colour_buttons.size():
		_colour_buttons[at].button_pressed = setup.colour.is_equal_approx(RunSetup.COLOURS[at])
	if _seed_label != null:
		_seed_label.text = "Chart no. %d. Write it down if you want this world again." \
			% setup.seed_value
