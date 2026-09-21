class_name Temperament
extends RefCounted

## What kind of manner moves a man (#260, `docs/mechanics/tone.md` §5).
##
## ## 🔒 Three traits, not five weights
##
## A weight per tone is what makes the difference expressive — *how much manner
## matters to him* is a poor question, *what kind of manner moves him* is a good
## one.
##
## But five weights drawn independently, on top of the six a contact already
## carries, produce **a man who loves being flattered and also loves being
## threatened**. That is not a personality, it is a dice roll. So three traits
## are drawn and the tone weights are derived from them.
##
## | Trait | Scales |
## | :--- | :--- |
## | **vanity** | `pleased` |
## | **mettle** | `annoyed`, `hateful`, **and harshness** |
## | **pity** | `desperate` |
##
## 🔒 **Dutiful carries no trait and no weight**, which is the tell that the cut
## is right: its identity is *costs nothing, buys nothing*, so there is nothing
## in it for a personality to have an opinion about. It still scores — uniformly,
## for everybody — and that is the whole of what dutiful is.
##
## 🔒 **Mettle scales harshness too.** `HarshnessConsideration` already carried a
## personality weight and its own note read *"a proud man minds being commanded
## more than a dutiful one."* One trait driving both the harsh clause and the
## hostile tones is right: a man who resents being bullied resents the threat and
## the contempt alike.
##
## ## 🔒 A negative weight inverts that tone
##
## The kernel multiplies a consideration's score by the actor's weight, so a
## trait below zero flips that tone's whole table for him.
##
## **The bully needs no case of his own.** He takes courtesy for weakness and
## responds to force, and he falls out of this machinery as two numbers below
## zero rather than as a branch on who is reading. There is no such branch
## anywhere and `test_tone` says so.

const VANITY: StringName = &"vanity"
const METTLE: StringName = &"mettle"
const PITY: StringName = &"pity"

const ALL: Array[StringName] = [METTLE, PITY, VANITY]

## Where a trait may sit.
##
## 🔒 **Below zero on purpose**, unlike an ordinary consideration weight. A man
## who reads courtesy as weakness is not a man who is merely unmoved by it, and
## the floor is what makes him reachable without a special case. Tuning.
const TRAIT_MIN: float = -0.7
const TRAIT_MAX: float = 1.6

## An unremarkable temperament, for a contact whose traits nobody authored.
const MIDDLING: float = 0.9


## Which consideration weights each trait sets.
##
## **One place, so the harsh clause and the hostile tones cannot drift apart.**
static func scaled_by() -> Dictionary:
	return {
		String(VANITY): [String(ToneConsiderations.of(Tone.PLEASED))],
		# The harsh clause and the two hostile tones, from the one number.
		String(METTLE): [
			String(ToneConsiderations.of(Tone.ANNOYED)),
			String(ToneConsiderations.of(Tone.HATEFUL)),
			"harshness",
		],
		String(PITY): [String(ToneConsiderations.of(Tone.DESPERATE))],
	}


## Every consideration a trait decides the weight of, sorted.
static func derived_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var table := scaled_by()
	for trait_id in ALL:
		for consideration in table[String(trait_id)]:
			out.append(String(consideration))
	out.sort()
	return out


## Draw a temperament from a contact's own stream.
static func draw(rng: RandomNumberGenerator) -> Dictionary:
	var traits: Dictionary = {}
	# In the fixed order of `ALL`, so the same seed gives the same man however
	# the caller assembled anything.
	for trait_id in ALL:
		traits[String(trait_id)] = rng.randf_range(TRAIT_MIN, TRAIT_MAX)
	return traits


## An authored temperament, filling in whatever the data did not say.
static func from_record(record: Dictionary) -> Dictionary:
	var traits: Dictionary = {}
	for trait_id in ALL:
		traits[String(trait_id)] = float(record.get(String(trait_id), MIDDLING))
	return traits


## Fold a temperament into a contact's weight vector.
##
## Named `write_into` rather than `apply` because `tools/lint.gd` reserves that
## word: `.apply(` outside `sim/` is Seam A being violated, and a helper that
## happened to share the name would have to be exempted from a rule worth more
## than the name is.
##
## 🔒 **After the ordinary draw, never before.** `Contact.generate` rolls a
## weight for every consideration it is handed, and harshness is one of them — a
## man whose mettle was written first would have it rolled over and the trait
## would decide nothing.
static func write_into(traits: Dictionary, contact: Contact) -> void:
	if contact == null:
		return
	var table := scaled_by()
	for trait_id in ALL:
		var value := float(traits.get(String(trait_id), MIDDLING))
		for consideration in table[String(trait_id)]:
			contact.set_weight(StringName(consideration), value)
