class_name NativeHelpDriver
extends RefCounted

## Their people arrive, in **phase 1** (#207, `natives.md` §6).
##
## Beside the Crown's settlers and for the same reason: this is where new people
## appear, so a man who walked in from the village next door is counted, fed and
## housed in the same month as one who stepped off a ship — and nothing
## downstream can tell them apart, which is the point.
##
## 🔒 **Nothing here touches the Crown's books.** There is no path from this
## driver to `CrownAccounts`, so population the natives provide does not move
## `net_position` and costs the PC nothing in standing or prestige. The cheapest
## population in the game comes from the people the colony is displacing.

var colony: Colony = null
var natives: Tribes = null
var map: WorldMap = null

## Expeditions in the open, so a party crossing their country can pick up guides.
var parties: Array = []


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.ARRIVALS or natives == null:
		return

	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony

	if colony != null:
		for town in colony.in_order():
			var village := _nearest_to(town.at)
			if village == null:
				continue
			var tribe := natives.find((village as Village).tribe)
			NativeHelp.join(tribe, village, town, context)
			NativeHelp.gifts(tribe, village, town, context)

	for party in parties:
		var village := _nearest_to((party as ExpeditionParty).at)
		if village == null:
			continue
		NativeHelp.join_party(
			natives.find((village as Village).tribe), village, party, context)


## The village whose country this place is deepest in, or null.
##
## The same reach as every other question about the neighbours, so a town near
## enough to offend a people is near enough to be helped by them.
func _nearest_to(where: Vector2i) -> Village:
	var nearest: Village = null
	var deepest := 0.0
	for village in natives.villages_in_order():
		var depth := Intrusion.into(where, village as Village)
		if depth > deepest + 0.0001:
			nearest = village
			deepest = depth
	return nearest
