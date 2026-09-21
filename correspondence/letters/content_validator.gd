class_name ContentValidator
extends RefCounted

## Checks the whole `data/` tree in one pass.
##
## The Author writes hundreds of letters by hand. Every problem this catches is
## one that would otherwise render `I require {param:amount}` in front of a
## player, or fire an effect that does not exist, at the exact moment the game is
## least able to recover.
##
## Every problem names **the file, the path within it, and the offending token**,
## because "invalid letter" costs more to chase than the mistake cost to make.

class Problem:
	extends RefCounted

	var file: String
	var path: String
	var message: String

	func _init(p_file: String, p_path: String, p_message: String) -> void:
		file = p_file
		path = p_path
		message = p_message

	func _to_string() -> String:
		return "%s\n    at %s\n    %s" % [file.get_file(), path, message]


var problems: Array[Problem] = []
var letters_checked: int = 0
var triggers_checked: int = 0
var resources_checked: int = 0

var _file: String = ""


func ok() -> bool:
	return problems.is_empty()


func report() -> String:
	if ok():
		return "content: %d letters, %d triggers, %d resources, no problems" % [
			letters_checked, triggers_checked, resources_checked,
		]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("content: %d problem(s)" % problems.size())
	for problem in problems:
		lines.append("  %s" % problem)
	return "\n".join(lines)


func _problem(path: String, message: String) -> void:
	problems.append(Problem.new(_file, path, message))


# --- Entry points ----------------------------------------------------------

## Validate every letter and trigger in a loaded content database.
func validate(content: ContentDatabase) -> bool:
	for id in content.ids("letters"):
		validate_letter(content.collection("letters")[id])
	for id in content.ids("triggers"):
		validate_trigger(content.collection("triggers")[id])
	validate_resources(content)
	return ok()


# --- Resources -------------------------------------------------------------

## The resource data has to hang together, or a town will one day try to make
## clothing out of something that does not exist.
##
## Checked here rather than at runtime because **adding a resource is adding a
## file** (#36), and a build-time error is the only thing standing between a
## typo in `converts_from` and a silent hole in the economy.
func validate_resources(content: ContentDatabase) -> void:
	var known: Dictionary = {}
	for id in content.ids("resources"):
		known[id] = true

	for id in content.ids("resources"):
		resources_checked += 1
		var record: Dictionary = content.collection("resources")[id]
		_file = String(record.get(JsonLoader.SOURCE_KEY, "?"))

		for input in record.get("converts_from", []):
			if not known.has(String(input)):
				_problem("converts_from", "'%s' is made from '%s', which is not a resource" % [id, input])
			elif String(input) == id:
				_problem("converts_from", "'%s' is made from itself" % id)

		if typeof(record.get("luxury", false)) != TYPE_BOOL:
			_problem("luxury", "'%s' must be true or false" % id)
		if typeof(record.get("producible", true)) != TYPE_BOOL:
			_problem("producible", "'%s' must be true or false" % id)

	# Only meaningful once the catalogue is loaded, which the CLI does first.
	if ResourceCatalogue.size() == 0:
		return
	for id in ResourceCatalogue.ids():
		var kind := ResourceCatalogue.get_kind(StringName(id))
		if kind.is_raw():
			continue
		if not ResourceCatalogue.has_complete_chain(StringName(id)):
			_file = "data/resources"
			_problem("converts_from", "'%s' cannot be made from anything the colony can produce" % id)


# --- Letters ---------------------------------------------------------------

func validate_letter(record: Dictionary) -> void:
	letters_checked += 1
	var letter := Letter.from_record(record)
	_file = letter.source_file

	if letter.is_composable():
		# A player-initiated letter is written *by* the PC, so it has no sender,
		# and its recipients come from `to_roles`.
		for role in letter.to_roles:
			if String(role).is_empty():
				_problem("to_roles", "empty role")
		if not letter.has_reply():
			_problem("reply", "a composable letter needs a reply block — it is all reply")
	elif letter.sender.is_empty():
		_problem("sender", "a letter needs a sender")

	if not LetterSchema.is_type(letter.type):
		_problem("type", "unknown type '%s'. Known: %s" % [letter.type, _join(LetterSchema.TYPES)])

	_check_params_block(letter)
	_check_perception_block(letter)

	for index in letter.body.size():
		_check_line(letter.body[index], letter, "body[%d]" % index)

	if letter.has_reply():
		_check_reply(letter)


