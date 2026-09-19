class_name BuildPhase
extends ColonyPhase

## **Build.** The objective advances, consuming resources, and may complete
## (SPEC §11.3, #49).
##
## ## Two kinds of objective
##
## A town building a church is part-way through something. A town **stockpiling
## food** is not — it is behaving a certain way, indefinitely, and there is
## nothing here for Build to advance. Both are objectives; only one is a project.
##
## A governor who can only ever be half-way through a building writes the same
## letter every month. `Objective` holds both kinds; this phase acts on the one
## that has a finish and leaves the other to Work and Reckon, where it belongs.
##
## ## Invested is spent
##
## Resources go **out of the stockpile and into the frame**. They are not
## reserved, not earmarked — they are timber that has been cut and raised. So:
##
## - Consume cannot eat them, Sell cannot sell them, Relief cannot give them away.
## - **A town that runs short stalls rather than losing what it has already
##   invested**, which is the difference between a build that is waiting for
##   stone and a build that has to start over.
## - Abandoning the objective forfeits them, because the frame is already up.
##
## ## Labour after materials
##
## A build needs its materials *and* its months. Months only start counting once
## every resource is in — a crew does not raise a wall it has no stone for — so a
## town short of one thing stalls with its progress intact and picks up where it
## left off.

const EVENT_ADVANCED: StringName = &"build_advanced"
const EVENT_STALLED: StringName = &"build_stalled"
const EVENT_COMPLETED: StringName = &"building_completed"


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	# A posture has nothing to advance and nothing to stall. It is not idleness —
	# Work and Reckon are both already bent by it.
	if Objective.kind_of(town.objective) != Objective.CONSTRUCTION:
		return

	var building := Building.find(town.objective)
	var invested: Dictionary = {}
	var outstanding := Objective.outstanding(town)
	var ids: PackedStringArray = PackedStringArray(outstanding.keys())
	ids.sort()
	for resource in ids:
		var moved := town.invest(StringName(resource), float(outstanding[resource]))
		if moved > 0.0:
			invested[resource] = moved

	if not Objective.materials_complete(town):
		# **Stalled, not reset.** Everything moved above stays in the frame.
		context.log.emit(EVENT_STALLED, town.id, context.state.month, {
			"town": String(town.id),
			"objective": String(town.objective),
			"name": building.display_name,
			"invested": invested,
			"still_needed": Objective.outstanding(town),
			"progress": Objective.progress_fraction(town),
			"months_done": town.objective_progress,
		}, WorldPhase.COLONY_MONTH)
		return

	town.objective_progress += 1
	var required := Objective.months_required(town)

	if town.objective_progress < required:
		context.log.emit(EVENT_ADVANCED, town.id, context.state.month, {
			"town": String(town.id),
			"objective": String(town.objective),
			"name": building.display_name,
			"invested": invested,
			"months_done": town.objective_progress,
			"months_required": required,
			"progress": Objective.progress_fraction(town),
		}, WorldPhase.COLONY_MONTH)
		return

	# Done. The effect comes from the building standing, never from this phase
	# copying numbers onto the town — which is why completion only has to record
	# that it stands.
	var finished := town.objective
	town.add_building(finished)
	town.clear_objective()

	context.log.emit(EVENT_COMPLETED, town.id, context.state.month, {
		"town": String(town.id),
		"building": String(finished),
		"name": building.display_name,
		"months_required": required,
		"grants_contact": building.grants_contact,
		"unlocks": Building.unlocked_by(finished),
	}, WorldPhase.COLONY_MONTH)
