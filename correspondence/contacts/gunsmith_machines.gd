class_name GunsmithMachines
extends RefCounted

## The gunsmith's machines break (#438, `institutional-contacts.md` §3 *His
## machines break*; `buildings.md` §3, §6).
##
## ## 🔒 The roll
##
## In a month when his town's quality of life is below `QUALITY_BELOW`, a
## quartermaster whose machines have not broken in the past `COOLDOWN_MONTHS`
## rolls from his own stream: a `CHANCE` that they break. One event (Seam A)
## naming him, his town and the sum he asks, which his letter reads.
##
## ## 🔒 What comes of it
##
## - **The Crown pays**: a promise of gold to the town, kept, puts the sum in the
##   town's purse (`town-economy.md` §4) and the machines are mended. The
##   gunsmith never goes dark.
## - **Anything else** — refused, ignored, or promised and then broken because
##   the Crown is refusing payments — and **the gunsmith is dark for
##   `DARK_MONTHS`**. That lands as an Intent the month after (Seam C): a letter
##   never writes the world (Seam B), and a refusal becomes a dark gunsmith the
##   way any answer becomes a deed.
##
## Each is read off the log, since the break: the promise kept or broken to him,
## his order refused, his letter ignored. **Whichever comes first settles it.**
##
## ## Phase 7
##
## After the colony month, so the quality of life he rolls on is this month's;
## and after promises are settled and orders resolved, so an answer that arrived
## this month is read this month.

const QUALITY_BELOW: float = 0.4
const COOLDOWN_MONTHS: int = 12
const CHANCE: float = 0.2
## What he asks to mend them. A placeholder (#438).
const REPAIR_GOLD: int = 50
## How long the gunsmith is dark when the Crown does not pay. Author's ruling.
const DARK_MONTHS: int = 6

const KIND: StringName = &"quartermaster"
const GUNSMITH: StringName = &"gunsmith"
const LETTER: String = "quartermaster.machines_broken"

const EVENT_BROKE: StringName = &"gunsmith_machines_broke"
const EVENT_MENDED: StringName = &"gunsmith_machines_mended"

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or run == null or run.colony == null:
		return
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.kind != KIND or contact.is_dead:
			continue
		var town := ColonyMeasures.home_of(contact, run)
		if town == null:
			continue
		if contact.machines_waiting:
			_settle(contact, town, state, log)
		else:
			_roll(contact, town, state, log)


## Whether his machines may break this month. The dice are `_roll`'s.
static func may_break(contact: Contact, town: Town, month: int) -> bool:
	if contact.machines_waiting or not town.has_building(GUNSMITH):
		return false
	if town.quality_of_life >= QUALITY_BELOW:
		return false
	return contact.machines_broke < 0 or month - contact.machines_broke >= COOLDOWN_MONTHS


func _roll(contact: Contact, town: Town, state: WorldState, log: EventLog) -> void:
	if not may_break(contact, town, state.month) or run.streams == null:
		return
	if run.streams.contact_stream(String(contact.id)).randf() >= CHANCE:
		return
	contact.machines_broke = state.month
	contact.machines_waiting = true
	log.emit(EVENT_BROKE, contact.id, state.month, {
		"quartermaster": String(contact.id),
		"town": String(town.id),
		"amount": REPAIR_GOLD,
	}, WorldPhase.RECKONING)


## Read what came of his letter, since the break. Nothing yet is nothing yet.
func _settle(contact: Contact, town: Town, state: WorldState, log: EventLog) -> void:
	var answer := answer_to(contact, log)
	if answer == &"":
		return
	contact.machines_waiting = false
	if answer == &"paid":
		log.emit(EVENT_MENDED, contact.id, state.month, {
			"quartermaster": String(contact.id),
			"town": String(town.id),
		}, WorldPhase.RECKONING)
		return
	if run.intents == null:
		return
	run.intents.commit(Intent.new(&"", ShutBuildingExecutor.KIND, contact.id, town.id, 1, {
		"town": String(town.id),
		"building": String(GUNSMITH),
		"months": DARK_MONTHS,
		"because": String(answer),
	}), log, state.month)


## 🔒 **What the Crown did about his machines**, as the log says it: `paid`,
## `refused`, `ignored`, `broken`, or nothing yet. The earliest answer since the
## break is the one that stands.
static func answer_to(contact: Contact, log: EventLog) -> StringName:
	if log == null or contact.machines_broke < 0:
		return &""
	var since := contact.machines_broke
	var first: SimEvent = null
	var answer: StringName = &""
	var seen: Dictionary = {
		PromiseBook.EVENT_KEPT: &"paid",
		PromiseBook.EVENT_BROKEN: &"broken",
		Silence.EVENT_IGNORED: &"ignored",
		Compliance.OUTCOME_EVENTS[Compliance.REFUSE]: &"refused",
		Compliance.OUTCOME_EVENTS[Compliance.COMPLY]: &"refused",
		Compliance.OUTCOME_EVENTS[Compliance.PARTIAL]: &"refused",
		Compliance.OUTCOME_EVENTS[Compliance.DELAY]: &"refused",
		Compliance.OUTCOME_EVENTS[Compliance.REINTERPRET]: &"refused",
		Compliance.OUTCOME_EVENTS[Compliance.ACT_ALONE]: &"refused",
	}
	var types: Array = seen.keys()
	for type in types:
		for entry in log.of_type(type):
			var happened: SimEvent = entry
			if happened.month < since or happened.subject != contact.id:
				continue
			if not _answers_him(happened, contact):
				continue
			if first == null or happened.seq < first.seq:
				first = happened
				answer = seen[type]
	return answer


## Whether this event is an answer to his letter about the machines.
static func _answers_him(happened: SimEvent, _contact: Contact) -> bool:
	match happened.type:
		PromiseBook.EVENT_KEPT, PromiseBook.EVENT_BROKEN:
			return String(happened.payload.get("kind", "")) == "gold"
		Silence.EVENT_IGNORED:
			return String(happened.payload.get("letter", "")) == LETTER
	# An order reaching him: only a refusal counts. A promise of gold resolves
	# through the promise, above.
	var order: Dictionary = happened.payload.get("order", {})
	return String(order.get("kind", "")) == String(M1Registrations.ORDER_REFUSE)
