class_name Valuation
extends RefCounted

## What a thing is worth, to whom (#136, `docs/mechanics/town-economy.md` §1).
##
## ## 🔒 Three dictionaries, and trade happens on the gap
##
## **A single price table was wrong.** No ship comes from the Crown carrying
## lumber, because a developed country and a forested colony value timber about
## the same and there is no gap to pay for the voyage. No food goes the other
## way, because the home country grows it on a scale the colony cannot touch.
##
## So the mercantile pattern is not a rule anywhere. The colony exports raw
## goods and imports manufactures **because the valuations say so**:
##
## | | Town | Crown | Result |
## | :--- | --: | --: | :--- |
## | Furs | low — it has plenty | high — scarce and fashionable | colony **sells** |
## | Tools | high — it needs them, makes few | low — it manufactures them | colony **buys** |
## | Lumber | low | low | **no trade** |
## | Food | moderate | low — grown at home at scale | **no trade** |
##
## That is the age of colonialism emerging from a price table.
##
## ## Every one of them is a function
##
## **Nothing is locked static.** A valuation is a function; a constant is a
## function with no inputs. Starting the Crown's as effectively fixed and adding
## drivers later costs nothing, whereas declaring it immovable would have to be
## undone.
##
## | Dictionary | Moves with | Pace |
## | :--- | :--- | :--- |
## | Town | desired stock against what it holds | monthly |
## | Natives | their circumstances — war, trust, what they hold | seasonal |
## | Crown | events at home — a failed harvest, a die-off, a war | slow |
##
## **When the Crown's prices do move, it is news.** A failed harvest at home
## means it will suddenly pay handsomely for colonial grain, reversing a trade
## that never made sense before and giving the Steward something worth writing
## about. That is content the model gets for free and a fixed table could never
## produce.
##
## ## 🔒 The PC has no lever on any of it
##
## SPEC §10.2 locks that his gold is not a wallet and §8.1 gives him no lever on
## terms of trade. **Prices move because the world moves, never because he
## asked**, which is why nothing here takes an Order and why no effect names a
## faction's valuation.

## The merchant's cut. **A trade only happens where the gap clears this**, which
## is what makes "no lumber trade" a consequence rather than a rule: there is no
## margin in carrying a thing across an ocean to sell it for what it was worth
## where it started.
const MERCHANT_MARGIN: float = 0.18


# --- The Crown --------------------------------------------------------------

## What the Crown will pay, before duty.
##
## **The seam was cut for a harvest failure and policy arrived through it first**
## (#80, `policy.md` §8). A patron whose specialty is horses can be persuaded to
## have his Barony buy from your colony instead of its neighbour, and the game
## expresses that as the Crown's price for horses going up.
##
## Which is the whole argument for a valuation being a function: a constant table
## could not have carried this without being rewritten, and the driver the player
## actually chose is more interesting than the weather.
static func crown(resource: StringName, state: WorldState = null) -> float:
	return ResourceCatalogue.price_of(resource) 		* PolicyEffects.price_multiplier(state, resource)


# --- The town ---------------------------------------------------------------
#
# **Not here yet, and deliberately.** §1 says the town's dictionary moves with
# desired stock against what it holds, which is #135 — but a town valuation
# expressed as a multiple of the Crown's price cannot produce §1's own table.
# The gap would be a function of shortfall alone, so every surplus would sell
# and every shortage would buy, whatever the resource, and "no lumber trade"
# could not fall out.
#
# The two dictionaries have to be independent absolute numbers, which means a
# second authored table. That is a content decision with a tea-rule constraint
# on it (#113), so it is the PO's rather than mine. Raised on #136.


# --- The natives ------------------------------------------------------------

## What a tribe thinks a thing is worth, as a multiple of the Crown's price.
##
## **A thing is valuable to them when making it requires a craft they cannot
## do**, and worthless when it does not. They are not short of land or its
## fruits.
##
## Cigars and rum are both made from what the land gives, but **rum needs a still
## and a cigar needs a pair of hands** — only one of those is a craft they lack.
## Iron at nothing and tools at everything says the same from the other end: the
## value is in the making, not the material.
##
## **Authored now and inert until M5.** Cutting the hole in the right shape is
## the point. `appetite` is where a tribe's circumstances will enter — a tribe at
## war wants guns and horses far more than one at peace (§12.5) — so this is not
## a fixed table with a hostility gate bolted on; the valuations themselves move.
static func natives(resource: StringName, appetite: Dictionary = {}) -> float:
	var base := crown(resource)
	var craft := ResourceCatalogue.native_worth(resource)
	return base * craft * float(appetite.get(String(resource), 1.0))
