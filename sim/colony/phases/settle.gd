class_name SettlePhase
extends ColonyPhase

## **Settle.** The month is totted up and the town decides what it does next
## (SPEC §11.3, #53).
##
## Two things happen here, in this order:
##
## 1. **Each town reconsiders its objective**
##    (`docs/mechanics/governor-objectives.md` §7). Complete, stalled, or serving
##    an intent the governor no longer holds — any of those and it picks
##    something else, deterministically. None of them and it carries on.
## 2. **The colony's condition is worked out.** Revenue is the duty the Crown
##    actually took (#47) and food security is what is left after eating (#48).
##
## ## What is still a placeholder
##
## **Supply is a random walk and quality of life is not computed at all.** #50
## owns both. The drift is here rather than nowhere because the letters go static
## without it and a static playtest tests nothing (#20) — but it is not a model
## of anything and nothing should be built on it.
##
## The reconsideration half *is* a model, and is not #50's to replace.

const EVENT_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"

# --- The drift, which #50 replaces -----------------------------------------

const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const WAR_DRAIN: float = 0.09
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

## How many months of food the colony holds to count as fully secure. Matches
## the perception range in `docs/mechanics/perception.md` §4.
const SECURE_MONTHS: float = 3.0


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	_reconsider(town, context)

	# The colony's condition is the colony's, not any one town's.
	if claim_month(context):
		_settle_the_colony(context)


## The three tests, and a new objective when one of them fires.
func _reconsider(town: Town, context: ColonyContext) -> void:
	var verdict := Reconsideration.verdict(town, context)
	if verdict == Reconsideration.NONE:
		return

	# A stalled objective is not offered again this month. Anything else is:
	# a project the town finished is off the list on its own, and an objective
	# the intent moved away from may still be the best answer to the new one.
	var excluding: PackedStringArray = PackedStringArray()
	if verdict == Reconsideration.HARD_STALL or verdict == Reconsideration.SOFT_STALL:
		excluding.append(String(town.objective))

	if verdict != Reconsideration.COMPLETED:
		Reconsideration.abandon(town, verdict, context)

	var chosen := ObjectiveSelector.choose(town, town.intent, context, excluding)
	if chosen["id"] == &"":
		return

	town.objective = chosen["id"]
	town.objective_target = chosen["target"]
	town.objective_intent = town.intent
	town.objective_since = context.state.month
	town.objective_progress = 0
	town.objective_idle_months = 0
	town.objective_invested = {}

	context.log.emit(ObjectiveSelector.EVENT_CHOSEN, town.id, context.state.month, {
		"town": String(town.id),
		"objective": String(town.objective),
		"name": Objective.display_name(town.objective),
		"kind": String(Objective.kind_of(town.objective)),
		"target": town.objective_target,
		"intent": String(town.intent),
		"after": String(verdict),
	}, WorldPhase.COLONY_MONTH)


func _settle_the_colony(context: ColonyContext) -> void:
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

	state.apply(context.log, EVENT_SETTLED, &"colony", {
		WorldValues.SUPPLY: clampf(supply, 0.0, 100.0),
		WorldValues.REVENUE: context.crown_tax,
		WorldValues.FOOD: _food_security(context),
	}, WorldPhase.COLONY_MONTH)


## Months of food the colony is holding, per mouth, capped.
##
## **Read after Consume, so it is what is actually left**, not what was harvested
## and then eaten. This is the number the Steward quotes and the governors write
## around, and SPEC §9.1 makes letters matching the simulation an invariant — so
## it had better be the food that is really in the storehouses.
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
