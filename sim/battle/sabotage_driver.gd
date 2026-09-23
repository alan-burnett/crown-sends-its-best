class_name SabotageDriver
extends RefCounted

## A patron interfering with one duke (#284, `docs/mechanics/patrons.md` §5).
##
## ## 🔒 One named rival, and no other
##
## **The strongest thing a patron has**, and the one specialty that is influence
## rather than a shipment. It is written per duke, so a colony facing three of
## them is a colony that had to choose which one to have a bad year.
##
## ## 🔒 It never touches the PC's relationship with that duke
##
## Which is what makes it work: *the patron is sneaky enough to cover for the PC
## entirely*, so nothing here moves a loyalty, banks an optic or emits anything a
## rival could read. A duke whose companies fight badly for a year never puts it
## together.
##
## ## 🔒 And it cannot undo the latch
##
## `rival-pressure.md` §3 locks that a duke at **minimum** loyalty is there for
## the run. **A patron may help the PC survive that; nothing brings a duke back
## from open war.** So a duke at minimum is refused the gift outright rather than
## quietly given a weaker version of it — the check is at the grant, where the
## refusal can be a letter.
##
## ## What this file does each month
##
## Reads the world value and writes `Company.sabotaged` on the men it names.
## The year runs down on its own because the value carries the month it ends, so
## nothing has to remember to switch it off — and a company raised in the ninth
## month of a sabotaged year is sabotaged too, which is right: it is the duke's
## affairs that are in disarray, not one body of men.

## Where a sabotaged year lives, per duke. Same shape as
## `TributeExecutor.DEFERRED_PREFIX`, and for the same reason: a world value
## saves and loads with everything else and appears in the diff when it moves.
const SABOTAGED_PREFIX: String = "rival.sabotaged_until."

const EVENT_ARRANGED: StringName = &"rival_sabotaged"

## How long a patron's interference lasts. **A year**, per §5, and not tuning —
## the ticket names the span, and a different one is a different gift.
const MONTHS: int = 12

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


static func key_for(duke: StringName) -> String:
	return SABOTAGED_PREFIX + String(duke)


## Whether this duke's affairs are in disarray this month.
static func is_sabotaged(state: WorldState, duke: StringName, month: int) -> bool:
	if state == null or String(duke).is_empty():
		return false
	return month < int(state.get_value(key_for(duke), 0.0))


## Arrange it (Seam A). Returns whether the patron could.
##
## 🔒 **Refused outright for a duke at minimum**, rather than granted weakly. §3's
## latch is that he is there for the run, and a gift that appeared to help and
## did not would be worse than one the patron declines to offer.
static func arrange(
	duke: Contact, state: WorldState, log: EventLog, month: int
) -> bool:
	if duke == null or RivalDuke.band_of(duke.loyalty()) == RivalDuke.MINIMUM:
		return false

	state.apply(log, EVENT_ARRANGED, duke.id, {
		key_for(duke.id): float(month + MONTHS),
	}, WorldPhase.DISPATCH)
	return true


## Phase 1, before anybody moves: mark the men whose year this is.
func on_phase(
	phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams
) -> void:
	if phase != WorldPhase.ARRIVALS or run == null or run.companies == null:
		return
	for entry in run.companies.list:
		var company: Company = entry
		if company == null or company.allegiance != Company.RIVAL:
			continue
		# **By the duke who raised it**, which `Muster` records — a rival company
		# carries whose it is, so three dukes' armies on one map are told apart
		# without anything here knowing how they got there.
		company.sabotaged = is_sabotaged(state, company.raised_by, state.month)