func _check_params_block(letter: Letter) -> void:
	for name in letter.params:
		var declared := StringName(letter.params[name])
		if not LetterSchema.is_param_type(declared):
			_problem("params.%s" % name, "unknown param type '%s'. Known: %s" % [
				declared, _join(LetterSchema.PARAM_TYPES),
			])


func _check_perception_block(letter: Letter) -> void:
	for name in letter.perception:
		var entry: Variant = letter.perception[name]
		if typeof(entry) != TYPE_DICTIONARY:
			_problem("perception.%s" % name, "expected an object with 'measure' and 'ladder'")
			continue
		var measure := String(entry.get(LetterSchema.KEY_MEASURE, ""))
		if measure.is_empty():
			_problem("perception.%s" % name, "no measure named")
		elif not MeasureRegistry.has_measure(measure):
			_problem("perception.%s" % name, "unknown measure '%s'. Known: %s" % [
				measure, ", ".join(MeasureRegistry.ids()),
			])
		var ladder: Array = entry.get(LetterSchema.KEY_LADDER, [])
		if ladder.size() < 2:
			_problem("perception.%s.ladder" % name, "a ladder needs at least two rungs, got %d" % ladder.size())


func _check_line(line: Variant, letter: Letter, path: String) -> void:
	if typeof(line) != TYPE_DICTIONARY:
		_problem(path, "expected an object with a 'text' field")
		return

	for tone in line.get(LetterSchema.KEY_ONLY_TONES, []):
		if not Tone.is_tone(StringName(tone)):
			_problem("%s.only_tones" % path, "unknown tone '%s'. The five are %s" % [tone, _join(Tone.ALL)])

	var overrides: Variant = line.get(LetterSchema.KEY_TONE)
	if typeof(overrides) == TYPE_DICTIONARY:
		for tone in overrides:
			if not Tone.is_tone(StringName(tone)):
				_problem("%s.tone" % path, "unknown tone '%s'. The five are %s" % [tone, _join(Tone.ALL)])
		for tone in overrides:
			_check_slots(String(overrides[tone]), line, letter, "%s.tone.%s" % [path, tone])

	var inserts: Variant = line.get(LetterSchema.KEY_INSERT, {})
	if typeof(inserts) == TYPE_DICTIONARY:
		for insert_name in inserts:
			var by_tone: Variant = inserts[insert_name]
			if typeof(by_tone) != TYPE_DICTIONARY:
				_problem("%s.insert.%s" % [path, insert_name], "expected tone keys mapping to text")
				continue
			for tone in by_tone:
				if not Tone.is_tone(StringName(tone)):
					_problem("%s.insert.%s" % [path, insert_name],
						"unknown tone '%s'. The five are %s" % [tone, _join(Tone.ALL)])

	_check_slots(String(line.get(LetterSchema.KEY_TEXT, "")), line, letter, path)
	_check_unused_inserts(line, letter, path)


func _check_slots(text: String, line: Dictionary, letter: Letter, path: String) -> void:
	for slot in LetterSchema.slots_in(text):
		var kind := StringName(slot["kind"])
		var name: String = slot["name"]
		var token: String = slot["token"]

		if not LetterSchema.is_slot_kind(kind):
			_problem(path, "unknown slot kind in '%s'. The four are %s" % [token, _join(LetterSchema.SLOT_KINDS)])
			continue

		match kind:
			LetterSchema.SLOT_PARAM:
				if not letter.params.has(name):
					_problem(path, "'%s' is not declared in params" % token)
			LetterSchema.SLOT_PERCEPTION:
				if not letter.perception.has(name):
					_problem(path, "'%s' has no entry in the perception block" % token)
			LetterSchema.SLOT_SENDER:
				if not LetterSchema.is_sender_field(StringName(name)):
					_problem(path, "'%s' is not on the sender whitelist. The fields are %s" % [
						token, _join(LetterSchema.SENDER_FIELDS),
					])
			LetterSchema.SLOT_INSERT:
				var inserts: Variant = line.get(LetterSchema.KEY_INSERT, {})
				if typeof(inserts) != TYPE_DICTIONARY or not inserts.has(name):
					_problem(path, "'%s' has no insert defined on this line" % token)


