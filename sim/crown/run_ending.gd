class_name RunEnding
extends RefCounted

## How a run stopped, and what the court made of it (#77, SPEC §13.2, §14.1;
## `docs/mechanics/prestige.md` §9).
##
## ## 🔒 Scored from the state at that moment, not from a running total
##
## Prestige reflects the Crown's **current** view (SPEC §13.2), so the figure a
## run ends on is the figure it had reached — not a tally kept alongside it that
## could have drifted. `Prestige.of(log)` is asked once, here, and what it
## answers is the score.
##
## That is what makes retiring a decision rather than a formality: **the number
## is not waiting at the finish line, it is the one you are standing on.**
##
## ## The three ways out, and what each is worth (§9)
##
## | | |
## | :--- | :--- |
## | **Voluntary retirement** | the tally as it stands. No bonus, no penalty — the timing *was* the decision |
## | **Forced retirement at fifty years** | also the tally, and normally a great one: six hundred months of net gold against a fixed set of black marks |
## | **A fail condition** | the tally, **less a large final optics debt**. Losing the colony is the most embarrassing thing that can happen to the Crown |
##
## Only the first exists (#77). Fifty years is #78's neighbour and fail
## conditions are M6, and both are a row in `OpticsRegister` and a reason
## recorded here rather than a change to how ending works.
##
## ## 🔒 Ironman: an ended run cannot be resumed
##
## SPEC §16.2. The save is closed out when the ending is recorded, and the ending
## itself is part of the state — so a save that somehow survived would still say
## the run was over rather than quietly letting it continue.

const EVENT_ENDED: StringName = &"run_ended"

## Why it stopped. Two of the three have nothing that produces them yet.
const RETIRED: StringName = &"retired"
const TERM_EXPIRED: StringName = &"term_expired"
const FAILED: StringName = &"failed"

var reason: StringName = &""
var month: int = -1

## The score, settled once when the run ended.
##
## Held rather than recomputed because the log a summary reads may outlive the
## run's own accounting — and because #78's epitaph must say the same thing
## every time it is opened.
var score: float = 0.0
var net_gold: float = 0.0
var optics_debt: float = 0.0

## 🔒 **Which fail condition it was** (#267, `endings.md` §1). Both ways of
## losing are `FAILED` and cost the same final optics debt — the court is equally
## embarrassed either way — so this is what the summary and the epitaph read to
## tell *the colony was overrun* from *the colony threw us out*.
##
## Empty for a run that ended any other way.
var how: StringName = &""


func is_over() -> bool:
	return not String(reason).is_empty()


## End the run, from the state as it stands (Seam A).
##
## **The final optics debt of a fail condition is charged here and priced in the
## register**, not decided by whatever discovered the failure — same rule as
## every other optic (`prestige.md` §4).
static func end(reason_for: StringName, log: EventLog, month_now: int) -> RunEnding:
	if reason_for == FAILED:
		log.emit(OpticsRegister.EVENT_RUN_FAILED, &"crown", month_now, {
			"reason": String(reason_for),
		}, WorldPhase.RUN_END_CHECK)

	var parts := Prestige.of(log)
	var ending := RunEnding.new()
	ending.reason = reason_for
	ending.month = month_now
	ending.score = float(parts["total"])
	ending.net_gold = float(parts["net_gold"])
	ending.optics_debt = float(parts["optics_debt"])

	# 🔒 **No figure on the payload.** SPEC §14.1 keeps prestige off the player's
	# screens, and that does not stop being true because the run is over — #78's
	# summary says what became of the colony and what the court made of the man,
	# in words. The score is on the ending for the epitaph to read, not in an
	# event a letter could render.
	log.emit(EVENT_ENDED, &"crown", month_now, {
		"reason": String(reason_for),
		"month": month_now,
		"years": int(month_now / 12),
	}, WorldPhase.RUN_END_CHECK)
	return ending


func to_dict() -> Dictionary:
	return {
		"reason": String(reason),
		"month": month,
		"score": score,
		"net_gold": net_gold,
		"optics_debt": optics_debt,
		"how": String(how),
	}


static func from_dict(data: Dictionary) -> RunEnding:
	var out := RunEnding.new()
	out.reason = StringName(data.get("reason", ""))
	out.month = int(data.get("month", -1))
	out.score = float(data.get("score", 0.0))
	out.net_gold = float(data.get("net_gold", 0.0))
	out.optics_debt = float(data.get("optics_debt", 0.0))
	out.how = StringName(data.get("how", ""))
	return out
