class_name TribeGrievances
extends RefCounted

## Every letter a tribe has written to a governor, and the acts still going on
## (#435, `docs/mechanics/natives.md` §11).
##
## ⚠ assumed there: **the same act on the same tile is noticed once, until it
## stops and starts again.** `ongoing` is what makes that true — last month's
## acts, keyed by what and where and by whom, so an act still going on is not
## written about twice and one that stopped and began again is.

const EVENT_WRITTEN: StringName = &"tribe_wrote_to_the_governor"

var list: Array[TribeGrievance] = []
var next_ordinal: int = 0

## Act key -> true, for the acts noticed and still going on.
var ongoing: Dictionary = {}


## A tribe writes (Seam A).
func write(
	tribe: StringName, town: Town, act: StringName, at: Vector2i, company: StringName,
	log: EventLog, month: int,
) -> TribeGrievance:
	var grievance := TribeGrievance.new()
	grievance.id = StringName("grievance_%d" % next_ordinal)
	next_ordinal += 1
	grievance.tribe = tribe
	grievance.town = town.id
	grievance.governor = town.governor_id
	grievance.act = act
	grievance.at = at
	grievance.company = company
	grievance.month = month
	list.append(grievance)
	if log != null:
		log.emit(EVENT_WRITTEN, tribe, month, {
			"grievance": String(grievance.id),
			"tribe": String(tribe),
			"town": String(town.id),
			"governor": String(town.governor_id),
			"act": String(act),
			"at": [at.x, at.y],
			"company": String(company),
		}, WorldPhase.RECKONING)
	return grievance


func find(id: StringName) -> TribeGrievance:
	for grievance in list:
		if grievance.id == id:
			return grievance
	return null


## The letters written before `month` that no governor has answered yet.
func awaiting_answer(month: int) -> Array[TribeGrievance]:
	var out: Array[TribeGrievance] = []
	for grievance in list:
		if not grievance.is_answered() and grievance.month < month:
			out.append(grievance)
	return out


## The letter this governor asked the PC about and has not yet answered, the
## latest first (#436), or null.
func asked_by(governor: StringName) -> TribeGrievance:
	var latest: TribeGrievance = null
	for grievance in list:
		if grievance.governor != governor or grievance.asked_month < 0 or grievance.is_answered():
			continue
		if latest == null or grievance.asked_month >= latest.asked_month:
			latest = grievance
	return latest


## The latest letter written to this governor, whatever became of it (#436).
func latest_to(governor: StringName) -> TribeGrievance:
	var latest: TribeGrievance = null
	for grievance in list:
		if grievance.governor == governor and (latest == null or grievance.month >= latest.month):
			latest = grievance
	return latest


## 🔒 **Whether this tribe has written to this town's governor in an earlier
## month** — the lock every hostile objective waits on (§11).
func has_written_before(tribe: StringName, town: StringName, month: int) -> bool:
	for grievance in list:
		if grievance.tribe == tribe and grievance.town == town and grievance.month < month:
			return true
	return false


func to_dict() -> Dictionary:
	var entries: Array = []
	for grievance in list:
		entries.append(grievance.to_dict())
	var keys: Array = ongoing.keys()
	keys.sort()
	return {"list": entries, "next_ordinal": next_ordinal, "ongoing": keys}


static func from_dict(data: Dictionary) -> TribeGrievances:
	var book := TribeGrievances.new()
	for entry in data.get("list", []):
		book.list.append(TribeGrievance.from_dict(entry))
	book.next_ordinal = int(data.get("next_ordinal", book.list.size()))
	for key in data.get("ongoing", []):
		book.ongoing[String(key)] = true
	return book
