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

## **The one intent directed against the PC** (#128, SPEC §8.5, §12.3).
##
## At the bottom of the loyalty scale an order does not merely fail — it can
## become the reason for what happens next. A man insulted past bearing does not
## only decline; the thing he now intends may be to turn his town against the
## Crown.
##
## It does not replace SPEC §12.3's threshold: a town still rebels when its
## sentiment crosses. What this adds is **a resident contact with heavy influence
## deliberately driving that sentiment up**, with his town's objectives serving
## it. The governor accelerates, the sentiment crosses, the town declares — which
## is a far better story than a number quietly passing a line, and gives the
## player something he can see coming.
##
## **Reachable only at very low loyalty**, enforced as a filter rather than a
## weight (`deliberation.md` §5). A weight can lose a close vote; this must not
## be reachable at all by a man who does not loathe the PC.
##
## **And it is not permanent.** Loyalty recovering moves him off it
## (`contacts.md` §8): there is no permanent break, and a governor who has been
## won back stops preparing for a rebellion he no longer wants.
const SEDITION: StringName = &"prepare_for_rebellion"

## **The one intent directed against the people already here** (#204, SPEC
## §11.3, §12.5; `natives.md` §3).
##
## A governor who has decided the tribe beside him is the problem, and means to
## be rid of them. It is the clearest route to the point of no return — not
## because the intent itself is unforgivable, but because a town set on this is a
## town whose next act is the one that is.
##
## 🔒 **The PC can argue against it and cannot forbid it.** §11.3 locks that a
## governor's intent is his to judge, so a determined man drives them off at his
## people's expense while the PC writes letters about it. That is the whole of
## why this is an intent rather than a policy.
##
## 🔒 **Visible to the tribe from the month he adopts it**, before anything is
## built. There is no hiding a purpose from people who live next door.
##
## **Reachable only by a governor who has somebody to drive off**, enforced as a
## filter rather than a weight (`deliberation.md` §5): a man whose town has never
## seen a native cannot want this, however warlike he is, and a weight can lose a
## close vote where a filter cannot.
const DRIVE_OFF: StringName = &"drive_them_off"

const ALL: Array[StringName] = [
	ECONOMY, POPULATION, DEFENCE, SETTLEMENT, SURVIVAL, SEDITION, DRIVE_OFF,
]

## Sorted for iteration, since the order intents are weighed in must not depend
## on the order they happen to be declared in.
const IN_ORDER: Array[StringName] = [
	DRIVE_OFF, ECONOMY, POPULATION, DEFENCE, SETTLEMENT, SEDITION, SURVIVAL,
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


## Whether this intent is aimed at the Crown rather than at the town.
##
## Asked by rebel sentiment, which weighs a governor preparing for rebellion far
## more heavily than a merely disaffected one, and by the letters, which have to
## be able to hint at it before it is too late.
static func is_sedition(id: StringName) -> bool:
	return id == SEDITION


## Whether this is an intent **a governor reaches entirely on his own**.
##
## 🔒 There is no letter in which the PC asks for one of these, and there should
## not be. Both are things the colony arrives at because of how it has been
## treated and how it has behaved, which makes them consequences rather than one
## more thing the PC decides from an armchair — and that is worth more than the
## instrument would be.
##
## He is not powerless about either. He argues by urging something else, and a
## governor who takes the other course has been talked round. What he cannot do
## is **ask** for a rebellion, or for a people to be driven off their land.
##
## `test_colony_letters` reads this: an intent outside it with no letter option
## is a hole, and one inside it with a letter option is a different kind of
## mistake.
static func is_his_alone(id: StringName) -> bool:
	return id == SEDITION or id == DRIVE_OFF


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
	# **A town being made ready to stand alone.** Walls and powder, grain it will
	# not have to buy, and nothing whatever for the Crown's trade — the one
	# profile that wants the colony's commerce to *fall*, because every shilling
	# of it is a thread back to London.
	SEDITION:   {"food": 0.9, "trade": -0.8, "defence": 1.0, "comfort": 0.2, "capacity": 0.6, "expansion": -0.5},
	# **Guns and land.** A governor set on driving them off wants his militia
	# armed and his border pushed, and has no patience for anything that is not
	# one of those two — least of all the trade with them that comfort would
	# otherwise come from.
	DRIVE_OFF:  {"food": 0.5, "trade": -0.2, "defence": 1.0, "comfort": 0.0, "capacity": 0.5, "expansion": 0.8},
}

## The axes, sorted. Iterating the profile dictionary directly would make the
## floating-point sum depend on insertion order.
const AXES: Array[String] = ["capacity", "comfort", "defence", "expansion", "food", "trade"]


## How much an intent values one axis.
## How far apart two intents are, from nought to one (#213).
##
## **Measured off the profile table and nothing else.** The table already *is*
## what an intent means, so "settling a new town and securing survival want
## opposite things" falls out of the numbers rather than being written down
## somewhere a later edit could contradict. Adding an intent adds a row and this
## keeps working.
##
## Normalised by the widest gap the table can produce, so the figure means the
## same thing whatever the axes are worth.
static func distance_between(a: StringName, b: StringName) -> float:
	if String(a).is_empty() or String(b).is_empty() or a == b:
		return 0.0
	var first: Dictionary = PROFILES.get(a, {})
	var second: Dictionary = PROFILES.get(b, {})
	if first.is_empty() or second.is_empty():
		return 0.0

	var axes: Array = first.keys()
	axes.sort()
	var apart := 0.0
	for axis in axes:
		apart += absf(float(first[axis]) - float(second.get(axis, 0.0)))
	return clampf(apart / maxf(0.0001, _widest_gap()), 0.0, 1.0)


## The largest distance any two profiles in the table are apart, unnormalised.
static func _widest_gap() -> float:
	var widest := 0.0
	for a in IN_ORDER:
		for b in IN_ORDER:
			if a == b:
				continue
			var apart := 0.0
			var first: Dictionary = PROFILES.get(a, {})
			# Over `AXES` rather than the dictionary: a floating-point sum taken
			# in insertion order is a sum that can change when a row is edited.
			for axis in AXES:
				apart += absf(float(first.get(axis, 0.0)) - float(PROFILES.get(b, {}).get(axis, 0.0)))
			widest = maxf(widest, apart)
	return widest


static func value_of(intent: StringName, axis: String) -> float:
	var profile: Dictionary = PROFILES.get(intent, {})
	return float(profile.get(axis, 0.0))
