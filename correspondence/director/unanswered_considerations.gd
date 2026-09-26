class_name UnansweredConsiderations
extends RefCounted

## What a contact weighs when he has to decide something the PC would not answer.
##
## SPEC §9.3: he decides **"either at random or in their own interest, depending
## on personality"**. Those are the two considerations, and which of them wins is
## the contact's weight vector rather than a branch — a capricious contact is one
## who weights `caprice` highly, and no code anywhere asks whether a contact is
## the capricious kind.

const KINDS: Array[StringName] = [DecisionKind.UNANSWERED]


static func register_all() -> void:
	Deliberation.register_consideration(SelfInterestConsideration.new(&"self_interest"), KINDS)
	Deliberation.register_consideration(CapriceConsideration.new(&"caprice"), KINDS)
	# ⚠ Provisional, pending the PO's ruling on #450 — see the class.
	Deliberation.register_filter(NotOnTheCrownsPurse.new(&"not_on_the_crowns_purse"), KINDS)


## ⚠ **Provisional: he does not spend the Crown's money** (#450).
##
## A decision left to him is now carried out, and `SelfInterestConsideration`
## values a promise of gold highest — so a man left alone would pick the option
## that pays him from the Crown's purse. **Whether he may is the PO's to rule**,
## in `contacts.md` §3. Until then he may not: an answer the PC never gave does
## not commit the Crown's money.
##
## A filter and not a weight, because whichever way it is ruled it is a rule
## (`deliberation.md` §5). Ruled the other way, this class and its registration
## are deleted and nothing else changes.
class NotOnTheCrownsPurse:
	extends DeliberationFilter

	## Effects that pay out of the Crown's purse whatever their arguments.
	const CROWN_PAID: Array = [
		"promise_gold", "promise_gold_to_town", "fund_policy", "ship_resource_paying_double",
	]

	func permits(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> bool:
		var effects: Variant = candidate.get_value("effect", {})
		if typeof(effects) != TYPE_DICTIONARY:
			return true
		for effect_id in effects:
			if spends_the_crowns_money(String(effect_id), effects[effect_id]):
				return false
		return true

	## A policy the Crown pays some of, or a payment that is not nought.
	static func spends_the_crowns_money(effect_id: String, args: Variant) -> bool:
		if CROWN_PAID.has(effect_id):
			return true
		if typeof(args) != TYPE_DICTIONARY:
			return false
		var split := String(args.get("split", Policy.NONE))
		if split != String(Policy.NONE):
			return true
		var payment: Variant = args.get("payment", 0)
		if typeof(payment) == TYPE_STRING:
			return not String(payment).is_empty() and String(payment) != "0"
		return float(payment) > 0.0


## **In his own interest.** An option that grants him something looks good; one
## that refuses him or costs him does not.
class SelfInterestConsideration:
	extends Consideration

	## What each effect is worth to the person on the other end of it.
	const WORTH: Dictionary = {
		"promise_gold": 1.0,
		"promise_resource": 0.8,
		"grant_favor": 0.7,
		"station_troops": -0.4,
		"adjust_loyalty": 0.2,
		"set_policy": 0.0,
		"refuse": -1.0,
	}

	func score(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> float:
		var effects: Variant = candidate.get_value("effect", {})
		if typeof(effects) != TYPE_DICTIONARY or effects.is_empty():
			return 0.0
		var total: float = 0.0
		var ids: Array = effects.keys()
		ids.sort()
		for effect_id in ids:
			total += float(WORTH.get(String(effect_id), 0.0))
		return clampf(total, -1.0, 1.0)


## **At random.** Drawn from the contact's own stream, so it is a whim rather
## than a wildcard: the same seed produces the same whim.
class CapriceConsideration:
	extends Consideration

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if context.rng == null:
			return 0.0
		# Seeded off the candidate as well as the stream, so the draw belongs to
		# this option and does not depend on the order options were scored in.
		var mixed := StableHash.of_string("%d:%s" % [context.rng.seed, candidate.id])
		return (float(mixed % 2000) / 1000.0) - 1.0
