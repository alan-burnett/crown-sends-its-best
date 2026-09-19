class_name ColonyMeasures
extends RefCounted

## What a correspondent can be asked to judge, drawn from the real colony (#54).
##
## ## Why a governor sees different numbers under the same names
##
## The Crown's officers write about the colony. **A governor writes about his
## town**, and SPEC §8.2 makes him the PC's only window into a place. So the
## measure ids do not change — `food_security` is `food_security` — but for a
## governor they carry *his town's* answer.
##
## That is what lets one perception ladder serve both. The Steward saying the
## colony is amply provisioned and the Governor of Ashmere saying his people are
## in genuine want are not a contradiction: they are two true statements about
## different things, and the player has to hold both. Giving them separate
## measure ids would have made that a content problem to be remembered in every
## letter file rather than a property of who is writing.
##
## ## Truth in, bias out
##
## **Everything here is exact.** The lean that turns a number into a word lives
## in the perception resolver (`docs/mechanics/perception.md`), and it is capped
## at one rung whatever the contact's temperament. A measure that shaded itself
## would double the bias and let a letter say something false, which SPEC §9.1
## forbids.

## How far along the town's current project is, `0.0` to `1.0`.
const OBJECTIVE_PROGRESS: String = "objective_progress"

## How well stocked the town is against everything it needs, `0.0` to `1.0`.
const STOCKPILE_HEALTH: String = "stockpile_health"

## What the town bought and sold this month, in gold.
const TRADE_VOLUME: String = "trade_volume"

## Months of stock that counts as a healthy store. Matches the food ladder in
## `docs/mechanics/perception.md` §4 so the two read alike.
const HEALTHY_MONTHS: float = 3.0

## A month's trade for one town in good order. Tuning.
const BUSY_TRADE: float = 250.0


## What this contact is in a position to judge.
##
## A Crown officer gets the colony's figures; a governor gets his town's, under
## the same names.
static func for_contact(run: RunState, contact: Contact) -> Dictionary:
	var measures := WorldValues.measures(run.world)
	if contact == null or run.colony == null:
		return measures

	var town := run.colony.governed_by(contact.id)
	if town == null:
		return measures

	measures[WorldValues.FOOD] = food_months(town)
	measures[WorldValues.QUALITY_OF_LIFE] = town.quality_of_life
	measures[OBJECTIVE_PROGRESS] = Objective.progress_fraction(town)
	measures[STOCKPILE_HEALTH] = stockpile_health(town)
	measures[TRADE_VOLUME] = town.traded_value
	return measures


## Months of food in the larder, per mouth.
static func food_months(town: Town) -> float:
	var monthly := maxf(1.0, float(town.population())) * ColonyNeeds.per_head(&"food")
	if monthly <= 0.0:
		return 0.0
	return clampf(town.held(&"food") / monthly, 0.0, HEALTHY_MONTHS)


## How well stocked the town is across everything it must have.
##
## **The worst need, not the average.** A town with a year of grain and no cloth
## at all is not four-fifths well; it is a town with no cloth, and a governor
## writing home says so.
static func stockpile_health(town: Town) -> float:
	var worst := 1.0
	var mouths := maxf(1.0, float(town.population()))
	for resource in ColonyNeeds.needed_resources():
		var monthly := mouths * ColonyNeeds.per_head(StringName(resource))
		if monthly <= 0.0:
			continue
		var months := town.held(StringName(resource)) / monthly
		worst = minf(worst, clampf(months / HEALTHY_MONTHS, 0.0, 1.0))
	return worst
