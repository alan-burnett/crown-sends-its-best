class_name RunEndCheck
extends RefCounted

## Whether the run has ended badly (#267, `docs/mechanics/endings.md` §1, §4;
## SPEC §13.1).
##
## **The game had no way to lose.** Voluntary retirement shipped in M3, so a
## player could leave, and phase 6 — named *Run-end check* since the world month
## was written — did nothing at all.
##
## ## 🔒 Two endings, and they are not the same shape
##
## **Colony Overrun is one test**: the population of the colony **and all its
## expeditions** is zero. Not standing, not troops, not the Marshal. A full
## treasury and Crown troops standing on an empty map buy nothing, because no
## immigration is coming to a colony that no longer exists.
##
## **An expedition in the field keeps the run alive.** A colony whose last town
## falls while settlers are still crossing the map has not ended — it has one
## chance left, walking.
##
## **A rebel town's people are still the colony's people.** §13.1 counts every
## town the colony holds, *loyal or rebel*, so a colony entirely in revolt is
## populous and is not this ending at all.
##
## **Independence is four conditions, together**: no loyal town, standing lost,
## no Crown troops in the colony, and the Marshal will send no more. §13.1's
## undefined clause — *the Crown refuses to send more troops to put it down* — is
## what conditions 2, 3 and 4 mean between them.
##
## ## 🔒 At most one ending, and Overrun is asked first
##
## A colony with nobody left in it has no loyal town either, so both would
## otherwise fire on the same month. **There is nothing left to save** beats
## **they have taken it from us**, because the second describes people who are
## still there.


## Whether the run has ended, and why. Empty while it has not.
##
## Asked every month in phase 6 and answering at most once, which is what keeps
## the two endings from racing.
static func reason_for(
	colony: Colony,
	parties: Array,
	companies: Companies,
	standing: CrownStanding,
	marshal: Contact,
	state: WorldState,
) -> StringName:
	if is_overrun(colony, parties):
		return OVERRUN
	if is_independent(colony, companies, standing, marshal, state):
		return INDEPENDENCE
	return &""


## The two ways a run is lost. Both record `RunEnding.FAILED`; these say which.
const OVERRUN: StringName = &"colony_overrun"
const INDEPENDENCE: StringName = &"independence"


## 🔒 **One test, and it counts the walkers** (§1).
static func is_overrun(colony: Colony, parties: Array) -> bool:
	if colony == null:
		return false
	# 🔒 **A run that has not begun is not a run that has ended**, and the two look
	# identical from here: no towns either way.
	#
	# It used to be told apart by *is anybody walking*, which worked only while
	# nothing could take a town — and #218 and #225 made that false. A colony that
	# lost its last town with no expedition in the field would have read as month
	# one of a new game and the ending would never have fired.
	#
	# `has_held_a_town` is the distinction, set the first time a town joins the
	# colony and never cleared.
	if not colony.has_held_a_town and parties.is_empty():
		return false
	return people_in(colony, parties) <= 0


## Everyone the colony still has, in its towns and on the road.
##
## **Loyal or rebel**, because §13.1 counts every town the colony holds.
static func people_in(colony: Colony, parties: Array) -> int:
	var people := 0
	if colony != null:
		for town in colony.in_order():
			people += town.population()
	for party in parties:
		var walking: ExpeditionParty = party
		if walking != null:
			people += walking.people + _experts_in(walking)
	return people


static func _experts_in(party: ExpeditionParty) -> int:
	var total := 0
	var kinds: Array = party.experts.keys()
	kinds.sort()
	for kind in kinds:
		total += int(party.experts[kind])
	return total


## 🔒 **Four conditions, together** (§1). Any one untrue and the run goes on.
static func is_independent(
	colony: Colony,
	companies: Companies,
	standing: CrownStanding,
	marshal: Contact,
	state: WorldState,
) -> bool:
	if colony == null or colony.is_empty():
		return false
	return not any_town_is_loyal(colony) \
		and standing != null and standing.has_lost_confidence() \
		and crown_troops_in(companies) <= 0 \
		and not will_send_more(marshal, standing, state)


## Condition 1.
##
## **`Colony.loyal()` and nothing of its own**, so *a town loyal to the Crown*
## cannot come to mean two different things — the same arrangement the crowding
## measure and its filter have, and for the same reason.
static func any_town_is_loyal(colony: Colony) -> bool:
	return colony != null and not colony.loyal().is_empty()


