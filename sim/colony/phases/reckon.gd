class_name ReckonPhase
extends ColonyPhase

## **Reckon.** Each town works out, in priority order, what it must have, what
## its objective requires, and what it would like (SPEC §11.3 step 2), plus the
## reserve it holds back and what it can spare.
##
## It decides nothing and moves nothing. It writes down the quantities that
## **Relief, Exchange, Consume, Build and Sell all honour**, so that five phases
## asking the same question cannot get five answers — which is how a town ends up
## selling the grain it is about to eat.
##
## **🔒 Needs, then the objective, then wants** (SPEC §11.3) is enforced by the
## order the numbers are worked out in: needs and reserve come off the top, and
## only what survives that is spare.

const EVENT_RECKONED: StringName = &"town_reckoned"

## How much of each comfort a town would like to have, as months of what it can
## actually drink.
const LUXURY_MONTHS: float = 1.0


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := Reckoning.new(town.id)
	var mouths := float(town.population())

	# Needs: what the town will die without.
	for resource in ColonyNeeds.needed_resources():
		var required := mouths * ColonyNeeds.per_head(StringName(resource))
		if required > 0.0:
			reckoning.needs[resource] = required

	# Tier 2, the objective: the rest of what it is building, over what has
	# already gone into the frame. Never more urgent than a need.
	reckoning.objective = Objective.still_to_gather(town)

	# Tier 3, wants: comforts, bought with whatever survives the first two.
	# Worked out here rather than in Exchange so that all three tiers are
	# established in one place and read from one place.
	# **A buying target and a selling floor**, which is one number doing both jobs
	# (`town-economy.md` §3). Without the floor a town buys rum in Exchange,
	# drinks a little of it in Consume, and sells the rest back to the Crown in
	# Sell — paying duty in both directions, every month, for nothing.
	var appetite := mouths * ColonyNeeds.luxury_per_head() * LUXURY_MONTHS
	for resource in ResourceCatalogue.luxuries():
		var short_of := appetite - before.held(town.id, StringName(resource))
		if short_of > 0.0:
			reckoning.wants[resource] = short_of
		reckoning.reserve[resource] = maxf(reckoning.reserve_of(StringName(resource)), appetite)

	# Reserve: months of need held back before anything is sold, plus whatever
	# the town's storehouses let it keep.
	var extra_months := Building.reserve_months_for(town)
	for resource in ColonyNeeds.needed_resources():
		var monthly := mouths * ColonyNeeds.per_head(StringName(resource))
		reckoning.reserve[resource] = monthly * (ColonyNeeds.reserve_months(StringName(resource)) + extra_months)

	# A standing posture to stockpile or harvest something means the town parts
	# with none of it. Reserving all of it is how that becomes true everywhere at
	# once, rather than in each of the four phases that might have moved it.
	for hoarded in Objective.posture_focus(town):
		reckoning.reserve[hoarded] = maxf(
			reckoning.reserve_of(StringName(hoarded)),
			before.held(town.id, StringName(hoarded)),
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
		"objective": reckoning.objective,
		"wants": reckoning.wants,
		"reserve": reckoning.reserve,
		"short_of": reckoning.shortages(),
	}, WorldPhase.COLONY_MONTH)
