class_name DesiredStock
extends RefCounted

## What a town wants to be holding, and how badly (#135,
## `docs/mechanics/town-economy.md` §3).
##
## ## The other half of a valuation
##
## §3 makes a town's valuation `base + need`, where `base` is an authored figure
## and `need` is **how far below desired stock the town is**. This is that
## desired stock, and the doc names its four parts:
##
## > what the coming months' needs require
## > + what the objective requires
## > + what the intent leans toward
## > + what the town's buildings give it a use for
##
## ## Tiers are a reach, not a gate
##
## §4 says the tiers — needs, then the objective, then wants — are *"a heavy
## multiplier on valuation, not a gate"*. So each resource carries a **reach**
## alongside its amount: how steeply its valuation climbs as the town falls
## short of it. A town forty lumber short of a church wants that lumber far more
## urgently than a town forty lumber short of a comfortable pile, and the
## difference is the reach rather than a separate term added on.
##
## **This is what subsumes the old objective weight.** Work used to add a flat
## bonus to anything the objective called for; now the objective raises desired
## stock and the tier raises the reach, and the tile scoring never hears about
## objectives at all.
##
## ## Read from month-start state
##
## 🔒 Built from the snapshot the colony month opened with, never from what a
## town has already done this month. Work is phase 1 and Reckon is phase 2; if
## the two computed desired stock from different states they would disagree about
## what the town wants inside a single month, and the letters would report one of
## them while the map showed the other.

## How steeply valuation climbs, per tier (§4).
##
## **Needs and the objective both outrank a want, and the objective outranks a
## need.** That is not a claim that the church matters more than the grain — the
## survival check is a filter applied afterwards and it does not negotiate. It is
## that a town one month short of food is nearly always *slightly* short, where a
## town short of the church's lumber is short of all of it, and the reach is what
## makes the second read as urgent as it is.
const REACH_NEED: float = 2.0
const REACH_OBJECTIVE: float = 3.0
const REACH_INTENT: float = 1.5
const REACH_USE: float = 1.0

## How many months of input a town keeps for a building it actually has.
const USE_MONTHS: float = 2.0

## How much of each resource the town wants to be holding.
var amounts: Dictionary = {}

## And how steeply it minds falling short of each.
var reach: Dictionary = {}

## Resources it wants more of whatever it holds (§3, "what the intent leans
## toward").
var leans: Dictionary = {}


func wanted(resource: StringName) -> float:
	return float(amounts.get(String(resource), 0.0))


func reach_of(resource: StringName) -> float:
	return float(reach.get(String(resource), REACH_USE))


## Whether a standing order means no pile of this is ever enough.
##
## ## A want with no target, because that is what a standing order is
##
## **Every other want is a quantity and this one is not.** A town told to
## stockpile grain wants more grain — not more grain up to a number, which is a
## project rather than a posture.
##
## Expressing it as a quantity was tried and it decays: a lean of a few months'
## eating is a rounding error beside a stockpile of a hundred, so the valuation
## slides back to `base` and the town quietly stops obeying an order nobody
## countermanded. The player would watch a standing instruction fade out on its
## own, which is precisely the failure the correspondence loop exists to prevent.
##
## It is not an unbounded surplus either: `Objective.hoards` already stops the
## town selling what it is stockpiling, so the pile is the point. The bound is
## the player changing the order.
func leans_toward(resource: StringName) -> bool:
	return leans.has(String(resource))


## Raise the want on a resource, keeping the most urgent reason for it.
##
## **Max rather than sum**, on both. Two reasons to want forty lumber are still
## forty lumber, and a town that wanted grain for its people and again for its
## brewhouse would ask for twice what it eats.
func _want(resource: StringName, amount: float, tier: float) -> void:
	if amount <= 0.0:
		return
	var key := String(resource)
	amounts[key] = maxf(float(amounts.get(key, 0.0)), amount)
	reach[key] = maxf(float(reach.get(key, 0.0)), tier)


