class_name ReplyWizard
extends RefCounted

## The mad-libs reply: the player fills blanks from short lists, and the game
## assembles a flowing, period-style letter in the PC's voice (SPEC §9.2).
##
## The file reads top to bottom as the player's experience: the letter you read,
## your reply options, the letter you write. This walks the second and third of
## those.
##
## **This is the wizard's logic, not its screen.** #22 draws it. Keeping them
## apart is what lets the under-a-minute target be tested without a viewport,
## and what lets composing (#19) reuse the whole thing rather than a copy of it.
##
## **The wizard never writes sim state.** It edits an `OutgoingLetter`; effects
## fire through the registry and produce Orders only when the post is sent.

var letter: Letter = null
var outgoing: OutgoingLetter = null
var renderer: LetterRenderer = null


func _init(p_letter: Letter = null, p_outgoing: OutgoingLetter = null) -> void:
	letter = p_letter
	outgoing = p_outgoing
	renderer = LetterRenderer.new()


# --- Tone ------------------------------------------------------------------

## **Not every outgoing letter has a tone** (SPEC §9.2).
func has_tone_step() -> bool:
	return letter.has_tone_step()


## How many characters of blank stand in for the unchosen wording.
const BLANK: String = "______"


## The question this letter phrases in its own words: *"Your letter finds me
## ______."* The `tone` id is the fixed global key; the wording is written fresh
## per letter, and a letter may offer **any subset** of the five.
##
## The insertion point renders as a **blank to be filled**, which is the whole
## mad-libs conceit — and stops the raw `{choice}` token reaching the player,
## which is what it did before anybody looked at the screen.
func tone_prompt() -> String:
	if not has_tone_step():
		return ""
	var phrasing := String(letter.reply[LetterSchema.KEY_TONE].get(LetterSchema.KEY_TEXT, ""))
	return phrasing.replace(LetterSchema.CHOICE_TOKEN, BLANK)


## `[{tone, text}]` in the order the letter offers them.
func tone_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_tone_step():
		return out
	for option in letter.reply[LetterSchema.KEY_TONE].get(LetterSchema.KEY_OPTIONS, []):
		out.append({"tone": StringName(option.get(LetterSchema.KEY_TONE, "")), "text": String(option.get(LetterSchema.KEY_TEXT, ""))})
	return out


func choose_tone(tone: StringName) -> bool:
	for option in tone_options():
		if option["tone"] == tone:
			outgoing.tone = tone
			return true
	push_error("'%s' is not offered by '%s'." % [tone, letter.id])
	return false


# --- Harsh, the second axis -------------------------------------------------

## 🔒 **Asked after the tone, and never when answering** (#263, `tone.md` §9).
##
## The two are orthogonal, so this is a step of its own rather than a sixth tone
## — five tones times harsh-or-not is **ten registers.** It is not offered on an
## answering letter because there is nothing to lean on: *you* are the one
## deciding, and *do it or else* has no object.
func has_harsh_step() -> bool:
	return LetterKind.may_be_harsh(letter)


func harsh_prompt() -> String:
	return HarshClause.prompt() if has_harsh_step() else ""


func harsh_options() -> Array[Dictionary]:
	return HarshClause.options() if has_harsh_step() else [] as Array[Dictionary]


func choose_harsh(harsh: bool) -> bool:
	if not has_harsh_step():
		push_error("'%s' cannot be written harshly." % letter.id)
		return false
	outgoing.harsh = harsh
	outgoing.choose(HARSH_STEP, "lean" if harsh else "leave_it")
	return true


## The step id the answer is recorded under, so *not yet asked* and *asked and
## declined* are different states — a letter is not finished until he has said.
const HARSH_STEP: String = "_harsh"


# --- Steps -----------------------------------------------------------------

func steps() -> Array:
	return letter.steps()


## The first step still unanswered, or -1 when the letter is finished.
func next_step_index() -> int:
	if has_tone_step() and outgoing.tone.is_empty():
		return 0
	var all_steps := steps()
	for index in all_steps.size():
		if not outgoing.has_chosen(String(all_steps[index].get("id", ""))):
			return index
	return -1


## Whether the wizard still owes the player the harsh question.
func harsh_is_pending() -> bool:
	return has_harsh_step() and not outgoing.has_chosen(HARSH_STEP)


