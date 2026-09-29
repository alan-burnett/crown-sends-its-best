class_name UnlockConditions
extends RefCounted

## What a finished run unlocks for the runs after it (#465, `perks-and-quirks.md`
## §1, `prestige.md` §10, SPEC §5, §14.3).
##
## ## 🔒 Every option but the first has one condition of its own
##
## *It's my first day* is unlocked at the start; every other perk and quirk names
## **one condition**, themed to what it does, in its `unlocked_by`. It is checked
## when a run ends, however it ends, and an option whose condition the run met
## goes into the hall of records (`Records`) and is offered from the next run on.
##
## ## 🔒 Conditions are data
##
## An id into this registry with typed params, as a letter's conditions are:
## never logic in a data file. `PARAMS` is the contract the validator checks, and
## `met` is the only place an id means anything. **A named static function per
## id and a `match`**, never a lambda held in a static (`CLAUDE.md`).
##
## Thresholds are the data's and are placeholders.

## The field on a perk or quirk that names its condition.
const KEY: String = "unlocked_by"

## Condition id -> {param: type}. Types: `integer`, `number`, `string`, `strings`.
const PARAMS: Dictionary = {
	"a_contact_of_kind_ends_at": {"kind": "string", "band": "string"},
	"these_contacts_end_at": {"ids": "strings", "band": "string"},
	"founds_towns": {"count": "integer"},
	"urgings_taken": {"count": "integer"},
	"ends_in_prestige_band": {"band": "string"},
	"survives_a_refusal_and_retires": {},
	"the_diplomat_lives": {},
	"a_patron_leaves_at": {"band": "string"},
	"a_town_goes_hungry": {},
	"peak_population": {"at_least": "integer"},
	"lasts_months": {"months": "integer"},
	"a_church_in_every_town": {},
	"a_trade_agreement_with_a_tribe": {},
	"makes": {"resource": "string"},
	"a_commander_reaches": {"level": "integer"},
}


static func is_condition(id: String) -> bool:
	return PARAMS.has(id)


static func ids() -> PackedStringArray:
	var out := PackedStringArray(PARAMS.keys())
	out.sort()
	return out


## The perks and quirks this finished run unlocks, sorted: every one whose
## condition it met. Those unlocked at the start are never listed.
static func unlocked_by(run: RunState, content: ContentDatabase) -> PackedStringArray:
	var out := PackedStringArray()
	if run == null or content == null:
		return out
	for record in [RunModifiers.PERKS_RECORD, RunModifiers.QUIRKS_RECORD]:
		for entry in RunModifiers.entries_in(content, record):
			var option: Dictionary = entry
			if bool(option.get(RunModifiers.UNLOCKED_AT_START, false)):
				continue
			var condition: Variant = option.get(KEY, {})
			if typeof(condition) != TYPE_DICTIONARY:
				continue
			for id in condition:
				if met(String(id), condition[id], run):
					out.append(String(option.get("id", "")))
	out.sort()
	return out


## Whether the finished run met this condition.
static func met(id: String, args: Dictionary, run: RunState) -> bool:
	match id:
		"a_contact_of_kind_ends_at":
			return _a_contact_of_kind_ends_at(args, run)
		"these_contacts_end_at":
			return _these_contacts_end_at(args, run)
		"founds_towns":
			return _founds_towns(args, run)
		"urgings_taken":
			return _urgings_taken(args, run)
		"ends_in_prestige_band":
			return _ends_in_prestige_band(args, run)
		"survives_a_refusal_and_retires":
			return _survives_a_refusal_and_retires(args, run)
		"the_diplomat_lives":
			return _the_diplomat_lives(args, run)
		"a_patron_leaves_at":
			return _a_patron_leaves_at(args, run)
		"a_town_goes_hungry":
			return _a_town_goes_hungry(args, run)
		"peak_population":
			return _peak_population(args, run)
		"lasts_months":
			return _lasts_months(args, run)
		"a_church_in_every_town":
			return _a_church_in_every_town(args, run)
		"a_trade_agreement_with_a_tribe":
			return _a_trade_agreement_with_a_tribe(args, run)
		"makes":
			return _makes(args, run)
		"a_commander_reaches":
			return _a_commander_reaches(args, run)
	return false


# --- The conditions -----------------------------------------------------------

## *Righteous*: a living contact of this kind — a clergyman — ends at the band.
static func _a_contact_of_kind_ends_at(args: Dictionary, run: RunState) -> bool:
	var band := StringName(args.get("band", Relationship.HIGH))
	for contact in _contacts(run):
		if String(contact.kind) == String(args.get("kind", "")) and not contact.is_dead \
				and Relationship.band_of(contact.loyalty()) == band:
			return true
	return false


## *Well connected at court*: every one of these ends at the band.
static func _these_contacts_end_at(args: Dictionary, run: RunState) -> bool:
	var band := StringName(args.get("band", Relationship.HIGH))
	var wanted: Array = args.get("ids", [])
	if wanted.is_empty():
		return false
	for id in wanted:
		var contact := run.contact(StringName(id))
		if contact == null or contact.is_dead or Relationship.band_of(contact.loyalty()) != band:
			return false
	return true


