class_name BuildPhase
extends ColonyPhase

## **Build.** The objective advances, consuming resources, and may complete
## (SPEC §11.3, #49).
##
## ## Three kinds of objective
##
## A town building a church, or raising a farm on a named tile, is part-way
## through something. A town **stockpiling food** is not — it is behaving a certain way, indefinitely, and there is
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
## ## 🔒 The materials are the time (#148)
##
## A build used to need its materials gathered **and** its months elapsed, with
## the months authored beside the cost and kept plausible against it by hand.
## Now a town has a **build capacity** — resources a month it can put into
## construction, from its population and its `build_speed` — and only that much
## goes into the frame each month. A granary of sixty resources takes a town of
## capacity thirty exactly two months, and nothing had to be authored to say so.
##
## So stalling is one condition rather than two: the town cannot get the
## resources, or it has no capacity. A town short of one thing still stalls with
## its progress intact and picks up where it left off — what it has invested is
## in the frame.

const EVENT_ADVANCED: StringName = &"build_advanced"
const EVENT_STALLED: StringName = &"build_stalled"
const EVENT_COMPLETED: StringName = &"building_completed"


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	# A posture has nothing to advance and nothing to stall. It is not idleness —
	# Work and Reckon are both already bent by it.
	if not Objective.completes(town.objective):
		return

	# **Only what a month's hands can raise.** Sorted, so which resource goes into
	# the frame first is the colony's rather than the iteration order's.
	var capacity := Objective.build_capacity(town)
	var invested: Dictionary = {}
	var outstanding := Objective.outstanding(town)
	var ids: PackedStringArray = PackedStringArray(outstanding.keys())
	ids.sort()
	for resource in ids:
		if capacity <= 0.0:
			break
		var moved := town.invest(StringName(resource), minf(float(outstanding[resource]), capacity))
		if moved > 0.0:
			invested[resource] = moved
			capacity -= moved

	if not Objective.materials_complete(town):
		# **Stalled, not reset.** Everything moved above stays in the frame.
		#
		# A month only counts against the objective if **nothing at all** went
		# into it. A town putting a month's capacity into the frame is *advancing*
		# — that is now the whole of what advancing means (#148) — and a town
		# buying its tools a few at a time is gathering rather than going nowhere.
		# Counting those months would have it give up on everything expensive and
		# then give up on the replacement for the same reason, for ever (#53).
		var moving := not invested.is_empty()
		town.objective_progress += 1 if moving else 0
		town.objective_idle_months = 0 if moving else town.objective_idle_months + 1
		context.log.emit(
			EVENT_ADVANCED if moving else EVENT_STALLED,
			town.id, context.state.month, {
				"town": String(town.id),
				"objective": String(town.objective),
				"name": Objective.display_name(town.objective),
				"invested": invested,
				"still_needed": Objective.outstanding(town),
				"progress": Objective.progress_fraction(town),
				"months_done": town.objective_progress,
				"months_required": Objective.months_required(town),
			}, WorldPhase.COLONY_MONTH)
		return

	town.objective_progress += 1
	town.objective_idle_months = 0
	# **What it actually took**, not what it was projected to take. The projection
	# is the selector's business; a governor writing home reports the months.
	var required := town.objective_progress

	# Done. The effect comes from the thing standing, never from this phase
	# copying numbers onto the town — which is why completion only has to record
	# that it stands.
	var finished := town.objective
	var kind := Objective.kind_of(finished)
	var at := town.objective_target
	var payload: Dictionary = {
		"town": String(town.id),
		"objective": String(finished),
		"kind": String(kind),
		"name": Objective.display_name(finished),
		"months_required": required,
	}

	if kind == Objective.EXPEDITION:
		# **It leaves.** The people, the cargo and the matching share of the
		# purse go with it; where it goes is #176's business.
		Expedition.launch(town, context)
	elif kind == Objective.COMPANY:
		# **Men under arms** (#342). The same shape one tier up: a body of people
		# leaving a town with a share of its stores. Its commander, if the order
		# it was given needs one, is found when it is time to move.
		Raising.raise_from(town, context)
	elif kind == Objective.IMPROVEMENT:
		if context.map == null or not context.map.can_build(at.x, at.y, finished):
			# The ground changed under it. Nothing is refunded, because the work
			# was really done; the objective simply has nowhere to land.
			context.log.emit(EVENT_STALLED, town.id, context.state.month, {
				"town": String(town.id),
				"objective": String(finished),
				"name": Objective.display_name(finished),
				"invested": invested,
				"still_needed": {},
				"progress": Objective.progress_fraction(town),
				"months_done": town.objective_progress,
				"unbuildable_at": at,
			}, WorldPhase.COLONY_MONTH)
			town.objective_idle_months += 1
			return
		context.map.build(at.x, at.y, finished, context.log, context.state.month, town.id)
		payload["at"] = at
	else:
		town.add_building(finished)
		payload["grants_contact"] = Building.find(finished).grants_contact
		payload["unlocks"] = Building.unlocked_by(finished)

	town.clear_objective()
	# Remembered past the clearing, so the governor can write home about it.
	town.last_completed = finished
	town.last_completed_month = context.state.month
	context.log.emit(EVENT_COMPLETED, town.id, context.state.month, payload, WorldPhase.COLONY_MONTH)
