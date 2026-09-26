class_name Silence
extends RefCounted

## What happens when the PC does not reply.
##
## Choosing not to reply is **always** an option, and its consequence depends on
## what the letter asked for (SPEC §9.3):
##
## | Letter asks for | Effect of no reply |
## | :--- | :--- |
## | A **request** — resources, funds, favours, permission | A **rude refusal**. The sender loses loyalty. |
## | A **decision** | The sender **decides for himself**. He loses loyalty for being ignored. |
## | **Nothing** — reports, news | No penalty. |
##
## **A culled letter and an ignored letter are not the same.** Culling means the
## contact never consulted the PC and handled it himself: no loyalty loss.
## Ignoring means he asked and was not answered. The outcomes look similar in the
## world and are entirely different in the Relationship — which is the whole
## reason the distinction is worth code.

const EVENT_IGNORED: StringName = &"letter_ignored"
const EVENT_DECIDED_ALONE: StringName = &"decided_without_the_pc"


## Resolve every letter the player left unanswered when the post went.
static func resolve_unanswered(run: RunState, content: ContentDatabase) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for inbound in run.inbox:
		if inbound.status != InboundLetter.SET_ASIDE:
			continue
		if not content.has_record("letters", inbound.letter_id):
			continue
		var letter := Letter.from_record(content.record("letters", inbound.letter_id))
		var contact := run.contact(inbound.sender)
		if contact == null:
			continue
		resolved.append(resolve_one(contact, letter, inbound, run))
	return resolved


## 🔒 **What being unanswered costs him** (#390, *Distant colony*).
##
## **One in every run without the quirk**, and below one under it: a man who
## knows his letter spent two months on a ship does not conclude he is being
## ignored the moment it goes unanswered. **He gives the ocean the benefit of the
## doubt**, which is the half of the quirk that makes distance liveable rather
## than merely slower.
##
## It scales the deed and not the letter, so a contact who was *going* to mind
## still minds — less.
static var _costs: float = 1.0


static func costs() -> float:
	return _costs


static func set_cost_scale(scale: float) -> void:
	_costs = maxf(0.0, scale)


static func reset() -> void:
	_costs = 1.0


static func resolve_one(contact: Contact, letter: Letter, inbound: InboundLetter, run: RunState) -> Dictionary:
	# Reports and news asked for nothing, so silence costs nothing.
	if not letter.silence_is_refusal() and not letter.silence_is_a_decision():
		return {"letter": letter.id, "outcome": "no_penalty"}

	# **He asked and was not answered**, which costs either way.
	var moved := contact.relationship.record_deed(Relationship.IGNORED, _costs)
	# **Being unanswered is a thing that happened to him**, and he can name the
	# month it did (#127).
	contact.relationship.remember(
		Relationship.IGNORED, run.world.month, 0.0, String(letter.type)
	)
	run.log.emit(EVENT_IGNORED, contact.id, run.world.month, {
		"letter": letter.id,
		"type": String(letter.type),
		"loyalty_change": moved,
	}, WorldPhase.RECKONING)

	if letter.silence_is_a_decision():
		var decision := decide_alone(contact, letter, inbound, run, true)
		return {"letter": letter.id, "outcome": "decided_alone", "decision": decision}

	return {"letter": letter.id, "outcome": "rude_refusal", "loyalty_change": moved}


## The sender decides for himself.
##
## **Through the deliberation kernel, not a coin flip.** He weighs the same
## options the PC would have been offered and picks one, so what he does is
## in character and the trace says why.
##
## `was_ignored` separates the two origins: false when the letter was culled and
## he simply never asked, true when he asked and was not answered.
static func decide_alone(
	contact: Contact,
	letter: Letter,
	inbound: InboundLetter,
	run: RunState,
	was_ignored: bool,
) -> Decision:
	var steps := letter.steps()
	if steps.is_empty():
		return null

	var step: Dictionary = steps[0]
	var candidates: Array = []
	for option in step.get(LetterSchema.KEY_OPTIONS, []):
		candidates.append(Candidate.new(StringName(option.get("id", "")), {
			"option": option,
			"effect": option.get(LetterSchema.KEY_EFFECT, {}),
		}))
	if candidates.is_empty():
		return null

	var context := DeliberationContext.new(DecisionKind.UNANSWERED, run.world, run.log)
	context.phase = WorldPhase.RECKONING
	context.rng = run.streams.contact_stream(String(contact.id))
	context.diff = run.last_diff
	context.data = {
		"letter": letter.id,
		"was_ignored": was_ignored,
		"loyalty": contact.loyalty(),
	}

	var decision := Deliberation.choose(contact, candidates, context)
	var done := carry_out(contact, candidates, inbound, run, decision)

	run.log.emit(EVENT_DECIDED_ALONE, contact.id, run.world.month, {
		"letter": letter.id,
		"chose": String(decision.chosen_id()),
		"was_ignored": was_ignored,
		"inbound": String(inbound.id),
		# What he set in motion, by kind: the Intents carry the rest.
		"did": done,
	}, WorldPhase.RECKONING)

	return decision


## 🔒 **What he decided, he does** (#450, SPEC §9.3, `contacts.md` §3).
##
## The option he chose is carried out as his own will: each of its effects
## becomes the Order it would have been had the PC chosen it, and each Order the
## Intent a contact acting alone commits (Seam C). The same path as *acting
## alone* with a different origin, which is what §8.5 asks of the two. It used to
## end at the event: nothing read the choice, and a decision left to him changed
## nothing at all.
##
## Returns the kinds of what he set in motion, in effect-id order.
static func carry_out(
	contact: Contact,
	candidates: Array,
	inbound: InboundLetter,
	run: RunState,
	decision: Decision,
) -> Array:
	var done: Array = []
	if decision == null or not decision.has_choice() or run.intents == null:
		return done
	var chosen: Candidate = null
	for entry in candidates:
		if (entry as Candidate).id == decision.chosen_id():
			chosen = entry
	if chosen == null:
		return done
	var effects: Variant = chosen.get_value("effect", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return done

	var context := LetterContext.new(run.world, contact, &"")
	context.month = run.world.month
	context.params = inbound.params
	var ids: Array = (effects as Dictionary).keys()
	ids.sort()
	for effect_id in ids:
		var order := ContentRegistry.run_effect(String(effect_id), effects[effect_id], context)
		if order == null:
			continue
		run.intents.commit(Compliance.as_his_own_will(order, contact), run.log, run.world.month)
		done.append(String(order.kind))
	return done
