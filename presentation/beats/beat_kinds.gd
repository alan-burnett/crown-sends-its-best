class_name BeatKinds
extends RefCounted

## What a kind of beat looks like, sounds like, and how long it takes (#293,
## `docs/mechanics/beats.md` §4).
##
## ## ⚠️ Data and named methods. Never lambdas
##
## `CLAUDE.md`: Godot 4.7 segfaults on shutdown with a `Callable` still held in a
## static registry, and **a beat registry is exactly the shape that invites
## one.** So an entry holds:
##
## | | |
## | :--- | :--- |
## | `sound`, `sprite` | **asset ids**, never paths (SPEC §16.3) |
## | `seconds` | how long it wants, before magnitude scales it |
## | `settles` | **the name of a method the stage implements** |
##
## `settles` is a string, and the stage is the object that owns the method. So
## the behaviour lives with the screen that has it, the registry holds nothing
## but data, and there is no `Callable` anywhere to be held at exit.
##
## ## 🔒 Registered, never guessed
##
## A kind nobody has registered plays for no time, makes no sound and settles
## nothing. That is deliberately inert rather than an error: a producer that
## emitted an unknown kind would otherwise take the whole month's playback down,
## and `beats.md` §6 is clear that **a beat that did not play is not an event
## that did not happen** — the sim's state is already correct either way.

## What the quietest beat gets of its kind's time. A beat at magnitude nought is
## still a beat; it is simply not worth dwelling on.
const QUIETEST: float = 0.45

const KEY_SOUND: String = "sound"
const KEY_SPRITE: String = "sprite"
const KEY_SECONDS: String = "seconds"
const KEY_SETTLES: String = "settles"

static var _kinds: Dictionary = {}


## Register a kind. **Data only** — `settles` is a method name, not a callable.
static func register(
	id: StringName,
	settles: String,
	seconds: float = 0.6,
	sound: String = "",
	sprite: String = "",
) -> void:
	_kinds[String(id)] = {
		KEY_SETTLES: settles,
		KEY_SECONDS: maxf(0.0, seconds),
		KEY_SOUND: sound,
		KEY_SPRITE: sprite,
	}


static func reset() -> void:
	_kinds = {}


static func has(id: StringName) -> bool:
	return _kinds.has(String(id))


static func ids() -> PackedStringArray:
	var out := PackedStringArray(_kinds.keys())
	out.sort()
	return out


static func _entry(id: StringName) -> Dictionary:
	return _kinds.get(String(id), {})


## The method the stage must implement to settle a beat of this kind.
static func settles_with(id: StringName) -> String:
	return String(_entry(id).get(KEY_SETTLES, ""))


static func seconds_of(id: StringName) -> float:
	return float(_entry(id).get(KEY_SECONDS, 0.0))


static func sound_of(id: StringName) -> String:
	return String(_entry(id).get(KEY_SOUND, ""))


static func sprite_of(id: StringName) -> String:
	return String(_entry(id).get(KEY_SPRITE, ""))
