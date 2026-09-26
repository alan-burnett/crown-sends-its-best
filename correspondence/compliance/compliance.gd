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

## The key the manner of the letter travels under, from the desk to the
## deliberation months later (#262).
const URGED_TONE: String = "urged_tone"

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

## What leaning on a man adds to a half measure, on an asking letter (#263).
##
## Tuning, and a multiplier rather than a figure of its own so the two axes stay
## two: the tone decides how generous he is and the threat decides how much the
## threat is worth.
const HARSH_PARTIAL: float = 1.3

## And the most a partial can ever be, however hard the PC leans.
##
## **A man who did the lot has complied**, and partial would otherwise be a word
## for two different answers.
const HARSHEST_PARTIAL: float = 0.9

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
		"dissonance": dissonance_of(order, rebel, state),
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
	# says how often; this says what. 🔒 **A promise of no gold is nothing to
	# remember** (#460), and nothing the court hears of either.
	var empty := is_only_words(order)
	if not empty:
		contact.relationship.remember(
			_deed_of(order), state.month, _size_of(order), _about(order)
		)
	# 🔒 **And what he did for the PC, if it cost him** (#397).
	_remember_his_favour(order, contact, outcome, state.month)
	# **And the court hears of it, if he is the sort the court listens to**
	# (`prestige.md` §5). Returns at once for everybody who is not a patron, so
	# this is one guard in one place rather than a rule the next call site has to
	# remember.
	#
	# 🔒 **Except an undertaking to ship** (#441, `patrons.md` §4): the goods
	# arriving are the deed, so `PromiseBook` banks it when the promise is kept
	# or broken, and a promise alone is nothing the court has seen.
	if order.kind != M1Registrations.ORDER_PROMISE_SHIPMENT and not empty:
		PatronCredit.bank(contact, _deed_of(order), log, state.month)

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
		M1Registrations.ORDER_TROUBLE_A_DUKE, M1Registrations.ORDER_SEND_AN_EXPERT, \
		M1Registrations.ORDER_GIVE_THE_CROWN_GOLD:
			# **Taking up his offer is the favour he wanted** (#395, #443): a
			# patron who offers a kindness and has it accepted says so at court,
			# as one who is refused says the other thing (`patrons.md` §4).
			return Relationship.GRANTED
		M1Registrations.ORDER_REFUSE, M1Registrations.ORDER_DECLINE_DEMAND:
			return Relationship.REFUSED
		M1Registrations.ORDER_ADJUST_LOYALTY:
			return Relationship.GRANTED if float(order.get_param("amount", 0.0)) >= 0.0 \
				else Relationship.REFUSED
	return Relationship.DELIVERED


## 🔒 **He did the PC a favour: he complied with an order that cost him** (#397,
## the Author's ruling on the ticket). In whole or in part, and worth what this
## file prices the order at, times the share he did. An order he was paid in full
## for, or one that costs nobody anything, is duty and no favour.
##
## Two are remembered elsewhere, when the thing has actually happened: goods he
## ships (`FavourDriver`, when the shipment ends), and a patron's men (when they
## land). Remembering them here as well would count one kindness twice.
static func _remember_his_favour(
	order: Order, contact: Contact, outcome: StringName, month: int
) -> void:
	if outcome != COMPLY and outcome != PARTIAL:
		return
	if _deed_of(order) != Relationship.DELIVERED or order.kind == M1Registrations.ORDER_SHIP_RESOURCE:
		return
	if Patron.is_patron(contact) and order.kind == M1Registrations.ORDER_ENACT_POLICY \
			and StringName(order.get_param("effect", "")) == PolicyEffects.CROWN_TROOPS:
		return
	var priced: Variant = _priced(order)
	if priced == null or float(priced) <= 0.0:
		return
	var share := 1.0 if outcome == COMPLY else partial_share(order)
	contact.relationship.remember_favour(Relationship.FAVOUR_COMPLIED, month,
		_size_of(order) * share, _about(order), float(priced) * share)


## 🔒 **What a refusal was a refusal of** (#391, `contacts.md` §7).
##
## `refuse` takes nothing but its addressee, so a refusal was remembered with no
## size and no subject — and *"you will remember that you refused me the iron"*
## had nothing to name. The desk stamps these on a refusal written in answer to a
## letter that asked for an amount of a resource (`TurnMachine._build_orders`),
## under names of their own so nothing mistakes them for what was *given*.
const ASKED_AMOUNT: String = "asked_amount"
const ASKED_RESOURCE: String = "asked_resource"


## How much of it there was. **Two hundred measures of iron is a different
## memory from two**, and a letter that could only say "a kindness" would be
## saying nothing.
static func _size_of(order: Order) -> float:
	for name in ["amount", "payment", "months", ASKED_AMOUNT]:
		if order.params.has(name):
			return absf(float(order.get_param(name, 0.0)))
	return 0.0


