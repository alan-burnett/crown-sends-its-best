class_name RunSummary
extends RefCounted

## What became of the colony, and what the Crown got from it (#78, SPEC §6.3,
## §14.2).
##
## ## 🔒 Read off the event log, never off a tally kept beside it
##
## The same rule the Ledger follows. A second running total would be a second
## thing to keep in step, and the first time the two disagreed the player would
## be reading a lie about their own run — at the one moment there is no next
## month in which to notice.
##
## ## 🔒 The colony's fate and the PC's are reported in the same even voice
##
## SPEC §5 locks that nothing in the game can harm the PC and that every ending
## sends him into comfort. The summary lets that sit **without commentary**: it
## says what happened to the colony and what happened to the man, in the same
## register, and does not tell the player how to feel about the gap.
##
## SPEC §3.2 is in force. The satire targets the empire and never the colonized:
## a colony ruined by the PC's misrule is not a joke at the colonists' expense,
## and nothing here is phrased as though it were.

## What the whole run came to. Every figure is a reduction over the log or a
## reading of the final state, and nothing here is accumulated during play.
static func of(run: RunState) -> Dictionary:
	var log := run.log
	var accounts := CrownAccounts.of(log)
	var out: Dictionary = {
		"months": run.world.month,
		"years": int(run.world.month / 12),
		"reason": String(run.ending.reason) if run.ending != null else "",
		# 🔒 **Which ending, and why** (#269). `reason` says *failed*, and failed
		# is two entirely different stories: the colony was overrun, or the colony
		# threw us out. The summary that could not tell them apart would be the
		# one screen in the game that did not say what had happened.
		#
		# Empty for a retirement and for fifty years served, because those are
		# wholly described by `reason` — there is no second question about a man
		# who chose to go home.
		"how": String(run.ending.how) if run.ending != null else "",
		# What the Crown got. Received and paid rather than the net alone,
		# because "you netted them nine hundred" and "you moved forty thousand
		# through their hands and kept nine hundred of it" are different facts
		# and the second is the one that stings.
		"received": _total(accounts, "received"),
		"paid": _total(accounts, "paid"),
		"net": accounts.net_position(),
	}

	# What the colony became. Read off the colony as it stands, since a town is
	# not an event — but every *change* to it was one, and the counts below come
	# from the record rather than from the towns' own memories.
	var towns := 0
	var people := 0
	var rebelling := 0
	if run.colony != null:
		for town in run.colony.in_order():
			towns += 1
			people += town.population()
			if town.rebelling:
				rebelling += 1
	out["towns"] = towns
	out["people"] = people
	out["towns_in_revolt"] = rebelling

	out["protests"] = log.of_type(TradeProtest.EVENT_DECLARED).size()
	out["rebellions"] = log.of_type(Rebellion.EVENT_DECLARED).size()
	out["returns"] = log.of_type(Rebellion.EVENT_RETURNED).size()
	out["famines"] = log.of_type(ConsumePhase.EVENT_FAMINE).size()
	out["settlers"] = _settlers(log)
	out["letters"] = log.of_type(TurnMachine.EVENT_POST_SENT).size()

	# 🔒 **The score belongs to the ending, not to this.** `Prestige` is settled
	# once when the run stops (#77) and the summary reports what it settled at —
	# recomputing here could disagree with the ending the save holds.
	if run.ending != null:
		out["score"] = run.ending.score
		out["net_gold"] = run.ending.net_gold
		out["optics_debt"] = run.ending.optics_debt
	return out


## How many people ever crossed the ocean to come here.
static func _settlers(log: EventLog) -> int:
	var total := 0
	for event in log.of_type(Immigration.EVENT_ARRIVED):
		total += int(event.payload.get("workers", 0)) + int(event.payload.get("experts", 0))
	return total


static func _total(accounts: CrownAccounts, field: String) -> float:
	var sum := 0.0
	for month in accounts.recorded():
		sum += float(accounts.months.get(month, {}).get(field, 0.0))
	return sum
