class_name OrderRule
extends RefCounted

## The standing order a company is raised with, its foe, and where each order
## takes it (#434, `docs/mechanics/commanders.md` §3, the Author's ruling on
## #423).
##
## ## 🔒 One fixed rule, the same for a militia and a commander
##
## No personality, no weights and no dice — like choosing an objective
## (`governor-agendas.md` §1). The same town, intent and map give the same
## order. It reads **the intent the company was raised under** and **whether a
## threat is known within 8 tiles of its town**:
##
## | Raised under | Threat within 8 | No threat |
## | :--- | :--- | :--- |
## | **Go wide, go tall** | defend the town | explore |
## | **Military** | march on a foe | guard the border |
## | **Prepare for rebellion** | march on the Crown's troops, once it has declared | the same |
##
## A militia keeps its order until its term ends. A commander starts with it,
## and from the next month deliberates afresh.
##
## ## 🔒 The filters bind first
##
## **Colonists never fight colonists** (`battles.md` §1): a foe is only ever
## somebody `Battle.may_fight` allows. **A rebel company's foe is always the
## Crown's troops**, and so is the foe of a company raised to prepare for
## rebellion — which, until its town declares, may fight nobody at all and so
## holds its town.

## How near the raising town a threat must be to decide the order (§3).
const THREAT_WITHIN: int = 8


## The order the rule gives a company raised from `town` under `intent`.
static func order_for(town: Town, intent: StringName, context: ColonyContext) -> StringName:
	match intent:
		GovernorIntent.GO_WIDE, GovernorIntent.GO_TALL:
			if threat_near(town, context) != null:
				return StandingOrder.DEFEND_THE_TOWN
			return StandingOrder.EXPLORE
		GovernorIntent.MILITARY:
			if threat_near(town, context) != null:
				return StandingOrder.MARCH_ON_A_FOE
			return StandingOrder.GUARD_THE_BORDER
		GovernorIntent.SEDITION:
			return StandingOrder.MARCH_ON_A_FOE
	return StandingOrder.DEFEND_THE_TOWN


## The nearest company within `THREAT_WITHIN` of the town that may fight it, or
## null. Nearest by the town, then first in resolution order.
static func threat_near(town: Town, context: ColonyContext) -> Company:
	if town == null or context == null or context.companies == null:
		return null
	var wall := TownCompany.of(town)
	var nearest: Company = null
	var closest := THREAT_WITHIN + 1
	for entry in context.companies.in_resolution_order():
		var other: Company = entry
		if other.is_empty() or other.at == Company.NOWHERE:
			continue
		if not Battle.may_fight(wall, other):
			continue
		var away := _apart(town.at, other.at)
		if away < closest:
			nearest = other
			closest = away
	return nearest


# --- 🔒 Its foe --------------------------------------------------------------

## What a company marching on its foe marches on: the nearest company of the
## faction that makes its town least safe (§3 *Its foe*), or null.
##
## **The faction** is the one whose companies bring the most force within
## `THREAT_WITHIN` of the town — safety is a question of forces the town cannot
## handle (`quality-of-life.md` §6), so the strongest near it is the one it
## fears most. With none near, the faction of the nearest foe anywhere. **Its
## target** is that faction's nearest company to the town, ties on id.
static func foe_of(company: Company, home: Town, context: ColonyContext) -> Company:
	if company == null or context == null or context.companies == null:
		return null
	var from := home.at if home != null else company.at
	var crown_only := company.allegiance == Company.REBEL \
		or company.raised_under == GovernorIntent.SEDITION

	var strength: Dictionary = {}
	var nearest_of: Dictionary = {}
	var nearest_overall: Company = null
	for entry in context.companies.in_resolution_order():
		var other: Company = entry
		if other.is_empty() or other.at == Company.NOWHERE:
			continue
		if not Battle.may_fight(company, other):
			continue
		if crown_only and other.allegiance != Company.CROWN:
			continue
		var faction := faction_of(other, context)
		var away := _apart(from, other.at)
		if away <= THREAT_WITHIN:
			strength[faction] = float(strength.get(faction, 0.0)) + Force.of(other, context.map, false)
		var held: Company = nearest_of.get(faction, null)
		if held == null or away < _apart(from, held.at):
			nearest_of[faction] = other
		if nearest_overall == null or away < _apart(from, nearest_overall.at):
			nearest_overall = other

	if nearest_overall == null:
		return null
	var chosen := faction_of(nearest_overall, context)
	var most := -1.0
	var factions: Array = strength.keys()
	factions.sort()
	for faction in factions:
		if float(strength[faction]) > most:
			most = float(strength[faction])
			chosen = String(faction)
	return nearest_of.get(chosen, nearest_overall)


## Whose a company is: its allegiance, and for a tribe or a duke, which.
static func faction_of(company: Company, context: ColonyContext) -> String:
	var whose := String(company.raised_by)
	if company.allegiance == Company.NATIVE and context != null and context.natives != null:
		for village in context.natives.villages_in_order():
			if (village as Village).id == company.raised_by:
				whose = String((village as Village).tribe)
				break
	return "%s:%s" % [company.allegiance, whose]


# --- Where each order goes -------------------------------------------------------

## 🔒 **Explore** (§3): the nearest land tile the colony has never seen, measured
## from the company, ties on the tile's coordinates (row, then column). **It has
## no radius.** Nowhere left, and it holds where it stands.
static func nearest_unexplored(from: Vector2i, map: WorldMap, knowledge: MapKnowledge) -> Vector2i:
	if map == null or knowledge == null or from == Company.NOWHERE:
		return Company.NOWHERE
	var best := Company.NOWHERE
	var closest := 0
	for y in map.height:
		for x in map.width:
			if not map.is_land(x, y):
				continue
			var at := Vector2i(x, y)
			if knowledge.is_explored(at):
				continue
			var away := _apart(from, at)
			if best == Company.NOWHERE or away < closest:
				best = at
				closest = away
	return best


## 🔒 **Guard the border** (§3): the tile at the edge of its town's influence
## that faces the nearest threat, or the town itself if none is known. The edge
## is the ring at the town's reach, and of that ring the land tile nearest the
## threat in a straight line, ties north-west first.
static func border_post(home: Town, context: ColonyContext) -> Vector2i:
	if home == null:
		return Company.NOWHERE
	var threat := threat_near(home, context)
	if threat == null or context.map == null:
		return home.at
	var reach := Territory.reach_of(home)
	var best := home.at
	var closest := -1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if maxi(absi(dx), absi(dy)) != reach:
				continue
			var at := home.at + Vector2i(dx, dy)
			if not context.map.in_bounds(at.x, at.y) or not context.map.is_land(at.x, at.y):
				continue
			var away := (at - threat.at).length_squared()
			if closest < 0 or away < closest:
				best = at
				closest = away
	return best


static func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
