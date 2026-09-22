class_name MainMenuScreen
extends Control

## The title screen (#353, SPEC §15, §16.2, §16.1).
##
## §15 asks for four things: **start a new run, continue the run in progress,
## open options, see version info.** Until now `main.gd` booted straight into the
## game with a comment reading *"the main menu is M7"*.
##
## ## 🔒 Nothing starts or resumes on its own
##
## The first thing the player sees is a choice. A menu that auto-continued would
## make the one destructive option on the screen the only one he had to go
## looking for.
##
## ## 🔒 New Game destroys the run in progress, and says which one
##
## SPEC §16.2 locks one save per run and no loading of earlier states. So the run
## in progress **is** the only save there is, and starting another throws it
## away — the third irreversible act in the game after sending the post and
## retiring, and §15 locks that irreversible actions are confirmed.
##
## **It is confirmed in its own words, naming the colony and the year it
## reached.** A confirmation that reads like every other confirmation is one the
## player stops reading, and this one is throwing away nine years of somebody's
## colony.
##
## ## 🔒 Continue is absent, not greyed
##
## When there is no run, and when there is one that cannot be loaded. A greyed
## control is a promise that it might work; there is nothing here that could make
## it work.
##
## ## Version info has a job beyond the corner of the screen
##
## `CLAUDE.md`: during development a save from an older version is **refused, not
## migrated**, and nothing had anywhere to say so. **This screen is where that
## surfaces** — both versions, in plain words, with Continue absent rather than
## offering a load that will fail.

signal continued
signal new_game
signal options_opened
signal records_opened

const TITLE: String = "The Crown Sends Its Best"

## What the run in progress looks like from outside, refreshed on every draw.
var save: Dictionary = {}

var _column: VBoxContainer = null
var _confirming: Control = null


func begin() -> void:
	_build()


## Draw, or draw again after the save has changed under us.
func refresh() -> void:
	save = SaveGame.peek()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_confirming = null

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if save.is_empty():
		save = SaveGame.peek()

	var desk := ColorRect.new()
	desk.color = DeskTheme.DESK_WOOD
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, DeskTheme.GUTTER)
	add_child(margins)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", DeskTheme.GAP)
	margins.add_child(_column)

	var title := DeskTheme.label(TITLE, DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_column.add_child(DeskTheme.spacer(DeskTheme.GAP * 2))

	# 🔒 **A stale save is reported here**, because this is the only screen that
	# ever sees one — and it is reported before the buttons, so the player reads
	# why Continue is missing rather than wondering where it went.
	if int(save.get("result", SaveGame.Result.NO_SAVE)) == SaveGame.Result.WRONG_VERSION \
			or int(save.get("result", 0)) == SaveGame.Result.UNREADABLE:
		var trouble := DeskTheme.label(
			String(save.get("message", "")), DeskTheme.SIZE_LABEL, DeskTheme.SEAL)
		_column.add_child(trouble)
		_column.add_child(DeskTheme.spacer())

	if can_continue():
		var carry_on := DeskTheme.button("Continue — %s, year %d" % [
			_colony_name(), int(save.get("year", 1))])
		carry_on.pressed.connect(func() -> void: continued.emit())
		_column.add_child(carry_on)

	var fresh := DeskTheme.button("New game")
	fresh.pressed.connect(_on_new_game)
	_column.add_child(fresh)

	var hall := DeskTheme.button("Hall of records")
	hall.pressed.connect(func() -> void: records_opened.emit())
	_column.add_child(hall)

	var options := DeskTheme.button("Options")
	options.pressed.connect(func() -> void: options_opened.emit())
	_column.add_child(options)

	_column.add_child(DeskTheme.spacer())
	var version := DeskTheme.label(
		"Version %s  ·  saves v%d" % [Settings.game_version(), RunState.SAVE_VERSION],
		DeskTheme.SIZE_SMALL, DeskTheme.INK_FADED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(version)

	_focus_first()


## Whether there is a run this build can actually pick up.
##
## 🔒 **Loadable, not merely present.** A save from an older version is a file on
## disk and not a run in progress, and offering to continue it would be offering
## a load that fails.
func can_continue() -> bool:
	return int(save.get("result", SaveGame.Result.NO_SAVE)) == SaveGame.Result.OK


## Whether starting a new run would destroy something.
func would_destroy_a_run() -> bool:
	return int(save.get("result", SaveGame.Result.NO_SAVE)) != SaveGame.Result.NO_SAVE


## What the confirmation calls the thing being thrown away.
##
## The capital's name, or a plain description for a save too damaged to read one
## out of — which still has to be confirmed, because it is still a run.
func confirmation_text() -> String:
	if not would_destroy_a_run():
		return ""
	var colony := _colony_name()
	var year := int(save.get("year", 1))
	if colony.is_empty():
		return (
			"Beginning again destroys the run in progress. There is one save and "
			+ "no way back to it."
		)
	return (
		"%s is in its %s year. Beginning again destroys it — there is one save "
		+ "per run and no way back to it."
	) % [colony, _ordinal(year)]


func _colony_name() -> String:
	return String(save.get("colony", ""))


func _on_new_game() -> void:
	if not would_destroy_a_run():
		new_game.emit()
		return
	_confirm()


## The confirmation, in its own words (§15).
func _confirm() -> void:
	if _confirming != null:
		return

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))
	_confirming = panel

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", DeskTheme.GAP)
	panel.add_child(inner)

	inner.add_child(DeskTheme.label(confirmation_text(), DeskTheme.SIZE_BODY))

	var go_on := DeskTheme.button("Yes — begin a new colony")
	go_on.pressed.connect(func() -> void: new_game.emit())
	inner.add_child(go_on)

	var back := DeskTheme.button("No — keep the run in progress")
	back.pressed.connect(_dismiss)
	inner.add_child(back)

	_column.add_child(panel)
	if go_on.is_inside_tree():
		go_on.grab_focus()


func _dismiss() -> void:
	if _confirming == null:
		return
	_confirming.queue_free()
	_confirming = null
	_focus_first()


## Whether the confirmation is up, for a caller that wants to know.
func is_confirming() -> bool:
	return _confirming != null


## **Every screen works with touch and with mouse and keyboard** (SPEC §15), so
## the first control takes focus and Escape backs out of the confirmation.
func _focus_first() -> void:
	if _column == null:
		return
	for child in _column.get_children():
		if child is Button and (child as Button).is_inside_tree():
			(child as Button).grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _confirming != null:
		_dismiss()
		accept_event()


## An ordinal in words, because *its 9th year* on a title screen reads like a
## spreadsheet and this is the one place the game is being ceremonious.
static func _ordinal(year: int) -> String:
	const WORDS: PackedStringArray = [
		"first", "second", "third", "fourth", "fifth", "sixth", "seventh",
		"eighth", "ninth", "tenth", "eleventh", "twelfth",
	]
	if year >= 1 and year <= WORDS.size():
		return String(WORDS[year - 1])
	return "%dth" % year
