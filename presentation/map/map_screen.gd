class_name MapScreen
extends Control

## The known New World, to look at (#55, SPEC §15).
##
## ## 🔒 Read-only, and only what the colony knows
##
## **Only the desk has decisions** (SPEC §7), so nothing here changes anything.
## One control closes the screen; the only other, while a month plays back,
## skips to its end — which changes nothing either (#296).
##
## **The map shows what the colony knows** (SPEC §11.2), which is why this reads
## `MapKnowledge` and nothing else. `tools/lint.gd` fails if anything under
## `presentation/` so much as mentions `WorldMap`, `Territory` or
## `MapGenerator` — because the failure mode is not a crash, it is a map that
## quietly tells the truth about ground nobody has walked, and M5 puts tribes on
## that ground.
##
## Three states, visibly distinct:
##
## - **Unexplored** — nothing but the dark. Not a grey tile: no tile.
## - **Remembered** — drawn as last seen, dimmed and hatched, because it may be
##   out of date and the player should feel that.
## - **In sight** — full colour. What is shown is true this month.
##
## ## Playback (#296, `beats.md` §6)
##
## At the start of a turn the map plays back the month: the beats
## `MonthPlayback` chose, in the order they happened, each leaving a ring on its
## tile while the view eases to it. **The map underneath is already the
## month-end map** — every beat's outcome is only a mark on it — so skipping at
## any point settles the rest at once and lands on exactly the map watching to
## the end would have (§3). Opened from the desk's button it is a map to look at,
## with no playback at all.

## How large a tile is at rest, in pixels.
const TILE: float = 28.0

const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 3.5
const ZOOM_STEP: float = 1.15

## How far one press of an arrow key slides the map.
const KEY_PAN: float = 64.0

const REMEMBERED_DIM: float = 0.45

var knowledge: MapKnowledge = null

## 🔧 **A content-testing aid, not the design** (the Author, 2026-09-25): a text
## box under each of the colony's towns with its people, what it is building and
## what its governor intends, so letters can be checked against the towns they
## are about. The presentation pass replaces it.
##
## **It shows what the player is otherwise only told in letters**, a governor
## preparing for rebellion among it, so switch it off before anything ships.
const SHOWS_TOWN_DETAIL: bool = true
const DETAIL_FONT_SIZE: int = 12
const DETAIL_PAD: float = 4.0
const DETAIL_BACK: Color = Color(0.05, 0.05, 0.07, 0.82)

## The colony's towns, for the text boxes above. Null draws none.
var colony: Colony = null

## What the player is looking at. Neither of these is game state.
var _zoom: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _dragging: bool = false

var _canvas: Control = null
var _caption: Label = null
var _closed: Callable = Callable()

## The month being played back, and the rings its beats have left.
var _runner: BeatRunner = null
var _skip: Button = null
var _marks: Array[Beat] = []
var _showing: Beat = null
var _easing: Tween = null


## Play back a month's beats over the map (#296). Call after `begin`.
##
## An empty list plays nothing; the map is simply there to look at.
func play(beats: Array[Beat], assets: AssetRegistry = null) -> void:
	if beats.is_empty():
		return
	_runner = BeatRunner.new()
	_runner.assets = assets
	add_child(_runner)
	_runner.beat_shown.connect(_on_beat_shown)
	_runner.finished.connect(_on_played)
	if _skip != null:
		_skip.visible = true
	var queue := BeatQueue.new(self)
	queue.push_all(beats)
	_runner.play(queue)


## 🔒 **A map beat's outcome: a ring on its tile** (`MonthPlayback.SETTLES`).
##
## Called by the queue *before* the beat is shown, and all at once by a skip, so
## the rings are the same however the month was watched.
func mark_beat(beat: Beat) -> void:
	_marks.append(beat)
	_redraw()


func _on_beat_shown(beat: Beat) -> void:
	_showing = beat
	_ease_to(beat.place)
	_redraw()


## 🔒 **Watched or skipped, it ends on the same map**, framed on the colony.
func _on_played() -> void:
	_showing = null
	if _easing != null:
		_easing.kill()
	if _skip != null:
		_skip.visible = false
	_frame_the_colony()


func _skip_playback() -> void:
	if _runner != null:
		_runner.skip()


