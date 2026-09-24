class_name CutsceneScreen
extends Control

## A painting, a line, and advance (#297, `docs/mechanics/cutscenes.md` §1,
## SPEC §15, §6.1).
##
## ## 🔒 It does not animate, and it does not use the beat queue
##
## The map is the animated screen. This is the painting shown about it, and that
## is the whole of it — **no queue, no beats, no fast-forward**, because there is
## nothing running to get ahead of. It takes the bed (SPEC §15 gives it music)
## and a sound on each panel change.
##
## **This is not built on #293 and must not be.** A cutscene that animated would
## need everything the map needs, for a screen with no information on it. If this
## file ever imports a beat, something has been misunderstood.
##
## ## One path for one panel and for three
##
## Advance moves to the next panel, and off the last one. A single-panel
## cutscene is one where the first panel is also the last, so there is no
## special case — `Cutscene.is_last` answers both and the screen never compares
## counts itself.
##
## ## Portrait first, and every input
##
## One column: the painting at the top, the caption beneath it, and a single
## advance control that is tap-sized and focusable. **Touch, mouse and keyboard**
## (SPEC §15) — the button takes a tap or a click or `ui_accept`, and a click
## anywhere on the painting advances too, because a still image the player has
## finished with invites a tap wherever their thumb already is.
##
## The image is capped to the letter measure on anything wider than a phone, for
## the same reason the letter column is: the caption has to stay readable beside
## it, and a painting stretched across a desktop monitor with one line under it
## reads as a mistake.
##
## ## The art is a reference
##
## SPEC §16.3. A panel names `cutscene.arrival`; `AssetRegistry` says what that
## currently is; final art lands as a change to a data file. A missing one is the
## registry's obvious placeholder rather than an empty screen, because losing
## sight of where you are in a run to a typo in an art path is a poor trade.

## What the caption is allowed to be worth, as a share of the screen. The
## painting takes the rest, and the caption keeps its own room on a phone where
## three lines of text is a real amount of the page.
const CAPTION_SHARE: float = 0.28

## The sound a panel change makes (SPEC §15). An asset id, never a path.
##
## 🔒 **The bed is not here** (#294, `beats.md` §2). Music is a layer that
## survives moving between screens, so a cutscene *asks* for its bed and never
## owns a player for it — a screen that started and stopped its own music would
## cut the bed every time the player left it, which is the thing §2 says must
## not happen.
const PANEL_SOUND: String = "sound.cutscene_panel"

signal finished

var cutscene: Cutscene = null

## Where the registry is asked from. **Injected rather than looked up**, for the
## same reason `AssetRegistry.content_source` is: the `Assets` autoload only
## exists when the game boots normally, and a screenshot tool or a harness
## running under `--script` has no such identifier.
var assets: AssetRegistry = null

## The three layers (#294). Injected for the same reason, and **optional**: a
## cutscene with nowhere to send its sounds is a silent cutscene, not a broken
## one.
var sound: SoundEngine = null

var _at: int = 0

## The facts this showing's captions name (#299), from `RunState.cutscenes_due`.
var values: Dictionary = {}

var _painting: TextureRect = null
## 🔒 **Where a painting will go, until it is painted** (#299): its asset id
## in brackets, in the painting's own space, so the art can be dropped in by name.
var _unpainted: Label = null
var _caption: Label = null
var _advance: Button = null
var _counter: Label = null
var _sound: AudioStreamPlayer = null


