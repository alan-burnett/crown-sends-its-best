class_name HarshClause
extends RefCounted

## The one sentence a harsh letter adds (#263, `docs/mechanics/tone.md` §9).
##
## ## 🔒 A second axis, not a sixth tone
##
## A **yes-or-no the wizard asks after the tone is set**, and the two are
## orthogonal: five tones times harsh-or-not is **ten registers**.
##
## | | |
## | :--- | :--- |
## | **Always** | a loyalty loss, and the town remembers it if it bore the order |
## | **Directing** | push toward comply and partial |
## | **Asking** | push toward comply and partial, **and a larger partial** |
## | **Answering** | **not offered at all** |
##
## ## Saying yes adds one sentence and nothing else
##
## The sentence is **tone-keyed**, which is the whole reason the two axes
## multiply: the same flag reads as velvet from a pleased PC —
##
## > *Please see to this matter most promptly, lest we allow room for
## > unpleasantness.*
##
## — and as a threat from an annoyed one:
##
## > *Failure to meet this requirement will be met with most dire consequences.*
##
## Saying no adds nothing at all. **A harsh letter is a letter with one more line
## in it**, and that line is what the governor's town remembers
## (`rebel-sentiment.md` §4).
##
## ## 🔒 Harsh and urgency are on opposite sides of the desk
##
## | | Set by | Direction | Feeds |
## | :--- | :--- | :--- | :--- |
## | **harsh** | **the player** | **outbound** | compliance, rebel sentiment |
## | **urgency** | **the trigger author** | **inbound only** | the sender's choice of tone |
##
## They sound alike and have nothing to do with each other. **The PC never sets
## urgency and a contact never sets harshness**, and a dev who wires either
## across the desk has joined two unrelated systems.
##
## Prose lives in `data/clauses_en/harsh.json`, so a second language is a copied
## folder in which only the strings change.

const COLLECTION: String = "clauses"
const RECORD: String = "harsh"

static var _by_tone: Dictionary = {}
static var _default: String = ""
static var _prompt: String = ""
static var _yes: String = ""
static var _no: String = ""


static func load_from(record: Dictionary) -> void:
	_by_tone = record.get("by_tone", {}).duplicate()
	_default = String(record.get("default", ""))
	_prompt = String(record.get("prompt", ""))
	_yes = String(record.get("yes", ""))
	_no = String(record.get("no", ""))


static func reset() -> void:
	_by_tone = {}
	_default = ""
	_prompt = ""
	_yes = ""
	_no = ""


## The question the wizard puts.
static func prompt() -> String:
	return _prompt


## `[{id, harsh, label}]` — the two answers, in the order the player reads them.
static func options() -> Array[Dictionary]:
	return [
		{"id": "lean", "harsh": true, "label": _yes},
		{"id": "leave_it", "harsh": false, "label": _no},
	]


## The sentence, in the manner the rest of the letter was written.
##
## **The default is not an error case.** A letter with no tone step is still a
## letter that can lean on a man, and it leans in the plain register.
static func sentence(tone: StringName) -> String:
	return String(_by_tone.get(String(tone), _default))
