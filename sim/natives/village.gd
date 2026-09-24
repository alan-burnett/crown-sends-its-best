class_name Village
extends RefCounted

## A tribe's settlement (#205, SPEC §12.5, §11.1;
## `docs/mechanics/natives.md` §4).
##
## It works land, holds stores, feeds its people and trades.
##
## ## 🔒 A tribe never founds a village
##
## **The map's villages are the map's villages**, fixed at generation. They grow
## in place — in population, and in **influence**, the land they work.
##
## That is what keeps tribes full actors rather than a diminishing obstacle.
## **The colony expands by founding and a tribe expands by thriving**, and the
## two press against each other over the same ground. A colony that leaves its
## neighbours alone does not find them conveniently static; it finds them
## growing, and wanting the tiles it had meant to farm next.
##
## There is no `found()` here and there is no code path that makes one.
##
## ## 🔒 No buildings, no governor, no contact, no intent
##
## **No buildings at all** — they shape the country without fortifying it, which
## is why a village is easier to take than a town and why taking one is worse.
## They build farms and **never forts** (§11.1).
##
## **No governor and no contact**, so there is nobody the PC could write to even
## if the mechanism allowed it.
##
## **And no intent layer.** A town needs a governor's intent because a governor
## is a person with his own opinion who may be wrong. **A tribe's situation is
## its own intent, and it is never wrong about what is happening to it** — so
## what steers a village is the tribe's standings and nothing else.

const EVENT_GREW: StringName = &"village_grew"
## A hungry month thinned them (#427). Seam A: a village's people falling is an
## event like a town's, so nothing downstream has to notice it by subtraction.
const EVENT_STARVED: StringName = &"village_starved"
const EVENT_SPREAD: StringName = &"village_influence_spread"
const EVENT_OBJECTIVE: StringName = &"village_objective"

## What a village can set itself to. **Simpler than a town's**, because it has no
## buildings to want and no governor to have opinions about them.
const FEED_OURSELVES: StringName = &"feed_ourselves"
const GROW: StringName = &"grow"
const WORK_MORE_LAND: StringName = &"work_more_land"
const ARM_OURSELVES: StringName = &"arm_ourselves"
const DRIVE_THEM_OFF: StringName = &"drive_them_off"

const OBJECTIVES: Array[StringName] = [
	ARM_OURSELVES, DRIVE_THEM_OFF, FEED_OURSELVES, GROW, WORK_MORE_LAND,
]

## Where a tribe's regard for the colony stops being a worry and starts being a
## reason to arm. Tuning.
const UNEASY_BELOW: float = 40.0
const FRIGHTENED_BELOW: float = 22.0

## Months of food a village wants in hand before it thinks about anything else.
const HUNGRY_BELOW: float = 1.5

## How far a village's influence reaches at its smallest, and the most it ever
## reaches. Tuning.
const INFLUENCE_MIN: int = 1
const INFLUENCE_MAX: int = 4

## People per tile of reach. A village presses outward because it has mouths to
## feed, not because it has decided to. Tuning.
const MOUTHS_PER_REACH: float = 22_000.0

var id: StringName = &""
var tribe: StringName = &""
var at: Vector2i = Vector2i(-1, -1)

var people: int = 0
var stores: Dictionary = {}

## Births owed but not yet born, carried as a town's are.
var growth_accrued: float = 0.0

## What it is doing about its situation this month.
var objective: StringName = FEED_OURSELVES


## How far its worked land reaches.
##
## **Derived from its people**, so a village that prospers presses outward and
## one that is starving pulls in — without anything deciding to expand. The
## colony's border is a consequence of its towns; this is the same rule for
## people who never founded anything.
func influence() -> int:
	return clampi(
		INFLUENCE_MIN + int(floorf(float(people) / MOUTHS_PER_REACH)),
		INFLUENCE_MIN, INFLUENCE_MAX)


## Whether this village works a tile.
func holds(tile: Vector2i) -> bool:
	var reach := influence()
	return absi(tile.x - at.x) <= reach and absi(tile.y - at.y) <= reach


