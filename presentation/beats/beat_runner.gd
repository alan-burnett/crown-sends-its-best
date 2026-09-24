class_name BeatRunner
extends Node

## Plays a `BeatQueue` in real time, and gets out of the way when asked (#293,
## `docs/mechanics/beats.md` §1, §3).
##
## ## 🔒 It animates. It never decides
##
## The queue settles a beat *before* this is told to show it, so every tween here
## is catching up to a destination already reached. **Nothing in this file may
## compute an outcome**, and a dev who reaches for one has broken §3 in the way
## that passes every test and shows up the first time somebody skips.
##
## Which is why the node is this thin. `BeatQueue` holds the contract and is
## tested headless with no viewport; this holds a timer.
##
## ## Skipping stops the tween and nothing else
##
## There is no state to unwind. The beat being shown was settled before its
## animation started, so stopping halfway leaves exactly the world that stopping
## at the end would.
##
## **And one sound covers the whole skip** (§3): the individual beats' sounds are
## dropped rather than compressed, because four skipped sentences firing four
## pen-scratches at once is the failure the rule exists to prevent.

## The asset id of the sound a skip makes — the letter folded, the map settling.
## One, however many beats it covered.
const RESOLUTION_SOUND: String = "sound.beats_resolved"

signal beat_shown(beat: Beat)
signal finished

var queue: BeatQueue = null

## Where sounds come from. **Injected**, for the same reason the cutscene
## screen's is: the `Assets` autoload only exists when the game boots normally.
var assets: AssetRegistry = null

## Whether to play at all. A player who has turned animation off, or a harness,
## gets the same world a second later than everybody else.
var animates: bool = true

## 🔒 **`finished` fires once per `play`.** A player tapping skip as the last
## beat ends would otherwise finish twice, and a caller that closes a screen on
## it would close something else.
var _over: bool = false

var _timer: Timer = null
var _player: AudioStreamPlayer = null
var _showing: Beat = null


func _ready() -> void:
	_make_nodes()


## The timer and the player, made on first need. **Before `_ready` as well**: a
## caller that adds this and plays it in one breath would otherwise find no timer
## and play the whole month in a single frame.
func _make_nodes() -> void:
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_next)
		add_child(_timer)
	if _player == null:
		_player = AudioStreamPlayer.new()
		add_child(_player)


## Start playing. An empty queue finishes at once.
func play(p_queue: BeatQueue) -> void:
	_make_nodes()
	queue = p_queue
	_over = false
	if queue == null or queue.is_done():
		_finish()
		return
	if not animates:
		skip()
		return
	_next()


## Fast-forward. Applies every remaining outcome and plays one sound for the lot.
func skip() -> void:
	if queue == null:
		_finish()
		return
	if _timer != null:
		_timer.stop()
	_showing = null
	var covered := queue.skip()
	if covered > 0:
		_play(RESOLUTION_SOUND)
	_finish()


## Which beat is on screen, or null.
func showing() -> Beat:
	return _showing


func _next() -> void:
	if queue == null or queue.is_done():
		_showing = null
		_finish()
		return

	# 🔒 **Settled here, by the queue, before anything is drawn.** The wait below
	# is decoration over a world that has already changed.
	_showing = queue.play_next()
	if _showing == null:
		_finish()
		return

	_play(_showing.sound())
	beat_shown.emit(_showing)

	var wait := _showing.seconds()
	if wait <= 0.0 or _timer == null:
		_next()
		return
	_timer.start(wait)


func _finish() -> void:
	if _over:
		return
	_over = true
	finished.emit()


func _play(id: String) -> void:
	if _player == null or assets == null or id.is_empty() or not assets.has(id):
		return
	var stream := assets.resource(id) as AudioStream
	if stream == null:
		return
	_player.stream = stream
	_player.play()