## Show a cutscene. Emits `finished` when advance leaves the last panel.
##
## **An empty cutscene finishes immediately** rather than showing a blank page.
## §1 says a caption with no image is not a cutscene; a cutscene with no panels
## is not one either, and the player should not be made to dismiss it.
func begin(p_cutscene: Cutscene, p_assets: AssetRegistry = null) -> void:
	cutscene = p_cutscene
	assets = p_assets
	_at = 0
	_build()
	if cutscene == null or cutscene.is_empty():
		finished.emit()
		return
	_show_panel()
	if sound != null:
		sound.bed(SoundEngine.BED_CUTSCENE)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL

	# **Dark rather than the desk's wood.** A cutscene is not a thing on the
	# desk; it is the screen the desk is interrupted by, and the map's dark is
	# what the game already uses for "you are not at the desk".
	var backdrop := ColorRect.new()
	backdrop.color = DeskTheme.MAP_DARK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, DeskTheme.GUTTER)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	margins.add_child(column)

	_painting = TextureRect.new()
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_painting.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_painting.mouse_filter = Control.MOUSE_FILTER_STOP
	_painting.gui_input.connect(_on_painting_input)
	column.add_child(_painting)

	_unpainted = DeskTheme.label("", DeskTheme.SIZE_HEADING, DeskTheme.PAPER_HANDLED)
	_unpainted.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unpainted.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unpainted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unpainted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painting.add_child(_unpainted)

	_caption = DeskTheme.label("", DeskTheme.SIZE_BODY, DeskTheme.PAPER)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_caption)

	# **Which panel of how many**, and only when there is more than one. A
	# counter on a single-panel cutscene is a promise of more that never comes.
	_counter = DeskTheme.label("", DeskTheme.SIZE_SMALL, DeskTheme.MAP_STALE)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_counter)

	_advance = DeskTheme.button("")
	_advance.pressed.connect(advance)
	column.add_child(_advance)

	_sound = AudioStreamPlayer.new()
	add_child(_sound)


func _show_panel() -> void:
	if cutscene == null:
		return
	var image := cutscene.image_at(_at)
	var painted := _is_painted(image)
	_painting.texture = _texture(image) if painted else null
	_unpainted.text = "" if painted else "[%s]" % image
	_caption.text = cutscene.caption_at(_at, values)
	_counter.text = "" if cutscene.count() <= 1 \
		else "%d of %d" % [_at + 1, cutscene.count()]
	# **The last panel says it is the last.** A player who knows one more tap
	# ends this is a player who is reading rather than waiting.
	_advance.text = "Go on" if not cutscene.is_last(_at) else "Begin"
	# **Only once it is actually on screen.** A caller that builds the screen
	# before adding it, and a `--script` run that never processes a frame, both
	# reach here with the button outside the tree — and focus is a courtesy to
	# the keyboard player, never a thing worth an error for.
	if _advance.is_inside_tree():
		_advance.grab_focus()
	_apply_measure()


## Move to the next panel, or off the last one.
func advance() -> void:
	if cutscene == null or cutscene.is_empty():
		finished.emit()
		return
	if cutscene.is_last(_at):
		# 🔒 **The bed is not stopped here.** The next screen asks for its own
		# and it cross-fades; stopping it would cut the music every time a
		# cutscene ended (§2).
		finished.emit()
		return
	_at += 1
	_play(PANEL_SOUND)
	_show_panel()


## Which panel is showing. For the caller that resumes one, and for the harness.
func at() -> int:
	return _at


func _on_painting_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		advance()
		accept_event()


## 🔒 **Advance is the only input** (§1). Nothing here goes back, skips ahead or
## leaves early: the panels are the whole of what a cutscene can be asked to do,
## and a screen with a "skip" would be one the Author cannot rely on being seen.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance()
		accept_event()


## The painting, capped to the letter measure on anything wider than a phone.
func _apply_measure() -> void:
	if _painting == null:
		return
	var room := size if size.x > 0.0 else Vector2(DeskTheme.PORTRAIT_MAX_WIDTH, 0.0)
	var width := minf(room.x - float(DeskTheme.GUTTER * 2), float(DeskTheme.LETTER_MEASURE))
	_painting.custom_minimum_size = Vector2(
		maxf(0.0, width),
		maxf(0.0, room.y * (1.0 - CAPTION_SHARE)),
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_measure()


## Whether a painting exists for this id yet: registered, with a path, and the
## file there. Anything less shows the id in its place.
func _is_painted(id: String) -> bool:
	if assets == null or id.is_empty() or not assets.has(id):
		return false
	var path := assets.resolve(id)
	return not path.is_empty() and ResourceLoader.exists(path)


func _texture(id: String) -> Texture2D:
	if assets == null or id.is_empty():
		return null
	return assets.texture(id)


func _play(id: String) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	_sound.stream = stream
	_sound.play()


## **Silence rather than a placeholder.** A missing painting is worth shouting
## about because the screen is mostly painting; a missing sound is not, and the
## registry has already reported it once.
func _stream(id: String) -> AudioStream:
	if assets == null or not assets.has(id):
		return null
	return assets.resource(id) as AudioStream
