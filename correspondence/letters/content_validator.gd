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
	validate_clauses()
	validate_war_appetites(content)
	return ok()


## 🔒 **Every condition the sim knows about has a phrase** (#268).
##
## A `conditions` param renders what `IndependenceClause` holds, so a condition
## added to `LastChance` without prose beside it would put an id in front of the
## player in the most formal letter of the run. Build-time, because that is the
## only place it can be caught before it is read.
func validate_clauses() -> void:
	for gap in IndependenceClause.missing():
		_problem("clauses.independence", "no prose for '%s'" % gap)


## 🔒 **No luxury carries a war appetite** (#141, `town-economy.md` §1).
##
## What keeps SPEC §10.2's tea rule safe by construction: tea is the cheapest
## pleasure a town can never make for itself, and a war that priced it above a
## luxury the colony can brew would have towns brew instead of buying, with trade
## protests quietly ceasing to work and nothing failing loudly.
##
## A test, not a convention — and caught on the build, because the data edit that
## would break it looks entirely reasonable.
func validate_war_appetites(content: ContentDatabase) -> void:
	for id in content.ids("resources"):
		var record: Dictionary = content.collection("resources")[id]
		if not bool(record.get("luxury", false)):
			continue
		if float(record.get("war_appetite", 0.0)) > 0.0:
			_problem("resources.%s" % id,
				"a luxury carries a war appetite. A Crown at war prices iron, not tea")


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
	_check_option_conditions(option, path)

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
## 🔒 **When an option may be taken at all** (#275, `patrons.md` §5).
##
## Checked exactly as a trigger's conditions are, against the same registry,
## because they **are** a trigger's conditions: one place a condition is defined
## and one validator asking whether it exists.
##
## An unknown id on an option would otherwise fail closed and silently —
## `test_condition` answers false for a condition nobody registered, so the
## option would simply never appear and the letter would read as though the
## author had never written it.
func _check_option_conditions(option: Dictionary, path: String) -> void:
	var conditions: Variant = option.get(LetterSchema.KEY_CONDITIONS, [])
	if typeof(conditions) != TYPE_ARRAY:
		_problem("%s.conditions" % path, "expected an array of condition objects")
		return

	for index in conditions.size():
		var entry: Variant = conditions[index]
		var at := "%s.conditions[%d]" % [path, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_problem(at, "expected an object mapping a condition id to its params")
			continue
		for condition_id in entry:
			var args: Variant = entry[condition_id]
			if typeof(args) != TYPE_DICTIONARY:
				_problem("%s.%s" % [at, condition_id], "expected an object of params")
				continue
			for problem in ContentRegistry.check_condition_call(String(condition_id), args):
				_problem("%s.%s" % [at, condition_id], problem)


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

	# A trigger that names a cutscene is a different record (#299).
	if record.has(CutsceneTriggers.KEY_CUTSCENE):
		_check_cutscene_trigger(record)
		return

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

	_check_recall_gates(params, conditions)
	_check_reports(params, conditions)

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


## 🔒 **A letter that names a memory fires only when there is one to name**
## (#391, `contacts.md` §7).
##
## `recalled` reads zero and an empty string when there is nothing of that kind
## on record, so a trigger reaching for one without its gate renders *"you
## refused me 0 of , 0 months ago"* — a SPEC §9.1 violation waiting for a
## contact nobody has refused.
const RECALL_GATES: Dictionary = {
	"kindness": "remembers_a_kindness",
	"slight": "remembers_a_slight",
	"broken_word": "remembers_a_broken_word",
	"in_character": "remembers_in_character",
}


func _check_recall_gates(params: Variant, conditions: Array) -> void:
	if typeof(params) != TYPE_DICTIONARY:
		return
	var gates: Dictionary = {}
	for entry in conditions:
		if typeof(entry) == TYPE_DICTIONARY:
			for condition_id in entry:
				gates[String(condition_id)] = true
	var names: Array = params.keys()
	names.sort()
	for name in names:
		var spec: Variant = params[name]
		if typeof(spec) != TYPE_DICTIONARY or String(spec.get("from", "")) != "recalled":
			continue
		var reach := String(spec.get("reach", "kindness"))
		var gate := String(RECALL_GATES.get(reach, ""))
		if gate.is_empty():
			_problem("params.%s" % name, "recalls '%s', which no gate covers" % reach)
		elif not gates.has(gate):
			_problem("params.%s" % name,
				"recalls a %s without the '%s' condition, so it can name a memory that does not exist"
					% [reach, gate])


## 🔒 **A report reads only what it can understand, and only when it
## happened** (#398).
##
## `it_happened` and `what_happened` name an event, whom it concerns and a field.
## Each must be one `ReportableEvents` knows; and a `what_happened` param needs an
## `it_happened` gate on the same event and scope, or the letter prints an empty
## name for an event that never took place.
func _check_reports(params: Variant, conditions: Array) -> void:
	var gated: Dictionary = {}
	for index in conditions.size():
		var entry: Variant = conditions[index]
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("it_happened"):
			continue
		var args: Dictionary = entry["it_happened"]
		var event := String(args.get("event", ""))
		var concerning := String(args.get("concerning", ""))
		_check_report_scope("conditions[%d].it_happened" % index, event, concerning)
		gated["%s/%s" % [event, concerning]] = true

	if typeof(params) != TYPE_DICTIONARY:
		return
	var names: Array = params.keys()
	names.sort()
	for name in names:
		var spec: Variant = params[name]
		if typeof(spec) != TYPE_DICTIONARY or String(spec.get("from", "")) != "what_happened":
			continue
		var event := String(spec.get("event", ""))
		var concerning := String(spec.get("concerning", ""))
		var path := "params.%s" % name
		if not _check_report_scope(path, event, concerning):
			continue
		if ReportableEvents.field_kind(event, String(spec.get("field", ""))).is_empty():
			_problem(path, "'%s' carries no readable field '%s'" % [event, spec.get("field", "")])
		if not gated.has("%s/%s" % [event, concerning]):
			_problem(path, (
				"reads '%s' concerning %s without an it_happened gate on the same, "
				+ "so it can name something that never happened") % [event, concerning])


func _check_report_scope(path: String, event: String, concerning: String) -> bool:
	if not ReportableEvents.is_reportable(event):
		_problem(path, "'%s' is not a reportable event (see ReportableEvents)" % event)
		return false
	if not ReportableEvents.can_concern(event, concerning):
		_problem(path, "'%s' cannot be asked about as '%s'" % [event, concerning])
		return false
	return true


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
				continue
			# 🔒 **A reported field is the type the letter expects** (#398): a
			# tribe's name in a `tribe` param, a head count in an `integer` one.
			var spec: Variant = supplied[name]
			if typeof(spec) == TYPE_DICTIONARY and String(spec.get("from", "")) == "what_happened":
				var kind := ReportableEvents.field_kind(
					String(spec.get("event", "")), String(spec.get("field", "")))
				if not kind.is_empty() and kind != String(letter.params[name]):
					_problem("params.%s" % name, "reads a %s into a param declared %s" % [
						kind, letter.params[name]])


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


## 🔒 Every tuner personality must prefer options that exist (#313,
## `reply-vocabulary.md` §5).
##
## `data/balance/policies.json` describes each test player as a list of option ids
## to prefer, and `balance.gd` falls through to the letter's first option when a
## preference matches nothing. **Nothing fails, so a dead preference is silent** —
## and a dead preference means the harness has been reporting on a player who was
## never simulated.
##
## It had been true of **seven of the eight**: `yes`, `no` and `partial` were in
## the file and in no letter, so the spendthrift never said yes and the four
## steady-hand runs — which carry `tea_free`, `tea_duty` and `poor_ground`, the
## comparisons the tuning rests on — never paid part.
##
## The other checks in this file are tidiness. **This one is a number being
## wrong.**
func check_balance_policies(content: ContentDatabase) -> void:
	const POLICIES: String = "balance"

	var offered: Dictionary = {}
	for id in content.ids("letters"):
		_collect_option_ids(content.collection("letters")[id], offered)
	if offered.is_empty():
		return

	# 🔒 **A check that finds nothing has found nothing wrong** is the shape of
	# the bug this replaces. If the personalities are not there at all, say so.
	if content.ids(POLICIES).is_empty():
		_file = "data/%s" % POLICIES
		_problem(POLICIES, (
			"holds no tuner personalities, so nothing checks what the balance "
			+ "harness has been simulating"
		))
		return

	# The collection is the **folder**, `data/balance/`, and not the file inside
	# it. Reading `policies` here found nothing and reported nothing, which is
	# precisely the failure this check exists to end.
	for id in content.ids(POLICIES):
		var policy: Dictionary = content.collection(POLICIES)[id]
		_file = String(policy.get(JsonLoader.SOURCE_KEY, ""))
		for wanted in policy.get("prefer", []):
			if offered.has(String(wanted)):
				continue
			_problem("policies.%s" % id, (
				"prefers option '%s', which no letter offers — so the "
				+ "preference falls through and the harness reports on a "
				+ "player who was never simulated"
			) % wanted)

		# 🔒 **And the registers, for the same reason** (#317, `tone.md` §3).
		# A personality writes a tone per letter kind; a misspelt tone or a kind
		# that is not one of the three falls back to the plain register and
		# measures a player nobody wrote.
		_check_registers(id, policy)


## The tone and harshness a personality writes per kind of letter.
func _check_registers(id: String, policy: Dictionary) -> void:
	var registers: Variant = policy.get("registers", {})
	if typeof(registers) != TYPE_DICTIONARY:
		_problem("policies.%s.registers" % id, "must be a table of letter kinds")
		return

	for kind in registers:
		if not LetterKind.ALL.has(StringName(kind)):
			_problem("policies.%s.registers" % id, (
				"names the letter kind '%s', which is not one of %s"
			) % [kind, ContentValidator._join(LetterKind.ALL)])
			continue
		var register: Variant = registers[kind]
		if typeof(register) != TYPE_DICTIONARY:
			_problem("policies.%s.registers.%s" % [id, kind], "must be a table")
			continue
		var tone := String(register.get("tone", ""))
		if not tone.is_empty() and not Tone.is_tone(StringName(tone)):
			_problem("policies.%s.registers.%s" % [id, kind],
				"writes in '%s', which is not one of the five tones" % tone)
		if register.has("harsh") and typeof(register["harsh"]) != TYPE_BOOL:
			_problem("policies.%s.registers.%s" % [id, kind],
				"declares 'harsh' as something other than true or false")

	# 🔒 **Harshness is not offered when answering** (§9), so a personality
	# asking for it there is asking for something the wizard will refuse — and a
	# silently refused request is how this ticket's whole class of bug happens.
	var answering: Dictionary = registers.get(String(LetterKind.ANSWERING), {})
	if bool(answering.get("harsh", false)):
		_problem("policies.%s.registers.answering" % id, (
			"leans on a man about a decision the PC has already made, which §9 "
			+ "does not offer — there is nothing to lean on"
		))


## Every reply option id a letter offers.
##
## Walks the record rather than matching text, for the same reason
## `_collect_effects` does: a param or a resource sharing a name with an option
## must not be mistaken for one.
func _collect_option_ids(node: Variant, into: Dictionary) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			for key in node:
				if String(key) == "options" and typeof(node[key]) == TYPE_ARRAY:
					for option in node[key]:
						if typeof(option) == TYPE_DICTIONARY and option.has("id"):
							into[String(option["id"])] = true
				_collect_option_ids(node[key], into)
		TYPE_ARRAY:
			for entry in node:
				_collect_option_ids(entry, into)


## 🔒 **Every generating role has a bag, and no bag is too small** (#304,
## `names.md` §6).
##
## A missing bag fails **silently and completely**: `NameBags.person` answers
## empty for a bag nobody wrote, so the contact keeps whatever name he had —
## which for a generated man is none at all, and his letters arrive from nobody.
##
## The threshold is a placeholder. §7 asks for it to be set from a measured long
## run rather than guessed, and this is the guess until somebody measures.
const FEWEST_NAMES: int = 12

func check_name_bags(content: ContentDatabase) -> void:
	_file = "data/%s" % NameBags.COLLECTION

	for bag in NameBags.ALL:
		if not content.has_record(NameBags.COLLECTION, bag):
			_problem(bag, (
				"is a bag the generator draws from and there is no such file, so "
				+ "everything drawn from it is nameless"
			))
			continue
		var record := content.record(NameBags.COLLECTION, bag)
		var keys := PackedStringArray(["given", "family"])
		if bag == NameBags.TOWNS:
			keys = PackedStringArray(["names"])
		for key in keys:
			var entries: Variant = record.get(key, [])
			if typeof(entries) != TYPE_ARRAY:
				_problem("%s.%s" % [bag, key], "expected a list of names")
				continue
			if entries.is_empty():
				_problem("%s.%s" % [bag, key], "is empty, so nothing drawn from it has a name")
			elif entries.size() < FEWEST_NAMES:
				_problem("%s.%s" % [bag, key], (
					"holds %d names, which is too few for a long run without "
					+ "repeating — at least %d"
				) % [entries.size(), FEWEST_NAMES])

	# And every role that generates draws from one of them.
	for role in NameBags.BY_ROLE:
		var bag := String(NameBags.BY_ROLE[role])
		if not NameBags.ALL.has(bag):
			_problem(String(role), "draws from '%s', which is not a bag" % bag)


## 🔒 **Every perk and quirk names a knob that exists** (#286,
## `perks-and-quirks.md` §2).
##
## A modifier id nobody has registered would apply **nothing**, so a perk the
## player chose would be a perk he did not get — and the offered list would go on
## offering it. That is the whole reason the ids go through a registry rather
## than being read loosely.
func check_run_modifiers(content: ContentDatabase) -> void:
	_file = "data/%s" % RunModifiers.PERKS

	for record in [RunModifiers.PERKS_RECORD, RunModifiers.QUIRKS_RECORD]:
		if not content.has_record(RunModifiers.PERKS, record):
			_problem(record, (
				"does not exist, so adding a %s means adding a file — which is "
				+ "the one thing the framework is for"
			) % record.trim_suffix("s"))
			continue

		var seen: Dictionary = {}
		for entry in RunModifiers.entries_in(content, record):
			var id := String((entry as Dictionary).get("id", ""))
			if id.is_empty():
				_problem(record, "holds an entry with no id")
				continue
			if seen.has(id):
				_problem("%s.%s" % [record, id], "is declared twice")
			seen[id] = true

			var modifiers: Variant = (entry as Dictionary).get("modifiers", [])
			if typeof(modifiers) != TYPE_ARRAY:
				_problem("%s.%s.modifiers" % [record, id], "expected a list")
				continue
			for modifier in modifiers:
				if typeof(modifier) != TYPE_DICTIONARY:
					_problem("%s.%s.modifiers" % [record, id],
						"expected an object mapping a modifier id to its params")
					continue
				for modifier_id in modifier:
					if not RunModifiers.is_modifier(String(modifier_id)):
						_problem("%s.%s" % [record, id], (
							"names the knob '%s', which nothing turns — known: %s"
						) % [modifier_id, ", ".join(RunModifiers.ids())])


## 🔒 **Every patron is somebody, and every vice does something** (#282,
## `patrons.md` §2, §3, §6).
##
## Three ways a patron file can be wrong, and each of them ships a man the player
## meets who is quietly nothing:
##
## | | Because |
## | :--- | :--- |
## | a catalogue with fewer than two entries | §3's mismatch is impossible with one |
## | no vices at all | every patron would roll nothing |
## | a knob nothing turns and nothing reads | the vice would be a name and no more |
##
## The last is the one that matters, and it is the same check the perks carry for
## the same reason. **A vice naming `will_not_touch_gold` instead of
## `will_not_touch` would apply nothing**, the Author would have written it, the
## player would have met him, and nobody would ever find out.
func check_patrons(content: ContentDatabase) -> void:
	_file = "data/%s" % Patron.COLLECTION

	if not content.has_record(Patron.COLLECTION, Patron.CATALOGUE_RECORD):
		_problem(Patron.CATALOGUE_RECORD,
			"does not exist, so a patron has nothing to specialise in")
	else:
		var entries: Array = content.record(
			Patron.COLLECTION, Patron.CATALOGUE_RECORD).get("entries", [])
		if entries.size() < 2:
			_problem(Patron.CATALOGUE_RECORD, (
				"holds %d entries, and §3 wants a specialty and a need that are "
				+ "never the same — which needs two"
			) % entries.size())
		var seen: Dictionary = {}
		for entry in entries:
			var id := String((entry as Dictionary).get("id", ""))
			if id.is_empty():
				_problem(Patron.CATALOGUE_RECORD, "holds an entry with no id")
			elif seen.has(id):
				_problem("%s.%s" % [Patron.CATALOGUE_RECORD, id], "is declared twice")
			seen[id] = true

	if not content.has_record(PatronVices.COLLECTION, PatronVices.RECORD):
		_problem(PatronVices.RECORD,
			"does not exist, so every patron would arrive with no vice at all")
		return

	var vices: Array = content.record(
		PatronVices.COLLECTION, PatronVices.RECORD).get("entries", [])
	if vices.is_empty():
		_problem(PatronVices.RECORD, "holds no vices, so nothing makes a patron difficult")
	var known: Dictionary = {}
	for entry in vices:
		var id := String((entry as Dictionary).get("id", ""))
		if id.is_empty():
			_problem(PatronVices.RECORD, "holds a vice with no id")
			continue
		if known.has(id):
			_problem("%s.%s" % [PatronVices.RECORD, id], "is declared twice")
		known[id] = true

		var knobs: Variant = (entry as Dictionary).get("knobs", [])
		if typeof(knobs) != TYPE_ARRAY:
			_problem("%s.%s.knobs" % [PatronVices.RECORD, id], "expected a list")
			continue
		if knobs.is_empty():
			_problem("%s.%s" % [PatronVices.RECORD, id],
				"names no knobs, so it is a word and not a vice")
		for knob in knobs:
			if typeof(knob) != TYPE_DICTIONARY:
				_problem("%s.%s.knobs" % [PatronVices.RECORD, id],
					"expected an object mapping a knob id to its params")
				continue
			for knob_id in knob:
				if not PatronVices.is_knob(String(knob_id)):
					_problem("%s.%s" % [PatronVices.RECORD, id], (
						"names the knob '%s', which nothing turns and nothing "
						+ "reads — turned: %s; read: %s"
					) % [
						knob_id,
						", ".join(PackedStringArray(PatronVices.APPLIES.keys())),
						", ".join(PackedStringArray(PatronVices.READ_BY.keys())),
					])


## 🔒 **Every bonus a commander earns turns something** (#223,
## `commanders.md` §6).
##
## The same check the perks and the patrons' vices carry, and the same failure it
## prevents: a bonus the Author wrote, a commander reached, and that did nothing
## at all — *Siegecraft* misspelt as `siege_craft` would apply nothing, the
## commander would go on being told he had it, and nobody would ever find out.
##
## Also refuses a level table that cannot rank anybody and thresholds that run
## backwards, because a level nobody can reach is a level nobody can be told
## about.
func check_commander_experience(content: ContentDatabase) -> void:
	_file = "data/%s" % CommanderExperience.COLLECTION

	if not content.has_record(CommanderExperience.COLLECTION, CommanderExperience.RECORD):
		_problem(CommanderExperience.RECORD,
			"does not exist, so a commander can never learn anything")
		return

	var record := content.record(
		CommanderExperience.COLLECTION, CommanderExperience.RECORD)

	var levels: Variant = record.get("levels", [])
	if typeof(levels) != TYPE_ARRAY or (levels as Array).is_empty():
		_problem("%s.levels" % CommanderExperience.RECORD,
			"holds no levels, so nobody can rise at all")
	else:
		var last := -1.0
		for entry in levels as Array:
			var at := float((entry as Dictionary).get("casualties", 0.0))
			if at < last:
				_problem("%s.levels" % CommanderExperience.RECORD, (
					"runs backwards at %f, so a level arrives before the one below it"
				) % at)
			last = at

	var bonuses: Variant = record.get("bonuses", [])
	if typeof(bonuses) != TYPE_ARRAY:
		_problem("%s.bonuses" % CommanderExperience.RECORD, "expected a list")
		return
	for entry in bonuses as Array:
		var id := String((entry as Dictionary).get("id", ""))
		if id.is_empty():
			_problem("%s.bonuses" % CommanderExperience.RECORD,
				"holds a bonus with no id")
			continue
		var turns: Dictionary = (entry as Dictionary).get("turns", {})
		var adds: Dictionary = (entry as Dictionary).get("adds", {})
		var named := PackedStringArray(turns.keys())
		named.append_array(PackedStringArray(adds.keys()))
		if (entry as Dictionary).has("country"):
			named.append("country")
		if named.is_empty():
			_problem("%s.%s" % [CommanderExperience.RECORD, id],
				"turns nothing, so it is a word and not a bonus")
		for knob in named:
			if not CommanderExperience.is_knob(String(knob)):
				_problem("%s.%s" % [CommanderExperience.RECORD, id], (
					"names the knob '%s', which nothing reads — known: %s"
				) % [knob, ", ".join(PackedStringArray(
					CommanderExperience.READ_BY.keys()))])


## Cross-check that every trigger names a letter that exists, and report letters
## nothing can ever fire.
# --- 🔒 Agendas (#428, `governor-agendas.md` §2, §11, §13) -----------------

## 🔒 **The six intents, and the table that moves a governor between them.**
##
## Every intent has its prose and a stockpile of resources that exist; the table
## has a row for every consideration it names and no other, a column only for an
## intent the table may push (education has none — only an urging reaches it),
## and every cell is a push between -1 and +1. And **every letter that urges an
## intent names one the PC may urge**: a removed intent, or education, or
## rebellion, in a reply option is a hole the player can fall through.
func check_agendas(content: ContentDatabase) -> void:
	_file = "data/colony/agendas.json"
	if not content.has_record("colony", "agendas"):
		_problem("agendas", "there is no agendas record, so no intent has a stockpile or a table")
		return
	var record: Dictionary = content.record("colony", "agendas")

	var seen: Dictionary = {}
	for entry in record.get("intents", []):
		var id := String(entry.get("id", ""))
		var path := "intents.%s" % id
		if not GovernorIntent.is_intent(StringName(id)):
			_problem(path, "'%s' is not one of the intents" % id)
			continue
		seen[id] = true
		for field in ["name", "pursuing"]:
			if String(entry.get(field, "")).is_empty():
				_problem(path, "has no %s" % field)
		var stocks: Variant = entry.get("stocks", {})
		if typeof(stocks) != TYPE_DICTIONARY:
			_problem(path, "stocks must be an object of resource -> per thousand")
			continue
		for resource in stocks:
			if not ResourceCatalogue.has(StringName(resource)):
				_problem(path + ".stocks", "'%s' is not a resource" % resource)
			elif float(stocks[resource]) < 0.0:
				_problem(path + ".stocks", "'%s' is negative" % resource)
	for intent in GovernorIntent.IN_ORDER:
		if not seen.has(String(intent)):
			_problem("intents", "'%s' has no entry" % intent)

	var table: Variant = record.get("considerations", {})
	if typeof(table) != TYPE_DICTIONARY:
		_problem("considerations", "expected an object of row -> intent -> push")
		return
	for row in IntentConsiderations.TABLE_ROWS:
		if not (table as Dictionary).has(String(row)):
			_problem("considerations", "the table has no '%s' row" % row)
	for row in table:
		var path := "considerations.%s" % row
		if not IntentConsiderations.TABLE_ROWS.has(StringName(row)):
			_problem(path, "'%s' is not a row the governor weighs" % row)
			continue
		var cells: Variant = table[row]
		if typeof(cells) != TYPE_DICTIONARY:
			_problem(path, "expected an object of intent -> push")
			continue
		for intent in cells:
			if not GovernorIntent.is_intent(StringName(intent)):
				_problem(path, "'%s' is not an intent" % intent)
			elif StringName(intent) == GovernorIntent.EDUCATION:
				_problem(path, "education has no column: only an urging reaches it")
			var push := float(cells[intent])
			if push < -1.0 or push > 1.0:
				_problem(path + "." + String(intent), "%s is outside -1 to +1" % push)

	_file = "data/colony/agendas.json"
	for entry in record.get("intents", []):
		_check_menu(String(entry.get("id", "")), entry.get("menu", null))

	for id in content.ids("letters"):
		var letter: Dictionary = content.collection("letters")[id]
		_file = String(letter.get(JsonLoader.SOURCE_KEY, id))
		for step in letter.get(LetterSchema.KEY_REPLY, {}).get(LetterSchema.KEY_STEPS, []):
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				var effect: Variant = option.get("effect", {})
				if typeof(effect) != TYPE_DICTIONARY or not (effect as Dictionary).has("urge_intent"):
					continue
				var urged := StringName(effect["urge_intent"].get("intent", ""))
				if not GovernorIntent.pc_may_urge(urged):
					_problem("options.%s" % option.get("id", "?"),
						"urges '%s', which the PC may not ask for" % urged)


## 🔒 **A menu the walk can read** (#429, `governor-agendas.md` §12): every
## objective is a building or a slot the registry knows, every condition is
## registered and its params typed, a slot's own params are its own, and **every
## building's prerequisites sit higher on the same menu** — or the building
## could never be reached, and nothing would say so.
func _check_menu(intent: String, menu: Variant) -> void:
	var path := "intents.%s.menu" % intent
	if typeof(menu) != TYPE_ARRAY:
		_problem(path, "expected a menu: an array of entries")
		return
	var above: Dictionary = {}
	for index in (menu as Array).size():
		var entry: Variant = menu[index]
		var at := "%s[%d]" % [path, index]
		if typeof(entry) != TYPE_DICTIONARY:
			_problem(at, "expected an object with an objective")
			continue
		var objective := StringName(entry.get("objective", ""))
		if AgendaMenu.is_slot(objective):
			var takes: Dictionary = AgendaMenu.SLOTS[String(objective)]["params"]
			for key in entry:
				if key == "objective" or key == "when":
					continue
				if not takes.has(key):
					_problem(at, "'%s' takes no '%s'" % [objective, key])
				elif String(takes[key]) == "scorer" and not AgendaMenu.SCORERS.has(String(entry[key])):
					_problem(at, "'%s' is not a scorer (%s)" % [entry[key], ", ".join(AgendaMenu.SCORERS)])
				elif String(takes[key]) == "number" and typeof(entry[key]) not in [TYPE_INT, TYPE_FLOAT]:
					_problem(at, "'%s' must be a number" % key)
		elif Building.has(objective):
			for key in entry:
				if key != "objective" and key != "when":
					_problem(at, "a building takes no '%s'" % key)
			for required in Building.find(objective).requires:
				if not above.has(String(required)):
					_problem(at, "'%s' needs '%s', which is not above it on this menu" % [objective, required])
		else:
			_problem(at, "'%s' is neither a building nor a slot" % objective)
		for condition in entry.get("when", []):
			_check_menu_condition(at, condition)
		above[String(objective)] = true


func _check_menu_condition(at: String, condition: Variant) -> void:
	if typeof(condition) != TYPE_DICTIONARY:
		_problem(at + ".when", "expected {is, params...}")
		return
	var id := String(condition.get("is", ""))
	if not AgendaMenu.CONDITIONS.has(id):
		_problem(at + ".when", "'%s' is not a condition (%s)" % [id,
			", ".join(PackedStringArray(AgendaMenu.CONDITIONS.keys()))])
		return
	var takes: Dictionary = AgendaMenu.CONDITIONS[id]
	for key in takes:
		if not condition.has(key):
			_problem(at + ".when." + id, "is missing '%s'" % key)
		elif String(takes[key]) == "number" and typeof(condition[key]) not in [TYPE_INT, TYPE_FLOAT]:
			_problem(at + ".when." + id, "'%s' must be a number" % key)
		elif String(takes[key]) == "resource" and not ResourceCatalogue.has(StringName(condition[key])):
			_problem(at + ".when." + id, "'%s' is not a resource" % condition[key])
	for key in condition:
		if key != "is" and not takes.has(key):
			_problem(at + ".when." + id, "has no param '%s'" % key)


# --- 🔒 Cutscenes (#299, `cutscenes.md` §5) ------------------------------------

## A cutscene trigger's own shape: a kind, one registered condition with the
## params it needs, and params the caption can be told from.
func _check_cutscene_trigger(record: Dictionary) -> void:
	var kind := String(record.get(CutsceneTriggers.KEY_KIND, ""))
	if not CutsceneTriggers.KINDS.has(kind):
		_problem("kind", "'%s' is not a kind of cutscene (%s)" % [kind, ", ".join(CutsceneTriggers.KINDS)])
	if record.has(CutsceneTriggers.KEY_AFTER) and kind != CutsceneTriggers.RECURRING \
			and not String(record[CutsceneTriggers.KEY_AFTER]).is_empty():
		_problem("after", "only a recurring cutscene stands aside for a first")

	var on: Variant = record.get(CutsceneTriggers.KEY_ON, {})
	if typeof(on) != TYPE_DICTIONARY or (on as Dictionary).size() != 1:
		_problem("on", "expected one condition, as {id: {params}}")
	else:
		var condition_id := String((on as Dictionary).keys()[0])
		var args: Variant = on[condition_id]
		if not CutsceneTriggers.CONDITIONS.has(condition_id):
			_problem("on", "'%s' is not a cutscene condition (%s)" % [
				condition_id, ", ".join(PackedStringArray(CutsceneTriggers.CONDITIONS.keys()))])
		elif typeof(args) != TYPE_DICTIONARY:
			_problem("on.%s" % condition_id, "expected an object of params")
		else:
			for required in CutsceneTriggers.REQUIRED.get(condition_id, []):
				if not (args as Dictionary).has(required):
					_problem("on.%s" % condition_id, "is missing '%s'" % required)
			var declared: Dictionary = CutsceneTriggers.CONDITIONS[condition_id]
			for name in args:
				if not declared.has(name):
					_problem("on.%s" % condition_id, "has no param '%s'" % name)
			if (args as Dictionary).has("where") and typeof(args["where"]) != TYPE_DICTIONARY:
				_problem("on.%s.where" % condition_id, "expected an object of field -> value")

	var params: Variant = record.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		_problem("params", "expected an object of param names to sources")
		return
	for name in params:
		var source: Variant = params[name]
		var path := "params.%s" % name
		if typeof(source) != TYPE_DICTIONARY:
			_problem(path, "expected a source object")
			continue
		var from := String(source.get("from", ""))
		if not CutsceneParams.SOURCES.has(from):
			_problem(path, "'%s' is not a cutscene param source (%s)" % [from, ", ".join(CutsceneParams.SOURCES)])
			continue
		if from == "event" and String(source.get("field", "")).is_empty():
			_problem(path, "reads the event but names no field")
		if (from == "event" or from == "subject") and source.has("as") \
				and not CutsceneParams.KINDS.has(String(source["as"])):
			_problem(path, "'%s' is not a kind of value (%s)" % [source["as"], ", ".join(CutsceneParams.KINDS)])
		if from == "colony" and not ["people", "towns"].has(String(source.get("measure", ""))):
			_problem(path, "a colony figure must be 'people' or 'towns'")


## 🔒 **Every cutscene can be shown, and every trigger shows one.**
##
## At least one panel, an image and a caption on each, every image registered in
## the asset store so the art can be dropped in by id, every `{param:}` a
## caption uses declared, every declared param supplied by every trigger that
## shows it, and every trigger naming a cutscene that exists. The opening is
## required outright: SPEC §6.1 opens every run with it.
func check_cutscenes(content: ContentDatabase) -> void:
	var assets: Dictionary = content.collection(AssetRegistry.COLLECTION)
	var firsts: Dictionary = {}
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if String(record.get(CutsceneTriggers.KEY_KIND, "")) == CutsceneTriggers.FIRST:
			firsts[String(record.get(CutsceneTriggers.KEY_CUTSCENE, ""))] = true

	for id in content.ids(Cutscene.COLLECTION):
		var record: Dictionary = content.record(Cutscene.COLLECTION, id)
		_file = String(record.get(JsonLoader.SOURCE_KEY, id))
		var panels: Variant = record.get(Cutscene.KEY_PANELS, [])
		if typeof(panels) != TYPE_ARRAY or (panels as Array).is_empty():
			_problem("panels", "'%s' has no panels" % id)
			continue
		var declared: Dictionary = record.get(Cutscene.KEY_PARAMS, {})
		for index in (panels as Array).size():
			var panel: Variant = panels[index]
			var path := "panels[%d]" % index
			if typeof(panel) != TYPE_DICTIONARY:
				_problem(path, "expected an object with an image and a text")
				continue
			var image := String(panel.get(Cutscene.KEY_IMAGE, ""))
			var text := String(panel.get(Cutscene.KEY_TEXT, ""))
			if image.is_empty():
				_problem(path, "has no image")
			elif not assets.has(image):
				_problem(path, "image '%s' is not in the asset store" % image)
			if text.is_empty():
				_problem(path, "has no caption")
			for slot in LetterSchema.slots_in(text):
				if String(slot["kind"]) != "param" or not declared.has(String(slot["name"])):
					_problem(path, "uses %s, which the cutscene does not declare" % slot["token"])

	if not content.has_record(Cutscene.COLLECTION, String(Cutscene.OPENING)):
		_file = "data/cutscenes_en"
		_problem(String(Cutscene.OPENING), "there is no opening cutscene, and SPEC §6.1 opens every run with one")

	for id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[id]
		if not trigger.has(CutsceneTriggers.KEY_CUTSCENE):
			continue
		_file = String(trigger.get(JsonLoader.SOURCE_KEY, ""))
		var cutscene := String(trigger[CutsceneTriggers.KEY_CUTSCENE])
		if not content.has_record(Cutscene.COLLECTION, cutscene):
			_problem("cutscene", "'%s' names cutscene '%s', which does not exist" % [id, cutscene])
			continue
		var after := String(trigger.get(CutsceneTriggers.KEY_AFTER, ""))
		if not after.is_empty() and not firsts.has(after):
			_problem("after", "'%s' stands aside for '%s', which no first shows" % [id, after])
		var wanted: Dictionary = content.record(Cutscene.COLLECTION, cutscene).get(Cutscene.KEY_PARAMS, {})
		var supplied: Dictionary = trigger.get("params", {})
		for name in wanted:
			if not supplied.has(name):
				_problem("params", "'%s' shows '%s' without supplying '%s'" % [id, cutscene, name])


func check_trigger_targets(content: ContentDatabase) -> void:
	var referenced: Dictionary = {}
	for id in content.ids("triggers"):
		var record: Dictionary = content.collection("triggers")[id]
		if record.has(CutsceneTriggers.KEY_CUTSCENE):
			continue  # A cutscene's trigger; `check_cutscenes` covers it.
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