## An insert defined and never referenced is dead prose the Author expected to
## see. Worth saying so.
func _check_unused_inserts(line: Dictionary, letter: Letter, path: String) -> void:
	var inserts: Variant = line.get(LetterSchema.KEY_INSERT, {})
	if typeof(inserts) != TYPE_DICTIONARY:
		return
	var referenced: Dictionary = {}
	var texts: PackedStringArray = PackedStringArray([String(line.get(LetterSchema.KEY_TEXT, ""))])
	var overrides: Variant = line.get(LetterSchema.KEY_TONE)
	if typeof(overrides) == TYPE_DICTIONARY:
		for tone in overrides:
			texts.append(String(overrides[tone]))
	for text in texts:
		for slot in LetterSchema.slots_in(text):
			if StringName(slot["kind"]) == LetterSchema.SLOT_INSERT:
				referenced[slot["name"]] = true
	for insert_name in inserts:
		if not referenced.has(insert_name):
			_problem("%s.insert.%s" % [path, insert_name], "defined but never used in this line")


# --- Replies ---------------------------------------------------------------

func _check_reply(letter: Letter) -> void:
	if letter.has_tone_step():
		var block: Dictionary = letter.reply[LetterSchema.KEY_TONE]
		_check_slots(String(block.get(LetterSchema.KEY_TEXT, "")), {}, letter, "reply.tone")
		var options: Array = block.get(LetterSchema.KEY_OPTIONS, [])
		if options.is_empty():
			_problem("reply.tone.options", "a tone block needs at least one option")
		var seen: Dictionary = {}
		for index in options.size():
			var option: Dictionary = options[index]
			var tone := StringName(option.get(LetterSchema.KEY_TONE, ""))
			var path := "reply.tone.options[%d]" % index
			if not Tone.is_tone(tone):
				_problem(path, "unknown tone '%s'. The five are %s" % [tone, _join(Tone.ALL)])
			elif seen.has(tone):
				_problem(path, "tone '%s' is offered twice" % tone)
			seen[tone] = true
			_check_slots(String(option.get(LetterSchema.KEY_TEXT, "")), option, letter, path)

	var steps: Array = letter.steps()
	for step_index in steps.size():
		var step: Dictionary = steps[step_index]
		var step_path := "reply.steps[%d]" % step_index
		var options: Array = step.get(LetterSchema.KEY_OPTIONS, [])
		if options.is_empty():
			_problem(step_path, "a step needs at least one option")
		for option_index in options.size():
			_check_option(options[option_index], letter, "%s.options[%d]" % [step_path, option_index])

	var closing: Array = letter.closing()
	for index in closing.size():
		_check_line(closing[index], letter, "reply.closing[%d]" % index)


func _check_option(option: Variant, letter: Letter, path: String) -> void:
	if typeof(option) != TYPE_DICTIONARY:
		_problem(path, "expected an object")
		return

	# **Every choice's mechanical effect is understandable from its wording**
	# (SPEC §9.2), which starts with there being wording at all.
	if String(option.get(LetterSchema.KEY_LABEL, "")).is_empty():
		_problem(path, "an option needs a label, so the player can tell what he is ordering")

	_check_line(option, letter, path)
	_check_slots(String(option.get(LetterSchema.KEY_LABEL, "")), option, letter, "%s.label" % path)
	_check_harshness(option, path)

	var effect: Variant = option.get(LetterSchema.KEY_EFFECT)
	if effect == null:
		return
	if typeof(effect) != TYPE_DICTIONARY:
		_problem("%s.effect" % path, "expected an object mapping an effect id to its params")
		return
	for effect_id in effect:
		var args: Variant = effect[effect_id]
		if typeof(args) != TYPE_DICTIONARY:
			_problem("%s.effect.%s" % [path, effect_id], "expected an object of params")
			continue
		_check_effect_args(String(effect_id), args, letter, "%s.effect.%s" % [path, effect_id])