## *Good first impression*: towns founded, by the colony's expeditions or by the
## Crown's ships. The first town is not a founding.
static func _founds_towns(args: Dictionary, run: RunState) -> bool:
	var founded := run.log.of_type(ExpeditionParty.EVENT_FOUNDED).size() \
		+ run.log.of_type(CrownFounding.EVENT_ARRIVED).size()
	return founded >= int(args.get("count", 1))


## *Hard to say no to*: the PC's urgings that landed on a governor's town —
## complied with, partly or wholly, or delayed and then landed.
static func _urgings_taken(args: Dictionary, run: RunState) -> bool:
	var taken := 0
	for event in run.log.of_type(UrgeIntentExecutor.EVENT_URGED):
		if String(event.payload.get(UrgeIntentExecutor.AUTHOR, "")) == String(Urging.PC):
			taken += 1
	return taken >= int(args.get("count", 1))


## *Good PR*: the run ends in this prestige band or a better one.
static func _ends_in_prestige_band(args: Dictionary, run: RunState) -> bool:
	if run.prestige == null:
		return false
	return _band_index(run.prestige.band()) >= _band_index(StringName(args.get("band", "")))


static func _band_index(band: StringName) -> int:
	for index in Prestige.BANDS.size():
		if Prestige.BANDS[index][0] == band:
			return index
	return Prestige.BANDS.size()


## *My boss is a jerk*: the Crown refused the PC's promises at some point, and
## the run ended with him retiring.
static func _survives_a_refusal_and_retires(_args: Dictionary, run: RunState) -> bool:
	if run.ending == null or run.ending.reason != RunEnding.RETIRED:
		return false
	return not run.log.of_type(CrownRefusal.EVENT_REFUSING).is_empty()


## *Read between the lines*: the Diplomat is alive at the end.
static func _the_diplomat_lives(_args: Dictionary, run: RunState) -> bool:
	for contact in _contacts(run):
		if contact.role == Contact.ROLE_DIPLOMAT and not contact.is_dead:
			return true
	return false


## *Busy patrons*: a patron left at the band. His regard stops moving when he
## goes, so it is read off him.
static func _a_patron_leaves_at(args: Dictionary, run: RunState) -> bool:
	var band := StringName(args.get("band", Relationship.HIGH))
	for event in run.log.of_type(PatronTerm.EVENT_DEPARTED):
		var patron := run.contact(StringName(event.payload.get("patron", "")))
		if patron != null and Relationship.band_of(patron.loyalty()) == band:
			return true
	return false


## *It could be worse*: a town lost people to hunger.
static func _a_town_goes_hungry(_args: Dictionary, run: RunState) -> bool:
	return not run.log.of_type(ConsumePhase.EVENT_FAMINE).is_empty()


## *Boom town*: the most the colony ever held.
static func _peak_population(args: Dictionary, run: RunState) -> bool:
	var peak := 0
	for event in run.log.of_type(LastChance.EVENT_LOOKED):
		peak = maxi(peak, int(event.payload.get("peak", 0)))
	return peak >= int(args.get("at_least", 1))


## *Distant colony*: how long it lasted.
static func _lasts_months(args: Dictionary, run: RunState) -> bool:
	return run.ending != null and run.ending.month >= int(args.get("months", 1))


## *A pious colony*: every town it holds at the end has a church.
static func _a_church_in_every_town(_args: Dictionary, run: RunState) -> bool:
	if run.colony == null or run.colony.is_empty():
		return false
	for town in run.colony.in_order():
		if not (town as Town).has_building(&"church"):
			return false
	return true


## *Restless country*: a trade agreement was made with a tribe.
static func _a_trade_agreement_with_a_tribe(_args: Dictionary, run: RunState) -> bool:
	return not run.log.of_type(TradeAgreement.EVENT_OPENED).is_empty()


## *Scarce iron*: a town made this resource itself.
static func _makes(args: Dictionary, run: RunState) -> bool:
	var resource := String(args.get("resource", ""))
	for event in run.log.of_type(ConvertPhase.EVENT_CONVERTED):
		var made: Variant = event.payload.get("made", {})
		if typeof(made) == TYPE_DICTIONARY and float((made as Dictionary).get(resource, 0.0)) > 0.0:
			return true
	return false


## *Commando commanders*: a commander rose to this level.
static func _a_commander_reaches(args: Dictionary, run: RunState) -> bool:
	for event in run.log.of_type(Battle.EVENT_ROSE):
		if int(event.payload.get("level", 0)) >= int(args.get("level", 1)):
			return true
	return false


static func _contacts(run: RunState) -> Array:
	var out: Array = []
	var ids: Array = run.contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = run.contacts[id]
		if contact != null:
			out.append(contact)
	return out
