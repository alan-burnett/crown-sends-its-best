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


func _init(p_standing: CrownStanding = null) -> void:
	standing = p_standing


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
