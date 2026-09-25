class_name TribeGrievance
extends RefCounted

## A tribe has written to a governor (#435, `docs/mechanics/natives.md` §11).
##
## ## 🔒 They always write first
##
## **Before a tribe acts against the colony, it writes to the governor.** It
## names the act and asks for it to stop. **It never writes to the PC** (§1):
## the letter goes to the governor of the town the act belongs to, and it is sim
## state and an event, not the PC's post.
##
## ## What it records
##
## The act and where, whom it went to, and — once he has answered — what he said
## and the month the tribe took it. The answer is his; what the tribe does about
## it is `TribeGrievanceDriver`'s.

# --- The four acts a tribe notices (§11), and the warning --------------------------

const LAND_WORKED: StringName = &"land_worked"
const IMPROVEMENT_BUILT: StringName = &"improvement_built"
const COMPANY_ON_ITS_GROUND: StringName = &"company_on_its_ground"
const TOWN_FOUNDED: StringName = &"town_founded"
## 🔒 **What it will do, said before it does it** (§11: *"writes again first,
## saying what it will do"*). The letter every hostile objective follows.
const WE_WILL_DRIVE_YOU_OFF: StringName = &"we_will_drive_you_off"

const ACTS: Array[StringName] = [
	COMPANY_ON_ITS_GROUND, IMPROVEMENT_BUILT, LAND_WORKED, TOWN_FOUNDED, WE_WILL_DRIVE_YOU_OFF,
]

# --- The governor's four answers (§11) --------------------------------------------

const YIELD: StringName = &"yield"
const GIFT: StringName = &"gift"
const REFUSE: StringName = &"refuse"
const THREATEN: StringName = &"threaten"

## Sorted, so the kernel weighs them in one order and ties break the same way.
const ANSWERS: Array[StringName] = [GIFT, REFUSE, THREATEN, YIELD]

var id: StringName = &""
var tribe: StringName = &""
var town: StringName = &""
var governor: StringName = &""
var act: StringName = &""
var at: Vector2i = Vector2i(-1, -1)
## The company it was about, for `COMPANY_ON_ITS_GROUND`.
var company: StringName = &""
## The month the tribe wrote.
var month: int = 0

## What he said, or empty while he has not answered.
var answer: StringName = &""
## The month his answer landed (phase 2), or -1.
var answered_month: int = -1
## The month the tribe took it, or -1 while it has not.
var taken_month: int = -1

## 🔒 **The month he wrote to the PC asking how to answer**, or -1 (#436, §11). A
## governor at or above neutral asks first and holds his answer a month.
var asked_month: int = -1

## What the PC urged, once the governor's compliance took it (#436), and how hard
## it was said. **An urging, never the answer**: he still weighs it.
var urged: StringName = &""
var urged_tone: StringName = &""


func is_answered() -> bool:
	return not String(answer).is_empty()


## Whether yielding means anything for this act. **A town cannot unfound itself**,
## and a warning is not an act to stop.
func may_be_yielded() -> bool:
	return act == LAND_WORKED or act == IMPROVEMENT_BUILT or act == COMPANY_ON_ITS_GROUND


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"tribe": String(tribe),
		"town": String(town),
		"governor": String(governor),
		"act": String(act),
		"at": [at.x, at.y],
		"company": String(company),
		"month": month,
		"answer": String(answer),
		"answered_month": answered_month,
		"taken_month": taken_month,
		"asked_month": asked_month,
		"urged": String(urged),
		"urged_tone": String(urged_tone),
	}


static func from_dict(data: Dictionary) -> TribeGrievance:
	var grievance := TribeGrievance.new()
	grievance.id = StringName(data.get("id", ""))
	grievance.tribe = StringName(data.get("tribe", ""))
	grievance.town = StringName(data.get("town", ""))
	grievance.governor = StringName(data.get("governor", ""))
	grievance.act = StringName(data.get("act", ""))
	var place: Array = data.get("at", [-1, -1])
	grievance.at = Vector2i(int(place[0]), int(place[1])) if place.size() >= 2 else Vector2i(-1, -1)
	grievance.company = StringName(data.get("company", ""))
	grievance.month = int(data.get("month", 0))
	grievance.answer = StringName(data.get("answer", ""))
	grievance.answered_month = int(data.get("answered_month", -1))
	grievance.taken_month = int(data.get("taken_month", -1))
	grievance.asked_month = int(data.get("asked_month", -1))
	grievance.urged = StringName(data.get("urged", ""))
	grievance.urged_tone = StringName(data.get("urged_tone", ""))
	return grievance
