class_name Director
extends RefCounted

## Decides **who writes to the PC this month and about what**.
##
## Kept strictly apart from the engine that decides **how a letter reads** (#8,
## #9). Triggers live in `data/triggers/*.json` and hold no prose, which also
## keeps them free of localisation. The letter file declares its `params`; the
## director supplies them. The letter never re-decides what it is about.
##
## This is the most genuinely new design in M1 and expects to be revised after
## playtest.

# --- Volume (SPEC §9.6) ----------------------------------------------------
#
# **🔒 The phase of a run is set by the calendar year**, not the colony's size.
# Year boundaries and the budgets themselves are tuning values.

const EARLY_UNTIL_YEAR: int = 2
const MID_UNTIL_YEAR: int = 5

const EARLY_BUDGET: int = 6
const MID_BUDGET: int = 12
const LATE_BUDGET: int = 20

## Months before the same letter may arrive again.
##
## Without this the same three triggers fire every month and the Author reads the
## same correspondence twelve times — which is the failure #20 warns about, and
## it lands on the director rather than on the world. A trigger may set its own
## `cooldown`; a standing report wants a short one, a crisis letter a long one.
const DEFAULT_COOLDOWN: int = 3

const EVENT_CULLED: StringName = &"letter_culled"
const EVENT_DISPATCHED: StringName = &"letter_dispatched"

var content: ContentDatabase = null

## Letters the director could not acknowledge because no content exists for it
## yet. #24 authors that content; this is the checklist.
var unacknowledged: PackedStringArray = PackedStringArray()


func _init(p_content: ContentDatabase = null) -> void:
	content = p_content


## **Volume targets are tuning, not an enforced cap** — a player running wide may
## legitimately exceed them.
static func budget_for_year(year: int) -> int:
	if year <= EARLY_UNTIL_YEAR:
		return EARLY_BUDGET
	if year <= MID_UNTIL_YEAR:
		return MID_BUDGET
	return LATE_BUDGET


# --- Choosing the month's post ---------------------------------------------

## Build this turn's inbox.
func compose_inbox(run: RunState, outcomes: Array = []) -> Array[InboundLetter]:
	unacknowledged = PackedStringArray()

	var fired := _fired_triggers(run)
	var acknowledging := _acknowledgements(run, outcomes)
	var letters := _cull(fired, acknowledging, run)

	for letter in letters:
		run.letters_sent[letter.letter_id] = run.world.month
		run.log.emit(EVENT_DISPATCHED, letter.sender, run.world.month, {
			"letter": letter.letter_id,
			"tone": String(letter.tone),
		}, WorldPhase.DISPATCH)
	return letters


## Every trigger whose conditions hold, in trigger id order so the result does
## not depend on how the files were loaded.
func _fired_triggers(run: RunState) -> Array[InboundLetter]:
	var fired: Array[InboundLetter] = []
	for trigger_id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[trigger_id]
		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue

		if _too_soon(trigger, letter_id, run):
			continue

		var letter := Letter.from_record(content.record("letters", letter_id))
		var contact := run.contact(StringName(letter.sender))
		if contact == null:
			continue

		var context := _context(run, contact)
		if not _conditions_hold(trigger, context):
			continue

		fired.append(_inbound(trigger, letter, contact, context, run))
	return fired


## Whether this letter arrived too recently to arrive again.
func _too_soon(trigger: Dictionary, letter_id: String, run: RunState) -> bool:
	if not run.letters_sent.has(letter_id):
		return false
	var cooldown := int(trigger.get("cooldown", DEFAULT_COOLDOWN))
	return run.world.month - int(run.letters_sent[letter_id]) < cooldown


func _conditions_hold(trigger: Dictionary, context: LetterContext) -> bool:
	for entry in trigger.get("conditions", []):
		for condition_id in entry:
			if not ContentRegistry.test_condition(String(condition_id), entry[condition_id], context):
				return false
	return true


func _context(run: RunState, contact: Contact) -> LetterContext:
	var context := LetterContext.new(run.world, contact, &"")
	context.diff = run.last_diff
	context.measures = StubWorld.measures(run.world)
	return context


## Build the letter that will land on the desk, values and tone included.
func _inbound(trigger: Dictionary, letter: Letter, contact: Contact, context: LetterContext, run: RunState) -> InboundLetter:
	var inbound := InboundLetter.new(letter.id, StringName(letter.sender), &"")
	inbound.id = StringName("inbound_%d_%s" % [run.turn, letter.id])
	inbound.month = run.world.month
	inbound.measures = context.measures.duplicate()
	inbound.params = _supply_params(trigger, letter, context)
	inbound.tone = tone_for(contact, float(trigger.get("urgency", 0.0)))
	return inbound


## **Every declared param is supplied, at the right type, before rendering.**
func _supply_params(trigger: Dictionary, letter: Letter, context: LetterContext) -> Dictionary:
	var sources: Dictionary = trigger.get("params", {})
	var supplied: Dictionary = {}

	var names: Array = letter.params.keys()
	names.sort()
	for name in names:
		var declared := StringName(letter.params[name])
		var value: Variant = null

		if sources.has(name):
			var spec: Variant = sources[name]
			if typeof(spec) == TYPE_DICTIONARY and spec.has("from"):
				var args: Dictionary = spec.duplicate()
				var source_id := String(args["from"])
				args.erase("from")
				value = ContentRegistry.supply_param(source_id, args, context)
			else:
				value = spec
		else:
			push_error("Trigger supplies no value for '%s', declared by '%s'." % [name, letter.id])

		supplied[name] = _coerce(value, declared, "%s.%s" % [letter.id, name])
	return supplied


