class_name ProvostDriver
extends RefCounted

## The Provost presses a town toward learning (#401, `governor-agendas.md` §2,
## §13, `governor-objectives.md` §4, `the-provost.md`).
##
## ## 🔒 He urges, as the PC can, and names no building
##
## At **low regard**, with a town able to build a library and none in the colony,
## he argues its governor toward **education**. It is the lever the PC pulls,
## from a different hand — Seam C's *same code path, different origins*. His will
## becomes an Intent; the month after, it lands as an urging **in his name**
## (#405), beside the PC's and erasing nothing; the governor re-deliberates, and
## the menu walk picks whatever serves learning (#429). **Nothing here touches an
## objective** (SPEC §8.5), so there is no exception to the lock at all.
##
## ## 🔒 Once, until it has faded
##
## He does not press again while an urging of his still stands in any town, or
## while one is on its way. Pressing afresh every month would keep it fresh for
## ever, and a governor argued at once is a story; one argued at monthly is a
## clerk with a grievance.
##
## ## Which town
##
## The three conditions are the ticket's, and all three are locks — filters, not
## weights — so nothing is left for the kernel to score. Of the towns that could
## build one, **the largest**: the one whose want of schooling is most visible
## from home. Ties go to the town first in id order.

## What he presses for, and the building whose absence stirs him.
const LIBRARY: StringName = &"library"

## 🔒 **How hard** (#401 §2): the Provost has acted, so it pulls hard — as hard
## as the PC's most desperate letter. A factor on the half-life, exactly as a
## tone is (`Urging.strength`). Tuning.
const PRESSES_WITH: float = 1.5

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.INTENT or run == null:
		return
	var town := pressed(state, log, streams)
	if town == null:
		return
	var intent := Intent.new(
		&"", UrgeIntentExecutor.KIND, Provost.ID, town.governor_id, 1, {
			"intent": String(GovernorIntent.EDUCATION),
			UrgeIntentExecutor.AUTHOR: String(Provost.ID),
			UrgeIntentExecutor.TOWN: String(town.id),
			UrgeIntentExecutor.STRENGTH: PRESSES_WITH,
		})
	# **His own will**, not an Order: nobody wrote to him.
	intent.origin = Intent.ORIGIN_WILL
	run.intents.commit(intent, log, state.month)


## The town he presses this month, or null.
func pressed(state: WorldState, log: EventLog, streams: RngStreams) -> Town:
	var him := run.contact(Provost.ID)
	if him == null or him.is_dead or him.relationship == null:
		return null
	# 🔒 **Only at low regard.** A man who thinks well of the PC writes to him
	# about the schools; one who does not goes round him.
	if Relationship.band_of(him.loyalty()) != Relationship.LOW:
		return null
	if run.colony == null or _a_library_stands() or _he_is_already_heard(state.month):
		return null

	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony
	context.contacts = run.contacts
	context.territory = run.territory_now()
	context.run_seed = run.run_seed

	var chosen: Town = null
	for town in run.colony.in_order():
		# A town with nobody to argue at, or one that has declared against the
		# Crown, has no governor who would hear a Crown officer out.
		if String(town.governor_id).is_empty() or town.rebelling:
			continue
		if not AgendaMenu.building_is_takeable(LIBRARY, town, context):
			continue
		if chosen == null or town.population() > chosen.population():
			chosen = town
	return chosen


## 🔒 **None in the colony**: one library anywhere and he has nothing to sneer at.
func _a_library_stands() -> bool:
	for town in run.colony.in_order():
		if town.has_building(LIBRARY):
			return true
	return false


## Whether an urging of his still stands anywhere, or one is on its way.
func _he_is_already_heard(month: int) -> bool:
	for intent in run.intents.live_for_source(Provost.ID):
		if intent.kind == UrgeIntentExecutor.KIND:
			return true
	for town in run.colony.in_order():
		var his := town.urging_by(Provost.ID)
		if his != null and his.pull(month, IntentConsiderations.URGING_HALF_LIFE) \
				>= IntentConsiderations.LEARNING_STANDS:
			return true
	return false
