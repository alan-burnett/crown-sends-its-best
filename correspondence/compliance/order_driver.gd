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

## Orders waiting to be read. Filled when the post is sent, emptied when it lands.
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
	for order in pending:
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

	pending.clear()


## Outcomes from the month just resolved, by contact.
func outcomes_for(contact_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for result in results:
		var order: Order = result["order"]
		if order.addressed_to == contact_id:
			out.append(result)
	return out
