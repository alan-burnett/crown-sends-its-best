class_name Diplomat
extends RefCounted

## The PC's only resident eyes (#81, SPEC §8.1;
## `docs/mechanics/the-diplomat.md`).
##
## ## 🔒 Low loyalty spoils the intelligence, not the compliance
##
## For every other contact, a slighted man does less of what he is told. For the
## Diplomat, **a slighted man tells you less** — and that is the whole of his
## design. He is not a saint; he is a courtier posted overseas who would like his
## comforts, and what reaches the PC degrades as his regard does.
##
## The satire is in the gap: he writes about starvation in one paragraph and asks
## for money for his own luxuries in the next, and **both letters are true**.
##
## ## 🔒 Aware of every town, housed in one
##
## The broad reports cover the colony. The sharp ones — who is loyal, who is
## sliding toward sedition, which orders were refused — cover **exactly one
## town**, the one he lives in. That is what makes where he lives a decision.
##
## ## 🔒 He is never replaced
##
## SPEC §8.1 is explicit that nobody will take the post. When he dies the run
## continues blind, in the milestone where rebellion is the likeliest way to lose.

const ROLE: StringName = Contact.ROLE_DIPLOMAT

const EVENT_MOVED: StringName = &"diplomat_rehomed"
const EVENT_DIED: StringName = &"diplomat_died"
const EVENT_LEFT: StringName = &"diplomat_travelling"

## What his regard buys, worst to best. **The home-town detail goes first**
## (§5): a cooling man stops telling you his own business before he stops
## telling you the colony's.
const SILENT: StringName = &"silent"
const COLONY_ONLY: StringName = &"colony_only"
const EVERYTHING: StringName = &"everything"

## Where each tier begins. Tuning (§8).
const SPEAKS_AT_ALL: float = 18.0
const SPEAKS_OF_HOME: float = 45.0

## How wretched or dangerous his town must be before he asks to be moved.
## Either alone is enough (§3). Tuning.
const ASKS_ABOVE_SENTIMENT: float = 45.0
const ASKS_BELOW_SAFETY: float = 0.45

## How poorly he must be living before he asks for money for himself (§4).
const ASKS_BELOW_QUALITY: float = 0.45

## Months of silence a move costs. **A real blackout** — the price of agreeing is
## going blind in the months after the town he was watching got dangerous.
const MONTHS_TRAVELLING: int = 2


## Which town he lives in, or empty.
##
## Held as the display name because that is the field `lives_in` and
## `{sender:town}` already read; one rule for every resident (§4 of
## `rebel-sentiment.md`).
static func home_of(contact: Contact, colony: Colony) -> Town:
	if contact == null or colony == null or contact.town.is_empty():
		return null
	for town in colony.in_order():
		if town.display_name == contact.town:
			return town
	return null


## What reaches the PC at this regard.
static func reporting_at(loyalty: float) -> StringName:
	if loyalty < SPEAKS_AT_ALL:
		return SILENT
	if loyalty < SPEAKS_OF_HOME:
		return COLONY_ONLY
	return EVERYTHING


## Whether his town has become somewhere he would rather not be.
##
## **Either alone is enough** (§3): a safe town seething with sedition and a
## quiet town nobody can defend are both reasons to write.
static func wants_to_move(town: Town) -> bool:
	if town == null:
		return false
	return town.rebel_sentiment >= ASKS_ABOVE_SENTIMENT \
		or safety_of(town) <= ASKS_BELOW_SAFETY


## Whether he would ask for money for himself this month (§4).
##
## 🔒 **It does not reach the town.** This is for his own luxuries, because the
## place has become unpleasant to live in — and he is never lying about the
## place. Mechanically a patron's request: pay and his regard rises, refuse and
## it falls.
static func wants_paying(town: Town) -> bool:
	return town != null and town.quality_of_life <= ASKS_BELOW_QUALITY


