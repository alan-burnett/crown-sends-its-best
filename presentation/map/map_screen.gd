class_name MapScreen
extends Control

## The known New World, to look at (#55, SPEC §15).
##
## ## 🔒 Read-only, and only what the colony knows
##
## **Only the desk has decisions** (SPEC §7), so nothing here changes anything.
## There is one control on the screen and it closes the screen.
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
## ## Static, not playback
##
## M2 needs the player to be able to look. Map playback arrives in M4, when
## expeditions and armies give it something worth watching.

## How large a tile is at rest, in pixels.
const TILE: float = 28.0

const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 3.5
const ZOOM_STEP: float = 1.15

## How far one press of an arrow key slides the map.
const KEY_PAN: float = 64.0

const REMEMBERED_DIM: float = 0.45

var knowledge: MapKnowledge = null

## What the player is looking at. Neither of these is game state.
var _zoom: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _dragging: bool = false

var _canvas: Control = null
var _caption: Label = null
var _closed: Callable = Callable()


## Show the map. `on_closed` is called when the player is done with it.
func begin(p_knowledge: MapKnowledge, on_closed: Callable = Callable()) -> void:
	knowledge = p_knowledge
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
