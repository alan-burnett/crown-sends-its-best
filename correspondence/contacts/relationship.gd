class_name Relationship
extends RefCounted

## Where the PC and one contact stand.
##
## **Not a log of letters.** It is the state of the relationship: what has been
## granted and refused, what is still owed, and how long since the PC last
## wrote. **Loyalty** (SPEC §8.5) is the headline scalar inside it.
##
## **This is not a ledger.** SPEC §4 fixes Ledger as the gold screen and nothing
## else.
##
## The correspondence layer reads this alongside world state and the world diff.
## People react to change as much as to standing conditions, so all three
## inputs matter.

const MIN_LOYALTY: float = 0.0
const MAX_LOYALTY: float = 100.0
const NEUTRAL_LOYALTY: float = 50.0

# --- Deeds -----------------------------------------------------------------

const GRANTED: StringName = &"granted"
const REFUSED: StringName = &"refused"
const DELIVERED: StringName = &"delivered"
const PROMISE_BROKEN: StringName = &"promise_broken"
const IGNORED: StringName = &"ignored"

const DEEDS: Array[StringName] = [GRANTED, REFUSED, DELIVERED, PROMISE_BROKEN, IGNORED]

## **🔒 Deeds outweigh words** (SPEC §8.5). What the PC grants, refuses, promises
## and delivers moves loyalty far more than the tone of his letters, and silence
## has its own effect (SPEC §9.3).
##
## Tuning values. They are here rather than in a data file because they are
## balance, not content; they move to data the moment the PO wants to tune them
## without a build.
const DEED_WEIGHT: Dictionary = {
	GRANTED: 6.0,
	REFUSED: -5.0,
	DELIVERED: 8.0,
	PROMISE_BROKEN: -12.0,
	IGNORED: -7.0,
}

## How many things a contact keeps in mind at once.
##
## **A fifty-year run cannot hold every deed for every contact in a save.** Keep
## the most significant and the most recent and let the middle fall away, which
## is also how people remember: you recall the great kindness and the last
## slight, and the ordinary months in between are gone.
const MEMORY_LIMIT: int = 12

## How many of those are held simply for being recent, whatever they were.
##
## Without this a contact would remember four remarkable years and nothing about
## last month, and a letter referring to the spring of a decade ago as though it
## were news reads as a man who has stopped paying attention.
const MEMORY_RECENT: int = 4


## Tone flavours how a letter lands and has **only a minor effect on loyalty**
## compared with what the letter actually grants or promises (SPEC §9.2).
##
## A table keyed per tone, never a scale: the five tones are not ordered.
##
## 🔒 **Dutiful is nought, and not a gain** (#262, `tone.md` §4). Its identity
## is *costs nothing, buys nothing* — the safe choice a player who never thinks
## about tone can take and lose very little by. A positive figure quietly makes
## it the best letter to send about anything, which is the one thing it must not
## be.
##
## 🔒 **And desperate keeps its slight loss.** Pleading diminishes you in the
## reader's eyes: a man who begs is a man who has lost his grip, and he is
## writing it down. It is half of what stops desperation being the answer to
## everything, the other half being the permanent mark on prestige.
const TONE_WEIGHT: Dictionary = {
	Tone.PLEASED: 0.6,
	Tone.DUTIFUL: 0.0,
	Tone.ANNOYED: -0.5,
	Tone.DESPERATE: -0.2,
	Tone.HATEFUL: -0.9,
}

## What being written to that way does to his **desire to write again** (#264,
## `tone.md` §4, `the-director.md` §4).
##
## 🔒 **Pleased increasing it is a cost, not a benefit.** More letters from him
## is more of a capped desk spent on him: being kind to a man gives you a
## chattier morning's post, and SPEC §9.6's budget is a ceiling.
##
## 🔒 **And hateful's major decrease is the other kind of cost.** A man written
## to contemptuously stops consulting the PC — and a man who has stopped
## consulting him does what *he* wants instead (#259, §10). **That is Seam C,
## arrived at by insult.**
##
## Dutiful and desperate move it not at all. Dutiful because it is the plain
## register and buys nothing; desperate because a man reading a plea is not
## thereby made keener or warier of writing — what it costs the PC is his regard
## and his prestige, which is quite enough.
##
## A table per tone, never a scale, like everything else keyed on tone.
const EAGERNESS_WEIGHT: Dictionary = {
	Tone.PLEASED: 0.06,
	Tone.DUTIFUL: 0.0,
	Tone.ANNOYED: -0.04,
	Tone.DESPERATE: 0.0,
	Tone.HATEFUL: -0.18,
}

