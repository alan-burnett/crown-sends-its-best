class_name SummaryScreen
extends Control

## The last screen of a run (#78, SPEC §6.3, §14.2).
##
## ## 🔒 The same even voice for both fates
##
## SPEC §5 locks that nothing in the game can harm the PC, and that every ending
## — including the worst of them — sends him into comfort. This screen reports
## **what became of the colony and what became of the man in the same register**
## and does not comment on the distance between them. The gap is the point;
## pointing at it would spoil it.
##
## SPEC §3.2 is in force. The satire is at the expense of the empire, the court
## and the man. A colony ruined by the PC's misrule is not a joke at the
## colonists' expense, and nothing here is phrased as though it were.
##
## ## 🔒 Prestige is shown **here**, and nowhere during the run
##
## SPEC §14.1 keeps it off every screen while the run is alive — `tools/lint.gd`
## enforces that by keeping the `Prestige` class out of `presentation/` entirely.
## The figure reaches this screen on `RunEnding`, which is where the run's score
## was settled when it stopped (#77). That is the seam: **during the run there is
## no number to read; at the end there is nothing left to spend it on.**
##
## ## The recap reads the log
##
## Through `RunSummary`, the same reduction the Ledger makes over the same
## record. A tally kept alongside would be a second thing to keep in step, and
## the first time the two disagreed the player would be reading a lie about their
## own run — at the one moment there is no next month in which to notice.
##
## ## Portrait first
##
## One column, scrolled, capped to the letter measure on anything wider. The
## recap arrives **a line at a time**, which is the animation: this is a page of
## text and a page of text that appears all at once is a page nobody reads.

## How long between lines of the recap. Slow enough to read, quick enough that a
## player who has seen it before is not held hostage by it.
const LINE_SECONDS: float = 0.45

var run: RunState = null
var content: ContentDatabase = null

var _lines: VBoxContainer = null
var _pending: Array[Control] = []
var _timer: Timer = null
var _margins: MarginContainer = null


func begin(p_run: RunState, p_content: ContentDatabase) -> void:
	run = p_run
	content = p_content
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var desk := ColorRect.new()
	desk.color = DeskTheme.DESK_WOOD
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", DeskTheme.GAP)
	_margins.add_child(inner)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)

	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", DeskTheme.GAP)
	scroll.add_child(_lines)

	var show_it_all := DeskTheme.button("Show it all")
	show_it_all.pressed.connect(_show_everything)
	inner.add_child(show_it_all)

	_compose_the_page()
	_apply_measure()

	_timer = Timer.new()
	_timer.wait_time = LINE_SECONDS
	_timer.timeout.connect(_reveal_one)
	add_child(_timer)
	_timer.start()


## Everything the page will say, built up front and revealed a line at a time.
func _compose_the_page() -> void:
	var facts := RunSummary.of(run)

	_hold(DeskTheme.label(_opening(facts), DeskTheme.SIZE_HEADING, DeskTheme.PAPER))
	_hold(DeskTheme.spacer())

	_hold(_heading("The colony"))
	for line in _the_colony(facts):
		_hold(_body(line))
	_hold(DeskTheme.spacer())

	_hold(_heading("What the Crown got"))
	for line in _the_crown(facts):
		_hold(_body(line))
	_hold(DeskTheme.spacer())

	# 🔒 **The one screen the figure appears on.** It is stated flatly and not
	# celebrated: the court's arithmetic, reported in the court's own terms.
	_hold(_heading("The court's account of you"))
	_hold(_body("The court reckons you at %s. It reckons everybody at something, "
		% [_pounds(float(facts.get("score", 0.0)))]
		+ "and it has never found a second way of doing it."))
	_hold(_body("%s of that is what you netted them. %s of it is what it cost them "
		% [_pounds(float(facts.get("net_gold", 0.0))), _pounds(float(facts.get("optics_debt", 0.0)))]
		+ "to be embarrassed by you."))
	_hold(DeskTheme.spacer())

	_hold(_heading("And you"))
	_hold(_body(_epitaph()))


func _opening(facts: Dictionary) -> String:
	var years := int(facts.get("years", 0))
	match String(facts.get("reason", "")):
		String(RunEnding.TERM_EXPIRED):
			return "Fifty years, and the term is served."
		String(RunEnding.FAILED):
			return "The colony is lost, in its %s year." % [_ordinal(years + 1)]
		_:
			return "You asked to be relieved, in the %s year." % [_ordinal(years + 1)]


