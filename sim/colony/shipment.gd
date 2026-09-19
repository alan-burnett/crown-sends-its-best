class_name Shipment
extends RefCounted

## Goods a town owes the Crown, and the priority its governor gave them
## (#69, `docs/mechanics/crown-demands.md` §5).
##
## ## 🔒 Compliance is a choice of tier, not a mood
##
## The PC promises things he does not control. Gold is the Crown's to move;
## resources sit in a town's stockpile, and SPEC §11.3 locks that towns run
## themselves. So the governor's answer maps straight onto Reckon's tiers:
##
## | His answer | The shipment enters at | What it costs his town |
## | :--- | :--- | :--- |
## | *"I will treat this as a need"* | **Needs** | It outranks his own project; the town buys to fulfil it and goes without |
## | *"We will ship what we can"* | **Spare**, after objective and reserve | Only genuine surplus leaves |
## | *"I am giving you nothing"* | — | Nothing leaves |
##
## That precision is the point. A governor who refuses is not being disloyal — he
## is weighing his town against a war on the far side of an ocean, and §11.3
## gives him the authority to.
##
## ## The Intent is the record
##
## A shipment is a live Intent and nothing else, so there is no second copy of it
## on the town to fall out of step or to serialise separately. Reckon asks the
## book what this town owes at the needs tier; the executor works the same book.

const KIND: StringName = &"ship_resource"

## He treats it as a need: the town buys to fulfil it and goes without.
const TIER_NEED: StringName = &"need"

## Only genuine surplus leaves, after the objective and the reserve.
const TIER_SPARE: StringName = &"spare"

## How fast a town is expected to move goods, in months.
##
## The monthly quota is the whole shipment divided by this — so **a large demand
## asks for more each month than a small one**, a town that cannot meet the pace
## falls behind, and the Marshal takes a great many horses across a year rather
## than refusing them for being many (§5).
const MONTHS: float = 6.0

## Months of nothing moving before a shipment is given up as stalled.
##
## Not silence: a stalled Intent is a resolution the next month's letters can
## report, which is what turns "the goods never came" into something the Marshal
## can write about.
const PATIENCE: int = 8


## What this town owes the Crown at a given tier, per month.
##
## Returns resource -> quantity. Read by Reckon for the needs tier, and by the
## executor for both.
##
## **Matched through the governor**, because the PC addressed a man and not a
## place: an Intent's target is the contact who agreed to it, and the town is
## whichever one he speaks for. A letter can only ever reach a person
## (SPEC §11.3).
static func owed_by(
	intents: IntentBook,
	colony: Colony,
	town: Town,
	tier: StringName,
) -> Dictionary:
	var owed: Dictionary = {}
	if intents == null or colony == null or town == null:
		return owed
	for intent in intents.live():
		if intent.kind != KIND or town_of(colony, intent) != town:
			continue
		if StringName(intent.data.get("tier", TIER_SPARE)) != tier:
			continue
		var resource := String(intent.data.get("resource", ""))
		if resource.is_empty():
			continue
		owed[resource] = float(owed.get(resource, 0.0)) + monthly_quota(intent)
	return owed


## Which town an Intent's goods come out of.
static func town_of(colony: Colony, intent: Intent) -> Town:
	if colony == null:
		return null
	var named := colony.by_id(intent.target)
	return named if named != null else colony.governed_by(intent.target)


## How much of this shipment the town is asked for in one month.
static func monthly_quota(intent: Intent) -> float:
	var total := float(intent.data.get("amount", 0.0))
	var shipped := float(intent.data.get("shipped", 0.0))
	return maxf(0.0, minf(total / MONTHS, total - shipped))


## Which tier a governor's answer puts the shipment at.
##
## **Full compliance damages his own town**, which is why it costs his loyalty
## unless the payment makes it up to him — the same payment-for-loyalty model
## SPEC §8.5 gives the Marshal's troops. A partial or delayed answer is the
## middle course: the goods go, but only what the town will not miss.
static func tier_for(outcome: StringName) -> StringName:
	return TIER_NEED if outcome == Compliance.COMPLY else TIER_SPARE
