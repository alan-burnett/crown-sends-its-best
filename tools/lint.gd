extends SceneTree

## Architectural lint.
##
##     godot --headless --script res://tools/lint.gd
##
## Two rules that later tickets depend on and that are cheap to check now and
## expensive to retrofit once hundreds of files exist:
##
## 1. **`sim/` references no Godot node type** (#1). The world sim is
##    deterministic and headless; the moment a node appears in it, it can no
##    longer run in a test or a balance harness.
## 2. **Nothing draws from the global RNG** (#2). Every random decision comes
##    from a named stream, so adding a die roll in one system cannot perturb
##    another's sequence. `randi()`, and also `Array.shuffle()` and
##    `pick_random()`, which quietly use the same global generator.
##
## It keeps **Crown standing** and **rebel sentiment** out of `presentation/`
## entirely — the two jaws of the Squeeze, neither of which is ever a number the
## player sees — because SPEC
## §10.3 makes the four bands the whole interface and a screen that can read the
## figure is a screen that will eventually print it.
##
## It also bans GDScript's built-in `hash()` in run-affecting code, because it is
## not documented as stable across engine versions or platforms and the game
## ships on desktop and mobile (SPEC §16.1).
##
## And it enforces SPEC §8.5's lock on what a letter can reach: **an order
## reaches the governor's intent, never the town's objective.** The PC cannot
## name the project, the tile or the month, and the check is here rather than in
## a review because the tempting version of that bug — a letter effect that sets
## `town.objective` directly — looks entirely reasonable in isolation.

const SIM_ROOT: String = "res://sim"
const PRESENTATION_ROOT: String = "res://presentation"
const SCAN_ROOTS: PackedStringArray = ["res://sim", "res://correspondence", "res://presentation", "res://core", "res://game"]

## Node types and node-only APIs. `sim/` may use RefCounted and plain data.
const NODE_PATTERNS: Array[Array] = [
	["\\bextends\\s+(Node|Node2D|Node3D|Control|CanvasItem|Window|Viewport|SceneTree|MainLoop)\\b", "extends a Godot node type"],
	["\\bget_tree\\s*\\(", "calls get_tree()"],
	["\\bget_node\\s*\\(", "calls get_node()"],
	["\\badd_child\\s*\\(", "calls add_child()"],
	["\\bqueue_free\\s*\\(", "calls queue_free()"],
	["@onready\\b", "uses @onready"],
	["\\$[A-Za-z_\"]", "uses $ node access"],
]

## `sim/` sits at the bottom of the stack and depends on nothing above it.
const LAYER_PATTERNS: Array[Array] = [
	["res://correspondence", "references the correspondence layer"],
	["res://presentation", "references the presentation layer"],
	["res://core", "references core infrastructure"],
]

## The bare forms are the global RNG. `rng.randf_range()` on a named stream is
## exactly what code *should* write, so these must not match a call that has a
## receiver — hence "not preceded by a dot" rather than a plain word boundary.
##
## `shuffle()` and `pick_random()` are the other way round: they are Array
## methods, always written with a receiver, and they draw from the global
## generator regardless.
const NO_RECEIVER: String = "(^|[^_a-zA-Z0-9.])"

const RNG_PATTERNS: Array[Array] = [
	[NO_RECEIVER + "randomize\\s*\\(", "calls randomize()"],
	[NO_RECEIVER + "randi\\s*\\(", "calls randi()"],
	[NO_RECEIVER + "randf\\s*\\(", "calls randf()"],
	[NO_RECEIVER + "randi_range\\s*\\(", "calls randi_range()"],
	[NO_RECEIVER + "randf_range\\s*\\(", "calls randf_range()"],
	[NO_RECEIVER + "rand_from_seed\\s*\\(", "calls rand_from_seed()"],
	["\\.shuffle\\s*\\(", "calls shuffle(), which uses the global RNG"],
	["\\.pick_random\\s*\\(", "calls pick_random(), which uses the global RNG"],
]

const HASH_PATTERN: String = "(^|[^_a-zA-Z0-9.])hash\\s*\\("