## Where he would ask to go.
##
## **The town where the sum of his two problems is least**, ties broken toward
## the largest — a man choosing between two equally quiet places picks the one
## with more to do and more to eat.
static func destination_for(from: Town, colony: Colony) -> Town:
	if colony == null:
		return null
	var best: Town = null
	var best_trouble := 0.0
	for town in colony.in_order():
		if from != null and town.id == from.id:
			continue
		var trouble := town.rebel_sentiment / maxf(1.0, Rebellion.DECLARES_AT) \
			+ (1.0 - safety_of(town))
		if best == null or trouble < best_trouble - 0.0001:
			best = town
			best_trouble = trouble
		elif absf(trouble - best_trouble) <= 0.0001 and best != null:
			# 🔒 **Ties break toward the largest town**, and then on the name, so
			# two towns of a size do not resolve by iteration order.
			if town.population() > best.population() \
					or (town.population() == best.population()
						and String(town.id) < String(best.id)):
				best = town
				best_trouble = trouble
	return best


## How safe a town feels.
##
## **The stored figure, never a fresh reckoning.** Settle writes it beside
## quality of life from one reading of the month, so the safety he writes home
## about and the safety the town lived by cannot drift apart — and asking here
## would need a whole colony context in the correspondence layer to answer.
static func safety_of(town: Town) -> float:
	return 1.0 if town == null else clampf(town.safety, 0.0, 1.0)


## Move him, and start the blackout (Seam A).
static func rehome(contact: Contact, to: Town, context: ColonyContext) -> void:
	if contact == null or to == null:
		return
	var was := contact.town
	contact.town = to.display_name
	contact.travelling_until = context.state.month + MONTHS_TRAVELLING
	context.log.emit(EVENT_MOVED, contact.id, context.state.month, {
		"from": was,
		"to": to.display_name,
		"silent_until": contact.travelling_until,
	}, WorldPhase.CROWNS_MONTH)


## Whether he is somewhere at sea and therefore writing nothing.
static func is_travelling(contact: Contact, month: int) -> bool:
	return contact != null and contact.travelling_until > month


# --- 🔒 His death ------------------------------------------------------------

## Rebellion kills him outright (§6).
##
## **No roll.** This is what gives the rehoming request its teeth: the letter is
## the warning, and ignoring it is how the man is lost. The "every town rebels"
## case needs no special rule — wherever he is will flip.
static func rebellion_took_him(contact: Contact, town: Town, context: ColonyContext) -> bool:
	if contact == null or town == null or contact.is_dead:
		return false
	if contact.town != town.display_name:
		return false
	_kill(contact, town, "rebellion", context)
	return true


## An enemy attack may kill him, at `1 / new_population` (§6).
##
## Ten to nine is a long shot; two to one is certain; **a town reduced to nothing
## takes him with it.**
##
## 🔒 **Famine never endangers him. Only enemies do.** The distinction is the
## whole point of the rule, and it is enforced by this being the only path — the
## famine in `Consume` does not call it and must not.
##
## Nothing calls this yet: enemies are M5 and M6. It is here so that the
## milestone that brings them emits an attack and stops, rather than deciding for
## itself what an attack does to the Crown's man on the spot.
static func attack_took_him(
	contact: Contact,
	town: Town,
	new_population: int,
	context: ColonyContext,
) -> bool:
	if contact == null or town == null or contact.is_dead:
		return false
	if contact.town != town.display_name:
		return false
	if new_population <= 0:
		_kill(contact, town, "attack", context)
		return true

	# **His own stream**, derived per contact, so the same seed kills or spares
	# him at the same moment however much else has happened elsewhere.
	var rng := context.streams.contact_stream(String(contact.id))
	if rng.randf() > 1.0 / float(new_population):
		return false
	_kill(contact, town, "attack", context)
	return true


static func _kill(contact: Contact, town: Town, cause: String, context: ColonyContext) -> void:
	contact.is_dead = true
	# 🔒 **Never replaced** (SPEC §8.1). Nobody will take the post, and the run
	# continues blind — which is the cost, and why the warning letter matters.
	context.log.emit(EVENT_DIED, contact.id, context.state.month, {
		"town": String(town.id),
		"cause": cause,
		"replaced": false,
	}, WorldPhase.COLONY_MONTH)
