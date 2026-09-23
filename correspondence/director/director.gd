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

## The stream both draws come from: who still consults, and who survives a
## cull. **Named, like every other** — the month's post must not shift because
## mapgen happened to draw a different number of times.
const STREAM: String = "letters"

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
		run.letters_sent[sent_key(letter.letter_id, letter.sender)] = run.world.month
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

		# A trigger that answers an outcome fires only when that outcome happens,
		# and one that offers a purpose fires only when the player composes. Left
		# in the ordinary sweep they fire on their own — and being unskippable,
		# acknowledgements then crowd out every real letter with news of orders
		# nobody gave.
		if trigger.has("acknowledges") or bool(trigger.get(Composer.OFFERS_KEY, false)):
			continue

		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue

		var letter := Letter.from_record(content.record("letters", letter_id))
		for entry in senders_of(letter, run):
			var contact: Contact = entry
			# 🔒 **Cooldown is per man, not per letter** (#361). Two governors
			# both have a shortage to report; one reporting his must not silence
			# the other's for nine months.
			if _too_soon(trigger, letter_id, contact, run):
				continue

			var context := _context(run, contact)
			# 🔒 **Conditions still gate** (#254). They say whether a letter is
			# *true*; pressure says whether he *bothers*. A letter that is not
			# true is never a candidate whatever he feels about the world.
			if not _conditions_hold(trigger, context):
				continue

			fired.append(_inbound(trigger, letter, contact, context, run))
	return _only_what_they_want_to_say(_still_consulting(fired, run), run)


## Everybody who could send this letter, sorted (#361).
##
## 🔒 **A named man, or a role.** `sender` is read as a contact id first, so
## every letter addressed to one particular office — the Chancellor, the Steward,
## the Marshal — behaves exactly as it always has. A `sender` that names nobody
## is read as a **role**, and expands to one candidate per contact holding it,
## each with his own context.
##
## That is what the folder layout always implied and what the director never
## did: before this, `sender: "governor"` matched no contact and was skipped in
## silence every month for ever — six letters that could never fire, two of them
## SPEC §12.3's entire rebellion arc — while sixteen more were bound to the
## capital's fixed id and no second town's governor wrote anything at all.
##
## 🔒 **And it needs no new volume control.** `Threshold` already raises a man's
## bar for each further contact of a redundant role, and already lists governors,
## institutional contacts, commanders and patrons as roles a colony accumulates.
## That rule has simply never had a second governor to apply to.
func senders_of(letter: Letter, run: RunState) -> Array:
	var named := run.contact(StringName(letter.sender))
	if named != null:
		return [named]
	if not Contact.is_role(StringName(letter.sender)):
		return []

	var out: Array = []
	var ids: Array = run.contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = run.contacts[id]
		if contact != null and not contact.is_dead 				and contact.role == StringName(letter.sender):
			out.append(contact)
	return out


## Take out the questions and offers of the men who have stopped asking.
##
## 🔒 **Loyalty gates the kind of letter, not the number** (#259, §10). A disliked
## PC's desk is not quieter — it is **hollowed out**. The same stack of paper
## arrives and far fewer of them are decisions: he is still being asked for
## things, he has simply stopped being consulted.
##
## So the gate runs **before** selection. A question a man will not ask is not a
## candidate at all, and the report or request he also had to send takes the slot
## instead. Raising his threshold would have made him quieter, which is the one
## thing §10 says this must not do.
##
## **One draw per man per month, not one per letter.** Whether he still consults
## the Crown is a fact about him this month; drawing per letter would let him ask
## one question and withhold another in the same post, which is a man in two minds
## rather than a man who has given up on his governor.
##
## He settles the strongest of them himself, by the path a culled question takes
## (§12). No loyalty is lost either way — **he never asked.**
func _still_consulting(fired: Array[InboundLetter], run: RunState) -> Array[InboundLetter]:
	var withheld: Dictionary = {}
	var senders: Array = []
	for inbound in fired:
		if not senders.has(String(inbound.sender)):
			senders.append(String(inbound.sender))
	senders.sort()

	var rng := run.streams.stream(STREAM)
	for sender in senders:
		var contact := run.contact(StringName(sender))
		if Consultation.consults(contact, rng):
			continue
		var his: Array[InboundLetter] = []
		# Withheld **by position**, because two letters on one desk may share an
		# id and §13 means to allow that.
		for index in fired.size():
			if String(fired[index].sender) != sender:
				continue
			if Consultation.is_consultative(_type_of(fired[index])):
				his.append(fired[index])
				withheld[index] = true
		_settles_it_himself(contact, his, run)

	if withheld.is_empty():
		return fired

	var asking: Array[InboundLetter] = []
	for index in fired.size():
		if not withheld.has(index):
			asking.append(fired[index])
	return asking


