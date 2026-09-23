class_name TaxWaiver
extends RefCounted

## A duty set aside for a stated number of months, which reverts on its own
## (#278, `docs/mechanics/institutional-contacts.md` §3).
##
## Nothing in SPEC §10.2 could express this. Rates there are **standing** — a
## base plus per-resource overrides, colony-wide, with nothing that expires — so
## the clergy's two asks needed a shape the tax system did not have.
##
## ## 🔒 It is the shortage's shape, deliberately
##
## `CrownPrices`' shortage is a per-resource world value that decays over a
## season and is advanced in the Crown's month. This is the same thing counted in
## months rather than lifted and eased, and for the same reasons: it **serialises
## with the save**, it **appears in the world diff** when it changes, and there is
## no second structure that could disagree with the state about what is running.
##
## ## 🔒 Nothing is scheduled in advance
##
## §3, the Author's second ruling: **the waiver begins the month the PC agrees.**
## The holy day used to be announced three months out, which would have wanted a
## scheduled-future-event mechanism — a system with no owner, standing up for one
## caller. There is nothing to schedule here, and the second thing that genuinely
## needs a scheduler can generalise from it.
##
## ## 🔒 Two shapes, one mechanism
##
## | | Waives | For |
## | :--- | :--- | :--- |
## | **A festival** | one resource | about three months |
## | **A holy day** | everything | the one month |
##
## The holy day is not a loop over every resource. It is one key — `ALL` — so a
## resource added to the catalogue next year is covered without anybody
## remembering to cover it, and so ending one is ending one thing.
##
## ## 🔒 Colony-wide, because there is no other kind of rate
##
## §10.2 locks that there are no per-town rates, and this changes nothing about
## that: a priest asking relief for his own poor **is asking the whole colony to
## go without the duty**, and the letters say so rather than pretending otherwise.

## Where a waiver's remaining months are kept, one world value per resource.
const PREFIX: String = "tax_waived."

## 🔒 **The holy day's key**, and the reason it is a key rather than a loop.
##
## A resource id may not collide with it — `*` is not a legal id anywhere in the
## catalogue, which is what makes it safe as a name for *everything*.
const ALL: StringName = &"*"

const EVENT_GRANTED: StringName = &"duty_waived"
const EVENT_ENDED: StringName = &"duty_resumed"

## What each ask is worth, in months. Tuning, and §5 owns both.
##
## **A festival outlasts a holy day by a season**, which is the whole difference
## between them: one is a celebration of a good year in one trade, the other is a
## single month in which nobody works.
const FESTIVAL_MONTHS: int = 3
const HOLY_DAY_MONTHS: int = 1


static func key_for(resource: StringName) -> String:
	return PREFIX + String(resource)


## Months still to run on this resource's own waiver, or on the holy day.
static func months_left(state: WorldState, resource: StringName) -> int:
	if state == null:
		return 0
	return maxi(0, int(state.get_value(key_for(resource), 0)))


## Whether a duty is presently set aside — by its own waiver or by a holy day.
##
## 🔒 **This does not know about trade protests**, and must not. Whether a
## protested resource is exempt is a question about the colony, which a
## `WorldState` cannot answer; `ColonyContext.tax_rate` asks it, because that is
## the object which knows both.
static func running(state: WorldState, resource: StringName) -> bool:
	return months_left(state, ALL) > 0 or months_left(state, resource) > 0


## Anything presently waived, sorted. `*` in the list is a holy day.
static func all_running(state: WorldState) -> PackedStringArray:
	var out := PackedStringArray()
	if state == null:
		return out
	for key in state.value_keys():
		if not String(key).begins_with(PREFIX):
			continue
		if int(state.get_value(key, 0)) <= 0:
			continue
		out.append(String(key).substr(PREFIX.length()))
	out.sort()
	return out


## Set a duty aside (Seam A).
##
## **The longer of the two wins** where one is already running, rather than the
## later one replacing it. A priest granted a second festival in the same trade
## is not being told the first one is over.
static func grant(
	state: WorldState,
	log: EventLog,
	resource: StringName,
	months: int,
	phase: StringName = WorldPhase.RECKONING,
) -> void:
	if state == null or months <= 0:
		return
	var left := maxi(months_left(state, resource), months)
	state.apply(log, EVENT_GRANTED, &"crown", {key_for(resource): left}, phase)


## Phase 5: take a month off everything running, and end what has run out.
##
## **In the Crown's month beside the shortage**, which is where a thing that
## counts down the Crown's own arrangements belongs — and it is before the
## Colony Month of the month after, so a waiver granted in March covers March
## and is gone by the time June's trade is priced.
static func advance(state: WorldState, log: EventLog) -> void:
	if state == null:
		return
	for id in all_running(state):
		var left := months_left(state, StringName(id)) - 1
		if left > 0:
			state.apply(log, EVENT_GRANTED, &"crown",
				{key_for(StringName(id)): left}, WorldPhase.CROWNS_MONTH)
			continue
		# 🔒 **Said out loud when it ends.** A duty coming back is a rise the
		# towns will feel (`trade-protests.md` §3), and a rise nobody announced
		# is the shape of a colony being surprised by its own government.
		state.apply(log, EVENT_ENDED, &"crown",
			{key_for(StringName(id)): 0}, WorldPhase.CROWNS_MONTH)
