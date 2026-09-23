class_name Patron
extends RefCounted

## A man at court who takes an interest, asks for things, and does not stay
## (#282, SPEC §8.3; `docs/mechanics/patrons.md` §1, §2, §3, §7).
##
## ## 🔒 Three things rolled at arrival, and a mismatch by construction
##
## | | |
## | :--- | :--- |
## | **Specialty** | something he can supply or arrange |
## | **Need** | something of particular value to him |
## | **Vice** | what makes him difficult |
##
## **Specialty and need are never the same** (§3), and it is guaranteed by the
## draw rather than checked afterwards: the need is taken from the catalogue with
## his specialty removed, so there is no state in which the two match and no
## rule anybody has to remember.
##
## **Vice, not personality.** `contacts.md` §1 reserves *personality* for the
## weight vector every contact has, this one included. A vice is a named bundle
## of mechanical behaviour on top, and `PatronVices` is where the bundle lives.
##
## ## 🔒 He arrives from the Squeeze, and there is no second clock
##
## `crown-demands.md` §6, dimension 4 — *more hands out* — already names patrons
## alongside rival dukes and Crown officers who were not asking before. Same
## annual draw, same bucket, same guarantee they cannot bunch, and the arithmetic
## is `RivalDuke.how_many_arrived`'s with a different threshold.
##
## **And §6's ceiling was written for this.** *"Reach ceilings because there are
## only so many people in the world with a hand out before M7 brings patrons."*
## M7 is here, so the ceiling rises — which incidentally lets the third duke
## arrive, who could not reach the board at a ceiling of four.
##
## ## What is not here
##
## The offer object, the departure clock and the rival specialty are §§4, 5 and
## 8, and each has its own ticket. This is the man: who he is, what he wants, and
## when he turns up.

const ROLE: StringName = Contact.ROLE_PATRON

const COLLECTION: String = "patrons"
const CATALOGUE_RECORD: String = "catalogue"

## How many can be in the correspondence at once.
##
## ⚠️ **`patrons.md` §12 leaves this open** — *nothing fixes it, and §9.6's
## letter volume is the real constraint; three is probably the ceiling.* Three is
## what shipped, and it is the same figure the dukes carry for the same reason.
## The PO's to overturn.
##
## A quirk names it (`perks-and-quirks.md` §4, *Busy patrons*), and **that is why
## §9.6 is the constraint rather than a footnote**: more patrons is more of the
## desk, which is the drawback the entry is built on rather than a side effect to
## be tuned away.
static var _how_many: int = 3


static func how_many() -> int:
	return _how_many


## Turn it. Never below zero; a run with no patrons in it is a run that has not
## met one yet, which is already the first four years of every run.
static func set_how_many(count: int) -> void:
	_how_many = maxi(0, count)


const EVENT_ARRIVED: StringName = &"patron_arrived"

static var _catalogue: Array = []


static func load_from(record: Dictionary) -> void:
	_catalogue = record.get("entries", []).duplicate(true)


static func reset() -> void:
	_catalogue = []
	_how_many = 3


## Every id in the catalogue, in file order.
##
## **File order, not sorted**, because the draw is an index into it and sorting
## here would make adding an entry re-roll every patron in every seed. The file
## is the fixed order; `data/patrons/catalogue.json` is the record of it.
static func catalogue_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in _catalogue:
		out.append(String((entry as Dictionary).get("id", "")))
	return out


## What kind of thing a catalogue entry is: a shipment, or rivals (§3).
static func kind_of(id: String) -> String:
	for entry in _catalogue:
		if String((entry as Dictionary).get("id", "")) == id:
			return String((entry as Dictionary).get("kind", "shipment"))
	return ""


static func is_patron(contact: Contact) -> bool:
	return contact != null and contact.role == ROLE


# --- Arrival ----------------------------------------------------------------

## How many patrons the Squeeze has produced (§7).
##
## 🔒 **Counted off the Squeeze, kept nowhere.** The same shape as
## `RivalDuke.how_many_arrived`, and for the same reason: a stored count is a
## second clock, and §7 says there is not one. Two properties fall out of the
## bucket rather than needing code — they arrive staggered, one source per draw,
## and they cannot bunch, because §7 of `crown-demands.md` guarantees dimension 4
## at most twice in four draws.
##
## 🔒 **Not behind the dukes** (#339). This once waited for five hands out, on
## the argument that a patron is the softest version of *more hands out* and the
## run should meet the hard ones first. The Author heard it and ruled the other
## way: any draw of dimension 4 can put out any of the three, and the first may
## be a patron's. At five hands, the first patron came in year nine at the
## earliest, outside the run SPEC §6.2 designs for.
static func how_many_arrived(growth: DemandGrowth) -> int:
	if growth == null:
		return 0
	return clampi(growth.sources_of(DemandGrowth.SOURCE_PATRON), 0, _how_many)


## The id the nth patron goes by.
##
## **Numbered from one, and never reused.** A patron who leaves is gone
## (§8) and the man who follows him is a different man with a different name, so
## the number counts arrivals rather than seats.
static func id_for(ordinal: int) -> StringName:
	return StringName("patron_%d" % ordinal)


## Everyone on the roster who is a patron, in id order.
static func all_in(run: RunState) -> Array:
	var out: Array = []
	if run == null:
		return out
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if is_patron(contact):
			out.append(contact)
	return out


# --- The man ----------------------------------------------------------------

## Roll a patron from his own stream (§2).
##
## 🔒 **The order of the draws is the order of the fields**, and it must not
## change: the same seed has to keep giving the same man however much is added
## around him. Specialty, then need from the catalogue with the specialty taken
## out, then vice.
##
## `Contact.generate` has already drawn his personality, his name and his
## temperament from the same stream, so these three continue that sequence
## rather than starting one.
static func generate(
	id: StringName, streams: RngStreams, month: int = 0
) -> Contact:
	var contact := Contact.generate(id, ROLE, streams, IntentConsiderations.ALL)
	contact.known_since = month
	var rng := streams.contact_stream(String(id))
	var ids := catalogue_ids()
	if not ids.is_empty():
		contact.specialty = String(ids[rng.randi_range(0, ids.size() - 1)])
		# 🔒 **The mismatch is the draw, not a check.** Removing his specialty
		# before the second draw means there is no state in which the two match,
		# so nothing downstream has to ask.
		var wanted := PackedStringArray()
		for entry in ids:
			if String(entry) != contact.specialty:
				wanted.append(String(entry))
		if not wanted.is_empty():
			contact.need = String(wanted[rng.randi_range(0, wanted.size() - 1)])
	var vices := PatronVices.ids()
	if not vices.is_empty():
		contact.vice = StringName(vices[rng.randi_range(0, vices.size() - 1)])
	PatronVices.apply_to(contact)
	return contact
