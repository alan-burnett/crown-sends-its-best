class_name Settings
extends RefCounted

## What the player has set, across runs (#353, SPEC §15).
##
## ## 🔒 Not part of the run, and not part of Ironman
##
## SPEC §16.2's one-save-per-run rule is about the *run*. How loud the music is
## and how large the text is are facts about the person holding the phone, so
## they live in their own file and **survive a run being thrown away** — a player
## who set the text larger because he needs it larger must not have to do it
## again because he started a new colony.
##
## Which is also why there is no save-management screen. §15 asks for options and
## save management to share a UI; under Ironman there is nothing to manage — no
## slots, no loading, no naming — and the only save operation that exists is
## discarding the run in progress by starting another, which belongs on the
## confirmation that does it.
##
## ## 🔒 A missing or damaged file is the defaults, never an error
##
## Losing a run to a settings file is not a trade anybody would make. Everything
## here is read with a default and clamped to a range it cannot be wrong outside.
##
## ## What goes in it beyond these is open
##
## §15 says *"we will add more to this"*, so this is a small table rather than a
## shape: a key, a default, a range. Adding one is three lines and a control.

const PATH: String = "user://settings.cfg"
const SECTION: String = "options"

const KEY_TEXT_SCALE: String = "text_scale"
const KEY_MUSIC: String = "music"
const KEY_SOUND: String = "sound"

## How much larger or smaller than the designed size text is drawn.
##
## **Text is the main medium and must be comfortable to read at length on a
## phone** (`CLAUDE.md`), so this reaches further than most settings do: it
## scales every label and every button in the game.
const TEXT_SCALE_MIN: float = 0.8
const TEXT_SCALE_MAX: float = 1.6
const TEXT_SCALE_DEFAULT: float = 1.0

const VOLUME_DEFAULT: float = 0.7

static var _values: Dictionary = {}
static var _loaded: bool = false


## Read the file, or the defaults. **Idempotent**, so anything may call it.
static func ensure_loaded(path: String = PATH) -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in [KEY_TEXT_SCALE, KEY_MUSIC, KEY_SOUND]:
		if file.has_section_key(SECTION, key):
			_values[key] = file.get_value(SECTION, key)


static func reset() -> void:
	_values = {}
	_loaded = false


## Write the file. Returns whether it stuck.
##
## A failure is reported and survived: a player whose disk is full should lose
## his preference, not his game.
static func save_settings(path: String = PATH) -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_TEXT_SCALE, text_scale())
	file.set_value(SECTION, KEY_MUSIC, music_volume())
	file.set_value(SECTION, KEY_SOUND, sound_volume())
	var wrote := file.save(path)
	if wrote != OK:
		push_warning("Could not write the settings: %s" % error_string(wrote))
		return false
	return true


static func text_scale() -> float:
	ensure_loaded()
	return clampf(
		float(_values.get(KEY_TEXT_SCALE, TEXT_SCALE_DEFAULT)),
		TEXT_SCALE_MIN, TEXT_SCALE_MAX)


static func set_text_scale(value: float) -> void:
	ensure_loaded()
	_values[KEY_TEXT_SCALE] = clampf(value, TEXT_SCALE_MIN, TEXT_SCALE_MAX)


static func music_volume() -> float:
	ensure_loaded()
	return clampf(float(_values.get(KEY_MUSIC, VOLUME_DEFAULT)), 0.0, 1.0)


static func set_music_volume(value: float) -> void:
	ensure_loaded()
	_values[KEY_MUSIC] = clampf(value, 0.0, 1.0)


static func sound_volume() -> float:
	ensure_loaded()
	return clampf(float(_values.get(KEY_SOUND, VOLUME_DEFAULT)), 0.0, 1.0)


static func set_sound_volume(value: float) -> void:
	ensure_loaded()
	_values[KEY_SOUND] = clampf(value, 0.0, 1.0)


## What the game calls itself, for the corner of the menu.
##
## **From `project.godot`, not a constant here.** A version in two places is a
## version that disagrees with itself the first time somebody bumps one.
static func game_version() -> String:
	var named: Variant = ProjectSettings.get_setting("application/config/version", "")
	return String(named) if not String(named).is_empty() else "in development"
