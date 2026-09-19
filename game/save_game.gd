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
