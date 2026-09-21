class_name Consultation
extends RefCounted

## Whether a man still bothers to consult the PC (#259,
## `docs/mechanics/the-director.md` §10).
##
## ## 🔒 Loyalty gates the **kind** of letter, not the number
##
## | | At low loyalty |
## | :--- | :--- |
## | **Questions** — asking the PC's direction | **fewer** |
## | **Offers** — policies, help, ventures | **fewer** |
## | **Requests** — give me gold, give me iron | **unchanged** |
##
## So a disliked PC's desk is not quieter. **It is hollowed out.** The same stack
## of paper arrives and far fewer of them are decisions. He is still being asked
## for things; he has simply stopped being consulted.
##
## That is what makes §12's *he has lost the power to influence the world*
## something the player reads rather than merely suffers — and it removes any
## reward for being disliked, because the volume never drops.
##
## ## Why it has to be a filter and not a threshold
##
## Raising his threshold would make him quieter, which is the one thing §10 says
## this must not do. So the gate runs **before** selection: a question he will not
## ask is not a candidate at all, and the report or request he also had to send
## takes the slot instead. Same man, same month, same one letter — a different
## kind of letter.
##
## And he does not simply drop it. **He decides it himself**, through the kernel,
## by the same path a culled question takes (§12) — which is SPEC §9.6's *low
## loyalty contacts more often decide for themselves* in as many words. No loyalty
## is lost either way: he never asked.

const COLLECTION: String = "director"
const RECORD: String = "consultation"

## The kinds of letter that are a consultation at all.
##
## A request and a demand are asks, not decisions, and §10 leaves them untouched
## — being disliked must not spare the PC the begging. Reports, news and warnings
## ask nothing and so cannot be withheld.
const CONSULTATIVE: Array[StringName] = [
	LetterSchema.TYPE_QUESTION, LetterSchema.TYPE_OFFER,
]

## The stream the draw comes from.
##
## **Named, like every other** — a man's willingness to consult must not shift
## because mapgen happened to draw a different number of times.
const STREAM: String = "letters"

## Where consultation begins to fall off.
##
## 🔒 **The band, not a second boundary.** `Relationship.MEDIUM_AT` is already
## where the game says a man's regard has gone low (#258, SPEC §8.5), and §10's
## table says *at low loyalty*. A number of its own here would be a second
## definition of the same word, and the two would drift within a milestone.
const DEFAULT_ALWAYS_ABOVE: float = Relationship.MEDIUM_AT

## And how often a man at the very bottom still asks.
##
## **Never nought.** A man who has entirely stopped consulting the PC is a man
## the PC can no longer reach, and the game has an ending for that rather than a
## silence. §10 asks for *fewer*, which is what this is.
const DEFAULT_FLOOR_CHANCE: float = 0.4
const DEFAULT_AT_BOTTOM: float = 5.0

static var _always_above: float = DEFAULT_ALWAYS_ABOVE
static var _floor_chance: float = DEFAULT_FLOOR_CHANCE
static var _at_bottom: float = DEFAULT_AT_BOTTOM


## Every magnitude is data, because *how hollow is a hated man's desk* is a
## playtest question and not one anybody can answer at a keyboard.
static func load_from(record: Dictionary) -> void:
	_always_above = float(record.get("always_above", _always_above))
	_floor_chance = float(record.get("floor_chance", _floor_chance))
	_at_bottom = float(record.get("at_bottom", _at_bottom))


static func reset() -> void:
	_always_above = DEFAULT_ALWAYS_ABOVE
	_floor_chance = DEFAULT_FLOOR_CHANCE
	_at_bottom = DEFAULT_AT_BOTTOM


## Whether this kind of letter is a consultation.
static func is_consultative(letter_type: StringName) -> bool:
	return CONSULTATIVE.has(letter_type)


## How often a man at this loyalty still asks rather than deciding alone.
##
## One above `always_above`, flat at `floor_chance` from `at_bottom` down, and
## straight between. **Never nought**: a man who has entirely stopped consulting
## the PC is a man the PC can no longer reach at all, and the game has an ending
## for that rather than a silence.
static func chance_at(loyalty: float) -> float:
	if loyalty >= _always_above:
		return 1.0
	if loyalty <= _at_bottom:
		return _floor_chance
	var across := (loyalty - _at_bottom) / maxf(0.0001, _always_above - _at_bottom)
	return _floor_chance + across * (1.0 - _floor_chance)


## Whether this man still consults the PC this month, or settles things himself.
##
## **Asked of the man, once a month.** What it gates is his questions and offers;
## his requests and demands go regardless, because being disliked must not spare
## the PC the begging.
static func consults(contact: Contact, rng: RandomNumberGenerator) -> bool:
	if contact == null or rng == null:
		return true
	var chance := chance_at(contact.loyalty())
	if chance >= 1.0:
		return true
	return rng.randf() < chance
