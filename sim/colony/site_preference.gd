class_name SitePreference
extends RefCounted

## What the PC may say about where a town goes (#177,
## `docs/mechanics/founding-towns.md` §5, SPEC §11.4).
##
## ## 🔒 The PC never chooses a tile
##
## He approves, refuses, or states a **preference** — toward the coast, near the
## ore, away from the tribes. SPEC §11.4 locks it, and the shape of this file is
## how it is kept true: **there is no function here that takes a coordinate.** A
## preference is a name; the governor turns it into ground.
##
## ## 🔒 The site cannot be fixed at launch
##
## The PC's preferences arrive in his reply to the governor's first letter, so a
## site chosen the month the party left would make them **a month too late and
## worth nothing**.
##
## So the governor sets out toward a **region**, and a letter can shift him while
## he travels. That is `world-month.md` §3's interruptible multi-month action in
## its clearest form, and it is the moment in the game where a letter most
## obviously arrives in time to matter.
##
## ## It gives "away from the tribes" a price
##
## SPEC §11.4: founding near or beyond native land offends the nearby tribes in
## proportion to the intrusion — and **the best ground is usually ground somebody
## already lives on.** A PC steering his people to safety is steering them to
## worse land, knowingly, and the preference is what makes that a decision rather
## than an accident.

## What the governor does when nobody has told him anything: the best ground he
## can find, which is what he would have done anyway.
const GOOD_GROUND: StringName = &"good_ground"

## Toward the coast — poorer ground, better trade, and a ship can reach it.
const THE_COAST: StringName = &"the_coast"

## Near the ore, and whatever else is in the rock.
const THE_ORE: StringName = &"the_ore"

## Away from the tribes. **The expensive one**, and the point of the mechanic.
const AWAY_FROM_TRIBES: StringName = &"away_from_tribes"

const ALL: Array[StringName] = [GOOD_GROUND, THE_COAST, THE_ORE, AWAY_FROM_TRIBES]

## How far from the region's centre the governor will look. Tuning.
const REGION_RADIUS: int = 3

## What a preference is worth against the **spread** of ground merit inside the
## region, which runs nought to one.
##
## Below one on purpose: a preference can carry a field that is merely good over
## one that is slightly better, and cannot carry a field the town would starve
## on. Tuning.
const PREFERENCE_WEIGHT: float = 0.8


static func is_preference(id: StringName) -> bool:
	return ALL.has(id)


## The tile the governor would settle on, given a region and a preference.
##
## 🔒 **Deterministic, and his choice rather than the PC's.** No seed and no
## roll: the same region, the same preference and the same map give the same
## answer, so a save reloaded mid-crossing founds the same town.
##
## Ties break on the coordinates, so which tile wins is the map's business and
## not the iteration order's.
static func site_in(
	region: Vector2i,
	preference: StringName,
	map: WorldMap,
	colony: Colony = null,
) -> Vector2i:
	if map == null or region == Vector2i(-1, -1):
		return Vector2i(-1, -1)

	# **Two passes, because a preference has to mean something.** The merit of
	# ground is an absolute figure running into double digits, and a preference
	# added to it raw would never once change the answer — decoration rather than
	# an instrument. So merit is normalised **within the region**, since the
	# governor is choosing between these fields and no others, and the preference
	# is weighed against that spread.
	var candidates: Array = []
	var best_merit := -1.0e30
	var worst_merit := 1.0e30
	for dy in range(-REGION_RADIUS, REGION_RADIUS + 1):
		for dx in range(-REGION_RADIUS, REGION_RADIUS + 1):
			var at := region + Vector2i(dx, dy)
			if not map.in_bounds(at.x, at.y) or not map.is_land(at.x, at.y):
				continue
			if _too_near_a_town(at, colony):
				continue
			var merit := _ground_merit(at, map)
			candidates.append({"at": at, "merit": merit, "want": _wanted(at, preference, map)})
			best_merit = maxf(best_merit, merit)
			worst_merit = minf(worst_merit, merit)
	if candidates.is_empty():
		return Vector2i(-1, -1)

	var spread := maxf(0.0001, best_merit - worst_merit)
	var best := Vector2i(-1, -1)
	var most := -1.0e30
	for entry in candidates:
		var at: Vector2i = entry["at"]
		var worth := (float(entry["merit"]) - worst_merit) / spread \
			+ PREFERENCE_WEIGHT * float(entry["want"])
		if worth > most + 0.0001 \
				or (absf(worth - most) <= 0.0001 and _before(at, best)):
			best = at
			most = worth
	return best


## How well this ground answers what he was asked for, from nought to one.
##
## 🔒 **A preference shades the answer; it does not replace it.** A PC who asks
## for the coast gets the best coastal ground rather than the first wet tile in
## the list, because the merit of the ground is still in the sum.
static func _wanted(at: Vector2i, preference: StringName, map: WorldMap) -> float:
	match preference:
		THE_COAST:
			return _coastal(at, map)
		THE_ORE:
			return clampf(map.yield_around(at.x, at.y, &"ore") / 4.0, 0.0, 1.0)
		AWAY_FROM_TRIBES:
			# 🔒 **The expensive preference.** It pays nothing for good ground and
			# buys distance instead, which is the whole design: safety is bought
			# with harvests.
			return 1.0 - intrusion_at(at, map)
		_:
			return 0.0


## How good the ground is, on its own terms: food first, then everything else.
static func _ground_merit(at: Vector2i, map: WorldMap) -> float:
	var merit := map.yield_around(at.x, at.y, &"food") * 1.5
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		if id == &"food" or ResourceCatalogue.is_livestock(id):
			continue
		merit += map.yield_around(at.x, at.y, id) * 0.25
	return merit


## How much settling here would intrude on somebody, from nought to one.
##
## 🔒 **The seam SPEC §11.4 needs, and nothing fills it yet.** Tribes are M5, so
## this answers zero everywhere — deliberately, and said out loud, because the
## alternative is a preference that costs nothing and reads as free.
##
## When natives arrive, this is the one function that has to learn about them,
## and both the preference and the founding offence read it.
static func intrusion_at(_at: Vector2i, _map: WorldMap) -> float:
	return 0.0


## Whether a site sits on somebody else's doorstep.
static func _too_near_a_town(at: Vector2i, colony: Colony) -> bool:
	if colony == null:
		return false
	for town in colony.in_order():
		if town.at.distance_squared_to(at) <= 4:
			return true
	return false


## How much water is in reach, from nought to one.
static func _coastal(at: Vector2i, map: WorldMap) -> float:
	var water := 0
	var looked := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := at + Vector2i(dx, dy)
			if not map.in_bounds(near.x, near.y):
				continue
			looked += 1
			if not map.is_land(near.x, near.y):
				water += 1
	return 0.0 if looked == 0 else float(water) / float(looked)


## A fixed order for ties, so the map decides and not the loop.
static func _before(a: Vector2i, b: Vector2i) -> bool:
	if b == Vector2i(-1, -1):
		return true
	return a.y < b.y or (a.y == b.y and a.x < b.x)
