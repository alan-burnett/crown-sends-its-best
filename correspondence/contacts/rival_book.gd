class_name RivalBook
extends RefCounted

## Which dukes have reached the bottom (#209, `rival-pressure.md` §3).
##
## 🔒 **A latch, and the only thing stored about a band.** Everything else a duke
## does is read off his loyalty by `RivalDuke.band_of`, so there is no band field
## for the two to disagree about. This holds one fact that genuinely is not
## derivable: *he has been to the bottom*, which survives his loyalty climbing
## back afterwards.
##
## Built the same way `Tribe.irreconcilable` is, because the two docs mean it the
## same way: a point of no return the player can see coming and cannot reverse.
## Ids go in and never come out, and there is no method here that removes one.

const EVENT_LATCHED: StringName = StringName("rival_reached_minimum")

var latched: Dictionary = {}


func is_at_minimum(duke: StringName) -> bool:
	return bool(latched.get(String(duke), false))


## Record that a duke has reached the bottom (Seam A). Returns whether this was
## the month it happened.
##
## 🔒 **One way only.** There is deliberately no `release`, no `clear` and no
## setter taking a boolean: a dev who wanted a duke talked back from the bottom
## would have to add the method and argue with `test_rival_dukes`.
func reached_minimum(duke: Contact, context: ColonyContext) -> bool:
	if duke == null or is_at_minimum(duke.id):
		return false
	latched[String(duke.id)] = true
	context.log.emit(EVENT_LATCHED, duke.id, context.state.month, {
		"rival": String(duke.id),
		# **That he has, never how far down.** SPEC §10.3's rule about the
		# Crown's standing holds here for the same reason: a payload carrying the
		# figure is a payload a letter could render.
		"name": duke.display_name,
	}, WorldPhase.RECKONING)
	return true


## Dukes at the bottom, in id order.
func in_order() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(latched.keys())
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in in_order():
		out[String(id)] = true
	return {"latched": out}


static func from_dict(data: Dictionary) -> RivalBook:
	var book := RivalBook.new()
	book.latched = data.get("latched", {}).duplicate()
	return book
