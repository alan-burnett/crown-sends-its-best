class_name TribeAnswerExecutor
extends IntentExecutor

## What a governor's answer to a tribe does, the month after he gives it (#435,
## `docs/mechanics/natives.md` §11).
##
## | Answer | What happens |
## | :--- | :--- |
## | **Yield** | the town stops working the tile, or calls the company home. An improvement is left standing but unused |
## | **Gift** | he sends the tribe resources to smooth it over |
## | **Refuse**, **threaten** | the town carries on |
##
## 🔒 **Nothing here moves the tribe's standing.** That is the tribe's, when the
## answer reaches it (`TribeGrievanceDriver`); this is only the town doing what its
## governor said.

const EVENT_YIELDED: StringName = &"town_yielded_to_a_tribe"
const EVENT_GIFTED: StringName = &"town_sent_a_tribe_a_gift"

## Supplied by the turn loop.
var run: RunState = null


func handles(intent: Intent) -> bool:
	return intent.kind == TribeGrievanceDriver.ANSWER_KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	if run == null or run.tribes == null:
		return Intent.STALLED
	var grievance := run.tribes.grievances.find(StringName(intent.data.get("grievance", "")))
	var town: Town = run.colony.by_id(grievance.town) if grievance != null and run.colony != null else null
	if grievance == null or town == null:
		return Intent.STALLED

	var context := ColonyContext.new(state, log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	match StringName(intent.data.get("answer", "")):
		TribeGrievance.YIELD:
			_yield(grievance, town, context)
		TribeGrievance.GIFT:
			_gift(grievance, town, intent.data.get("gift", {}), context)
	grievance.answered_month = state.month
	intent.progress = intent.months_required
	return Intent.COMPLETED


## 🔒 **The field goes unworked from next month, and whatever stands on it stays**
## (§11). A company on their ground is called home.
func _yield(grievance: TribeGrievance, town: Town, context: ColonyContext) -> void:
	if grievance.act == TribeGrievance.COMPANY_ON_ITS_GROUND:
		var company := run.companies.find(grievance.company) if run.companies != null else null
		if company != null and not company.is_empty():
			if company.is_headless():
				company.stand_down(town, context)
			else:
				# **Argued, never ordered** (#405): the governor's own urging, and
				# the commander weighs it like any other.
				company.stand(Urging.make(town.governor_id, CommanderConsiderations.WITHDRAW, context.state.month))
	else:
		town.yield_tile(grievance.at, grievance.tribe)
	context.log.emit(EVENT_YIELDED, town.id, context.state.month, {
		"grievance": String(grievance.id),
		"town": String(town.id),
		"tribe": String(grievance.tribe),
		"act": String(grievance.act),
		"at": [grievance.at.x, grievance.at.y],
		"company": String(grievance.company),
	}, WorldPhase.MOVEMENT)


## Whatever he promised, out of what the town still holds.
func _gift(grievance: TribeGrievance, town: Town, gift: Dictionary, context: ColonyContext) -> void:
	if gift.is_empty():
		return
	var village: Village = null
	var closest := 0
	for entry in run.tribes.villages_of(grievance.tribe):
		var candidate: Village = entry
		var away := maxi(absi(candidate.at.x - grievance.at.x), absi(candidate.at.y - grievance.at.y))
		if village == null or away < closest:
			village = candidate
			closest = away
	if village == null:
		return
	var resource := StringName(gift.get("resource", ""))
	var sent := town.take(resource, float(gift.get("amount", 0.0)))
	if sent <= 0.0:
		return
	village.stores[String(resource)] = float(village.stores.get(String(resource), 0.0)) + sent
	context.log.emit(EVENT_GIFTED, town.id, context.state.month, {
		"grievance": String(grievance.id),
		"town": String(town.id),
		"tribe": String(grievance.tribe),
		"village": String(village.id),
		"resource": String(resource),
		"amount": sent,
	}, WorldPhase.MOVEMENT)
