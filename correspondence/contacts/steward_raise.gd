class_name StewardRaise
extends RefCounted

## The Steward raises a duty over the PC's head (#452, `the-steward.md` §3;
## SPEC §10.2).
##
## > If your crown standing is lost **and** the steward's loyalty is low, he may
## > unilaterally raise taxes and inform you after the fact, ignoring your input.
##
## ## 🔒 Not compliance: will
##
## Nothing was ordered. He deliberates, and what he decides becomes an Intent
## the sim executes the month after (Seam C) — the same Intent a raise the PC
## ordered becomes, with a different origin.
##
## ## 🔒 The two conditions are a filter
##
## The spec locks them, so they gate the candidate before scoring rather than
## making it merely likely (`deliberation.md` §5). Standing lost **and** his
## regard in the low band, or *raise* is not on the table. Once it is, whether he
## takes it is his weight vector: his appetite for duties against his restraint.
##
## ## 🔒 The rate he has been advising
##
## He raises the rate his last push named, one step — a man finally doing what
## he has been saying for a year. **A Steward who has never pushed for a rate has
## none to raise**, and does not.
##
## ## Once in a while
##
## Not again while his last raise is still on its way, nor within
## `COOLDOWN_MONTHS` of it. A placeholder: §3 does not say how often, and a man
## who raised every month would be a ratchet rather than a decision.
##
## Phase 8, where will becomes Intent.

const STEWARD: StringName = &"steward"
const PUSH_LETTER: String = "steward.request_tax_rise"

const RAISE: StringName = &"raise"
const HOLD: StringName = &"hold"

## How long after one raise before he will make another. A placeholder.
const COOLDOWN_MONTHS: int = 12

const EVENT_RAISED: StringName = &"steward_raised_the_duty"

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


static func register_all() -> void:
	var kinds: Array[StringName] = [DecisionKind.STEWARD_RAISES]
	Deliberation.register_filter(OnlyWhenTheCrownIsLostAndHeIsSour.new(&"standing_lost_and_regard_low"), kinds)
	Deliberation.register_consideration(HisAppetiteForDuty.new(&"appetite_for_duty"), kinds)
	Deliberation.register_consideration(Restraint.new(&"restraint"), kinds)


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.INTENT or run == null or run.intents == null:
		return
	var steward := run.contact(STEWARD)
	if steward == null or steward.is_dead:
		return
	var resource := advised_rate(log, STEWARD)
	if resource.is_empty() or not may_raise_again(log, state.month):
		return
	if _a_raise_is_on_its_way():
		return

	var context := DeliberationContext.new(DecisionKind.STEWARD_RAISES, state, log)
	context.phase = WorldPhase.INTENT
	context.data = {
		"standing_lost": run.standing != null and run.standing.has_lost_confidence(),
		"loyalty": steward.loyalty(),
	}
	var decision := Deliberation.choose(steward, [Candidate.new(RAISE, {}), Candidate.new(HOLD, {})], context)
	if not decision.has_choice() or decision.chosen_id() != RAISE:
		return

	var letter := LetterContext.new(state, steward, &"")
	letter.month = state.month
	var order := ContentRegistry.run_effect("set_tax_rate", {
		"to": String(STEWARD), "resource": resource, "steps": 1,
	}, letter)
	if order == null:
		return
	run.intents.commit(Compliance.as_his_own_will(order, steward), log, state.month)
	log.emit(EVENT_RAISED, steward.id, state.month, {
		"steward": String(steward.id),
		"resource": resource,
		"from": TaxRates.rate_for(state, StringName(resource)),
		"to": float(order.get_param("rate", 0.0)),
	}, WorldPhase.INTENT)


## 🔒 **The rate his last push named** (§3), or empty if he never pushed.
static func advised_rate(log: EventLog, steward: StringName) -> String:
	if log == null:
		return ""
	var named := ""
	for entry in log.of_type(Director.EVENT_DISPATCHED):
		var sent: SimEvent = entry
		if sent.subject != steward or String(sent.payload.get("letter", "")) != PUSH_LETTER:
			continue
		named = String(sent.payload.get("params", {}).get("resource", ""))
	return named


## Not within `COOLDOWN_MONTHS` of his last raise.
static func may_raise_again(log: EventLog, month: int) -> bool:
	if log == null:
		return true
	for entry in log.of_type(EVENT_RAISED):
		if month - (entry as SimEvent).month < COOLDOWN_MONTHS:
			return false
	return true


func _a_raise_is_on_its_way() -> bool:
	for intent in run.intents.live():
		if intent.kind == M1Registrations.ORDER_SET_TAX_RATE and intent.source == STEWARD \
				and intent.origin == Intent.ORIGIN_WILL:
			return true
	return false


## 🔒 **Standing lost and his regard low, or *raise* is not on the table.**
class OnlyWhenTheCrownIsLostAndHeIsSour:
	extends DeliberationFilter

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != StewardRaise.RAISE:
			return true
		return bool(context.get_value("standing_lost", false)) \
			and Relationship.band_of(float(context.get_value("loyalty", 100.0))) == Relationship.LOW


## **His bias is permanent and in one direction** (§1): he prefers high duties.
class HisAppetiteForDuty:
	extends Consideration

	func score(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> float:
		return 1.0 if candidate.id == StewardRaise.RAISE else 0.0


## **What regard he has left for the PC** holds his hand, as far as it goes.
class Restraint:
	extends Consideration

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if candidate.id != StewardRaise.HOLD:
			return 0.0
		return clampf(float(context.get_value("loyalty", 0.0)) / Relationship.MAX_LOYALTY, 0.0, 1.0)
