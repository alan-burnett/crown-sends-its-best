class_name DeliberationContext
extends RefCounted

## What an actor knows while deciding.
##
## Contacts react to **change** as much as to standing conditions — "revenue
## fell by a third" and "revenue is low" are different judgments — so the
## context carries the diff alongside the state.
##
## It also carries the `EventLog`, because `choose()` always emits its trace
## (`docs/mechanics/deliberation.md` §6) and passing the log in is what makes
## that structural rather than something a caller must remember.

## Which decision is being made. Selects the considerations that apply.
var kind: StringName = &""

var state: WorldState = null
var diff: WorldDiff = null
var log: EventLog = null

var month: int = 0
var phase: StringName = &""

## The actor's own RNG stream, where a decision needs one. Never the global RNG.
var rng: RandomNumberGenerator = null

## Whatever else the considerations for this kind need — the Order being
## resolved, the letter under consideration, the town doing the deciding.
var data: Dictionary = {}


func _init(p_kind: StringName = &"", p_state: WorldState = null, p_log: EventLog = null) -> void:
	kind = p_kind
	state = p_state
	log = p_log
	if state != null:
		month = state.month


func get_value(key: String, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)
