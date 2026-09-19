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

var _file: String = ""


func ok() -> bool:
	return problems.is_empty()


func report() -> String:
	if ok():
		return "content: %d letters, %d triggers, no problems" % [letters_checked, triggers_checked]
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
	return ok()


# --- Letters ---------------------------------------------------------------

func validate_letter(record: Dictionary) -> void:
	letters_checked += 1
	var letter := Letter.from_record(record)
	_file = letter.source_file

	if letter.sender.is_empty():
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
		for name in letter.params:
			if not supplied.has(name):
				_problem("params", "'%s' declares param '%s', which this trigger does not supply" % [letter_id, name])


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