## 🔒 **An option that says it is harsh must say so in a way the engine reads.**
##
## `harsh` is the one property of a reply option that changes what the order
## *does* rather than how it reads — it buys compliance at the price of the
## governor's regard and the town's patience (#71) — and a misspelled key or a
## string where a boolean belongs would leave the prose promising a command the
## engine delivers as a request. Silently, and in the direction that flatters the
## content.
##
## It is also meaningless without an order to attach to, so an option that is
## harsh and has no effect is a mistake rather than a harmless decoration.
func _check_harshness(option: Dictionary, path: String) -> void:
	if not option.has(LetterSchema.KEY_HARSH):
		return
	if typeof(option[LetterSchema.KEY_HARSH]) != TYPE_BOOL:
		_problem("%s.harsh" % path, "must be true or false")
		return
	if not bool(option[LetterSchema.KEY_HARSH]):
		return
	var effect: Variant = option.get(LetterSchema.KEY_EFFECT)
	if typeof(effect) != TYPE_DICTIONARY or (effect as Dictionary).is_empty():
		_problem("%s.harsh" % path, "is harsh but carries no effect, so it orders nothing")


func _check_effect_args(effect_id: String, args: Dictionary, letter: Letter, path: String) -> void:
	for problem in ContentRegistry.check_effect_call(effect_id, args):
		_problem(path, problem)
	# A `"{name}"` placeholder must name something the letter declared, or the
	# director has nothing to supply.
	for name in args:
		var value: Variant = args[name]
		if typeof(value) != TYPE_STRING:
			continue
		if value.begins_with("{") and value.ends_with("}"):
			var param_name: String = value.substr(1, value.length() - 2)
			if not letter.params.has(param_name):
				_problem(path, "'%s' refers to '%s', which is not declared in params" % [value, param_name])


# --- Triggers --------------------------------------------------------------

func validate_trigger(record: Dictionary) -> void:
	triggers_checked += 1
	_file = String(record.get(JsonLoader.SOURCE_KEY, ""))
	var id := String(record.get("id", ""))

	var letter_id := String(record.get("letter", ""))
	if letter_id.is_empty():
		_problem("letter", "trigger '%s' names no letter" % id)

	var conditions: Variant = record.get("conditions", [])
	if typeof(conditions) != TYPE_ARRAY:
		_problem("conditions", "expected an array of condition objects")
		return

	var params: Variant = record.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		_problem("params", "expected an object of param names to sources")
	else:
		for name in params:
			var spec: Variant = params[name]
			if typeof(spec) != TYPE_DICTIONARY or not spec.has("from"):
				continue  # A literal value, which needs no source.
			var args: Dictionary = spec.duplicate()
			var source_id := String(args["from"])
			args.erase("from")
			for problem in ContentRegistry.check_param_source_call(source_id, args):
				_problem("params.%s" % name, problem)

	for index in conditions.size():
		var entry: Variant = conditions[index]
		var path := "conditions[%d]" % index
		if typeof(entry) != TYPE_DICTIONARY:
			_problem(path, "expected an object mapping a condition id to its params")
			continue
		for condition_id in entry:
			var args: Variant = entry[condition_id]
			if typeof(args) != TYPE_DICTIONARY:
				_problem("%s.%s" % [path, condition_id], "expected an object of params")
				continue
			for problem in ContentRegistry.check_condition_call(String(condition_id), args):
				_problem("%s.%s" % [path, condition_id], problem)


