class_name Reconsideration
extends RefCounted

## Whether the town keeps doing what it is doing
## (`docs/mechanics/governor-objectives.md` §7).
##
## Runs every Settle, deterministically — no personality, no dice — and asks
## exactly three questions:
##
## 1. **Is the objective complete?**
## 2. **Has it stalled?**
## 3. **Has the intent changed since this objective was chosen?**
##
## If none hold, the town carries on.
##
## ## 🔒 Stickiness is not a tuned switching margin
##
## There is no hysteresis constant here and there must not be one. A town that is
## making progress on a sensible project simply continues, because none of the
## three tests fire — **not** because a margin held it in place. That is the
## difference between a town with a plan and a town whose plan is an artefact of
## a threshold, and it is why oscillation is impossible rather than merely
## unlikely.
##
## ## Sunk progress
##
## An intent change makes the objective **eligible** for reconsideration; it does
## not abandon it. A dock three weeks from completion gets finished; a dock
## barely begun does not.
##
## **The crisis case is the one that matters.** If the natives are burning the
## outskirts and the governor turns to defence, the town must not spend eleven
## more months on a dock — so a crisis intent overrides far deeper sunk progress
## than a routine change does.

const EVENT_ABANDONED: StringName = &"objective_abandoned"

## Months of no progress at all before an objective counts as going nowhere.
const SOFT_STALL_MONTHS: int = 3

## How far along a project has to be to survive an ordinary change of intent.
const ROUTINE_SUNK: float = 0.25

# Why an objective was set aside. Named, because the governor's next letter says
# which of these happened and a letter may not misrepresent it (SPEC §9.1).
const NONE: StringName = &"none"
const COMPLETED: StringName = &"completed"
const HARD_STALL: StringName = &"unobtainable"
const SOFT_STALL: StringName = &"going_nowhere"
const INTENT_CHANGED: StringName = &"intent_changed"


## Run the three tests. Returns why the town should stop, or `NONE`.
static func verdict(town: Town, context: ColonyContext) -> StringName:
	if not Objective.completes(town.objective):
		# A posture has nothing to complete and nothing to stall. It stands until
		# the intent it serves changes.
		if String(town.objective).is_empty():
			return COMPLETED
		return INTENT_CHANGED if _intent_moved(town) else NONE

	if hard_stalled(town, context):
		return HARD_STALL
	if soft_stalled(town):
		return SOFT_STALL
	if _intent_moved(town) and not _worth_finishing(town):
		return INTENT_CHANGED
	return NONE


## Whether the intent has moved since this objective was chosen for it.
static func _intent_moved(town: Town) -> bool:
	return town.objective_intent != town.intent


## Whether the sunk progress earns the project the right to be finished anyway.
static func _worth_finishing(town: Town) -> bool:
	# No intent is a crisis since survival went (#428); #429 retires the rule.
	return Objective.progress_fraction(town) >= ROUTINE_SUNK


## **Hard stall** — a required input cannot be obtained at all.
##
## Not "we have none this month": the town does not produce it, does not hold
## it, and cannot buy it. Patience does not fix that.
static func hard_stalled(town: Town, context: ColonyContext) -> bool:
	var outstanding := Objective.outstanding(town)
	var ids: PackedStringArray = PackedStringArray(outstanding.keys())
	ids.sort()
	for resource in ids:
		if not ObjectiveSelector.can_obtain(town, StringName(resource), context):
			return true
	return false


## **Soft stall** — the work is possible and is going nowhere.
##
## `objective_idle_months` is kept by the Build phase, which is the only thing
## that knows whether a month moved the project on. Counting it there and reading
## it here keeps the detection deterministic and out of Build's way.
static func soft_stalled(town: Town) -> bool:
	return town.objective_idle_months >= SOFT_STALL_MONTHS


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
