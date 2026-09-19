class_name PolicyEffects
extends RefCounted

## What a policy actually does to the world
## (#80, `docs/mechanics/policy.md` §8).
##
## ## Not a rate and not a flag
##
## > A policy's effect can reach into the economy, the population, the military,
## > or the Crown's own opinion of what things are worth.
##
## A patron whose specialty is horses can be persuaded to have his Barony stop
## buying from its neighbour and buy from your colony instead. **The game
## expresses that as the Crown's price for horses going up** — which is why
## `town-economy.md` §1 makes every faction's valuations a function rather than a
## constant table. That shape was built for harvest failures; policy turns out to
## be its other driver, and the more interesting one, because the player chose
## it.
##
## ## Ids into a registry, like everything else
##
## The content pipeline's rule (CLAUDE.md): conditions and effects are ids with
## typed params, never logic in a data file. The same holds here, so the letters
## that ask for a policy name an effect and supply its params, and adding one is
## adding an entry rather than a branch.

const IMMIGRATION: StringName = &"encourage_immigration"
const FAVOUR_OUR_MARKET: StringName = &"favour_our_market"

const ALL: Array[StringName] = [IMMIGRATION, FAVOUR_OUR_MARKET]

## World value prefix for a policy's standing pressure on a Crown price.
##
## Read by `Valuation.crown`, which is why that function has taken a `state` it
## did not use since #136: the seam was cut for a harvest failure and policy is
## what arrived through it first.
const PRICE_PREFIX: String = "policy.price."

## How much more the Crown pays for a resource its officers have been persuaded
## to favour. Tuning.
const MARKET_LIFT: float = 0.35

## How much faster people come to a colony the Crown is subsidising. Tuning.
const IMMIGRATION_LIFT: float = 0.5


static func is_effect(id: StringName) -> bool:
	return ALL.has(id)


## The world value one policy moves, or empty for the ones that do not.
static func world_key(policy: Policy) -> String:
	if policy.effect != FAVOUR_OUR_MARKET:
		return ""
	var resource := String(policy.params.get("resource", ""))
	return "" if resource.is_empty() else PRICE_PREFIX + resource


## Everything the standing policies press on, as world values.
##
## **Recomputed from the book rather than accumulated**, for the same reason
## rebel sentiment is: a policy that ended should stop pressing the month it
## ends, and a value that had been added to would have to be subtracted from by
## somebody who remembered to.
static func pressure(book: PolicyBook) -> Dictionary:
	var values: Dictionary = {}
	if book == null:
		return values
	for policy in book.active():
		match policy.effect:
			FAVOUR_OUR_MARKET:
				var key := world_key(policy)
				if not key.is_empty():
					values[key] = float(values.get(key, 0.0)) + MARKET_LIFT
			IMMIGRATION:
				values[WorldValues.IMMIGRATION] = \
					float(values.get(WorldValues.IMMIGRATION, 0.0)) + IMMIGRATION_LIFT
	return values


## What the Crown pays for a resource, after whatever its officers have been
## persuaded of.
static func price_multiplier(state: WorldState, resource: StringName) -> float:
	if state == null:
		return 1.0
	return 1.0 + maxf(0.0, float(state.get_value(PRICE_PREFIX + String(resource), 0.0)))
