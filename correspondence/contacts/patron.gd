class_name Patron
extends RefCounted

## A man at court who takes an interest, asks for things, and does not stay
## (#282, SPEC §8.3; `docs/mechanics/patrons.md` §1, §2, §3, §7).
##
## ## 🔒 Three things rolled at arrival, and a mismatch by construction
##
## | | |
## | :--- | :--- |
## | **Specialty** | what he will do for the colony once he thinks well enough of it |
## | **Need** | a resource or livestock kind he wants shipped to him |
## | **Vice** | what makes him difficult |
##
## **His need is never his specialty's kind** (§3), and it is guaranteed by the
## draw rather than checked afterwards: the need's kind is drawn with his
## specialty's kind taken out, so there is no state in which the two match and
## no rule anybody has to remember.
##
## **Two patrons to a kind, then none** (#439, §3). A resource or livestock
## specialty comes with one of two permanent bonuses, and what each kind has been
## rolled with is kept in `PatronBook.rolled`, which outlives the men.
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
## His letters, the departure clock and the rival specialty are §§4, 5 and 8,
## and each has its own ticket. This is the man: who he is, what he wants, and
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


## The knob alone, for `RunModifiers.reset_knobs`; the catalogue stays loaded.
static func reset_how_many() -> void:
	_how_many = 3


const EVENT_ARRIVED: StringName = &"patron_arrived"

static var _catalogue: Array = []


static func load_from(record: Dictionary) -> void:
	_catalogue = record.get("entries", []).duplicate(true)


static func reset() -> void:
	_catalogue = []
	reset_how_many()


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


## 🔒 **The two bonuses a resource or livestock specialty offers** (#439,
## `patrons.md` §3): a higher Crown price for his kind, or more of it across the
## colony — for livestock, faster breeding. **Permanent**, which is the only
## reason a kind is capped at one patron for each.
const BONUS_PRICE: String = "price"
const BONUS_MORE: String = "more"
const BONUSES: PackedStringArray = ["price", "more"]

## The specialties that roll a bonus, and so are capped at two to a kind (§3).
## **Experts, troops, gold and the rivals have no limit**, and their favours
## repeat.
const WITH_A_BONUS: PackedStringArray = ["resources", "livestock"]


## 🔒 **What a category names one of** (#396, `patrons.md` §3). A resource is
## anything the Crown prices that is not livestock; livestock is its own; an
## expert is expert in something the colony can make. Gold, troops and the rival
## specialty come in no kinds. Sorted, so the draw reads the same list every time.
##
## **What a need can name.** A specialty draws from `specialty_kinds_of`, which
## is narrower.
static func kinds_of(category: String) -> PackedStringArray:
	var out := PackedStringArray()
	match category:
		"resources":
			out = ResourceCatalogue.staples() + ResourceCatalogue.luxuries()
		"livestock":
			out = ResourceCatalogue.livestock()
		"experts":
			for id in ResourceCatalogue.staples() + ResourceCatalogue.luxuries():
				var kind := ResourceCatalogue.get_kind(StringName(id))
				if kind != null and kind.producible:
					out.append(id)
	out.sort()
	return out


