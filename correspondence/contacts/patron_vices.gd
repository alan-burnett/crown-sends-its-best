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
## machinery that wants it asks the question at the moment it matters — how
## loudly he speaks of the PC at court, how far his displeasure travels — because
## storing the answer would put it in two places.
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
##
## 🔒 **`Class.function`, and the function exists.** `test_knob_readers` holds
## every entry to that, because an entry here is the validator's whole reason to
## pass a vice. Four once pointed at machinery nobody had built, and three vices
## shipped doing nothing.
##
## **Not here, because nothing reads them yet** (#444): Respectable's
## `cancels_on_rebellion`, Doctrinaire's `will_not_touch`, Dilatory's
## `delivers_late` and Impatient's `offer_expires_in`. §6 names all four. Until
## each has a design and a reader, it stays out of this table and out of
## `data/patrons/vices.json`.
const READ_BY: Dictionary = {
	"prestige_voice": "PatronCredit.voice_of",
	"displeasure_spreads": "PatronGossip.share_of",
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
## asking *how loudly does he talk* gets an empty dictionary rather than a
## crash.
static func knob_of(contact: Contact, knob: String) -> Dictionary:
	if contact == null:
		return {}
	for entry in knobs_of(contact.vice):
		if (entry as Dictionary).has(knob):
			return (entry as Dictionary)[knob]
	return {}


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
