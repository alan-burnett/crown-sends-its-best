class_name Salutation
extends RefCounted

## How a letter addresses the PC (#358, `docs/mechanics/names.md` §2).
##
## > *pleased* — **To the most noble Lord Frank Zappa**
## > *hateful* — **To the despicable Frank Zappa**
##
## ## 🔒 The whole line is tone-keyed, not an adjective in front of a fixed name
##
## **Note what the hateful form does: it drops the title.** A contact refusing
## the PC his style is doing something, and it is something the prose has to be
## able to say. That is why this is a line per tone with two slots rather than a
## table of adjectives — a form that leaves `{title}` out withholds it, and
## nothing in the code has to know that withholding is a thing.
##
## It is the other end of §2 from `Letterhead`: that one is how a **sender** is
## shown, this is how the **PC** is addressed, and they move on different axes —
## a letterhead is fixed by the man's role and this one by his mood.
##
## ## 🔒 One place, not a line in every letter file
##
## The salutation is a property of how the PC is addressed, which is the same for
## every letter of a given tone. A copy at the top of each of eighty files would
## be eighty things to reword, and the ones that drifted would be the ones nobody
## opened — and a letter authored next year would simply forget.
##
## So it is prepended to the body, and a letter file says nothing about it. Four
## Chancellor letters opened with a hand-rolled `{param:pc_title} {param:pc_name}.`
## and have lost it: it is now said once, and said better, because it moves.
##
## Prose lives in `data/clauses_en/salutation.json`, so a second language is a
## copied folder in which only the strings change — the same arrangement
## `HarshClause` uses and for the same reason.

const COLLECTION: String = "clauses"
const RECORD: String = "salutation"

const TITLE_SLOT: String = "{title}"
const NAME_SLOT: String = "{name}"

static var _by_tone: Dictionary = {}
static var _default: String = ""


static func load_from(record: Dictionary) -> void:
	_by_tone = record.get("by_tone", {}).duplicate()
	_default = String(record.get("default", ""))


static func reset() -> void:
	_by_tone = {}
	_default = ""


## The form for this tone, with the slots still in it.
##
## **The default is not an error case.** A letter with no tone is still a letter
## addressed to somebody, and it is addressed in the plain register.
static func form(tone: StringName) -> String:
	return String(_by_tone.get(String(tone), _default))


## The line as the PC reads it.
##
## Empty when there is no PC to address — a letter rendered outside a run, which
## the content validator does constantly — so the body is simply the body and
## nothing renders with a hole where a name should be.
static func for_pc(tone: StringName, pc: RunSetup) -> String:
	if pc == null:
		return ""
	var line := form(tone)
	if line.is_empty():
		return ""
	# 🔒 **Trimmed, and then tidied.** `names.md` §1 puts a minimum of one on both
	# fields *after trimming*, so there is no nameless PC and nothing here needs a
	# fallback for one. What this does handle is a form that leaves `{title}` out,
	# which leaves a space behind it that the reader would see.
	return LetterRenderer.tidy(
		line.replace(TITLE_SLOT, pc.pc_title.strip_edges())
			.replace(NAME_SLOT, pc.pc_name.strip_edges()))
