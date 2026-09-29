class_name PatronVices
extends RefCounted

## What a vice actually turns (#282, `docs/mechanics/patrons.md` §6).
##
## ## 🔒 A vice names a knob. It never adds behaviour
##
## The same rule `perks-and-quirks.md` §2 puts on a perk, and for the same
## reason: ten vices written as ten special cases is ten places a change to the
## contact model has to be remembered.
##
## **Credulous is the pattern the rest follow** (§6). He has no escalation rule.
## He has a bias — his leans run positive — and because he sincerely believes the
## colony is prospering, what he asks for grows on its own. The greed is
## *derived from the perception* rather than bolted on beside it.
##
## ## Two tables, and every knob is in one of them
##
## | | |
## | :--- | :--- |
## | `APPLIES` | turned **when he arrives**, onto a field he already has |
## | `READ_BY` | read **where it is needed**, so there is nothing to turn |
##
## A knob is in `APPLIES` when some existing field holds it: a weight on a deed,
## a lean, a `cares_about`, how readily he writes. It is in `READ_BY` when the
## machinery that wants it asks the question at the moment it matters — whether
## he will touch rum, how late his shipment runs — because storing the answer
## would put it in two places.
##
## **Neither table may be empty of a knob some file names.** `ContentValidator`
## refuses a vice naming a knob that is in neither, which is the failure this
## shape exists to prevent: a vice the Author wrote, the player met, and that did
## nothing at all.
##
## Named static functions rather than lambdas: a `Callable` living in a static
## registry segfaults Godot 4.7 on shutdown (`CLAUDE.md`).

const COLLECTION: String = "patrons"
const RECORD: String = "vices"

## Knob id -> the name of the static function that turns it at arrival.
##
## **A table of names, not of callables**, looked up at the moment of use, so
## nothing holds a `Callable` at shutdown.
const APPLIES: Dictionary = {
	"deed_weight": "_deed_weight",
	"writes_readily": "_writes_readily",
	"lean": "_lean",
	"cares_about": "_cares_about",
}

## Knob id -> what reads it, for the reader and for the validator.
##
## 🔒 **Not a no-op list.** Each of these is asked for by name at the point it
## decides something, and the string says where — so a knob that stops being read
## is a dead entry somebody can see rather than a silent nothing.
const READ_BY: Dictionary = {
	"prestige_voice": "PatronCredit.voice_of",
	"displeasure_spreads": "PatronGossip.share_of",
	# 🔒 **Each names the function that reads it** (#444), as `Class.method`, so
	# a test can find every one and a knob can never again claim a reader that
	# does not exist.
	"cancels_on_rebellion": "PatronVices.respectable_withdraws",
	"will_not_touch": "PatronVices.disapproved_of",
	"delivers_late": "PatronVices.months_late",
	"offers_once": "PatronVices.may_offer_his_specialty",
}

static var _vices: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()


static func load_from(record: Dictionary) -> void:
	_vices = {}
	_order = PackedStringArray()
	for entry in record.get("entries", []):
		var id := String((entry as Dictionary).get("id", ""))
		if id.is_empty():
			continue
		_vices[id] = (entry as Dictionary).duplicate(true)
		_order.append(id)


static func reset() -> void:
	_vices = {}
	_order = PackedStringArray()


static func is_knob(id: String) -> bool:
	return APPLIES.has(id) or READ_BY.has(id)


## Every vice, in file order.
##
## **File order, not sorted**, because the draw is an index into it: sorting
## would make adding a vice re-roll every patron in every seed.
static func ids() -> PackedStringArray:
	return _order.duplicate()


static func has(id: StringName) -> bool:
	return _vices.has(String(id))


## The knobs a vice names, as `{knob_id: args}` dictionaries in file order.
static func knobs_of(vice: StringName) -> Array:
	return (_vices.get(String(vice), {}) as Dictionary).get("knobs", [])


## What this man's vice says about one knob, or empty if it says nothing.
##
## **The reader half of the contract.** A patron with no vice, a vice with no
## such knob and no vices loaded at all all answer the same way, so a caller
## asking *how late does he deliver* gets an empty dictionary rather than a
## crash.
static func knob_of(contact: Contact, knob: String) -> Dictionary:
	if contact == null:
		return {}
	for entry in knobs_of(contact.vice):
		if (entry as Dictionary).has(knob):
			return (entry as Dictionary)[knob]
	return {}


# --- 🔒 The four read where they are needed (#444, `patrons.md` §6) -----------

## He withdrew from the colony: the month after a town declared.
const EVENT_WITHDREW: StringName = &"patron_withdrew"
## The colony sold what he will not touch, and he minds.
const EVENT_OBJECTED: StringName = &"patron_objected"

## What a patron of each kind of gift hands over, which a dilatory man hands over
## late: his one-offs and his policies (§6, §4).
const GIVES: Array[StringName] = [
	&"send_an_expert", &"give_the_crown_gold", &"trouble_a_duke", &"enact_policy",
]


## 🔒 **Respectable** (§6): the month after any town declares, his regard falls,
## he writes that he can no longer be associated with the colony, and **his
## policies end with that letter**, which is `policy.md` §4's warning. What the PC
## promised him stands. **Every declaration does it again.**
static func respectable_withdraws(run: RunState, log: EventLog, month: int) -> void:
	if run == null or run.contacts == null:
		return
	var declared: Array = []
	for event in log.of_type(Rebellion.EVENT_DECLARED):
		if event.month == month - 1:
			declared.append(event)
	if declared.is_empty():
		return
	for entry in Patron.all_in(run):
		var patron: Contact = entry
		var knob := knob_of(patron, "cancels_on_rebellion")
		if patron.is_dead or knob.is_empty():
			continue
		for event in declared:
			patron.relationship.drift(-absf(float(knob.get("regard", 30.0))))
			var ended := PackedStringArray()
			if run.policies != null:
				for policy in run.policies.held_by(patron.id):
					run.policies.lapse(policy.id, log, month, "withdrew")
					ended.append(String(policy.id))
			log.emit(EVENT_WITHDREW, patron.id, month, {
				"patron": String(patron.id),
				"town": String(event.payload.get("town", event.subject)),
				"policies": ended,
			}, WorldPhase.RECKONING)


