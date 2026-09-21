class_name VillageDriver
extends RefCounted

## A month in the villages, in **phase 4** (#205, `natives.md` §4).

## Alongside the Colony Month rather than inside it. A village keeps no books the
## colony's phases understand — no reckoning, no exchange, no duty — so it has
## nothing to do in Reckon or Sell and putting it there would only mean nine
## chances to forget it.
##
## What it shares with a town is the ground. Phase 3 has just recomputed
## territory, so a village that spread last month is already drawn where it
## spread before any town works a tile this month.
##
## 🔒 **Nothing here founds anything.** The driver walks the villages generation
## made and asks each to live; there is no branch that appends to the list and no
## call that could.

var natives: Tribes = null
var map: WorldMap = null


func _init(p_natives: Tribes = null, p_map: WorldMap = null) -> void:
	natives = p_natives
	map = p_map


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.COLONY_MONTH or natives == null:
		return

	var context := ColonyContext.new(state, log, streams, map)
	# Villages are served in id order, and nothing here reads another village:
	# each works its own land and feeds its own people. The order cannot decide
	# anything and is fixed only so the log reads the same way twice.
	for village in natives.villages_in_order():
		var tribe := natives.find((village as Village).tribe)
		(village as Village).live(tribe, context)
