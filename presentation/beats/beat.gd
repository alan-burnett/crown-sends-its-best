class_name Beat
extends RefCounted

## One thing worth the player's attention (#293, `docs/mechanics/beats.md` §4).
##
## ```
## kind       StringName   registry id: picks the art and the sound
## subject    StringName   town, contact, company — who it is about
## place      Vector2i     where, when it has a where
## magnitude  float        0..1, how hard to draw it and how loud
## outcome    Dictionary   what will be true when it has played
## ```
##
## ## 🔒 A beat carries no prose
##
## `SimEvent` already holds this line — *the payload is never prose* — for the
## same reason: a sentence here would decide the language in code, in English.
## Where playback needs a caption it comes from `data/` like a letter does, keyed
## by `kind`.
##
## ## 🔒 A beat names assets, it never paths them
##
## SPEC §16.3 requires replaceable references, so `kind` resolves through
## `BeatKinds` to a sound and a sprite. Placeholders until the art swap, and the
## swap must need no code change.
##
## ## 🔒 The outcome exists before the animation starts
##
## §3, and the whole reason this class carries an `outcome` at all. **The
## animation interpolates toward a destination already known; it never computes
## it.** So skipping is: stop the tween, apply what is left, done — there is no
## half-finished state to unwind and no path where the player sees a different
## result for having been impatient.
##
## The two shipped producers already have this property, which is why it is a
## lock rather than a proposal: `ReplyWizard.assemble()` is a pure function of
## the choices made so far, and the map's month-end state is the sim's state.
##
## **A design where the animation computes the result will pass every test and
## break the first time somebody skips.**

const NOWHERE: Vector2i = Vector2i(-1, -1)

var kind: StringName = &""
var subject: StringName = &""
var place: Vector2i = NOWHERE

## How hard to draw it and how loud, nought to one.
var magnitude: float = 1.0

## 🔒 **What will be true when it has played**, as typed data.
##
## Settled by the stage rather than interpreted here — a beat knows what the
## destination is and nothing about how to get there.
var outcome: Dictionary = {}


func _init(
	p_kind: StringName = &"",
	p_subject: StringName = &"",
	p_outcome: Dictionary = {},
	p_magnitude: float = 1.0,
	p_place: Vector2i = NOWHERE,
) -> void:
	kind = p_kind
	subject = p_subject
	outcome = p_outcome.duplicate()
	magnitude = clampf(p_magnitude, 0.0, 1.0)
	place = p_place


func has_a_place() -> bool:
	return place != NOWHERE


## How long this beat wants, in seconds.
##
## **Derived from the kind and scaled by magnitude**, because §6's budget is time
## rather than count: a queue is trimmed by what it costs in seconds, and a beat
## that could not say how long it takes could not be budgeted for.
func seconds() -> float:
	return BeatKinds.seconds_of(kind) * lerpf(BeatKinds.QUIETEST, 1.0, magnitude)


## The sound this beat makes, as an asset id.
func sound() -> String:
	return BeatKinds.sound_of(kind)


## The sprite this beat draws, as an asset id.
func sprite() -> String:
	return BeatKinds.sprite_of(kind)


## For the event log and the harness. **Still no prose.**
func to_dict() -> Dictionary:
	return {
		"kind": String(kind),
		"subject": String(subject),
		"place": [place.x, place.y],
		"magnitude": magnitude,
		"outcome": outcome.duplicate(),
	}
