class_name SlotScorers
extends RefCounted

## Where and which, for the menu slots that need a choice (#430,
## `docs/mechanics/governor-agendas.md` §5, §8, §9).
##
## 🔒 **The order is fixed; where and which are scored, deterministically.** The
## walk decides *that* a town improves its ground or builds a conversion; this
## decides which tile and which one. No personality and no dice, like the walk:
## two governors of one intent in one town choose the same tile.
##
## ## Measured against this month's harvest
##
## Everything here asks what a thing **would have added to this month's
## harvest** (§5), from what each tile actually gave (`Town.harvested_at`). So a
## tile nobody worked adds nothing whatever is built on it, a farm goes only where
## food came off the ground, and a mine only where ore did.
##
## ## Native land
##
## 🔒 **Every scorer discounts a tile by how deep it lies in native land, times
## its intent's aversion** (§8, Author's ruling #422):
##
##     worth on the tile × (1 − intrusion depth × aversion)
##
## The aversions are data (`AgendaMenu.aversion_of`).

## Improve yield's buildings (§5).
const IMPROVE_YIELD_BUILDINGS: Array[StringName] = [
	&"irrigation_station", &"windmill", &"river_mill", &"mineworks", &"sawmill", &"stonecutters",
]

## And its improvements. 🔒 **Never a plantation**, which is get rich's own slot.
const IMPROVE_YIELD_IMPROVEMENTS: Array[StringName] = [&"farm", &"mine", &"pasture"]

## An improvement is a candidate for improve yield only while the town holds
## fewer than this many per thousand people (§5), or the slot would cover every
## tile it holds in farms.
const IMPROVE_YIELD_IMPROVEMENTS_BELOW: float = 1.0

## Get rich's conversions (§9). No other intent builds them.
const TRADE_CONVERSIONS: Array[StringName] = [
	&"furriers", &"weaving_shed", &"rolling_house", &"distillery", &"brewhouse",
]

## What each tile scorer considers (§8, the PO's draft).
const CONSIDERS: Dictionary = {
	"wide": [&"farm", &"pasture"],
	"tall": [&"farm", &"pasture", &"mine"],
	"worth": [&"plantation_sugar", &"plantation_cotton", &"plantation_tobacco", &"mine", &"farm"],
	"military": [&"fort"],
}

## 🔒 **A farm goes only on a tile that harvested food, a mine only on one that
## harvested ore** (§5), because what it would add is measured from what the
## tile gave.
const ONLY_WHERE_HARVESTED: Dictionary = {"farm": "food", "mine": "ore"}

## Below this, two scores are one score and the earlier candidate keeps it.
const EPSILON: float = 0.000001


## Fill a slot: `{id, target}`, or empty when nothing qualifies and the slot
## fails *placeable* (§3).
static func place(town: Town, intent: StringName, entry: Dictionary, context: ColonyContext) -> Dictionary:
	match String(entry.get("objective", "")):
		"improvement":
			return _improvement(town, intent, String(entry.get("choose", "")), context)
		"improve_yield":
			return _improve_yield(town, intent, context)
		"trade_conversion":
			return _trade_conversion(town, float(entry.get("input_at_least", 0.0)), context)
	return {}


# --- 🔒 Which tile (§8) ----------------------------------------------------------

static func _improvement(town: Town, intent: StringName, scorer: String, context: ColonyContext) -> Dictionary:
	if context.map == null or not CONSIDERS.has(scorer):
		return {}
	match scorer:
		"tall":
			# *The largest gain in food, then ore*: ore only where no tile gains food.
			var fed := _best_tile(town, intent, CONSIDERS[scorer], "food", context)
			return fed if not fed.is_empty() else _best_tile(town, intent, CONSIDERS[scorer], "ore", context)
		"wide":
			return _best_tile(town, intent, CONSIDERS[scorer], "food", context)
		"worth":
			return _best_tile(town, intent, CONSIDERS[scorer], "worth", context)
		"military":
			return _best_tile(town, intent, CONSIDERS[scorer], "threat", context)
	return {}


