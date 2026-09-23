class_name PromiseBook
extends RefCounted

## Every promise the PC has made, and the settling of them each month.
##
## Promises are honoured **automatically** while the PC is able to keep them
## (SPEC §9.5), so there is nothing for the player to do each month. What he
## notices is the month one breaks.
##
## Settling runs in **phase 5, the Crown's month**, which is where
## `docs/mechanics/world-month.md` puts "promises are honored or broken". That
## has to precede phase 7, Reckoning, because a contact cannot acknowledge a
## promise the Crown has not yet broken.

const EVENT_MADE: StringName = &"promise_made"
const EVENT_KEPT: StringName = &"promise_kept"
const EVENT_BROKEN: StringName = &"promise_broken"

## How long the PC has to make good on a promise before it falls due.
const DEFAULT_TERM_MONTHS: int = 1

var _promises: Array[Promise] = []
var _next_ordinal: int = 0


## Record a promise made in a letter.
##
## Created by an effect (#11) and recorded against the Relationship (#12), so a
## contact knows what is outstanding without anybody having to look it up.
func make(promise: Promise, contact: Contact, log: EventLog, month: int) -> Promise:
	if promise.id.is_empty():
		promise.id = StringName("promise_%d" % _next_ordinal)
	_next_ordinal += 1
	promise.made_month = month
	if promise.due_month <= month:
		promise.due_month = month + DEFAULT_TERM_MONTHS

	_promises.append(promise)
	if contact != null:
		contact.relationship.add_promise(String(promise.id))
	log.emit(EVENT_MADE, promise.to, month, promise.to_dict(), WorldPhase.DISPATCH)
	return promise


## Build a promise from an Order, or null if that Order promises nothing.
static func from_order(order: Order, month: int) -> Promise:
	match order.kind:
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PAY_TRIBUTE:
			# 🔒 **Tribute is a gold promise like any other** (SPEC §8.4, v3.0).
			# It comes out of the Crown's purse, so it lands on `net_position` and
			# lowers Crown Standing *and* prestige together
			# (`rival-pressure.md` §4) — and a Crown that has closed its purse
			# breaks it, which costs the PC the duke's regard at the worst
			# possible moment. None of that needs a second mechanism.
			return Promise.new(order.addressed_to, &"gold", {
				"amount": order.get_param("amount", 0),
			}, month, 0)
		M1Registrations.ORDER_PROMISE_RESOURCE:
			# The colony sends this from its own stockpiles, so the Crown cannot
			# refuse it.
			var promise := Promise.new(order.addressed_to, &"resource", {
				"amount": order.get_param("amount", 0),
				"resource": order.get_param("resource", ""),
			}, month, 0)
			promise.payer = Promise.PAYER_COLONY
			return promise
		M1Registrations.ORDER_PROMISE_REVENUE:
			# **Not the Crown's money to refuse**, and not the colony's to hand
			# over either: it is a figure the colony's own trade either reaches or
			# does not. The payer is recorded as the colony so that a Crown
			# repudiation leaves it standing — the Treasury closing its purse does
			# not excuse the PC from what he said his colony would earn.
			var wager := Promise.new(order.addressed_to, Promise.KIND_REVENUE, {
				"amount": order.get_param("amount", 0),
				"term_months": order.get_param("months", 0),
			}, month, month + int(order.get_param("months", 0)))
			wager.payer = Promise.PAYER_COLONY
			return wager
		M1Registrations.ORDER_PROMISE_SHIPMENT:
			# Settled on goods that actually left a town, not on the PC's word or
			# on a governor's answer. A governor who agreed and then could not
			# deliver breaks it exactly as one who refused outright.
			var undertaking := Promise.new(order.addressed_to, Promise.KIND_SHIPMENT, {
				"amount": order.get_param("amount", 0),
				"resource": order.get_param("resource", ""),
				"term_months": order.get_param("months", 0),
			}, month, month + int(order.get_param("months", 0)))
			undertaking.payer = Promise.PAYER_COLONY
			return undertaking
		M1Registrations.ORDER_GRANT_FAVOR:
			return Promise.new(order.addressed_to, &"favor", {
				"favor": order.get_param("favor", ""),
			}, month, 0)
	return null


# --- Settling --------------------------------------------------------------

## Honour or break every promise that has fallen due.
##
## `can_crown_pay` is the seam **crown standing plugs into in M3** (#17 says not
## to design that model here, and SPEC §17 defers part of it). For M1 the Crown
## always pays, and nothing in this file assumes a formula.
func settle_due(
	contacts: Dictionary,
	log: EventLog,
	month: int,
	can_crown_pay: bool = true,
	verdicts: Dictionary = {},
) -> Array[Promise]:
	var settled: Array[Promise] = []
	for promise in _promises:
		if not promise.is_due(month):
			continue

		var crown_refused := promise.payer == Promise.PAYER_CROWN and not can_crown_pay
		var contact: Contact = contacts.get(String(promise.to))

		if crown_refused:
			_break(promise, contact, log, month, "the Crown refused the payment", true)
		elif promise.is_a_wager() and not bool(verdicts.get(String(promise.id), false)):
			# **The bet the PC lost.** He promised what his colony would return and
			# it did not return it. Nobody refused him anything; he was wrong about
			# his own colony, which costs more than an honest refusal would have.
			_break(promise, contact, log, month, "the colony's trade fell short of the figure")
		else:
			_keep(promise, contact, log, month)
		settled.append(promise)
	return settled


