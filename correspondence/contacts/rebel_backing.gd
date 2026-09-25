class_name RebelBacking
extends RefCounted

## Dukes back rebel towns, once in their lives (#403,
## `docs/mechanics/rival-pressure.md` §8 *They back rebel towns*; SPEC §12.3).
##
## ## 🔒 The roll
##
## Once a town has been rebelling for `AFTER_MONTHS`, every duke who has arrived
## and has not yet backed a rebellion rolls, each month, from his own stream.
## **His loyalty to the PC sets the chance**: certain at none, never at full, in
## proportion between. On success he backs **the most populous** town rebelling
## that long, ties to town order — an Intent `BackRebellionExecutor` lands the
## month after (Seam C).
##
## ## 🔒 Once in his life
##
## A duke who has backed a rebellion (`Contact.backed_rebellion`) never rolls
## again, nor does one whose backing is already on its way. **Two dukes may back
## the same town.**
##
## ## 🔒 Never lost to him, and his men go home
##
## Backing is not conquest: the town stays a rebel town of the colony. When it
## comes back to the Crown, returned or retaken, **his company goes home,
## commander and all** — he backed a rebellion, not the colony. `Rebellion`'s
## turning of the town's companies does not reach it, since the town does not
## support it.
##
## ## Phase 8
##
## Where will becomes Intent. The going home is first, so a town that came back
## this month has sent the duke's men away before anybody rolls.

## How long a town must have been out before a duke backs it. The Author's
## figure (§8).
const AFTER_MONTHS: int = 3

const EVENT_WENT_HOME: StringName = &"rebel_backing_went_home"

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.INTENT or run == null or run.colony == null:
		return
	_send_home(state, log)
	_roll(state, log)


## The chance a duke backs a rebellion this month: certain at no loyalty to the
## PC, never at full, in proportion between.
static func chance(duke: Contact) -> float:
	return 1.0 - clampf(duke.loyalty() / Relationship.MAX_LOYALTY, 0.0, 1.0)


## 🔒 **The most populous town rebelling `AFTER_MONTHS` or more**, ties to town
## order; or null.
static func town_to_back(colony: Colony, month: int) -> Town:
	if colony == null:
		return null
	var chosen: Town = null
	for entry in colony.in_order():
		var town: Town = entry
		if not town.rebelling or town.rebelling_since < 0 or month - town.rebelling_since < AFTER_MONTHS:
			continue
		if chosen == null or town.population() > chosen.population():
			chosen = town
	return chosen


func _roll(state: WorldState, log: EventLog) -> void:
	var town := town_to_back(run.colony, state.month)
	if town == null or run.intents == null or run.streams == null:
		return
	for entry in RivalDuke.arrived_in(run, run.demands):
		var duke: Contact = entry
		if duke.is_dead or not duke.backed_rebellion.is_empty() or _is_on_its_way(duke.id):
			continue
		if run.streams.contact_stream(String(duke.id)).randf() >= chance(duke):
			continue
		run.intents.commit(Intent.new(&"", BackRebellionExecutor.KIND, duke.id, duke.id, 1,
			{"town": String(town.id)}), log, state.month)


func _is_on_its_way(duke: StringName) -> bool:
	for intent in run.intents.live():
		if intent.kind == BackRebellionExecutor.KIND and intent.source == duke:
			return true
	return false


## Every duke's company whose town is no longer in rebellion goes home, with
## its commander: **one event per company**.
func _send_home(state: WorldState, log: EventLog) -> void:
	if run.companies == null:
		return
	var went := false
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty() or String(company.backs).is_empty():
			continue
		var town := run.colony.by_id(company.backs)
		if town != null and town.rebelling:
			continue
		log.emit(EVENT_WENT_HOME, company.raised_by, state.month, {
			"company": String(company.id),
			"town": String(company.backs),
			"duke": String(company.raised_by),
			"men": company.size,
			"commander": String(company.commander),
		}, WorldPhase.INTENT)
		# **They leave; they never linger as mouths**, and nothing of theirs
		# lands in the town. Their commander is the duke's man and goes with them.
		company.arms = {}
		company.size = 0
		if not String(company.commander).is_empty():
			run.contacts.erase(String(company.commander))
		went = true
	if went:
		run.companies.bury_the_dead()
