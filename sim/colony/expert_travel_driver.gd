class_name ExpertTravelDriver
extends RefCounted

## The scholar arranging travel, once a month (#280,
## `docs/mechanics/institutional-contacts.md` §3).
##
## > *I would like our experts to spread knowledge around the colony. We just
## > need a little gold for their travel expenses. I will arrange all the travel
## > and send them where they will be most useful. I suggest you build libraries
## > wherever they go so they can keep up on their skills.*
##
## ## 🔒 Phase 7, and not inside the colony month
##
## SPEC §11.3 locks that **every town completes a phase before any town begins
## the next**, so that no town benefits from being simulated first. A transfer
## moves a man *between* towns, so doing it inside a per-town phase would break
## exactly that: whether a town gained an expert would depend on whether it
## sorted after the one that gave him up.
##
## So it runs in Reckoning, after the whole colony month has finished and before
## the next one begins — which is also when it reads truest, because the month's
## yields and stores are settled and *most useful* is a judgement about the town
## as it now stands.
##
## ## 🔒 It reads a world value, never the policy book
##
## `PolicyEffects.pressure` writes the flag while the policy runs and clears it
## the month it lapses, exactly as every other policy presses. Nothing here knows
## what a policy is, so a policy that ended stops arranging travel without this
## file being told.
##
## ## Every town with a scholar, not one
##
## The letter says *I suggest you build libraries wherever they go*, so a second
## library makes the arrangement better rather than redundant. One policy, one
## charge, and the reach grows with what the colony has built.

const EVENT_ARRANGED: StringName = &"expert_travel_arranged"

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(
	phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams
) -> void:
	if phase != WorldPhase.RECKONING or run == null or run.colony == null:
		return
	if float(state.get_value(PolicyEffects.TRAVELLING_EXPERTS_KEY, 0.0)) <= 0.0:
		return

	var context := _context(state, log)
	var moved := 0
	for town in run.colony.in_order():
		if _scholar_in(town) == null:
			continue
		moved += _send_from(town, context)

	if moved > 0:
		log.emit(EVENT_ARRANGED, &"colony", state.month, {
			"moved": moved,
		}, WorldPhase.RECKONING)


## The man who arranges it, if this town has one.
##
## **The building's resident**, found the way everything else finds one — so a
## town whose library burned down stops arranging travel the same month.
func _scholar_in(town: Town) -> Contact:
	var id := ContactRoster.resident_id(town, "scholar")
	var scholar: Contact = run.contacts.get(String(id), null)
	return null if scholar == null or scholar.is_dead else scholar


## Send this town's spare experts wherever they would do more good.
##
## 🔒 **More than one, never the last man** — `spare_kinds` holds that, so a town
## that holds the colony's only weaver keeps him however badly somebody else
## wants one.
func _send_from(town: Town, context: ColonyContext) -> int:
	var sent := 0
	for kind in ExpertTransfer.spare_kinds(town):
		var resource := StringName(kind)
		var better := ExpertTransfer.most_useful_elsewhere(town, resource, context)
		if better == null:
			continue
		if ExpertTransfer.move(town, better, resource, context):
			sent += 1
	return sent


## What `Experts.worth_of` needs to judge a town, built from the run.
##
## **Assembled here rather than carried**, because the colony month's own context
## is gone by phase 7 and a stale one would judge the towns as they were before
## the month they have just had.
func _context(state: WorldState, log: EventLog) -> ColonyContext:
	var context := ColonyContext.new(state, log, run.streams, run.map)
	context.colony = run.colony
	context.contacts = run.contacts
	context.territory = run.territory_now()
	context.run_seed = run.run_seed
	return context