func _ease_to(at: Vector2i) -> void:
	if at == Beat.NOWHERE or size == Vector2.ZERO:
		return
	var goal := size * 0.5 - (Vector2(at) + Vector2(0.5, 0.5)) * TILE * _zoom
	if _easing != null:
		_easing.kill()
	_easing = create_tween()
	_easing.tween_method(_set_offset, _offset, goal, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_offset(to: Vector2) -> void:
	_offset = to
	_redraw()


## Show the map. `on_closed` is called when the player is done with it.
func begin(p_knowledge: MapKnowledge, on_closed: Callable = Callable(), p_colony: Colony = null) -> void:
	knowledge = p_knowledge
	colony = p_colony
	_closed = on_closed
	_build()
	_frame_the_colony()


# --- Building ---------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backing := ColorRect.new()
	backing.color = DeskTheme.MAP_DARK
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	# The tiles are drawn by hand rather than assembled as nodes: a map is a
	# picture, and a few thousand Controls to pan would cost more than it is
	# worth on a phone.
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_right", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_top", DeskTheme.GUTTER)
	margins.add_theme_constant_override("margin_bottom", DeskTheme.GUTTER)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(column)

	var heading := DeskTheme.label("The New World", DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)

	_caption = DeskTheme.label("", DeskTheme.SIZE_SMALL, DeskTheme.PAPER_HANDLED)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_caption)

	column.add_child(_spacer_that_grows())

	# **Skip settles; it never cancels** (`beats.md` §3). Only shown while a
	# month is playing back.
	_skip = DeskTheme.button("Skip")
	_skip.visible = false
	_skip.pressed.connect(_skip_playback)
	column.add_child(_skip)

	# **One control, and it leaves.** Nothing on this screen may change anything.
	var back := DeskTheme.button("Back to the desk")
	back.pressed.connect(_close)
	column.add_child(back)

	focus_mode = Control.FOCUS_ALL
	grab_focus()
	_describe()


func _spacer_that_grows() -> Control:
	var node := Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Open on what the colony has actually seen, rather than at the origin of a map
## most of which it has never visited.
func _frame_the_colony() -> void:
	var bounds := knowledge.bounds() if knowledge != null else {}
	if bounds.is_empty():
		return
	var from: Vector2i = bounds["from"]
	var to: Vector2i = bounds["to"]
	var middle := (Vector2(from) + Vector2(to) + Vector2.ONE) * 0.5
	_offset = size * 0.5 - middle * TILE * _zoom
	_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw_map() -> void:
	if knowledge == null:
		return
	var side := TILE * _zoom

	for at in knowledge.explored():
		var where := Vector2(at) * side + _offset
		var rect := Rect2(where, Vector2(side, side))
		var remembered := knowledge.state_of(at) == MapKnowledge.REMEMBERED

		var terrain := Terrain.find(knowledge.terrain_at(at))
		var colour := Color(terrain.colour) if terrain != null else DeskTheme.MAP_UNKNOWN
		if remembered:
			# **Dimmed because it may be out of date**, and the player should
			# feel the difference between what is known and what is remembered.
			colour = colour.darkened(REMEMBERED_DIM)
		_canvas.draw_rect(rect, colour)

		if knowledge.inside_border(at):
			_canvas.draw_rect(rect, DeskTheme.MAP_BORDER, false, maxf(1.0, side * 0.06))
		if not String(knowledge.worked_by(at)).is_empty():
			_canvas.draw_rect(
				Rect2(where + Vector2(side, side) * 0.38, Vector2(side, side) * 0.24),
				DeskTheme.MAP_WORKED,
			)

		# Ground a village works. Marked in the far corner from the town's mark,
		# so a tile carrying both shows both rather than one covering the other.
		if not knowledge.native_at(at).is_empty():
			_canvas.draw_rect(
				Rect2(where + Vector2(side * 0.66, side * 0.12), Vector2(side, side) * 0.2),
				DeskTheme.MAP_NATIVE,
			)

		# 🔒 **The contest, drawn and not resolved.** Both peoples want this tile
		# and nothing in the game says who gets it — so the map says so plainly
		# rather than quietly awarding it to one of them.
		# Somebody else's men, standing on the colony's own fields. Hatched
		# rather than filled: the ground is still the colony's, and it is the
		# working of it that has stopped.
		if not knowledge.denied_at(at).is_empty():
			_canvas.draw_line(where + Vector2(0.0, side), where + Vector2(side, 0.0),
				DeskTheme.MAP_DENIED, maxf(1.0, side * 0.14))

		if knowledge.is_contested(at):
			_canvas.draw_rect(rect, DeskTheme.MAP_CONTESTED, false, maxf(1.0, side * 0.08))

		var improvement := knowledge.improvement_at(at)
		if not String(improvement).is_empty():
			_canvas.draw_rect(
				Rect2(where + Vector2(side * 0.12, side * 0.12), Vector2(side, side) * 0.2),
				DeskTheme.MAP_IMPROVED,
			)

		if remembered:
			_canvas.draw_line(where, where + Vector2(side, side), DeskTheme.MAP_STALE, 1.0)

	for at in knowledge.towns:
		var centre := (Vector2(at) + Vector2(0.5, 0.5)) * side + _offset
		_canvas.draw_circle(centre, maxf(3.0, side * 0.3), DeskTheme.MAP_TOWN)

	if SHOWS_TOWN_DETAIL:
		_draw_town_details(side)

	# What happened this month (#296). A ring per beat, sized by how much it
	# mattered, and the one being shown brighter.
	for beat in _marks:
		var middle := (Vector2(beat.place) + Vector2(0.5, 0.5)) * side + _offset
		var now := beat == _showing
		_canvas.draw_arc(middle, side * lerpf(0.45, 0.8, beat.magnitude), 0.0, TAU, 24,
			DeskTheme.MAP_BEAT_NOW if now else DeskTheme.MAP_BEAT,
			maxf(1.5, side * (0.12 if now else 0.06)))

	# **A different shape, not a smaller circle.** There is nobody in a village
	# the PC could write to, and a marker that read as a settlement of his own
	# would be the map making a promise the correspondence cannot keep.
	for at in knowledge.villages:
		var corner := Vector2(at) * side + _offset
		var span := maxf(4.0, side * 0.58)
		var middle := corner + Vector2(side, side) * 0.5
		_canvas.draw_colored_polygon(PackedVector2Array([
			middle + Vector2(0.0, -span * 0.5),
			middle + Vector2(span * 0.5, span * 0.4),
			middle + Vector2(-span * 0.5, span * 0.4),
		]), DeskTheme.MAP_VILLAGE)


