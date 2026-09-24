class_name AgendaMenu
extends RefCounted

## Each intent walks an ordered menu of objectives (#429,
## `docs/mechanics/governor-agendas.md` §3, §4, §7, §12).
##
## 🔒 **The first entry that is wanted, reachable, placeable and not already
## built is taken.** Top to bottom, no scoring, no personality: two governors
## with the same intent in the same town build the same thing, and arguing with
## the intent is the game. When nothing is taken the town holds **no building**,
## the shared fallback, and walks the menu again next Settle.
##
## **Menus and gates are data** (`data/colony/agendas.json`), so the Author can
## reorder a menu or move a threshold without a code change. A condition in data
## is an id into the registry below, with typed params — never logic.

## The shared fallback of every menu (§3). Never completes; while it stands the
## town works every tile a tenth harder.
const NO_BUILDING: StringName = &"no_building"

## What *no building* adds to every tile the town works.
const NO_BUILDING_YIELD: float = 0.1

## 🔒 **Conditions, by id, with the type of every param** (§7). `number` is any
## figure; `resource` names a resource that exists.
const CONDITIONS: Dictionary = {
	"unexplored_within": {"n": "number"},
	"companies_out_below": {"n": "number"},
	"expeditions_launched_below": {"n": "number"},
	"outgrows_the_colony": {"offset": "number", "factor": "number"},
	"population_at_least": {"n": "number"},
	"improvements_per_thousand_below": {"n": "number"},
	"harvested_at_least": {"resource": "resource", "n": "number"},
	"coastal": {},
	"safety_below": {"n": "number"},
	"quality_of_life_below": {"n": "number"},
	"no_trade_protest_on": {"resource": "resource"},
}

## 🔒 **The slots a menu may name besides a building** (§4, §5, §6), each with
## the params it takes and the ticket that makes it placeable. **Until that
## lands the walk skips the slot as not placeable** (#429's ruling), so a menu
## can name it today and start using it the day it is built. `SlotScorers`
## fills the ones that are built (#430).
const SLOTS: Dictionary = {
	"scouting_company": {"params": {}, "built_by": "#432"},
	"big_company": {"params": {}, "built_by": "#432"},
	"lean_expedition": {"params": {}, "built_by": "#431"},
	"thick_expedition": {"params": {}, "built_by": "#431"},
	"improvement": {"params": {"choose": "scorer"}, "built_by": "#430"},
	"improve_yield": {"params": {}, "built_by": "#430"},
	"trade_conversion": {"params": {"choose": "scorer", "input_at_least": "number"}, "built_by": "#430"},
}

## The scorers a slot may `choose` with (§8, §9), and which of them each slot
## takes. Get rich's conversions are chosen by worth and nothing else (§9).
const SCORERS: PackedStringArray = ["military", "tall", "wide", "worth"]
const SLOT_SCORERS: Dictionary = {
	"improvement": ["military", "tall", "wide", "worth"],
	"trade_conversion": ["worth"],
}

## Intent id -> its menu, as loaded.
static var _menus: Dictionary = {}

## Intent id -> how much it minds native land, nought to one (§8, #422).
static var _aversions: Dictionary = {}


static func load_from(record: Dictionary) -> void:
	_menus = {}
	_aversions = {}
	for entry in record.get("intents", []):
		var intent := String(entry.get("id", ""))
		var menu: Variant = entry.get("menu", [])
		if not intent.is_empty() and typeof(menu) == TYPE_ARRAY:
			_menus[intent] = (menu as Array).duplicate(true)
		if not intent.is_empty():
			_aversions[intent] = clampf(float(entry.get("native_aversion", 0.0)), 0.0, 1.0)


static func menu_of(intent: StringName) -> Array:
	return _menus.get(String(intent), [])


static func is_slot(id: StringName) -> bool:
	return SLOTS.has(String(id))


## How much this intent minds building on native land, nought to one (§8
## *Native land*): a tile deep in it is worth `1 − aversion` of the same tile
## outside it.
static func aversion_of(intent: StringName) -> float:
	return float(_aversions.get(String(intent), 0.0))


# --- The walk ------------------------------------------------------------------

## What the town takes, walking its intent's menu: `{id, target}`, with
## `target` a tile for an improvement and `Vector2i(-1, -1)` otherwise. Never
## empty: a menu with nothing taken ends in *no building*.
static func walk(town: Town, intent: StringName, context: ColonyContext) -> Dictionary:
	for entry in menu_of(intent):
		var id := StringName(entry.get("objective", ""))
		if not wanted(entry, town, context):
			continue
		if is_slot(id):
			var placed := _place(town, intent, entry, context)
			if placed.is_empty():
				continue
			return placed
		if not building_is_takeable(id, town, context):
			continue
		return {"id": id, "target": Vector2i(-1, -1)}
	return {"id": NO_BUILDING, "target": Vector2i(-1, -1)}


