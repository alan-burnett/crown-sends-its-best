class_name Grievances
extends RefCounted

## What a town holds against the Crown, and how it fades
## (#71, `docs/mechanics/rebel-sentiment.md` §4).
##
## ## 🔒 They decay, they do not expire
##
## A grievance is a **timed contributor**: it enters at full weight and falls
## linearly to nothing over its life. Flat expiry would drop a town's sentiment
## several points in one month for no visible reason, and the Diplomat has to be
## able to describe a trend truthfully — he cannot report that a town is settling
## if the number lurches.
##
## ## Held against the Crown, not against a person
##
## A refusal does double duty (§4): it costs the governor's loyalty *and* it
## raises the town's sentiment, because **the people learn the Crown would not
## help them**. The two are separate consequences of one letter, which is why
## this lives on the town rather than on a relationship.

## What a grievance can be about. Ids, so the letters and the Diplomat can name
## what a town is sore about without reading a weight.
const REFUSED: StringName = &"refused"
const PROMISE_BROKEN: StringName = &"promise_broken"
const HARSH_ORDER: StringName = &"harsh_order"
const MILITARY_ABUSE: StringName = &"military_abuse"
const RELIEF_IMBALANCE: StringName = &"relief_imbalance"

const EVENT_TAKEN: StringName = &"town_took_offence"

## Town id -> array of `{kind, month, months, weight}`.
var _held: Dictionary = {}


## Record a new grievance against a town.
func add(
	town_id: StringName,
	kind: StringName,
	month: int,
	weight: float,
	months: int,
	log: EventLog = null,
) -> void:
	if weight <= 0.0 or months <= 0:
		return
	var key := String(town_id)
	if not _held.has(key):
		_held[key] = []
	_held[key].append({
		"kind": String(kind),
		"month": month,
		"months": months,
		"weight": weight,
	})
	if log != null:
		log.emit(EVENT_TAKEN, town_id, month, {
			"town": key,
			"kind": String(kind),
			"months": months,
			# **No weight in the payload.** Sentiment is never a number the player
			# sees (§6), and a payload carrying one is a payload a letter could
			# render.
		}, WorldPhase.COLONY_MONTH)


## What a town's grievances add up to this month.
##
## Linear decay over each grievance's life: full weight the month it is taken,
## nothing the month it runs out.
func weight_for(town_id: StringName, month: int) -> float:
	var total := 0.0
	for entry in _held.get(String(town_id), []):
		total += _remaining(entry, month)
	return total


## Which grievances a town is still sore about, freshest first.
##
## For the Diplomat and the governor, who have to be able to name what is wrong
## without anybody seeing a figure.
func active(town_id: StringName, month: int) -> PackedStringArray:
	var sore: Array = []
	for entry in _held.get(String(town_id), []):
		if _remaining(entry, month) > 0.0:
			sore.append([int(entry["month"]), String(entry["kind"])])
	sore.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) > int(b[0])
		return String(a[1]) < String(b[1]))

	var out: PackedStringArray = PackedStringArray()
	for entry in sore:
		out.append(String(entry[1]))
	return out


## Drop what has run its course.
##
## **Housekeeping, not mechanics.** A spent grievance already contributes nothing;
## this only stops the list growing without bound over a fifty-year run.
func forget_spent(month: int) -> void:
	for key in _held.keys():
		var kept: Array = []
		for entry in _held[key]:
			if _remaining(entry, month) > 0.0:
				kept.append(entry)
		if kept.is_empty():
			_held.erase(key)
		else:
			_held[key] = kept


func _remaining(entry: Dictionary, month: int) -> float:
	var months := maxi(1, int(entry.get("months", 1)))
	var age := month - int(entry.get("month", 0))
	if age < 0 or age >= months:
		return 0.0
	return float(entry.get("weight", 0.0)) * (1.0 - float(age) / float(months))


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = _held.keys()
	keys.sort()
	for key in keys:
		out[key] = _held[key].duplicate(true)
	return out


static func from_dict(data: Dictionary) -> Grievances:
	var restored := Grievances.new()
	var keys: Array = data.keys()
	keys.sort()
	for key in keys:
		restored._held[key] = (data[key] as Array).duplicate(true)
	return restored