## What it concerned — a resource, an intent, whatever the letter was about.
##
## Empty when the deed had no subject. A refusal with nothing attached is still
## a refusal and the letters have to be able to say so.
static func _about(order: Order) -> String:
	for name in ["resource", "intent", "favor", "policy", ASKED_RESOURCE]:
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

	# **The manner it was written in travels with it** (#262, `tone.md` §4). An
	# urging is consulted for months after the letter was read, and how hard it
	# pulls is a property of the letter rather than of the month it is read in —
	# so the tone has to survive the journey from the desk to the deliberation.
	#
	# 🔒 **Only where it was the PC who wrote.** A contact who acted alone wrote
	# nobody a letter, so there is no manner to carry and the entry is absent
	# rather than defaulted.
	if outcome != ACT_ALONE and Tone.is_tone(order.tone):
		params[URGED_TONE] = String(order.tone)

	var intent := Intent.new(
		&"",
		StringName(order.kind),
		contact.id,
		StringName(order.get_param("to", String(contact.id))),
		int(MONTHS_FOR.get(outcome, 1)),
		params,
	)
	intent.origin = Intent.ORIGIN_WILL if outcome == ACT_ALONE else Intent.ORIGIN_ORDER
	# **Which letter it came from** (#393), so the other Orders in the same letter
	# are not mistaken for a later one contradicting it.
	intent.letter = order.letter
	return intent


## 🔒 **An Order he carries out of his own will** (#450): the Intent acting
## alone produces, for a decision the PC left to him.
static func as_his_own_will(order: Order, contact: Contact) -> Intent:
	return _intent_for(order, ACT_ALONE, contact)


## What the request costs the contact, roughly, in the same units as payment.
static func cost_of(order: Order) -> float:
	var priced: Variant = _priced(order)
	if priced != null:
		return float(priced)

	# 🔒 **An unlisted order kind is a bug, not a default** (#302).
	#
	# This fell through to two hundred, and that figure was **fabricated**: it
	# said a thing costs the recipient rather a lot on the sole grounds that
	# nobody had said what it cost. It broke `urge_intent` once — the comment in
	# `_priced` is the post-mortem — and then broke `set_tax_rate` the same way,
	# and four more kinds were quietly carrying it when this was written.
	#
	# **Nought and loud.** Nought because *we do not know that this costs him
	# anything* is the honest reading of an omission; loud because the silence is
	# what let it happen twice.
	push_error(
		"cost_of() has no case for order kind '%s', so it is priced at nothing. "
		% order.kind + "Give it a case in Compliance._priced."
	)
	return 0.0


## Whether this kind of order has a price at all.
##
## **Asked of the same match `cost_of` uses**, so the two cannot drift: a kind
## added to one is added to both, and `test_compliance` fails the moment a
## registered kind has no case.
static func is_priced(kind: StringName) -> bool:
	return _priced(Order.new(kind, &"anyone", {"resource": "iron", "amount": 1}, 0)) != null


## What this order costs the man who receives it, or **null** if nobody has said.
static func _priced(order: Order) -> Variant:
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
		M1Registrations.ORDER_TROUBLE_A_DUKE, M1Registrations.ORDER_SEND_AN_EXPERT, \
		M1Registrations.ORDER_GIVE_THE_CROWN_GOLD:
			# **It is his specialty and his pleasure** (#395, #443, `patrons.md`
			# §4, §5): he offered it, so being taken up on it costs him nothing he
			# minds.
			return 0.0
		M1Registrations.ORDER_ANSWER_THE_TRIBE:
			# **He asked** (#436). Being told what to say to the tribe costs him
			# nothing but his own opinion of it.
			return 0.0
		M1Registrations.ORDER_URGE_INTENT, M1Registrations.ORDER_URGE_COMPANY:
			# **Being told what matters costs a governor nothing to carry out.**
			# Nor a commander what his men should do (#394): he is commanding
			# either way, and what it costs him is his own judgement.
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
		M1Registrations.ORDER_SET_TAX_RATE, M1Registrations.ORDER_SET_POLICY, \
		M1Registrations.ORDER_WAIVE_DUTY, M1Registrations.ORDER_MOVE_DIPLOMAT:
			# 🔒 **A rate costs the colony, not the man who sets it** (#302, SPEC
			# §8.1). The Steward is being asked to do his job, in the direction he
			# already wants — and priced at the fall-through's two hundred, against
			# a man whose heaviest weight is `cost_of_request`, the Steward of the
			# Revenue refused an order to raise the revenue on turn one.
			#
			# **And a move costs the Crown, not the Diplomat** (#393). The gold for
			# his journey is a separate promise in the same letter; pricing the move
			# as well would charge him for travelling on the Crown's business, and
			# he would refuse even the move he asked for.
			return 0.0
		M1Registrations.ORDER_PREFER_SITE, M1Registrations.ORDER_DISSUADE_FOUNDING:
			# **An opinion about where a town goes costs nothing to receive.** What
			# it costs him is his own judgement, which is `autonomy`'s business
			# rather than a price — the same argument as an urging, and it must be,
			# because a preference is an urging about a place.
			return 0.0
		M1Registrations.ORDER_ADJUST_LOYALTY, M1Registrations.ORDER_GRANT_FAVOR, \
		M1Registrations.ORDER_APOLOGISE, \
		M1Registrations.ORDER_FUND_FOUNDING, M1Registrations.ORDER_PAY_TRIBUTE, \
		M1Registrations.ORDER_DEFLECT_TRIBUTE:
			# Answering letters (#261). He never deliberates over these, so the
			# price is moot — but it is written down, because an unpriced kind is
			# how this went wrong twice and a moot figure is still a figure.
			return 0.0
	return null


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
static func dissonance_of(order: Order, town: Town, state: WorldState = null) -> float:
	if order == null:
		return 0.0
	match order.kind:
		M1Registrations.ORDER_URGE_INTENT:
			if town == null:
				return 0.0
			var urged := StringName(order.get_param("intent", ""))
			if not GovernorIntent.is_intent(urged):
				return 0.0
			return GovernorIntent.distance_between(urged, town.intent)
		M1Registrations.ORDER_SET_TAX_RATE:
			return _cut_below_his_rate(order, state)
	return 0.0


