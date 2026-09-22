class_name RivalTileDriver
extends RefCounted

## A duke parks men on the colony's ground, in **phase 3** (#188,
## `rival-pressure.md` §5).
##
## Phase 3 is Territory, and this runs straight after it: a duke sits on ground
## the colony actually holds, so the influence areas have to be this month's. The
## Colony Month is phase 4, so Work sees the denial the same month it happens and
## the town's yields fall for it.
##
## The one month of separation the loop promises is still there. Loyalty moves in
## **phase 7**, so a duke who fell into the low band this month parks in phase 3
## of the next one — announced by his own cooling before anything is taken.
##
## ## 🔒 It reads a band and writes a tile list, and that is all
##
## No damage, no casualties, no defeat, **no optic**. There is no path from here
## to `OpticsRegister` and nothing in this file knows what a battle is.
##
## ## 🔒 And no Order can clear it
##
## The PC raises the duke's loyalty until he leaves. There is deliberately no
## Order kind that reaches this, so the only instrument is a letter with money in
## it — Rule by Correspondence with nothing else to hide behind.

## How many tiles a duke sits on at the top of the low band, and at the bottom
## of the scale. Tuning.
const TILES_AT_LOW: int = 1
const TILES_AT_WORST: int = 4

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.TERRITORY or run == null or run.denied == null:
		return

	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony

	var territory: Territory = run.territory_now()
	# 🔒 **Only the dukes the Squeeze has produced** (#300, §6). All three are
	# on the roster from month one because SPEC §8.4 makes rivals fixed contacts,
	# and one of them ships below the low band — so before this, a foreign duke
	# parked men on the colony's fields in the first month of every run, and the
	# governor wrote a desperate letter about it before the colony had done
	# anything at all.
	for duke in RivalDuke.arrived_in(run, run.demands):
		var band := RivalDuke.band_for(duke, run.rivals)
		if not RivalDuke.denies_tiles(band):
			# 🔒 **Raising his loyalty past the low band ends it**, and nothing
			# else does. This is the only place men are withdrawn.
			run.denied.withdraw(duke.id, context)
			continue
		_park(duke, band, territory, context)


## Put his men on the best ground the colony holds and is not already denied.
##
## **The best, deterministically.** He is not choosing at random and he is not
## being polite: the tile that hurts most is the tile he takes, and ties break on
## coordinates so the same world gives the same answer twice.
func _park(
	duke: Contact,
	band: StringName,
	territory: Territory,
	context: ColonyContext,
) -> void:
	var wanted := _how_many(duke, band)
	var standing := run.denied.count_for(duke.id)
	if standing >= wanted or territory == null or run.colony == null:
		return

	for _step in wanted - standing:
		var best := Vector2i(-1, -1)
		var most := -1.0e30
		var whose: StringName = &""
		for town in run.colony.in_order():
			for at in territory.tiles_of(town.id):
				if run.denied.is_denied(at):
					continue
				var worth := run.map.yield_around(at.x, at.y, &"food")
				if worth > most + 0.0001 \
						or (absf(worth - most) <= 0.0001 and _before(at, best)):
					best = at
					most = worth
					whose = town.id
		if best == Vector2i(-1, -1):
			return
		run.denied.park(duke.id, best, whose, context)


## How much ground he takes, scaled by how far down he is.
##
## **Proportionate** (§5): it is not a single event but a pressure that deepens,
## which is what makes it the right thing for the spread between asking for money
## and burning towns.
func _how_many(duke: Contact, band: StringName) -> int:
	if band == RivalDuke.MINIMUM:
		return TILES_AT_WORST
	var loyalty: float = duke.relationship.loyalty if duke.relationship != null else 0.0
	var into := clampf(
		(RivalDuke.MEDIUM_AT - loyalty) / maxf(1.0, RivalDuke.MEDIUM_AT - RivalDuke.LOW_AT),
		0.0, 1.0)
	return clampi(
		TILES_AT_LOW + int(roundf(into * float(TILES_AT_WORST - TILES_AT_LOW))),
		TILES_AT_LOW, TILES_AT_WORST)


static func _before(a: Vector2i, b: Vector2i) -> bool:
	if b == Vector2i(-1, -1):
		return true
	return a.y < b.y or (a.y == b.y and a.x < b.x)
