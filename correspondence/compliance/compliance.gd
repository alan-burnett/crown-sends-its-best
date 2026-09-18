class_name Compliance
extends RefCounted

## **Your orders are requests** (SPEC §8.5). This is where that becomes true.
##
## A player letter never touches sim state. It creates an **Order** addressed to
## a contact. The contact resolves it here — and what he does about it runs
## through the deliberation kernel, never a bespoke `if` chain, so a system added
## in a later milestone changes how contacts respond without anybody editing this
## file.
##
## **Acting alone is the same code path as complying**, with a different origin.
## That is the whole point of Seam C: "the contact complied with your order" and
## "the contact acted on his own and informed the PC afterward" are one mechanism.

# --- The six outcomes ------------------------------------------------------

const COMPLY: StringName = &"comply"
const PARTIAL: StringName = &"partial"
const DELAY: StringName = &"delay"
const REINTERPRET: StringName = &"reinterpret"
const REFUSE: StringName = &"refuse"
## Especially at low loyalty: he does what he thinks best and tells the PC after.
const ACT_ALONE: StringName = &"act_alone"

const OUTCOMES: Array[StringName] = [COMPLY, PARTIAL, DELAY, REINTERPRET, REFUSE, ACT_ALONE]

## Distinct event types, so next month's letters can key on what he did without
## unpacking a payload.
const OUTCOME_EVENTS: Dictionary = {
	COMPLY: &"order_complied",
	PARTIAL: &"order_partly_complied",
	DELAY: &"order_delayed",
	REINTERPRET: &"order_reinterpreted",
	REFUSE: &"order_refused",
	ACT_ALONE: &"contact_acted_alone",
}

## How long each outcome takes to carry out. **Consequential actions are
## multi-month so a letter can interrupt them**
## (`docs/mechanics/world-month.md` §3); a delay is simply a longer one.
const MONTHS_FOR: Dictionary = {
	COMPLY: 1,
	PARTIAL: 1,
	DELAY: 3,
	REINTERPRET: 2,
	ACT_ALONE: 2,
}

## What a partial compliance actually delivers. Tuning.
const PARTIAL_SHARE: float = 0.5


## Resolve one Order into an Intent, or into nothing if he refuses.
##
## Returns `{outcome, decision, intent}`. `intent` is null on a refusal, because
## a refusal is a thing that did not happen.
static func resolve(
	order: Order,
	contact: Contact,
	book: IntentBook,
	state: WorldState,
	log: EventLog,
	streams: RngStreams,
) -> Dictionary:
	var context := DeliberationContext.new(DecisionKind.ORDER_COMPLIANCE, state, log)
	context.phase = WorldPhase.RECKONING
	context.rng = streams.contact_stream(String(contact.id))
	context.data = {
		"order": order,
		"cost": cost_of(order),
		"payment": payment_in(order),
		"loyalty": contact.loyalty(),
		"vagueness": vagueness_of(order),
	}

	var decision := Deliberation.choose(contact, _candidates(), context)
	var outcome: StringName = decision.chosen_id() if decision.has_choice() else REFUSE

	log.emit(OUTCOME_EVENTS[outcome], contact.id, state.month, {
		"order": order.to_dict(),
		"outcome": String(outcome),
	}, WorldPhase.RECKONING)

	# **A costly request reduces loyalty unless the PC makes it up to them**
	# (SPEC §8.5). Paying generously for troops costs nothing; paying less does.
	_settle_loyalty(order, contact, outcome)

	var intent: Intent = null
	if outcome != REFUSE:
		intent = _intent_for(order, outcome, contact)
		book.commit(intent, log, state.month)

	return {"outcome": outcome, "decision": decision, "intent": intent}


static func _candidates() -> Array:
	var candidates: Array = []
	for outcome in OUTCOMES:
		candidates.append(Candidate.new(outcome, {"outcome": String(outcome)}))
	return candidates


## Turn the outcome into what he will actually do.
##
## **Acting alone produces an Intent exactly as complying does**, differing only
## in `origin`. Downstream, the executor cannot tell them apart — only the
## letters care.
static func _intent_for(order: Order, outcome: StringName, contact: Contact) -> Intent:
	var params := order.params.duplicate(true)

	match outcome:
		PARTIAL:
			if params.has("amount") and JsonTypes.is_int_like(params["amount"]):
				params["amount"] = int(JsonTypes.to_int(params["amount"], "amount") * PARTIAL_SHARE)
		REINTERPRET:
			# He does what he thinks you meant, which is not what you wrote.
			params["reinterpreted"] = true

	var intent := Intent.new(
		&"",
		StringName(order.kind),
		contact.id,
		StringName(order.get_param("to", String(contact.id))),
		int(MONTHS_FOR.get(outcome, 1)),
		params,
	)
	intent.origin = Intent.ORIGIN_WILL if outcome == ACT_ALONE else Intent.ORIGIN_ORDER
	return intent


## What the request costs the contact, roughly, in the same units as payment.
static func cost_of(order: Order) -> float:
	match order.kind:
		M1Registrations.ORDER_REQUEST_TROOPS:
			return 1000.0
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PROMISE_RESOURCE:
			# Being given something costs the recipient nothing.
			return 0.0
		M1Registrations.ORDER_REFUSE:
			return 0.0
	return 200.0


## How much room the order leaves to decide what the PC meant.
##
## An order carrying a figure is specific: send 200 of iron, pay 500 for troops.
## One carrying only words — set this policy, grant this favour — is not, and
## SPEC §8 expects personality to show in how a contact reads it.
static func vagueness_of(order: Order) -> float:
	for key in order.params:
		if key == "to":
			continue
		var value: Variant = order.params[key]
		var kind := typeof(value)
		if kind == TYPE_INT or kind == TYPE_FLOAT:
			return 0.0
	return 1.0


static func payment_in(order: Order) -> float:
	if order.params.has("payment"):
		return float(order.get_param("payment", 0.0))
	if order.kind == M1Registrations.ORDER_PROMISE_GOLD:
		return float(order.get_param("amount", 0.0))
	return 0.0


## How generously the PC paid, as a share of what the request costs.
static func payment_ratio(order: Order) -> float:
	var cost := cost_of(order)
	if cost <= 0.0:
		return 1.0
	return clampf(payment_in(order) / cost, 0.0, 1.0)


## Deeds move loyalty; the outcome does not.
##
## What the PC did — asked for something costly, paid for it or did not, granted
## something — is what registers. Whether the contact then complied is his own
## business, not a favour the PC did him.
static func _settle_loyalty(order: Order, contact: Contact, _outcome: StringName) -> void:
	match order.kind:
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PROMISE_RESOURCE, M1Registrations.ORDER_GRANT_FAVOR:
			contact.relationship.record_deed(Relationship.GRANTED)
		M1Registrations.ORDER_REFUSE:
			contact.relationship.record_deed(Relationship.REFUSED)
		M1Registrations.ORDER_REQUEST_TROOPS:
			# Paying generously leaves loyalty where it was; paying little stings.
			var shortfall := 1.0 - payment_ratio(order)
			if shortfall > 0.0:
				contact.relationship.record_deed(Relationship.REFUSED, shortfall)
		_:
			pass

	if not order.tone.is_empty():
		contact.relationship.record_tone(order.tone)
