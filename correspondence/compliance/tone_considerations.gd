class_name ToneConsiderations
extends RefCounted

## How the PC's manner lands on the man reading it (#260,
## `docs/mechanics/tone.md` §4, §5).
##
## The PC may write hatefully to a man who has done nothing wrong. Nothing stops
## him, so **tone must carry a function** or the first blank of every reply is
## decoration.
##
## ## 🔒 Inside the kernel, not on top of it
##
## **Each tone is a consideration**, scoring zero unless the letter carries it,
## sitting alongside loyalty, cost, payment, harshness, clarity and autonomy —
## and weighted by personality like every one of them.
##
## This is not a detail of where the code goes. The kernel's whole design is that
## a consideration produces a score and the actor's personality supplies a weight
## (`deliberation.md` §4). Build tone *outside* that, as a table applied to the
## result, and **every contact in the game reacts to a hateful letter
## identically** — and making one react differently then needs a branch on who he
## is, which `CLAUDE.md` forbids in as many words.
##
## Inside the kernel it costs nothing. **A man who minds being shouted at is one
## number in a vector already being filled in when he is generated**
## (`Temperament`).
##
## ## 🔒 The tables are the centre of a distribution
##
## §4's figures describe **the average reader**. A *slight loyalty loss* for
## annoyed is slight for a typical man and far worse for a proud one, so these
## are a midpoint to tune rather than a value to set — and what they buy is five
## tones times every personality in the game rather than five tones.
##
## Written as named subclasses rather than lambdas: a `Callable` living in a
## static registry segfaults Godot 4.7 on shutdown (`CLAUDE.md`).

## The consideration id for a tone.
##
## **Derived rather than listed**, so a sixth tone would be impossible to add
## here without adding it to `Tone` first — which is where §2's lock lives.
static func of(tone: StringName) -> StringName:
	return StringName("tone_%s" % tone)


## Every tone consideration id, sorted.
static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for tone in Tone.ALL:
		out.append(String(of(tone)))
	out.sort()
	return out


static func register_all(kinds: Array) -> void:
	Deliberation.register_consideration(Pleased.new(of(Tone.PLEASED)), kinds)
	Deliberation.register_consideration(Dutiful.new(of(Tone.DUTIFUL)), kinds)
	Deliberation.register_consideration(Annoyed.new(of(Tone.ANNOYED)), kinds)
	Deliberation.register_consideration(Desperate.new(of(Tone.DESPERATE)), kinds)
	Deliberation.register_consideration(Hateful.new(of(Tone.HATEFUL)), kinds)


## The shape every one of them has: a table, and silence unless it is asked.
##
## 🔒 **Zero unless the letter carries this tone.** A consideration with an
## opinion about a letter written in some other manner would be one that shifted
## every decision in the game by a constant, which is the difference between a
## consideration and a thumb on the scale.
class OfTone:
	extends Consideration

	var tone: StringName = &""

	func _init(p_id: StringName, p_tone: StringName) -> void:
		super(p_id)
		tone = p_tone

	func pull() -> Dictionary:
		return {}

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if StringName(context.get_value("tone", &"")) != tone:
			return 0.0
		return clampf(float(pull().get(candidate.id, 0.0)), -1.0, 1.0)


## **Makes friends, and is not taken seriously** (§6).
##
## Toward complying and toward a partial answer — and a **big** push toward
## delay, because a man who is glad to hear from you is a man comfortable enough
## to get to it presently.
class Pleased:
	extends OfTone

	func _init(p_id: StringName) -> void:
		super(p_id, Tone.PLEASED)

	func pull() -> Dictionary:
		return {
			Compliance.COMPLY: 0.5,
			Compliance.PARTIAL: 0.4,
			Compliance.DELAY: 0.9,
			Compliance.REINTERPRET: 0.0,
			Compliance.REFUSE: -0.3,
			Compliance.ACT_ALONE: -0.2,
		}


## **Costs nothing, buys nothing** (§6).
##
## 🔒 **No trait and no weight anywhere.** It is the plain register, so it pushes
## away from the sideways answers and does nothing else — and it does that
## identically for every man in the game, which is precisely its identity.
class Dutiful:
	extends OfTone

	func _init(p_id: StringName) -> void:
		super(p_id, Tone.DUTIFUL)

	func pull() -> Dictionary:
		return {
			Compliance.COMPLY: 0.0,
			Compliance.PARTIAL: 0.0,
			Compliance.DELAY: 0.0,
			Compliance.REINTERPRET: -0.4,
			Compliance.REFUSE: -0.4,
			Compliance.ACT_ALONE: -0.4,
		}


## **Peevishness, which reads as fussiness** (§4).
##
## A big push toward a partial answer and **away from delay** — a man being
## grumbled at does the least that will stop the grumbling, and does it now.
class Annoyed:
	extends OfTone

	func _init(p_id: StringName) -> void:
		super(p_id, Tone.ANNOYED)

	func pull() -> Dictionary:
		return {
			Compliance.COMPLY: 0.1,
			Compliance.PARTIAL: 0.9,
			Compliance.DELAY: -0.7,
			Compliance.REINTERPRET: 0.2,
			Compliance.REFUSE: 0.1,
			Compliance.ACT_ALONE: 0.0,
		}


## **Need, which reaches a decent man where nothing else would** (§6).
##
## Away from refusing, and hard away from delay: a letter that says the thing is
## urgent is a letter you do not put in a drawer.
##
## 🔒 **Delay is removed, not weighed against** (#261, §4).
## `DesperationIsNotPutOff` is a filter and takes delay off the list before any
## of this is scored, because a weight can lose a close vote and the identity of
## the tone is that **nothing is delayed.**
##
## So there is **no entry for delay here.** A heavy negative weight alongside the
## filter would be the same rule written twice, and the second copy would go on
## looking like it was doing the work after somebody removed the first.
class Desperate:
	extends OfTone

	func _init(p_id: StringName) -> void:
		super(p_id, Tone.DESPERATE)

	func pull() -> Dictionary:
		return {
			Compliance.COMPLY: 0.6,
			Compliance.PARTIAL: 0.3,
			Compliance.REINTERPRET: -0.1,
			Compliance.REFUSE: -0.6,
			Compliance.ACT_ALONE: 0.0,
		}


## **Contempt, which a man may answer in kind** (§6).
##
## Toward refusing and toward acting alone. A man written to like this has been
## told what the Crown thinks of him, and some of them answer it.
class Hateful:
	extends OfTone

	func _init(p_id: StringName) -> void:
		super(p_id, Tone.HATEFUL)

	func pull() -> Dictionary:
		return {
			Compliance.COMPLY: -0.6,
			Compliance.PARTIAL: -0.2,
			Compliance.DELAY: 0.1,
			Compliance.REINTERPRET: 0.3,
			Compliance.REFUSE: 1.0,
			Compliance.ACT_ALONE: 0.8,
		}
