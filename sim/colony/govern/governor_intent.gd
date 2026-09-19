class_name GovernorIntent
extends RefCounted

## What a governor wants for his town (`docs/mechanics/governor-objectives.md` §4).
##
## ## Two levels, and only one of them is personal
##
## **Intent** is the standing goal — *increase economic output*, *grow the
## population*, *strengthen our defences*. It may hold for twenty months. The
## governor chooses it, through the deliberation kernel, with his personality as
## the weight vector.
##
## **Objective** is the concrete project serving it — a church, a farm on tile
## 14, an expedition's stores. The *town* chooses that, deterministically, with
## no personality and no dice (`ObjectiveSelector`).
##
## **Personality decides what he wants; competence decides how it gets done.**
## He has wise advisors, so he never picks a foolish project — he picks an
## excellent project in service of a goal the PC may think is entirely wrong.
## **That is where the game lives.** The player argues with a governor's intent,
## never with his carpentry.
##
## ## 🔒 The PC cannot name an objective
##
## SPEC §8.5: *"An order reaches the governor's intent, never the town's
## objective. The PC can argue for a goal; he cannot name the project, the tile,
## or the month."*
##
## That is characterisation before it is mechanics — a pampered aristocrat who
## has never seen a dock does not have the vocabulary — but the mechanical
## reason is stronger. Objective selection is deterministic and well informed;
## everything the PC knows arrived through one man's perception ladders, a month
## late. Letting him name projects would replace a good optimiser with a worse
## one and make the colony read as incompetent.
##
## `tools/lint.gd` fails if anything outside `sim/` writes a town's objective.
##
## ## Why not `Intent`
##
## `Intent` is taken, and means something else: the sim's unit of work, with a
## target and a progress and a resolution, executed over months. A governor's
## intent is a standing *wish*. The spec uses one word for both; the code cannot.

## Get more out of the land and the trade.
const ECONOMY: StringName = &"increase_economic_output"

## More people, better fed and better housed.
const POPULATION: StringName = &"grow_the_population"

## Walls, forts, powder.
const DEFENCE: StringName = &"strengthen_defences"

## Put a second town in the ground. Founding is M4; gathering for it is not.
const SETTLEMENT: StringName = &"settle_a_new_town"

## **The crisis intent.** Everything else waits.
const SURVIVAL: StringName = &"secure_survival"

const ALL: Array[StringName] = [ECONOMY, POPULATION, DEFENCE, SETTLEMENT, SURVIVAL]

## Sorted for iteration, since the order intents are weighed in must not depend
## on the order they happen to be declared in.
const IN_ORDER: Array[StringName] = [
	ECONOMY, POPULATION, DEFENCE, SETTLEMENT, SURVIVAL,
]


static func is_intent(id: StringName) -> bool:
	return ALL.has(id)


## Whether this intent is an emergency.
##
## **A crisis may override deep sunk progress** and a routine change may not
## (mechanics §7). If natives are burning the outskirts, the town must not spend
## eleven more months on a dock.
static func is_crisis(id: StringName) -> bool:
	return id == SURVIVAL


## What the town is being steered towards, on each axis an objective can serve.
##
## **This table is the whole of "serving an intent".** `ObjectiveSelector` scores
## every available project and posture on these axes and takes the best — so
## adding an intent is adding a row, and adding an axis is teaching the selector
## to measure one more thing. Neither is a branch.
const PROFILES: Dictionary = {
	ECONOMY:    {"food": 0.2, "trade": 1.0, "defence": 0.0, "comfort": 0.2, "capacity": 0.3, "expansion": 0.0},
	POPULATION: {"food": 1.0, "trade": 0.2, "defence": 0.1, "comfort": 0.9, "capacity": 0.5, "expansion": 0.0},
	DEFENCE:    {"food": 0.3, "trade": 0.1, "defence": 1.0, "comfort": 0.1, "capacity": 0.4, "expansion": 0.0},
	SETTLEMENT: {"food": 0.6, "trade": 0.3, "defence": 0.1, "comfort": 0.0, "capacity": 0.3, "expansion": 1.0},
	SURVIVAL:   {"food": 1.0, "trade": 0.0, "defence": 0.4, "comfort": 0.3, "capacity": 0.8, "expansion": -1.0},
}

## The axes, sorted. Iterating the profile dictionary directly would make the
## floating-point sum depend on insertion order.
const AXES: Array[String] = ["capacity", "comfort", "defence", "expansion", "food", "trade"]


## How much an intent values one axis.
static func value_of(intent: StringName, axis: String) -> float:
	var profile: Dictionary = PROFILES.get(intent, {})
	return float(profile.get(axis, 0.0))
