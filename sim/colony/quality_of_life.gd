class_name QualityOfLife
extends RefCounted

## How pleasant or miserable the average citizen's life is
## (SPEC §11.3, `docs/mechanics/quality-of-life.md`).
##
## A value in `[0, 1]`, scoped to one town, **never shown to the player as a
## number**. It is read by immigration (§12.1), by rebel sentiment from M3
## (§12.3), and by every governor letter.
##
## ## 🔒 Memoryless, but the inputs remember
##
## **There is no carry-over term, no smoothing and no inertia.** Last month's
## value does not appear in this month's calculation, and adding a smoothing term
## would be a bug rather than a refinement.
##
## It is stable anyway, because most of what feeds it cannot move quickly: food
## stockpiles accumulate over months, so does objective progress, so does town
## gold. A large swing therefore needs several things to change at once — which
## is exactly what happens when something dramatic happens to a town. Smoothing
## would blunt the one case the design needs to land hard.
##
## ## The shape
##
## ```
## substance = w_health*health + w_safety*safety + w_means*means + w_hope*hope
## QoL       = substance + PLEASURE_LIFT * pleasure * (1 - substance)
## ```
##
## **Substance is a weighted sum, not a product.** Health does not gate the
## others. A town with five decent things going for it absorbs the loss of one; a
## town propped up by a single component collapses when that component goes. The
## same raid devastates a struggling town and merely bruises a thriving one.
##
## **Pleasure masks rather than adds.** It lifts the town a fraction of the way
## from wherever it stands towards contentment, so **its power is greatest when
## life is worst**. A thriving town gains almost nothing from more rum; a wretched
## town gains enormously. That is not a logical assessment of the situation. It is
## human nature, and it is the point.
##
## ## 🔒 Acyclicity
##
## QoL feeds rebel sentiment, so **it must never read rebel sentiment.** It may
## read facts about the world — was this town attacked, were the roads cut, is it
## in rebellion — but never the sentiment value itself. That keeps a month's
## computation acyclic while still allowing §12.3's multi-month spiral, mediated
## through things that actually happened rather than through a number reading
## itself.

# --- Weights. All tuning, all to be revised against the harness (#56) -------

const W_HEALTH: float = 0.30
const W_SAFETY: float = 0.25
const W_MEANS: float = 0.20
const W_HOPE: float = 0.25

## **Safety is inert until M5, so it is left out of the sum** (#117).
##
## Pinned at 1.0 and carrying a quarter of the weight, it contributed a flat
## 0.25 every month — which is not a component, it is a constant, and it put a
## floor of 0.25 under every town in the game. Across 400 harness runs quality of
## life never left 0.91–0.98 (#90), so every ladder hung on it had one reachable
## rung and every governor said the same word about his people for five years.
##
## Excluded and the rest renormalised: same relative balance between health,
## means and hope, and the full range reachable.
##
## **This widens the range; it does not create variation.** A town whose health,
## means and hope all sit near 1.0 still scores near 1.0. Real movement needs the
## colony to struggle, which is M3's pressures landing. This only removes the
## structural floor so that when they land, the ladders can discriminate.
##
## **Flipping this back is not the M5 plan.** The Author has asked that safety's
## return be a fresh look at how combat reaches quality of life rather than a
## restoration of these numbers — safety is not the only component a war touches.
const SAFETY_IS_INERT: bool = true

## How far pleasure carries a town from where it stands towards contentment.
const PLEASURE_LIFT: float = 0.45

## **Fitness weighs more than progress.** A town forgives slow work on the right
## problem far more readily than fast work on the wrong one.
const FITNESS_SHARE: float = 0.65
const PROGRESS_SHARE: float = 0.35

## Months of food in the larder that counts as secure.
##
## **The single number that most sets the colony's difficulty**, per the doc's
## open items. Matches the perception range in `perception.md` §4, so the
## governor's word for the food situation and the town's feeling about it move
## together.
const SECURE_MONTHS: float = 3.0

## How health divides between a full larder and a clothed population.
const FOOD_SHARE: float = 0.7

## Gold per head at which a town can buy what it wants when the ship docks.
const COMFORTABLE_PURSE: float = 30.0

## Luxury types a town needs before variety stops adding anything.
const VARIETY_TARGET: float = 3.0

