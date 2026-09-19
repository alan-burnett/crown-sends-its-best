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

## Told when the Crown's drafts start bouncing, so every policy the PC was
## funding becomes a renegotiation rather than a silent collapse (#80, §5).
var policies: PolicyBook = null
var contacts: Dictionary = {}


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
		_judgement(log, state.month),
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
		"judgement": float(moved["judgement"]),
		# **The number is not in here.** The bands are the whole interface, and a
		# payload carrying the figure is a payload a letter could render.
	}, WorldPhase.RUN_END_CHECK)

	_react(state, log)


## What the Crown made of the PC's conduct this month, beyond his accounts.
##
## **Read off the log**, like everything else here, so the letters and the sheet
## cannot disagree about what happened. Three things register:
##
## - A revenue target reached. He said what his colony would return and it did.
## - A revenue target missed. Worse than never having undertaken it, because the
##   Treasury now knows something about his judgement as well as his colony.
## - A demand declined. It costs, and it costs **less** than missing one — which
##   is the whole decision the Steward's letter puts in front of the player.
##
## The cost of declining is scaled by `refusal_cost`, which is how the
## `desperation` axis reaches anything at all: it changes the price of saying no
## and nothing else, so a player who grants everything never feels it
## (`crown-demands.md` §6).
func _judgement(log: EventLog, month: int) -> float:
	if log == null:
		return 0.0
	var total := 0.0
	for event in log.for_month(month):
		match event.type:
			PromiseBook.EVENT_KEPT:
				if String(event.payload.get("kind", "")) == String(Promise.KIND_REVENUE):
					total += CrownStanding.TARGET_REACHED
			PromiseBook.EVENT_BROKEN:
				if String(event.payload.get("kind", "")) == String(Promise.KIND_REVENUE):
					total -= CrownStanding.TARGET_MISSED
			DemandBook.EVENT_LAPSED:
				# **Silence is not neutral.** The Marshal was not asking whether the
				# PC had noticed him, and letting the deadline pass costs what
				# saying no plainly would have cost. SPEC §9.3 lets the post pile
				# up; it does not make it free.
				total -= DemandSchedule.refusal_cost(growth)
			Compliance.OUTCOME_EVENTS[Compliance.COMPLY], \
			Compliance.OUTCOME_EVENTS[Compliance.PARTIAL], \
			Compliance.OUTCOME_EVENTS[Compliance.DELAY], \
			Compliance.OUTCOME_EVENTS[Compliance.REINTERPRET], \
			Compliance.OUTCOME_EVENTS[Compliance.REFUSE]:
				# **The deed is the PC's, whatever the contact then does with it.**
				# He declined the Crown; what the Steward makes of the letter is a
				# separate matter and is already on the relationship.
				var order: Dictionary = event.payload.get("order", {})
				if String(order.get("kind", "")) == String(M1Registrations.ORDER_DECLINE_DEMAND):
					total -= DemandSchedule.refusal_cost(growth)
	return total


## The run's growth, so the price of a refusal is this year's price. Set by the
## turn machine; without it the steady figure stands.
var growth: DemandGrowth = null


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

	if promises == null:
		return
	promises.can_crown_pay = refusal.pays()

	# **The month it stops, it stops for everything.** Not only what fell due.
	if String(happened.get("event", "")) == String(CrownRefusal.EVENT_REFUSING):
		var broken := promises.repudiate(log, state.month)
		# **And every policy he was funding is now unfunded** (#80, §5). Not a
		# collapse: it puts him in the same position as if he had written to each
		# enactor saying he would pay nothing, and each decides for himself. A PC
		# who has been generous finds half his apparatus carried by men willing
		# to cover for him; one who has squeezed everyone finds it unwinds in a
		# season, at the exact moment he can least afford it.
		if policies != null:
			policies.crown_stopped_paying(log, state.month, contacts)
		log.emit(CrownRefusal.EVENT_REFUSING, &"crown", state.month, {
			"state": String(refusal.state),
			"repudiated": broken.size(),
			# Who was let down, so the grievances #71 reads are already on the
			# record and nothing has to be reconstructed later.
			"let_down": _names(broken),
		}, WorldPhase.RUN_END_CHECK)


static func _names(broken: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for promise in broken:
		if not out.has(String(promise.to)):
			out.append(String(promise.to))
	out.sort()
	return out
