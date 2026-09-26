class_name Reconsideration
extends RefCounted

## Whether the town keeps doing what it is doing (#429,
## `docs/mechanics/governor-agendas.md` §3).
##
## 🔒 **An objective is held until it is complete, the governor's intent
## changes, or it stalls. Nothing else ends it.** There is no crisis override:
## the menu decided what was worth doing, and a hard month does not change that.
##
## **A building or an improvement stalls** (#467, `governor-agendas.md` §3):
## three months running with nothing committed to it, and the town gives it up,
## takes back what it had put in, and walks its menu again the same Settle —
## passing over what it has just shown it cannot build for `PASS_OVER_MONTHS`.
## Expeditions and companies never stall, because they can leave with nothing
## but their share of the people.
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
## A building or an improvement with nothing committed to it for three months.
const STALLED: StringName = &"stalled"

## Months running with nothing committed before a build stalls. Author's ruling
## (#467).
const STALL_MONTHS: int = 3

## How long a stalled objective is passed over by the menu walk. A placeholder
## (#467).
const PASS_OVER_MONTHS: int = 12


static func verdict(town: Town) -> StringName:
	if String(town.objective).is_empty():
		return COMPLETED
	if town.objective == AgendaMenu.NO_BUILDING:
		return OPEN
	# Before a change of intent: three idle months are a fact about the project
	# whatever the governor now wants, and a stall gives back what a change of
	# intent would forfeit.
	if has_stalled(town):
		return STALLED
	if town.objective_intent != town.intent:
		return INTENT_CHANGED
	return NONE


## Whether the town has stalled on what it is building. **Only a construction or
## an improvement can**: *no building*, an expedition and a company have nothing
## to commit to.
static func has_stalled(town: Town) -> bool:
	var kind := Objective.kind_of(town.objective)
	if kind != Objective.CONSTRUCTION and kind != Objective.IMPROVEMENT:
		return false
	return town.objective_idle_months >= STALL_MONTHS


## 🔒 **Give up a stalled build and take back what was in it** (#467) — unlike a
## change of intent, where the frame is lost. The town has shown it cannot finish
## the thing, so the frame comes down and its materials go back to the
## stockpile, and the walk passes the objective over for `PASS_OVER_MONTHS` so it
## does not take straight back what it just gave up. One event (Seam A).
static func stall(town: Town, context: ColonyContext) -> void:
	var given_up := town.objective
	if String(given_up).is_empty():
		return
	var progress := Objective.progress_fraction(town)
	var returned := town.objective_invested.duplicate()
	var ids := PackedStringArray(returned.keys())
	ids.sort()
	for resource in ids:
		town.store(StringName(resource), float(returned[resource]))
	var until := context.state.month + PASS_OVER_MONTHS
	town.pass_over(given_up, until)
	town.clear_objective()

	context.log.emit(EVENT_ABANDONED, town.id, context.state.month, {
		"town": String(town.id),
		"objective": String(given_up),
		"name": Objective.display_name(given_up),
		"reason": String(STALLED),
		"progress": progress,
		"forfeited": {},
		"returned": returned,
		"passed_over_until": until,
		"intent": String(town.intent),
	}, WorldPhase.COLONY_MONTH)


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
