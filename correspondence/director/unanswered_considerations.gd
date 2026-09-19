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


## **In his own interest.** An option that grants him something looks good; one
## that refuses him or costs him does not.
class SelfInterestConsideration:
	extends Consideration

	## What each effect is worth to the person on the other end of it.
	const WORTH: Dictionary = {
		"promise_gold": 1.0,
		"promise_resource": 0.8,
		"grant_favor": 0.7,
		"request_troops": -0.4,
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
