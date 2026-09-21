class_name Compliance
extends RefCounted

## **Your orders are requests** (SPEC §8.5). This is where that becomes true.
##
## A player letter never touches sim state. It creates an **Order** addressed to
## a contact. The contact resolves it here — and what he does about it runs
## through the deliberation kernel, never a bespoke `if` chain, so a system added
## in a later milestone changes how contacts respond without anybody editing this
## file.
##
## **Acting alone is the same code path as complying**, with a different origin.
## That is the whole point of Seam C: "the contact complied with your order" and
## "the contact acted on his own and informed the PC afterward" are one mechanism.

# --- The six outcomes ------------------------------------------------------

const COMPLY: StringName = &"comply"
const PARTIAL: StringName = &"partial"
const DELAY: StringName = &"delay"
const REINTERPRET: StringName = &"reinterpret"
const REFUSE: StringName = &"refuse"
## Especially at low loyalty: he does what he thinks best and tells the PC after.
const ACT_ALONE: StringName = &"act_alone"

const OUTCOMES: Array[StringName] = [COMPLY, PARTIAL, DELAY, REINTERPRET, REFUSE, ACT_ALONE]

## Distinct event types, so next month's letters can key on what he did without
## unpacking a payload.
## How many months ahead a contact looks when he weighs a standing charge.
##
## **A policy has no end date**, so asked "what will this cost you", the honest
## answer is "forever". A man does not weigh forever; he weighs a year or so and
## decides. Tuning.
const POLICY_HORIZON: float = 14.0

const OUTCOME_EVENTS: Dictionary = {
	COMPLY: &"order_complied",
	PARTIAL: &"order_partly_complied",
	DELAY: &"order_delayed",
	REINTERPRET: &"order_reinterpreted",
	REFUSE: &"order_refused",
	ACT_ALONE: &"contact_acted_alone",
}

## How long each outcome takes to carry out. **Consequential actions are
## multi-month so a letter can interrupt them**
## (`docs/mechanics/world-month.md` §3); a delay is simply a longer one.
const MONTHS_FOR: Dictionary = {
	COMPLY: 1,
	PARTIAL: 1,
	DELAY: 3,
	REINTERPRET: 2,
	ACT_ALONE: 2,
}

## What a partial compliance actually delivers. Tuning.
const PARTIAL_SHARE: float = 0.5

## What each tone makes of a partial, on an **asking** letter (#261, `tone.md`
## §3, §4).
##
## 🔒 **Annoyed's push toward a partial is worth less if the partial is a tenth
## of what was asked.** The two knobs move together or the tone's whole identity
## — *half of it, now* — is a push toward an outcome that means nothing.
##
## Pleased is generous because he is glad to; hateful gives the least he can
## while still not having refused, which is its own kind of answer. Dutiful is
## the plain register and moves it not at all.
##
## Tuning, and the centre of a distribution like every other figure here: the
## traits scale it per man.
const PARTIAL_BY_TONE: Dictionary = {
	Tone.PLEASED: 0.65,
	Tone.DUTIFUL: 0.5,
	Tone.ANNOYED: 0.5,
	Tone.DESPERATE: 0.7,
	Tone.HATEFUL: 0.3,
}

## How much of an `adjust_loyalty` amount counts as one deed's worth. Tuning.
const LOYALTY_STEP: float = 5.0

## What being leaned on costs a governor, in deeds.
##
## **Less than a refusal and more than nothing.** The PC did not decline to help
## him; he told him. Tuning (§8).
const HARSH_LOYALTY_COST: float = 0.8


