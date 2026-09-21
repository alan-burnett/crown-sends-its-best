class_name PrestigeDriver
extends RefCounted

## Settles prestige once a month (#76, `docs/mechanics/prestige.md` §6).
##
## ## Where it sits, and where the doc says it sits
##
## §6 asks for three things: **after promises are honoured or broken**, **after
## standing updates**, and **before phase 7, Reckoning**, so that contacts
## writing this month's letters read this month's prestige rather than last
## month's.
##
## It heads that list "world month phase 5, the Crown's Month" — but standing
## does not update in phase 5. `CrownStandingDriver` runs in **phase 6**, and its
## own docstring explains why: duty is taken in phase 4 and promises are settled
## in phase 5, so a figure judged in phase 5 would read a month whose promises
## had not all landed.
##
## So this runs in phase 6, immediately after standing, which satisfies all three
## of §6's actual constraints. The phase number in the heading is the one thing
## that does not fit, and it is the doc's to correct rather than mine.
##
## ## It reads the log, like everything else on this side of the ocean
##
## Through `CrownAccounts` and `OpticsRegister`, which are two reductions over
## one record. Nothing accumulates a running total in a field where it could
## drift away from what actually happened.

var prestige: Prestige = null


func _init(p_prestige: Prestige = null) -> void:
	prestige = p_prestige


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RUN_END_CHECK or prestige == null:
		return
	prestige.settle(log, state.month)