func step_prompt(index: int) -> String:
	var all_steps := steps()
	if index < 0 or index >= all_steps.size():
		return ""
	return String(all_steps[index].get(LetterSchema.KEY_PROMPT, ""))


## The options for a step, each with the **label the player reads**.
##
## **🔒 Every choice's mechanical effect can be understood from its wording.**
## Exact numbers may stay hidden, but the player is never misled about what he is
## ordering — so the label is rendered through the same slot machinery as the
## prose, and `{param:amount}` in a label shows the real figure.
func options_for(index: int, context: LetterContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all_steps := steps()
	if index < 0 or index >= all_steps.size():
		return out
	for option in all_steps[index].get(LetterSchema.KEY_OPTIONS, []):
		out.append({
			"id": String(option.get("id", "")),
			"label": renderer.resolve_slots(String(option.get(LetterSchema.KEY_LABEL, "")), option, letter, context),
			"effect": option.get(LetterSchema.KEY_EFFECT, {}),
		})
	return out


func choose(step_id: String, option_id: String) -> bool:
	for step in steps():
		if String(step.get("id", "")) != step_id:
			continue
		for option in step.get(LetterSchema.KEY_OPTIONS, []):
			if String(option.get("id", "")) == option_id:
				outgoing.choose(step_id, option_id)
				return true
	push_error("'%s' offers no option '%s' at step '%s'." % [letter.id, option_id, step_id])
	return false


func is_complete() -> bool:
	return outgoing.is_complete(letter) and not harsh_is_pending()


# --- The letter the player writes ------------------------------------------

## Assemble the reply.
##
## **Continuous prose, not concatenated fragments.** The tone line, the chosen
## options in step order, and the closing, run together and tidied — an empty
## insert leaves no double space and no orphaned comma behind it.
##
## Tone changes the wording **throughout**, not only the opening: every line
## resolves against the chosen tone, so inserts fill, `only_tones` lines appear
## or vanish, and per-line overrides swap.
func assemble(context: LetterContext) -> String:
	context.tone = outgoing.tone
	var parts: PackedStringArray = PackedStringArray()

	var opening := _tone_line(context)
	if not opening.is_empty():
		parts.append(opening)

	for step in steps():
		var step_id := String(step.get("id", ""))
		if not outgoing.has_chosen(step_id):
			continue
		var option := _option(step, outgoing.chosen_for(step_id))
		if option.is_empty():
			continue
		var text := renderer.render_line(option, letter, context)
		if not text.is_empty():
			parts.append(text)

	# 🔒 **One sentence, and nothing else about the letter changes** (#263,
	# §9). Before the closing, because it is the last thing he says rather than
	# how he signs off — and keyed by the tone, which is what makes harsh a second
	# axis instead of a sixth entry in the first.
	if outgoing.harsh:
		var clause := HarshClause.sentence(outgoing.tone)
		if not clause.is_empty():
			parts.append(renderer.resolve_slots(clause, {}, letter, context))

	var closing := renderer.render_lines(letter.closing(), letter, context)
	if not closing.is_empty():
		parts.append(closing)

	return LetterRenderer.tidy(" ".join(parts))


## The opening, with the chosen wording dropped into the letter's own phrasing.
func _tone_line(context: LetterContext) -> String:
	if not has_tone_step() or outgoing.tone.is_empty():
		return ""
	var block: Dictionary = letter.reply[LetterSchema.KEY_TONE]
	var phrasing := String(block.get(LetterSchema.KEY_TEXT, ""))
	for option in block.get(LetterSchema.KEY_OPTIONS, []):
		if StringName(option.get(LetterSchema.KEY_TONE, "")) == outgoing.tone:
			var wording := renderer.resolve_slots(String(option.get(LetterSchema.KEY_TEXT, "")), option, letter, context)
			phrasing = phrasing.replace(LetterSchema.CHOICE_TOKEN, wording)
			break
	return LetterRenderer.tidy(renderer.resolve_slots(phrasing, {}, letter, context))


func _option(step: Dictionary, option_id: String) -> Dictionary:
	for option in step.get(LetterSchema.KEY_OPTIONS, []):
		if String(option.get("id", "")) == option_id:
			return option
	return {}
