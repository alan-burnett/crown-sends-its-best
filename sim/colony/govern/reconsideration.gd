class_name Reconsideration
extends RefCounted

## Whether the town keeps doing what it is doing (#429,
## `docs/mechanics/governor-agendas.md` §3).
##
## 🔒 **An objective is held until it is complete, or the governor's intent
## changes. Nothing else ends it.** A town that goes broke keeps its objective and
## makes no progress — too bad. There is no stall detection and no crisis
## override: the menu decided what was worth doing, and a hard month does not
## change that.
##
## **No building never completes**, so the menu is walked again every Settle
## while it stands, and the first month a gate opens the town takes it.

const EVENT_ABANDONED: StringName = &"objective_abandoned"

# Why the objective is looked at again. Named, because the governor's next
# letter says which of these happened and a letter may not misrepresent it
# (SPEC §9.1).
const NONE: StringName = &"none"
const COMPLETED: StringName = &"completed"
const INTENT_CHANGED: StringName = &"intent_changed"
## Standing on *no building*, which is walked again every month.
const OPEN: StringName = &"open"


static func verdict(town: Town) -> StringName:
	if String(town.objective).is_empty():
		return COMPLETED
	if town.objective == AgendaMenu.NO_BUILDING:
		return OPEN
	if town.objective_intent != town.intent:
		return INTENT_CHANGED
	return NONE


## Set the objective aside, recording why. **Whatever was invested is gone** —
## the timber is already cut and standing in the half-built frame.
static func abandon(town: Town, reason: StringName, context: ColonyContext) -> void:
	var given_up := town.objective
	if String(given_up).is_empty():
		return
	var progress := Objective.progress_fraction(town)
	var forfeited := town.objective_invested.duplicate()
	town.clear_objective()

	context.log.emit(EVENT_ABANDONED, town.id, context.state.month, {
		"town": String(town.id),
		"objective": String(given_up),
		"name": Objective.display_name(given_up),
		"reason": String(reason),
		"progress": progress,
		"forfeited": forfeited,
		"intent": String(town.intent),
	}, WorldPhase.COLONY_MONTH)