## Resolve one Order into an Intent, or into nothing if he refuses.
##
## Returns `{outcome, decision, intent}`. `intent` is null on a refusal, because
## a refusal is a thing that did not happen.
static func resolve(
	order: Order,
	contact: Contact,
	book: IntentBook,
	state: WorldState,
	log: EventLog,
	streams: RngStreams,
	rebel: Town = null,
) -> Dictionary:
	var context := DeliberationContext.new(DecisionKind.ORDER_COMPLIANCE, state, log)
	context.phase = WorldPhase.RECKONING
	context.rng = streams.contact_stream(String(contact.id))
	context.data = {
		"order": order,
		"cost": cost_of(order),
		"payment": payment_in(order),
		"loyalty": contact.loyalty(),
		"vagueness": vagueness_of(order),
		# **Leaning on a man works** (`rebel-sentiment.md` §4). It is the surest
		# way to be obeyed and the PC pays for it twice — in the governor's regard
		# below, and in what the town holds against the Crown afterwards.
		"harsh": order.harsh,
		# **The manner he is being written to in** (#260, `tone.md` §5). One of
		# five considerations reads it and the other four score nothing, so the
		# PC's first blank carries a function rather than decorating the page.
		"tone": order.tone,
		# **How far the letter cuts against what he already wants** (#213).
		#
		# 🔒 It changes the **manner** of his answer, never the decision. A
		# governor whose town is threatened, told to chase profit, is markedly
		# likelier to reinterpret the instruction into something he can live with
		# — *"I have applied Your Grace's instruction regarding our profits to the
		# timber we shall need for the palisade"* — and that letter is
		# unreachable if compliance cannot tell an agreeable order from an
		# unwelcome one.
		#
		# **Compliance still does not decide the intent.** `contacts.md` §3 locks
		# the split: compliance decides whether he listens, phase 8's
		# deliberation decides what he concludes, and collapsing them would put
		# the PC's letter and the governor's judgement in one scoring pass and
		# stop the argument being an argument.
		"dissonance": dissonance_of(order, rebel),
	}

	# 🔒 **Answering has no compliance step** (#261, `tone.md` §3). *You* are the
	# one complying. A man who wrote asking the PC to bear his share does not then
	# deliberate about whether to accept it, one told to stop is not being asked
	# either, and a man who was refused has not been handed anything to refuse in
	# turn — all of them are answers to his own letter.
	#
	# **He does not deliberate at all**, rather than deliberating and having the
	# answer overruled. `choose()` always emits its scoring trace (`CLAUDE.md`),
	# so the overruled version would write a weighing that never happened into the
	# log every consumer of that trace reads.
	#
	# This was already half here, as the two policy kinds and a comment saying
	# *being paid is not a request*. `LetterKind` is that rule with a name and the
	# rest of the list, because half a rule in a comment is a rule the next order
	# kind does not get.
	var answering := not LetterKind.deliberates(StringName(order.kind))
	var decision: Decision = null if answering else Deliberation.choose(
		contact, _candidates(), context)
	var outcome: StringName = COMPLY
	if not answering:
		outcome = decision.chosen_id() if decision.has_choice() else REFUSE

	# **A rebel town's governor has no loyalty to the Crown** (SPEC §12.3, #72).
	# A filter rather than a weight, per `CLAUDE.md`: the spec locks that the PC
	# gets no cooperation, and a heavy thumb on the scale would still let a very
	# well-liked governor comply with the Crown he has just renounced.
	#
	# The PC may still write. He will simply be refused, and the refusal is a
	# real event his letters can report rather than silence.
	if rebel != null and rebel.rebelling:
		outcome = REFUSE

	# **An embargo is not addressed to the town it falls on.** It is an
	# instruction to the rest of the colony, carried in a letter to the man it
	# concerns as a courtesy, so his willingness has nothing to do with whether
	# the convoys stop. A rebel governor refusing it would have made the Crown's
	# only punishment conditional on the goodwill of the man being punished.
	if order.kind == M1Registrations.ORDER_EMBARGO:
		outcome = COMPLY

	log.emit(OUTCOME_EVENTS[outcome], contact.id, state.month, {
		"order": order.to_dict(),
		"outcome": String(outcome),
	}, WorldPhase.RECKONING)

	# **A costly request reduces loyalty unless the PC makes it up to them**
	# (SPEC §8.5). Paying generously for troops costs nothing; paying less does.
	_settle_loyalty(order, contact, outcome)
	# **And he remembers it**, with enough to describe it later (#127). The count
	# says how often; this says what.
	contact.relationship.remember(
		_deed_of(order), state.month, _size_of(order), _about(order)
	)

	var intent: Intent = null
	if outcome != REFUSE:
		intent = _intent_for(order, outcome, contact)
		book.commit(intent, log, state.month)

	return {"outcome": outcome, "decision": decision, "intent": intent}


## Which deed this Order will read as, to the man who received it.
##
## The same match as `_settle_loyalty`, kept beside it so the two cannot
## disagree about whether a letter was a kindness or an injury — a contact who
## warmed to a letter and remembered it as a slight would be two different men.
static func _deed_of(order: Order) -> StringName:
	match order.kind:
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PROMISE_RESOURCE, \
		M1Registrations.ORDER_PROMISE_REVENUE, M1Registrations.ORDER_PROMISE_SHIPMENT, \
		M1Registrations.ORDER_GRANT_FAVOR:
			return Relationship.GRANTED
		M1Registrations.ORDER_REFUSE, M1Registrations.ORDER_DECLINE_DEMAND:
			return Relationship.REFUSED
		M1Registrations.ORDER_ADJUST_LOYALTY:
			return Relationship.GRANTED if float(order.get_param("amount", 0.0)) >= 0.0 \
				else Relationship.REFUSED
	return Relationship.DELIVERED


