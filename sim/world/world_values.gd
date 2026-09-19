class_name WorldValues
extends RefCounted

## The named scalars the world is made of, and what a run starts with.
##
## They live here rather than on whichever driver happens to move them, because
## more than one does: the Crown's war is the Crown's business and the colony's
## supply is the colony's, and the letters read both without caring which.

## The Crown's war, elsewhere. Moves in phase 5 and is not the colony's to touch.
const WAR: String = "crown_war_intensity"
const CAMPAIGN_MONTHS_LEFT: String = "crown_campaign_months_left"

## The colony.
##
## **Revenue and food security are derived from the towns**: revenue is the duty
## the Crown actually took this month (#47), food security is what the colony is
## holding once it has eaten (#48). Supply is still a drift and is #50's to
## replace.
const REVENUE: String = "colony_revenue"
const SUPPLY: String = "supply_situation"
const FOOD: String = "food_security"


static func initial_state() -> WorldState:
	var state := WorldState.new(0, {
		WAR: 35.0,
		REVENUE: 50.0,
		SUPPLY: 62.0,
		FOOD: 1.1,
		CAMPAIGN_MONTHS_LEFT: 0,
	})
	for key in TaxRates.initial_values():
		state.values[key] = TaxRates.initial_values()[key]
	return state


## The raw values a letter may judge, for the perception resolver.
static func measures(state: WorldState) -> Dictionary:
	return {
		WAR: float(state.get_value(WAR, 0.0)),
		REVENUE: float(state.get_value(REVENUE, 0.0)),
		SUPPLY: float(state.get_value(SUPPLY, 0.0)),
		FOOD: float(state.get_value(FOOD, 0.0)),
		"tax_burden": TaxRates.burden(state),
	}