## What this town wants to be holding, from the state the month opened with.
static func for_town(town: Town, before: ColonySnapshot) -> DesiredStock:
	var desired := DesiredStock.new()
	# Rates are per thousand people (`Population`).
	var people := maxf(1.0, float(town.population()))
	var mouths := Population.thousands(people)

	# 1. **What the coming months' needs require.** This month's meal and the
	# months of reserve behind it, which is what the town's storehouses extend.
	for resource in ColonyNeeds.needed_resources():
		var id := StringName(resource)
		var monthly := mouths * ColonyNeeds.per_head(id)
		var extra_months := Building.reserve_months_for(town, id)
		desired._want(id, monthly * (1.0 + ColonyNeeds.reserve_months(id) + extra_months), REACH_NEED)

		# **A need's want extends to what the need is made of** (#64). Cloth is
		# woven, not harvested, so a town that valued furs at nothing would stand
		# at an idle loom in a cold month.
		var inputs := ResourceCatalogue.inputs_for(id)
		if inputs.is_empty():
			continue

		# **And it falls away as the need itself is met.** A want for the input
		# that never reads the output is a want the town can never satisfy: a
		# town with a year of cloth in its presses went on valuing furs as though
		# its people were in rags, so every forest tile outscored every field and
		# a standing order to grow grain could not outvote it. The shortfall on
		# the cloth is what the furs are wanted *for*.
		var want := monthly * (1.0 + ColonyNeeds.reserve_months(id) + extra_months)
		var short := clampf((want - before.held(town.id, id)) / maxf(want, 1.0), 0.0, 1.0)
		if short <= 0.0:
			continue
		var raw := monthly * Conversion.best_ratio(town, id) \
			* (1.0 + ColonyNeeds.reserve_months(id)) * short
		for input in inputs:
			desired._want(StringName(input), raw, REACH_NEED)

	# 2. **What the objective requires**, over what is already in the frame.
	var outstanding := Objective.outstanding(town)
	for resource in outstanding:
		desired._want(StringName(resource), float(outstanding[resource]), REACH_OBJECTIVE)

	# 3. **What the intent leans toward.** A military intent does not protect the
	# guns a town has; it creates a want for guns it does not.
	var stocks := Objective.intent_stocks(town.intent)
	for resource in stocks:
		desired._want(StringName(resource),
			Population.amount_for(StringName(resource), float(stocks[resource]), people), REACH_INTENT)
	for hoarded in Objective.posture_focus(town):
		var id := StringName(hoarded)
		desired.leans[String(hoarded)] = true
		desired._want(id, maxf(before.held(town.id, id), Population.amount_for(id, 1.0, people)), REACH_INTENT)

	# 4. **What the town's buildings give it a use for.** A loom makes furs worth
	# having in a way they are not in a town without one, and that is a fact about
	# the building rather than about furs.
	for recipe in Conversion.all():
		if not Building.improves_conversion(town, recipe.id()):
			continue
		desired._want(recipe.input, recipe.consumes_for(town) * USE_MONTHS, REACH_USE)

	# **And what they want laid in by name** (#148). A blanket reserve only made
	# a town sell less of everything, which is not an effect anybody would
	# choose; per-resource, it changes behaviour — a weavers' loom gives the town
	# a real reason to stockpile cotton instead of selling it.
	#
	# Months of *draw*, not months of consumption, because the resources a
	# building wants laid in are mostly ones nobody eats.
	for resource in Building.reserved_resources(town):
		var id := StringName(resource)
		var months := Building.reserve_months_for(town, id)
		desired._want(id, monthly_draw(town, id, mouths) * months, REACH_USE)

	return desired


## How much of a resource this town gets through in a month.
##
## What its people eat, or what its buildings put through the recipe that
## consumes it — whichever is larger. **A month has to mean something for a
## resource nobody eats**, or `reserve_months` on cotton would reserve nothing.
static func monthly_draw(town: Town, resource: StringName, mouths: float) -> float:
	var draw := mouths * ColonyNeeds.per_head(resource)
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if recipe.input == resource and recipe.available_to(town):
			draw = maxf(draw, recipe.consumes_for(town))
	return draw