## What a single luxury is worth against three. Beer alone is worth less than
## beer, rum and tea together.
const VARIETY_FLOOR: float = 0.6

## How much of the town's regard a governor earns for *intending* the right thing
## before the project serving it has been chosen.
##
## The doc calls hope "a reading of his intent right now" and also ties fitness
## to the objective. Both: the project counts fully and the bare intent counts
## for most of it, which is what makes writing to a governor **the fastest lever
## the PC has** — hope moves the month he adopts the idea, not the month the
## church is finished.
const INTENT_SHARE: float = 0.7


## Every component and the value they make, for one town.
##
## Returned whole rather than as a single float because the letters and the
## balance harness both want to know *which* part of a town's life is bad, and
## recomputing the parts from the total is not possible.
static func of(town: Town, context: ColonyContext) -> Dictionary:
	var wellbeing: Dictionary = context.wellbeing.get(String(town.id), {})

	var parts: Dictionary = {
		"health": health_of(town, wellbeing),
		"safety": safety_of(town),
		"means": means_of(town),
		"hope": hope_of(town, context),
		"pleasure": pleasure_of(wellbeing),
	}
	parts["substance"] = substance_of(parts)
	parts["quality_of_life"] = combine(float(parts["substance"]), float(parts["pleasure"]))
	return parts


## The weighted sum of the components that are not pleasure.
##
## Renormalised over whichever of them can actually vary, so that leaving one out
## changes the range and not the balance between the rest.
static func substance_of(parts: Dictionary) -> float:
	var total := (
		W_HEALTH * float(parts.get("health", 0.0))
		+ W_MEANS * float(parts.get("means", 0.0))
		+ W_HOPE * float(parts.get("hope", 0.0))
	)
	if not SAFETY_IS_INERT:
		total += W_SAFETY * float(parts.get("safety", 0.0))
	return clampf(total / live_weight(), 0.0, 1.0)


## What the weights add up to, over the components that can move.
static func live_weight() -> float:
	var total := W_HEALTH + W_MEANS + W_HOPE
	if not SAFETY_IS_INERT:
		total += W_SAFETY
	return maxf(0.001, total)


## What a component is worth once the sum has been renormalised.
##
## Exposed so a test can state the interim balance without recomputing it, and
## so nothing has to hardcode 0.40 where 0.30 is written.
static func effective_weight(raw: float) -> float:
	return raw / live_weight()


## Pleasure lifts, it does not add.
static func combine(substance: float, pleasure: float) -> float:
	return clampf(substance + PLEASURE_LIFT * pleasure * (1.0 - substance), 0.0, 1.0)


# --- The five components ----------------------------------------------------

## **Health.** Can people eat and stay warm.
##
## Food is measured against a *reserve*, not against this month's consumption:
## eating exactly enough every month is not the same as being secure, and ample
## food in the larder is what a high-QoL town has.
##
## **Livestock count towards the buffer**, at the rate a hungry town would
## actually get out of them (§12.2). That is what makes a herd matter before M4
## brings pastures, and it is why a town with cattle feels safer than its grain
## alone would suggest.
static func health_of(town: Town, wellbeing: Dictionary) -> float:
	var mouths := maxf(1.0, float(town.population()))
	var monthly := mouths * ColonyNeeds.per_head(&"food")

	var larder := town.held(&"food")
	for id in ResourceCatalogue.livestock():
		larder += float(town.livestock_head(StringName(id))) * ResourceCatalogue.slaughter_yield_of(StringName(id))

	var fed := 0.0 if monthly <= 0.0 else clampf(larder / (monthly * SECURE_MONTHS), 0.0, 1.0)

	# Clothing is read from what Consume found, not from the stockpile: Consume
	# runs first and a well-clothed town ends the month holding none.
	var clothed := float(wellbeing.get("clothing", 0.0))

	return clampf(FOOD_SHARE * fed + (1.0 - FOOD_SHARE) * clothed, 0.0, 1.0)


