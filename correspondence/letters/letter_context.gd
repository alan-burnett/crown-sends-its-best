class_name LetterContext
extends RefCounted

## What is known while a letter is being judged and rendered.
##
## The correspondence layer reads **world state, the world diff, and
## Relationship** together. People react to change as much as to standing
## conditions, so "revenue fell by a third" and "revenue is low" are different
## letters and need different inputs.
##
## The same object serves trigger conditions (#14) and the renderer (#9), so a
## condition and a slot can never disagree about what month it is.

var state: WorldState = null
var diff: WorldDiff = null

## Who is writing. Supplies `{sender:}` fields and the perception leans.
var sender: Contact = null

var month: int = 0

## Values the director supplied against the letter's declared `params` (#14).
## **Exact and truthful** — this is the quantities half of SPEC §9.1.
var params: Dictionary = {}

## Raw sim values for the letter's `perception` entries, keyed by measure id.
## The **judgments** half: biased on the way out, never false.
var measures: Dictionary = {}

## The one tone id the director computed for this letter (SPEC §9.1).
## Downstream code treats tone as opaque and never re-derives circumstance
## from it.
var tone: StringName = &""

## The Order an acknowledgement is about, where there is one. Lets a letter say
## what it was you asked for without the director having to flatten it first.
var data_order: Order = null

## Whether the Crown is still honouring the PC's word, and how long he has.
##
## **The band, the window and the deadline — never the standing figure.** A
## letter that could read the number is a letter that would eventually print it
## (SPEC §10.3), and `tools/lint.gd` keeps `presentation/` away from it too.
var refusal: CrownRefusal = null

## **What the court makes of the PC** (#76, SPEC §14.1, `prestige.md` §7).
##
## Here because §7 makes Crown officers the audible channel and says it should be
## working there **before patrons ever exist**. A letter may ask whether the
## court is warming or cooling; it may never render the figure, and `tools/lint.gd`
## keeps `presentation/` away from the class entirely.
var prestige: Prestige = null

## How hard the Crown is leaning, and along which axis it last leaned harder.
##
## **What the Crown did, not what it is worth.** A letter may ask whether the
## bar moved this month and which way; the magnitudes belong to the director and
## reach the prose as declared `params`, the same rule that keeps the standing
## figure off the page (SPEC §10.3).
var demands: DemandGrowth = null

## What the Crown asked for this month, if it asked for anything.
var demand_book: DemandBook = null

## The standing instructions the PC has bought (#80).
##
## **What is owed and by whom**, so a man about to let one lapse can say so and
## the letter can name the charge. Never the loyalty it is costing him — that is
## his own business, like every other regard in the game.
var policies: PolicyBook = null

## Who the PC is (#79).
##
## **Flavour, and the letters are the whole of what it is for.** SPEC §5 makes
## the name, title, portrait and colour mechanically inert, so this is here to
## be addressed by and for nothing else — no condition reads it and no effect
## takes it.
var pc: RunSetup = null

## The run's event log.
##
## **What happened, which is the only thing a letter may react to** (Seam A). A
## condition that needs to know a town came home reads the event that said so
## rather than inferring it from a flag that looks the same as never having left.
var log: EventLog = null

## The town this letter is about, when the sender speaks for one.
##
## **A governor's letter is about a place**, and the conditions that decide
## whether he writes at all need to see it. Null for the Crown's officers, who
## write about the colony and have no town of their own.
var town: Town = null

## **Everyone the PC corresponds with**, for the one contact who reports on other
## contacts (#81, `the-diplomat.md` §2).
##
## The Diplomat's home-town reporting is the intent, loyalty and relationship of
## the governor and every other man living there — the sharpest intelligence in
## the game, covering exactly one town. Nothing else needs this.
var contacts: Dictionary = {}

## **Every town**, for the one contact who is aware of all of them (#81).
##
## The Diplomat reports on the colony and most sharply on the town he lives in,
## so he is the only sender who needs more than his own. Nothing else reads it.
var colony: Colony = null

## The peoples already here (#208, `natives.md` §1).
##
## 🔒 **Nothing about a tribe reaches the PC except through his own people.**
## They are here so a governor's letter can say *which* people he borders and a
## condition can ask whether he borders any — never so a letter can render what
## they think of him. The figure goes through a `{perception:}` ladder or it does
## not go at all.
var natives: Tribes = null


func _init(p_state: WorldState = null, p_sender: Contact = null, p_tone: StringName = &"") -> void:
	state = p_state
	sender = p_sender
	tone = p_tone
	if state != null:
		month = state.month


func param(name: String, default_value: Variant = null) -> Variant:
	return params.get(name, default_value)


func has_param(name: String) -> bool:
	return params.has(name)


func measure(id: String, default_value: float = 0.0) -> float:
	return float(measures.get(id, default_value))


func loyalty() -> float:
	return sender.loyalty() if sender != null else Relationship.NEUTRAL_LOYALTY


## A whitelisted contact field. **Not open field access** — the list is fixed so
## the validator can check it and renaming a field in code cannot silently break
## hundreds of letter files.
func sender_field(field: StringName) -> String:
	if sender == null:
		return ""
	match field:
		&"name":
			return sender.display_name
		&"title":
			return sender.title
		&"town":
			return sender.town
		&"months_silent":
			return str(sender.relationship.months_silent(month))
	push_error("'%s' is not on the sender whitelist." % field)
	return ""
