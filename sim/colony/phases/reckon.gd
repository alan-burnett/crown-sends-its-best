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

## What a town lays out on comforts, as months of what it can drink valued at
## the dearest thing it might reasonably buy. Tuning.
const COMFORT_MONTHS: float = 2.5


## The purse for comforts. **Scaled by how well the town is already living**, so
## a wretched town spends what little it has on comforts and a thriving one
## spends more of a larger purse — which is the rum trap working rather than a
## special case (`quality-of-life.md` §8).
func _comfort_budget(town: Town, mouths: float) -> float:
	var drinkable := mouths * ColonyNeeds.luxury_per_head() * COMFORT_MONTHS
	return drinkable * ResourceCatalogue.price_of(&"tea")


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := Reckoning.new(town.id)
	var mouths := float(town.population())

	# What this governor's intent wants kept on hand, per head. Used twice: as a
	# reserve the town will not sell below, and as a want it goes shopping for.
	var stocks := Objective.intent_stocks(town.intent)

	# The month's trading account opens here, before Exchange and Sell write to
	# it, so what a governor reports is this month and not the run so far.
	town.traded_value = 0.0

	# Needs: what the town will die without.
	for resource in ColonyNeeds.needed_resources():
		var required := mouths * ColonyNeeds.per_head(StringName(resource))
		if required > 0.0:
			reckoning.needs[resource] = required

	# **And what the governor has made a need of** (#69, `crown-demands.md` §5).
	# A shipment he agreed to treat as a need outranks his own project: the town
	# buys to fulfil it and goes without. That is what makes his three answers a
	# choice of tier rather than a mood, and it is the whole cost the payment is
	# there to make up to him.
	var owed := Shipment.owed_by(context.intents, context.colony, town, Shipment.TIER_NEED)
	for resource in owed:
		reckoning.needs[resource] = float(reckoning.needs.get(resource, 0.0)) \
			+ float(owed[resource])

	# Tier 2, the objective: the rest of what it is building, over what has
	# already gone into the frame. Never more urgent than a need.
	reckoning.objective = Objective.still_to_gather(town)

	# Tier 3 also carries what the governor's intent wants laid in, which is the
	# demand side of the reserve above. Bought after the project and before the
	# rum: a governor bent on defence wants powder more than he wants a drink.
	for resource in stocks:
		var wanted := mouths * float(stocks[resource]) - before.held(town.id, StringName(resource))
		if wanted > 0.0:
			reckoning.wants[resource] = wanted

	# Tier 3, wants: comforts, bought with whatever survives the first two.
	# Worked out here rather than in Exchange so that all three tiers are
	# established in one place and read from one place.
	# **What the town will lay out on comforts**, which Exchange spends at the
	# margin. Not a per-kind appetite: which comfort is worth buying depends on
	# what the cellar holds and what each one is taxed at, and that is a decision
	# rather than a quantity (`town-economy.md` §2).
	reckoning.comfort_budget = _comfort_budget(town, mouths)

	# A selling floor, so a town does not buy rum in Exchange, drink a little in
	# Consume and sell the rest back in Sell — paying duty both directions, every
	# month, for nothing. A month of drinking, per kind.
	var cellar := mouths * ColonyNeeds.luxury_per_head() * LUXURY_MONTHS
	for resource in ResourceCatalogue.luxuries():
		reckoning.reserve[resource] = maxf(reckoning.reserve_of(StringName(resource)), cellar)

	# Reserve: months of need held back before anything is sold, plus whatever
	# the town's storehouses let it keep.
	var extra_months := Building.reserve_months_for(town)
	for resource in ColonyNeeds.needed_resources():
		var monthly := mouths * ColonyNeeds.per_head(StringName(resource))
		reckoning.reserve[resource] = monthly * (ColonyNeeds.reserve_months(StringName(resource)) + extra_months)

	# **A need's reserve extends to what the need is made of** (#64). Clothing is
	# woven from furs, so a town that sold every fur it trapped would stand at an
	# idle loom in a cold month and buy cloth from the Crown instead — which is
	# what it did before conversion existed, and would go on doing with a loom
	# standing in the town.
	for resource in ColonyNeeds.needed_resources():
		var making := StringName(resource)
		var inputs := ResourceCatalogue.inputs_for(making)
		if inputs.is_empty():
			continue
		var monthly := mouths * ColonyNeeds.per_head(making)
		var raw := monthly * ResourceCatalogue.input_per_unit_of(making) 			* (1.0 + ColonyNeeds.reserve_months(making))
		for input in inputs:
			reckoning.reserve[input] = maxf(reckoning.reserve_of(StringName(input)), raw)

	# **The objective raises the reserve on what it consumes.** The reserve exists
	# to serve the project, so what the project still needs is held back from
	# Relief and from Sell rather than being counted as spare.
	for resource in Objective.outstanding(town):
		reckoning.reserve[resource] = maxf(
			reckoning.reserve_of(StringName(resource)),
			float(Objective.outstanding(town)[resource]),
		)

	# **The intent raises it more broadly**, and this is one of the few ways a
	# governor's intent reaches the economy at all. A military intent does not
	# protect the guns the town has — it creates demand for guns it does not,
	# and sends the town shopping (`town-economy.md` §3).
	for resource in stocks:
		reckoning.reserve[resource] = maxf(
			reckoning.reserve_of(StringName(resource)),
			mouths * float(stocks[resource]),
		)

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
