class_name LetterRenderer
extends RefCounted

## Turns a letter template plus its supplied params into the text the player
## reads.
##
## **The invariant this protects: quantities are exact, judgments are biased.**
## A number goes through `{param:}` and arrives untouched. A judgment goes
## through `{perception:}` and is shaded by the sender's lean. Neither can be
## routed through the other, because they resolve by different machinery and the
## validator checks which one a name was declared in. SPEC §9.1 makes this a
## correctness rule: no letter ever reports a false figure.
##
## Four slot kinds and no others:
##
## | Slot | Meaning |
## | :--- | :--- |
## | `{param:x}` | An exact, truthful value supplied by the director |
## | `{perception:x}` | A biased judgment (#10) |
## | `{sender:x}` | A whitelisted contact field |
## | `{insert:x}` | A tone-keyed fragment, local to its own line, may be empty |

## Space before these is always wrong, however the slots resolved.
const CLINGING_PUNCTUATION: String = ",.;:!?)"


## Render a letter's body, **addressed to the PC**.
##
## 🔒 **The salutation is prepended here rather than written into each
## letter file** (#358, `names.md` §2). It is a property of how the PC is
## addressed, which is the same for every letter of a given tone, so a copy at
## the top of eighty files would be eighty things to reword — and a letter
## authored next year would forget.
##
## It is on the body alone. A reply's prose is the PC writing, and a man does not
## address himself.
func render_body(letter: Letter, context: LetterContext) -> String:
	var body := render_lines(letter.body, letter, context)
	var addressed := Salutation.for_pc(context.tone, context.pc)
	if addressed.is_empty():
		return body
	if body.is_empty():
		return addressed
	return "%s %s" % [addressed, body]


## Render any list of lines — body, closing, or the prose on a reply option.
##
## Lines join into **flowing prose**, not concatenated fragments, so an empty
## insert leaves no double space and no orphaned comma behind it.
func render_lines(lines: Array, letter: Letter, context: LetterContext) -> String:
	var rendered: PackedStringArray = PackedStringArray()
	for line in lines:
		var text := render_line(line, letter, context)
		if not text.is_empty():
			rendered.append(text)
	return tidy(" ".join(rendered))


## Render one line, or "" if its tone gate excludes it.
func render_line(line: Dictionary, letter: Letter, context: LetterContext) -> String:
	# `only_tones` omits the line entirely for tones not listed.
	if line.has(LetterSchema.KEY_ONLY_TONES):
		var allowed: Array = line[LetterSchema.KEY_ONLY_TONES]
		if not allowed.has(String(context.tone)):
			return ""

	var text := String(line.get(LetterSchema.KEY_TEXT, ""))

	# A per-line `tone` override replaces the default **for that tone only**.
	var overrides: Variant = line.get(LetterSchema.KEY_TONE)
	if typeof(overrides) == TYPE_DICTIONARY and overrides.has(String(context.tone)):
		text = String(overrides[String(context.tone)])

	return tidy(resolve_slots(text, line, letter, context))


## Replace every slot in `text`.
func resolve_slots(text: String, line: Dictionary, letter: Letter, context: LetterContext) -> String:
	var out := text
	for slot in LetterSchema.slots_in(text):
		out = out.replace(slot["token"], _resolve(slot, line, letter, context))
	return out


func _resolve(slot: Dictionary, line: Dictionary, letter: Letter, context: LetterContext) -> String:
	var name: String = slot["name"]
	match StringName(slot["kind"]):
		LetterSchema.SLOT_PARAM:
			return _param(name, letter, context)
		LetterSchema.SLOT_PERCEPTION:
			return _perception(name, letter, context)
		LetterSchema.SLOT_SENDER:
			return context.sender_field(StringName(name))
		LetterSchema.SLOT_INSERT:
			return _insert(name, line, context)
	push_error("Unknown slot kind '%s' in '%s'." % [slot["kind"], letter.id])
	return ""


