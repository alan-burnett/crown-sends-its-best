class_name CultivationDriver
extends RefCounted

## The Diplomat cultivating the governor he lives with (#285,
## `docs/mechanics/the-diplomat.md` §7, `docs/mechanics/policy.md` §7).
##
## ## 🔒 The PC's only indirect lever on loyalty
##
## Everywhere else a contact's regard answers to what the PC did to **him**.
## This buys it with money and somebody else's effort — the one instrument
## against a governor the PC cannot otherwise reach: a proud man, a sullen one,
## or one already sliding toward sedition.
##
## ## 🔒 Only the governor he lives with
##
## The target is worked out from where the Diplomat is **this month**, never
## stored — so rehoming moves it for free, and `the-diplomat.md` §3's *he asks to
## be moved when his town turns dangerous* becomes a decision rather than a
## courtesy. **The PC now has a reason to move him toward trouble**, and the two
## pulls are opposite and both legitimate.
##
## ## 🔒 And it does not persist
##
## What he buys sits in `Relationship.cultivated`, apart from what the governor
## himself feels. The month the policy lapses, or the Diplomat dies in a town
## that turned on him, **the loyalty he was buying dies with him** — which is
## only expressible because it was never part of the man's own regard.
##
## Cleared for *everybody* rather than for the man who was being cultivated, so a
## Diplomat who was rehomed and then lost does not leave a warm governor behind
## in the town he left.

const EVENT_CULTIVATED: StringName = &"governor_cultivated"
const EVENT_LAPSED: StringName = &"cultivation_lapsed"

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(
	phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams
) -> void:
	if phase != WorldPhase.RECKONING or run == null:
		return

	var target := _being_cultivated(state)
	if target == null:
		_forget_everybody(log, state.month)
		return

	# **Everybody else first**, so a rehoming that moved the table also cools the
	# governor who used to sit at it.
	_forget_everybody(log, state.month, target)

	var before: float = target.relationship.cultivated
	target.relationship.cultivated = minf(
		PolicyEffects.CULTIVATION_CEILING, before + PolicyEffects.CULTIVATION_A_MONTH)
	if is_equal_approx(target.relationship.cultivated, before):
		return

	log.emit(EVENT_CULTIVATED, target.id, state.month, {
		"governor": String(target.id),
		# 🔒 **No figure for the player.** SPEC §8.5 keeps loyalty off his screens;
		# what a letter may say is that the Crown's man dined with him.
		"town": target.town,
	}, WorldPhase.RECKONING)


## The governor of the town the Diplomat is living in, while the policy runs.
##
## Null when there is no policy, no Diplomat, no town, or he is dead — each of
## which is the same answer as far as the governor is concerned.
func _being_cultivated(state: WorldState) -> Contact:
	if float(state.get_value(PolicyEffects.CULTIVATE_GOVERNOR_KEY, 0.0)) <= 0.0:
		return null
	var diplomat := run.contact(&"diplomat")
	if diplomat == null or diplomat.is_dead:
		return null
	var home := Diplomat.home_of(diplomat, run.colony)
	if home == null:
		return null
	return run.contact(home.governor_id)


## Drop what was bought from everybody but the man still being cultivated.
func _forget_everybody(log: EventLog, month: int, keep: Contact = null) -> void:
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact == null or contact == keep or contact.relationship == null:
			continue
		if is_zero_approx(contact.relationship.cultivated):
			continue
		contact.relationship.cultivated = 0.0
		log.emit(EVENT_LAPSED, contact.id, month, {
			"governor": String(contact.id),
		}, WorldPhase.RECKONING)