## How much of it there was. **Two hundred measures of iron is a different
## memory from two**, and a letter that could only say "a kindness" would be
## saying nothing.
static func _size_of(order: Order) -> float:
	for name in ["amount", "payment", "months"]:
		if order.params.has(name):
			return absf(float(order.get_param(name, 0.0)))
	return 0.0


## What it concerned — a resource, an intent, whatever the letter was about.
##
## Empty when the deed had no subject. A refusal with nothing attached is still
## a refusal and the letters have to be able to say so.
static func _about(order: Order) -> String:
	for name in ["resource", "intent", "favor", "policy"]:
		if order.params.has(name):
			return String(order.get_param(name, ""))
	return ""


static func _candidates() -> Array:
	var candidates: Array = []
	for outcome in OUTCOMES:
		candidates.append(Candidate.new(outcome, {"outcome": String(outcome)}))
	return candidates


## Turn the outcome into what he will actually do.
##
## **Acting alone produces an Intent exactly as complying does**, differing only
## in `origin`. Downstream, the executor cannot tell them apart — only the
## letters care.
static func _intent_for(order: Order, outcome: StringName, contact: Contact) -> Intent:
	var params := order.params.duplicate(true)

	match outcome:
		PARTIAL:
			if params.has("amount") and JsonTypes.is_int_like(params["amount"]):
				params["amount"] = int(
					JsonTypes.to_int(params["amount"], "amount") * partial_share(order))
		REINTERPRET:
			# He does what he thinks you meant, which is not what you wrote.
			params["reinterpreted"] = true

	if order.kind == M1Registrations.ORDER_SHIP_RESOURCE:
		# **Compliance is a choice of priority tier, not a mood** (#69,
		# `crown-demands.md` §5). Treating a shipment as a need outranks the
		# governor's own project and his town goes without; shipping what he can
		# lets only genuine surplus leave. The same three answers, read as what
		# they cost his town rather than as how he felt about being asked.
		params["tier"] = String(Shipment.tier_for(outcome))
		params["shipped"] = 0.0

	var intent := Intent.new(
		&"",
		StringName(order.kind),
		contact.id,
		StringName(order.get_param("to", String(contact.id))),
		int(MONTHS_FOR.get(outcome, 1)),
		params,
	)
	intent.origin = Intent.ORIGIN_WILL if outcome == ACT_ALONE else Intent.ORIGIN_ORDER
	return intent


## What the request costs the contact, roughly, in the same units as payment.
static func cost_of(order: Order) -> float:
	match order.kind:
		M1Registrations.ORDER_REQUEST_TROOPS:
			return 1000.0
		M1Registrations.ORDER_SHIP_RESOURCE:
			# **Full compliance damages his own town**, so it costs him, and the
			# payment is what makes it up to him (SPEC §8.5). Priced off what the
			# goods are worth, so a demand for two hundred iron weighs more on him
			# than one for twenty.
			return float(order.get_param("amount", 0)) \
				* ResourceCatalogue.price_of(StringName(order.get_param("resource", "")))
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PROMISE_RESOURCE, \
		M1Registrations.ORDER_PROMISE_REVENUE, M1Registrations.ORDER_PROMISE_SHIPMENT:
			# Being given something costs the recipient nothing.
			return 0.0
		M1Registrations.ORDER_REFUSE, M1Registrations.ORDER_DECLINE_DEMAND, \
		M1Registrations.ORDER_FUND_POLICY, M1Registrations.ORDER_END_POLICY:
			return 0.0
		M1Registrations.ORDER_EMBARGO:
			# It costs him a great deal, and no payment is on offer. What that
			# does to his regard is the point of laying one.
			return 0.0 if int(order.get_param("months", 0)) <= 0 else 2000.0
		M1Registrations.ORDER_ENACT_POLICY:
			# **What it costs him is what the PC is not paying**, for as long as
			# it stands — so an unfunded policy is an expensive thing to be asked
			# for and a fully funded one costs him nothing but his name.
			var monthly := float(order.get_param("cost", 0.0))
			var unpaid: float = Policy.UNPAID_SHARE.get(
				StringName(order.get_param("split", "none")), 1.0)
			return monthly * unpaid * POLICY_HORIZON
		M1Registrations.ORDER_URGE_INTENT:
			# **Being told what matters costs a governor nothing to carry out.**
			# He is governing either way, and the town pays for its own projects
			# out of its own stores.
			#
			# Costing it anything made `payment_offered` decide every priority
			# letter in the game: the PC sends no gold with a pronouncement, so
			# refusing scored highest every month and the governor answered
			# "I will not" to instructions he already agreed with. What an urge
			# actually costs him is his own judgement, and that is the `autonomy`
			# consideration's business rather than a price.
			return 0.0
	return 200.0


