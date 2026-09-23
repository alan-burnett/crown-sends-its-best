class_name RivalDuke
extends RefCounted

## A rival empire's man on this coast (#209, SPEC §12.4;
## `docs/mechanics/rival-pressure.md` §1, §2, §3).
##
## ## 🔒 Almost nothing here is new machinery
##
## **A duke is an ordinary contact with his values inverted.** A name, a
## personality and a loyalty, moved by the same deeds through the same path.
## `GRANTED`, `REFUSED`, `DELIVERED` and `PROMISE_BROKEN` already carry the
## weights; `LoyaltyDrift` already moves a man by the things he judges the Crown
## by. What differs is only **what he cares about**.
##
## > They want the PC paying and weak.
##
## So he cares about `colony_is_no_threat` — the colony *not* having got far —
## and a prospering colony drags him down by exactly the mechanism a failing one
## drags a governor down. There is no second scalar, no inversion flag and no
## bespoke drift: the inversion is a measure with a name.
##
## ### Which makes loyalty a protection racket, and the game never says so
##
## One word doing double duty: a governor's regard and a duke's satisfaction with
## his cut. **A "loyal" rival is not a friend. He is a man who is being paid.**
##
## ## 🔒 Prospering is what he can see
##
## Towns, population and territory — **never `net_position`**. The Crown's ledger
## is the Crown's and a rival has no sight of it.
##
## That is a lock rather than a detail. If rival aggression read net position,
## the same number would drive Crown Standing, prestige *and* the rivals, and the
## PC would be punished three ways for the single thing the Crown demands of him.
##
## ## 🔒 What a duke never does
##
## - never asks for help against another rival or the natives
## - never offers his own resources — **there is no trade with a rival, ever**
## - never becomes peaceful or mutually beneficial, at any loyalty
## - **one duke per rival**, the PC's only contact with that empire
##
## A dev writing a rival offer, a rival alliance or a second rival contact has
## left the spec, and `test_rival_dukes` says so.

const ROLE: StringName = Contact.ROLE_RIVAL

## 🔒 **Three, fixed** (SPEC §12.4), like the tribes. Not a tuning value.
const HOW_MANY: int = 3

const EVENT_AT_MINIMUM: StringName = &"rival_reached_minimum"

# --- The four bands ---------------------------------------------------------

## What he does, read off the one loyalty value.
##
## 🔒 **No second state machine**, exactly as `crown-standing.md` reads its four
## stages from standing. There is no band field anywhere, on a contact or on a
## book: the band is a function and the function is the only definition.
const HIGH: StringName = &"high"
const MEDIUM: StringName = &"medium"
const LOW: StringName = &"low"
const MINIMUM: StringName = &"minimum"

const BANDS: Array[StringName] = [HIGH, LOW, MEDIUM, MINIMUM]

## Where each band begins. Tuning.
const HIGH_AT: float = 60.0
const MEDIUM_AT: float = 35.0
const LOW_AT: float = 12.0


## Which band this loyalty sits in.
##
## 🔒 **A pure function of one number.** Anything that stored the answer would be
## a second place the truth lived, and the two would eventually disagree.
static func band_of(loyalty: float) -> StringName:
	if loyalty >= HIGH_AT:
		return HIGH
	if loyalty >= MEDIUM_AT:
		return MEDIUM
	if loyalty >= LOW_AT:
		return LOW
	return MINIMUM


## What band a duke is in, with the latch taken into account.
##
## 🔒 **Minimum is a latch.** Once a duke reaches the bottom he is there for the
## run, whatever his loyalty does afterwards — paying no longer helps, because
## there is nothing left to buy. The same shape `natives.md` gives a tribe that
## has concluded the colony means its destruction, and meant the same way: a
## point of no return the player can see coming and cannot reverse.
static func band_for(duke: Contact, book: RivalBook) -> StringName:
	if duke == null:
		return MINIMUM
	if book != null and book.is_at_minimum(duke.id):
		return MINIMUM
	return band_of(duke.relationship.loyalty if duke.relationship != null else 0.0)


## Whether a duke in this band will park men on the colony's ground (#188).
static func denies_tiles(band: StringName) -> bool:
	return band == LOW or band == MINIMUM


## Whether he makes open war on towns.
static func makes_war(band: StringName) -> bool:
	return band == MINIMUM


## How dear his tribute is, as a multiple of the ordinary ask.
##
## **Reasonable while he is being paid, dearer once he is not.** Tuning, and
## #210's to spend.
static func tribute_multiple(band: StringName) -> float:
	match band:
		HIGH:
			return 1.0
		MEDIUM:
			return 1.8
		_:
			# 🔒 Past medium he is not asking any more. A figure here would imply
			# a payment that bought something, and below medium none does.
			return 0.0


## Whether a missed payment is let go.
static func forgives_a_missed_payment(band: StringName) -> bool:
	return band == HIGH


## Every duke in the run, in id order.
## How many dukes have actually turned up (#300, `rival-pressure.md` §6).
##
## 🔒 **A duke arrives as the Squeeze's fourth dimension, and there is no second
## schedule.** He spawns when a draw lands on dimension 4 and the hand it puts
## out is a duke's — *that is the whole of it* — so this counts
## `DemandGrowth.sources` rather than keeping anything, and two properties the
## doc names fall out instead of needing code:
##
## **They arrive staggered**, one source per draw, so the colony faces one duke,
## then two, then three across a run. **And they cannot bunch**, because §7's
## bucket guarantees dimension 4 at most twice in four draws.
##
## 🔒 **And in no order** (#339). He waits on no count of other hands: the first
## hand a run meets may be his, or a patron's, or a Crown officer's. Nought until
## a draw puts his out — *prospering does not attract rivals*, and in month one
## there is nothing to be attracted to.
static func how_many_arrived(growth: DemandGrowth) -> int:
	if growth == null:
		return 0
	return clampi(growth.sources_of(DemandGrowth.SOURCE_DUKE), 0, HOW_MANY)


## The dukes who have arrived, in the order they arrive.
##
## 🔒 **Present as a contact and active in the world are not the same thing.**
## SPEC §8.4 makes rivals fixed contacts, so all three are on the roster from the
## start and `all_in` still finds them — what this adds is that a duke who has not
## yet been produced by the Squeeze does not park men on the colony's fields.
##
## Ordered by id, which is the same tie-break every other ordered thing in the
## game uses, so the same run always meets the same duke first.
static func arrived_in(run: RunState, growth: DemandGrowth) -> Array:
	var arrived := how_many_arrived(growth)
	if arrived <= 0:
		return []
	var dukes := all_in(run)
	dukes.sort_custom(func(a: Contact, b: Contact) -> bool:
		return String(a.id) < String(b.id))
	return dukes.slice(0, arrived)


## Every duke on the roster, arrived or not.
static func all_in(run: RunState) -> Array:
	var out: Array = []
	if run == null:
		return out
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		if contact != null and contact.role == ROLE:
			out.append(contact)
	return out
