class_name ObjectiveSelector
extends RefCounted

## What the town does about its governor's intent
## (`docs/mechanics/governor-objectives.md` §5).
##
## ## 🔒 Deterministic. No personality, no weights, no dice.
##
## The governor has wise and honourable advisors. **He never picks a foolish
## project** — he picks an excellent project in service of a goal the player may
## think is completely wrong, and arguing with the goal is the game.
##
## A personality weight anywhere in this file breaks the design, and a town that
## builds badly reads as a bug rather than as character. The mechanics doc marks
## three rows *no*: choosing an objective, detecting a stall, choosing a tile.
## All three live here.
##
## ## How the scoring works
##
## Every candidate — a building, an improvement on a particular tile, a standing
## posture — is measured on the same six axes, and the intent says what the axes
## are worth (`GovernorIntent.PROFILES`). Adding an intent is adding a row;
## adding a kind of objective is teaching this to measure one more thing. Neither
## is a branch on which intent it is.
##
## ## Ties
##
## Broken by a **hash of the run seed with the town and the candidate**. Fixed by
## the seed, as the doc requires, but not *drawn* — nothing here consumes from an
## RNG stream, so a tie cannot shift every later draw in the colony.

const EVENT_CHOSEN: StringName = &"objective_chosen"

## How much a long or expensive project is marked down. Two identical benefits
## are not equally good if one takes four months (tuning).
const COST_PENALTY: float = 0.35

## Below this an objective is not worth starting at all.
const WORTH_DOING: float = 0.01

## What a share of every future month is worth beside a single month of it.
##
## A sawmill raising timber by three fifths does so **for the rest of the run**.
## Without this a permanent improvement scores like a good week and the town
## never builds anything (tuning).
const LASTING: float = 2.5

## What one unit of extra yield on one tile is worth.
const PER_UNIT_YIELD: float = 0.1

## What a standing posture is worth.
##
## **Deliberately modest.** A posture costs nothing and finishes instantly, so
## anything generous makes it beat every project on the board for ever, and a
## colony that only ever works harder at what it already does is not a colony
## with a governor. It is the answer when there is nothing worth building —
## which is exactly what it should be.
const POSTURE_WORTH: float = 0.08


## What the town should work on, given the intent. Returns `{id, target}`, with
## `target` a tile for an improvement and `Vector2i(-1, -1)` otherwise.
##
## `excluding` drops candidates the town has just given up on, so a stalled
## objective is not immediately chosen again.
static func choose(
	town: Town,
	intent: StringName,
	context: ColonyContext,
	excluding: PackedStringArray = PackedStringArray(),
) -> Dictionary:
	var nothing: Dictionary = {"id": &"", "target": Vector2i(-1, -1), "score": 0.0}
	if not GovernorIntent.is_intent(intent):
		return nothing

	var best: Dictionary = nothing
	var best_key: int = 0
	for candidate in candidates(town, context, intent):
		if excluding.has(String(candidate["id"])):
			continue
		var score := float(candidate["score"])
		if score <= WORTH_DOING:
			continue
		var key := _tiebreak(context.run_seed, town.id, StringName(candidate["id"]))
		if best["id"] == &"" or score > float(best["score"]) + 0.0001:
			best = candidate
			best_key = key
		elif absf(score - float(best["score"])) <= 0.0001 and key < best_key:
			best = candidate
			best_key = key
	return best


## Everything the town could work on, scored. Sorted by id, so the list itself
## carries no ordering information the scoring did not put there.
static func candidates(town: Town, context: ColonyContext, intent: StringName = &"") -> Array:
	var out: Array = []
	# Scored against the intent asked about, never against whatever the town
	# happens to hold — `choose()` is asked "what would serve this?", and a town
	# whose governor changed his mind this month must not be scored against last
	# month's answer.
	if String(intent).is_empty():
		intent = town.intent

	for id in Building.available_to(town):
		if not _can_obtain_all(town, Building.find(StringName(id)).cost, context):
			continue
		out.append({
			"id": StringName(id),
			"target": Vector2i(-1, -1),
			"score": _scored(_building_axes(StringName(id)), intent, Building.find(StringName(id)).months),
		})

	for id in Improvement.ids():
		var improvement := Improvement.find(StringName(id))
		if improvement.natural:
			continue  # Roads come of trade, not of orders (SPEC §11.1).
		if not _can_obtain_all(town, improvement.cost, context):
			continue
		var sited := _best_tile_for(town, improvement, context)
		if sited["at"] == Vector2i(-1, -1):
			continue
		out.append({
			"id": StringName(id),
			"target": sited["at"],
			"score": _scored(sited["axes"], intent, improvement.months),
		})

	for id in Objective.posture_ids():
		out.append({
			"id": StringName(id),
			"target": Vector2i(-1, -1),
			"score": _scored(_posture_axes(StringName(id), town, context), intent, 1),
		})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))
	return out


# --- Scoring ----------------------------------------------------------------

## Axes against the intent's profile, marked down for how long it takes.
static func _scored(axes: Dictionary, intent: StringName, months: int) -> float:
	var total := 0.0
	for axis in GovernorIntent.AXES:
		total += float(axes.get(axis, 0.0)) * GovernorIntent.value_of(intent, axis)
	return total / (1.0 + COST_PENALTY * float(maxi(0, months - 1)))


