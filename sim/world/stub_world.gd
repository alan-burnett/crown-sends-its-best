class_name StubWorld
extends RefCounted

## A stand-in world for M1, so the correspondence layer can be built and played
## before the real simulation exists (M2).
##
## **Its only job is to produce enough month-to-month variety that letters
## genuinely differ.** If it were static the playtest would test nothing — the
## Author would read the same four letters twelve times and correctly conclude
## the game is dull. So this is not "hold some numbers": the values push on each
## other, a campaign runs for a while and then stops, convoys are occasionally
## lost, and the situation gets better and worse at different rates.
##
## It emits **real events and a real diff**, in the same phases the real sim
## uses, so the correspondence layer cannot tell it is a stub and M2 can swap in
## behind the seam.

# --- The values the M1 letters talk about ----------------------------------

const WAR: String = "crown_war_intensity"
const REVENUE: String = "colony_revenue"
const SUPPLY: String = "supply_situation"
const FOOD: String = "food_security"

## Not a value the letters quote, but the thing that makes the war move in runs
## rather than wandering: a campaign begins, lasts some months, and ends.
const CAMPAIGN_MONTHS_LEFT: String = "crown_campaign_months_left"

const EVENT_WAR_MOVED: StringName = &"crown_war_moved"
const EVENT_CAMPAIGN_BEGAN: StringName = &"crown_campaign_began"
const EVENT_CAMPAIGN_ENDED: StringName = &"crown_campaign_ended"
const EVENT_COLONY_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"

# --- Tuning ----------------------------------------------------------------
#
# Every number here is a tuning value. They exist to make twelve turns feel
# different, not to be balanced; M2 replaces the whole file.

const WAR_MIN: float = 0.0
const WAR_MAX: float = 100.0
const CAMPAIGN_CHANCE: float = 0.28
const CAMPAIGN_MIN_MONTHS: int = 2
const CAMPAIGN_MAX_MONTHS: int = 5
const CAMPAIGN_CLIMB: float = 9.0
const WAR_COOLING: float = 4.5
const WAR_NOISE: float = 3.0

## What the war takes out of the colony's supply each month, per point of war.
const WAR_DRAIN: float = 0.09
const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

const REVENUE_FROM_SUPPLY: float = 14.0
const REVENUE_NOISE: float = 90.0
const REVENUE_SMOOTHING: float = 0.45

const FOOD_FROM_SUPPLY: float = 0.022
const FOOD_NOISE: float = 0.12


## The state a run starts from.
static func initial_state() -> WorldState:
	return WorldState.new(0, {
		WAR: 35.0,
		REVENUE: 900.0,
		SUPPLY: 62.0,
		FOOD: 1.1,
		CAMPAIGN_MONTHS_LEFT: 0,
	})


## Called once per phase by `WorldMonth`.
##
## Only two phases do anything here. The Crown's month moves the war and the
## colony's month settles what that cost — the order matters, because the colony
## is reckoning with the war as it stands this month, not last month's.
func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	match phase:
		WorldPhase.CROWNS_MONTH:
			_advance_war(state, log, streams.stream("sim"))
		WorldPhase.COLONY_MONTH:
			_advance_colony(state, log, streams.stream("sim"))


# --- The Crown's month -----------------------------------------------------

func _advance_war(state: WorldState, log: EventLog, rng: RandomNumberGenerator) -> void:
	var war := float(state.get_value(WAR, 0.0))
	var months_left := int(state.get_value(CAMPAIGN_MONTHS_LEFT, 0))

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
		WAR: war,
		CAMPAIGN_MONTHS_LEFT: months_left,
	}, WorldPhase.CROWNS_MONTH)


# --- The colony's month ----------------------------------------------------

func _advance_colony(state: WorldState, log: EventLog, rng: RandomNumberGenerator) -> void:
	var war := float(state.get_value(WAR, 0.0))
	var supply := float(state.get_value(SUPPLY, 0.0))
	var revenue := float(state.get_value(REVENUE, 0.0))

	# The war pulls supply down; the colony pulls it back up. Which of the two
	# wins this month is what the Marshal and the Steward end up arguing about.
	supply += SUPPLY_RECOVERY - war * WAR_DRAIN
	supply += rng.randf_range(-SUPPLY_NOISE, SUPPLY_NOISE)

	if rng.randf() < CONVOY_LOSS_CHANCE:
		supply -= CONVOY_LOSS
		log.emit(EVENT_CONVOY_LOST, &"colony", state.month, {
			"supply_lost": CONVOY_LOSS,
		}, WorldPhase.COLONY_MONTH)

	supply = clampf(supply, 0.0, 100.0)

	# Revenue follows supply but lags it, so a good month does not read as a
	# reversal and the Steward has something to be wrong about.
	var target := supply * REVENUE_FROM_SUPPLY + rng.randf_range(-REVENUE_NOISE, REVENUE_NOISE)
	revenue = lerpf(revenue, maxf(target, 0.0), REVENUE_SMOOTHING)

	var food := clampf(supply * FOOD_FROM_SUPPLY + rng.randf_range(-FOOD_NOISE, FOOD_NOISE), 0.0, 3.0)

	state.apply(log, EVENT_COLONY_SETTLED, &"colony", {
		SUPPLY: supply,
		REVENUE: revenue,
		FOOD: food,
	}, WorldPhase.COLONY_MONTH)


# --- Measures --------------------------------------------------------------

## What the letters may judge. The raw values a `LetterContext` carries.
static func measures(state: WorldState) -> Dictionary:
	return {
		WAR: float(state.get_value(WAR, 0.0)),
		REVENUE: float(state.get_value(REVENUE, 0.0)),
		SUPPLY: float(state.get_value(SUPPLY, 0.0)),
		FOOD: float(state.get_value(FOOD, 0.0)),
	}