## The one he would have raised, settled without the PC.
##
## **The strongest of them**, ties on the letter id, which is the same order
## severity would have put them in (#257, §7) without needing his pressure — the
## question here is not which letter he sends but which one he has had to decide
## for himself.
func _settles_it_himself(contact: Contact, his: Array[InboundLetter], run: RunState) -> void:
	if contact == null or his.is_empty():
		return
	var loudest: InboundLetter = null
	var speaks_to := -1.0
	for inbound in his:
		var felt := Severity.of(content.record("letters", inbound.letter_id))
		if loudest == null or felt > speaks_to + 0.0001 \
				or (absf(felt - speaks_to) <= 0.0001
					and inbound.letter_id < loudest.letter_id):
			loudest = inbound
			speaks_to = felt
	var letter := Letter.from_record(content.record("letters", loudest.letter_id))
	Silence.decide_alone(contact, letter, loudest, run, false)


func _type_of(inbound: InboundLetter) -> StringName:
	return StringName(content.record("letters", inbound.letter_id).get("type", ""))


## Thin the true letters down to the ones their senders actually want to send.
##
## 🔒 **A contact writes one letter per month at most** (#254, §3), and only when
## a topic he cares about clears his threshold. A man with three grievances
## writes about the worst of them.
##
## 🔒 **A must-send letter bypasses pressure** (§2). `skippable: false` already
## meant *never culled*; it now also means *ignores the dampers and the
## threshold*, because there is no deliberation about whether to trouble the
## Crown with the natives attacking. **No new field.**
##
## 🔒 **Which of his true letters he sends is severity's** (#257, §7). A topic
## usually has several letters — *give us a break* and *they cannot bear it* are
## the same concern said at two strengths — and he sends the strongest whose bar
## the pressure clears.
func _only_what_they_want_to_say(
	fired: Array[InboundLetter],
	run: RunState,
) -> Array[InboundLetter]:
	var kept: Array[InboundLetter] = []
	var spoken: Dictionary = {}
	# 🔒 **Redundancy is the only volume control that scales** (#255). Computed
	# once for the roster rather than per man, because the answer is about the
	# roster and a wide colony has a great many men in it.
	var ranks := Threshold.ranks_in(run.contacts)

	for inbound in fired:
		var record: Dictionary = content.record("letters", inbound.letter_id)
		if not bool(record.get(LetterSchema.KEY_SKIPPABLE, true)):
			# The natives have attacked and the governor wants orders. It goes.
			#
			# 🔒 **An unskippable letter always wins selection** (SPEC §10.3).
			# It is kept before pressure is consulted and it does not touch
			# `spoken`, so it neither loses its place to a routine question nor
			# spends the one letter the man had this month.
			#
			# The standing warning is the case that matters: it is unskippable
			# and its trigger id sorts *after* the Chancellor's routine question,
			# so a rule that took the first true letter a contact had would lose
			# a letter §10.3 guarantees — and `crown-standing.md` §3 makes it a
			# gate, so the Crown could then never refuse either.
			#
			# #257 is about to rank a contact's letters against one another.
			# `test_must_send_precedence` is what stops that ranking reaching a
			# letter that was never a candidate for ranking.
			kept.append(inbound)
			continue

		var sender := String(inbound.sender)
		var contact := run.contact(inbound.sender)
		var felt := Pressure.for_contact(
			contact, inbound.measures, run.log, run.world.month, run.writings)
		var loudest := Pressure.loudest(
			felt, Threshold.for_contact(contact, int(ranks.get(sender, 0))))
		if loudest.is_empty():
			continue

		# 🔒 **The strongest whose bar the pressure clears** (#257). A letter that
		# speaks to more than he feels is out of reach; among the rest he sends
		# the one that says it hardest, rather than whichever trigger id sorted
		# first — which is what decided it before, and made a letter late in the
		# alphabet unreachable for any man who had an earlier one to send.
		var speaks_to := Severity.of(record)
		if speaks_to > float(loudest["pressure"]):
			continue
		if spoken.has(sender) and speaks_to <= float(spoken[sender]["speaks_to"]):
			continue

		if spoken.has(sender):
			kept.erase(spoken[sender]["letter"])
		spoken[sender] = {
			"topic": String(loudest["topic"]),
			"speaks_to": speaks_to,
			"letter": inbound,
		}
		kept.append(inbound)

	# **What he wrote, and about what.** Recorded here rather than in `Pressure`
	# so the dampers count a letter that was actually sent, not one that merely
	# could have been.
	#
	# 🔒 **Must-sends are not recorded** (§6, §2). They bypass both dampers, so a
	# governor reporting that the natives have attacked has not thereby had his
	# say about anything, and next month he can still raise what he meant to.
	var senders: Array = spoken.keys()
	senders.sort()
	for sender in senders:
		run.writings.record(
			StringName(sender), String(spoken[sender]["topic"]), run.world.month)
	return kept