## How much room the order leaves to decide what the PC meant.
##
## An order carrying a figure is specific: send 200 of iron, pay 500 for troops.
## One carrying only words — set this policy, grant this favour — is not, and
## SPEC §8 expects personality to show in how a contact reads it.
##
## **An intent is specific without carrying a number.** "Your people's survival
## must come first" is one of exactly five things the PC can say and there is
## nothing in it to misread — so a governor who disagrees refuses honestly rather
## than claiming your letter admitted of more than one reading. Judging it vague
## made every governor reinterpret or refuse every priority he was ever sent,
## which read as a man who could not follow plain English.
## How far an order cuts against what the contact currently wants (#213).
##
## **Zero where nothing applies**, exactly as harshness is zero for a mild
## letter. Only `urge_intent` can be read this way today: it is the one order
## kind that names what the PC wants the town to be *for*, which is the thing a
## governor can hold a contrary opinion about. Another kind that acquires an
## answer to "against his judgement" adds a branch here and nothing else.
static func dissonance_of(order: Order, town: Town) -> float:
	if order == null or town == null:
		return 0.0
	if order.kind != M1Registrations.ORDER_URGE_INTENT:
		return 0.0
	var urged := StringName(order.get_param("intent", ""))
	if not GovernorIntent.is_intent(urged):
		return 0.0
	return GovernorIntent.distance_between(urged, town.intent)


static func vagueness_of(order: Order) -> float:
	if order.kind == M1Registrations.ORDER_URGE_INTENT:
		return 0.0
	for key in order.params:
		if key == "to":
			continue
		var value: Variant = order.params[key]
		var kind := typeof(value)
		if kind == TYPE_INT or kind == TYPE_FLOAT:
			return 0.0
	return 1.0


static func payment_in(order: Order) -> float:
	if order.params.has("payment"):
		return float(order.get_param("payment", 0.0))
	if order.kind == M1Registrations.ORDER_PROMISE_GOLD:
		return float(order.get_param("amount", 0.0))
	return 0.0


## How generously the PC paid, as a share of what the request costs.
static func payment_ratio(order: Order) -> float:
	var cost := cost_of(order)
	if cost <= 0.0:
		return 1.0
	return clampf(payment_in(order) / cost, 0.0, 1.0)


## Deeds move loyalty; the outcome does not.
##
## What the PC did — asked for something costly, paid for it or did not, granted
## something — is what registers. Whether the contact then complied is his own
## business, not a favour the PC did him.
static func _settle_loyalty(order: Order, contact: Contact, _outcome: StringName) -> void:
	match order.kind:
		M1Registrations.ORDER_PROMISE_GOLD, M1Registrations.ORDER_PROMISE_RESOURCE, \
		M1Registrations.ORDER_PROMISE_REVENUE, M1Registrations.ORDER_PROMISE_SHIPMENT, \
		M1Registrations.ORDER_GRANT_FAVOR:
			contact.relationship.record_deed(Relationship.GRANTED)
		M1Registrations.ORDER_REFUSE, M1Registrations.ORDER_DECLINE_DEMAND:
			contact.relationship.record_deed(Relationship.REFUSED)
		M1Registrations.ORDER_ADJUST_LOYALTY:
			# The letter said plainly that it would move his regard, so it must.
			var amount := float(order.get_param("amount", 0.0))
			if amount >= 0.0:
				contact.relationship.record_deed(Relationship.GRANTED, amount / LOYALTY_STEP)
			else:
				contact.relationship.record_deed(Relationship.REFUSED, absf(amount) / LOYALTY_STEP)
		M1Registrations.ORDER_REQUEST_TROOPS:
			# Paying generously leaves loyalty where it was; paying little stings.
			var shortfall := 1.0 - payment_ratio(order)
			if shortfall > 0.0:
				contact.relationship.record_deed(Relationship.REFUSED, shortfall)
		_:
			pass

	# **A command is not a request, and he notices** (§4). Recorded whatever the
	# outcome, because the deed is the PC's and not his: being written to that way
	# is the thing that stings, not whether he then did it.
	if order.harsh:
		contact.relationship.record_deed(Relationship.REFUSED, HARSH_LOYALTY_COST)

	if not order.tone.is_empty():
		contact.relationship.record_tone(order.tone)


## How much of an asking letter a partial answer actually does.
##
## 🔒 **Asking letters only** (`tone.md` §3). Directing has no amount in it — a
## governor half-persuaded toward profit is not chasing half a profit — and
## answering never reaches a partial at all.
static func partial_share(order: Order) -> float:
	if not LetterKind.has_a_magnitude(StringName(order.kind)):
		return PARTIAL_SHARE
	return float(PARTIAL_BY_TONE.get(order.tone, PARTIAL_SHARE))