## 🔧 The content-testing text box under each known town (see `SHOWS_TOWN_DETAIL`).
## A fixed type size whatever the zoom, so it stays readable.
func _draw_town_details(side: float) -> void:
	if colony == null:
		return
	var font := ThemeDB.fallback_font
	var line_height := font.get_height(DETAIL_FONT_SIZE)
	var ascent := font.get_ascent(DETAIL_FONT_SIZE)
	for entry in colony.in_order():
		var town: Town = entry
		if not knowledge.towns.has(town.at):
			continue
		var lines := details_of(town)
		var width := 0.0
		for line in lines:
			width = maxf(width, font.get_string_size(
				line, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_FONT_SIZE).x)
		var box := Vector2(width, line_height * lines.size()) + Vector2(DETAIL_PAD, DETAIL_PAD) * 2.0
		var centre := (Vector2(town.at) + Vector2(0.5, 0.5)) * side + _offset
		var corner := Vector2(centre.x - box.x * 0.5, centre.y + maxf(3.0, side * 0.3) + 4.0)
		_canvas.draw_rect(Rect2(corner, box), DETAIL_BACK)
		for index in lines.size():
			var baseline := corner + Vector2(DETAIL_PAD, DETAIL_PAD + ascent + line_height * index)
			_canvas.draw_string(font, baseline, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
				DETAIL_FONT_SIZE, DeskTheme.PAPER)


## What the text box says about a town: its name and people, what it is
## building, and what its governor intends.
static func details_of(town: Town) -> PackedStringArray:
	var building := "nothing" if String(town.objective).is_empty() \
		else Objective.display_name(town.objective)
	var intent := "none" if String(town.intent).is_empty() \
		else Objective.intent_name(town.intent)
	return PackedStringArray([
		"%s · %s people" % [town.display_name, Figures.with_thousands(town.population())],
		"Building: %s" % building,
		"Intent: %s" % intent,
	])


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _describe() -> void:
	if _caption == null or knowledge == null:
		return
	var places: PackedStringArray = PackedStringArray()
	for at in knowledge.towns:
		places.append(String(knowledge.towns[at]))
	places.sort()
	var where := ", ".join(places) if not places.is_empty() else "nowhere yet"

	# Who else the colony has found. **Named only once somebody has seen them**,
	# because the map shows what the colony knows and nothing more.
	var peoples: Dictionary = {}
	for at in knowledge.villages:
		peoples[String(knowledge.villages[at])] = true
	var neighbours: PackedStringArray = PackedStringArray(peoples.keys())
	neighbours.sort()

	var line := "%d tiles known · %s" % [knowledge.seen.size(), where]
	if not neighbours.is_empty():
		line += " · neighbours: %s" % ", ".join(neighbours)
	_caption.text = line


# --- Looking about ----------------------------------------------------------
#
# **Touch and mouse and keyboard, from one implementation** (SPEC §15). Drag or
# swipe to pan, wheel or pinch to zoom, arrows and +/- for a keyboard.

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_click(event)
	elif event is InputEventMouseMotion and _dragging:
		_offset += (event as InputEventMouseMotion).relative
		_redraw()
		accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_on_key(event as InputEventKey)


func _on_click(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_about(event.position, ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_about(event.position, 1.0 / ZOOM_STEP)


func _on_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT: _pan(Vector2(KEY_PAN, 0.0))
		KEY_RIGHT: _pan(Vector2(-KEY_PAN, 0.0))
		KEY_UP: _pan(Vector2(0.0, KEY_PAN))
		KEY_DOWN: _pan(Vector2(0.0, -KEY_PAN))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _zoom_about(size * 0.5, ZOOM_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT: _zoom_about(size * 0.5, 1.0 / ZOOM_STEP)
		KEY_HOME: _frame_the_colony()
		KEY_SPACE, KEY_ENTER:
			if _skip == null or not _skip.visible:
				return
			_skip_playback()
		KEY_ESCAPE: _close()
		_: return
	accept_event()


func _pan(by: Vector2) -> void:
	_offset += by
	_redraw()


## Zoom about a point, so the tile under the finger stays under the finger.
func _zoom_about(at: Vector2, by: float) -> void:
	var was := _zoom
	_zoom = clampf(_zoom * by, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(was, _zoom):
		return
	_offset = at - (at - _offset) * (_zoom / was)
	_redraw()


func _close() -> void:
	if _closed.is_valid():
		_closed.call()
	queue_free()
