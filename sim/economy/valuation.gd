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
	# 🔒 **Multiplied together, never one instead of the other** (#141). A
	# patron's barony and a war must both be able to act at once, and a shortage
	# on top of either.
	return ResourceCatalogue.price_of(resource) \
		* PolicyEffects.price_multiplier(state, resource) \
		* CrownPrices.multiplier(state, resource)


# --- The town ---------------------------------------------------------------

## What anything is worth to a town that has no use for it.
##
## ## 🔒 An absolute figure, not a share of `base`
##
## **A share of `base` is not a collapse**, and getting this wrong produced the
## clearest bug in #135: a town drowning in furs and drowning in cloth still
## valued the cloth at four times the furs, because both had been scaled by the
## same fraction. So it put a hand on the loom and spent the month turning a
## surplus it did not want into a different surplus it did not want, and the
## scoring called it the best work available.
##
## §3 says the valuation *collapses* once the town is above desired stock. A
## collapse levels things. What the town does with the pile afterwards is Sell's
## question and the Crown's price answers it — Work has no business ranking two
## things the town has no use for.
##
## Not zero, only because a valuation at zero would let a town pay duty to be rid
## of something. Tuning (§10).
const SURPLUS_FLOOR: float = 0.25


## What a unit is worth to this town, this month (#135, §3).
##
## ## 🔒 Base plus need, and both halves are necessary
##
##     valuation  =  base  +  need
##
## `base` is what the resource is worth to the town **in itself** — its entry in
## §1's dictionary, an authored figure independent of the Crown's price. `need`
## is a signed premium on top: positive while the town is below its desired
## stock, negative once it is above.
##
## **They add, they do not multiply.** Multiplying would make the premium
## proportional to a town's existing opinion of the thing, so a town desperate
## for grain and a town desperate for horses would be desperate in different
## currencies.
##
## And `base` cannot be derived from the Crown's price. Derive it and the gap
## between the two dictionaries becomes a function of shortfall alone — every
## surplus sells and every shortage buys, whatever the resource, §1's "no lumber
## trade" row cannot happen, and valuation is always at or above what the Crown
## pays so the sell rule never fires at all.
##
## ## One number, four questions
##
## This is the only thing the town's economy asks. Which tiles to work is
## `yield x valuation`; whether to buy is valuation above the Crown's price plus
## duty; whether to sell is valuation below what the Crown pays after duty;
## what to keep is the same gap restated. **There is no second scoring rule
## anywhere**, which is what stops the map and the ledger disagreeing.
static func town(resource: StringName, desired: DesiredStock, held: float) -> float:
	var base := ResourceCatalogue.town_base(resource)
	var wanted := desired.wanted(resource)
	# Normalised by the want, so shortfall is "how far short, as a share of what
	# was wanted" and reads the same for forty lumber as for four horses. A town
	# that wants none of a thing is measured against a single unit, so holding any
	# of it at all is a surplus.
	var shortfall := 1.0 if desired.leans_toward(resource) \
		else clampf((wanted - held) / maxf(wanted, 1.0), -1.0, 1.0)
	var need := base * desired.reach_of(resource) * shortfall
	return maxf(SURPLUS_FLOOR, base + need)


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


# --- Where the two dictionaries meet ----------------------------------------

## Whether this town would rather have the resource than the gold (§3).
##
## **The buy side of the gap.** Landed cost is the Crown's price plus the duty,
## so a rate high enough closes the trade on its own — which is §2's point that
## the Steward can be genuinely wrong about a rate rather than merely greedy.
static func worth_buying(
	resource: StringName,
	desired: DesiredStock,
	held: float,
	context: ColonyContext,
) -> bool:
	var landed := crown(resource, context.state) * (1.0 + context.tax_rate(resource))
	return town(resource, desired, held) > landed * (1.0 + MERCHANT_MARGIN)


## And whether it would rather have the gold than the resource.
##
## **The same gap read the other way**, which is why there is no third rule for
## what a town keeps: what it keeps is what neither of these fires on.
##
## The merchant's cut is on this side too. Somebody has to carry the thing across
## an ocean either way, and a margin charged only to importers would make the
## colony's exports look profitable at gaps that do not pay for the voyage.
static func worth_selling(
	resource: StringName,
	desired: DesiredStock,
	held: float,
	context: ColonyContext,
) -> bool:
	var net := crown(resource, context.state) * (1.0 - context.tax_rate(resource))
	return town(resource, desired, held) * (1.0 + MERCHANT_MARGIN) < net