## How far a run of letters can move it.
##
## **Never nought and never unbounded.** A man the PC has been kind to for four
## years should be noticeably chattier, not writing three letters a month; and a
## man he has abused should be very nearly silent without becoming unreachable,
## because an unreachable contact is an ending rather than a silence. Tuning.
const LEAST_EAGER: float = 0.45
const MOST_EAGER: float = 1.6

## Where a man starts, having been written to not at all.
const EAGER_AT_FIRST: float = 1.0

var contact_id: StringName = &""

var loyalty: float = NEUTRAL_LOYALTY

## 🔒 **Regard somebody else is buying on the PC's behalf** (#285,
## `the-diplomat.md` §7), held apart from the man's own.
##
## The Diplomat cultivates the governor he lives with — dines him, flatters him,
## is seen at his table — and that governor thinks better of the Crown **for as
## long as it runs**. It is the PC's only indirect lever on loyalty: everywhere
## else a contact's regard answers to what the PC did to *him*.
##
## 🔒 **Kept separate because it does not persist.** When the policy lapses, or
## the Diplomat dies in a town that turned on him, **the loyalty he was buying
## dies with him** — which is only expressible if it was never part of what the
## man himself felt. Folded into `Contact.loyalty()`, so every reader sees the
## cultivated figure and nothing has to remember to ask.
var cultivated: float = 0.0

## How apt he is to write to the PC, after everything the PC has written to him.
##
## Read by the director as a divisor on his threshold: **eager men have lower
## bars.** It is not how strongly he feels — pressure is the world's business —
## it is whether he reaches for the pen.
var eagerness: float = EAGER_AT_FIRST

## Per-deed multipliers on `DEED_WEIGHT`, for the men who are not like the rest.
##
## 🔒 **A scale on the weight, never a second weight.** A thin-skinned patron
## (`patrons.md` §6) feels a refusal twice as hard, and he feels it through the
## line everybody else feels it through — so a change to what a refusal costs
## reaches him without anybody remembering that he exists.
##
## Empty for nearly everyone, which is what makes it safe to put here: a
## relationship that says nothing behaves exactly as it did before there was a
## field.
var deed_scale: Dictionary = {}

## 🔒 **What his regard lets the PC hear** (#258, `the-director.md` §2).
##
## **Consulted, informed, bypassed** — one event, three entirely different
## months. A governor changing his intent tells a man he likes and asks what he
## would rather; tells a man he is merely obliged to; and does not mention it at
## all to a man he does not.
##
## Bands rather than a figure, because SPEC §8.5 keeps loyalty off the player's
## screens: what reaches him is which of three letters arrived, or none.
const HIGH: StringName = &"high"
const MEDIUM: StringName = &"medium"
const LOW: StringName = &"low"

const BANDS: Array[StringName] = [HIGH, LOW, MEDIUM]

## Tuning.
const HIGH_AT: float = 62.0
const MEDIUM_AT: float = 34.0


## Which band a regard sits in.
static func band_of(regard: float) -> StringName:
	if regard >= HIGH_AT:
		return HIGH
	return MEDIUM if regard >= MEDIUM_AT else LOW


## And his.
func band() -> StringName:
	return band_of(loyalty)

## Promise ids the PC still owes this contact. The promise model itself is #17;
## this holds the reference so a contact knows what is outstanding.
var outstanding_promises: PackedStringArray = PackedStringArray()

## How many times each deed has happened. Deed kind -> count.
var deeds: Dictionary = {}

## The last world month the PC wrote. -1 means never.
var last_written_month: int = -1

## What he actually remembers, oldest first (#127).
##
## **Counts answer how often; this answers what.** A contact asking for
## something new can reach back, find the last time the PC was generous, and
## name it — which is a fact about the past, and SPEC §9.1 requires letters to
## get those right. The bias is in *which* one he reaches for.
var history: Array[Recollection] = []


func _init(p_contact_id: StringName = &"", p_loyalty: float = NEUTRAL_LOYALTY) -> void:
	contact_id = p_contact_id
	loyalty = clampf(p_loyalty, MIN_LOYALTY, MAX_LOYALTY)


# --- Loyalty ---------------------------------------------------------------

## Record something the PC did, and move loyalty by it.
##
## `scale` lets a caller say how big the deed was — granting 10 gold and granting
## 10,000 are both `GRANTED`. Returns the actual change after clamping, so a
## caller can report what really happened rather than what it asked for.
## Record a deed as something he will remember, as well as counting it.
##
## `magnitude` and `subject` are what make it describable: two hundred measures
## of iron rather than "a kindness". Both may be empty — a refusal with no
## subject is still a refusal, and a letter has to be able to say so.
func remember(
	deed: StringName,
	month: int,
	magnitude: float = 0.0,
	subject: String = "",
) -> void:
	history.append(Recollection.new(deed, month, magnitude, subject))
	_forget_the_middle()


