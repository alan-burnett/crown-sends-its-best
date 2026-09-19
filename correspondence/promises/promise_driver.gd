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
	promises.settle_due(contacts, log, state.month, can_crown_pay)


## Repudiate everything the Crown owes, the month it stops paying.
##
## Called by the standing driver in phase 6, **after** this phase has already
## settled what fell due — so a promise that came due during the warning window
## was paid before the faucet shut, which is what the window is for.
func repudiate(log: EventLog, month: int) -> Array[Promise]:
	if promises == null:
		return []
	return promises.repudiate(contacts, log, month)
