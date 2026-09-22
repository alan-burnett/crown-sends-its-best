class_name BeatQueue
extends RefCounted

## Beats pushed, played in order, and skipped at any time (#293,
## `docs/mechanics/beats.md` §1, §3).
##
## ## 🔒 Fast-forward settles. It never cancels
##
## §3 is the whole point of this file. **Every beat's outcome exists before its
## animation starts**, so skipping is: stop the tween, apply what is left,
## done.
##
## There is no half-finished state to unwind, no beat that must be allowed to
## finish for correctness, and **no path where the player sees a different result
## for having been impatient.** `test_beats` asserts exactly that by running one
## queue to the end and skipping another at every possible point, and comparing
## what the stage was told.
##
## **A design where the animation computes the result will pass every test and
## break the first time somebody skips.** So the queue settles a beat *before*
## the runner is told to animate it — the animation is always catching up to a
## destination already reached.
##
## ## The split follows the house style
##
## `ReplyWizard` is logic and `letter_view.gd` is its screen, and that separation
## is what lets the wizard be tested without a viewport. Same here: **this is a
## `RefCounted` and `BeatRunner` is the node.** A month's beat list can be
## asserted headless, which is the acceptance line that matters most.
##
## ## 🔒 What a skipped beat does to sound
##
## **Its sound is dropped, not compressed.** Four skipped sentences must not fire
## four pen-scratches at once — one resolution sound covers the whole skip, and
## the bed carries on underneath. The queue reports which sounds a caller should
## actually play; skipping reports none of them.
##
## ## Selection is not here
##
## A producer hands the queue a list (§1). The event log needs a selector and the
## reply wizard does not, so the selector is a component only one of them uses
## and the queue is shared by both.

signal beat_settled(beat: Beat)
signal drained

## The object whose named methods apply outcomes. §4's `settles` is a method on
## this, which is what keeps every `Callable` off the registry.
var stage: Object = null

var beats: Array[Beat] = []

var _at: int = 0
var _skipped: bool = false


func _init(p_stage: Object = null) -> void:
	stage = p_stage


func push(beat: Beat) -> void:
	if beat != null:
		beats.append(beat)


func push_all(list: Array) -> void:
	for entry in list:
		push(entry as Beat)


func size() -> int:
	return beats.size()


## How many have been settled so far.
func settled() -> int:
	return _at


func is_done() -> bool:
	return _at >= beats.size()


func was_skipped() -> bool:
	return _skipped


## What is left to play, in order.
func remaining() -> Array[Beat]:
	var out: Array[Beat] = []
	for index in range(_at, beats.size()):
		out.append(beats[index])
	return out


## How long the rest of the queue wants, in seconds.
##
## §6's budget is time rather than count, so a caller trimming a month's playback
## asks this rather than counting beats.
func seconds_remaining() -> float:
	var total := 0.0
	for beat in remaining():
		total += beat.seconds()
	return total


## Settle the next beat and return it, or null when there are none left.
##
## 🔒 **Settled first, animated after.** The runner asks for the next beat, gets
## a world in which that beat has already happened, and then spends its half
## second interpolating toward it.
func play_next() -> Beat:
	if is_done():
		drained.emit()
		return null
	var beat := beats[_at]
	_at += 1
	_settle(beat)
	if is_done():
		drained.emit()
	return beat


## Apply every remaining beat's outcome at once.
##
## Returns how many were settled by the skip, which is what a caller needs to
## know whether to play the one resolution sound.
##
## **Safe mid-beat**, because the beat being animated was already settled by
## `play_next` before the tween started — so there is nothing half-applied to
## finish and nothing to unwind. Stopping the tween is the runner's business and
## has no bearing on state.
func skip() -> int:
	var settled_now := 0
	while not is_done():
		_settle(beats[_at])
		_at += 1
		settled_now += 1
	_skipped = true
	drained.emit()
	return settled_now


## The sounds a caller should actually play for what is left.
##
## 🔒 **Empty after a skip** (§3). Four skipped sentences must not fire four
## pen-scratches at once; the caller plays its single resolution sound instead.
func sounds_remaining() -> PackedStringArray:
	var out := PackedStringArray()
	for beat in remaining():
		var id := beat.sound()
		if not id.is_empty():
			out.append(id)
	return out


## Push everything back to the start. **Does not unsettle anything** — there is
## no such operation, because §3's contract is that an outcome once applied is
## simply true.
func clear() -> void:
	beats.clear()
	_at = 0
	_skipped = false


func _settle(beat: Beat) -> void:
	var method := BeatKinds.settles_with(beat.kind)
	# **An unregistered kind settles nothing, and that is not an error.** §6: a
	# beat that did not play is not an event that did not happen — the sim's
	# state is already correct, and taking the month's playback down over an
	# unknown kind would be the worse failure.
	if stage != null and not method.is_empty() and stage.has_method(method):
		stage.call(method, beat)
	beat_settled.emit(beat)
