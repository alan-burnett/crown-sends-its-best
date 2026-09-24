class_name CutsceneTriggers
extends RefCounted

## Which cutscenes a month earned, and in what order (#298,
## `docs/mechanics/cutscenes.md` §2, §3, §4).
##
## ## Three kinds, and only two of them are here
##
## | Kind | Fires |
## | :--- | :--- |
## | **first** | the first time ever in the run |
## | **recurring** | the first time **each turn** |
## | **bookend** | scripted, at run start and run end — *not by this* |
##
## Bookends compete with nothing and are shown by whoever opens or closes the
## run. Everything else fires **from the event log**, and the desk is in it: a
## contact refusing an order or acting without asking is an event
## (`order_refused`, `contact_acted_alone`) exactly as a battle is. One trigger
## source, not two (§2).
##
## ## 🔒 As many as the month earned, in the order they happened
##
## **No budget, no deferral, no expiry** (§3). A turn plays every cutscene it
## triggered, ordered by the `seq` of the event that triggered it — the order
## things happened inside the month, which is the order the map has just played
## them in. What keeps this from being a slideshow is the catalog, not a cap:
## almost everything in it is a first, and a first fires once a run.
##
## ## 🔒 A recurrence is once a turn, and never in its first's turn
##
## One protest painting however many towns protest; and *Shots Exchanged* does
## not follow *The First Blood* in the same turn, because they are the same event
## seen twice and the first turn gets the painting that will not come again.
##
## ## The shape of a trigger
##
## ```
## {"cutscene": "landfall", "kind": "first", "on": {"event_happened": {"event": "town_founded"}}}
## {"cutscene": "shots_exchanged", "kind": "recurring", "after": "the_first_blood",
##  "on": {"event_happened": {"event": "battle_fought"}}}
## ```
##
## `on` names a condition in `CONDITIONS` — **an id into a code-side registry,
## never logic in a data file** (`CLAUDE.md`, §5). The records live beside the
## letters' in `data/triggers`, told apart by naming a `cutscene` rather than a
## `letter`; the catalog and its validator are #299.

const FIRST: String = "first"
const RECURRING: String = "recurring"
const BOOKEND: String = "bookend"
const KINDS: PackedStringArray = ["bookend", "first", "recurring"]

const KEY_CUTSCENE: String = "cutscene"
const KEY_KIND: String = "kind"
const KEY_ON: String = "on"
## A recurrence names the first it follows, so it can stand aside in that turn.
const KEY_AFTER: String = "after"

## The conditions a trigger may name, with their params. Matched in `_matches`;
## a row here and a branch there, and nothing callable is held (`CLAUDE.md`).
const CONDITIONS: Dictionary = {
	"event_happened": {"event": "string"},
}


## Every cutscene trigger in the content: the trigger records that name a
## cutscene, in id order.
static func from_content(content: ContentDatabase) -> Array:
	var out: Array = []
	if content == null:
		return out
	for id in content.ids("triggers"):
		var record: Dictionary = content.record("triggers", id)
		if record.has(KEY_CUTSCENE):
			out.append(record)
	return out


## The cutscenes these events earned, as `{cutscene, kind, seq}`, in the order
## they happened. **Pure**: `seen` — the firsts already shown this run — is read
## and not written. `record` writes it.
static func fired(triggers: Array, events: Array, seen: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var firsts_now: Dictionary = {}

	for trigger in _in_order(triggers):
		if String(trigger.get(KEY_KIND, "")) != FIRST:
			continue
		var cutscene := String(trigger.get(KEY_CUTSCENE, ""))
		if seen.has(cutscene):
			continue
		var because := _first_match(trigger, events)
		if because == null:
			continue
		firsts_now[cutscene] = true
		out.append({"cutscene": cutscene, "kind": FIRST, "seq": because.seq})

	for trigger in _in_order(triggers):
		if String(trigger.get(KEY_KIND, "")) != RECURRING:
			continue
		# 🔒 Never in the turn its first fired.
		if firsts_now.has(String(trigger.get(KEY_AFTER, ""))):
			continue
		var because := _first_match(trigger, events)
		if because == null:
			continue
		out.append({
			"cutscene": String(trigger.get(KEY_CUTSCENE, "")),
			"kind": RECURRING,
			"seq": because.seq,
		})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["seq"]) != int(b["seq"]):
			return int(a["seq"]) < int(b["seq"])
		return String(a["cutscene"]) < String(b["cutscene"]))
	return out


## Remember the firsts that fired, against the turn they fired in.
static func record(due: Array, seen: Dictionary, turn: int) -> void:
	for entry in due:
		if String(entry["kind"]) == FIRST:
			seen[String(entry["cutscene"])] = turn


## Just the ids, in order.
static func ids_of(due: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in due:
		out.append(String(entry["cutscene"]))
	return out


## The earliest event this trigger's condition matches, or null.
static func _first_match(trigger: Dictionary, events: Array) -> SimEvent:
	var on: Variant = trigger.get(KEY_ON, {})
	if typeof(on) != TYPE_DICTIONARY or (on as Dictionary).size() != 1:
		return null
	var condition_id := String((on as Dictionary).keys()[0])
	var args: Variant = on[condition_id]
	if typeof(args) != TYPE_DICTIONARY:
		return null
	for entry in events:
		var event: SimEvent = entry
		if _matches(condition_id, args, event):
			return event
	return null


static func _matches(condition_id: String, args: Dictionary, event: SimEvent) -> bool:
	match condition_id:
		"event_happened":
			return String(event.type) == String(args.get("event", ""))
	return false


## Triggers sorted by cutscene id, so nothing depends on how the files loaded.
static func _in_order(triggers: Array) -> Array:
	var out := triggers.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get(KEY_CUTSCENE, "")) < String(b.get(KEY_CUTSCENE, "")))
	return out
