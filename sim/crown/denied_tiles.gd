class_name DeniedTiles
extends RefCounted

## Ground a rival has parked men on (#188, SPEC §11.2;
## `docs/mechanics/rival-pressure.md` §5).
##
## ## 🔒 It is not combat
##
## Nothing is destroyed, nobody dies, **no defeat is scored and no optics debt is
## incurred**. The colony is merely poorer, month after month, for as long as he
## sits there. There is no path from this file to `OpticsRegister` and nothing
## here emits anything the prestige reckoning prices.
##
## That is what the spread between Low and Minimum needs in order to mean
## anything: a duke short of open war hurting the colony materially without the
## escalation open war implies.
##
## ## 🔒 A denied tile is absent, never scored at zero
##
## Work's candidate list simply does not contain it. A tile nobody can reach is
## not a tile the town looked at and rejected — scoring it at zero would put it
## in the trace, in the ranking and in any future explanation of why the month
## went as it did, all of which would be false.
##
## ## 🔒 The only instrument is a letter with money in it
##
## The PC cannot order it cleared. He raises the duke's loyalty until the man
## leaves, and there is deliberately no Order kind that touches this. Rule by
## Correspondence with nothing else to hide behind.

const EVENT_PARKED: StringName = &"rival_parked_on_our_ground"
const EVENT_WITHDREW: StringName = &"rival_withdrew"

## Tile key -> the duke sitting on it.
var held: Dictionary = {}


static func key_of(at: Vector2i) -> String:
	return "%d,%d" % [at.x, at.y]


func is_denied(at: Vector2i) -> bool:
	return held.has(key_of(at))


func denied_by(at: Vector2i) -> StringName:
	return StringName(held.get(key_of(at), ""))


## Every tile this duke is sitting on, in a fixed order.
func of_duke(duke: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in in_order():
		if StringName(held[key]) == duke:
			out.append(_tile(String(key)))
	return out


func count_for(duke: StringName) -> int:
	return of_duke(duke).size()


## Tile keys, sorted. Never iterate `held` where the result depends on order.
func in_order() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray(held.keys())
	keys.sort()
	return keys


## A duke's men arrive on a tile (Seam A). Returns whether they were not already
## there.
func park(duke: StringName, at: Vector2i, town: StringName, context: ColonyContext) -> bool:
	if is_denied(at):
		return false
	held[key_of(at)] = String(duke)
	context.log.emit(EVENT_PARKED, town, context.state.month, {
		"rival": String(duke),
		"town": String(town),
		"at": [at.x, at.y],
		# **Which tiles and which town**, because the map plays this back and the
		# governor writes about it. Soldiers on your own doorstep are not a
		# secret, so nothing here is withheld from the player.
		"tiles": count_for(duke),
	}, WorldPhase.TERRITORY)
	return true


## And they leave (Seam A). Returns how many tiles he gave up.
func withdraw(duke: StringName, context: ColonyContext) -> int:
	var going := of_duke(duke)
	if going.is_empty():
		return 0
	for at in going:
		held.erase(key_of(at))
	context.log.emit(EVENT_WITHDREW, duke, context.state.month, {
		"rival": String(duke),
		"tiles": going.size(),
	}, WorldPhase.TERRITORY)
	return going.size()


static func _tile(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key in in_order():
		out[String(key)] = held[key]
	return {"held": out}


static func from_dict(data: Dictionary) -> DeniedTiles:
	var book := DeniedTiles.new()
	book.held = data.get("held", {}).duplicate()
	return book
