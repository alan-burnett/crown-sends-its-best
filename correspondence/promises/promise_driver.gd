class_name PromiseDriver
extends RefCounted

## Settles promises in **phase 5, the Crown's month**.
##
## `docs/mechanics/world-month.md` puts "promises are honored or broken" there,
## and that phase must precede phase 7: a contact cannot acknowledge a promise
## the Crown has not yet broken.

var promises: PromiseBook = null
var contacts: Dictionary = {}

## The seam crown standing (M3) plugs into. For M1 the Crown always pays, and
## nothing here assumes a formula for when it would not.
var can_crown_pay: bool = true


func _init(p_promises: PromiseBook = null) -> void:
	promises = p_promises


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.CROWNS_MONTH or promises == null:
		return
	promises.settle_due(contacts, log, state.month, can_crown_pay, _wagers_won(log, state.month))


## Which revenue targets the colony actually reached (#69).
##
## **Judged off the Crown's own books**, through `CrownAccounts` — the same
## reduction crown standing uses and the same one the Ledger shows the player. A
## promise settled against a figure the player cannot find on his own sheet is a
## promise he cannot learn from.
##
## The window is the months the promise was outstanding, the month it was made
## excluded: a target accepted in March for six months is judged on April
## through September, because March was already spent when he agreed to it.
func _wagers_won(log: EventLog, month: int) -> Dictionary:
	var verdicts: Dictionary = {}
	var accounts: CrownAccounts = null
	for promise in promises.outstanding():
		if not promise.is_a_wager() or not promise.is_due(month):
			continue
		if promise.kind == Promise.KIND_SHIPMENT:
			verdicts[String(promise.id)] = _shipped(log, promise, month) >= promise.amount()
			continue
		if accounts == null:
			accounts = CrownAccounts.of(log)
		var earned := 0.0
		for at in range(promise.made_month + 1, month + 1):
			earned += accounts.received_in(at)
		verdicts[String(promise.id)] = earned >= promise.amount()
	return verdicts


## How much of the promised resource actually left a town inside the term.
##
## **Goods, not good intentions.** A governor who agreed and then could not
## deliver breaks the promise exactly as one who refused outright, because the
## Marshal is counting crates and not letters — which is what makes the PC's only
## power over goods he has already promised another letter.
func _shipped(log: EventLog, promise: Promise, month: int) -> float:
	var wanted := String(promise.terms.get("resource", ""))
	var total := 0.0
	for event in log.of_type(ShipmentExecutor.EVENT_SENT):
		if event.month <= promise.made_month or event.month > month:
			continue
		if String(event.payload.get("resource", "")) != wanted:
			continue
		total += float(event.payload.get("quantity", 0.0))
	return total


## Repudiate everything the Crown owes, the month it stops paying.
##
## Called by the standing driver in phase 6, **after** this phase has already
## settled what fell due — so a promise that came due during the warning window
## was paid before the faucet shut, which is what the window is for.
func repudiate(log: EventLog, month: int) -> Array[Promise]:
	if promises == null:
		return []
	return promises.repudiate(contacts, log, month)
