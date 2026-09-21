class_name Composer
extends RefCounted

## Writing to somebody unprompted (SPEC §9.4).
##
## **A player-initiated letter is the same file shape as a reply, minus the
## `body`.** One format, not two — which is why composing reuses `ReplyWizard`
## whole rather than a copy of it, and why a purpose gets a tone block and steps
## for free.
##
## ## The flow
##
## ```
## what is this letter about?  ->  who should receive it?  ->  [the reply wizard]
## ```
##
## **Purpose first, not contact first.** #19 left this open. Contact first reads
## more naturally in fiction, and on a phone it survives fifteen contacts — but
## contacts keep arriving: a governor per town, patrons coming and going,
## institutional contacts from buildings. The list only grows.
##
## The deciding argument is not screen length though. The player's actual
## question is "I want to do X — who can do it?", and asking the purpose first
## lets the game offer **only the recipients for whom that purpose is valid**.
## Invalid pairings become unrepresentable rather than merely hidden, which is
## one fewer way for a letter to exist that nobody can act on.
##
## Availability lives in triggers, never in the letter file, for the same reason
## firing conditions do: a letter file holds prose and mechanics, not when.

const OFFERS_KEY: String = "offers_composition"

## The param naming whoever the player chose to write to. Supplied by the flow
## rather than declared with a default, since the recipient *is* the choice.
const RECIPIENT_PARAM: String = "to"


var content: ContentDatabase = null


func _init(p_content: ContentDatabase = null) -> void:
	content = p_content


## Purposes the player may write about at all, given the state of the run.
##
## `[{letter_id, purpose, recipients}]`, in letter id order.
func purposes(run: RunState) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []

	for trigger_id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[trigger_id]
		if not bool(trigger.get(OFFERS_KEY, false)):
			continue

		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue
		var letter := Letter.from_record(content.record("letters", letter_id))

		var recipients := recipients_for(letter, run, trigger)
		if recipients.is_empty():
			continue

		offered.append({
			"letter_id": letter_id,
			"purpose": letter.purpose,
			"recipients": recipients,
		})

	offered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["letter_id"]) < String(b["letter_id"]))
	return offered


## **Only recipients for whom this purpose is valid**, in id order.
##
## The purpose says which roles it makes sense for, and the trigger's conditions
## are evaluated **per recipient** — so "ask for troops" can be available for the
## Marshal and not for the Steward, and unavailable even for the Marshal when the
## state says so.
func recipients_for(letter: Letter, run: RunState, trigger: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if not letter.to_roles.is_empty() and not letter.to_roles.has(String(contact.role)):
			continue

		var context := LetterContext.new(run.world, contact, &"")
		context.diff = run.last_diff
		var allowed := true
		for entry in trigger.get("conditions", []):
			for condition_id in entry:
				if not ContentRegistry.test_condition(String(condition_id), entry[condition_id], context):
					allowed = false
					break
			if not allowed:
				break
		if allowed:
			out.append(contact.id)
	return out


## Begin composing. Returns a wizard over a fresh outgoing letter, already added
## to the post so it can be rewritten or discarded before the post is sent.
func begin(run: RunState, letter_id: String, to: StringName) -> ReplyWizard:
	if not content.has_record("letters", letter_id):
		push_error("No letter '%s'." % letter_id)
		return null

	var letter := Letter.from_record(content.record("letters", letter_id))
	var outgoing := OutgoingLetter.new(letter_id, to)
	# An unprompted letter answers nothing, which is what `in_reply_to` being
	# empty means downstream.
	outgoing.in_reply_to = &""
	outgoing.params = _params_for(letter, run, to)
	run.post.add(outgoing)
	return ReplyWizard.new(letter, outgoing)


## A composed letter's params come from the world at the moment of writing, since
## there is no incoming letter to have carried them.
func _params_for(letter: Letter, run: RunState, to: StringName) -> Dictionary:
	var contact := run.contact(to)
	var context := LetterContext.new(run.world, contact, &"")
	context.diff = run.last_diff
	context.measures = ColonyMeasures.for_contact(run, contact)
	context.town = run.colony.governed_by(contact.id) if run.colony != null else null
	context.refusal = run.refusal
	context.prestige = run.prestige
	context.demands = run.demands
	context.demand_book = run.demand_book
	context.log = run.log
	context.pc = run.setup
	context.policies = run.policies

	# The recipient is chosen in the flow, not declared with a default, so
	# `{to}` in an effect resolves to whoever the player picked.
	var supplied: Dictionary = {RECIPIENT_PARAM: String(to)}
	var names: Array = letter.params.keys()
	names.sort()
	for name in names:
		if String(name) == RECIPIENT_PARAM:
			continue
		var declared := StringName(letter.params[name])
		var value: Variant = letter.compose_defaults.get(name)
		if typeof(value) == TYPE_DICTIONARY and value.has("from"):
			var args: Dictionary = value.duplicate()
			var source_id := String(args["from"])
			args.erase("from")
			value = ContentRegistry.supply_param(source_id, args, context)
		if LetterSchema.NUMERIC_PARAM_TYPES.has(declared):
			value = JsonTypes.to_int(value if value != null else 0, "%s.%s" % [letter.id, name])
		supplied[name] = value
	return supplied