## An exact value. Whole numbers render without a decimal point: Godot's JSON
## parser hands back every number as a float, and "200.0" in front of a player is
## the mistake the whole typed-params contract exists to prevent.
func _param(name: String, letter: Letter, context: LetterContext) -> String:
	if not context.has_param(name):
		push_error("No value supplied for {param:%s}." % name)
		return ""
	var value: Variant = context.param(name)
	# **A head count reads as the man writing counts it** (#437,
	# `population.md` §7): counted heads from a town's own governor and the
	# Steward, an estimate in words from everybody else.
	if letter != null and String(letter.params.get(name, "")) == "people":
		var souls := Figures.headcount(float(value))
		return Figures.counted(souls) if _counts_heads(letter, context) else Figures.estimated(souls)
	if JsonTypes.is_int_like(value) and typeof(value) != TYPE_STRING:
		return str(JsonTypes.to_int(value, name))
	return str(value)


## Whether this letter's sender counts heads here (#437). The Steward always
## does; a governor only about **his own** town, which is the letter's `town`
## param when it has one, and his own when it has none.
func _counts_heads(letter: Letter, context: LetterContext) -> bool:
	var sender := context.sender
	if sender == null or sender.counts() != Contact.COUNTS_HEADS:
		return false
	if sender.role != Contact.ROLE_GOVERNOR:
		return true
	for name in letter.params:
		if String(letter.params[name]) != "town" or not context.has_param(String(name)):
			continue
		var about := String(context.param(String(name)))
		return about == sender.town or about == String(sender.id).trim_prefix("governor_")
	return true


## A biased judgment. The ladder is local to this letter; the lean belongs to the
## sender.
func _perception(name: String, letter: Letter, context: LetterContext) -> String:
	if not letter.perception.has(name):
		push_error("'%s' has no perception entry '%s'." % [letter.id, name])
		return ""
	var entry: Dictionary = letter.perception[name]
	var measure_id := String(entry.get(LetterSchema.KEY_MEASURE, ""))
	var ladder := PackedStringArray(entry.get(LetterSchema.KEY_LADDER, []))
	var lean: float = context.sender.lean_for(measure_id) if context.sender != null else 0.0
	# **The shape belongs to the sender too** (#279). It is a fact about how he
	# reads the world rather than about what he is reading, so it travels with his
	# lean and not with the ladder.
	var shape: StringName = \
		context.sender.lean_shape if context.sender != null else Perception.SHAPE_FLAT
	return Perception.word(measure_id, context.measure(measure_id), lean, ladder, shape)


## A tone-keyed fragment, local to its own line. **Missing renders as empty, not
## as a literal** — an insert with nothing to say for this tone simply says
## nothing.
func _insert(name: String, line: Dictionary, context: LetterContext) -> String:
	var inserts: Variant = line.get(LetterSchema.KEY_INSERT, {})
	if typeof(inserts) != TYPE_DICTIONARY or not inserts.has(name):
		return ""
	var by_tone: Variant = inserts[name]
	if typeof(by_tone) != TYPE_DICTIONARY:
		return ""
	return String(by_tone.get(String(context.tone), ""))


## Close the gaps an empty slot leaves behind.
##
## "You shall have 200 entire{insert:barb}." with nothing to say for this tone
## has to read "You shall have 200 entire.", not "... entire ." — the seam where
## a fragment was is exactly where prose stops flowing.
static func tidy(text: String) -> String:
	var out := text
	var spaces := RegEx.new()
	spaces.compile("[ \\t]{2,}")
	out = spaces.sub(out, " ", true)

	var before_punctuation := RegEx.new()
	before_punctuation.compile("[ \\t]+([%s])" % CLINGING_PUNCTUATION)
	out = before_punctuation.sub(out, "$1", true)

	var after_open := RegEx.new()
	after_open.compile("\\([ \\t]+")
	out = after_open.sub(out, "(", true)

	# A slot that vanished can leave a doubled comma behind it.
	var doubled := RegEx.new()
	doubled.compile(",[ \\t]*,")
	out = doubled.sub(out, ",", true)

	return out.strip_edges()
