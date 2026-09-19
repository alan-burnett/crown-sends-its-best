class_name Letter
extends RefCounted

## A letter template, as loaded from `data/letters_<lang>/`.
##
## The file reads top to bottom as the player's experience: the letter you read,
## your reply options, the letter you write.
##
## **Whether this letter fires is not in here.** That lives in
## `data/triggers/*.json` (#14). Two engines stay apart: one decides whether a
## letter is sent and with what values, the other decides how it reads. `params`
## is the typed contract between them — the file declares, the director supplies.

var id: String = ""
var sender: String = ""
var type: StringName = &""

## Whether the volume system may cull this letter when the desk is over budget
## (#14). An unskippable letter always reaches the desk.
var skippable: bool = true

## Declared param name -> declared type. **A contract, not a generator.**
var params: Dictionary = {}

## Slot name -> `{measure, ladder}`. Ladders are **local to the letter that uses
## them**: the same measure can carry entirely different words elsewhere.
var perception: Dictionary = {}

var body: Array = []
var reply: Dictionary = {}

## Set on a **player-initiated** letter (#19): what the player is writing about,
## in his own words. A letter with a purpose and no body is composable.
var purpose: String = ""

## Which contact roles this purpose makes sense for. Empty means anyone.
var to_roles: PackedStringArray = PackedStringArray()

## Values for the letter's declared params when the player composes it, since
## there is no incoming letter to have carried them.
var compose_defaults: Dictionary = {}

var source_file: String = ""


static func from_record(record: Dictionary) -> Letter:
	var letter := Letter.new()
	letter.id = String(record.get(LetterSchema.KEY_ID, ""))
	letter.sender = String(record.get(LetterSchema.KEY_SENDER, ""))
	letter.type = StringName(record.get(LetterSchema.KEY_TYPE, ""))
	letter.skippable = bool(record.get(LetterSchema.KEY_SKIPPABLE, true))
	letter.params = record.get(LetterSchema.KEY_PARAMS, {}).duplicate()
	letter.perception = record.get(LetterSchema.KEY_PERCEPTION, {}).duplicate(true)
	letter.body = record.get(LetterSchema.KEY_BODY, []).duplicate(true)
	letter.reply = record.get(LetterSchema.KEY_REPLY, {}).duplicate(true)
	letter.purpose = String(record.get(LetterSchema.KEY_PURPOSE, ""))
	letter.to_roles = PackedStringArray(record.get(LetterSchema.KEY_TO_ROLES, []))
	letter.compose_defaults = record.get(LetterSchema.KEY_COMPOSE_DEFAULTS, {}).duplicate(true)
	letter.source_file = String(record.get(JsonLoader.SOURCE_KEY, ""))
	return letter


## **The same file shape as a reply, minus the `body`.** One format, not two.
func is_composable() -> bool:
	return not purpose.is_empty() and body.is_empty()


## **A letter with no reply block is valid** — reports and news need no response.
func has_reply() -> bool:
	return not reply.is_empty()


## Whether the reply offers a tone. **Not every outgoing letter has a tone**
## (SPEC §9.2).
func has_tone_step() -> bool:
	return reply.has(LetterSchema.KEY_TONE)


## The tones this letter offers. A letter may offer **any subset** of the five.
func offered_tones() -> Array[StringName]:
	var out: Array[StringName] = []
	if not has_tone_step():
		return out
	for option in reply[LetterSchema.KEY_TONE].get(LetterSchema.KEY_OPTIONS, []):
		out.append(StringName(option.get(LetterSchema.KEY_TONE, "")))
	return out


func steps() -> Array:
	return reply.get(LetterSchema.KEY_STEPS, [])


func closing() -> Array:
	return reply.get(LetterSchema.KEY_CLOSING, [])


## Whether silence on this letter is a rude refusal, a decision made without the
## PC, or nothing at all (SPEC §9.3). Derived from `type`, so the Author never
## authors it.
func silence_is_refusal() -> bool:
	return LetterSchema.TYPES_ASKING_FOR_SOMETHING.has(type)


func silence_is_a_decision() -> bool:
	return LetterSchema.TYPES_ASKING_A_DECISION.has(type)
