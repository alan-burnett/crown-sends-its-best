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

## The Provost's five (#173, `the-provost.md` §2).
##
## **Four of one shape and one of another.** The first four set how many people
## cross and what they bring; the fifth buys books, costs almost nothing, and
## reaches every town in the colony.
const VOLUME: StringName = &"immigration_volume"
const PROVISION: StringName = &"immigration_provision"
const EXPERTS: StringName = &"immigration_experts"
const LIVESTOCK: StringName = &"immigration_livestock"
const CURRICULUM: StringName = &"curriculum"

const PROVOST_KNOBS: Array[StringName] = [VOLUME, PROVISION, EXPERTS, LIVESTOCK, CURRICULUM]

## The journalist's two (#279, `institutional-contacts.md` §3).
##
## 🔒 **Neither is the trap.** What the PC must do to keep him loyal is the trap
## — hold the colony to the worst town rather than the average, and carry a
## programme that raises the stakes everywhere else over years. **What he gets
## for it is not.** Both of these are things a player should reach for, the cost
## is paid before the benefit arrives, and the benefit being genuinely good is
## what makes the bargain worth taking and worth regretting.
##
## A policy that was itself a hidden cost would make the whole man a trick. He is
## not a trick; he is sincere, and dangerous because of it. **Do not tune these
## down to compensate for the trap.**
const PUBLIC_RELATIONS: StringName = &"public_relations"
const CROWN_SENTIMENT: StringName = &"crown_sentiment"

## The scholar's (#280, `institutional-contacts.md` §3).
##
## *"I would like our experts to spread knowledge around the colony. We just need
## a little gold for their travel expenses. I will arrange all the travel and
## send them where they will be most useful. I suggest you build libraries
## wherever they go so they can keep up on their skills."*
##
## **Cheap, and not free.** It is travel expenses rather than an instrument, and
## the cost is what keeps it a decision — but the thing it buys is the only cure
## for expertise landing in the wrong town, so a PC who can afford anything
## should take it.
const TRAVELLING_EXPERTS: StringName = &"travelling_experts"

const ALL: Array[StringName] = [
	IMMIGRATION, FAVOUR_OUR_MARKET, VOLUME, PROVISION, EXPERTS, LIVESTOCK,
	CURRICULUM, PUBLIC_RELATIONS, CROWN_SENTIMENT, TRAVELLING_EXPERTS,
]

## What each knob is set to. **Four settings and no numbers**, because the PC is
## writing a letter and not filling in a form (`the-provost.md` §2).
const NOTHING: StringName = &"nothing"
const A_LITTLE: StringName = &"a_little"
const A_LOT: StringName = &"a_lot"
const A_GREAT_DEAL: StringName = &"a_great_deal"

const SETTINGS: Array[StringName] = [NOTHING, A_LITTLE, A_LOT, A_GREAT_DEAL]

## How far up each setting sits, from nought to one. The knobs differ in what
## they *buy*, below; they do not differ in what the words mean.
const SETTING_STRENGTH: Dictionary = {
	"nothing": 0.0,
	"a_little": 0.33,
	"a_lot": 0.66,
	"a_great_deal": 1.0,
}

## What a knob at its top setting is worth, per knob. All tuning
## (`the-provost.md` §9).
##
## 🔒 **Curriculum is the cheap one and the wide one.** It is the counterweight
## to the library: a library is expensive and raises one town a great deal, this
## is almost nothing and raises all of them slightly, so **a colony too poor to
## build anything can still have some learning**. Its figure is small on purpose
## and should stay small.
const AT_A_GREAT_DEAL: Dictionary = {
	"immigration_volume": 1.6,
	"immigration_provision": 2.0,
	"immigration_experts": 0.12,
	"immigration_livestock": 1.4,
	"curriculum": 1.2,
}

## What the colony is charged a month, per knob, at its top setting. Tuning.
##
## Curriculum is a **meagre payment** (§2) and costs a fraction of the others.
const MONTHLY_AT_A_GREAT_DEAL: Dictionary = {
	"immigration_volume": 240.0,
	"immigration_provision": 200.0,
	"immigration_experts": 300.0,
	"immigration_livestock": 160.0,
	"curriculum": 35.0,
}

