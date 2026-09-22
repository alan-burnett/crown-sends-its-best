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
##
## ## The bar moves here too
##
## From year four the Crown leans harder, along one axis a year
## (`crown-demands.md` §§1, 7). It belongs in this phase because it is the
## Crown's own business rather than the colony's: nothing the player did that
## month causes it, and nothing in the colony can prevent it.
##
## It runs **before** standing is judged in phase 6, so the month the bar moves
## is judged against the bar as it now stands rather than as it was.

const EVENT_WAR_MOVED: StringName = &"crown_war_moved"
const EVENT_CAMPAIGN_BEGAN: StringName = &"crown_campaign_began"
const EVENT_CAMPAIGN_ENDED: StringName = &"crown_campaign_ended"

const EVENT_EMIGRATION: StringName = &"crown_emigration_changed"

# --- Tuning ----------------------------------------------------------------

## What one year of the Crown's decline adds to the flow of people leaving it.
##
## Against `Immigration.FLOW_BASE` of 1.0, so a run that reaches its eighth year
## is drawing on something like twice the emigration it began with. Tuning.
const FLOW_PER_DECLINE: float = 0.22

const WAR_MIN: float = 0.0
const WAR_MAX: float = 100.0
const CAMPAIGN_CHANCE: float = 0.28
const CAMPAIGN_MIN_MONTHS: int = 2
const CAMPAIGN_MAX_MONTHS: int = 5
const CAMPAIGN_CLIMB: float = 9.0
const WAR_COOLING: float = 4.5
const WAR_NOISE: float = 3.0


## The run's growth state. Set by the turn machine; absent in the tests that
## only care about the war, which is why this is checked rather than assumed.
var growth: DemandGrowth = null

## What the Crown is asking for. Set by the turn machine.
var demands: DemandBook = null

## The colony, and the men the PC writes to. Set by the turn machine, and absent
## in the tests that only care about the war — which is why both are checked.
var colony: Colony = null
var contacts: Dictionary = {}


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.CROWNS_MONTH:
		return
	if growth != null:
		growth.advance(state.year_index(), streams, log, state.month)
		if demands != null:
			demands.advance(state.month, growth, streams, log)
		_settle_emigration(state, log)
	_please_the_provost(state, log)
	_advance_war(state, log, streams.stream("sim"))
	# 🔒 **Beside the war and not in a driver of its own** (#141). Both are the
	# Crown's own circumstances reaching the colony's prices, both move in phase 5,
	# and both draw from the same stream — so one seed shorts the same harvest in
	# the same month of the same campaign.
	CrownPrices.advance(state, log, streams.stream("sim"))


## A learned colony warms the Provost, whoever paid for the learning (#174).
##
## In the Crown's Month because he is a Crown officer and this is his side of the
## ocean's business. **Nothing about it is a payment**: the gold half of him is
## `policy.md`'s and runs through the ordinary drain, and this is the other half.
func _please_the_provost(state: WorldState, log: EventLog) -> void:
	if colony == null or contacts.is_empty():
		return
	var him: Contact = contacts.get(String(Provost.ID))
	if him == null:
		return
	var context := ColonyContext.new(state, log, null, null)
	context.colony = colony
	Provost.settle_regard(him, colony, context)


## How many people are leaving home (#171, `immigration.md` §5).
##
## 🔒 **Derived from the same decline that drives the demands**, not from a
## second schedule of its own. The Crown's obligations growing and its people
## leaving are one fact about the Crown, and two independent curves would
## eventually disagree about how bad things have got at home.
##
## So it reads `DemandGrowth`'s own history — one draw a year from year four,
## which *is* the measure of how far past its peak the Crown is — and nothing
## here has a calendar.
##
## The consequence is the point: **immigration rises precisely as demands grow
## and the PC can least afford to feed the arrivals.** It is also the mechanical
## half of §9, which is the most important claim in that document —
## immigration feeds population feeds development feeds rebel sentiment — so
## this is what makes that pressure arrive **on its own** rather than only when
## the PC invites it by running a pleasant colony.
func _settle_emigration(state: WorldState, log: EventLog) -> void:
	var declined := float(growth.history.size())
	var flow := declined * FLOW_PER_DECLINE
	if absf(flow - float(state.get_value(Immigration.FLOW_KEY, 0.0))) < 0.0001:
		return
	state.apply(log, EVENT_EMIGRATION, &"crown", {Immigration.FLOW_KEY: flow},
		WorldPhase.CROWNS_MONTH)


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
