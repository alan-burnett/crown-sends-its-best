class_name OrderDriver
extends RefCounted

## Carries the post across the ocean and hands it to the people it is addressed
## to.
##
## **The phase this runs in is the timing rule.** A letter arrives in phase 1,
## but it is not *read* until **phase 7, Reckoning** — a dispatch reaches a
## commander in the field after the fighting he was already committed to. He then
## commits to an Intent in phase 8, and carries it out in **phase 2 of the month
## after**.
##
## So an order written on turn T is acknowledged in turn T+1's letters, and its
## physical consequence happens during turn T+1's resolution, which the player
## watches in turn T+2's map playback. Resolving compliance anywhere earlier
## would quietly destroy the announce-then-act property.

var contacts: Dictionary = {}
var intents: IntentBook = null
var promises: PromiseBook = null

## The colony, so a governor who has renounced the Crown can be told apart from
## one who is merely disinclined (#72). Absent in fixtures that do not care.
var colony: Colony = null

## Standing instructions the PC has bought (#80). An enactor who agrees to one
## puts his name to it here, in the month he agrees.
var policies: PolicyBook = null

## The tribes' letters, which a governor who asked the PC holds open (#436).
var tribes: Tribes = null

const EVENT_ANSWER_URGED: StringName = &"tribe_answer_urged"

## Orders waiting to be read. Filled when the post is sent, emptied when it lands.
##
## 🔒 **The run's array, not the driver's** (#390). Under *Distant colony* an
## Order is still at sea when the game is saved, and the driver is rebuilt on
## load — so the bag it carries has to be one the save knows about. The turn
## machine hands it `RunState.orders_at_sea`, and nothing here may replace the
## array, only change what is in it.
var pending: Array[Order] = []

## What each order came to, for the letters that report it next month.
var results: Array[Dictionary] = []

## The seam crown standing (M3) plugs into. For M1 the Crown always pays.
var can_crown_pay: bool = true


func _init(p_intents: IntentBook = null, p_promises: PromiseBook = null) -> void:
	intents = p_intents
	promises = p_promises


func carry(order: Order) -> void:
	pending.append(order)


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING:
		return

	results.clear()
	# 🔒 **The outbound half of the crossing** (#390). An Order written this
	# month is read this month at the ordinary distance; under *Distant colony* it
	# waits on the water, and the ones still out stay in `pending` rather than
	# being dropped.
	#
	# It reads the same knob the inbound queue does, because §4 says *an extra
	# month each way* — two numbers would let a run exist in which the PC hears
	# late and is obeyed promptly, which is a slow contact rather than a distant
	# colony.
	var still_at_sea: Array[Order] = []
	for order in pending:
		if state.month - order.issued_month < Crossing.months():
			still_at_sea.append(order)
			continue
		var contact: Contact = contacts.get(String(order.addressed_to))
		if contact == null:
			push_error("Order addressed to unknown contact '%s'." % order.addressed_to)
			continue

		# A promise binds the PC from the moment it is read, whatever the
		# recipient then decides to do about the rest of the letter.
		var promise := PromiseBook.from_order(order, state.month)
		if promise != null and promises != null:
			promises.make(promise, contact, log, state.month)

		var rebel: Town = null if colony == null else colony.governed_by(contact.id)
		var result := Compliance.resolve(order, contact, intents, state, log, streams, rebel)
		result["order"] = order
		results.append(result)
		_enact_if_agreed(order, contact, result, state, log)
		_urge_the_answer_if_agreed(order, contact, result, state, log)
		_settle_policy(order, contact, state, log)

	pending.clear()
	pending.append_array(still_at_sea)


## A policy stands from the month its enactor agrees to it.
##
## **Only on a full compliance.** A policy half-agreed to is not a thing: he
## either puts his name to it or he does not, and a delay or a reinterpretation
## is the same as a no. That is the one place a policy differs from an ordinary
## Order, and it is because it is a standing commitment rather than a task.
func _enact_if_agreed(
	order: Order,
	contact: Contact,
	result: Dictionary,
	state: WorldState,
	log: EventLog,
) -> void:
	if policies == null or order.kind != M1Registrations.ORDER_ENACT_POLICY:
		return
	if String(result.get("outcome", "")) != String(Compliance.COMPLY):
		return

	var effect := StringName(order.get_param("effect", ""))
	if not PolicyEffects.is_effect(effect):
		push_error("Unknown policy effect '%s'. Add it to PolicyEffects." % effect)
		return

	policies.enact(Policy.new(
		contact.id,
		effect,
		float(order.get_param("cost", 0.0)),
		StringName(order.get_param("split", Policy.NONE)),
		order.params,
	), log, state.month)


## 🔒 **The PC's word on how to answer a tribe reaches the letter he asked about**
## (#436, `natives.md` §11), and only if his compliance took it. It is an urging
## on the letter, weighed with everything else when he answers this month; a
## refusal leaves him to answer exactly as he would have with no reply. The same
## moment a policy stands from, and for the same reason: he answers in the month
## the reply reaches him.
func _urge_the_answer_if_agreed(
	order: Order,
	contact: Contact,
	result: Dictionary,
	state: WorldState,
	log: EventLog,
) -> void:
	if tribes == null or order.kind != M1Registrations.ORDER_ANSWER_THE_TRIBE:
		return
	if String(result.get("outcome", "")) != String(Compliance.COMPLY):
		return
	var answer := StringName(order.get_param("answer", ""))
	var grievance := tribes.grievances.asked_by(contact.id)
	if grievance == null or not TribeGrievance.ANSWERS.has(answer):
		return
	grievance.urged = answer
	grievance.urged_tone = order.tone
	log.emit(EVENT_ANSWER_URGED, contact.id, state.month, {
		"grievance": String(grievance.id),
		"governor": String(contact.id),
		"urged": String(answer),
		"tone": String(order.tone),
	}, WorldPhase.RECKONING)


## The PC's answer to a man who said he would not carry it further (§4).
##
## **Everything resets**, including the warning: a policy made good is not a
## policy three months from lapsing, or the PC would have paid up and still
## watched it end. A lump sum is regard rather than gold in the sim's books —
## the Crown's side of it is the charge, which the new split already carries.
func _settle_policy(order: Order, contact: Contact, state: WorldState, log: EventLog) -> void:
	if policies == null:
		return
	var held := policies.held_by(contact.id)
	if held.is_empty():
		return

	match order.kind:
		M1Registrations.ORDER_FUND_POLICY:
			var split := StringName(order.get_param("split", Policy.ALL))
			var bonus := float(order.get_param("bonus", 0.0))
			for policy in held:
				policy.made_good(split)
			if bonus > 0.0 and contact.relationship != null:
				# Everybody loves a bribe.
				contact.relationship.record_deed(Relationship.GRANTED)
				contact.relationship.remember(
					Relationship.GRANTED, state.month, bonus, String(held[0].effect)
				)
		M1Registrations.ORDER_END_POLICY:
			for policy in held:
				policies.lapse(policy.id, log, state.month)


## Outcomes from the month just resolved, by contact.
func outcomes_for(contact_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for result in results:
		var order: Order = result["order"]
		if order.addressed_to == contact_id:
			out.append(result)
	return out
