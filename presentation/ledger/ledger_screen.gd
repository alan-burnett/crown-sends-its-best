class_name LedgerScreen
extends Control

## **The one screen in the game that shows hard numbers** (SPEC §10.4).
##
## Every transaction of gold between the colony and the Crown, a page to a
## month, with the first page a graph of the whole run.
##
## ## Why the graph is first
##
## Crown standing is invisible and always will be. This is the compensating
## instrument: from it a player can derive the monthly net and watch the
## cumulative position accumulate. **The Ledger supplies the inputs and the
## letters supply the verdict**, and reading the gap between them is a real skill
## the game should reward.
##
## So **trend legibility is the point, not decoration**, and a worsening run has
## to be obvious at a glance on a phone.
##
## ## 🔒 Read-only, and Crown-side
##
## Only the desk has decisions (SPEC §7). The controls here turn pages and
## nothing else. A town's gold is hidden (SPEC §11.3) and `tools/lint.gd` fails
## if anything under `presentation/` names it.

## How tall the trend graph stands.
const GRAPH_HEIGHT: float = 200.0

## The widest a bar gets, so a short run does not render as slabs.
const MAX_BAR: float = 26.0

## Room for a figure, so the column lines up and never wraps.
const FIGURE_WIDTH: float = 84.0

var ledger: Ledger = null

## Which page is open. `-1` is the graph, which is the first page.
var _page: int = -1

var _graph: Control = null
var _sheet: VBoxContainer = null
var _heading: Label = null
var _summary: Label = null
var _back_page: Button = null
var _next_page: Button = null
var _closed: Callable = Callable()


func begin(p_ledger: Ledger, on_closed: Callable = Callable()) -> void:
	ledger = p_ledger
	_closed = on_closed
	_build()
	_show_page()


# --- Building ---------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backing := ColorRect.new()
	backing.color = DeskTheme.DESK_WOOD
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, DeskTheme.GUTTER)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DeskTheme.GAP)
	margins.add_child(column)

	_heading = DeskTheme.label("The Ledger", DeskTheme.SIZE_HEADING, DeskTheme.PAPER)
	column.add_child(_heading)

	_summary = DeskTheme.label("", DeskTheme.SIZE_SMALL, DeskTheme.PAPER_HANDLED)
	column.add_child(_summary)

	var paper := PanelContainer.new()
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", DeskTheme.panel(DeskTheme.PAPER))
	column.add_child(paper)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)

	_sheet = VBoxContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_constant_override("separation", DeskTheme.GAP)
	scroll.add_child(_sheet)

	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, GRAPH_HEIGHT)
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.draw.connect(_draw_trend)
	_sheet.add_child(_graph)

	var turning := HBoxContainer.new()
	turning.add_theme_constant_override("separation", DeskTheme.GAP)
	column.add_child(turning)

	_back_page = DeskTheme.button("Earlier")
	_back_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_page.pressed.connect(func() -> void: _turn(-1))
	turning.add_child(_back_page)

	_next_page = DeskTheme.button("Later")
	_next_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_page.pressed.connect(func() -> void: _turn(1))
	turning.add_child(_next_page)

	var back := DeskTheme.button("Back to the desk")
	back.pressed.connect(_close)
	column.add_child(back)

	focus_mode = Control.FOCUS_ALL
	grab_focus()


# --- Pages ------------------------------------------------------------------

## Pages in order: the graph, then a month at a time.
func _page_count() -> int:
	return 1 + ledger.months().size()


func _turn(by: int) -> void:
	var months := ledger.months()
	var index := clampi(_page + 1 + by, 0, maxi(0, _page_count() - 1))
	_page = index - 1
	if _page >= months.size():
		_page = months.size() - 1
	_show_page()


