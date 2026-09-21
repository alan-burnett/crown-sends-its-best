class_name Pressure
extends RefCounted

## Why a man bothers to write (#254, `docs/mechanics/the-director.md` §3).
##
## Today a trigger fires when its conditions hold and its cooldown has expired.
## **That is a gate, not a want.** This gives every contact a reason to write and
## a reason not to.
##
## ```
## pressure = gap + news - dampers
## ```
##
## ## 🔒 Topics are `cares_about`, and nothing else
##
## A contact's concerns are **not a second list**. They are the measures he
## already judges the PC by (`contacts.md` §6) — the same field that already
## decides what he writes about unprompted and what his loyalty drifts on. A
## second list would be a second place his character lived, and the two would
## disagree within a milestone.
##
## ## The news term is the point
##
## Without it a contact only writes when things are **already bad**, which is
## duller and less true. **People complain when something moves, not when it
## settles.**
##
## It is what makes the most human letter in the game possible:
##
## > *These taxes on beer are too much. They are not crippling us. Give us a
## > break.*
##
## A one-point overshoot is never worth a letter on its own. The **change** is
## what prompts him.
##
## And it makes the director a consumer of Seam A's event log alongside map
## playback and the ledger, rather than re-deriving the month: `WorldState.apply`
## records every value it moves, so what moved is read from the record rather
## than worked out a second time.
##
## 🔒 **Last month's log only.** News decays to nothing the month after without
## any damper being involved — the two are different mechanisms and a news term
## that faded would be a second damper wearing its coat.

## What a full gap is worth, so gap and news are on one scale.
##
## **A hundred, so the gap reads as a percentage**: how far the world is from
## what he wants, as a share of the whole distance it could be. A threshold of
## twenty-four is then *he writes when things are a quarter off*, which is a
## sentence somebody can argue with.
##
## All three are tuning, and §3's worked example is calibrated against a
## normalisation the doc does not state — so the shape is what this ticket
## fixes, and #255 and #256 own the figures.
const GAP_SCALE: float = 100.0
const NEWS_SCALE: float = 20.0

## What having already said a thing takes off.
##
## 🔒 **Counted in his own writings, not in months** (#256, §6). *The topic
## damper should last about as long as it takes him to say everything else he has
## to say* — so a man with five concerns damps each for roughly five writings,
## and rotation falls out instead of being enforced. Nothing tracks which topics
## he has used.
const TOPIC_DAMPER: float = 28.0

## And what having written at all takes off, for a month or two after.
##
## **The contact damper is why a man writes one letter and not five.** He picks
## his loudest concern, writes it, and the rest go below the line for a while —
## *I shall not pester the Crown.*
##
## 🔒 **Per individual contact, never per role.** Ending a policy six churches
## cared about brings six letters, and that is correct.
const CONTACT_DAMPER: float = 16.0
const CONTACT_MONTHS: int = 3

## The fewest writings a topic is damped for, however few concerns he has.
##
## A man with one concern would otherwise be undamped the moment he had written,
## and would write about the same thing every month for ever.
const FEWEST_WRITINGS: int = 2

## Where a man with no role and no history gives out.
##
## 🔒 **Only a fallback now** (#255). §4's threshold is the character — a base
## per role, redundancy and temperament — and `Threshold` owns it. This is what
## a caller gets for asking without saying who is asking, which is a fixture
## rather than a man.
const THRESHOLD: float = 24.0


## What every topic this man could write about is worth to him this month.
##
## Topic id -> pressure. Sorted by construction: `cares_about` is walked in
## order, so nothing here depends on the order a dictionary happened to hash in.
static func for_contact(
	contact: Contact,
	measures: Dictionary,
	log: EventLog,
	month: int,
	book: WritingBook = null,
) -> Dictionary:
	var out: Dictionary = {}
	if contact == null:
		return out

	var topics := contact.cares_about.duplicate()
	topics.sort()
	var moved := _what_moved(log, month)

	for topic in topics:
		if not MeasureRegistry.has_measure(String(topic)):
			continue
		out[String(topic)] = maxf(0.0,
			gap_on(String(topic), measures, contact)
			+ (NEWS_SCALE if moved.has(String(topic)) else 0.0)
			- damper_on(contact, String(topic), month, book))
	return out