## Condition 3: how many Crown soldiers are standing in the colony.
##
## 🔒 **The men, not the companies.** Two half-dead companies are not twice the
## garrison of one whole one, and §13.1's condition is whether the Crown still
## has force here at all.
##
## **No position test, deliberately.** Every Crown company in the run is in the
## colony — the Marshal raises them nowhere else and they are sent nowhere else
## — so asking where one stands would invent a distinction the sim does not have
## and would answer differently the month one marched between two towns.
##
## `Companies.list` holds only the living (`bury_the_dead`), so a company wiped
## out last month is already gone rather than counted at zero.
static func crown_troops_in(companies: Companies) -> int:
	if companies == null:
		return 0
	var men := 0
	for entry in companies.list:
		var company: Company = entry
		if company != null and company.allegiance == Company.CROWN:
			men += company.size
	return men


## Condition 4, and the one where a run actually ends.
##
## 🔒 **Derived by asking the kernel, not by a flag.** The question is *what
## would the Marshal do if the PC asked*, and the only honest way to answer it is
## to ask him — so this builds the request the PC has not made and resolves it
## hypothetically.
##
## He will never refuse troops the PC is paying for in full: that is
## `FullPaymentIsAYes`, a filter rather than a weight. **But the filter reads
## whether the Crown can pay**, and once standing is lost the Crown honours
## nothing (§10.3) — so the PC is not paying at all. He is banking on the
## Marshal's loyalty to foot the bill, and `the-marshal.md` §3 has him quietly
## covering it while his regard falls every month.
##
## **Which is how it actually happened.** The Crown that loses a colony this way
## does not lose a battle. It stops being willing to pay for the next one, and
## the man who decides that is an officer watching his own account and his own
## casualty lists.
static func will_send_more(
	marshal: Contact,
	standing: CrownStanding,
	state: WorldState,
) -> bool:
	# No Marshal is no answer rather than a refusal: an office nobody holds has
	# not declined anything, and a run must not end because a contact is missing.
	if marshal == null or state == null:
		return true

	var asking := Order.new(M1Registrations.ORDER_REQUEST_TROOPS, marshal.id, {
		"to": String(marshal.id),
	}, state.month)
	# 🔒 **The PC offers to pay in full**, which is the case §4 is about. The
	# guarantee is not *the PC is generous* — he always is, in this question — it
	# is *the Crown will honour it*, and that is what `can_crown_pay` carries.
	#
	# Asking with nothing on the table would be asking a different question: the
	# filter would never apply whatever the Crown's standing, and the Marshal
	# would read as unwilling from the first month of a run.
	asking.params["payment"] = Compliance.cost_of(asking)

	# 🔒 **And once the Crown will not honour it, the money is not there.**
	# §4: the PC *is* offering to pay in full, and the Crown honours nothing
	# (§10.3) — so what actually reaches the Marshal is nothing, and
	# `the-marshal.md` §3 has him quietly covering it while his regard falls.
	#
	# Two things therefore change together, and both are needed. Lifting the
	# guarantee alone leaves `payment_offered` reading a thousand gold nobody will
	# send, and the Marshal goes on obliging a Crown that has stopped paying him.
	var honoured := standing == null or not standing.has_lost_confidence()

	var decision := Deliberation.choose(marshal, _troop_answers(), _asking_context(
		marshal, asking, honoured, state))
	if not decision.has_choice():
		return false
	return decision.chosen_id() != Compliance.REFUSE


## The same six answers compliance would offer, built here so the hypothetical
## and the real resolution cannot come to differ.
static func _troop_answers() -> Array:
	var out: Array = []
	for outcome in Compliance.OUTCOMES:
		out.append(Candidate.new(outcome, {"outcome": String(outcome)}))
	return out


## 🔒 **A hypothetical leaves no mark** (§4).
##
## Two things would otherwise escape. `choose()` always emits its scoring trace,
## so the trace goes to a **scratch log** that is dropped — a weighing nobody
## asked for must not appear in the record every consumer of Seam A reads.
##
## And it takes **no RNG stream at all.** `choose` breaks ties on the candidate
## id precisely so a decision does not consume from the actor's stream; passing
## his stream here would be safe today and would silently shift every later draw
## in the run the moment that stopped being true.
static func _asking_context(
	marshal: Contact,
	asking: Order,
	honoured: bool,
	state: WorldState,
) -> DeliberationContext:
	var context := DeliberationContext.new(
		DecisionKind.ORDER_COMPLIANCE, state, EventLog.new())
	context.phase = WorldPhase.RUN_END_CHECK
	context.data = {
		"order": asking,
		"cost": Compliance.cost_of(asking),
		"payment": Compliance.payment_in(asking) if honoured else 0.0,
		"loyalty": marshal.loyalty(),
		"vagueness": Compliance.vagueness_of(asking),
		"harsh": false,
		"tone": Tone.DUTIFUL,
		"dissonance": 0.0,
		# **The Crown honours nothing once standing is lost** (§10.3), which is
		# what takes the guarantee away and lets him refuse at all.
		"can_crown_pay": honoured,
	}
	return context