## **The Crown repudiates everything it owes on the PC's word** (#70, SPEC §10.3).
##
## Not the promises that happen to fall due — *every* outstanding one. When the
## Treasury stops, it stops for all of them at once, and because the PC typically
## owes several people this lands as a broad collapse in goodwill rather than a
## single penalty. That breadth is intended and is the head of the failure
## spiral: broken promises lower loyalty, lower loyalty worsens compliance
## (SPEC §8.5), worse compliance raises rebel sentiment (§12.3).
##
## **Only gold drawn on the Crown.** A promise the colony fulfils from its own
## stockpiles is not the Crown's to refuse — a governor sending resources to a
## neighbour is unaffected.
##
## Returns what was broken, so the caller can say who was let down.
func repudiate(contacts: Dictionary, log: EventLog, month: int) -> Array[Promise]:
	var broken: Array[Promise] = []
	for promise in outstanding():
		if promise.payer != Promise.PAYER_CROWN or promise.kind != &"gold":
			continue
		# 🔒 **This is the spiral the perk defuses** (#287, *My boss is a jerk*).
		# `REFUSING` breaks every gold promise at once, so it lands as a broad
		# collapse in goodwill rather than one penalty — and it is the Crown that
		# said no, not the PC.
		_break(promise, contacts.get(String(promise.to)), log, month,
			"the Crown has stopped honouring what you pledged", true)
		broken.append(promise)
	return broken


## Break a promise for a reason other than the Crown's refusal — lack of means,
## or an Intent that never completed.
func break_promise(promise: Promise, contact: Contact, log: EventLog, month: int, reason: String) -> void:
	_break(promise, contact, log, month, reason)


func _keep(promise: Promise, contact: Contact, log: EventLog, month: int) -> void:
	promise.status = Promise.KEPT
	promise.settled_month = month
	if contact != null:
		contact.relationship.settle_promise(String(promise.id), true, month)
		contact.relationship.remember(
			Relationship.DELIVERED, month, promise.amount(),
			String(promise.terms.get("resource", "")),
		)
	log.emit(EVENT_KEPT, promise.to, month, promise.to_dict(), WorldPhase.CROWNS_MONTH)


func _break(
	promise: Promise,
	contact: Contact,
	log: EventLog,
	month: int,
	reason: String,
	by_the_crown: bool = false,
) -> void:
	promise.status = Promise.BROKEN
	promise.settled_month = month
	promise.broken_reason = reason
	# **A broken promise costs loyalty**, however it broke.
	if contact != null:
		contact.relationship.settle_promise(String(promise.id), false, month, by_the_crown)
		# The one a man is least likely to forget: being refused is
		# disappointing, being promised is being lied to (#127).
		contact.relationship.remember(
			Relationship.PROMISE_BROKEN, month, promise.amount(),
			String(promise.terms.get("resource", "")),
		)
	var payload := promise.to_dict()
	payload["reason"] = reason
	log.emit(EVENT_BROKEN, promise.to, month, payload, WorldPhase.CROWNS_MONTH)


# --- Reading ---------------------------------------------------------------

func all() -> Array[Promise]:
	return _promises.duplicate()


func outstanding() -> Array[Promise]:
	var out: Array[Promise] = []
	for promise in _promises:
		if promise.is_outstanding():
			out.append(promise)
	return out


func outstanding_to(contact_id: StringName) -> Array[Promise]:
	var out: Array[Promise] = []
	for promise in outstanding():
		if promise.to == contact_id:
			out.append(promise)
	return out


func by_id(id: StringName) -> Promise:
	for promise in _promises:
		if promise.id == id:
			return promise
	return null


func broken_in(month: int) -> Array[Promise]:
	var out: Array[Promise] = []
	for promise in _promises:
		if promise.status == Promise.BROKEN and promise.settled_month == month:
			out.append(promise)
	return out


func to_dict() -> Dictionary:
	var entries: Array = []
	for promise in _promises:
		entries.append(promise.to_dict())
	return {"promises": entries, "next_ordinal": _next_ordinal}


static func from_dict(data: Dictionary) -> PromiseBook:
	var book := PromiseBook.new()
	for entry in data.get("promises", []):
		book._promises.append(Promise.from_dict(entry))
	book._next_ordinal = int(data.get("next_ordinal", book._promises.size()))
	return book
