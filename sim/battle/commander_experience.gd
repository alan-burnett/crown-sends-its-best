class_name CommanderExperience
extends RefCounted

## What a commander learns in the field, and what it buys (#223,
## `docs/mechanics/commanders.md` §6).
##
## ## 🔒 Casualties inflicted, and nothing else
##
## **Not battles won**, because `battles.md` §6 has no rout and no surrender, so
## *winning* is not a quantity that exists — a battle exchanges losses and that
## is all.
##
## Casualties inflicted scales correctly on its own: **grinding a fort down over
## two years earns far more than a skirmish**, which is the right ordering, and a
## commander who has done nothing but garrison duty learns nothing.
##
## ## 🔒 Every bonus is data naming a knob
##
## The same rule perks and patrons' vices carry, and for the same reason: six
## bonuses written as six branches on a level number is six places a change to
## the company model has to be remembered, and the Author cannot add a seventh
## without a code change.
##
## A bonus declares the level it arrives at and the knob it turns. **A knob
## nothing reads is refused by the validator.**
##
## ## 🔒 Every bonus must be sayable in a letter
##
## §6's own constraint: *a commander should be able to tell the PC what he has
## become without the prose reading like a character sheet.* So each bonus has an
## id a letter can key a line off, and `rank_of` gives the whole man a name
## rather than a number — the words themselves live in `data/` like any other
## prose, because a sentence here would decide the language in code.
##
## **And the PC may never be shown the number.** §10 leaves open whether he
## learns a commander's level at all; nothing here renders one.
##
## ## 🔒 Husbandry reduces what is wanted. It never adds
##
## §6 is explicit, and it matters: a company **only ever dwindles** and is never
## re-equipped (`battles.md` §2). Arming more men with the same cargo is a change
## to what a head wants, not a delivery.

const COLLECTION: String = "battle"
const RECORD: String = "experience"

## Knob id -> what reads it. **Not a no-op list**: each of these is asked for by
## name at the point it decides something, and the string says where — so a knob
## that stops being read is a dead entry somebody can see.
const READ_BY: Dictionary = {
	"bearing": "Force.leadership_of",
	"marches": "Company.tiles_this_month",
	"hardiness": "Company.attrition_for_me",
	"country": "Force.terrain_of",
	"husbandry": "Company.wants_per_head",
	"siegecraft": "Force.fortification_of",
}

static var _levels: Array = []
static var _bonuses: Array = []


static func load_from(record: Dictionary) -> void:
	_levels = record.get("levels", []).duplicate(true)
	_bonuses = record.get("bonuses", []).duplicate(true)


static func reset() -> void:
	_levels = []
	_bonuses = []
	reset_starting_level()


static func is_knob(id: String) -> bool:
	return READ_BY.has(id)


## Every bonus a man of this level has, in file order.
##
## 🔒 **They stack** (§6). A long-lived commander becomes genuinely formidable,
## and that is intended: he is the one competent person in the PC's employ, and
## the PC cannot direct him.
static func bonuses_at(level: int) -> Array:
	var out: Array = []
	for entry in _bonuses:
		if int((entry as Dictionary).get("at", 1)) <= level:
			out.append(entry)
	return out


## What one knob is worth to a man of this level.
##
## **Stacked multiplicatively** where a bonus repeats, and `fallback` is what a
## commander of no level at all gets — which for every knob here is *no
## difference*, because the bonus is what experience buys and not a tax on the
## inexperienced.
static func knob_at(level: int, knob: String, fallback: float = 1.0) -> float:
	var worth := fallback
	var found := false
	for entry in bonuses_at(level):
		var values: Dictionary = (entry as Dictionary).get("turns", {})
		if not values.has(knob):
			continue
		if not found:
			worth = float(values[knob])
			found = true
		else:
			worth *= float(values[knob])
	return worth


## What one knob adds, for the knobs counted in whole things rather than shares.
static func added_at(level: int, knob: String) -> int:
	var total := 0
	for entry in bonuses_at(level):
		var values: Dictionary = (entry as Dictionary).get("adds", {})
		total += int(values.get(knob, 0))
	return total


## The terrain a man of this level knows, or "".
##
## 🔒 **One, and it is his** (§6's *a specialism in one terrain*). The last one
## he was given, so a second `country` bonus is a change of country rather than
## two at once — a commander who knew every kind of ground would be a commander
## with no specialism at all.
static func country_at(level: int) -> StringName:
	var known := &""
	for entry in bonuses_at(level):
		var named := String((entry as Dictionary).get("country", ""))
		if not named.is_empty():
			known = StringName(named)
	return known


## How high a man could go. Tuning, and §9 names it.
static func top_level() -> int:
	return maxi(0, _levels.size())


## What a tally of casualties has made of him.
##
## **Read from the tally, never stored**, so a thousand men killed and a level
## cannot disagree — and so retuning the thresholds re-ranks every commander in
## a saved run rather than only the ones raised afterwards.
static func level_for(inflicted: float) -> int:
	var level := _starting_level
	for entry in _levels:
		if inflicted + 0.0001 >= float((entry as Dictionary).get("casualties", 0.0)):
			level += 1
		else:
			break
	return mini(level, top_level())


# --- 🔒 The knob: what a man knows before his first battle ------------------

## How many levels a commander is credited with the day he is commissioned.
##
## Zero in every run until a quirk says otherwise (`perks-and-quirks.md` §4,
## *Commando commanders*), which is the whole history of the game so far: a new
## man has killed nobody and is ranked accordingly.
##
## 🔒 **Added to the tally's reading, not written into the tally.** The level is
## *read from casualties inflicted and never stored* so that a thousand men
## killed and a level cannot disagree — and so retuning the thresholds re-ranks
## every commander in a saved run. A starting credit written into `inflicted`
## would be a lie in the book about what a man had done, and the letters read
## that book.
static var _starting_level: int = 0


static func starting_level() -> int:
	return _starting_level


## Turn it. Capped at the top rank, because a man cannot begin above the highest
## thing the colony has a word for.
static func start_at(level: int) -> void:
	_starting_level = clampi(level, 0, top_level())


## The knob alone, for `RunModifiers.reset_knobs`; the ranks stay loaded.
static func reset_starting_level() -> void:
	_starting_level = 0


## What the colony calls a man of this level.
##
## 🔒 **An id, never a sentence** (`CLAUDE.md`). The words live in `data/` like
## any other prose, so a second language is a copied folder — and a letter keys
## its line off this rather than rendering a number the PC is not meant to see.
static func rank_of(level: int) -> StringName:
	var named := &""
	for index in mini(level, _levels.size()):
		var id := String((_levels[index] as Dictionary).get("rank", ""))
		if not id.is_empty():
			named = StringName(id)
	return named