## Where each knob's pressure lands, so the sim reads a world value and never
## the policy book.
const VOLUME_KEY: String = "policy.immigration.volume"
const PROVISION_KEY: String = "policy.immigration.provision"
const EXPERTS_KEY: String = "policy.immigration.experts"
const LIVESTOCK_KEY: String = "policy.immigration.livestock"

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

## Where the journalist's two press. Read by `DriftDriver` and `RebelSentiment`,
## which is what keeps either of them from having to know a policy book exists.
const PUBLIC_RELATIONS_KEY: String = "policy.public_relations"
const CROWN_SENTIMENT_KEY: String = "policy.crown_sentiment"

## Whether the scholar is arranging travel this month (#280). A flag rather than
## a figure: the transfers are an action, and `ExpertTravelDriver` is what takes
## it. Written here so the sim reads a world value and never the policy book,
## which is the rule every other policy follows.
const TRAVELLING_EXPERTS_KEY: String = "policy.travelling_experts"

## How much regard a month of good press earns every governor in the colony.
##
## Tuning, and deliberately worth having: §3's lock is that the benefit is not
## the trap and must not be tuned down to offset one.
const PUBLIC_RELATIONS_LIFT: float = 0.6

## 🔒 **A quarter of the rate, not twenty-five points off it** (#279).
##
## Ten per cent is counted as seven and a half, forty as thirty. **Not tuning** —
## the ticket fixes the figure, because "a quarter lower" is the whole
## description of what the policy does and a different number would be a
## different policy.
##
## 🔒 **The Crown still collects the real rate.** This reaches `RebelSentiment`
## and nothing else; no town pays a penny less and the Ledger is unchanged.
const CROWN_SENTIMENT_RELIEF: float = 0.25


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
			PUBLIC_RELATIONS:
				values[PUBLIC_RELATIONS_KEY] = \
					float(values.get(PUBLIC_RELATIONS_KEY, 0.0)) + PUBLIC_RELATIONS_LIFT
			CROWN_SENTIMENT:
				# **Never past the whole rate**, so no arrangement of policies can
				# make a town grateful for being taxed.
				values[CROWN_SENTIMENT_KEY] = minf(1.0,
					float(values.get(CROWN_SENTIMENT_KEY, 0.0)) + CROWN_SENTIMENT_RELIEF)
			TRAVELLING_EXPERTS:
				values[TRAVELLING_EXPERTS_KEY] = 1.0
			_:
				# The Provost's five (#173). Each presses on its own world value,
				# so the sim reads a figure and never the policy book.
				var knob := knob_key(policy.effect)
				if not knob.is_empty():
					values[knob] = float(values.get(knob, 0.0)) + worth_of(policy)
	return values


## The world value one of the Provost's knobs presses on.
static func knob_key(effect: StringName) -> String:
	match effect:
		VOLUME:
			return VOLUME_KEY
		PROVISION:
			return PROVISION_KEY
		EXPERTS:
			return EXPERTS_KEY
		LIVESTOCK:
			return LIVESTOCK_KEY
		CURRICULUM:
			# **The seam #168 cut and left open.** `Education` has read this key
			# since the month it was written; this is what finally writes it.
			return Education.CURRICULUM_KEY
		_:
			return ""


## What a knob at its setting is actually worth.
static func worth_of(policy: Policy) -> float:
	if policy == null:
		return 0.0
	var setting := String(policy.params.get("level", String(NOTHING)))
	return float(SETTING_STRENGTH.get(setting, 0.0)) \
		* float(AT_A_GREAT_DEAL.get(String(policy.effect), 0.0))


## What a knob at a setting costs the colony a month.
##
## Exposed so a letter can say the figure before the PC commits to it — **every
## choice's mechanical effect is understandable from its wording** (SPEC §9.2).
static func monthly_for(effect: StringName, setting: StringName) -> float:
	return float(SETTING_STRENGTH.get(String(setting), 0.0)) \
		* float(MONTHLY_AT_A_GREAT_DEAL.get(String(effect), 0.0))


## Whether this effect is one of the Provost's, for a letter or a test to ask.
static func is_a_knob(effect: StringName) -> bool:
	return PROVOST_KNOBS.has(effect)


## What the Crown pays for a resource, after whatever its officers have been
## persuaded of.
static func price_multiplier(state: WorldState, resource: StringName) -> float:
	if state == null:
		return 1.0
	return 1.0 + maxf(0.0, float(state.get_value(PRICE_PREFIX + String(resource), 0.0)))
