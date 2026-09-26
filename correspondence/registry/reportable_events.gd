class_name ReportableEvents
extends RefCounted

## 🔒 **What a letter may report, and how** (#398, `the-director.md` §2, §8;
## SPEC §9.1).
##
## Many events were emitted and read by nothing, so no letter could report them:
## a tribe's gift, a trade that closed, a hamlet founded, an expedition set upon,
## a duke gone to war, a tribute paid. One condition (`it_happened`) and one param
## source (`what_happened`) read any event listed here, rather than a bespoke pair
## per event.
##
## **Listed, not open.** A letter names an event id the way `world_value_above`
## names a world key — but only an event in this table, because the table is what
## says whom the event concerns and which of its fields a letter may print, and
## as what. A letter pointed at an event whose payload it does not understand is
## the failure the bespoke design would have prevented; this prevents it by
## keeping the understanding here, in code, where the validator can ask it.
##
## Adding an event is adding a row.

## Whom a report is about, as a letter asks it.
const CONCERNING_HIM: String = "him"
const CONCERNING_HIS_TOWN: String = "his_town"
const CONCERNING_THE_COLONY: String = "the_colony"
const CONCERNS: PackedStringArray = ["him", "his_town", "the_colony"]

## Event id -> which payload key names the man it concerns (`man`), which names
## the town (`town`), and the fields a letter may read, each with the letter
## param type it becomes. A row with no `man` cannot be asked about *him*, and
## one with no `town` cannot be asked about *his town*.
const TABLE: Dictionary = {
	"natives_gave": {
		"town": "town",
		"fields": {"tribe": "tribe", "town": "town"},
	},
	"natives_joined": {
		"town": "town",
		"fields": {"tribe": "tribe", "town": "town"},
	},
	"native_trade_closed": {
		"town": "town",
		"fields": {"tribe": "tribe", "town": "town"},
	},
	"town_founded": {
		"town": "from",
		"man": "governor",
		"fields": {"town": "town", "from": "town"},
	},
	"expedition_attacked": {
		"town": "town",
		"fields": {"town": "town", "lost_people": "integer"},
	},
	"expedition_turned_back": {
		"town": "town",
		"fields": {"town": "town", "souls": "integer", "months_out": "integer"},
	},
	"rival_reached_minimum": {
		"man": "rival",
		"fields": {"rival": "rival"},
	},
	"tribute_paid": {
		"man": "to",
		"fields": {"to": "rival", "gold": "gold"},
	},
	"company_destroyed": {
		"man": "commander",
		"fields": {"commander": "contact"},
	},
	# 🔒 **Somebody went round the PC** (#401): an urging from another hand
	# landed on a town. *Him* is whoever pressed it.
	"town_pressed": {
		"town": "town",
		"man": "author",
		"fields": {"town": "town", "author": "contact"},
	},
	# 🔒 **A duke backed a rebel town** (#403, `rival-pressure.md` §8). His
	# letter went to the town's governor; this is how the PC hears of it.
	"rebellion_backed": {
		"town": "town",
		"man": "duke",
		"fields": {"town": "town", "duke": "rival", "men": "integer", "gold": "gold"},
	},
	# The gunsmith's machines have broken, and the quartermaster asks what it
	# costs to mend them (#438).
	"gunsmith_machines_broke": {
		"town": "town",
		"man": "quartermaster",
		"fields": {"town": "town", "amount": "gold"},
	},
}


static func is_reportable(event: String) -> bool:
	return TABLE.has(event)


## Whether this event can be asked about in this way at all.
static func can_concern(event: String, concerning: String) -> bool:
	if not TABLE.has(event):
		return false
	match concerning:
		CONCERNING_HIM:
			return TABLE[event].has("man")
		CONCERNING_HIS_TOWN:
			return TABLE[event].has("town")
		CONCERNING_THE_COLONY:
			return true
	return false


## The letter param type a field becomes, or empty if it may not be read.
static func field_kind(event: String, field: String) -> String:
	if not TABLE.has(event):
		return ""
	return String(TABLE[event]["fields"].get(field, ""))


## The most recent such event within `within` months that concerns whom
## `concerning` names, or null.
static func latest(event: String, within: int, concerning: String, context: LetterContext) -> SimEvent:
	if context == null or context.log == null or not can_concern(event, concerning):
		return null
	var found: SimEvent = null
	for entry in context.log.of_type(StringName(event)):
		var happened: SimEvent = entry
		if within > 0 and context.month - happened.month >= within:
			continue
		if not _concerns(happened, TABLE[event], concerning, context):
			continue
		found = happened  # The log is in order, so the last match is the latest.
	return found


static func _concerns(happened: SimEvent, row: Dictionary, concerning: String, context: LetterContext) -> bool:
	match concerning:
		CONCERNING_HIM:
			return context.sender != null \
				and String(happened.payload.get(String(row["man"]), "")) == String(context.sender.id)
		CONCERNING_HIS_TOWN:
			return context.town != null \
				and String(happened.payload.get(String(row["town"]), "")) == String(context.town.id)
	return true


## What a letter may print of it: a number, or a name — never an id.
static func read(happened: SimEvent, event: String, field: String, context: LetterContext) -> Variant:
	var kind := field_kind(event, field)
	var raw: Variant = happened.payload.get(field, "")
	match kind:
		"integer", "gold":
			return int(roundf(float(raw)))
		"town":
			var town: Town = null if context.colony == null else context.colony.by_id(StringName(raw))
			return "" if town == null else town.display_name
		"tribe":
			var tribe: Tribe = null if context.natives == null else context.natives.find(StringName(raw))
			return "" if tribe == null else tribe.display_name
		"contact", "rival":
			var contact: Contact = context.contacts.get(String(raw))
			return "" if contact == null else contact.display_name
	return ""


# --- The registry's entries --------------------------------------------------

## Whether something of this kind happened lately, concerning him, his town or
## the colony.
static func it_happened(args: Dictionary, context: LetterContext) -> bool:
	return latest(String(args.get("event", "")), int(args.get("within", 0)),
		String(args.get("concerning", "")), context) != null


## A field of the most recent such event, as the letter prints it.
static func what_happened(args: Dictionary, context: LetterContext) -> Variant:
	var event := String(args.get("event", ""))
	var field := String(args.get("field", ""))
	var happened := latest(event, int(args.get("within", 0)),
		String(args.get("concerning", "")), context)
	if happened == null:
		var kind := field_kind(event, field)
		return 0 if kind == "integer" or kind == "gold" else ""
	return read(happened, event, field, context)
