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

## **What the Crown appointed the governors to do** (SPEC §6.1). One per run,
## and a governor's intent leans towards it with a pull that decays over the
## run. M2 carries a fixed mandate; Run Setup in M3 supplies the value and
## nothing else changes.
const MANDATE: String = "crown_mandate"

## **How the colony is living**, weighted by where the people are (#50). Settle
## computes each town's and this is what the Crown's officers see of it.
const QUALITY_OF_LIFE: String = "quality_of_life"

## What a month's duty has lately come to, as a running average.
##
## **The reference a judgement about the returns is made against** (#63,
## `docs/mechanics/perception.md` §4a). Forty gold is a good month for a hamlet
## and a catastrophe for a colony of thirty thousand, so a ladder pinned to
## absolute gold says the same word for ever. Settle keeps this; nothing else
## writes it.
const REVENUE_BASELINE: String = "colony_revenue_baseline"

## How fast the running normal follows the figure. Tuning.
##
## Slow enough that one good month does not become the new expectation, fast
## enough that a colony which has genuinely grown stops being judged against
## what it was two years ago.
const BASELINE_FOLLOW: float = 0.2

## Below this there is no meaningful normal to judge against and everything
## reads as a ratio to nothing.
const BASELINE_FLOOR: float = 1.0


static func initial_state() -> WorldState:
	var state := WorldState.new(0, {
		WAR: 35.0,
		REVENUE: 50.0,
		SUPPLY: 62.0,
		FOOD: 1.1,
		CAMPAIGN_MONTHS_LEFT: 0,
		MANDATE: GovernorIntent.ECONOMY,
		QUALITY_OF_LIFE: 0.5,
		REVENUE_BASELINE: 50.0,
	})
	for key in TaxRates.initial_values():
		state.values[key] = TaxRates.initial_values()[key]
	return state


## What a letter may judge, for the perception resolver.
##
## **A measure is a scale for a judgement; a `{param:}` is the figure.** Most of
## these are already ratios and scale by construction. The one that is not —
## gold — is turned into one here rather than normalised against a constant,
## because a constant stops meaning anything as the colony grows
## (`docs/mechanics/perception.md` §4a).
##
## Nothing is lost by it. A letter can say the month brought four thousand in
## duties *and* that the returns are thin, in one sentence, because the number is
## absolute and the judgement is relative. That split is the whole design.
static func measures(state: WorldState) -> Dictionary:
	return {
		WAR: float(state.get_value(WAR, 0.0)),
		REVENUE: revenue_standing(state),
		SUPPLY: float(state.get_value(SUPPLY, 0.0)),
		FOOD: float(state.get_value(FOOD, 0.0)),
		QUALITY_OF_LIFE: float(state.get_value(QUALITY_OF_LIFE, 0.0)),
		"tax_burden": TaxRates.burden(state),
	}


## This month's duty against what a month lately brings, where `1.0` is normal.
##
## So a colony ten times the size reads the same when it is doing as well as it
## usually does — which is correct rather than merely convenient. A Steward
## saying the returns are thin means thin *for this colony*, and he is telling
## the truth either way.
static func revenue_standing(state: WorldState) -> float:
	var baseline := maxf(BASELINE_FLOOR, float(state.get_value(REVENUE_BASELINE, 0.0)))
	return float(state.get_value(REVENUE, 0.0)) / baseline


## Where the running normal lands once this month is counted.
##
## Exposed so Settle writes it through `apply()` with everything else it settles,
## rather than reaching into the state itself.
static func followed_baseline(state: WorldState, duty: float) -> float:
	var baseline := float(state.get_value(REVENUE_BASELINE, 0.0))
	if baseline <= BASELINE_FLOOR:
		# Nothing to follow yet: the first month it trades *is* the normal.
		return maxf(duty, BASELINE_FLOOR)
	return baseline * (1.0 - BASELINE_FOLLOW) + duty * BASELINE_FOLLOW