## What a building is good for, read out of its effects rather than its name.
##
## Nothing here knows what a granary is. Add a building to the data and the
## governor can already want it for the right reasons.
static func _building_axes(id: StringName) -> Dictionary:
	var building := Building.find(id)
	if building == null:
		return {}
	var axes: Dictionary = {}

	var bonuses: Dictionary = building.effect("yield_bonus", {})
	for resource in bonuses:
		var amount := float(bonuses[resource])
		# A yield bonus is a share of everything the town will ever produce of
		# that resource, for the rest of the run. It is worth a great deal more
		# than the number looks.
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + amount * LASTING
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + amount * LASTING * _trade_weight(StringName(resource))

	axes["defence"] = float(building.effect("defence", 0.0)) * 0.5
	axes["comfort"] = float(building.effect("quality_of_life", 0.0)) * 0.5
	axes["capacity"] = (
		float(building.effect("reserve_months", 0.0)) * 0.5
		+ float(building.effect("pasture", 0)) * 0.03
		+ float(building.effect("build_speed", 0.0)) * 0.5
	)
	return axes


## What raising this improvement on this tile would actually change.
##
## Measured as the **difference in what the tile yields**, not as a property of
## the improvement, which is what makes a farm on plains worth more than a farm
## on scrubland without anything in code knowing which is which.
static func _improvement_axes(at: Vector2i, improvement: Improvement, context: ColonyContext) -> Dictionary:
	var terrain := Terrain.find(context.map.terrain_at(at.x, at.y))
	if terrain == null:
		return {}
	var axes: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var before := context.map.yield_at(at.x, at.y, id)
		var after := improvement.yield_of(terrain, id)
		var change := after - before
		if is_zero_approx(change):
			continue
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + change * PER_UNIT_YIELD
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + change * PER_UNIT_YIELD * _trade_weight(id)
	axes["capacity"] = float(improvement.capacity_on(terrain.id)) * 0.05
	axes["expansion"] = 0.0
	return axes


## What a standing posture is good for.
static func _posture_axes(id: StringName, town: Town, context: ColonyContext) -> Dictionary:
	var pretend := Town.new(town.id, town.display_name, town.at)
	pretend.objective = id
	var axes: Dictionary = {}

	for resource in Objective.posture_focus(pretend):
		var source := StringName(resource)
		# What the town can actually get more of by trying. A posture towards a
		# resource the land does not carry is worth nothing.
		var reachable := 0.0
		for at in context.tiles_of(town):
			reachable += context.map.yield_at(at.x, at.y, source)
		if reachable <= 0.0:
			continue
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + POSTURE_WORTH
			axes["capacity"] = float(axes.get("capacity", 0.0)) + POSTURE_WORTH * 0.7
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + POSTURE_WORTH * _trade_weight(source)

	if id == &"amass_expedition":
		axes["expansion"] = 1.0
	return axes


## How much a resource is worth bothering with, relative to grain.
static func _trade_weight(resource: StringName) -> float:
	var food := maxf(0.001, ResourceCatalogue.price_of(&"food"))
	return clampf(ResourceCatalogue.price_of(resource) / food, 0.0, 4.0) * 0.5


# --- 🔒 The governor picks the tile -----------------------------------------

## The best tile in the town's reach for this improvement.
##
## **Deterministic, and the PC never sees this function.** SPEC §11.4 locks tile
## choice to the governor; the player may write that he wants more grain, and
## may not write *where*.
static func _best_tile_for(town: Town, improvement: Improvement, context: ColonyContext) -> Dictionary:
	var none: Dictionary = {"at": Vector2i(-1, -1), "axes": {}}
	if context.map == null:
		return none

	var best := none
	var best_value := 0.0
	for at in context.tiles_of(town):
		if not context.map.can_build(at.x, at.y, improvement.id):
			continue
		if context.map.improvement_at(at.x, at.y) == improvement.id:
			continue  # Already there.
		var axes := _improvement_axes(at, improvement, context)
		var value := float(axes.get("food", 0.0)) + float(axes.get("trade", 0.0)) + float(axes.get("capacity", 0.0))
		# Ties break north-west first, so the choice is the map's rather than the
		# iteration order's.
		if value > best_value + 0.0001 or (
			absf(value - best_value) <= 0.0001
			and best["at"] != Vector2i(-1, -1)
			and (at.y < best["at"].y or (at.y == best["at"].y and at.x < best["at"].x))
		):
			best = {"at": at, "axes": axes}
			best_value = value
	return best


# --- Feasibility ------------------------------------------------------------

## Whether the town could ever get all of this.
##
## **A hard stall before it starts.** The militia needs guns, guns need iron, the
## town produces no ore and has no money — that objective is unreachable and no
## amount of patience fixes it, so it never becomes the objective in the first
## place.
static func _can_obtain_all(town: Town, cost: Dictionary, context: ColonyContext) -> bool:
	var ids: PackedStringArray = PackedStringArray(cost.keys())
	ids.sort()
	for resource in ids:
		if not can_obtain(town, StringName(resource), context):
			return false
	return true


static func can_obtain(town: Town, resource: StringName, context: ColonyContext) -> bool:
	if town.held(resource) > 0.0 or town.invested(resource) > 0.0:
		return true
	for at in context.tiles_of(town):
		if context.map != null and context.map.yield_at(at.x, at.y, resource) > 0.0:
			return true
	# Otherwise it has to be bought, which needs somebody to buy from and the
	# money to do it with.
	return Trade.may_trade_with_crown(town, context) and town.can_afford(ResourceCatalogue.price_of(resource))


## A tie broken by the seed rather than by a die.
##
## Different seeds break the same tie differently, which is what the doc asks
## for; the same seed breaks it the same way every time, and **no stream is
## consumed**, so a tie here cannot shift a draw somewhere else in the colony.
static func _tiebreak(run_seed: int, town_id: StringName, candidate: StringName) -> int:
	return StableHash.of_string("%d:%s:%s" % [run_seed, town_id, candidate])
