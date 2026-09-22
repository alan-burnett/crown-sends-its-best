class_name SoundEngine
extends Node

## The players behind the three layers (#294, `docs/mechanics/beats.md` §2).
##
## `SoundLayers` decides what should be playing and how loud; this owns the
## `AudioStreamPlayer`s and does what it is told. The split is the same one
## `BeatQueue` and `BeatRunner` take, and for the same reason: a cross-fade that
## could only be tested with a viewport is a cross-fade nobody tests.
##
## ## 🔒 Feedback is never queued
##
## A click that waits its turn behind an animation feels broken, and the desk is
## a place where a fast player clicks quickly. Feedback has **its own pool of
## voices** so that clicking again does not cut off the last click, and it does
## not go anywhere near `BeatQueue` — this file does not know the queue exists.
##
## ## 🔒 The bed survives everything
##
## Two players, cross-faded. Moving between desk, map and cutscene asks for a
## bed; asking for the one already playing is nothing at all. **A fast-forward
## does not touch it**, which is easy to keep true because nothing here is
## connected to the runner.
##
## ## 🔒 And it never reads the colony
##
## Nothing here takes a colony, a town, a run or a measure. It takes asset ids.
## `test_sound` scans this folder for the types it must not name.
##
## ## Assets are references
##
## SPEC §16.3. Everything is an id — `music.desk`, `sound.page_turn` — and the
## registry says what that currently is. A missing one is silence rather than an
## error, because a sound that does not play is a smaller problem than a run that
## does not start.

## Where the tree keeps it, for a screen that has not been handed one.
const AUTOLOAD_PATH: NodePath = ^"/root/Sound"
const ASSETS_PATH: NodePath = ^"/root/Assets"

## The beds each screen asks for. **Ids, and the screen's own choice** — the
## colony has no say in any of them.
const BED_DESK: String = "music.desk"
const BED_MAP: String = "music.map"
const BED_CUTSCENE: String = "music.cutscene"

var layers: SoundLayers = null

## Where ids resolve. Injected, for the same reason `AssetRegistry`'s own source
## is: the `Assets` autoload only exists when the game boots normally.
var assets: AssetRegistry = null

var _a: AudioStreamPlayer = null
var _b: AudioStreamPlayer = null
## Which of the two is carrying the track that is playing. The other is either
## silent or fading in behind it.
var _on_a: bool = true
var _feedback: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _beats: AudioStreamPlayer = null


func _init() -> void:
	layers = SoundLayers.new()


func _ready() -> void:
	_a = _voice()
	_b = _voice()
	_beats = _voice()
	for index in SoundLayers.FEEDBACK_VOICES:
		_feedback.append(_voice())
	if assets == null:
		# Looked up through the tree rather than by the autoload's global name.
		# That global only exists when the game boots normally, and naming it
		# would stop this file compiling under `--script`.
		assets = get_node_or_null(ASSETS_PATH) as AssetRegistry
	set_process(true)


func _voice() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	return player


# --- The bed ----------------------------------------------------------------

## Ask for a screen's bed. Cross-fades, or does nothing if it is already on.
func bed(track: String) -> void:
	var was := layers.playing
	if not layers.request(track):
		return
	if layers.is_crossfading():
		_load(_next_player(), layers.incoming)
	elif was != layers.playing:
		# Nothing was playing, so it comes up rather than fading in.
		_load(_current_player(), layers.playing)
	_apply_levels()
	_start(_current_player())
	if layers.is_crossfading():
		_start(_next_player())


## 🔒 **A fast-forward does not restart or interrupt the bed** (§3). Here so the
## runner has something to call that plainly is not `stop`.
func a_skip_happened() -> void:
	layers.a_skip_happened()


## Only at the end of a run, when there is no next screen to fade into.
func silence() -> void:
	layers.silence()
	for player in [_a, _b]:
		if player != null:
			player.stop()


func _process(delta: float) -> void:
	if not layers.is_crossfading():
		return
	layers.advance(delta)
	if not layers.is_crossfading():
		# The fade finished: the incoming player is now the one carrying the bed.
		_on_a = not _on_a
		var spent := _next_player()
		if spent != null:
			spent.stop()
	_apply_levels()


func _current_player() -> AudioStreamPlayer:
	return _a if _on_a else _b


func _next_player() -> AudioStreamPlayer:
	return _b if _on_a else _a


func _apply_levels() -> void:
	_set_level(_current_player(), layers.outgoing_level())
	_set_level(_next_player(), layers.incoming_level())


## Nought to one as decibels. **Silence is off rather than very quiet**, because
## `linear_to_db(0)` is negative infinity and a player left at it goes on
## consuming a voice for nothing.
func _set_level(player: AudioStreamPlayer, level: float) -> void:
	if player == null:
		return
	if level <= 0.0:
		player.volume_db = -80.0
		return
	player.volume_db = linear_to_db(clampf(level, 0.0, 1.0))


# --- Beats and feedback -----------------------------------------------------

## A beat's sound. One at a time, because beats are the layer that queues.
func beat(id: String) -> void:
	_play_on(_beats, id)


## 🔒 **Immediate, and never queued.** Round-robin over several voices so that a
## fast player clicking quickly hears every click rather than cutting off the
## last one.
func feedback(id: String) -> void:
	if _feedback.is_empty():
		return
	_play_on(_feedback[_next_voice], id)
	_next_voice = (_next_voice + 1) % _feedback.size()


func _play_on(player: AudioStreamPlayer, id: String) -> void:
	if player == null:
		return
	var stream := _stream(id)
	if stream == null:
		return
	player.volume_db = 0.0
	player.stream = stream
	player.play()


func _load(player: AudioStreamPlayer, id: String) -> void:
	if player == null:
		return
	player.stream = _stream(id)


func _start(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null or player.playing:
		return
	player.play()


## **Silence rather than an error.** A sound that does not play is a smaller
## problem than a run that does not start, and the registry has already reported
## the missing id once.
func _stream(id: String) -> AudioStream:
	if assets == null or id.is_empty() or not assets.has(id):
		return null
	return assets.resource(id) as AudioStream
