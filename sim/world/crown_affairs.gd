class_name CrownAffairs
extends RefCounted

## The other side of the ocean, in **phase 5, the Crown's Month**.
##
## The Crown's wars elsewhere advance, run by the Marshal, and they reach the
## colony through troop availability, demands and treaties (SPEC §12.4). This is
## still a stand-in — there is no real war simulation and M2 does not owe one —
## but it is a stand-in for **the Crown**, not for the colony, and the colony
## month does not replace it. Crown standing (M3) builds on this side.
##
## A campaign begins, runs for some months, and ends. That is what keeps the war
## moving in runs rather than wandering, and what gives the Marshal something to
## write about that is not the same letter twice.

const EVENT_WAR_MOVED: StringName = &"crown_war_moved"
const EVENT_CAMPAIGN_BEGAN: StringName = &"crown_campaign_began"
const EVENT_CAMPAIGN_ENDED: StringName = &"crown_campaign_ended"

# --- Tuning ----------------------------------------------------------------

const WAR_MIN: float = 0.0
const WAR_MAX: float = 100.0
const CAMPAIGN_CHANCE: float = 0.28
const CAMPAIGN_MIN_MONTHS: int = 2
const CAMPAIGN_MAX_MONTHS: int = 5
const CAMPAIGN_CLIMB: float = 9.0
const WAR_COOLING: float = 4.5
const WAR_NOISE: float = 3.0


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.CROWNS_MONTH:
		return
	_advance_war(state, log, streams.stream("sim"))


func _advance_war(state: WorldState, log: EventLog, rng: RandomNumberGenerator) -> void:
	var war := float(state.get_value(WorldValues.WAR, 0.0))
	var months_left := int(state.get_value(WorldValues.CAMPAIGN_MONTHS_LEFT, 0))

	if months_left > 0:
		months_left -= 1
		war += CAMPAIGN_CLIMB
		if months_left == 0:
			log.emit(EVENT_CAMPAIGN_ENDED, &"crown", state.month, {"war": war}, WorldPhase.CROWNS_MONTH)
	else:
		# Between campaigns the war cools, but never all the way: the Crown is at
		# the peak of its power and always fighting somebody.
		war -= WAR_COOLING
		if rng.randf() < CAMPAIGN_CHANCE:
			months_left = rng.randi_range(CAMPAIGN_MIN_MONTHS, CAMPAIGN_MAX_MONTHS)
			log.emit(EVENT_CAMPAIGN_BEGAN, &"crown", state.month, {
				"months": months_left,
			}, WorldPhase.CROWNS_MONTH)

	war += rng.randf_range(-WAR_NOISE, WAR_NOISE)
	war = clampf(war, WAR_MIN, WAR_MAX)

	state.apply(log, EVENT_WAR_MOVED, &"crown", {
		WorldValues.WAR: war,
		WorldValues.CAMPAIGN_MONTHS_LEFT: months_left,
	}, WorldPhase.CROWNS_MONTH)
