class_name DriftingSettle
extends ColonyPhase

## **Temporary.** What the stub world used to do to the colony's numbers, moved
## into the phase it belongs to.
##
## The colony's supply, revenue and food are not yet derived from anything — the
## phases that would derive them are #44 to #50. Until they land, something has
## to keep those numbers moving or the letters go static and the playtest tests
## nothing, which is the failure #20 warns about.
##
## So this drifts them, in **Settle**, where the town's condition is supposed to
## be worked out. **#50 replaces this file.** It is not a model of anything and
## should not be built on.

const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const WAR_DRAIN: float = 0.09
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

const REVENUE_FROM_SUPPLY: float = 14.0
const REVENUE_NOISE: float = 90.0
const REVENUE_SMOOTHING: float = 0.45

const FOOD_FROM_SUPPLY: float = 0.022
const FOOD_NOISE: float = 0.12

const EVENT_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"

## Whether it has already run this month. The drift belongs to the colony as a
## whole rather than to any one town, so it happens once however many towns there
## are — another reason this is a placeholder and not a model.
var _month_done: int = -1


func run(_town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	if _month_done == context.state.month:
		return
	_month_done = context.state.month

	var state := context.state
	var rng := context.streams.stream("sim")

	var war := float(state.get_value(WorldValues.WAR, 0.0))
	var supply := float(state.get_value(WorldValues.SUPPLY, 0.0))
	var revenue := float(state.get_value(WorldValues.REVENUE, 0.0))

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

	# Revenue follows supply but lags it, so a good month does not read as a
	# reversal and the Steward has something to be wrong about.
	var target := supply * REVENUE_FROM_SUPPLY + rng.randf_range(-REVENUE_NOISE, REVENUE_NOISE)
	revenue = lerpf(revenue, maxf(target, 0.0), REVENUE_SMOOTHING)

	var food := clampf(supply * FOOD_FROM_SUPPLY + rng.randf_range(-FOOD_NOISE, FOOD_NOISE), 0.0, 3.0)

	state.apply(context.log, EVENT_SETTLED, &"colony", {
		WorldValues.SUPPLY: supply,
		WorldValues.REVENUE: revenue,
		WorldValues.FOOD: food,
	}, WorldPhase.COLONY_MONTH)
