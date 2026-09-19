class_name CrownStandingDriver
extends RefCounted

## Advances Crown standing once a month, in **phase 6**.
##
## ## Why phase 6 and not phase 5
##
## Standing reacts to the month's revenue *and* the month's spending, and those
## land in different phases: duty is taken during the Colony Month (phase 4) and
## promises are honoured during the Crown's Month (phase 5). Judging in phase 5
## would read a month whose promises had not all been settled, and the figure
## would be a month out for the rest of the run.
##
## Phase 6 is also before Reckoning and Dispatch, so the Steward and the
## Chancellor write about a standing that already reflects the month they are
## writing about.
##
## ## It reads the log
##
## Through `CrownAccounts`, which is the same reduction the Ledger shows the
## player. **Two readers of one log is how the letters come to say one thing and
## the sheet another**, and the gap between those two is the player's only
## instrument for reading the Crown's mind.

var standing: CrownStanding = null

## The political half (#68). Driven from here so that the arithmetic always
## settles before the process reacts to it, in that order, once a month.
var refusal: CrownRefusal = null

## Told whether the Crown is paying, every month. The one place the two halves
## meet the rest of the game.
var promises: PromiseDriver = null


func _init(p_standing: CrownStanding = null, p_refusal: CrownRefusal = null) -> void:
	standing = p_standing
	refusal = p_refusal


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RUN_END_CHECK or standing == null:
		return

	var accounts := CrownAccounts.of(log)
	var moved := standing.advance(
		accounts.received_in(state.month),
		accounts.paid_in(state.month),
	)

	# **Emitted every month, moved or not.** A month the Crown thought about the
	# PC and concluded nothing is still a month it thought about him, and the
	# letters that read a band need it to be on the record either way.
	log.emit(CrownStanding.EVENT_MOVED, &"crown", state.month, {
		"band": String(moved["band"]),
		"was": String(moved["was"]),
		"changed_band": String(moved["band"]) != String(moved["was"]),
		"monthly_net": float(moved["monthly_net"]),
		"net_position": float(moved["net_position"]),
		"horizon": float(moved["horizon"]),
		# **The number is not in here.** The bands are the whole interface, and a
		# payload carrying the figure is a payload a letter could render.
	}, WorldPhase.RUN_END_CHECK)

	_react(state, log)


## The political process, after the arithmetic and never before it.
##
## **Refusal waits for the warning and the countdown**, however fast standing
## collapsed, which is how SPEC §10.3's locked guarantee is kept without
## blunting the arithmetic.
func _react(state: WorldState, log: EventLog) -> void:
	if refusal == null:
		return

	var happened := refusal.advance(standing, state.month)
	if not happened.is_empty():
		var payload := happened.duplicate()
		payload.erase("event")
		payload["state"] = String(refusal.state)
		log.emit(
			StringName(happened["event"]), &"crown", state.month,
			payload, WorldPhase.RUN_END_CHECK,
		)

	if promises != null:
		promises.can_crown_pay = refusal.pays()
