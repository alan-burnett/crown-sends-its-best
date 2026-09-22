class_name Reckoning
extends RefCounted

## What a town must have, what its project requires, and what it would like
## (SPEC §11.3).
##
## ## 🔒 Three tiers, in this order
##
## SPEC §11.3 step 2 names them, and the names are not interchangeable:
##
## | Tier | Field | What it is |
## | :--- | :--- | :--- |
## | 1 | `needs` | Survival: food and clothing. **The citizens meet these with the town's gold whatever the governor wants** |
## | 2 | `objective` | What the town's current project requires. The tier the governor directs |
## | 3 | `wants` | Discretionary comforts, bought with what is left |
##
## **"Wants" means the third tier and only the third.** It was used here for the
## second until SPEC §11.3's three-tier wording was read properly, which made
## "needs before wants" sound like a rule about building projects when it is a
## rule about rum. `docs/mechanics/governor-objectives.md` §3 flagged the clash;
## the spec wins.
##
## Reckon establishes these quantities; **Relief, Exchange, Consume, Build and
## Sell all honour them** rather than each working out its own answer.
##
## That is why it is a record rather than a calculation. Five phases asking the
## same question and getting five answers is how a town ends up selling the grain
## it is about to eat.
##
## **Not a ledger.** SPEC §4 fixes Ledger as the gold screen and nothing else.

var town_id: StringName = &""

## **Tier 1.** What the town will die without: food and clothing, by population.
var needs: Dictionary = {}

## 🔒 **Between the two** (#211, `town-economy.md` §4, `battles.md` §3). What the
## companies this town supports eat this month.
##
## **Its own tier, and deliberately not part of `needs`.** Needs drive
## `shortfall`, which is what the letters call a shortage and what a famine
## counts — and a town whose militia went hungry has not had a famine. Folding
## the two together would have a governor writing home about starving townsfolk
## who were eating perfectly well.
var companies: Dictionary = {}

## **Tier 2.** What the objective requires — the rest of the cost of what the
## town is building, over what has already gone into it.
var objective: Dictionary = {}

## **Tier 3.** What the governor's ambitions want laid in, bought with whatever
## survives the first two tiers. Never anything survival depends on.
var wants: Dictionary = {}

## What the town will lay out on comforts this month, in gold.
##
## **A budget, not a shopping list.** Which comfort it buys is decided at the
## margin by Exchange, given what the cellar already holds and what each one is
## taxed at — a town swimming in tea buys rum instead, and a town that makes its
## own rum buys neither (`town-economy.md` §2). A per-kind appetite could not
## express any of that.
var comfort_budget: float = 0.0

## Held back before anything is sold. Months of need, per the data.
var reserve: Dictionary = {}

## What is left once needs and reserve are covered. What Relief may give away
## and Sell may sell.
var spare: Dictionary = {}

## What the town does not have and cannot cover from its own stores. What
## Exchange goes shopping for (#47), and what the letters call a shortage.
var shortfall: Dictionary = {}


func _init(p_town_id: StringName = &"") -> void:
	town_id = p_town_id


func need_of(resource: StringName) -> float:
	return float(needs.get(String(resource), 0.0))


## What the companies this town victuals want of a resource this month.
func company_of(resource: StringName) -> float:
	return float(companies.get(String(resource), 0.0))


## What the objective still requires of a resource.
func objective_of(resource: StringName) -> float:
	return float(objective.get(String(resource), 0.0))


## What the town would like of a resource, if it can afford it after everything
## else.
func want_of(resource: StringName) -> float:
	return float(wants.get(String(resource), 0.0))


func reserve_of(resource: StringName) -> float:
	return float(reserve.get(String(resource), 0.0))


func spare_of(resource: StringName) -> float:
	return float(spare.get(String(resource), 0.0))


func shortfall_of(resource: StringName) -> float:
	return float(shortfall.get(String(resource), 0.0))


func is_short() -> bool:
	for resource in shortfall:
		if float(shortfall[resource]) > 0.0:
			return true
	return false


## Resources the town is short of, worst first, then by name.
##
## **Need is served worst-first** when towns give to each other (SPEC §11.3), so
## the order is part of the answer rather than a detail of presentation.
func shortages() -> PackedStringArray:
	var entries: Array = []
	for resource in shortfall:
		if float(shortfall[resource]) > 0.0:
			entries.append([float(shortfall[resource]), String(resource)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		return String(a[1]) < String(b[1]))

	var out: PackedStringArray = PackedStringArray()
	for entry in entries:
		out.append(String(entry[1]))
	return out


func to_dict() -> Dictionary:
	return {
		"town": String(town_id),
		"needs": needs.duplicate(),
		"companies": companies.duplicate(),
		"objective": objective.duplicate(),
		"wants": wants.duplicate(),
		"comfort_budget": comfort_budget,
		"reserve": reserve.duplicate(),
		"spare": spare.duplicate(),
		"shortfall": shortfall.duplicate(),
	}
