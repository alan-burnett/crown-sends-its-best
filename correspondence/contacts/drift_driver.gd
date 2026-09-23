class_name DriftDriver
extends RefCounted

## Moves every contact's regard with the world, once a month (#126).
##
## ## Phase 7, with the colony's month behind it
##
## Reckoning is where contacts take stock, and by then the colony month has run
## and the measures are this month's rather than last. A drift computed earlier
## would have every contact judging the PC on a month he had not yet had.
##
## It runs **before** compliance resolves this month's Orders, deliberately: a
## governor answering a letter does so in the mood the month has already put him
## in, which is how a colony going badly makes the PC's letters harder to land.

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or run == null:
		return

	var ids: Array = run.contacts.keys()
	ids.sort()  # Ordered, so the same month moves the same men in the same way.
	for id in ids:
		var contact: Contact = run.contacts[id]
		if contact == null or contact.relationship == null:
			continue

		var measures := ColonyMeasures.for_contact(run, contact)
		var drift := LoyaltyDrift.for_contact(contact, measures) \
			+ _good_press(contact, state)
		if is_zero_approx(drift):
			continue

		var before := contact.relationship.loyalty
		contact.relationship.drift(drift)
		log.emit(LoyaltyDrift.EVENT_DRIFTED, contact.id, state.month, {
			"contact": String(id),
			"direction": "warmer" if drift > 0.0 else "cooler",
			# **The topic, never the figure.** A contact who is cooling has a
			# reason and the reason is a thing he cares about — so his letters can
			# say the war is going badly without anybody seeing how badly he has
			# taken it.
			"about": LoyaltyDrift.loudest(contact, measures),
			"crossed": _crossed(before, contact.relationship.loyalty),
		}, WorldPhase.RECKONING)


## What a month of the journalist's *Public Relations* is worth to this man
## (#279, `institutional-contacts.md` §3).
##
## 🔒 **Governors only.** §3 has the policy swaying public opinion, and a
## governor is the town's leader and its voice — so what it buys is the regard of
## the men who run the colony, which `rebel-sentiment.md` §4 then carries into
## their towns through the prominence term that already exists. It buys nothing
## at court: the Crown's officers are an ocean away and do not read the colony's
## papers.
##
## **Read off a world value**, so this knows nothing about a policy book and a
## policy that ended stops pressing the month it ends.
func _good_press(contact: Contact, state: WorldState) -> float:
	if contact.role != Contact.ROLE_GOVERNOR or state == null:
		return 0.0
	return maxf(0.0, float(state.get_value(PolicyEffects.PUBLIC_RELATIONS_KEY, 0.0)))


## Whether this month took him past a figure that changes how he behaves.
##
## Reported so a letter can fire on the crossing rather than on the level, which
## is the difference between "he has turned against you" arriving once and
## arriving every month thereafter.
func _crossed(before: float, after: float) -> String:
	for mark in [25.0, 50.0, 75.0]:
		if before >= mark and after < mark:
			return "below_%d" % int(mark)
		if before < mark and after >= mark:
			return "above_%d" % int(mark)
	return ""