## Every param a letter declares must be supplied by the trigger that fires it,
## or the director has nothing to put in the slot.
func check_trigger_params(content: ContentDatabase) -> void:
	for id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[id]
		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue
		_file = String(trigger.get(JsonLoader.SOURCE_KEY, "?"))
		var letter := Letter.from_record(content.record("letters", letter_id))
		var supplied: Dictionary = trigger.get("params", {})
		if letter.is_composable():
			# A composed letter takes its values at the moment of writing, from
			# `compose_defaults`, not from the trigger that offers it.
			for name in letter.params:
				if String(name) == Composer.RECIPIENT_PARAM:
					continue  # The flow supplies the recipient.
				if not letter.compose_defaults.has(name):
					_problem("compose_defaults", "'%s' declares param '%s' with no compose default" % [letter_id, name])
			continue
		for name in letter.params:
			if not supplied.has(name):
				_problem("params", "'%s' declares param '%s', which this trigger does not supply" % [letter_id, name])


## Report any registered effect that no letter uses.
##
## ## 🔒 An effect nobody uses is an instrument the player cannot reach
##
## This exists because of a real one. `set_tax_rate` was registered, carried a
## builder that worked out the world key and the step, and had its own entry in
## the turn loop's executor table — and **no letter used it**. Every letter about
## a rate used `set_policy`, which the table maps to nothing.
##
## So SPEC §10.2's main economic instrument was disconnected for the whole of M1
## and M2, and the trade-protest backfire built on top of it (#115) rested on a
## lever the player could not pull. Nothing failed, because nothing checked.
##
## **Conditions and param sources are deliberately not checked.** An unused
## condition is vocabulary waiting for a letter to want it; an unused effect is a
## verb the game claims to have and does not.
## 🔒 **A reserve must name its resources** (#148).
##
## A blanket figure made a granary add two months of desired stock to guns and
## rum as readily as to grain, which only made the town sell less of everything —
## not an effect anybody would choose. Per-resource it changes behaviour instead:
## a weavers' loom gives a town a real reason to stockpile cotton.
##
## **No wildcard either.** A `"*"` key would reintroduce the blanket form through
## the door the per-resource shape was built to close, and it would do it
## quietly.
func check_building_reserves(content: ContentDatabase) -> void:
	for collection in ["buildings", "improvements"]:
		for id in content.ids(collection):
			_file = "%s/%s" % [collection, id]
			var record: Dictionary = content.collection(collection)[id]
			var effects: Dictionary = record.get("effects", {})
			if not effects.has("reserve_months"):
				continue
			var reserve: Variant = effects["reserve_months"]
			if typeof(reserve) != TYPE_DICTIONARY:
				_problem("effects.reserve_months", "a blanket figure; it must name its resources")
				continue
			for resource in reserve:
				if String(resource) == "*":
					_problem("effects.reserve_months", "uses a wildcard, which is the blanket form again")
				elif ResourceCatalogue.get_kind(StringName(resource)) == null:
					_problem("effects.reserve_months", "names '%s', which is not a resource" % resource)


## 🔒 **A building authors its cost and not its duration** (#148).
##
## Time is the cost divided by what the town can put into construction in a
## month, so a `months` field is a second authored number that can disagree with
## the first — and used to.
func check_no_authored_durations(content: ContentDatabase) -> void:
	for collection in ["buildings", "improvements"]:
		for id in content.ids(collection):
			_file = "%s/%s" % [collection, id]
			if content.collection(collection)[id].has("months"):
				_problem("months", "authored; build time is derived from cost and capacity")


