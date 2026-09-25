class_name CrownTroops
extends RefCounted

## The Marshal's troops (#420, `docs/mechanics/the-marshal.md` §2, §3, §6;
## `policy.md` §5).
##
## ## 🔒 A standing policy, and nothing else puts them here
##
## Crown troops come as **a policy in the ordinary sense of `policy.md`**, held
## by the Marshal: a monthly charge, a split, the 3× asymmetry on non-payment and
## the renegotiation when the Crown stops paying are all `PolicyBook`'s. This adds
## only what the policy *does*: each standing troops policy has its company in the
## colony, and a company whose policy no longer stands sails home.
##
## Two knobs (§2): **strength** — none, a garrison, a force, an army — and
## **posture**, which is the standing order the company lands under.
##
## ## 🔒 Never the colony's burden (§3)
##
## Supported abroad: **victualled by the Crown**, never from a town's stores. An
## unpaid month is not an unsupplied one — the Marshal covers it, and his regard
## falls for it through the ordinary drain.
##
## ## 🔒 He withdraws, he never escalates (§6)
##
## Nothing here lands a man the policy did not ask for. The one thing that happens
## without the PC is the leaving: when the policy lapses — the Marshal has written
## first, as `policy.md` §5 requires — the soldiers sail, and their going is one
## event naming how many went.
##
## Phase 1, with everything else that arrives by sea.

## The man who holds the troops policy (§2).
const MARSHAL: StringName = &"marshal"

const EVENT_LANDED: StringName = &"crown_troops_landed"
const EVENT_SAILED: StringName = &"crown_troops_sailed"

# --- Strength (§2) --------------------------------------------------------------

const NONE: StringName = &"none"
const A_GARRISON: StringName = &"a_garrison"
const A_FORCE: StringName = &"a_force"
const AN_ARMY: StringName = &"an_army"

## Men per setting. Placeholders against a duke's landing of 45,000
## (`Muster.LANDS_WITH`); the Marshal's figures are tuning (§10).
const MEN: Dictionary = {
	"none": 0,
	"a_garrison": 10_000,
	"a_force": 25_000,
	"an_army": 50_000,
}

# --- Posture (§2), and the order each one is -------------------------------------

## Defensive: they sit where the people are.
const HOLD_THE_TOWNS: StringName = &"hold_the_towns"
## They meet rivals and war parties before those reach a town.
const PATROL_THE_COUNTRY: StringName = &"patrol_the_country"
## 🔒 **The only thing that will fight rebels at all** (§12.6), so its foe is only
## ever a rebel.
const PUT_DOWN_THE_REBELLION: StringName = &"put_down_the_rebellion"

const ORDER_FOR: Dictionary = {
	"hold_the_towns": StandingOrder.DEFEND_THE_TOWN,
	"patrol_the_country": StandingOrder.GUARD_THE_BORDER,
	"put_down_the_rebellion": StandingOrder.MARCH_ON_A_FOE,
}

## What a landed company carries per thousand men. **A European army arrives
## equipped**, in the proportions a duke's does (`Muster.LANDS_ARMED`).
const GUNS_PER_THOUSAND: float = 1.0
const TOOLS_PER_THOUSAND: float = 0.45

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


## Whether a letter may ask for this strength: one of §2's, and not *none* — a
## policy for nobody would be charged every month and land no one.
static func is_a_strength(value: StringName) -> bool:
	return MEN.has(String(value)) and value != NONE


static func is_a_posture(value: StringName) -> bool:
	return ORDER_FOR.has(String(value))


static func men_for(strength: StringName) -> int:
	return int(MEN.get(String(strength), 0))


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.ARRIVALS or run == null or run.policies == null or run.companies == null:
		return
	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	# **Leaving before landing**, so a policy replaced in one month does not have
	# two companies ashore at once.
	_sail_home(context)
	_land(context)


## Every standing troops policy has its company ashore.
func _land(context: ColonyContext) -> void:
	for policy in run.policies.active():
		if policy.effect != PolicyEffects.CROWN_TROOPS or _its_company(policy.id) != null:
			continue
		var men := men_for(StringName(policy.params.get("strength", "")))
		var ashore := _where_they_land()
		if men <= 0 or ashore == null:
			continue
		var posture := StringName(policy.params.get("posture", String(HOLD_THE_TOWNS)))
		var thousands := float(men) / float(Population.THOUSAND)
		var company := context.companies.raise_company(
			Company.CROWN, men,
			{"guns": thousands * GUNS_PER_THOUSAND, "tools": thousands * TOOLS_PER_THOUSAND},
			Company.SUPPORTED_ABROAD, ashore.at, context,
			StringName(ORDER_FOR.get(String(posture), StandingOrder.DEFEND_THE_TOWN)),
			Company.COMMANDED)
		company.raised_by = policy.enactor
		company.raised_under = posture
		company.policy = policy.id
		# **Troops granted come with one** (§9), from the Marshal's pool.
		Commanders.take_command(company, null, run, context)
		context.log.emit(EVENT_LANDED, policy.enactor, context.state.month, {
			"policy": String(policy.id),
			"company": String(company.id),
			"men": men,
			"posture": String(posture),
			"town": String(ashore.id),
			"at": [ashore.at.x, ashore.at.y],
		}, WorldPhase.ARRIVALS)


## Every Crown company whose policy no longer stands goes home: **one event per
## policy**, with the men who went.
func _sail_home(context: ColonyContext) -> void:
	var standing: Dictionary = {}
	for policy in run.policies.active():
		standing[String(policy.id)] = true
	var going: Dictionary = {}
	var order: Array = []
	for entry in context.companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty() or String(company.policy).is_empty() or standing.has(String(company.policy)):
			continue
		var key := String(company.policy)
		if not going.has(key):
			going[key] = {"men": 0, "companies": [], "by": String(company.raised_by)}
			order.append(key)
		going[key]["men"] = int(going[key]["men"]) + company.size
		going[key]["companies"].append(String(company.id))
		# **They leave; they never linger as mouths** (§3). Their arms go with
		# them, and nothing of theirs lands in a town.
		company.arms = {}
		company.size = 0
	for key in order:
		context.log.emit(EVENT_SAILED, StringName(going[key]["by"]), context.state.month, {
			"policy": key,
			"men": int(going[key]["men"]),
			"companies": going[key]["companies"],
		}, WorldPhase.ARRIVALS)
	context.companies.bury_the_dead()


func _its_company(policy_id: StringName) -> Company:
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.policy == policy_id:
			return company
	return null


## **Where the people are** (§2): the most populous town still loyal, ties to the
## first in id order. A colony with no loyal town has nowhere to put them.
func _where_they_land() -> Town:
	if run.colony == null:
		return null
	var chosen: Town = null
	for town in run.colony.in_order():
		if town.rebelling:
			continue
		if chosen == null or town.population() > chosen.population():
			chosen = town
	return chosen
