class_name SoundLayers
extends RefCounted

## Three layers of sound, wired differently (#294, `docs/mechanics/beats.md` §2).
##
## | Layer | What it is | Driven by | Queued? |
## | :--- | :--- | :--- | :--- |
## | **Bed** | music and ambience | the **screen** | no — continuous, cross-faded |
## | **Beats** | the scratch of the pen, a town starving | the queue | **yes** |
## | **Feedback** | a click, a page turn, a confirm | player input | no — immediate |
##
## The music question and the page-turn question have different answers, and
## conflating them is what would make this system too big.
##
## ## 🔒 The bed never reacts to the colony
##
## No darkening strings as things go wrong, no swell when a town is founded.
## **The bed is the PC's taste, not the colony's mood.**
##
## The reason is characterisation rather than restraint. He is a pampered
## aristocrat an ocean away; opening these letters is his one chore of the month,
## and he puts on the music he likes while he does it. Music that grieved for a
## famine would belong to somebody who cared, and the joke of the whole game is
## that he is not that man.
##
## It also protects the letters. Adaptive scoring would tell the player how bad
## things are **before he reads a word**, which is the job of the post and of
## nobody else — the same reason `perception.md` keeps judgement in the sender's
## voice rather than in the interface.
##
## **So nothing here takes a colony, a town or a run**, and `test_sound` scans
## this folder to make sure nothing ever starts to.
##
## ## 🔒 Feedback is never queued
##
## A click that waits its turn behind an animation feels broken, and the desk is
## a place where a fast player clicks quickly. **Only beats wait.** Feedback does
## not pass through `BeatQueue` and there is no path by which it could — this
## file does not know the queue exists.
##
## ## 🔒 And the bed survives everything
##
## It does not restart on a fast-forward, and it does not restart moving between
## desk, map and cutscene — it cross-fades. Asking for the track already playing
## is deliberately nothing at all, which is what makes "the desk asks for the
## desk's bed every time it opens" safe.
##
## ## The policy, not the players
##
## Split the way `BeatQueue` is split from `BeatRunner`: this holds what should be
## playing and how loud, as arithmetic that can be asserted headless, and
## `SoundEngine` owns the `AudioStreamPlayer`s. A cross-fade that could only be
## tested with a viewport is a cross-fade nobody tests.

## How long a bed change takes, in seconds. Long enough to read as a change of
## room rather than a cut. Tuning.
const CROSSFADE_SECONDS: float = 1.5

## Quietest a fading track goes before it is considered gone.
const SILENT: float = 0.0
const FULL: float = 1.0

## How many feedback sounds may overlap. **More than one**, because a fast player
## clicking quickly must hear every click rather than cutting off the last one.
const FEEDBACK_VOICES: int = 4

## What is playing now, as an asset id.
var playing: String = ""

## What it is fading toward, or "" when nothing is.
var incoming: String = ""

## Nought to one: how far through the cross-fade.
var _progress: float = 1.0


## Ask for a bed track.
##
## 🔒 **Asking for what is already playing does nothing**, which is the whole of
## "it does not restart moving between screens": every screen asks for its bed
## when it opens, and only a screen that wants a different one gets a change.
##
## Returns whether this actually started a cross-fade.
func request(track: String) -> bool:
	if track == playing and incoming.is_empty():
		return false
	if track == incoming:
		return false
	if playing.is_empty():
		# **Nothing was playing, so there is nothing to fade from.** The first
		# bed of a session comes up rather than cross-fading with silence.
		playing = track
		incoming = ""
		_progress = 1.0
		return not track.is_empty()
	incoming = track
	_progress = 0.0
	return true


## Move the cross-fade on. Called with the frame's delta by the engine, and with
## whatever a test likes.
func advance(delta: float) -> void:
	if incoming.is_empty():
		return
	_progress = clampf(_progress + delta / maxf(0.001, CROSSFADE_SECONDS), 0.0, 1.0)
	if _progress >= 1.0:
		playing = incoming
		incoming = ""


func is_crossfading() -> bool:
	return not incoming.is_empty()


## How loud the outgoing track should be, nought to one.
func outgoing_level() -> float:
	if playing.is_empty():
		return SILENT
	return FULL - _progress if is_crossfading() else FULL


## How loud the incoming track should be, nought to one.
func incoming_level() -> float:
	return _progress if is_crossfading() else SILENT


## 🔒 **A fast-forward does nothing to the bed** (§3). Named so that the runner
## has something to call that plainly is not `stop`, and so that a dev reaching
## for one finds this instead.
func a_skip_happened() -> void:
	pass


## Stop the bed entirely. **Only at the end of a run**, which is the one time
## there is no next screen to fade into.
func silence() -> void:
	playing = ""
	incoming = ""
	_progress = 1.0
