class_name ExpeditionDriver
extends RefCounted

## Expeditions crossing country, in **world month phase 2, Movement** (#176,
## `docs/mechanics/founding-towns.md` §6).
##
## Phase 2 because that is where things on the map move, and because it is
## **before Territory and the Colony Month**: a party that came home this month
## is part of its town before that town works its ground.
##
## ## 🔒 It never returns fire
##
## There is no defence here and there is nowhere to put one. An expedition is
## prey until it arrives (§7), and the only thing this does with an attack is
## account for it.
##
## ## What it does not do yet
##
## **Nothing attacks.** Natives are M5 and rivals M6, so `ExpeditionParty.attacked`
## has no caller in the game — it is written, tested and waiting, so that the
## milestone bringing enemies emits an ambush and stops rather than deciding for
## itself what an ambush does to a wagon train.
##
## **Nothing arrives, either.** Founding the town on arrival is #179. A party
## that reaches its site simply stands there, which is visible and wrong-looking
## in exactly the way that makes the next ticket obvious.

var colony: Colony = null

## The ground itself, for working out where a region's best site actually is.
var map: WorldMap = null

## The parties in the open. The same array the colony context carries, so a
## launch in the Colony Month is on the map without anything copying it across.
var parties: Array = []


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.MOVEMENT:
		return

	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony
	context.parties = parties

	# **Iterated in a fixed order and rebuilt rather than mutated**, so which
	# party moves first cannot depend on what happened to another one.
	var still_out: Array = []
	for entry in parties:
		var party: ExpeditionParty = entry
		if party.is_empty():
			continue
		if _step(party, context):
			continue
		still_out.append(party)

	parties.clear()
	for party in still_out:
		parties.append(party)


## One month for one party. Returns true when it is finished with.
func _step(party: ExpeditionParty, context: ColonyContext) -> bool:
	if party.turning_back:
		var home := _town(party.parent)
		if home == null:
			# Its town is gone. It has nowhere to come back to, which is a state
			# M5 and M6 can produce and this one cannot — said plainly rather
			# than left as a party circling a hole in the map.
			party.turn_back(context)
			return true
		if party.advance(home.at, context) or party.at == home.at:
			party.come_home(home, context)
			return true
		return false

	# 🔒 **The ground is worked out afresh every month** (#177). That is what makes
	# a preference letter an instrument rather than a courtesy: it arrives
	# mid-crossing and the governor's answer to "where exactly" changes with it.
	#
	# A party with no region **waits** rather than wandering. Only a launch gives
	# it one, and a party the player watched go nowhere for reasons nobody wrote
	# down would be worse than one standing still.
	party.settle_destination(map, colony)
	if party.destination == Vector2i(-1, -1):
		return false

	if not party.advance(party.destination, context) and party.at != party.destination:
		return false

	# **It is there.** The town is founded with exactly what it carried (#179).
	var town := party.found(_name_for(party), _display_name_for(party), context)
	if town == null:
		return true
	colony.add(town)
	# 🔒 **Border and vision extend through the existing territory phase**, which
	# runs later in the same month. Nothing here touches the map: a town in the
	# colony is a town territory already knows how to account for, and a bespoke
	# path would be a second answer to a question already answered.
	return true


## What the new town is called, in the save and in the prose.
##
## **Derived from the party**, so it is the same on a reload and the same on two
## machines — a name drawn from a list would need a stream of its own, and the
## stream would have to be the party's, which is what the id already is.
func _name_for(party: ExpeditionParty) -> StringName:
	return StringName("town_%s" % String(party.id).replace("expedition_", ""))


func _display_name_for(party: ExpeditionParty) -> String:
	return String(_name_for(party)).replace("town_", "").capitalize()


func _town(id: StringName) -> Town:
	if colony == null:
		return null
	for town in colony.in_order():
		if town.id == id:
			return town
	return null