## **A town's gold is invisible to the player** (SPEC §11.3), and the player's own
## gold is not a wallet (§10.2). Neither is a number on the desk, so nothing in
## `presentation/` may reach the town's balance — by the field, by the accessors,
## or by digging it out of the serialised form.
##
## The Ledger shows Crown-side transactions, which is a different thing and has
## its own screen (#51).
## **A town's gold is invisible to the player** (SPEC §11.3), and the player's own
## gold is not a wallet (§10.2). Neither is a number on the desk, so nothing in
## `presentation/` may reach a town's balance — by the field, by the accessors, or
## by digging it out of the serialised form.
##
## The Ledger shows Crown-side transactions, which is a different thing and has
## its own screen (#51).
##
## Plain substrings rather than patterns: the question is whether presentation
## mentions these at all, and a substring answers it without anybody having to
## reason about escaping.
const TOWN_GOLD_NAMES: Array[Array] = [
	["_gold", "reads a town's hidden gold"],
	["receive_gold", "moves a town's hidden gold"],
	["spend_gold", "moves a town's hidden gold"],
	["can_afford", "asks after a town's hidden gold"],
]

## **🔒 The map only shows what the colony knows** (SPEC §11.2).
## Presentation reads `MapKnowledge`, never the real map — otherwise the first
## debug overlay leaks every rival's position the moment M5 puts them on it.
## 🔒 SPEC §8.5. Writing any of these outside `sim/` is naming a project or a
## tile on the PC's behalf.
##
## `urged_intent` is deliberately absent: that one **is** the letter's business,
## and it is what the PC argues about instead.
## **Writes, not mentions.** A governor's letter has every right to *read* how
## far along the work is — that is what a letter about the work is — and the
## first version of this rule banned the words outright and flagged the very
## condition that asks whether a project has started yet. The second banned
## `objective_progress =` by substring and flagged `objective_progress ==`.
##
## What SPEC §8.5 forbids is the PC reaching the objective, so what is matched is
## assignment to a member, and nothing else.
const OBJECTIVE_WRITES: Array[Array] = [
	["\\.objective\\s*=[^=]", "sets a town's objective"],
	["\\.objective_target\\s*=[^=]", "names the tile for a town's objective"],
	["\\.objective_progress\\s*(=[^=]|\\+=)", "moves a town's objective along"],
	["\\.objective_intent\\s*=[^=]", "decides what a town's objective serves"],
	["\\.objective_invested\\s*(=[^=]|\\[)", "moves what a town has put into its objective"],
	["\\.clear_objective\\s*\\(", "cancels a town's objective"],
]

## 🔒 SPEC §10.3, `docs/mechanics/crown-standing.md` §5. **Standing is never
## displayed as a number anywhere**, and the four bands are the entire
## interface.
##
## The Ledger is the compensating instrument and is untouched by this: the
## player may see every transaction and derive the monthly net. What they may
## not see is the Crown's judgement of it.
const STANDING_NAMES: Array[Array] = [
	["CrownStanding", "reads the Crown's judgement of the player"],
	["crown_standing", "reads the Crown's judgement of the player"],
	[".standing", "reads the Crown's judgement of the player"],
]

## 🔒 SPEC §12.3, `docs/mechanics/rebel-sentiment.md` §6. **Sentiment is never a
## number the player sees.** It surfaces three ways and no others: the Diplomat
## reports on it through his own perception ladders, the governor's tone shifts
## and he begins dropping hints, and his loyalty visibly slips in compliance.
##
## The same rule as crown standing and for the same reason. The two are the jaws
## of the Squeeze, and a player who could read either figure would be playing a
## spreadsheet rather than reading his post.
const SENTIMENT_NAMES: Array[Array] = [
	["RebelSentiment", "reads how close a town is to rebellion"],
	["rebel_sentiment", "reads how close a town is to rebellion"],
	["Grievances", "reads what a town holds against the Crown"],
]

const MAP_TRUTH_NAMES: Array[Array] = [
	["WorldMap", "reads the real map instead of MapKnowledge"],
	["MapGenerator", "reaches into map generation"],
	["Territory", "reads territory directly instead of MapKnowledge"],
]