## Every tile it works, in a fixed order.
func land(map: WorldMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := influence()
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile := at + Vector2i(dx, dy)
			if map == null or (map.in_bounds(tile.x, tile.y) and map.is_land(tile.x, tile.y)):
				out.append(tile)
	return out


## What it should be doing, given how its tribe sees the world (Seam A).
##
## 🔒 **Steered by the tribe's standings and nothing else.** There is no village
## opinion to be wrong, no governor to argue with, and no intent for the PC to
## write about — which is the whole reason a village needs no layer a town needs.
func decide(its_tribe: Tribe, months_of_food: float, context: ColonyContext) -> StringName:
	var was := objective

	if months_of_food < HUNGRY_BELOW:
		# Before anything else. A hungry people has one question.
		objective = FEED_OURSELVES
	elif its_tribe != null and its_tribe.is_irreconcilable_with(Tribe.COLONY):
		# 🔒 Past the point of no return there is nothing left to discuss, and
		# what a village does about that is not a mood — it is a conclusion.
		objective = DRIVE_THEM_OFF
	elif its_tribe != null and its_tribe.trust() < FRIGHTENED_BELOW:
		objective = ARM_OURSELVES
	elif its_tribe != null and its_tribe.trust() < UNEASY_BELOW:
		objective = WORK_MORE_LAND
	else:
		objective = GROW

	if objective == was:
		return objective
	context.log.emit(EVENT_OBJECTIVE, id, context.state.month, {
		"village": String(id),
		"tribe": String(tribe),
		"was": String(was),
		"now": String(objective),
	}, WorldPhase.COLONY_MONTH)
	return objective


## A month of living (Seam A).
##
## **They grow in place.** Nothing here founds anything, and there is nowhere in
## this file that could.
func live(its_tribe: Tribe, context: ColonyContext) -> void:
	var eaten := Population.of(ColonyNeeds.per_head(&"food"), float(people))
	var held := float(stores.get("food", 0.0))
	var months := held / maxf(0.0001, eaten)
	decide(its_tribe, months, context)

	# What the land gives them, at the reach they hold.
	#
	# **Everything the ground offers, not only the food** (#206). A village that
	# gathered nothing but grain would have nothing but grain to trade, and
	# `natives.md` §5 has them offering *what the village is actually producing*.
	# They take the raw things: they do not work iron and they do not brew.
	if context.map != null:
		var working := (1.3 if objective == WORK_MORE_LAND else 1.0) * _gathers
		var fields := land(context.map)
		for resource in _what_the_land_gives():
			var gathered := 0.0
			for tile in fields:
				gathered += context.map.yield_at(tile.x, tile.y, resource)
			if gathered <= 0.0:
				continue
			if resource == &"food":
				held += gathered * working
			else:
				stores[String(resource)] = float(
					stores.get(String(resource), 0.0)) + gathered * working

	# How short the month left them, before the stores are drawn down.
	var unmet := 0.0 if eaten <= 0.0 else clampf((eaten - held) / eaten, 0.0, 1.0)
	held = maxf(0.0, held - eaten)
	stores["food"] = held

	if held <= 0.0:
		# 🔒 **A hungry village loses a share** (#427, `population.md` §6), the
		# same share a town's famine takes, in one event that says how many.
		var lost := mini(people, maxi(1, int(round(
			float(people) * unmet * ConsumePhase.FAMINE_DEATH_RATE))))
		people -= lost
		context.log.emit(EVENT_STARVED, id, context.state.month, {
			"village": String(id),
			"tribe": String(tribe),
			"lost": lost,
			"people": people,
		}, WorldPhase.COLONY_MONTH)
		return

	var reach := influence()
	growth_accrued += float(people) * _birth_rate(its_tribe) * minf(1.0, months / 3.0)
	# **Whole people land, the fraction carries** (#427), in one event.
	var born := int(floorf(growth_accrued))
	if born <= 0:
		return
	growth_accrued -= float(born)
	people += born
	context.log.emit(EVENT_GREW, id, context.state.month, {
		"village": String(id),
		"tribe": String(tribe),
		"born": born,
		"people": people,
	}, WorldPhase.COLONY_MONTH)

	if influence() > reach:
		# 🔒 **A village that prospers presses outward**, and the colony finds its
		# neighbours wanting the tiles it had meant to farm next. This is the
		# event the map reads to draw the contest.
		context.log.emit(EVENT_SPREAD, id, context.state.month, {
			"village": String(id),
			"tribe": String(tribe),
			"at": [at.x, at.y],
			"reach": influence(),
			"was": reach,
		}, WorldPhase.COLONY_MONTH)


## The raw things a village takes off its land.
##
## 🔒 **Nothing processed and nothing that wants a craft they do not have.**
## `natives.md` §5 and SPEC §12.2: what they cannot make is exactly what they
## trade *for*, so a village that gathered tools would have no reason to deal
## with the colony at all.
static func _what_the_land_gives() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ResourceCatalogue.ids():
		var resource := StringName(id)
		if ResourceCatalogue.is_livestock(resource):
			continue
		if ResourceCatalogue.native_worth(resource) > CRAFT_THEY_LACK:
			continue
		out.append(resource)
	return out


## Above this, a thing takes a craft they do not have, and they gather none of
## it however much of it is lying about. Tuning.
const CRAFT_THEY_LACK: float = 1.0

## 🔒 **What the ground gives a village that works it** (#288, *Restless
## country*).
##
## **One in every run without the quirk**, and above one their villages take more
## off the same tiles than a colonial town would. They grow faster, they have more
## to spare, and they field more men when they conclude.
##
## 🔒 **On what they gather, never on the map.** `WorldMap.yield_at` is the
## ground, and it is the same ground the colony farms — a quirk that moved it
## would quietly hand the PC richer tiles as well, which is the opposite of the
## quirk. What changes is how much these neighbours get out of it.
static var _gathers: float = 1.0


static func gathers() -> float:
	return _gathers


static func set_gathers(scale: float) -> void:
	_gathers = maxf(0.0, scale)


static func reset() -> void:
	_gathers = 1.0


## How fast they grow, which is faster when they are at ease. Tuning.
func _birth_rate(its_tribe: Tribe) -> float:
	var settled := 1.0
	if its_tribe != null and its_tribe.trust() < UNEASY_BELOW:
		settled = 0.6
	return 0.010 * settled if objective != GROW else 0.016 * settled


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"tribe": String(tribe),
		"at": [at.x, at.y],
		"people": people,
		"stores": stores.duplicate(),
		"growth_accrued": growth_accrued,
		"objective": String(objective),
	}


static func from_dict(data: Dictionary) -> Village:
	var village := Village.new()
	village.id = StringName(data.get("id", ""))
	village.tribe = StringName(data.get("tribe", ""))
	var pair: Array = data.get("at", [-1, -1])
	village.at = Vector2i(int(pair[0]), int(pair[1])) if pair.size() >= 2 else Vector2i(-1, -1)
	village.people = int(data.get("people", 0))
	village.stores = data.get("stores", {}).duplicate()
	village.growth_accrued = float(data.get("growth_accrued", 0.0))
	village.objective = StringName(data.get("objective", String(FEED_OURSELVES)))
	return village
