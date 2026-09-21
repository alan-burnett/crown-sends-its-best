class_name ComplianceConsiderations
extends RefCounted

## What a contact weighs when a letter asks him for something.
##
## **Owned by this system, not by the AI** (`docs/mechanics/deliberation.md` §3).
## A milestone that adds a system ships that system's considerations with it, so
## when natives arrive in M5 they add a consideration here and every contact
## starts feeling them without this file changing.
##
## Each scores in `[-1, +1]` so considerations from different systems stay
## comparable and no system can dominate by choosing a larger scale. The actor's
## **personality weights** decide how much each one actually counts.

const KINDS: Array[StringName] = [DecisionKind.ORDER_COMPLIANCE]

## Above this the contact is well disposed, below it he is not.
const NEUTRAL: float = Relationship.NEUTRAL_LOYALTY

## A request costing this much is as costly as anything gets.
const COSTLY: float = 1000.0


static func register_all() -> void:
	Deliberation.register_consideration(LoyaltyConsideration.new(&"loyalty"), KINDS)
	Deliberation.register_consideration(CostConsideration.new(&"cost_of_request"), KINDS)
	Deliberation.register_consideration(PaymentConsideration.new(&"payment_offered"), KINDS)
	Deliberation.register_consideration(AutonomyConsideration.new(&"autonomy"), KINDS)
	Deliberation.register_consideration(ClarityConsideration.new(&"order_clarity"), KINDS)
	Deliberation.register_consideration(HarshnessConsideration.new(&"harshness"), KINDS)
	Deliberation.register_consideration(DissonanceConsideration.new(&"against_his_judgement"), KINDS)
	Deliberation.register_filter(FullPaymentIsAYes.new(&"full_payment_is_a_yes"), KINDS)
	# 🔒 **Tone belongs to compliance and sits in this kernel** (#260,
	# `tone.md` §5). A sibling file only because five tables and five classes
	# would bury the rest of this one — it registers here, against this decision
	# kind, and is weighted by personality like everything above it.
	ToneConsiderations.register_all(KINDS)