## The best tile for any of `ids`, by `measure`, discounted for native land.
## Candidates in list order and tiles north-west first, so a tie goes to the
## earlier one and never to the iteration order of anything.
static func _best_tile(
	town: Town, intent: StringName, ids: Array, measure: String, context: ColonyContext
) -> Dictionary:
	var town_prices := _town_prices(town)
	var prices := _after_tax(context) if measure == "worth" else town_prices
	var threat := _nearest_threat(town, context) if measure == "threat" else Vector2i(-1, -1)
	if measure == "threat" and threat == Vector2i(-1, -1):
		return {}  # Nothing to face, so nowhere to face it from.

	var best: Dictionary = {}
	var best_score := 0.0
	for id in ids:
		var improvement := Improvement.find(StringName(id))
		if improvement == null or improvement.natural:
			continue
		if not ObjectiveSelector.can_obtain_all(town, improvement.cost, context):
			continue
		var cost := _cost_of(improvement.cost, town_prices) if measure == "worth" else 1.0
		for at in _tiles_in_order(town, context):
			if not _may_improve(town, improvement, at, context):
				continue
			var score := 0.0
			match measure:
				"food", "ore":
					score = _gain(town, improvement, at, context, measure, prices)
				"worth":
					score = _worth_on(town, improvement, at, context, prices) / cost
				"threat":
					# Straight-line, so of three tiles on the border the one in
					# line with the threat faces it.
					score = 1.0 / (1.0 + float((at - threat).length_squared()))
			score *= _native_discount(at, intent, context)
			if score > best_score + EPSILON:
				best = {"id": StringName(id), "target": at}
				best_score = score
	return best


## How much more of one resource the tile would have given, for *wide* and *tall*.
## A pasture's food is the feed it saves less the grain the tile stops growing.
static func _gain(
	town: Town, improvement: Improvement, at: Vector2i, context: ColonyContext,
	resource: String, prices: Dictionary,
) -> float:
	if improvement.livestock_capacity > 0:
		return float(_pasture_on(town, improvement, at, context, prices)["food"]) if resource == "food" else 0.0
	return float(added_by(town, improvement, at, context).get(resource, 0.0))


## Everything the tile would have added, valued at `prices`, for *worth* and
## improve yield.
static func _worth_on(
	town: Town, improvement: Improvement, at: Vector2i, context: ColonyContext, prices: Dictionary
) -> float:
	if improvement.livestock_capacity > 0:
		return float(_pasture_on(town, improvement, at, context, prices)["value"])
	var added := added_by(town, improvement, at, context)
	var total := 0.0
	for resource in _sorted_keys(added):
		total += float(added[resource]) * float(prices.get(resource, 0.0))
	return total


## 🔒 **A tile qualifies only if the improvement could go there at all**, is not
## already there, and — for a farm or a mine — the tile gave what it improves.
static func _may_improve(town: Town, improvement: Improvement, at: Vector2i, context: ColonyContext) -> bool:
	if not context.map.can_build(at.x, at.y, improvement.id):
		return false
	if context.map.improvement_at(at.x, at.y) == improvement.id:
		return false
	var needs := String(ONLY_WHERE_HARVESTED.get(String(improvement.id), ""))
	if not needs.is_empty():
		var gave: Dictionary = town.harvested_at.get(_key(at), {})
		return float(gave.get(needs, 0.0)) > 0.0
	return true


## What building `improvement` on `at` would have added to this month's
## harvest, by resource. **Nothing, for a tile nobody worked.**
##
## The change in what the ground yields, through the town's own experts and
## buildings — the same factors Work applies. Not the fallback's tenth: the town
## gives that up the month it takes a project.
static func added_by(town: Town, improvement: Improvement, at: Vector2i, context: ColonyContext) -> Dictionary:
	var out: Dictionary = {}
	if context.map == null or not town.harvested_at.has(_key(at)):
		return out
	var terrain := Terrain.find(context.map.terrain_at(at.x, at.y))
	if terrain == null:
		return out
	# **What the ground's buildings add counts on both sides** (#409): a farm
	# under an irrigation station yields more than the same farm without one.
	var rules := Building.tile_yield_rules(town)
	var now := &"" if context.map.is_idle(at.x, at.y) else context.map.improvement_at(at.x, at.y)
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var after := improvement.yield_of(terrain, id) * _multiplier(town, id, rules, terrain.id, improvement.id)
		var before := context.map.yield_at(at.x, at.y, id) * _multiplier(town, id, rules, terrain.id, now)
		if absf(after - before) > EPSILON:
			out[resource] = after - before
	return out


