class_name DemandBook
extends RefCounted

## What the Crown is asking of the PC right now, and when it last asked
## (SPEC §10.2; `docs/mechanics/crown-demands.md` §4).
##
## ## A revenue target, not a bill
##
## SPEC §10.2 locks that the PC's gold is **not a wallet**, so the Steward is not
## asking him to hand over coins he does not have. He is stating what the colony
## is expected to return through taxed trade over the coming months.
##
## Accepting makes it a **promise** (SPEC §9.5), and whether it is kept depends
## on whether the colony's trade actually reaches the figure. **Saying yes is a
## bet on your own colony**: fall short and the promise *breaks*, costing loyalty
## on top of the standing. Refuse outright and it costs standing and the
## Steward's regard, but nothing breaks and nobody is surprised.
##
## That asymmetry is the decision, and the player has to judge his own colony to
## know which he is making.
##
## ## Issued by the sim, answered by the post
##
## The Crown decides in phase 5 that it wants something; the letter that carries
## it goes out in phase 9. Deciding it here rather than in a trigger condition
## keeps the schedule where the schedule belongs — a condition cannot record
## that it fired, so a demand scheduled from the letter side would either repeat
## every month or need a cooldown that could not grow with `frequency`.

const KIND_GOLD: StringName = &"gold"

const EVENT_DEMANDED: StringName = &"crown_demanded"

## Months before the Crown asks for anything at all.
##
## Not zero: a demand in the founding month arrives before the player has seen
## what he is governing, and the first decision of a run should not be a bet
## made blind.
const FIRST_DEMAND_MONTH: int = 3

## The month the Crown last asked for something, so the next one is `frequency`
## months after it rather than a fixed cooldown the growth could not reach.
var last_issued_month: int = -1

## The demand made this month, if any. Read by the letter that carries it.
var issued_month: int = -1
var asker: StringName = &""
var kind: StringName = KIND_GOLD
var amount: float = 0.0
var term_months: int = 0


## Whether a demand was made this month, and so whether a letter is owed.
func is_pending(month: int) -> bool:
	return issued_month == month and issued_month >= 0


## Decide whether the Crown asks for something this month, and what.
##
## Returns whether it did. **Idempotent within a month**, since the driver runs
## once a month but nothing should depend on that being true.
func advance(month: int, growth: DemandGrowth, log: EventLog) -> bool:
	if month < FIRST_DEMAND_MONTH or issued_month == month:
		return false
	if last_issued_month >= 0:
		if float(month - last_issued_month) < DemandSchedule.months_between(growth):
			return false

	issued_month = month
	last_issued_month = month
	asker = &"steward"
	kind = KIND_GOLD
	amount = DemandSchedule.gold_target(growth)
	term_months = DemandSchedule.term_months()

	if log != null:
		log.emit(EVENT_DEMANDED, asker, month, {
			"asker": String(asker),
			"kind": String(kind),
			"amount": amount,
			"term_months": term_months,
		}, WorldPhase.CROWNS_MONTH)
	return true


func to_dict() -> Dictionary:
	return {
		"last_issued_month": last_issued_month,
		"issued_month": issued_month,
		"asker": String(asker),
		"kind": String(kind),
		"amount": amount,
		"term_months": term_months,
	}


static func from_dict(data: Dictionary) -> DemandBook:
	var restored := DemandBook.new()
	restored.last_issued_month = int(data.get("last_issued_month", -1))
	restored.issued_month = int(data.get("issued_month", -1))
	restored.asker = StringName(data.get("asker", ""))
	restored.kind = StringName(data.get("kind", KIND_GOLD))
	restored.amount = float(data.get("amount", 0.0))
	restored.term_months = int(data.get("term_months", 0))
	return restored