## Being leaned on (`rebel-sentiment.md` §4).
##
## **A harsh order is the most likely thing to actually be obeyed**, which is the
## whole reason the PC would write one. It pushes hard towards compliance and
## away from the sideways answers — a man told plainly does not quietly
## reinterpret the instruction, and he does not put it off and hope.
##
## He may still refuse outright. That is the point of it being a consideration
## and not a filter: a governor who has had enough can still say no, and a harsh
## order to a man who despises the PC is how a refusal becomes a rupture rather
## than a shrug.
##
## It is a **weight, not a rule**, so personality still decides. A proud man
## minds being commanded more than a dutiful one, and the same letter lands
## differently on the two of them.
##
## 🔒 **And that weight is mettle** (#260, `tone.md` §5). The trait that decides
## how he takes the hostile tones decides how he takes being commanded, because a
## man who resents being bullied resents the threat and the contempt alike. This
## class does not know that: `Temperament` writes the number and the kernel
## reads it, which is why there is no branch here on who is reading.
class HarshnessConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.COMPLY: 1.0,
		Compliance.PARTIAL: -0.2,
		Compliance.DELAY: -0.8,
		Compliance.REINTERPRET: -1.0,
		Compliance.REFUSE: -0.3,
		Compliance.ACT_ALONE: -0.9,
	}

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if not bool(context.get_value("harsh", false)):
			return 0.0
		return clampf(float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## Goodwill works like a currency (SPEC §8.5). A contact who likes the PC does
## what he is asked; one who does not looks for another way.
class LoyaltyConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.COMPLY: 1.0,
		Compliance.PARTIAL: 0.2,
		Compliance.DELAY: -0.3,
		Compliance.REINTERPRET: -0.4,
		Compliance.REFUSE: -1.0,
		Compliance.ACT_ALONE: -1.0,
	}

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var standing: float = (float(context.get_value("loyalty", NEUTRAL)) - NEUTRAL) / NEUTRAL
		return clampf(standing * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## What the PC is asking for. A large request is easier to shave, to put off, or
## to decline than a small one.
class CostConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.COMPLY: -1.0,
		Compliance.PARTIAL: 0.6,
		Compliance.DELAY: 0.5,
		Compliance.REINTERPRET: 0.3,
		Compliance.REFUSE: 0.8,
		Compliance.ACT_ALONE: 0.2,
	}

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var cost: float = clampf(float(context.get_value("cost", 0.0)) / COSTLY, 0.0, 1.0)
		return clampf(cost * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## **The Marshal troop model, generalised to every costly request**: the payment
## level chosen in the letter drives the loyalty cost, and then the chance of a
## refusal (SPEC §8.5, §12.6).
class PaymentConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.COMPLY: 1.0,
		Compliance.PARTIAL: -0.5,
		Compliance.DELAY: -0.4,
		Compliance.REINTERPRET: -0.3,
		Compliance.REFUSE: -1.0,
		Compliance.ACT_ALONE: -0.5,
	}

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var cost: float = float(context.get_value("cost", 0.0))
		if cost <= 0.0:
			# Nothing was asked of him, so there is nothing to pay for.
			return 0.0
		var paid: float = clampf(float(context.get_value("payment", 0.0)) / cost, 0.0, 1.0)
		return clampf((paid * 2.0 - 1.0) * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## **Contacts may act on their own and simply inform the PC afterward, especially
## if their loyalty is low** (SPEC §8.5).
class AutonomyConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.ACT_ALONE: 1.0,
		Compliance.REINTERPRET: 0.6,
		Compliance.REFUSE: 0.4,
		Compliance.COMPLY: -0.5,
	}

	func applies_to(candidate: Candidate) -> bool:
		return PULL.has(candidate.id)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var disaffection: float = clampf((NEUTRAL - float(context.get_value("loyalty", NEUTRAL))) / NEUTRAL, 0.0, 1.0)
		return clampf(disaffection * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## **How they read vague orders** (SPEC §8).
##
## Reinterpretation needs an axis of its own. Without one it is dominated
## everywhere — a disaffected contact acts alone instead, and a put-upon one
## refuses — so it could never actually happen. What invites it is not dislike
## but **ambiguity**: an order with no figure in it leaves room to decide what the
## PC must have meant.
##
## Which is also why the PC saying exactly what he wants is a real choice, rather
## than flavour.
class ClarityConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.REINTERPRET: 1.0,
		Compliance.COMPLY: -0.6,
		Compliance.PARTIAL: 0.2,
		Compliance.DELAY: 0.2,
	}

	func applies_to(candidate: Candidate) -> bool:
		return PULL.has(candidate.id)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var vagueness: float = float(context.get_value("vagueness", 0.0))
		return clampf(vagueness * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## Being told to do something he thinks is wrong (#213).
##
## 🔒 **It changes the manner of his answer and never the decision.**
## `contacts.md` §3 locks the two-stage split: compliance decides whether he
## engages with the letter, and his phase 8 deliberation decides whether he
## agrees with it, where `crown_urging` and `native_threat` meet as two of eight
## weighted considerations and the better argument wins. This does not move that
## decision here, and must not.
##
## What it fixes is that a governor whose border is threatened and a governor
## with nothing to worry about answered "attend to the colony's profit"
## **identically**, because `urge_intent` costs nothing and cost was the only
## thing carrying the weight of an ask.
##
## 🔒 **It does not pull toward refusing.** Refusing is about regard — a man who
## disagrees but likes the PC finds a way to do both, and the way he finds is
## reinterpretation:
##
## > *I have read Your Grace's instruction regarding our profits, and have
## > applied it to the timber we shall need for the palisade.*
##
## Weighted by personality like every other, so a dutiful man swallows it and a
## proud one does not.
class DissonanceConsideration:
	extends Consideration

	const PULL: Dictionary = {
		Compliance.REINTERPRET: 1.0,
		Compliance.ACT_ALONE: 0.8,
		Compliance.DELAY: 0.35,
		Compliance.COMPLY: -0.9,
		# 🔒 Not refuse. Deliberately absent rather than set to zero, so that
		# anybody adding it has to come past this comment.
	}

	func applies_to(candidate: Candidate) -> bool:
		return PULL.has(candidate.id)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var against: float = clampf(float(context.get_value("dissonance", 0.0)), 0.0, 1.0)
		return clampf(against * float(PULL.get(candidate.id, 0.0)), -1.0, 1.0)


## **Full payment is a guaranteed yes** while crown standing can cover it
## (SPEC §12.6).
##
## A filter rather than a heavy weight, because a guarantee that can lose a close
## vote is not a guarantee. Crown standing is M3; until then the Crown always
## pays, and the seam is the `can_crown_pay` flag the context carries.
class FullPaymentIsAYes:
	extends DeliberationFilter

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != Compliance.REFUSE:
			return true
		var cost: float = float(context.get_value("cost", 0.0))
		if cost <= 0.0:
			return true
		if not bool(context.get_value("can_crown_pay", true)):
			return true
		return float(context.get_value("payment", 0.0)) < cost
