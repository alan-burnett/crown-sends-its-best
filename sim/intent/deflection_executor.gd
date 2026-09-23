class_name DeflectionExecutor
extends IntentExecutor

## Sending a duke to collect his tribute from the patron's house (#284,
## `docs/mechanics/patrons.md` §5, `rival-pressure.md` §4).
##
## > *He took the bait, we arrested the men, well done on capturing those
## > traitors.*
##
## ## 🔒 The only answer to a tribute demand that costs nothing
##
## `rival-pressure.md` gives a demand exactly two answers and both cost:
##
## | | Costs |
## | :--- | :--- |
## | **Pay** | gold out of `net_position`, standing *and* prestige, plus an optic that never decays |
## | **Refuse** | the duke's loyalty, driving him toward tile denial and war |
##
## **This is a third door.** It costs neither, and it is worth two demands — the
## one deflected and the one skipped. So this file writes a date and **nothing
## else**: no gold moves, no loyalty moves, and `OpticsRegister` is not told,
## because there is nothing for the court to hear about. *The patron is sneaky
## enough to cover for the PC entirely.*
##
## A dev who adds an optic here has made the third door cost something, and the
## whole mechanic is that it does not.
##
## ## 🔒 A skipped demand is not a deferred attack
##
## `TributeExecutor` writes `rival.quiet_until.` when the PC **pays**, which is
## about whether the duke comes for the colony. This is about whether he writes
## again. **Two keys**, for the same reason #210 split the state change from the
## optic: one name for two things is how paying a man quietly came to mean he had
## also stopped asking.

const KIND: StringName = &"deflect_tribute"

## Where a skipped demand lives, per duke.
const SKIPPED_PREFIX: String = "rival.demand_skipped_until."

const EVENT_DEFLECTED: StringName = &"tribute_deflected"

## How long he is silent for. **One demand**, per §5 — *the duke skips his next
## demand, and the one after is normal* — so this is the trigger's own cooldown
## and a month, and it is not tuning independent of that figure.
const DEMAND_CYCLE: int = 15


static func key_for(duke: StringName) -> String:
	return SKIPPED_PREFIX + String(duke)


## Whether this duke is sitting on his hands this month.
static func is_holding_off(state: WorldState, duke: StringName, month: int) -> bool:
	if state == null or String(duke).is_empty():
		return false
	return month < int(state.get_value(key_for(duke), 0.0))


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var to := String(intent.data.get("to", ""))
	if to.is_empty():
		return Intent.STALLED

	var until := state.month + DEMAND_CYCLE
	state.apply(log, EVENT_DEFLECTED, StringName(to), {
		key_for(StringName(to)): float(until),
	}, WorldPhase.MOVEMENT)

	log.emit(EVENT_DEFLECTED, StringName(to), state.month, {
		"duke": to,
		"silent_until": until,
		# 🔒 **Nothing about the PC's part in it.** He never puts it together, so
		# the log carries what happened and not who arranged it — and no reader
		# can price a thing it cannot find.
		"cost": 0.0,
	}, WorldPhase.MOVEMENT)
	return Intent.COMPLETED
