class_name SiteRequest
extends RefCounted

## What the colony is for, and the ground that answers it (#273, SPEC §11.4;
## `docs/mechanics/map.md` §4, §6).
##
## ## 🔒 He states what he wants. He does not choose a tile
##
## §11.4 locks that the PC never chooses a tile when founding a town — he states
## preferences and a competent man finds the ground. **Run start is the same act
## by the same sort of person**, and it would be strange for the one decision he
## makes before anything exists to be the one where he reads a map better than
## his own governors.
##
## It is also the only version that is honestly playable. **A coordinate means
## nothing to a player who has never played**, and three of them mean nothing
## three times. This replaces the three-site list.
##
## ## 🔒 A request tilts a good site. It does not pick a strange one
##
## There is a base score for a site — what the ground around it is worth — and a
## request adds weight **on top of it**, never in place of it.
##
## So *quick growth* does not find the most maritime tile on the map regardless
## of what surrounds it. It finds **a good site that happens to lean seaward**,
## and a player who asks for one thing is never handed somewhere bad at
## everything else.
##
## Each tilt is a weight vector over terrain, scored across the tiles a town
## would work. **Adding a request is adding a row, not a branch** — the same
## shape as a governor's intent profiles.
##
## ## 🔒 Sea within reach, whatever was asked
##
## The Crown reaches the colony by ship. A landlocked first town cannot run
## Exchange, cannot be supplied, and cannot receive a single immigrant or
## soldier. Later towns may be landlocked and that is fine — by then there are
## roads and carts and neighbours. It is only the first, alone on a shore with an
## ocean between it and everything it needs, that has no alternative.
##
## So the four requests operate **above a floor**, and *how coastal* is a
## consequence of which one was asked for rather than a dial of its own.

const QUICK_GROWTH: StringName = &"quick_growth"
const ECONOMIC_OPPORTUNITY: StringName = &"economic_opportunity"
const LONG_TERM_CULTIVATION: StringName = &"long_term_cultivation"
const DEFENSIVE_POSITION: StringName = &"defensive_position"

## Sorted, so anything iterating them does so in a fixed order.
const ALL: Array[StringName] = [
	DEFENSIVE_POSITION, ECONOMIC_OPPORTUNITY, LONG_TERM_CULTIVATION, QUICK_GROWTH,
]

## What each request leans toward, per tile a town would work.
##
## 🔒 **A row, not a branch.** A fifth request is a line in this table and
## nothing else — and `defensive_position` is empty here on purpose, because §4
## answers it by fiat below rather than by hunting for rare ground.
const TILTS: Dictionary = {
	String(QUICK_GROWTH): {"sea": 1.0},
	String(ECONOMIC_OPPORTUNITY): {"forest": 1.0, "mountains": 0.8},
	String(LONG_TERM_CULTIVATION): {"grassland": 1.0, "plains": 0.8, "mountains": 0.4},
	String(DEFENSIVE_POSITION): {},
}

## What a tilted terrain is worth against the base score.
##
## **Enough to move the answer, not enough to replace it.** The base runs to
## twenty-odd on good ground; a request adds a few points per matching tile in
## reach, so it reorders the good sites among themselves and never lifts a bad
## one above them. Tuning.
const TILT_WEIGHT: float = 1.6

## How far a town's first influence reaches, for scoring the ground around it.
const REACH: int = 2

## How near the sea must be for a ship to reach the colony at all.
const SEA_WITHIN: int = 2


static func is_request(id: StringName) -> bool:
	return ALL.has(id)


## The site this request answers with.
##
## 🔒 **Deterministic, and the same act as any other founding.** No seed and no
## roll: the same map and the same request give the same ground, so a save
## reloaded at month one lands in the same place.
##
## Ties break on the coordinates, so which tile wins is the map's business and
## not the iteration order's.
static func choose(map: WorldMap, request: StringName) -> Vector2i:
	if map == null:
		return Vector2i(-1, -1)

	# 🔒 **The defensive request takes the best untilted site** (§4) and the
	# mountain is put under it afterwards. No search and no rare-terrain hunt:
	# it asked for a position rather than a country.
	var tilt: Dictionary = TILTS.get(String(request), {})

	var best := Vector2i(-1, -1)
	var most := -1.0e30
	for y in map.height:
		for x in map.width:
			if not map.is_land(x, y):
				continue
			# 🔒 The floor, applied before anything is weighed. A site the Crown
			# cannot reach is not a worse site, it is not a site.
			if not sea_within_reach(map, x, y):
				continue
			var worth := score(map, x, y, tilt)
			if worth > most + 0.0001 \
					or (absf(worth - most) <= 0.0001 and _before(Vector2i(x, y), best)):
				best = Vector2i(x, y)
				most = worth
	return best


## What this ground is worth, to a colony that asked for this.
##
## The base score and the tilt, added. **Never a replacement**: strip the tilt
## and the answer is still a good site.
static func score(map: WorldMap, x: int, y: int, tilt: Dictionary) -> float:
	# 🔒 **Desert is already the lowest-valued terrain there is** (§4), and it is
	# the base that makes it so: `site_score` weighs food, wood and stone, and
	# desert yields effectively none of the three.
	#
	# I added an explicit penalty on top and mutation testing showed removing it
	# changed nothing — desert stays under a tenth of the ground around every
	# answer without it. A second rule saying what the first already says is a
	# rule nobody notices has stopped working.
	var worth := MapGenerator.site_score(map, x, y)
	if tilt.is_empty():
		return worth

	for dy in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var at := Vector2i(x + dx, y + dy)
			if not map.in_bounds(at.x, at.y):
				continue
			worth += TILT_WEIGHT * float(
				tilt.get(String(map.terrain_at(at.x, at.y)), 0.0))
	return worth


## 🔒 Whether a ship can reach this ground (§6). Not negotiable, whatever was
## asked for.
static func sea_within_reach(map: WorldMap, x: int, y: int) -> bool:
	for dy in range(-SEA_WITHIN, SEA_WITHIN + 1):
		for dx in range(-SEA_WITHIN, SEA_WITHIN + 1):
			var at := Vector2i(x + dx, y + dy)
			if map.in_bounds(at.x, at.y) and map.terrain_at(at.x, at.y) == &"sea":
				return true
	return false


## Whether this request is answered by putting high ground under the town.
static func wants_high_ground(request: StringName) -> bool:
	return request == DEFENSIVE_POSITION


## And the fiat itself (§4).
##
## **The tile beneath the town is made a mountain.** Separate from `choose` on
## purpose: choosing reads the map and this writes to it, and a function that did
## both would be one a caller could not ask a question of without changing the
## world.
##
## The shipped coastal ground carries no mountains at all, so this will be very
## nearly the only coastal mountain on the map — which is characterful and
## correct, and is what asking for a position rather than a country buys.
static func raise_high_ground(map: WorldMap, at: Vector2i) -> void:
	if map == null or not map.in_bounds(at.x, at.y):
		return
	map.set_terrain(at.x, at.y, &"mountains")


static func _before(a: Vector2i, b: Vector2i) -> bool:
	if b == Vector2i(-1, -1):
		return true
	return a.y < b.y or (a.y == b.y and a.x < b.x)
