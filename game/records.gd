class_name Records
extends RefCounted

## The hall of records: past runs and their epitaphs (#354, SPEC §14.3).
##
## ## 🔒 It survives the run being thrown away
##
## §16.2's one-save-per-run rule governs the *run*. This is not the run — it is
## what is left of the ones before it — so it lives in its own file and
## `SaveGame.delete_save` does not touch it. **New Game destroys the save and
## must not destroy this**, or the only record of a colony would be deleted by
## the act of founding the next one.
##
## ## 🔒 It is the only place meta-progression is visible
##
## §14.3 gates unlocks on prestige and on conditions (`prestige.md` §10), and
## `the-advisor.md` §7 already hangs a condition off one. **A player who never
## sees his past runs has no way to know what he is playing toward**, and unlocks
## that arrive unexplained read as the game changing its mind rather than as
## progress.
##
## ## 🔒 What a row does not carry, and why
##
## **No prestige total.** `prestige.md` §10 flags that a long run almost always
## out-scores a short one, so a raw total invites a player to read the hall as a
## high-score table and play for length — which is a design question and the
## Author's. It is deliberately absent rather than hidden: the field is not
## written, so turning it on later is a decision and not an oversight.
##
## **And nothing announces an unlock.** `the-advisor.md` §7 locks that *his*
## condition is silent — a veteran is not congratulated for outgrowing the
## tutorial. Whether that silence is the rule for every unlock or the exception
## for that one is unsettled, so this says nothing at all rather than inventing
## the louder half.
##
## ## A damaged file loses the hall, never the game
##
## Read with defaults throughout. Losing a run to the record of an older one
## would be a poor trade.

const PATH: String = "user://records.cfg"
const SECTION: String = "runs"
const KEY: String = "entries"

const FIELD_COLONY: String = "colony"
const FIELD_REASON: String = "reason"
const FIELD_HOW: String = "how"
const FIELD_YEAR: String = "year"
const FIELD_EPITAPH: String = "epitaph"
const FIELD_ID: String = "id"

## 🔒 **What past runs have unlocked** (#465, SPEC §14.3): perk and quirk ids.
## Read here so the setup screen offers only what is unlocked; **what unlocks
## each is the PO's to write** (`prestige.md` §10), and until it is nothing
## writes this and a new player is offered the first-day perk alone.
const UNLOCKS_SECTION: String = "unlocks"
const UNLOCKS_KEY: String = "ids"

static var _entries: Array = []
static var _unlocks: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func ensure_loaded(path: String = PATH) -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var unlocked: Variant = file.get_value(UNLOCKS_SECTION, UNLOCKS_KEY, [])
	if typeof(unlocked) == TYPE_ARRAY or typeof(unlocked) == TYPE_PACKED_STRING_ARRAY:
		_unlocks = PackedStringArray(unlocked)
	var stored: Variant = file.get_value(SECTION, KEY, [])
	if typeof(stored) != TYPE_ARRAY:
		return
	for entry in stored as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			_entries.append((entry as Dictionary).duplicate())


static func reset() -> void:
	_entries = []
	_unlocks = PackedStringArray()
	_loaded = false


static func save_records(path: String = PATH) -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY, _entries.duplicate(true))
	file.set_value(UNLOCKS_SECTION, UNLOCKS_KEY, _unlocks.duplicate())
	var wrote := file.save(path)
	if wrote != OK:
		push_warning("Could not write the hall of records: %s" % error_string(wrote))
		return false
	return true


## Every run the hall holds, **most recent first**.
static func all(path: String = PATH) -> Array:
	ensure_loaded(path)
	var out := _entries.duplicate()
	out.reverse()
	return out


## The perk and quirk ids past runs have unlocked, sorted.
static func unlocks(path: String = PATH) -> PackedStringArray:
	ensure_loaded(path)
	var out := _unlocks.duplicate()
	out.sort()
	return out


static func is_empty(path: String = PATH) -> bool:
	ensure_loaded(path)
	return _entries.is_empty()


## Write a finished run into the hall.
##
## 🔒 **Idempotent.** A run reaches this from two directions — retiring, and the
## end-of-run check finding the colony gone — and the screens that show an ending
## may be opened more than once. Keyed by the seed and the month it stopped, so
## the same run recorded twice is recorded once.
##
## Returns whether this was the time it went in.
static func remember(
	run: RunState, content: ContentDatabase, path: String = PATH
) -> bool:
	ensure_loaded(path)
	if run == null or run.ending == null or not run.ending.is_over():
		return false

	var id := "%d:%d" % [run.run_seed, run.ending.month]
	for entry in _entries:
		if String((entry as Dictionary).get(FIELD_ID, "")) == id:
			return false

	_entries.append({
		FIELD_ID: id,
		FIELD_COLONY: _capital_of(run),
		FIELD_REASON: String(run.ending.reason),
		# 🔒 **Which fail condition it was** (`endings.md` §1). Both ways of
		# losing are `FAILED`, so without this the hall could not tell *the colony
		# was overrun* from *the colony threw us out* — and those are the two
		# stories a player most wants to remember apart.
		FIELD_HOW: String(run.ending.how),
		FIELD_YEAR: int(run.ending.month / WorldState.MONTHS_PER_YEAR) + 1,
		FIELD_EPITAPH: _epitaph_for(run.ending, content),
	})
	save_records(path)
	return true


## What the run was called: its capital.
static func _capital_of(run: RunState) -> String:
	if run.colony == null or run.colony.is_empty():
		return ""
	return run.colony.in_order()[0].display_name


## The epitaph, as prose, resolved once and kept.
##
## **Kept rather than looked up again**, because the epitaph chosen for a run is
## part of what happened to it: a later change to `data/epitaphs_en/` must not
## rewrite what the hall says about a colony that fell two years ago.
static func _epitaph_for(ending: RunEnding, content: ContentDatabase) -> String:
	if content == null:
		return ""
	var record := Epitaph.for_ending(ending, content)
	return String(record.get("text", ""))


## How a row reads, in the player's words rather than the enum's.
##
## Here rather than in the screen because it is the one place the three outcomes
## are named, and `endings.md` distinguishes them by more than the reason.
static func how_it_ended(entry: Dictionary) -> String:
	var reason := String(entry.get(FIELD_REASON, ""))
	var how := String(entry.get(FIELD_HOW, ""))
	match reason:
		String(RunEnding.RETIRED):
			return "Relieved at his own request"
		String(RunEnding.TERM_EXPIRED):
			return "Recalled at the end of his term"
		String(RunEnding.FAILED):
			if how.is_empty():
				return "The colony was lost"
			# The two ways of losing read very differently and the hall should
			# say which it was.
			if how == String(RunEndCheck.OVERRUN):
				return "The colony was overrun"
			if how == String(RunEndCheck.INDEPENDENCE):
				return "The colony threw the Crown out"
			return "The colony was lost"
	return "Ended"
