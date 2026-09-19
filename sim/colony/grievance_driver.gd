class_name GrievanceDriver
extends RefCounted

## Turns the month's events into what towns hold against the Crown
## (#71, `docs/mechanics/rebel-sentiment.md` §4).
##
## ## Phase 7, and a month behind on purpose
##
## Promises are honoured or broken in phase 5 and orders resolve in phase 7, so
## this runs after both and the grievances it records are counted by the *next*
## colony month. That lag is right rather than tolerated: a town learns what the
## Crown did to it when the news reaches it, not the instant a clerk in London
## writes it down.
##
## ## It reads the log
##
## Like crown standing and the Ledger, and for the same reason. **Two readers of
## one log is how the letters come to say one thing and the sheet another**, and
## a grievance nobody can trace to an event is a grievance the Diplomat cannot
## describe.

## What each kind is worth, and how long a town stays sore about it. All tuning
## (§8); §9 flags grievance magnitudes as an open item and specifically asks that
## two refusals in a year should not rebel a contented town.
const WEIGHTS: Dictionary = {
	"refused": 9.0,
	"promise_broken": 14.0,
	"harsh_order": 6.0,
	"military_abuse": 20.0,
	"relief_imbalance": 7.0,
}

const MONTHS: Dictionary = {
	"refused": 14,
	"promise_broken": 20,
	"harsh_order": 10,
	"military_abuse": 30,
	"relief_imbalance": 12,
}

## How much a town must give away over what it receives before it minds.
##
## **Relief is free materially and not free politically** (SPEC §11.3). A town
## that is always the giver is being governed for somebody else's benefit, and it
## notices — but one convoy is neighbourliness, not a grievance.
const RELIEF_PATIENCE: float = 220.0

var colony: Colony = null
var grievances: Grievances = null


func _init(p_colony: Colony = null, p_grievances: Grievances = null) -> void:
	colony = p_colony
	grievances = p_grievances


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or colony == null or grievances == null:
		return
	for event in log.for_month(state.month):
		_read(event, state.month, log)
	for town in colony.in_order():
		_weigh_relief(town, state.month, log)
	grievances.forget_spent(state.month)


## What one event did to somebody's town.
func _read(event: SimEvent, month: int, log: EventLog) -> void:
	match event.type:
		PromiseBook.EVENT_BROKEN:
			# **However it broke.** A promise the Crown repudiated is as broken to
			# the town as one the PC could not keep, and SPEC §10.3 is explicit
			# that a collapse in standing reaches the colony this way.
			_against(event.subject, Grievances.PROMISE_BROKEN, month, log)
		Compliance.OUTCOME_EVENTS[Compliance.COMPLY], \
		Compliance.OUTCOME_EVENTS[Compliance.PARTIAL], \
		Compliance.OUTCOME_EVENTS[Compliance.DELAY], \
		Compliance.OUTCOME_EVENTS[Compliance.REINTERPRET], \
		Compliance.OUTCOME_EVENTS[Compliance.REFUSE]:
			var order: Dictionary = event.payload.get("order", {})
			var kind := String(order.get("kind", ""))
			if kind == String(M1Registrations.ORDER_REFUSE) \
					or kind == String(M1Registrations.ORDER_DECLINE_DEMAND):
				# **A refusal does double duty** (§4): it costs the governor's
				# loyalty *and* it raises the town's sentiment, because the people
				# learn the Crown would not help them.
				_against(event.subject, Grievances.REFUSED, month, log)


## Whether this town has been carrying the colony for too long.
func _weigh_relief(town: Town, month: int, log: EventLog) -> void:
	if town.relief_balance < RELIEF_PATIENCE:
		return
	# **Charged once per patience spent**, so a town that keeps giving keeps
	# minding, and one that gave a great deal in a single hard winter minds once.
	town.relief_balance -= RELIEF_PATIENCE
	_add(town.id, Grievances.RELIEF_IMBALANCE, month, log)


## Record it against whichever town this contact speaks for.
##
## The Crown's officers speak for nobody in the colony, so a promise broken to
## the Chancellor offends no town — which is right: the people never hear of it.
func _against(contact_id: StringName, kind: StringName, month: int, log: EventLog) -> void:
	var town := colony.governed_by(contact_id)
	if town == null:
		return
	_add(town.id, kind, month, log)


func _add(town_id: StringName, kind: StringName, month: int, log: EventLog) -> void:
	grievances.add(
		town_id, kind, month,
		float(WEIGHTS.get(String(kind), 0.0)),
		int(MONTHS.get(String(kind), 0)),
		log,
	)