## Keep the most recent and the most significant; let the middle go.
func _forget_the_middle() -> void:
	if history.size() <= MEMORY_LIMIT:
		return

	var recent := history.slice(maxi(0, history.size() - MEMORY_RECENT))
	var older := history.slice(0, maxi(0, history.size() - MEMORY_RECENT))
	# Most memorable first, ties broken by recency so a man forgets the older of
	# two equal memories.
	older.sort_custom(func(a: Recollection, b: Recollection) -> bool:
		if not is_equal_approx(a.weight(), b.weight()):
			return a.weight() > b.weight()
		return a.month > b.month)

	var kept := older.slice(0, maxi(0, MEMORY_LIMIT - recent.size()))
	kept.sort_custom(func(a: Recollection, b: Recollection) -> bool: return a.month < b.month)

	history.clear()
	for entry in kept:
		history.append(entry)
	for entry in recent:
		history.append(entry)


# --- What he reaches for ----------------------------------------------------

## The largest kindness he remembers, or null.
##
## What a contact leads with when he is about to ask for something else.
func most_generous() -> Recollection:
	return _best(func(entry: Recollection) -> bool: return entry.is_a_kindness(),
		func(a: Recollection, b: Recollection) -> bool:
			if not is_equal_approx(a.magnitude, b.magnitude):
				return a.magnitude > b.magnitude
			return a.month > b.month)


## The most recent thing done *to* him, or null.
func most_recent_slight() -> Recollection:
	return _best(func(entry: Recollection) -> bool: return entry.is_a_slight(),
		func(a: Recollection, b: Recollection) -> bool: return a.month > b.month)


## The last time the PC's word did not hold, or null.
##
## Kept separate from a slight because it is a different accusation: being
## refused is disappointing and being promised is being lied to.
func last_broken_word() -> Recollection:
	return _best(func(entry: Recollection) -> bool: return entry.kind == PROMISE_BROKEN,
		func(a: Recollection, b: Recollection) -> bool: return a.month > b.month)


## The one a contact of this temper reaches for, or null.
##
## **Free characterisation.** Same log, same queries, different weights: a warm
## man leads with the last kindness and a sour one with the last slight, and
## neither of them is lying. `sourness` runs `0.0` to `1.0`.
func recalled(sourness: float) -> Recollection:
	var kindness := most_generous()
	var slight := most_recent_slight()
	if kindness == null:
		return slight
	if slight == null:
		return kindness
	return slight if sourness >= 0.5 else kindness


func _best(matches: Callable, better: Callable) -> Recollection:
	var found: Recollection = null
	for entry in history:
		if not matches.call(entry):
			continue
		if found == null or better.call(entry, found):
			found = entry
	return found


func record_deed(deed: StringName, scale: float = 1.0) -> float:
	if not DEEDS.has(deed):
		push_error("Unknown deed '%s'." % deed)
		return 0.0
	deeds[String(deed)] = int(deeds.get(String(deed), 0)) + 1
	return _move_loyalty(float(DEED_WEIGHT[deed]) * scale * scale_for(deed))


## Record the tone of a letter the PC sent.
##
## Two things happen: his regard moves, and so does **how apt he is to write
## back** (#264, `tone.md` §4).
func record_tone(tone: StringName) -> float:
	if not Tone.is_tone(tone):
		push_error("Unknown tone '%s'." % tone)
		return 0.0
	eagerness = clampf(
		eagerness + float(EAGERNESS_WEIGHT[tone]), LEAST_EAGER, MOST_EAGER)
	return _move_loyalty(float(TONE_WEIGHT[tone]))


## Move regard with the world rather than with a deed (#126).
##
## **Separate from `record_deed` on purpose.** A deed is a thing the PC did and
## belongs in the count that letters read back; drift is the weather, and adding
## it to the deed tally would have a contact remembering a bad winter as though
## the PC had refused him something.
func drift(delta: float) -> float:
	return _move_loyalty(delta)


func _move_loyalty(delta: float) -> float:
	var before := loyalty
	loyalty = clampf(loyalty + delta, MIN_LOYALTY, MAX_LOYALTY)
	return loyalty - before


## How much harder this man takes a deed than the next man.
##
## **One, unless something said otherwise**, so the ordinary contact is
## untouched and the scale cannot quietly invert a weight: a negative multiplier
## would turn a refusal into a favour.
func scale_for(deed: StringName) -> float:
	return maxf(0.0, float(deed_scale.get(String(deed), 1.0)))


