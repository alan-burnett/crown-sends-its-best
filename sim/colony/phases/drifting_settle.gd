class_name DriftingSettle
extends ColonyPhase

## **Settle, partially.** What the colony's month adds up to, as far as the
## phases that exist can say.
##
## Two of the three headline numbers are now **derived from the towns** rather
## than invented here:
##
## - **Revenue** is the duty the Crown actually took this month, across Exchange
##   and Sell (#47). Not a drifting figure the Steward reports — the sum of real
##   transactions, each of which is in the log with its rate and its tax.
## - **Food security** is how many months of food the colony is holding after
##   Consume has eaten (#48).
##
## **Supply is still drifting.** Nothing derives it yet — it is the convoy, the
## Crown's shipping, the state of the road — and #50 is where it stops being a
## random walk. Until then something has to keep it moving or the Marshal and the
## Steward have nothing to disagree about, which is the failure #20 warns of.
##
## So: **#50 replaces what is left of the drift**, and inherits the derivations.
## The drifting half is not a model of anything and should not be built on. The
## derived half is.

const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const WAR_DRAIN: float = 0.09
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

## How many months of food a colony has to hold to count as fully secure.
const SECURE_MONTHS: float = 3.0

const EVENT_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"


func run(_town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	# The colony's condition is the colony's, not any one town's.
	if not claim_month(context):
		return

	var state := context.state
	var rng := context.streams.stream("sim")

	var war := float(state.get_value(WorldValues.WAR, 0.0))
	var supply := float(state.get_value(WorldValues.SUPPLY, 0.0))

	# The war pulls supply down; the colony pulls it back up. Which wins this
	# month is what the Marshal and the Steward end up arguing about.
	supply += SUPPLY_RECOVERY - war * WAR_DRAIN
	supply += rng.randf_range(-SUPPLY_NOISE, SUPPLY_NOISE)

	if rng.randf() < CONVOY_LOSS_CHANCE:
		supply -= CONVOY_LOSS
		context.log.emit(EVENT_CONVOY_LOST, &"colony", state.month, {
			"supply_lost": CONVOY_LOSS,
		}, WorldPhase.COLONY_MONTH)

	supply = clampf(supply, 0.0, 100.0)

	state.apply(context.log, EVENT_SETTLED, &"colony", {
		WorldValues.SUPPLY: supply,
		WorldValues.REVENUE: context.crown_tax,
		WorldValues.FOOD: _food_security(context),
	}, WorldPhase.COLONY_MONTH)


## Months of food the colony is holding, per mouth, capped.
##
## **Read after Consume, so it is what is actually left**, not what was harvested
## and then eaten. This is the number the Steward quotes and the governors write
## around, and SPEC §9.1 makes letters matching the simulation an invariant — so
## it had better be the food that is actually in the storehouses.
func _food_security(context: ColonyContext) -> float:
	if context.colony == null or context.colony.is_empty():
		return 0.0

	var held := 0.0
	var mouths := 0.0
	for town in context.colony.in_order():
		held += town.held(&"food")
		mouths += float(town.population())
	if mouths <= 0.0:
		return 0.0

	var monthly := mouths * ColonyNeeds.per_head(&"food")
	if monthly <= 0.0:
		return 0.0
	return clampf(held / monthly, 0.0, SECURE_MONTHS)
