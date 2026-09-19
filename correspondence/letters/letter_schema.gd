class_name LetterSchema
extends RefCounted

## The vocabulary of a letter file, in one place, so the validator and the
## renderer cannot drift apart.
##
## **Letters are data** (SPEC §9.7). Templates, conditions, options, tones and
## effects live in files so the Author can add content without engine changes.
## The Author writes hundreds of these by hand, which is why the validator (#8)
## has to catch a mistake at build time rather than render
## `I require {param:amount}` in front of a player.

# --- Letter types (SPEC §9.1) ----------------------------------------------

const TYPE_REPORT: StringName = &"report"
const TYPE_QUESTION: StringName = &"question"
const TYPE_REQUEST: StringName = &"request"
const TYPE_DEMAND: StringName = &"demand"
const TYPE_WARNING: StringName = &"warning"
const TYPE_NEWS: StringName = &"news"
const TYPE_OFFER: StringName = &"offer"

const TYPES: Array[StringName] = [
	TYPE_REPORT, TYPE_QUESTION, TYPE_REQUEST, TYPE_DEMAND, TYPE_WARNING, TYPE_NEWS, TYPE_OFFER,
]

## Types that ask the PC for something. Silence on one of these is a **rude
## refusal** and costs loyalty (SPEC §9.3), which is what separates an ignored
## letter from a culled one (#14, #18).
const TYPES_ASKING_FOR_SOMETHING: Array[StringName] = [TYPE_REQUEST, TYPE_DEMAND, TYPE_OFFER]

## Types that ask the PC to decide. Silence means the sender decides for himself.
const TYPES_ASKING_A_DECISION: Array[StringName] = [TYPE_QUESTION]

# --- Param types (#8) ------------------------------------------------------

## **`params` is a typed contract, not a generator.** The file declares what it
## expects; the director (#14) supplies the values. The letter file never
## re-decides what it is about.
const PARAM_TYPES: Array[StringName] = [
	&"resource", &"integer", &"gold", &"town", &"contact",
	&"tribe", &"rival", &"tile", &"building", &"objective",
]

## Param types that are whole numbers.
##
## Godot's JSON parser returns every number as a float, so a declared integer has
## to be coerced on the way in or `{param:amount}` renders "200.0" at the player.
const NUMERIC_PARAM_TYPES: Array[StringName] = [&"integer", &"gold"]

# --- Slots (#9) ------------------------------------------------------------

const SLOT_PARAM: StringName = &"param"
const SLOT_PERCEPTION: StringName = &"perception"
const SLOT_SENDER: StringName = &"sender"
const SLOT_INSERT: StringName = &"insert"

## Four kinds and no others. An unknown kind is an error rather than a literal
## left in the prose.
const SLOT_KINDS: Array[StringName] = [SLOT_PARAM, SLOT_PERCEPTION, SLOT_SENDER, SLOT_INSERT]

## **A fixed whitelist, not open field access**, so the validator can check it
## and renaming a field in code does not silently break hundreds of letter files.
const SENDER_FIELDS: Array[StringName] = [&"name", &"title", &"town", &"months_silent"]

## Where a tone option's wording drops into the line that offers it:
## `"Your letter finds me {choice}."` It has no `kind:name` shape, so it is not a
## slot and the validator leaves it alone. The reply wizard (#15) substitutes it.
const CHOICE_TOKEN: String = "{choice}"

## Matches `{kind:name}`.
const SLOT_PATTERN: String = "\\{(?<kind>[a-z_]+):(?<name>[a-zA-Z0-9_.]+)\\}"

# --- Keys ------------------------------------------------------------------

const KEY_ID: String = "id"
const KEY_SENDER: String = "sender"
const KEY_TYPE: String = "type"
const KEY_SKIPPABLE: String = "skippable"
const KEY_PARAMS: String = "params"
const KEY_PERCEPTION: String = "perception"
const KEY_BODY: String = "body"
const KEY_REPLY: String = "reply"
const KEY_TEXT: String = "text"
const KEY_TONE: String = "tone"
const KEY_ONLY_TONES: String = "only_tones"
const KEY_OPTIONS: String = "options"
const KEY_STEPS: String = "steps"
const KEY_CLOSING: String = "closing"
const KEY_PROMPT: String = "prompt"
const KEY_LABEL: String = "label"
const KEY_EFFECT: String = "effect"
const KEY_INSERT: String = "insert"
const KEY_MEASURE: String = "measure"
const KEY_PURPOSE: String = "purpose"
const KEY_TO_ROLES: String = "to_roles"
const KEY_COMPOSE_DEFAULTS: String = "compose_defaults"
const KEY_LADDER: String = "ladder"


static func is_type(value: StringName) -> bool:
	return TYPES.has(value)


static func is_param_type(value: StringName) -> bool:
	return PARAM_TYPES.has(value)


static func is_slot_kind(value: StringName) -> bool:
	return SLOT_KINDS.has(value)


static func is_sender_field(value: StringName) -> bool:
	return SENDER_FIELDS.has(value)


## Every slot in a line, as `{kind, name, token}` dictionaries, in order.
static func slots_in(text: String) -> Array[Dictionary]:
	var regex := RegEx.new()
	regex.compile(SLOT_PATTERN)
	var found: Array[Dictionary] = []
	for result in regex.search_all(text):
		found.append({
			"kind": StringName(result.get_string("kind")),
			"name": result.get_string("name"),
			"token": result.get_string(),
		})
	return found