## §5 *A pasture*, Author's ruling #421: **the food it saves and the head it
## breeds, less what the tile stops yielding.** `food` in units, for the scorers
## that count food; `value` at `prices`, for those that count worth.
##
## - **Feed saved**: the head that go unsupported, up to the pasture's capacity,
##   times what they eat. Kind by kind in id order (§5, ⚠ assumed).
## - **Breeding gained**: what those same head would bear in a month on pasture.
##   Off it they bear nothing (`SettlePhase._breed`).
## - **Yield lost**: what the tile gave last month, less what it would under a
##   pasture. A tile nobody worked loses nothing.
static func _pasture_on(
	town: Town, pasture: Improvement, at: Vector2i, context: ColonyContext, prices: Dictionary
) -> Dictionary:
	var terrain := Terrain.find(context.map.terrain_at(at.x, at.y))
	if terrain == null:
		return {"food": 0.0, "value": 0.0}
	var room := float(pasture.capacity_on(terrain.id) - context.map.livestock_capacity_at(at.x, at.y))
	var rate := SettlePhase.LIVESTOCK_RATE * (1.0 + Building.growth_bonus_for(town))
	var unsupported := ConsumePhase.unsupported_head(town, context)

	var fed := 0.0
	var bred := 0.0
	for kind in _sorted_keys(unsupported):
		if room <= 0.0:
			break
		var head := minf(float(unsupported[kind]), room)
		room -= head
		fed += head * ResourceCatalogue.feed_of(StringName(kind))
		bred += head * rate * float(prices.get(kind, 0.0))

	var lost_food := 0.0
	var lost_value := 0.0
	var gave: Dictionary = town.harvested_at.get(_key(at), {})
	for resource in _sorted_keys(gave):
		var under := pasture.yield_of(terrain, StringName(resource)) \
			* _multiplier(town, StringName(resource), Building.tile_yield_rules(town), terrain.id, pasture.id)
		var lost := maxf(0.0, float(gave[resource]) - under)
		lost_value += lost * float(prices.get(resource, 0.0))
		if resource == "food":
			lost_food += lost
	return {
		"food": fed - lost_food,
		"value": fed * float(prices.get("food", 0.0)) + bred - lost_value,
	}


## The tile nearest the nearest force that may fight this town (§8 *military*).
## Nearest by the town, then the first in resolution order.
static func _nearest_threat(town: Town, context: ColonyContext) -> Vector2i:
	if context.companies == null:
		return Vector2i(-1, -1)
	var wall := TownCompany.of(town)
	var nearest := Vector2i(-1, -1)
	var closest := 0
	for entry in context.companies.in_resolution_order():
		var company: Company = entry
		if not Battle.may_fight(wall, company):
			continue
		var away := _apart(town.at, company.at)
		if nearest == Vector2i(-1, -1) or away < closest:
			nearest = company.at
			closest = away
	return nearest


# --- 🔒 Improve yield (§5) ---------------------------------------------------------

## **One slot that weighs every way of getting more out of the ground**, each by
## what it would have added to this month's harvest over its cost, both at town
## prices. The highest worth is built.
static func _improve_yield(town: Town, intent: StringName, context: ColonyContext) -> Dictionary:
	var prices := _town_prices(town)
	var best: Dictionary = {}
	var best_worth := 0.0

	for id in IMPROVE_YIELD_BUILDINGS:
		if not AgendaMenu.building_is_takeable(id, town, context):
			continue
		var building := Building.find(id)
		var bonuses: Dictionary = building.effect("yield_bonus", {})
		var added := 0.0
		for resource in _sorted_keys(bonuses):
			# Over what the town's buildings already add, which the harvest includes.
			var already := 1.0 + Building.yield_bonus_for(town, StringName(resource))
			added += float(town.harvested.get(resource, 0.0)) * float(bonuses[resource]) / already \
				* float(prices.get(resource, 0.0))
		added += _ground_added(town, building, context, prices)
		var worth := added / _cost_of(building.cost, prices)
		if worth > best_worth + EPSILON:
			best = {"id": id, "target": Vector2i(-1, -1)}
			best_worth = worth

	if context.map == null or not AgendaMenu.holds(
			{"is": "improvements_per_thousand_below", "n": IMPROVE_YIELD_IMPROVEMENTS_BELOW}, town, context):
		return best
	for id in IMPROVE_YIELD_IMPROVEMENTS:
		var improvement := Improvement.find(id)
		if improvement == null or not ObjectiveSelector.can_obtain_all(town, improvement.cost, context):
			continue
		var cost := _cost_of(improvement.cost, prices)
		for at in _tiles_in_order(town, context):
			if not _may_improve(town, improvement, at, context):
				continue
			var worth := _worth_on(town, improvement, at, context, prices) / cost \
				* _native_discount(at, intent, context)
			if worth > best_worth + EPSILON:
				best = {"id": id, "target": at}
				best_worth = worth
	return best


# --- 🔒 Get rich's conversions (§9) --------------------------------------------------

