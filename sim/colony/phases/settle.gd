class_name SettlePhase
extends ColonyPhase

## **Settle.** The month is totted up: how the town lived, whether it grew, and
## what it does next (SPEC §11.3, #50, #53).
##
## Four things happen, in this order, and the order is the reason it is one
## phase rather than four:
##
## 1. **Quality of life** is computed from the month that has just happened
##    (`QualityOfLife`, from `docs/mechanics/quality-of-life.md`).
## 2. **The population grows** from births, at a rate that reads the quality of
##    life just computed (SPEC §12.1).
## 3. **Each town reconsiders its objective**
##    (`docs/mechanics/governor-objectives.md` §7).
## 4. **The colony's condition** is settled: revenue is the duty the Crown
##    actually took (#47) and food security is what is left after eating (#48).
##
## ## 🔒 Quality of life is stored, and moved only here
##
## A reader that recomputed it would get a different answer halfway through a
## month and two readers would disagree. So it is written once, in Settle, and
## everything else in the game reads the field.
##
## ## 🔒 Rebel sentiment is not touched
##
## M3 owns it. QoL feeds sentiment, so sentiment must not feed back within a
## month (`quality-of-life.md` §7) — and the surest way to keep that true is that
## nothing here writes it at all.
##
## ## What is still a placeholder
##
## **Supply is a random walk.** Nothing derives it: it is the convoy, the Crown's
## shipping, the state of the road, and none of those are modelled. It moves so
## the letters do not go static, which is the failure #20 warns of, and it is not
## a model of anything.

const EVENT_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"
const EVENT_LIVED: StringName = &"town_lived"
const EVENT_BORN: StringName = &"town_grew"

# --- Population (SPEC §12.1) ------------------------------------------------

## Births a month per head, in a town living well.
##
## **Natural growth starts slowly and snowballs**: it is a share of the
## population, so a town of twelve gains a person every year or so and a town of
## two hundred gains several a month. Immigration, which §12.1 calls the main
## source of early growth, is M4.
const BIRTH_RATE: float = 0.006

## Below this quality of life nobody is having children.
const BARREN_BELOW: float = 0.25

# --- The drift, which nothing yet replaces ---------------------------------

const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const WAR_DRAIN: float = 0.09
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

## How many months of food the colony holds to count as fully secure. Matches
## the perception range in `docs/mechanics/perception.md` §4.
const SECURE_MONTHS: float = 3.0

## Changes smaller than this are not worth a letter noticing.
const NOTICEABLE: float = 0.02


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	_live(town, context)
	_grow(town, context)
	_reconsider(town, context)

	# The colony's condition is the colony's, not any one town's.
	if claim_month(context):
		_settle_the_colony(context)


## How the town lived this month.
func _live(town: Town, context: ColonyContext) -> void:
	var parts := QualityOfLife.of(town, context)
	var before := town.quality_of_life
	town.quality_of_life = float(parts["quality_of_life"])

	# **The direction and rough magnitude**, so a governor's letter can say that
	# things are looking up without the letter doing arithmetic — and so it
	# cannot say so when they are not (SPEC §9.1).
	var change := town.quality_of_life - before
	var direction := "steady"
	if change > NOTICEABLE:
		direction = "better"
	elif change < -NOTICEABLE:
		direction = "worse"

	context.log.emit(EVENT_LIVED, town.id, context.state.month, {
		"town": String(town.id),
		"quality_of_life": town.quality_of_life,
		"was": before,
		"change": change,
		"direction": direction,
		"health": float(parts["health"]),
		"safety": float(parts["safety"]),
		"means": float(parts["means"]),
		"hope": float(parts["hope"]),
		"pleasure": float(parts["pleasure"]),
	}, WorldPhase.COLONY_MONTH)


## Births. **Not immigration**, which is M4 and is the larger source.
func _grow(town: Town, context: ColonyContext) -> void:
	if town.quality_of_life < BARREN_BELOW or town.population() <= 0:
		return

	town.growth_accrued += float(town.population()) * BIRTH_RATE * town.quality_of_life
	var born := int(floor(town.growth_accrued))
	if born <= 0:
		return

	town.growth_accrued -= float(born)
	town.workers += born
	context.log.emit(EVENT_BORN, town.id, context.state.month, {
		"town": String(town.id),
		"born": born,
		"population": town.population(),
	}, WorldPhase.COLONY_MONTH)


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
		WorldValues.QUALITY_OF_LIFE: _colony_quality_of_life(context),
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


## How the colony is living, **weighted by where people actually are**.
##
## A colony of one wretched hamlet and one thriving city is not living averagely;
## it is mostly living the way the city does, because that is where most of it
## is. Weighting by population is what makes the Crown's impression of the
## colony match the impression of the average colonist.
func _colony_quality_of_life(context: ColonyContext) -> float:
	if context.colony == null or context.colony.is_empty():
		return 0.0
	var total := 0.0
	var mouths := 0.0
	for town in context.colony.in_order():
		var here := float(town.population())
		total += town.quality_of_life * here
		mouths += here
	if mouths <= 0.0:
		return 0.0
	return clampf(total / mouths, 0.0, 1.0)