## 🔒 **What a specialty can name** (#439, §3): only what the colony can make.
## **Tea is never a specialty** — the colony can neither grow it nor sell it, so
## nothing he could do for it would matter.
static func specialty_kinds_of(category: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in kinds_of(category):
		var kind := ResourceCatalogue.get_kind(StringName(id))
		if kind != null and kind.producible:
			out.append(id)
	return out


## Whether a catalogue entry can be a patron's need (§3): **only a resource or a
## livestock kind**, something the colony can ship him. Read off the file, so the
## catalogue says it once.
static func can_be_needed(id: String) -> bool:
	for entry in _catalogue:
		if String((entry as Dictionary).get("id", "")) == id:
			return bool((entry as Dictionary).get("needed", false))
	return false


static func _one_of(kinds: PackedStringArray, rng: RandomNumberGenerator) -> String:
	if kinds.is_empty():
		return ""
	return kinds[rng.randi_range(0, kinds.size() - 1)]


## The kinds of a category still open to a new specialty, given what each kind
## has been rolled with before (§3). **A kind two patrons have held is closed**:
## both bonuses have been on offer, and the book on it is shut.
static func _open_kinds(category: String, rolled: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for kind in specialty_kinds_of(category):
		if WITH_A_BONUS.has(category) and (rolled.get(kind, []) as Array).size() >= BONUSES.size():
			continue
		out.append(kind)
	return out


## The catalogue entries a new patron can still specialise in, in file order.
## One whose kinds are all closed is closed; one that comes in no kinds never is.
static func _open_specialties(rolled: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id in catalogue_ids():
		if not kinds_of(id).is_empty() and _open_kinds(id, rolled).is_empty():
			continue
		out.append(id)
	return out


## 🔒 **The second patron of a kind offers the other bonus** (§3); the first
## draws one.
static func _bonus_for(contact: Contact, rolled: Dictionary, rng: RandomNumberGenerator) -> String:
	if not WITH_A_BONUS.has(contact.specialty) or contact.specialty_kind.is_empty():
		return ""
	var taken: Array = rolled.get(contact.specialty_kind, [])
	if not taken.is_empty():
		for bonus in BONUSES:
			if not taken.has(bonus):
				return bonus
	return BONUSES[rng.randi_range(0, BONUSES.size() - 1)]


## What a need of this category could name for him: every kind of it but his
## specialty's.
static func _wanted_kinds(category: String, contact: Contact) -> PackedStringArray:
	var out := PackedStringArray()
	for kind in kinds_of(category):
		if kind != contact.specialty_kind:
			out.append(kind)
	return out


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
## around him. Specialty, its kind and its bonus; then need and its kind; then
## vice.
##
## #439 reordered them, deliberately, when the need stopped being drawn from the
## specialty's list; saves from before it refuse to load.
##
## `Contact.generate` has already drawn his personality, his name and his
## temperament from the same stream, so these continue that sequence rather than
## starting one.
##
## 🔒 **`book` is what closes a kind** (§3, *two patrons to a kind, then none*).
## It holds what every patron before him was rolled with, the ones gone home
## included, since their own streams fixed it; and this man is entered in it.
## Without a book nothing is closed, which is only ever a test asking about one
## man.
static func generate(
	id: StringName, streams: RngStreams, month: int = 0, book: PatronBook = null
) -> Contact:
	var contact := Contact.generate(id, ROLE, streams, IntentConsiderations.ALL)
	contact.known_since = month
	var rng := streams.contact_stream(String(id))
	var rolled: Dictionary = book.rolled if book != null else {}

	var open := _open_specialties(rolled)
	if not open.is_empty():
		contact.specialty = String(open[rng.randi_range(0, open.size() - 1)])
		contact.specialty_kind = _one_of(_open_kinds(contact.specialty, rolled), rng)
		contact.specialty_bonus = _bonus_for(contact, rolled, rng)

	# 🔒 **The mismatch is the draw, not a check.** His specialty's kind is taken
	# out before the need's is drawn, so there is no state in which the two match
	# and nothing downstream has to ask.
	var needs := PackedStringArray()
	for entry in catalogue_ids():
		if can_be_needed(entry) and not _wanted_kinds(entry, contact).is_empty():
			needs.append(entry)
	if not needs.is_empty():
		contact.need = String(needs[rng.randi_range(0, needs.size() - 1)])
		contact.need_kind = _one_of(_wanted_kinds(contact.need, contact), rng)

	var vices := PatronVices.ids()
	if not vices.is_empty():
		contact.vice = StringName(vices[rng.randi_range(0, vices.size() - 1)])
	PatronVices.apply_to(contact)
	if book != null:
		book.note_roll(contact)
	return contact