## How many steps down a rate has to go before the Steward is wholly against it.
## Tuning.
const DEEP_CUT_STEPS: float = 2.0


## 🔒 **The Steward's bias** (#303, `the-steward.md` §2, SPEC §10.2).
##
## *He prefers high taxes*, so the rate he would have set is **never lower than
## the one standing** — derived from the world, never stored on him. A rise costs
## him nothing; a cut is against his judgement by how far it goes, and two steps
## down is as far against it as he gets.
##
## 🔒 **The manner of his answer, never the decision.** This feeds the same
## `DissonanceConsideration` a governor's does, which pulls toward reinterpreting,
## acting alone and delaying and deliberately not toward refusing — a Crown
## officer who disagrees with the Crown's revenue policy finds the instruction
## admitted of another reading. He never writes back *no*.
static func _cut_below_his_rate(order: Order, state: WorldState) -> float:
	if state == null:
		return 0.0
	var standing := TaxRates.rate_for(state, StringName(order.get_param("resource", "")))
	var ordered := float(order.get_param("rate", standing))
	return clampf((standing - ordered) / (TaxRates.STEP * DEEP_CUT_STEPS), 0.0, 1.0)


static func vagueness_of(order: Order) -> float:
	# One of a handful of things the PC can say, with nothing in it to misread.
	if order.kind == M1Registrations.ORDER_URGE_INTENT or order.kind == M1Registrations.ORDER_URGE_COMPANY \
			or order.kind == M1Registrations.ORDER_ANSWER_THE_TRIBE:
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
## 🔒 **A promise of no gold gives nothing** (#460): a gold promise or tribute of
## nought or less. It earns no gratitude, no memory and no promise to keep, and
## the reply wizard never offers one.
static func is_an_empty_promise(order: Order) -> bool:
	if order.kind != M1Registrations.ORDER_PROMISE_GOLD and order.kind != M1Registrations.ORDER_PAY_TRIBUTE:
		return false
	return float(order.get_param("amount", 0.0)) <= 0.0


## 🔒 **An order that gives nothing but words** (#459, #460): an apology, or a
## promise of no gold. It moves a man only as the tone of the letter does: no
## deed, no memory, and nothing the court hears of.
##
## *Deeds outweigh words* (SPEC §8.5): owning a broken promise must never leave
## him better disposed than before it was broken, and a deed of gratitude for an
## apology did.
static func is_only_words(order: Order) -> bool:
	return order.kind == M1Registrations.ORDER_APOLOGISE or is_an_empty_promise(order)


static func _settle_loyalty(order: Order, contact: Contact, _outcome: StringName) -> void:
	if is_only_words(order):
		if not order.tone.is_empty():
			contact.relationship.record_tone(order.tone)
		return
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
##
## 🔒 **And leaning on him makes the half measure larger** (#263, §9). Harsh is
## the second axis, so it multiplies the tone's share rather than replacing it:
## a hateful threat still buys less of the levy than a fond one, and a threat of
## either kind buys more than the same letter without it.
##
## Never the whole of it, however hard the PC leans. A man who did the lot has
## complied, and partial would then be a word for two different answers.
static func partial_share(order: Order) -> float:
	if not LetterKind.has_a_magnitude(StringName(order.kind)):
		return PARTIAL_SHARE
	var share := float(PARTIAL_BY_TONE.get(order.tone, PARTIAL_SHARE))
	if order.harsh:
		share *= HARSH_PARTIAL
	return clampf(share, 0.0, HARSHEST_PARTIAL)