## **Which conversion building**, by what it would earn from last month's harvest
## over its cost, ranked by what the town receives **after the PC's tax**.
##
## 🔒 **Never a conversion whose input the town did not harvest**, and never one
## whose input fell short of `input_at_least` — a distillery is not considered by
## a town that harvested no sugar.
##
## What it earns is **what it adds** (§5, *extra per month*): last month's
## harvest of the input converted on the building's terms, over what the terms
## the town already has would make of it, at what the output fetches after tax
## (⚠ assumed, #430). **Not net of selling the input raw**: the governor weighs
## what the building adds, and whether the town then converts or sells is Work's
## question, answered by its own valuations.
static func _trade_conversion(town: Town, input_at_least: float, context: ColonyContext) -> Dictionary:
	var net := _after_tax(context)
	var prices := _town_prices(town)
	var best: Dictionary = {}
	var best_worth := 0.0
	for id in TRADE_CONVERSIONS:
		if not AgendaMenu.building_is_takeable(id, town, context):
			continue
		var building := Building.find(id)
		var conversions: Dictionary = building.effect("conversions", {})
		var earns := 0.0
		for recipe in _sorted_keys(conversions):
			var parts := String(recipe).split("<-")
			if parts.size() != 2:
				continue
			var output := parts[0]
			var input := parts[1]
			var harvested := float(town.harvested.get(input, 0.0))
			if harvested <= 0.0 or harvested < input_at_least:
				continue
			var per_input := 1.0 / maxf(0.0001, float(conversions[recipe].get("ratio", 1.0)))
			var now_terms := Building.terms_for(town, StringName(recipe))
			if not now_terms.is_empty():
				per_input -= 1.0 / float(now_terms["ratio"])
			earns += harvested * maxf(0.0, per_input) * float(net.get(output, 0.0))
		var worth := earns / _cost_of(building.cost, prices)
		if worth > best_worth + EPSILON:
			best = {"id": id, "target": Vector2i(-1, -1)}
			best_worth = worth
	return best


# --- Prices ---------------------------------------------------------------------------

## What a unit of everything is worth to this town now (`town-economy.md` §3).
## **Cost is valued at town prices**, so a town that can cut its own timber
## reads timber as cheap (§5).
static func _town_prices(town: Town) -> Dictionary:
	var alone := Colony.new()
	alone.add(town)
	var desired := DesiredStock.for_town(town, ColonySnapshot.of(alone))
	var out: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		out[resource] = Valuation.town(id, desired, town.held(id))
	return out


## What the town receives for a unit, after the PC's tax (§9).
static func _after_tax(context: ColonyContext) -> Dictionary:
	var out: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		out[resource] = Valuation.crown(id, context.state) * (1.0 - context.tax_rate(id))
	return out


static func _cost_of(cost: Dictionary, prices: Dictionary) -> float:
	var total := 0.0
	for resource in _sorted_keys(cost):
		total += float(cost[resource]) * float(prices.get(resource, 0.0))
	return maxf(total, EPSILON)


# --- Helpers ----------------------------------------------------------------------------

static func _native_discount(at: Vector2i, intent: StringName, context: ColonyContext) -> float:
	var depth := Intrusion.depth_at(at, context.natives)
	return clampf(1.0 - depth * AgendaMenu.aversion_of(intent), 0.0, 1.0)


## The same factors Work puts on a tile's yield, less the fallback's: the
## town's experts, its buildings, and what they add on this ground (#409).
static func _multiplier(
	town: Town, resource: StringName, rules: Array = [], terrain: StringName = &"", improvement: StringName = &""
) -> float:
	return WorkPhase.expert_multiplier(town, resource) * (1.0 + Building.yield_bonus_for(town, resource)
		+ Building.tile_yield_bonus(rules, resource, terrain, improvement))


## What a building's ground-scoped bonuses (#409) would have added to this
## month's harvest, tile by tile, valued at `prices`: each worked tile's yield
## of a resource times the building's own bonus there, over what the tile's
## multiplier already was.
static func _ground_added(town: Town, building: Building, context: ColonyContext, prices: Dictionary) -> float:
	var own: Array = building.effect("tile_yield_bonus", [])
	if own.is_empty() or context.map == null:
		return 0.0
	var rules := Building.tile_yield_rules(town)
	var added := 0.0
	for key in _sorted_keys(town.harvested_at):
		var parts := String(key).split(",")
		var at := Vector2i(int(parts[0]), int(parts[1]))
		if not context.map.in_bounds(at.x, at.y):
			continue
		var terrain := context.map.terrain_at(at.x, at.y)
		var improvement := &"" if context.map.is_idle(at.x, at.y) else context.map.improvement_at(at.x, at.y)
		var gave: Dictionary = town.harvested_at[key]
		for resource in _sorted_keys(gave):
			var id := StringName(resource)
			var extra := Building.tile_yield_bonus(own, id, terrain, improvement)
			if extra <= 0.0:
				continue
			var already := 1.0 + Building.yield_bonus_for(town, id) + Building.tile_yield_bonus(rules, id, terrain, improvement)
			added += float(gave[resource]) * extra / already * float(prices.get(resource, 0.0))
	return added


static func _tiles_in_order(town: Town, context: ColonyContext) -> Array[Vector2i]:
	var tiles := context.tiles_of(town)
	tiles.sort_custom(SlotScorers._north_west_first)
	return tiles


static func _north_west_first(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _key(at: Vector2i) -> String:
	return "%d,%d" % [at.x, at.y]


static func _sorted_keys(record: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray()
	for key in record:
		keys.append(String(key))
	keys.sort()
	return keys