## **Safety.** Is the population being attacked, and is it safe to travel.
##
## **Pinned at 1.0 through M2.** Natives arrive in M5 and the military in M6, so
## this is a component that does nothing for two milestones and then matters
## enormously — and the weights will want revisiting when it comes alive.
##
## One consequence worth knowing about while tuning: because safety carries a
## quarter of substance and is always 1.0, **no town in M2 can feel worse than
## `W_SAFETY`.** The bottom of the range is unreachable, and the lowest rungs of
## the governor's quality-of-life ladder cannot fire until natives arrive. The
## doc's own worst worked example needs a raid to get below it.
##
## Note what it is not. It is **not "is this town at war"** but "is this town
## threatened by forces it cannot handle". A rebel town that has beaten what was
## sent against it is *safe*, and that is precisely when it becomes most
## dangerous to the colony (doc §6). That is why this reads facts about what
## happened to the town and never reads rebel sentiment.
static func safety_of(_town: Town) -> float:
	return 1.0


## **Means.** Can the town buy what it wants when the ship docks.
##
## **The only route by which hidden town gold becomes perceptible** (SPEC §11.3).
## The player never sees the number; they see a governor who sounds comfortable
## or pinched. `Town.prosperity()` answers with a judgement rather than a
## balance, so even here the number does not escape.
static func means_of(town: Town) -> float:
	return town.prosperity(COMFORTABLE_PURSE)


## **Hope.** Not "how far along is the objective" but **"is anyone addressing
## what we actually need."**
##
## This is where the town's judgement of its governor lives: not trust built from
## past behaviour, but a reading of his intent right now. A starving town
## building cannons scores near zero; a starving town building farms scores high.
static func hope_of(town: Town, context: ColonyContext) -> float:
	return clampf(
		FITNESS_SHARE * fitness_of(town, context) + PROGRESS_SHARE * progress_of(town),
		0.0,
		1.0,
	)


## Does what the town is doing answer what the town is short of?
##
## The largest unmet need is Reckon's, worst-first, so five phases and the town's
## own morale are all reading the same answer to the same question.
static func fitness_of(town: Town, context: ColonyContext) -> float:
	var shortages := context.reckoning_for(town).shortages()
	if shortages.is_empty():
		# Nothing is going unaddressed, because nothing is unmet. A comfortable
		# town does not resent its governor for building a church.
		return 1.0

	var worst := StringName(shortages[0])
	return maxf(
		_objective_addresses(town, worst, context),
		INTENT_SHARE * _intent_addresses(town, worst),
	)


## Is the work actually moving?
##
## **A town stalled four months at eighty per cent has little hope; a town
## visibly advancing at twenty has more.** Which is why an idle month divides
## rather than merely failing to add.
static func progress_of(town: Town) -> float:
	if not Objective.completes(town.objective):
		# A standing posture is always underway by definition. It is neither
		# advancing nor stuck; the town simply does it.
		return 0.5 if Objective.is_posture(town.objective) else 0.0
	return clampf(
		Objective.progress_fraction(town) / float(1 + maxi(0, town.objective_idle_months)),
		0.0,
		1.0,
	)


## **Pleasure.** Luxuries, scaled by how much of the population they reached, with
## a bonus for variety.
##
## Note what this does to **tea**. SPEC §10.1 says the colony can never produce
## it, so it comes only from the Crown. The variety bonus therefore makes tea the
## luxury a prosperous town most wants and most depends on trade for — so taxing
## tea hurts a comfortable town exactly where it is softest, and §10.2's line
## about tea being favoured for the first trade protest falls out of the
## mechanics rather than being hardcoded.
static func pleasure_of(wellbeing: Dictionary) -> float:
	var served := clampf(float(wellbeing.get("luxury", 0.0)), 0.0, 1.0)
	if served <= 0.0:
		return 0.0
	var kinds := clampf(float(wellbeing.get("luxury_kinds", 0)) / VARIETY_TARGET, 0.0, 1.0)
	return clampf(served * (VARIETY_FLOOR + (1.0 - VARIETY_FLOOR) * kinds), 0.0, 1.0)


