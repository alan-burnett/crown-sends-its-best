class_name Relationship
extends RefCounted

## Where the PC and one contact stand.
##
## **Not a log of letters.** It is the state of the relationship: what has been
## granted and refused, what is still owed, and how long since the PC last
## wrote. **Loyalty** (SPEC §8.5) is the headline scalar inside it.
##
## **This is not a ledger.** SPEC §4 fixes Ledger as the gold screen and nothing
## else.
##
## The correspondence layer reads this alongside world state and the world diff.
## People react to change as much as to standing conditions, so all three
## inputs matter.

const MIN_LOYALTY: float = 0.0
const MAX_LOYALTY: float = 100.0
const NEUTRAL_LOYALTY: float = 50.0

# --- Deeds -----------------------------------------------------------------

const GRANTED: StringName = &"granted"
const REFUSED: StringName = &"refused"
const DELIVERED: StringName = &"delivered"
const PROMISE_BROKEN: StringName = &"promise_broken"
const IGNORED: StringName = &"ignored"

const DEEDS: Array[StringName] = [GRANTED, REFUSED, DELIVERED, PROMISE_BROKEN, IGNORED]

## **🔒 Deeds outweigh words** (SPEC §8.5). What the PC grants, refuses, promises
## and delivers moves loyalty far more than the tone of his letters, and silence
## has its own effect (SPEC §9.3).
##
## Tuning values. They are here rather than in a data file because they are
## balance, not content; they move to data the moment the PO wants to tune them
## without a build.
const DEED_WEIGHT: Dictionary = {
	GRANTED: 6.0,
	REFUSED: -5.0,
	DELIVERED: 8.0,
	PROMISE_BROKEN: -12.0,
	IGNORED: -7.0,
}

## Tone flavours how a letter lands and has **only a minor effect on loyalty**
## compared with what the letter actually grants or promises (SPEC §9.2).
##
## A table keyed per tone, never a scale: the five tones are not ordered.
const TONE_WEIGHT: Dictionary = {
	Tone.PLEASED: 0.6,
	Tone.DUTIFUL: 0.4,
	Tone.ANNOYED: -0.5,
	Tone.DESPERATE: -0.2,
	Tone.HATEFUL: -0.9,
}

var contact_id: StringName = &""

var loyalty: float = NEUTRAL_LOYALTY

## Promise ids the PC still owes this contact. The promise model itself is #17;
## this holds the reference so a contact knows what is outstanding.
var outstanding_promises: PackedStringArray = PackedStringArray()

## How many times each deed has happened. Deed kind -> count.
var deeds: Dictionary = {}

## The last world month the PC wrote. -1 means never.
var last_written_month: int = -1


func _init(p_contact_id: StringName = &"", p_loyalty: float = NEUTRAL_LOYALTY) -> void:
	contact_id = p_contact_id
	loyalty = clampf(p_loyalty, MIN_LOYALTY, MAX_LOYALTY)


# --- Loyalty ---------------------------------------------------------------

## Record something the PC did, and move loyalty by it.
##
## `scale` lets a caller say how big the deed was — granting 10 gold and granting
## 10,000 are both `GRANTED`. Returns the actual change after clamping, so a
## caller can report what really happened rather than what it asked for.
func record_deed(deed: StringName, scale: float = 1.0) -> float:
	if not DEEDS.has(deed):
		push_error("Unknown deed '%s'." % deed)
		return 0.0
	deeds[String(deed)] = int(deeds.get(String(deed), 0)) + 1
	return _move_loyalty(float(DEED_WEIGHT[deed]) * scale)


## Record the tone of a letter the PC sent.
func record_tone(tone: StringName) -> float:
	if not Tone.is_tone(tone):
		push_error("Unknown tone '%s'." % tone)
		return 0.0
	return _move_loyalty(float(TONE_WEIGHT[tone]))


## Move regard with the world rather than with a deed (#126).
##
## **Separate from `record_deed` on purpose.** A deed is a thing the PC did and
## belongs in the count that letters read back; drift is the weather, and adding
## it to the deed tally would have a contact remembering a bad winter as though
## the PC had refused him something.
func drift(delta: float) -> float:
	return _move_loyalty(delta)


func _move_loyalty(delta: float) -> float:
	var before := loyalty
	loyalty = clampf(loyalty + delta, MIN_LOYALTY, MAX_LOYALTY)
	return loyalty - before


func deed_count(deed: StringName) -> int:
	return int(deeds.get(String(deed), 0))


# --- Correspondence --------------------------------------------------------

func note_letter_sent(month: int) -> void:
	last_written_month = month


## Months since the PC last wrote. Feeds the `{sender:months_silent}` slot (#9).
##
## A contact never written to reports the months since the run began, which is
## the honest answer to "how long have you been ignoring me".
func months_silent(current_month: int) -> int:
	if last_written_month < 0:
		return maxi(0, current_month)
	return maxi(0, current_month - last_written_month)


func add_promise(promise_id: String) -> void:
	if not outstanding_promises.has(promise_id):
		outstanding_promises.append(promise_id)


## How many times the PC's word has not been kept to this contact, and when it
## last happened.
##
## **Counted, not just felt.** The loyalty drop is immediate; the letter that
## says so comes next month, and needs to know there is something to say.
var promises_broken: int = 0
var last_promise_broken_month: int = -1


## Clear a promise. `kept` false records the broken-promise deed, which costs
## loyalty whether it broke through lack of means or a Crown refusal
## (SPEC §9.5, §10.3).
##
## The month is remembered so the injured party can **write about it** rather
## than merely thinking less of the PC. A loyalty drop nobody mentions is a
## number moving in the dark, and the cascade this feeds is supposed to be
## watchable (#70).
func settle_promise(promise_id: String, kept: bool, month: int = -1) -> float:
	var index := outstanding_promises.find(promise_id)
	if index >= 0:
		outstanding_promises.remove_at(index)
	if not kept:
		promises_broken += 1
		last_promise_broken_month = month
	return record_deed(DELIVERED if kept else PROMISE_BROKEN)


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"contact_id": String(contact_id),
		"loyalty": loyalty,
		"promises_broken": promises_broken,
		"last_promise_broken_month": last_promise_broken_month,
		"outstanding_promises": outstanding_promises.duplicate(),
		"deeds": deeds.duplicate(),
		"last_written_month": last_written_month,
	}


static func from_dict(data: Dictionary) -> Relationship:
	var relationship := Relationship.new(
		StringName(data.get("contact_id", "")),
		float(data.get("loyalty", NEUTRAL_LOYALTY)),
	)
	relationship.outstanding_promises = PackedStringArray(data.get("outstanding_promises", []))
	relationship.deeds = data.get("deeds", {}).duplicate()
	relationship.last_written_month = int(data.get("last_written_month", -1))
	relationship.promises_broken = int(data.get("promises_broken", 0))
	relationship.last_promise_broken_month = int(data.get("last_promise_broken_month", -1))
	return relationship
