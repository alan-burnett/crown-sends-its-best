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

## The towns a village might drive off, and whose governors it must write to
## first (#435).
var colony: Colony = null


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
	for entry in natives.villages_in_order():
		var village: Village = entry
		var tribe := natives.find(village.tribe)
		# 🔒 **They always write first** (#435, `natives.md` §11): no village
		# takes a hostile objective against a town whose governor has not had a
		# letter from its tribe in an earlier month. The town it would drive off
		# is the nearest.
		var target := TribeGrievanceDriver.nearest_town(colony, village.at)
		var written := target == null \
			or natives.grievances.has_written_before(village.tribe, target.id, state.month)
		village.live(tribe, context, written)
		if not written and tribe != null and tribe.is_irreconcilable_with(Tribe.COLONY) \
				and not _warned_this_month(village.tribe, target.id, state.month):
			# **They say what they will do before they do it.**
			natives.grievances.write(village.tribe, target,
				TribeGrievance.WE_WILL_DRIVE_YOU_OFF, village.at, &"", log, state.month)


func _warned_this_month(tribe: StringName, town: StringName, month: int) -> bool:
	for grievance in natives.grievances.list:
		if grievance.tribe == tribe and grievance.town == town and grievance.month == month:
			return true
	return false