## How far the world is from what he wants, on one topic.
##
## 🔒 **A distance, not a shortfall.** The first version of this read every
## measure as *higher is better* and needed no target at all — which is wrong in
## both directions at once. The Marshal cares about the war and wants it **over**;
## under a shortfall rule a fiercer war gave him a *smaller* gap and he stopped
## writing exactly when he had most to say.
##
## So a contact says what he would be content with, and the gap is how far off it
## is. That is §3 in as many words — *he compares the thing he cares about
## against what he thinks it should be* — and it is not a second list of
## concerns: the concerns are still `cares_about`, and this is a property of one
## he already has.
static func gap_on(topic: String, measures: Dictionary, contact: Contact = null) -> float:
	if not measures.has(topic) or not MeasureRegistry.has_measure(topic):
		return 0.0
	var where := MeasureRegistry.normalize(topic, float(measures[topic]))
	var wanted := contact.want_for(topic) if contact != null else Contact.WANTS_THE_BEST
	return GAP_SCALE * clampf(absf(where - wanted), 0.0, 1.0)


## Both dampers, added.
##
## 🔒 **They are set together and decay independently** (§6), which is the whole
## reason there are two: one is about *having said this* and the other about
## *having written at all*.
static func damper_on(
	contact: Contact,
	topic: String,
	month: int,
	book: WritingBook,
) -> float:
	if book == null or contact == null:
		return 0.0
	return topic_damper(contact, topic, book) + contact_damper(contact, month, book)


## *I have said this.* Counted in his letters.
##
## The span is **how many concerns he has**, so he works through them and comes
## round again — a man with five damps each for five writings and a man with two
## for two. The floor keeps a single-minded man from writing the same letter
## every month for ever.
static func topic_damper(contact: Contact, topic: String, book: WritingBook) -> float:
	var since := book.writings_since(contact.id, topic)
	if since < 0:
		return 0.0
	var span := maxi(FEWEST_WRITINGS, contact.cares_about.size())
	if since >= span:
		return 0.0
	return TOPIC_DAMPER * (1.0 - float(since) / float(span))


## *I shall not pester the Crown.* Counted in months, on every concern he has.
static func contact_damper(contact: Contact, month: int, book: WritingBook) -> float:
	var ago := book.months_since(contact.id, month)
	if ago < 0 or ago >= CONTACT_MONTHS:
		return 0.0
	return CONTACT_DAMPER * (1.0 - float(ago) / float(CONTACT_MONTHS))


## The one topic he would raise, and what it is worth — or empty.
##
## 🔒 **One letter per contact per month at most.** A man with three grievances
## writes about the worst of them; a man who wrote about all three would be a man
## the player learns to skim, which is the failure SPEC §9.6 exists to prevent.
##
## Ties break on the topic id rather than a die, so a tie is the world's business
## and not the iteration order's.
static func loudest(pressures: Dictionary, threshold: float = THRESHOLD) -> Dictionary:
	var names: Array = pressures.keys()
	names.sort()
	var best := ""
	var most := 0.0
	for topic in names:
		var felt := float(pressures[topic])
		if felt < threshold:
			continue
		if best.is_empty() or felt > most + 0.0001:
			best = String(topic)
			most = felt
	return {} if best.is_empty() else {"topic": best, "pressure": most}


## Which of the things he cares about moved last month.
##
## 🔒 **Read from the log, not re-derived.** `WorldState.apply` records every
## value it changes as `{changes: {key: {from, to}}}`, so this is Seam A's own
## account of the month rather than a second one that could disagree with it.
##
## **Last month's**, because a letter written this month is written about what
## has already happened — the director runs in Dispatch, after the world has had
## its month.
static func _what_moved(log: EventLog, month: int) -> Dictionary:
	var moved: Dictionary = {}
	if log == null or month <= 0:
		return moved
	for event in log.for_month(month - 1):
		var changes: Dictionary = event.payload.get("changes", {})
		for key in changes:
			var entry: Dictionary = changes[key]
			# **Compared as they were recorded.** A world value may be a number,
			# a string (the Crown's mandate) or absent before its first write, so
			# anything that coerced to a float here would crash on the mandate
			# and read a new key as unchanged.
			if entry.get("from", null) != entry.get("to", null):
				moved[String(key)] = true
	return moved