## Seam A and Seam B. Only the sim writes sim state, and inside the sim that
## means a phase or an executor consuming an Intent (#4). An effect handler or a
## UI path that reached `apply()` would be writing the world directly, which is
## exactly what "Orders are never writes" forbids.
const APPLY_PATTERN: String = "\\.apply\\s*\\("

## Files allowed to hold the thing they are the exception for.
const RNG_EXEMPT: PackedStringArray = ["res://sim/rng/rng_streams.gd"]
const HASH_EXEMPT: PackedStringArray = ["res://sim/rng/stable_hash.gd"]

var _violations: PackedStringArray = PackedStringArray()


func _init() -> void:
	for root in SCAN_ROOTS:
		for path in _gd_files(root):
			_check(path)

	if _violations.is_empty():
		print("lint: clean")
		quit(0)
		return

	print("lint: %d violation(s)" % _violations.size())
	for violation in _violations:
		print("  %s" % violation)
	quit(1)


func _check(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return
	var lines := source.split("\n")
	var in_sim := path.begins_with(SIM_ROOT)
	var in_presentation := path.begins_with(PRESENTATION_ROOT)

	for index in lines.size():
		var line := _strip(lines[index])
		if line.strip_edges().is_empty():
			continue

		if in_sim:
			for rule in NODE_PATTERNS:
				_match(path, index, line, rule[0], "sim/ %s" % rule[1])
			for rule in LAYER_PATTERNS:
				if line.contains(rule[0]):
					_report(path, index, "sim/ %s" % rule[1])

		if not RNG_EXEMPT.has(path):
			for rule in RNG_PATTERNS:
				_match(path, index, line, rule[0], rule[1])

		if not in_sim:
			_match(path, index, line, APPLY_PATTERN, "calls apply() outside sim/ — only the sim writes sim state (Seam A, Seam B)")
			for rule in OBJECTIVE_WRITES:
				_match(path, index, line, rule[0],
					"%s from outside sim/ (SPEC 8.5: an order reaches the governor's intent, never the town's objective)" % rule[1])

		if in_presentation:
			for rule in TOWN_GOLD_NAMES:
				if line.contains(rule[0]):
					_report(path, index, "presentation/ %s (SPEC 11.3: it is invisible to the player)" % rule[1])
			for rule in MAP_TRUTH_NAMES:
				if line.contains(rule[0]):
					_report(path, index, "presentation/ %s (SPEC 11.2 is locked)" % rule[1])
			for rule in STANDING_NAMES:
				if line.contains(rule[0]):
					_report(path, index, "presentation/ %s (SPEC 10.3: it is never a number the player sees)" % rule[1])
			for rule in SENTIMENT_NAMES:
				if line.contains(rule[0]):
					_report(path, index, "presentation/ %s (SPEC 12.3: it is never a number the player sees)" % rule[1])

		if not HASH_EXEMPT.has(path):
			_match(path, index, line, HASH_PATTERN, "calls the built-in hash(), which is not stable across versions or platforms — use StableHash")


func _match(path: String, index: int, line: String, pattern: String, message: String) -> void:
	var regex := RegEx.new()
	regex.compile(pattern)
	if regex.search(line) != null:
		_report(path, index, message)


func _report(path: String, index: int, message: String) -> void:
	_violations.append("%s:%d  %s" % [path, index + 1, message])


## Remove string literals and trailing comments, so a rule name inside a doc
## comment or an error message does not trip the lint that names it.
static func _strip(line: String) -> String:
	var out := ""
	var index := 0
	var quote := ""
	while index < line.length():
		var character := line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
			index += 1
			continue
		if character == "#":
			break
		out += character
		index += 1
	return out


func _gd_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(root, found)
	found.sort()
	return found


func _walk(dir_path: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var directories: PackedStringArray = PackedStringArray()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			directories.append(full_path)
		elif entry.ends_with(".gd"):
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	directories.sort()
	for child in directories:
		_walk(child, found)