## Whether this letter arrived too recently to arrive again.
func _too_soon(
	trigger: Dictionary, letter_id: String, contact: Contact, run: RunState
) -> bool:
	var key := sent_key(letter_id, contact.id)
	if not run.letters_sent.has(key):
		return false
	var cooldown := int(trigger.get("cooldown", DEFAULT_COOLDOWN))
	return run.world.month - int(run.letters_sent[key]) < cooldown


## 🔒 **What a cooldown remembers: this letter, from this man** (#361).
##
## Keyed by the pair because a role now expands to several men. One governor
## reporting a shortage must not silence every other governor's shortage for the
## length of the cooldown — which is the same letter about a different town.
static func sent_key(letter_id: String, sender: StringName) -> String:
	return "%s@%s" % [letter_id, sender]


func _conditions_hold(trigger: Dictionary, context: LetterContext) -> bool:
	for entry in trigger.get("conditions", []):
		for condition_id in entry:
			if not ContentRegistry.test_condition(String(condition_id), entry[condition_id], context):
				return false
	return true


func _context(run: RunState, contact: Contact) -> LetterContext:
	var context := LetterContext.new(run.world, contact, &"")
	context.diff = run.last_diff
	context.measures = ColonyMeasures.for_contact(run, contact)
	# 🔒 **The town this man lives in, however he came to live in it** (#280).
	# This asked `governed_by` and so answered null for every resident, which
	# meant no clergyman, scholar, journalist or quartermaster could write a
	# letter that mentioned the place he lives. `ColonyMeasures.home_of` is the
	# one rule — the governor by the town he governs, everybody else by the place
	# named on his own record — and asking it here rather than writing a second
	# one is what keeps a man's letters about the same town as his measures.
	context.town = ColonyMeasures.home_of(contact, run)
	context.refusal = run.refusal
	context.prestige = run.prestige
	context.colony = run.colony
	context.contacts = run.contacts
	context.natives = run.tribes
	context.demands = run.demands
	context.demand_book = run.demand_book
	context.log = run.log
	context.pc = run.setup
	context.policies = run.policies
	return context