func _show_page() -> void:
	for child in _sheet.get_children():
		if child != _graph:
			child.queue_free()

	var months := ledger.months()
	_graph.visible = _page < 0
	_back_page.disabled = _page < 0
	_next_page.disabled = _page >= months.size() - 1

	if _page < 0:
		_heading.text = "The Ledger"
		_summary.text = "The run so far · %s" % _signed(ledger.net_position())
		_graph.queue_redraw()
		if ledger.is_empty():
			_sheet.add_child(_line("Nothing has been traded yet.", "", DeskTheme.INK_FADED))
			return

		# **Green and red need saying once.** A graph nobody can read is
		# decoration, and this screen exists to be read.
		_sheet.add_child(_line("Duty received", "", DeskTheme.LEDGER_IN))
		_sheet.add_child(_line("Honoured on your word", "", DeskTheme.LEDGER_OUT))
		_sheet.add_child(DeskTheme.spacer())

		# The same months the bars show, in figures, so the trend can be read
		# off either way round.
		for entry in ledger.trend():
			_sheet.add_child(_line(
				"Year %d, month %d" % [1 + int(int(entry["month"]) / 12.0), 1 + int(entry["month"]) % 12],
				"%+d" % int(roundf(float(entry["net"]))),
				DeskTheme.INK if float(entry["net"]) >= 0.0 else DeskTheme.SEAL,
			))
		return

	var month: int = months[_page]
	var page := ledger.page(month)
	_heading.text = "Year %d, month %d" % [1 + int(month / 12.0), 1 + month % 12]
	_summary.text = "In %d · out %d · %s" % [
		int(roundf(page.received())), int(roundf(page.paid())), _signed(page.net()),
	]

	for entry in page.entries:
		var colour := DeskTheme.INK if entry.direction == Ledger.IN else DeskTheme.SEAL
		var mark := "+" if entry.direction == Ledger.IN else "-"
		_sheet.add_child(_line(entry.description, mark + _figure(entry.amount), colour))

	if page.entries.is_empty():
		_sheet.add_child(_line("A quiet month. Nothing passed either way.", "", DeskTheme.INK_FADED))
	else:
		_sheet.add_child(_line("This month", _signed(page.net()), DeskTheme.INK))


func _line(what: String, amount: String, colour: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DeskTheme.GAP)

	var left := DeskTheme.label(what, DeskTheme.SIZE_LABEL, colour)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	# **A figure never wraps.** The labels autowrap so that prose reads on a
	# phone, which turned the amount column into one character per line — "+",
	# then "1", then "9" — the first time a three-figure sum appeared.
	var right := DeskTheme.label(amount, DeskTheme.SIZE_LABEL, colour)
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.custom_minimum_size = Vector2(FIGURE_WIDTH, 0)
	row.add_child(right)
	return row


## A sum, in figures a line can carry.
##
## **A duty under a gold keeps its decimal.** Rounding printed "+0" beside a
## transaction that really happened, which reads as a bug rather than as a small
## number.
static func _figure(amount: float) -> String:
	return "%.1f" % amount if amount < 1.0 else "%d" % int(roundf(amount))


static func _signed(amount: float) -> String:
	var whole := int(roundf(amount))
	return "%+d net" % whole


# --- The trend --------------------------------------------------------------

## Months across, in and out as paired bars, with the zero line drawn.
##
## **A worsening trend has to be obvious at a glance on a phone**, which is why
## in and out are separate bars in different colours rather than one net line:
## a net line hides whether a bad month was a collapse in trade or a spree.
func _draw_trend() -> void:
	var trend := ledger.trend()
	if trend.is_empty():
		return

	var width := _graph.size.x
	var height := _graph.size.y
	var middle := height * 0.5
	var most := maxf(1.0, ledger.busiest_month())
	var step := width / float(trend.size())
	var bar := minf(MAX_BAR, maxf(2.0, step * 0.36))

	_graph.draw_line(Vector2(0.0, middle), Vector2(width, middle), DeskTheme.INK_FADED, 1.0)

	for index in trend.size():
		var entry: Dictionary = trend[index]
		var centre := step * (float(index) + 0.5)

		var up := float(entry["in"]) / most * (middle - 4.0)
		_graph.draw_rect(
			Rect2(Vector2(centre - bar, middle - up), Vector2(bar, up)),
			DeskTheme.LEDGER_IN,
		)

		var down := float(entry["out"]) / most * (middle - 4.0)
		_graph.draw_rect(
			Rect2(Vector2(centre, middle), Vector2(bar, down)),
			DeskTheme.LEDGER_OUT,
		)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT: _turn(-1)
		KEY_RIGHT: _turn(1)
		KEY_ESCAPE: _close()
		_: return
	accept_event()


func _close() -> void:
	if _closed.is_valid():
		_closed.call()
	queue_free()