## What became of the place. **Stated, never judged.**
func _the_colony(facts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var towns := int(facts.get("towns", 0))
	var people := int(facts.get("people", 0))
	# "between them" of a single town is the kind of seam a player notices and a
	# test never will.
	out.append("%s, holding %s%s." % [
		_count(towns, "town"), _count(people, "soul"), "" if towns == 1 else " between them"])

	var settlers := int(facts.get("settlers", 0))
	if settlers > 0:
		out.append("%s crossed the ocean to come here in your time." % [_count(settlers, "settler")])

	var famines := int(facts.get("famines", 0))
	if famines > 0:
		out.append("%s died of hunger." % [_count(famines, "person", "people")])

	var protests := int(facts.get("protests", 0))
	if protests > 0:
		out.append("%s ended with a town refusing to trade in something."
			% [_count(protests, "dispute")])

	var rebellions := int(facts.get("rebellions", 0))
	if rebellions > 0:
		out.append("%s declared against the Crown. %s came back."
			% [_count(rebellions, "town"), _count(int(facts.get("returns", 0)), "town")])
	var out_now := int(facts.get("towns_in_revolt", 0))
	if out_now > 0:
		out.append("%s still out." % [_count(out_now, "town", "towns", "is", "are")])
	return out


func _the_crown(facts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("%s in duty, taken out of the colony's trade."
		% [_pounds(float(facts.get("received", 0.0)))])
	out.append("%s paid out on your word." % [_pounds(float(facts.get("paid", 0.0)))])
	out.append("%s served. %s of post."
		% [_count(int(facts.get("months", 0)), "month"),
			_count(int(facts.get("letters", 0)), "round")])
	return out


## What became of the man. **Never absent, whatever the outcome** — SPEC §5.
func _epitaph() -> String:
	var record := Epitaph.for_ending(run.ending, content)
	if record.is_empty():
		# Should be unreachable: the content validator requires every outcome and
		# band to resolve. Said plainly rather than shown blank, because a blank
		# last screen is the one bug nobody gets a second month to notice.
		return "You went home, and were comfortable, as such men are."
	return String(record.get("text", ""))


# --- Revealing ---------------------------------------------------------------

func _hold(node: Control) -> void:
	node.visible = false
	_lines.add_child(node)
	_pending.append(node)


func _reveal_one() -> void:
	while not _pending.is_empty():
		var node: Control = _pending.pop_front()
		node.visible = true
		# Spacers are not worth a beat of their own.
		if node is Label:
			return
	_timer.stop()


## **A page of text must be skippable** (SPEC §15). A player who has seen it
## before should not be held hostage by the pacing.
func _show_everything() -> void:
	while not _pending.is_empty():
		_pending.pop_front().visible = true
	_timer.stop()


# --- Bits --------------------------------------------------------------------

func _heading(text: String) -> Label:
	return DeskTheme.label(text, DeskTheme.SIZE_LABEL, DeskTheme.PAPER)


func _body(text: String) -> Label:
	var node := DeskTheme.label(text, DeskTheme.SIZE_BODY, DeskTheme.PAPER)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## "one town", "four towns" — **never "1 town"**, because this is prose.
func _count(
	amount: int,
	singular: String,
	plural: String = "",
	is_word: String = "",
	are_word: String = "",
) -> String:
	var many := plural if not plural.is_empty() else singular + "s"
	var word := singular if amount == 1 else many
	var verb := ""
	if not is_word.is_empty():
		verb = " " + (is_word if amount == 1 else are_word)
	var words: PackedStringArray = PackedStringArray([
		"No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
	])
	var number := words[amount] if amount >= 0 and amount < words.size() else str(amount)
	return "%s %s%s" % [number, word, verb]


func _pounds(amount: float) -> String:
	var rounded := int(roundf(absf(amount)))
	var text := "£%s" % [_grouped(rounded)]
	return "a loss of " + text if amount < 0.0 else text


func _grouped(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	var seen := 0
	for index in range(digits.length() - 1, -1, -1):
		out = digits[index] + out
		seen += 1
		if seen % 3 == 0 and index > 0:
			out = "," + out
	return out


func _ordinal(number: int) -> String:
	var words: PackedStringArray = PackedStringArray([
		"", "first", "second", "third", "fourth", "fifth", "sixth", "seventh",
		"eighth", "ninth", "tenth",
	])
	return words[number] if number > 0 and number < words.size() else "%dth" % [number]


func _apply_measure() -> void:
	if _margins == null:
		return
	var side: int = maxi(DeskTheme.GUTTER, int((size.x - float(DeskTheme.LETTER_MEASURE)) * 0.5))
	_margins.add_theme_constant_override("margin_left", side)
	_margins.add_theme_constant_override("margin_right", side)
	_margins.add_theme_constant_override("margin_top", DeskTheme.GUTTER)
	_margins.add_theme_constant_override("margin_bottom", DeskTheme.GUTTER)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_measure()