## Build the letter that will land on the desk, values and tone included.
func _inbound(trigger: Dictionary, letter: Letter, contact: Contact, context: LetterContext, run: RunState) -> InboundLetter:
	# 🔒 **The man, never the authored string** (#361). Everything downstream
	# keys by sender — the cooldown, the one-letter-a-month rule, redundancy
	# ranks, whether he is still consulting — and with a role in that field two
	# governors would be one correspondent who wrote twice.
	var inbound := InboundLetter.new(letter.id, contact.id, &"")
	inbound.id = StringName("inbound_%d_%s_%s" % [run.turn, contact.id, letter.id])
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
	# 🔒 **A contact may be authored to write in one tone always** (#268,
	# `endings.md` §3), and exactly one is: the Chancellor is *delighted* to bring
	# the PC news of his failures, so he writes `pleased` about ruin whatever his
	# loyalty and however urgent it is.
	#
	# Read off the contact rather than branched on his id, because it is a fact
	# about the man.
	if not String(contact.writes_in).is_empty():
		return contact.writes_in

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
	# One acknowledgement per letter per turn. Two orders that came to the same
	# end are one piece of news, and the same paragraph twice on one desk reads
	# as a bug because it is one.
	var already: Dictionary = {}
	for result in outcomes:
		var order: Order = result["order"]
		var outcome := String(result["outcome"])
		var contact := run.contact(order.addressed_to)
		if contact == null:
			continue

		var trigger := _acknowledgement_trigger(String(order.addressed_to), outcome)
		if trigger.is_empty():
			unacknowledged.append("%s/%s" % [order.addressed_to, outcome])
			continue

		var letter_id := String(trigger["letter"])
		if already.has(letter_id):
			continue
		already[letter_id] = true

		var letter := Letter.from_record(content.record("letters", letter_id))
		var context := _context(run, contact)
		# The order that provoked it is a param source in its own right, so an
		# acknowledgement can say what it was you asked for.
		context.data_order = order
		var inbound := _inbound(trigger, letter, contact, context, run)
		inbound.id = StringName("inbound_%d_ack_%s" % [run.turn, order.id])
		letters.append(inbound)
	return letters


## The trigger marked `"acknowledges"` for this sender and outcome, or {}.
func _acknowledgement_trigger(sender: String, outcome: String) -> Dictionary:
	for trigger_id in content.ids("triggers"):
		var trigger: Dictionary = content.collection("triggers")[trigger_id]
		if String(trigger.get("acknowledges", "")) != outcome:
			continue
		var letter_id := String(trigger.get("letter", ""))
		if not content.has_record("letters", letter_id):
			continue
		if String(content.record("letters", letter_id).get("sender", "")) == sender:
			return trigger
	return {}


# --- Culling ---------------------------------------------------------------

## Trim the month's post to the budget.
##
## **Letters marked `skippable: false` always reach the desk**, and so does
## anything acknowledging last month's post. Only skippable letters are culled,
## and the outcome derives from the letter's `type`, needing no extra authoring.
##
## 🔒 **The budget is a ceiling and there is no floor** (#259, §11). A quiet month
## is a thin desk, and a thin desk is the correct reward for a colony running
## well. Nothing here manufactures post.
##
## 🔒 **And the desk plays out over budget when it must** (§13). The contact
## damper is per contact, so ending a policy six churches cared about brings six
## letters, and the PC answers all six or takes the loss with each. That is not
## the budget failing — the volume is the consequence, and letters of that kind
## are `skippable: false` precisely because escaping them through a cull would be
## escaping the decision.
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

	# 🔒 **Kept by position, never by id.** Two letters of the same kind can be on
	# one desk — six churches writing about one revoked policy is §13's whole
	# point — and a draw that indexed by letter id would keep or cull all six
	# together.
	var surviving := _draw_survivors(cullable, budget - kept.size(), run)
	for index in cullable.size():
		if surviving.has(index):
			kept.append(cullable[index])
		else:
			_cull_one(cullable[index], run)

	return kept


## Which skippable letters live, when there is not room for all of them.
##
## 🔒 **Drawn at random from a named stream, with no priority ordering** (#259,
## §11). Importance is the player's judgement, and a director ranking a famine
## above a charity appeal would be doing the player's job with worse information.
##
## **A seeded draw silences nobody systematically; a sort silences the same men
## in every run for ever.** Taking them in the order they fired meant taking them
## in trigger id order, so the desk was culled alphabetically and a contact whose
## triggers sorted late was quiet in every run ever played.
##
## Fisher-Yates on the stream rather than `Array.shuffle()`, which draws from the
## global RNG the lint forbids.
func _draw_survivors(cullable: Array[InboundLetter], room: int, run: RunState) -> Dictionary:
	var surviving: Dictionary = {}
	if room >= cullable.size():
		for index in cullable.size():
			surviving[index] = true
		return surviving
	if room <= 0:
		return surviving

	var order: Array[int] = []
	for index in cullable.size():
		order.append(index)

	var rng := run.streams.stream(STREAM)
	for index in range(order.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := order[index]
		order[index] = order[swap]
		order[swap] = held

	for index in room:
		surviving[order[index]] = true
	return surviving


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
