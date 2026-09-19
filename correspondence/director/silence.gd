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


static func resolve_one(contact: Contact, letter: Letter, inbound: InboundLetter, run: RunState) -> Dictionary:
	# Reports and news asked for nothing, so silence costs nothing.
	if not letter.silence_is_refusal() and not letter.silence_is_a_decision():
		return {"letter": letter.id, "outcome": "no_penalty"}

	# **He asked and was not answered**, which costs either way.
	var moved := contact.relationship.record_deed(Relationship.IGNORED)
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

	run.log.emit(EVENT_DECIDED_ALONE, contact.id, run.world.month, {
		"letter": letter.id,
		"chose": String(decision.chosen_id()),
		"was_ignored": was_ignored,
		"inbound": String(inbound.id),
	}, WorldPhase.RECKONING)

	return decision