## 🔒 **Every way a run can end has something to say about it** (#78).
##
## The epitaph is the last screen of a run and there is no next month in which to
## notice it was blank. So: every outcome resolves for every prestige band, every
## record names an outcome that can actually happen, and none of them is empty.
##
## The general form — a record with no `band` — is what makes that cheap: one
## file gives an outcome a floor, and the bands worth sharpening are sharpened.
## 🔒 What a letter declares about its own strength (#257).
##
## **`urgency` is tone's and `speaks_to` is severity's**, and the two must stay
## apart: SPEC §9.1 makes urgency one of tone's three inputs and the director
## feeds it straight into `tone_for`. A letter carrying `urgency` would be one
## trying to decide how it reads *and* whether it is reached for.
func check_severity(content: ContentDatabase) -> void:
	for id in content.ids("letters"):
		var record := content.record("letters", id)
		_file = String(record.get(JsonLoader.SOURCE_KEY, "?"))

		if record.has("urgency"):
			_problem(id, "declares 'urgency', which belongs to the trigger and to tone. "
				+ "A letter says how hard it speaks with 'speaks_to'")

		if not record.has(Severity.KEY):
			continue
		var speaks_to: Variant = record[Severity.KEY]
		if not (speaks_to is float or speaks_to is int):
			_problem(id, "'%s' is %s rather than a number" % [Severity.KEY, speaks_to])
			continue
		if float(speaks_to) < 0.0:
			_problem(id, "'%s' is %s, and a letter cannot speak to less than nothing"
				% [Severity.KEY, speaks_to])

		# 🔒 A must-send bypasses pressure entirely (§2), so a strength on one is
		# a figure nothing will ever read — and a reader would reasonably assume
		# it did something.
		if not bool(record.get(LetterSchema.KEY_SKIPPABLE, true)):
			_problem(id, "is unskippable and declares '%s'. A must-send bypasses "
				% Severity.KEY + "pressure, so nothing would ever read it")


func check_epitaphs(content: ContentDatabase) -> void:
	for id in content.ids(Epitaph.COLLECTION):
		var record := content.record(Epitaph.COLLECTION, id)
		_file = String(record.get(JsonLoader.SOURCE_KEY, "?"))
		var outcome := String(record.get("outcome", ""))
		if not Epitaph.outcomes().has(outcome):
			_problem(id, "outcome '%s' is not a way a run can end. The three are %s"
				% [outcome, ", ".join(Epitaph.outcomes())])
		var band := String(record.get("band", ""))
		if not band.is_empty() and not Prestige.band_names().has(band):
			_problem(id, "band '%s' is not a prestige band. They are %s"
				% [band, ", ".join(Prestige.band_names())])
		if String(record.get("text", "")).strip_edges().is_empty():
			_problem(id, "has no text, so a run could end on a blank screen")

	_file = "data/epitaphs"
	for outcome in Epitaph.outcomes():
		for band in Prestige.band_names():
			if Epitaph.for_outcome(StringName(outcome), StringName(band), content).is_empty():
				_problem("%s/%s" % [outcome, band],
					"no epitaph answers for it, so that run ends on nothing")


func check_effects_are_reachable(content: ContentDatabase) -> void:
	var used: Dictionary = {}
	for id in content.ids("letters"):
		_collect_effects(content.collection("letters")[id], used)

	_file = "registered effects"
	for id in ContentRegistry.effect_ids():
		if not used.has(String(id)):
			_problem("effects", (
				"'%s' is registered and no letter uses it, so the player cannot "
				+ "reach it — give it a letter, or stop registering it"
			) % id)


## Every effect id named anywhere in a letter record.
##
## Walks the record rather than matching text, so a resource called "refuse"
## could never be mistaken for the effect of the same name.
func _collect_effects(node: Variant, into: Dictionary) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			for key in node:
				if String(key) == "effect" and typeof(node[key]) == TYPE_DICTIONARY:
					for effect_id in node[key]:
						into[String(effect_id)] = true
				_collect_effects(node[key], into)
		TYPE_ARRAY:
			for entry in node:
				_collect_effects(entry, into)


## Cross-check that every trigger names a letter that exists, and report letters
## nothing can ever fire.
func check_trigger_targets(content: ContentDatabase) -> void:
	var referenced: Dictionary = {}
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		var letter_id := String(record.get("letter", ""))
		referenced[letter_id] = true
		if not letter_id.is_empty() and not content.has_record("letters", letter_id):
			_file = String(record.get(JsonLoader.SOURCE_KEY, ""))
			_problem("letter", "names letter '%s', which does not exist" % letter_id)


static func _join(values: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for value in values:
		out.append(String(value))
	return ", ".join(out)
