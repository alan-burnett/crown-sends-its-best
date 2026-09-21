class_name GovernorDriver
extends RefCounted

## **World phase 8 — Intent.** Each governor commits to what his town is for
## (`docs/mechanics/governor-objectives.md` §2).
##
## The cycle, across one month:
##
## | World phase | What happens |
## | :--- | :--- |
## | 1 Arrivals | the post reaches the colony |
## | 4 Colony Month, step 9 Settle | the town reconsiders its objective |
## | 7 Reckoning | the governor reads the post; compliance sets his posture |
## | **8 Intent** | **the governor commits to an intent** |
## | 9 Dispatch | he writes, announcing what he means to do |
##
## **An intent set in month N is acted on by the objective chosen in month N+1's
## Settle**, because Settle is phase 4 and this is phase 8. One month, the same
## separation as everything else in the loop, and the player sees the governor
## say what he means to do before he has done any of it.
##
## The choice goes through the deliberation kernel and always emits its trace, so
## the reason in his letter is the reason in the log and a letter cannot
## misrepresent why something was done (SPEC §9.1).

const EVENT_INTENT_SET: StringName = &"governor_intent"

var colony: Colony = null
var map: WorldMap = null

## Town id -> the governor who speaks for it, as a `DeliberationActor`. Supplied
## by the run, because loyalty lives in the correspondence layer and a `Contact`
## may not be reached from `sim/`.
var actors: Dictionary = {}

## Supplied by the territory driver, which runs in phase 3.
var territory_driver: TerritoryDriver = null

## The peoples already here (#204). A governor weighs how much of his own ground
## is somebody else's, and cannot intend to drive off people he has never met.
var natives: Tribes = null


func _init(p_colony: Colony = null, p_map: WorldMap = null) -> void:
	colony = p_colony
	map = p_map


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.INTENT or colony == null:
		return

	var territory: Territory = null
	if territory_driver != null:
		territory = territory_driver.territory

	# In id order. Which governor decides first cannot matter — each reads the
	# world, and none of them reads another's decision.
	for town in colony.in_order():
		_decide(town, state, log, streams, territory)


func _decide(
	town: Town,
	state: WorldState,
	log: EventLog,
	streams: RngStreams,
	territory: Territory,
) -> void:
	var actor: DeliberationActor = actors.get(String(town.governor_id))
	if actor == null:
		# A town with nobody to speak for it keeps whatever intent it had. It is
		# not a crash and it is not a silent default to the first in the list.
		return

	var context := DeliberationContext.new(DecisionKind.GOVERNOR_INTENT, state, log)
	context.phase = WorldPhase.INTENT
	context.rng = streams.contact_stream(String(town.governor_id))
	context.data = {
		"town": town,
		"colony": colony,
		"map": map,
		"territory": territory,
		"natives": natives,
		"mandate": String(state.get_value(WorldValues.MANDATE, "")),
		"urged": String(town.urged_intent),
		"urged_month": town.urged_month,
	}

	var candidates: Array = []
	for intent in GovernorIntent.IN_ORDER:
		candidates.append(Candidate.new(intent))

	var decision := Deliberation.choose(actor, candidates, context)
	if not decision.has_choice():
		return

	var chosen := decision.chosen_id()
	if chosen == town.intent:
		return

	var held := town.intent
	town.intent = chosen
	town.intent_since = state.month

	log.emit(EVENT_INTENT_SET, town.governor_id, state.month, {
		"town": String(town.id),
		"governor": String(town.governor_id),
		"intent": String(chosen),
		"was": String(held),
		"crisis": GovernorIntent.is_crisis(chosen),
	}, WorldPhase.INTENT)
