class_name ReckonPhase
extends ColonyPhase

## **Reckon.** Each town works out what it needs and wants this month: its
## consumption, what its objective requires, the reserve it wants to keep, and
## what it can spare (SPEC §11.3).
##
## It decides nothing and moves nothing. It writes down the quantities that
## **Relief, Exchange, Consume, Build and Sell all honour**, so that five phases
## asking the same question cannot get five answers — which is how a town ends up
## selling the grain it is about to eat.
##
## **🔒 Needs before wants** is enforced by the order the numbers are worked out
## in: needs and reserve come off the top, and only what survives that is spare.

const EVENT_RECKONED: StringName = &"town_reckoned"


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := Reckoning.new(town.id)
	var mouths := float(town.population())

	# Needs: what the town will die without.
	for resource in ColonyNeeds.needed_resources():
		var required := mouths * ColonyNeeds.per_head(StringName(resource))
		if required > 0.0:
			reckoning.needs[resource] = required

	# Wants: the rest of what it is building, over what has already gone into the
	# frame. Never more urgent than a need.
	reckoning.wants = Objective.still_to_gather(town)

	# Reserve: months of need held back before anything is sold, plus whatever
	# the town's storehouses let it keep.
	var extra_months := Building.reserve_months_for(town)
	for resource in ColonyNeeds.needed_resources():
		var monthly := mouths * ColonyNeeds.per_head(StringName(resource))
		reckoning.reserve[resource] = monthly * (ColonyNeeds.reserve_months(StringName(resource)) + extra_months)

	# A standing posture to stockpile or harvest something means the town parts
	# with none of it. Reserving all of it is how that becomes true everywhere at
	# once, rather than in each of the four phases that might have moved it.
	var hoarded := Objective.posture_focus(town)
	if not String(hoarded).is_empty():
		reckoning.reserve[String(hoarded)] = maxf(
			reckoning.reserve_of(hoarded),
			before.held(town.id, hoarded),
		)

	# Spare and shortfall fall out of the above, from the town's stores as the
	# phase began.
	for resource in ResourceCatalogue.ids():
		var held := before.held(town.id, StringName(resource))
		var committed := reckoning.need_of(StringName(resource)) + reckoning.reserve_of(StringName(resource))
		var over := held - committed
		if over > 0.0:
			reckoning.spare[resource] = over
		var missing := reckoning.need_of(StringName(resource)) - held
		if missing > 0.0:
			reckoning.shortfall[resource] = missing

	context.reckonings[String(town.id)] = reckoning

	context.log.emit(EVENT_RECKONED, town.id, context.state.month, {
		"town": String(town.id),
		"needs": reckoning.needs,
		"wants": reckoning.wants,
		"reserve": reckoning.reserve,
		"short_of": reckoning.shortages(),
	}, WorldPhase.COLONY_MONTH)