static func reset() -> void:
	_crown_break_scale = 1.0


## Say that this man feels a deed differently (#282, `patrons.md` §6).
func scale_deed(deed: StringName, scale: float) -> void:
	if not DEEDS.has(deed):
		push_error("Unknown deed '%s'." % deed)
		return
	deed_scale[String(deed)] = maxf(0.0, scale)


func deed_count(deed: StringName) -> int:
	return int(deeds.get(String(deed), 0))


# --- Correspondence --------------------------------------------------------

func note_letter_sent(month: int) -> void:
	last_written_month = month


## Months since the PC last wrote. Feeds the `{sender:months_silent}` slot (#9).
##
## A contact never written to reports the months since the run began, which is
## the honest answer to "how long have you been ignoring me".
func months_silent(current_month: int) -> int:
	if last_written_month < 0:
		return maxi(0, current_month)
	return maxi(0, current_month - last_written_month)


func add_promise(promise_id: String) -> void:
	if not outstanding_promises.has(promise_id):
		outstanding_promises.append(promise_id)


## How many times the PC's word has not been kept to this contact, and when it
## last happened.
##
## **Counted, not just felt.** The loyalty drop is immediate; the letter that
## says so comes next month, and needs to know there is something to say.
var promises_broken: int = 0
var last_promise_broken_month: int = -1


## Clear a promise. `kept` false records the broken-promise deed, which costs
## loyalty whether it broke through lack of means or a Crown refusal
## (SPEC §9.5, §10.3).
##
## The month is remembered so the injured party can **write about it** rather
## than merely thinking less of the PC. A loyalty drop nobody mentions is a
## number moving in the dark, and the cascade this feeds is supposed to be
## watchable (#70).
func settle_promise(
	promise_id: String, kept: bool, month: int = -1, by_the_crown: bool = false
) -> float:
	var index := outstanding_promises.find(promise_id)
	if index >= 0:
		outstanding_promises.remove_at(index)
	if not kept:
		promises_broken += 1
		last_promise_broken_month = month
	# 🔒 **A promise the Crown broke is not a promise the PC broke** (#287, *My
	# boss is a jerk*). `REFUSING` breaks every gold promise at once, and because
	# the PC typically owes several people it lands as a broad collapse in
	# goodwill rather than one penalty — then worse compliance, then rising
	# sentiment. **The nastiest spiral in the game**, and the perk defuses it.
	#
	# Thematically: people believe he meant it, and they know whose treasury said
	# no. So the scale is on *who refused*, never on the promise itself.
	if not kept and by_the_crown:
		return record_deed(PROMISE_BROKEN, _crown_break_scale)
	return record_deed(DELIVERED if kept else PROMISE_BROKEN)


## What a promise the **Crown** broke costs, against one the PC broke himself.
## One in every run without the perk.
static var _crown_break_scale: float = 1.0


static func crown_break_scale() -> float:
	return _crown_break_scale


static func set_crown_break_scale(scale: float) -> void:
	_crown_break_scale = maxf(0.0, scale)


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"contact_id": String(contact_id),
		"loyalty": loyalty,
		"cultivated": cultivated,
		"eagerness": eagerness,
		"promises_broken": promises_broken,
		"last_promise_broken_month": last_promise_broken_month,
		"outstanding_promises": outstanding_promises.duplicate(),
		"deeds": deeds.duplicate(),
		"deed_scale": deed_scale.duplicate(),
		"last_written_month": last_written_month,
		"history": _history_to_dicts(),
	}


func _history_to_dicts() -> Array:
	var out: Array = []
	for entry in history:
		out.append(entry.to_dict())
	return out


static func from_dict(data: Dictionary) -> Relationship:
	var relationship := Relationship.new(
		StringName(data.get("contact_id", "")),
		float(data.get("loyalty", NEUTRAL_LOYALTY)),
	)
	relationship.cultivated = float(data.get("cultivated", 0.0))
	relationship.eagerness = float(data.get("eagerness", EAGER_AT_FIRST))
	relationship.outstanding_promises = PackedStringArray(data.get("outstanding_promises", []))
	relationship.deeds = data.get("deeds", {}).duplicate()
	relationship.deed_scale = data.get("deed_scale", {}).duplicate()
	relationship.last_written_month = int(data.get("last_written_month", -1))
	relationship.promises_broken = int(data.get("promises_broken", 0))
	relationship.last_promise_broken_month = int(data.get("last_promise_broken_month", -1))
	for entry in data.get("history", []):
		relationship.history.append(Recollection.from_dict(entry))
	return relationship
