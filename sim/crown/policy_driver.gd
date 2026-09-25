class_name PolicyDriver
extends RefCounted

## Bills the month's policies and presses what they press
## (#80, `docs/mechanics/policy.md`).
##
## ## Phase 5, with the Crown's other money
##
## A policy's charge is the Crown's spending exactly as an honoured promise is,
## so it lands on the same books and `CrownAccounts` reduces both. It runs before
## standing is judged in phase 6, which is the point: **a PC who has taken on
## more than the colony returns watches his standing fall for it**, month after
## month, which is what a standing commitment ought to feel like.
##
## ## The pressure is recomputed, never accumulated
##
## Same reason as rebel sentiment: a policy that ended should stop pressing the
## month it ends, and a value that had been *added to* would have to be
## subtracted from by somebody who remembered to.

const EVENT_PRESSED: StringName = &"policy_pressure"

## What every world value a policy presses on is named under.
const POLICY_PREFIX: String = "policy."

var book: PolicyBook = null
var contacts: Dictionary = {}


func _init(p_book: PolicyBook = null) -> void:
	book = p_book


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.CROWNS_MONTH or book == null:
		return

	book.bill(contacts, log, state.month)
	# **Before the pressure is recomputed**, so a policy that ended this month
	# stops pressing this month rather than getting one more for free.
	book.take_stock(log, state.month)

	# Everything the standing policies press on, worked out afresh. Written
	# through `apply` so the diff carries it and the letters can see it move.
	var pressure := PolicyEffects.pressure(book)
	var changes: Dictionary = {}
	for key in _keys_to_clear(state):
		changes[key] = 0.0
	for key in pressure:
		changes[key] = float(pressure[key])
	if not changes.is_empty():
		state.apply(log, EVENT_PRESSED, &"crown", changes, WorldPhase.CROWNS_MONTH)


## Which policy-driven values the world is currently carrying.
##
## Cleared before this month's are written, so a lapsed policy leaves nothing
## behind. Reading the state for them rather than keeping a list means the same
## thing cannot be true in two places.
##
## **Every `policy.` value, not only the prices** (#442). This read the price
## prefix and immigration alone, so the journalist's press, the Provost's knobs,
## the scholar's travel and the Diplomat's dinners went on pressing at their last
## figure after the policy behind them had ended.
func _keys_to_clear(state: WorldState) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key in state.value_keys():
		if String(key).begins_with(POLICY_PREFIX) \
				or String(key) == WorldValues.IMMIGRATION:
			keys.append(String(key))
	keys.sort()
	return keys