## How much of each comfort a town drinks in a month, given what it holds.
##
## **Evenly across the cellar, not down a list.** A town with beer and rum drinks
## some of each. Drawing in catalogue order instead would mean whichever comfort
## happens to be listed first is the only one anyone ever tastes: a town with a
## warehouse of beer would never touch the rum beside it, the variety bonus in
## `quality-of-life.md` §4 would be unreachable by buying, and "a town swimming
## in tea reaches for rum" (`town-economy.md` §2) could not be true however the
## buying was written.
##
## Water-filling: every kind takes an equal share of the month, and what a thin
## cellar cannot cover is shared out again over the rest. Ordered by id, so the
## result does not depend on how the catalogue is walked.
static func draw_from(mouths: float, held: Dictionary) -> Dictionary:
	var drawn: Dictionary = {}
	var left := mouths * ColonyNeeds.luxury_per_head()
	if left <= 0.0:
		return drawn

	var pool: PackedStringArray = PackedStringArray()
	for id in ResourceCatalogue.luxuries():
		if float(held.get(String(id), 0.0)) > 0.0:
			pool.append(String(id))
	pool.sort()

	while left > 0.000001 and not pool.is_empty():
		var share := left / float(pool.size())
		var thirsty: PackedStringArray = PackedStringArray()
		var round_took := 0.0
		for id in pool:
			var spare := float(held.get(id, 0.0)) - float(drawn.get(id, 0.0))
			var drunk := minf(share, spare)
			if drunk > 0.0:
				drawn[id] = float(drawn.get(id, 0.0)) + drunk
				round_took += drunk
			if spare - drunk > 0.000001:
				thirsty.append(id)
		if round_took <= 0.000001:
			break
		left -= round_took
		pool = thirsty
	return drawn


## What the town's comforts are worth, from a stockpile rather than from a
## month that has already happened.
##
## **The same draw Consume makes**, so the buying side and the drinking side
## cannot disagree about what a cellar is worth. A town that bought on one theory
## and drank on another would hold a heap of beer and wonder why it felt no
## better for it.
static func pleasure_from(mouths: float, held: Dictionary) -> float:
	var cap := mouths * ColonyNeeds.luxury_per_head()
	if cap <= 0.0:
		return 0.0

	var drawn := draw_from(mouths, held)
	var taken := 0.0
	for id in drawn:
		taken += float(drawn[id])
	return pleasure_of({
		"luxury": clampf(taken / cap, 0.0, 1.0),
		"luxury_kinds": drawn.size(),
	})


## How much better the town would feel for another `amount` of this.
##
## **The margin, given what it already has** (`town-economy.md` §2). A town
## swimming in tea gets more from its first rum than from its hundredth tea, and
## this is where that comes from — not from a rule about rum, but from the
## variety bonus read backwards.
static func marginal_pleasure(
	mouths: float,
	held: Dictionary,
	resource: StringName,
	amount: float,
) -> float:
	if amount <= 0.0:
		return 0.0
	var after := held.duplicate()
	after[String(resource)] = float(after.get(String(resource), 0.0)) + amount
	return pleasure_from(mouths, after) - pleasure_from(mouths, held)


# --- Who is addressing what -------------------------------------------------

## How much the current objective does about a resource the town is short of.
static func _objective_addresses(town: Town, resource: StringName, context: ColonyContext) -> float:
	match Objective.kind_of(town.objective):
		Objective.POSTURE:
			return 1.0 if Objective.posture_focus(town).has(String(resource)) else 0.0
		Objective.CONSTRUCTION:
			var building := Building.find(town.objective)
			var bonuses: Dictionary = building.effect("yield_bonus", {})
			if float(bonuses.get(String(resource), 0.0)) > 0.0:
				return 1.0
			# A storehouse does not grow grain, but a town short of it can see
			# the point of somewhere to keep more.
			if float(building.effect("reserve_months", 0.0)) > 0.0:
				return 0.6
			return 0.0
		Objective.IMPROVEMENT:
			var improvement := Improvement.find(town.objective)
			var at := town.objective_target
			if context.map == null or not context.map.in_bounds(at.x, at.y):
				return 0.0
			var terrain := Terrain.find(context.map.terrain_at(at.x, at.y))
			var before := context.map.yield_at(at.x, at.y, resource)
			return 1.0 if improvement.yield_of(terrain, resource) > before else 0.0
	return 0.0


## How much the governor's standing intent is about a resource the town is short
## of, through the axis that resource lives on.
static func _intent_addresses(town: Town, resource: StringName) -> float:
	var axis := "food" if resource == &"food" else "trade"
	if resource == &"clothing":
		# Clothing cannot be produced until conversion exists, so a town short of
		# it is waiting on trade whatever its governor intends.
		axis = "trade"
	return clampf(GovernorIntent.value_of(town.intent, axis), 0.0, 1.0)
