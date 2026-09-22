class_name PatronOffer
extends RefCounted

## Every offer a patron makes, and it is one object (#283,
## `docs/mechanics/patrons.md` §4).
##
## ```
## offer = { gives:  specialty | gold | nothing
##           wants:  his need  | gold | nothing }
## ```
##
## | gives → wants | Reads as |
## | :--- | :--- |
## | specialty → nothing | **a gift** |
## | nothing → his need | **a request** |
## | specialty → his need | **a barter** |
## | specialty → gold | **a sale** |
## | gold → his need | **a purchase** |
##
## ## 🔒 One letter family, one resolution path
##
## Five shapes that read entirely differently in prose are **four fields with
## some of them empty**. `settle` moves what is given and takes what is wanted
## and never asks which of the five it is holding; `shape_of` exists for the
## prose and for the log, and nothing decides anything by it.
##
## A dev who writes `if offer.is_a_gift()` has made five mechanics out of one,
## and the fifth one somebody adds later will be missing from four places.
##
## ## 🔒 Loyalty gates which he proposes, not how one resolves
##
## Gifts belong to high regard and bare requests to low — but that is a filter on
## **what he puts in the post**, applied before the offer exists. Once it exists
## it is the same object however well he thinks of the PC.

const NOTHING: StringName = &""
const SPECIALTY: StringName = &"specialty"
const NEED: StringName = &"need"
const GOLD: StringName = &"gold"

## What the five combinations are called. **Prose and the log only.**
const GIFT: StringName = &"gift"
const REQUEST: StringName = &"request"
const BARTER: StringName = &"barter"
const SALE: StringName = &"sale"
const PURCHASE: StringName = &"purchase"

const EVENT_OFFERED: StringName = &"patron_offered"
const EVENT_SETTLED: StringName = &"patron_offer_settled"

## Where each shape starts being worth proposing. Placeholders; M8 owns them.
##
## 🔒 **Gifts belong to high regard and bare requests to low** (§4). A man who
## thinks well of the PC sends things; a man who does not only asks.
const GIFT_ABOVE: float = 72.0
const BARTER_ABOVE: float = 45.0
const SALE_ABOVE: float = 40.0
const PURCHASE_ABOVE: float = 20.0

var gives: StringName = NOTHING
var wants: StringName = NOTHING

## How much, when either side of it is gold.
var gold: float = 0.0

## How much of the resource, either way.
var amount: float = 0.0


func _init(
	p_gives: StringName = NOTHING,
	p_wants: StringName = NOTHING,
	p_amount: float = 0.0,
	p_gold: float = 0.0,
) -> void:
	gives = p_gives
	wants = p_wants
	amount = p_amount
	gold = p_gold


## What this reads as. **For the letter and the log**, and for nothing else.
func shape() -> StringName:
	return shape_of(gives, wants)


static func shape_of(gives_what: StringName, wants_what: StringName) -> StringName:
	if gives_what == SPECIALTY and wants_what == NOTHING:
		return GIFT
	if gives_what == NOTHING and wants_what == NEED:
		return REQUEST
	if gives_what == SPECIALTY and wants_what == NEED:
		return BARTER
	if gives_what == SPECIALTY and wants_what == GOLD:
		return SALE
	if gives_what == GOLD and wants_what == NEED:
		return PURCHASE
	return NOTHING


func is_real() -> bool:
	return String(shape()).is_empty() == false


# --- 🔒 What he will propose, at this regard --------------------------------

## The shapes this patron would put in the post, cheapest regard first.
##
## **Sorted and complete**, so the draw below is deterministic and a shape that
## stops being offered is a number moving rather than a branch disappearing.
static func shapes_at(loyalty: float) -> PackedStringArray:
	var out := PackedStringArray([String(REQUEST)])
	if loyalty >= PURCHASE_ABOVE:
		out.append(String(PURCHASE))
	if loyalty >= SALE_ABOVE:
		out.append(String(SALE))
	if loyalty >= BARTER_ABOVE:
		out.append(String(BARTER))
	if loyalty >= GIFT_ABOVE:
		out.append(String(GIFT))
	out.sort()
	return out


## Build the offer of a named shape. Empty fields are the whole of the difference.
static func of_shape(
	name: StringName, amount_wanted: float, gold_wanted: float
) -> PatronOffer:
	match name:
		GIFT:
			return PatronOffer.new(SPECIALTY, NOTHING, amount_wanted, 0.0)
		REQUEST:
			return PatronOffer.new(NOTHING, NEED, amount_wanted, 0.0)
		BARTER:
			return PatronOffer.new(SPECIALTY, NEED, amount_wanted, 0.0)
		SALE:
			return PatronOffer.new(SPECIALTY, GOLD, amount_wanted, gold_wanted)
		PURCHASE:
			return PatronOffer.new(GOLD, NEED, amount_wanted, gold_wanted)
		_:
			return PatronOffer.new()


# --- 🔒 One resolution path -------------------------------------------------

## Settle an offer the PC answered (Seam A).
##
## 🔒 **Nothing here asks which of the five shapes it is holding.** It reads
## `gives` and `wants`, which is the model; `shape()` goes into the payload for
## the prose and the log and is read by nothing that decides.
##
## A dev who writes `if offer.shape() == GIFT` has made five mechanics out of
## one, and the sixth somebody adds later will be missing from five places.
##
## **And the deed banks either way** (`prestige.md` §5). Granting is a favour and
## refusing is a slight; both are things he will say at court, and both go
## through `PatronCredit`, which already knows what a deed is worth and refuses
## to count silence.
static func settle(
	offer: PatronOffer,
	patron: Contact,
	accepted: bool,
	log: EventLog,
	month: int,
) -> Dictionary:
	if offer == null or patron == null or not offer.is_real():
		return {}

	var moved := {
		"to_the_colony": _moved(offer.gives, patron, offer.amount, offer.gold),
		"to_the_patron": _moved(offer.wants, patron, offer.amount, offer.gold),
	}
	if not accepted:
		# 🔒 **Nothing moves and the slight still lands.** A refusal is an answer,
		# and §5 prices an answer.
		moved = {"to_the_colony": {}, "to_the_patron": {}}

	var banked := PatronCredit.bank(
		patron,
		Relationship.GRANTED if accepted else Relationship.REFUSED,
		log, month)

	if log != null:
		log.emit(EVENT_SETTLED, patron.id, month, {
			"patron": String(patron.id),
			# **For the prose, and for nothing that decides.**
			"shape": String(offer.shape()),
			"gives": String(offer.gives),
			"wants": String(offer.wants),
			"accepted": accepted,
			"banked": banked,
			"to_the_colony": moved["to_the_colony"],
			"to_the_patron": moved["to_the_patron"],
		}, WorldPhase.DISPATCH)
	return moved


## What one side of an offer actually is, as a shipment or a sum.
##
## **Three answers and no fourth**, because `gives` and `wants` have three
## values between them — which is what makes the five shapes five and not
## thirty.
static func _moved(
	what: StringName, patron: Contact, amount: float, gold: float
) -> Dictionary:
	match what:
		SPECIALTY:
			return {"shipment": patron.specialty, "amount": amount}
		NEED:
			return {"shipment": patron.need, "amount": amount}
		GOLD:
			return {"gold": gold}
		_:
			return {}