## Fill a slot. **An expedition is placed or it is not** (#431): a rebel town
## never founds one (SPEC §11.4) and a town with nobody to send cannot. Which
## tile and which one are scored (#430). Companies are not placeable until #432.
static func _place(town: Town, intent: StringName, entry: Dictionary, context: ColonyContext) -> Dictionary:
	var id := StringName(entry.get("objective", ""))
	if Objective.is_expedition(id):
		if not Expedition.may_launch(town, id):
			return {}
		return {"id": id, "target": Vector2i(-1, -1)}
	return SlotScorers.place(town, intent, entry, context)


## Whether every `when` of this entry holds.
static func wanted(entry: Dictionary, town: Town, context: ColonyContext) -> bool:
	for condition in entry.get("when", []):
		if not holds(condition, town, context):
			return false
	return true


## A building is taken when it exists, is not already standing, its
## prerequisites stand, and the town could get everything it costs.
static func building_is_takeable(id: StringName, town: Town, context: ColonyContext) -> bool:
	var building := Building.find(id)
	if building == null or town.has_building(id):
		return false
	if not building.prerequisites_met(town):
		return false
	return ObjectiveSelector.can_obtain_all(town, building.cost, context)


# --- The conditions ------------------------------------------------------------

## Whether one condition holds for this town. **A named switch, not a table of
## callables**: a `Callable` in a static registry segfaults Godot 4.7 on
## shutdown (CLAUDE.md).
static func holds(condition: Dictionary, town: Town, context: ColonyContext) -> bool:
	var n := float(condition.get("n", 0.0))
	match String(condition.get("is", "")):
		"unexplored_within":
			return _unexplored_within(town, int(n), context)
		"companies_out_below":
			return float(_companies_out(town, context)) < n
		"expeditions_launched_below":
			return float(town.expeditions_launched) < n
		"outgrows_the_colony":
			var colony_size := 0 if context.colony == null else context.colony.in_order().size()
			var reach := (Population.thousands(float(town.population()))
				- float(condition.get("offset", 0.0))) * float(condition.get("factor", 1.0))
			return reach > float(colony_size + context.parties.size())
		"population_at_least":
			return float(town.population()) >= n
		"improvements_per_thousand_below":
			return float(_improvements_of(town, context)) \
				/ maxf(Population.thousands(float(town.population())), 0.001) < n
		"harvested_at_least":
			return float(town.harvested.get(String(condition.get("resource", "")), 0.0)) >= n
		"coastal":
			return _is_coastal(town, context)
		"safety_below":
			return town.safety < n
		"quality_of_life_below":
			return town.quality_of_life < n
		"no_trade_protest_on":
			return not TradeProtest.is_protesting(town, StringName(condition.get("resource", "")))
	return false


## Unexplored territory lies within `n` tiles (Chebyshev, the influence ring) of
## the town: a land tile the colony has never seen.
static func _unexplored_within(town: Town, n: int, context: ColonyContext) -> bool:
	if context.map == null or context.territory == null:
		return false
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var at := town.at + Vector2i(dx, dy)
			if not context.map.in_bounds(at.x, at.y):
				continue
			if not context.territory.visible.has(at):
				return true
	return false


static func _companies_out(town: Town, context: ColonyContext) -> int:
	if context.companies == null:
		return 0
	return context.companies.supported_by(town.id).size()


## The improvements standing on this town's own ground. Roads come of trade and
## are not counted.
static func _improvements_of(town: Town, context: ColonyContext) -> int:
	if context.map == null:
		return 0
	var count := 0
	for at in context.tiles_of(town):
		var improvement := Improvement.find(context.map.improvement_at(at.x, at.y))
		if improvement != null and not improvement.natural:
			count += 1
	return count


## Sea within the town's reach.
static func _is_coastal(town: Town, context: ColonyContext) -> bool:
	if context.map == null or context.territory == null:
		return false
	for at in context.territory.influence:
		if StringName(context.territory.influence[at]) != town.id:
			continue
		if not context.map.is_land(at.x, at.y):
			return true
	return false


# --- What an intent values, read off its menu ----------------------------------

## Where on this intent's menu a thing sits: nought for the first entry, and the
## menu's length for anything it does not name. **The governor's own ranking**
## of what the town has: read by upkeep, which pays for what his intent values
## first (#429).
static func rank_of(intent: StringName, objective: StringName) -> int:
	var menu := menu_of(intent)
	for index in menu.size():
		if StringName(menu[index].get("objective", "")) == objective:
			return index
	return menu.size()
