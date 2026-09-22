class_name CommanderBook
extends RefCounted

## What each commander has done, across every company he has led (#223,
## `docs/mechanics/commanders.md` §6, §7).
##
## ## 🔒 The commander is the thing that persists, not the company
##
## A company **only ever dwindles** and is never reinforced or re-equipped
## (`battles.md` §2). What survives a company being wiped out is the man who led
## it: he waits in his town and takes the next command raised there, **at the
## level he left at**.
##
## So the tally is his and lives here rather than on any company — and that is
## the whole reason no resupply mechanic is needed. A dev who reaches for one to
## make veterans durable has solved a problem this already solves.
##
## ## 🔒 It is a tally, not a level
##
## The level is read from the tally by `CommanderExperience.level_for` and stored
## nowhere, so a thousand men killed and a level cannot disagree — and retuning
## the thresholds re-ranks every commander in a saved run rather than only the
## ones raised after the change.
##
## ## 🔒 And it is not part of the run's state in the sim's sense
##
## It is per-contact, keyed by his id, and it outlives his companies. Saved with
## the run because a commander who forgot two years of campaigning would be a
## different man.

## Contact id -> casualties he has inflicted, all told.
var inflicted: Dictionary = {}


## Record what a commander's company did to somebody.
##
## 🔒 **Casualties inflicted, and nothing else** (§6). Not battles, not months in
## the field, not ground taken — `battles.md` §6 has no rout and no surrender, so
## *winning* is not a quantity that exists.
##
## **A headless company earns nobody anything**, which is correct: there is no
## man to learn from it.
func record(commander: StringName, casualties: float) -> void:
	if String(commander).is_empty() or casualties <= 0.0:
		return
	inflicted[String(commander)] = float(
		inflicted.get(String(commander), 0.0)) + casualties


func inflicted_by(commander: StringName) -> float:
	return float(inflicted.get(String(commander), 0.0))


func level_of(commander: StringName) -> int:
	return CommanderExperience.level_for(inflicted_by(commander))


## 🔒 **A killed commander leaves nothing behind** (§7). His experience dies with
## him: there is nothing to recover and nothing to inherit, and this is the only
## method that removes a tally.
func he_died(commander: StringName) -> void:
	inflicted.erase(String(commander))


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	var ids := PackedStringArray(inflicted.keys())
	ids.sort()  # Ordered, so the same run writes the same save.
	for id in ids:
		out[String(id)] = float(inflicted[String(id)])
	return {"inflicted": out}


static func from_dict(data: Dictionary) -> CommanderBook:
	var book := CommanderBook.new()
	for id in data.get("inflicted", {}):
		book.inflicted[String(id)] = float(data["inflicted"][id])
	return book