## 🔒 **Doctrinaire** (§6): the resource he disapproves of, drawn at arrival from
## the knob's list, or empty for anybody else.
static func disapproved_of(contact: Contact, rng: RandomNumberGenerator) -> String:
	var knob := knob_of(contact, "will_not_touch")
	var choices: Array = knob.get("from", [])
	if choices.is_empty() or rng == null:
		return ""
	return String(choices[rng.randi_range(0, choices.size() - 1)])


## 🔒 **Each month the colony sells it to the Crown, his regard falls** (§6).
static func doctrinaire_objects(run: RunState, log: EventLog, month: int) -> void:
	if run == null:
		return
	for entry in Patron.all_in(run):
		var patron: Contact = entry
		if patron.is_dead or String(patron.disapproves).is_empty():
			continue
		var sold := 0.0
		for event in log.of_type(Trade.EVENT_SOLD):
			if event.month == month and String(event.payload.get("resource", "")) == patron.disapproves:
				sold += float(event.payload.get("quantity", 0.0))
		if sold <= 0.0:
			continue
		patron.relationship.drift(-absf(float(knob_of(patron, "will_not_touch").get("regard", 2.0))))
		log.emit(EVENT_OBJECTED, patron.id, month, {
			"patron": String(patron.id),
			"resource": patron.disapproves,
		}, WorldPhase.RECKONING)


## 🔒 **Dilatory** (§6): how many months after the PC accepts it what he gives
## lands. Nought for everybody else, whose land the month after.
static func months_late(contact: Contact) -> int:
	return maxi(0, int(knob_of(contact, "delivers_late").get("months", 0)))


## 🔒 **Impatient** (§6): he offers his specialty once. After any offer of it,
## whatever the answer, he never offers it again for his stay; an ordinary patron
## may (§4).
static func may_offer_his_specialty(contact: Contact, log: EventLog) -> bool:
	if contact == null or log == null or not _has_knob(contact, "offers_once"):
		return true
	for event in log.of_type(Director.EVENT_DISPATCHED):
		if event.subject == contact.id and Patron.SPECIALTY_OFFERS.has(String(event.payload.get("letter", ""))):
			return false
	return true


static func _has_knob(contact: Contact, knob: String) -> bool:
	for entry in knobs_of(contact.vice):
		if (entry as Dictionary).has(knob):
			return true
	return false


## Turn every knob this man's vice names that is turned at arrival.
##
## Applied once, when he is generated, because a vice is a fact about the man
## rather than a thing that happens to him.
static func apply_to(contact: Contact) -> void:
	if contact == null or not _vices.has(String(contact.vice)):
		return
	var turning := PatronVices.new()
	for entry in knobs_of(contact.vice):
		for knob in entry:
			var id := String(knob)
			if APPLIES.has(id):
				# **Dispatched by name through an instance**, which is the only
				# way GDScript will `call` into this script — and the instance is
				# made here and dropped here, so nothing holds a `Callable` at
				# shutdown (`CLAUDE.md`).
				turning.call(String(APPLIES[id]), contact, entry[knob])
			elif not READ_BY.has(id):
				push_error(
					"Vice '%s' names the knob '%s', which nothing turns or reads."
					% [contact.vice, id])


# --- The knobs --------------------------------------------------------------

## **Thin-skinned**: a refusal cuts deeper than it would.
##
## A per-contact scale on a deed everybody already feels, so the harsher register
## is the same machinery turned up rather than a second path through loyalty.
static func _deed_weight(contact: Contact, args: Dictionary) -> void:
	if contact.relationship == null:
		return
	contact.relationship.scale_deed(
		StringName(args.get("deed", "")), float(args.get("scale", 1.0)))


## **Importunate**: he will not take no, and writes again.
##
## `the-director.md` §4's readiness, which is exactly what an importunate man
## has — a low bar for reaching for a pen. The slide into `desperate` needs no
## knob of its own: `tone.md` §4 already carries a man who keeps writing and
## keeps being refused.
static func _writes_readily(contact: Contact, args: Dictionary) -> void:
	contact.writes_readily *= float(args.get("scale", 1.0))


## **Credulous**: he reads the colony as richer than it is.
##
## 🔒 **A lean, and nothing else** (§6). His asks grow because he believes the
## colony prospers, which is the perception resolver's business and not his.
static func _lean(contact: Contact, args: Dictionary) -> void:
	var measure := String(args.get("measure", ""))
	if measure.is_empty():
		return
	contact.leans[measure] = clampf(float(args.get("amount", 0.0)), -1.0, 1.0)


## **Pragmatic** and **Respectable**: what he judges the PC by.
##
## Both read the colony rather than what the PC sends them — one his books, the
## other his streets — and `cares_about` is where a contact says so. It is also
## what decides what he writes about unprompted (`contacts.md` §6), so a
## respectable man raising rebel sentiment in a letter falls out of the same line.
static func _cares_about(contact: Contact, args: Dictionary) -> void:
	var measure := String(args.get("measure", ""))
	if measure.is_empty() or contact.cares_about.has(measure):
		return
	contact.cares_about.append(measure)
