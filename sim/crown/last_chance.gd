class_name LastChance
extends RefCounted

## The last-chance stage, which is not a mechanism (#268,
## `docs/mechanics/endings.md` §2, SPEC §13.1).
##
## §13.1 locks that **every fail condition passes through a last-chance stage
## with a formal Chancellor warning, so that defeat is never a surprise.**
##
## ## 🔒 There is no countdown, and there is no state
##
## §2 is emphatic: *a dev who finds himself building a countdown for it has built
## a third timer alongside two that were already running.* Standing already
## descends a ladder — Concern, Alarm, the Chancellor, and only then a countdown
## before the Crown refuses a penny — and troops already leave by the Marshal's
## staged withdrawal, announced a season ahead.
##
## **The stage is the overlap of warnings that already exist.** What was missing
## is the Chancellor noticing, and that is all this adds.
##
## So this file holds **nothing**. It emits the four conditions and the
## population every month, moved or not, exactly as `CrownStanding.EVENT_MOVED`
## does — and *the log is the memory*. A condition that wants to know what
## changed reads the last two of these and compares them. There is no field
## anywhere recording that the stage has begun, because there is no stage: there
## are four facts and a number, and the Chancellor delights in both.
##
## ## What he is told
##
## | | |
## | :--- | :--- |
## | **Independence** | the four conditions, each named, each true or not |
## | **Overrun** | the population, which falls slowly and in the open |
##
## §2 again: there is no conjunction to watch approach for Overrun, only a number
## falling — but it falls one at a time under hardship and in shares under arms,
## every loss emits its own event, and **a colony does not arrive at zero people
## from a comfortable position.**

## Emitted **every month**, moved or not.
##
## A month the Crown looked at the colony and concluded it was fine is still a
## month it looked, and a condition that wants *what changed* needs both readings
## to compare. It is also what makes the acceptance line testable: an ending
## cannot fire in a month this did not precede.
const EVENT_LOOKED: StringName = &"last_chance_looked"

## The four conditions of Independence, named.
##
## 🔒 **The same four `RunEndCheck` decides on**, asked one at a time rather than
## re-derived — so the letter naming which are true and the check deciding
## whether the run is over can never disagree about one of them.
const EVERY_TOWN_REBELS: String = "every_town_rebels"
const CONFIDENCE_LOST: String = "confidence_lost"
const NO_TROOPS: String = "no_troops"
const NO_MORE_COMING: String = "no_more_coming"

const CONDITIONS: Array[String] = [
	CONFIDENCE_LOST, EVERY_TOWN_REBELS, NO_MORE_COMING, NO_TROOPS,
]

## How few people left makes it worth writing about, and the rungs below that.
##
## **Descending, and he writes again at each one** (§2: *and again as it
## worsens*). Tuning, and it is the one figure here that is: the rungs decide how
## much warning the player gets, and `endings.md` §2's claim is that by the time
## the Chancellor arrives *the player has watched it coming for a year*.
const DIRE_AT: Array[int] = [40, 25, 15, 8, 3]


## Look at the colony and say what is true, in the log (Seam A).
##
## Returns what it reported, so the caller need not read its own event back.
static func look(
	colony: Colony,
	parties: Array,
	companies: Companies,
	standing: CrownStanding,
	marshal: Contact,
	state: WorldState,
	log: EventLog,
) -> Dictionary:
	var people := RunEndCheck.people_in(colony, parties)
	var flags := conditions_of(colony, companies, standing, marshal, state)

	var payload := flags.duplicate()
	payload["people"] = people
	payload["rung"] = rung_for(people)
	payload["how_many"] = how_many_true(flags)
	payload["towns"] = 0 if colony == null else colony.in_order().size()
	log.emit(EVENT_LOOKED, &"crown", state.month, payload, WorldPhase.RUN_END_CHECK)
	return payload


## The four, each answered separately.
##
## 🔒 **`RunEndCheck` owns every one of these tests** and this only names them.
## A second reading of *has the Crown lost confidence* would be a second place
## the answer lived, and the first time one moved the Chancellor would start
## writing about a condition the check did not believe in.
static func conditions_of(
	colony: Colony,
	companies: Companies,
	standing: CrownStanding,
	marshal: Contact,
	state: WorldState,
) -> Dictionary:
	if colony == null:
		return {
			EVERY_TOWN_REBELS: false, CONFIDENCE_LOST: false,
			NO_TROOPS: false, NO_MORE_COMING: false,
		}
	return {
		EVERY_TOWN_REBELS: not RunEndCheck.any_town_is_loyal(colony),
		CONFIDENCE_LOST: standing != null and standing.has_lost_confidence(),
		NO_TROOPS: RunEndCheck.crown_troops_in(companies) <= 0,
		NO_MORE_COMING: not RunEndCheck.will_send_more(marshal, standing, state),
	}


static func how_many_true(flags: Dictionary) -> int:
	var count := 0
	for name in CONDITIONS:
		if bool(flags.get(name, false)):
			count += 1
	return count


## Which rung of the dwindling this population is on, or `-1` while it is fine.
##
## **Counted from the top down**, so a colony that fell two rungs in one month
## reports the lower of them and the Chancellor's letter is about where it is
## rather than about where it passed.
static func rung_for(people: int) -> int:
	var rung := -1
	for index in DIRE_AT.size():
		if people <= DIRE_AT[index]:
			rung = index
	return rung


# --- Reading it back --------------------------------------------------------

## What was reported this month, or empty.
static func latest(log: EventLog, month: int) -> Dictionary:
	var looks := log.of_type(EVENT_LOOKED)
	for index in range(looks.size() - 1, -1, -1):
		var event: SimEvent = looks[index]
		if event.month == month:
			return event.payload
	return {}


## What was reported the month before that, or empty.
static func previous(log: EventLog, month: int) -> Dictionary:
	var best: Dictionary = {}
	var latest_before := -1
	for event in log.of_type(EVENT_LOOKED):
		if event.month < month and event.month > latest_before:
			latest_before = event.month
			best = event.payload
	return best


## The conditions that became true this month, sorted. Empty when none did.
##
## 🔒 **Newly true only.** §3 has him writing *as each condition flips*, and a
## letter that fired every month a condition merely remained true would be the
## nagging the ladder above already does, from a man whose whole comic value is
## that he turns up rarely and at the worst moment.
static func newly_true(log: EventLog, month: int) -> PackedStringArray:
	var now := latest(log, month)
	if now.is_empty():
		return PackedStringArray()
	var before := previous(log, month)
	# 🔒 **The first look is a baseline and reports nothing.**
	#
	# *Flipped* needs a before, and without this the very first month of every run
	# would report `no_troops` as freshly true — it is true from the start,
	# because a colony begins with no Crown soldiers on the ground — and the
	# Chancellor would open every game by formally warning the player that the
	# colony was about to be lost.
	if before.is_empty():
		return PackedStringArray()
	var out := PackedStringArray()
	for name in CONDITIONS:
		if bool(now.get(name, false)) and not bool(before.get(name, false)):
			out.append(name)
	return out


## Whether the colony fell to a new rung of dwindling this month.
##
## **A rung it has not been on before**, so a colony that loses a man and regains
## him does not set the Chancellor writing twice about the same figure.
static func newly_dire(log: EventLog, month: int) -> bool:
	var now := latest(log, month)
	if now.is_empty():
		return false
	var rung := int(now.get("rung", -1))
	if rung < 0:
		return false
	for event in log.of_type(EVENT_LOOKED):
		if event.month < month and int(event.payload.get("rung", -1)) >= rung:
			return false
	return true