## Coerce against the declared type. Godot's JSON parser returns every number as
## a float, so `integer` and `gold` have to be pinned here or `{param:amount}`
## renders "200.0" at the player.
static func _coerce(value: Variant, declared: StringName, context_label: String) -> Variant:
	if LetterSchema.NUMERIC_PARAM_TYPES.has(declared):
		return JsonTypes.to_int(value, context_label)
	return value


# --- Tone ------------------------------------------------------------------

## The one tone id this sender writes in.
##
## SPEC §9.1 already defines incoming tone as exactly this compression of
## loyalty, personality, circumstance and urgency. Downstream code treats it as
## **opaque** and never re-derives circumstance from it.
##
## This bands *loyalty*, which is ordered. It does not order the **tones** — the
## five have no sequence, and nothing anywhere asks whether one tone is worse
## than another.
static func tone_for(contact: Contact, urgency: float = 0.0) -> StringName:
	var loyalty := contact.loyalty()

	if urgency >= 0.7 and loyalty < 70.0:
		return Tone.DESPERATE
	if loyalty >= 70.0:
		return Tone.PLEASED
	if loyalty >= 45.0:
		return Tone.DUTIFUL
	if loyalty >= 20.0:
		return Tone.ANNOYED
	return Tone.HATEFUL


# --- Acknowledgement -------------------------------------------------------

## **Each month's letters acknowledge the decisions sent in last month's post**
## (SPEC §9.1).
##
## A letter that acknowledges an outcome is never culled, whatever the budget:
## the player must always learn what became of what he wrote. Where no content
## exists for an outcome yet, it is recorded in `unacknowledged` rather than
## passing silently — #24 writes that content, and this is its checklist.
func _acknowledgements(run: RunState, outcomes: Array) -> Array[InboundLetter]:
	var letters: Array[InboundLetter] = []
	for result in outcomes:
		var order: Order = result["order"]
		var outcome := String(result["outcome"])
		var contact := run.contact(order.addressed_to)
		if contact == null:
			continue

		var letter_id := _acknowledgement_letter(String(order.addressed_to), outcome)
		if letter_id.is_empty():
			unacknowledged.append("%s/%s" % [order.addressed_to, outcome])
			continue

		var letter := Letter.from_record(content.record("letters", letter_id))
		var context := _context(run, contact)
		var inbound := _inbound({}, letter, contact, context, run)
		inbound.id = StringName("inbound_%d_ack_%s" % [run.turn, order.id])
		letters.append(inbound)
	return letters


## A trigger marked `"acknowledges"` for this sender and outcome, or "".
func _acknowledgement_letter(sender: String, outcome: String) -> String:
	for trigger_id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[trigger_id]
		if String(trigger.get("acknowledges", "")) != outcome:
			continue
		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue
		if String(content.record("letters", letter_id).get("sender", "")) == sender:
			return letter_id
	return ""


# --- Culling ---------------------------------------------------------------

## Trim the month's post to the budget.
##
## **Letters marked `skippable: false` always reach the desk**, and so does
## anything acknowledging last month's post. Only skippable letters are culled,
## and the outcome derives from the letter's `type`, needing no extra authoring.
func _cull(fired: Array[InboundLetter], acknowledging: Array[InboundLetter], run: RunState) -> Array[InboundLetter]:
	var budget := budget_for_year(run.world.year_index())

	var kept: Array[InboundLetter] = acknowledging.duplicate()
	var cullable: Array[InboundLetter] = []

	for inbound in fired:
		var letter := Letter.from_record(content.record("letters", inbound.letter_id))
		if letter.skippable:
			cullable.append(inbound)
		else:
			kept.append(inbound)

	for inbound in cullable:
		if kept.size() < budget:
			kept.append(inbound)
		else:
			_cull_one(inbound, run)

	return kept


## What happens to a letter the player never sees.
##
## **A culled letter is not an ignored one** (#18). Culling means the contact
## never consulted the PC and handled it himself, so there is **no loyalty
## loss**; ignoring means he asked and was not answered, which costs.
func _cull_one(inbound: InboundLetter, run: RunState) -> void:
	var letter := Letter.from_record(content.record("letters", inbound.letter_id))
	var outcome := "nothing"

	match letter.type:
		LetterSchema.TYPE_REQUEST, LetterSchema.TYPE_DEMAND, LetterSchema.TYPE_OFFER:
			# He takes it as a polite no.
			outcome = "polite_no"
		LetterSchema.TYPE_QUESTION:
			# He uses his own judgement, through the kernel.
			outcome = "decided_alone"
			var contact := run.contact(inbound.sender)
			if contact != null:
				Silence.decide_alone(contact, letter, inbound, run, false)

	run.log.emit(EVENT_CULLED, inbound.sender, run.world.month, {
		"letter": inbound.letter_id,
		"type": String(letter.type),
		"outcome": outcome,
	}, WorldPhase.DISPATCH)
