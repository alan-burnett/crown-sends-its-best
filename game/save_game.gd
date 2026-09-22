class_name SaveGame
extends RefCounted

## Ironman saving. **One save per run, and no loading of earlier states**
## (SPEC §16.2).
##
## The game saves automatically when the post is sent, and the player may quit at
## any time and continue later with the turn in progress — including its outgoing
## post — intact.
##
## **There is no code path here that loads any state other than the current
## one.** No slots, no timestamps, no "load previous". A corrupt save is a lost
## run, which is why this is one of the few places the testing policy makes tests
## mandatory.
##
## **The save is Godot variant bytes, not JSON.** JSON has no integer type, so a
## round trip through it turns every `4` into `4.0` — which changes the state
## hash without changing the state, and would make the determinism test fail for
## a reason that has nothing to do with determinism. `var_to_bytes` preserves int
## and float exactly. Objects are refused on the way back in: a save is plain
## data and nothing in it should be able to construct anything.
##
## JSON stays where it belongs, on hand-authored content in `data/`.

const SAVE_PATH: String = "user://run.save"

## Kept **only for bug reproduction** and never used to reconstruct state
## (`CLAUDE.md`). Replaying decisions to rebuild a world is precisely what the
## full snapshot exists to avoid.
const DECISION_LOG_PATH: String = "user://decisions.log"

enum Result { OK, NO_SAVE, UNREADABLE, WRONG_VERSION }


## Write the run. Returns true on success.
static func save(run: RunState, path: String = SAVE_PATH) -> bool:
	run.version = RunState.SAVE_VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_var(run.to_dict(), false)
	file.close()
	return true


static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Load the run in progress.
##
## **A save from an older version is refused, not migrated.** Migration work
## belongs after release; during development a stale save is a bug waiting to be
## misread as a balance problem.
static func load_run(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"result": Result.NO_SAVE, "run": null, "message": "There is no run in progress."}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"result": Result.UNREADABLE, "run": null,
			"message": "The save file could not be read: %s" % error_string(FileAccess.get_open_error()),
		}
	var data: Variant = file.get_var(false)
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		return {"result": Result.UNREADABLE, "run": null, "message": "The save file is damaged."}

	var version := int(data.get("version", 0))
	if version != RunState.SAVE_VERSION:
		return {
			"result": Result.WRONG_VERSION, "run": null,
			"message": (
				"This save is from version %d and the game is version %d. " % [version, RunState.SAVE_VERSION]
				+ "Saves are not migrated during development, so this run cannot be continued."
			),
		}

	return {"result": Result.OK, "run": RunState.from_dict(data), "message": ""}


## What the save says about itself, without building a run out of it (#353).
##
## The main menu needs three things before it can draw: **whether there is a run,
## whether it can be continued, and what starting another would throw away.** All
## three are in the file's first few keys, and reconstructing a whole `RunState`
## — a map, a colony, an event log — to read a town's name and a month would be a
## second or two of work to put a sentence on a button.
##
## 🔒 **It reads; it never repairs.** A damaged or stale save reports itself here
## and `Continue` is absent, which is the same refusal `load_run` makes and not a
## softer one.
##
## Returns `{result, version, colony, year, message}`. `colony` is the capital's
## name, because that is what the player calls the run.
static func peek(path: String = SAVE_PATH) -> Dictionary:
	var nothing := {
		"result": Result.NO_SAVE, "version": 0, "colony": "", "year": 0,
		"message": "There is no run in progress.",
	}
	if not FileAccess.file_exists(path):
		return nothing

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		nothing["result"] = Result.UNREADABLE
		nothing["message"] = "The save file could not be read: %s" \
			% error_string(FileAccess.get_open_error())
		return nothing
	var data: Variant = file.get_var(false)
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		nothing["result"] = Result.UNREADABLE
		nothing["message"] = "The save file is damaged."
		return nothing

	var record: Dictionary = data
	var version := int(record.get("version", 0))
	var out := {
		"result": Result.OK,
		"version": version,
		"colony": _capital_of(record),
		"year": _year_of(record),
		"message": "",
	}
	if version != RunState.SAVE_VERSION:
		out["result"] = Result.WRONG_VERSION
		out["message"] = (
			"This save is from version %d and the game is version %d. "
			% [version, RunState.SAVE_VERSION]
			+ "Saves are not migrated during development, so this run cannot be continued."
		)
	return out


## The capital's name, or "" for a save that has no towns left in it.
##
## **The first town in the colony's own order**, which is the one the run was
## founded on — so a player who lost his capital still reads the name he knows.
static func _capital_of(record: Dictionary) -> String:
	var towns: Variant = record.get("colony", {}).get("towns", [])
	if typeof(towns) != TYPE_ARRAY or (towns as Array).is_empty():
		return ""
	return String((towns as Array)[0].get("name", ""))


## The 1-based year the run reached. **The same arithmetic `WorldState` does**,
## rather than a second opinion about when a year turns.
static func _year_of(record: Dictionary) -> int:
	var month := int(record.get("world", {}).get("month", 0))
	return month / WorldState.MONTHS_PER_YEAR + 1


static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Append one line to the decision log, for bug repro only.
static func note_decision(line: String, path: String = DECISION_LOG_PATH) -> void:
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()
