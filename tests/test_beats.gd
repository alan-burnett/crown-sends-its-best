extends TestCase

## The beat queue, and what a skip must never change (#293,
## `docs/mechanics/beats.md` §1, §3, §4).
##
## 🔒 **Fast-forward settles. It never cancels.** Every beat's outcome exists
## before its animation starts, so skipping is: stop the tween, apply what is
## left, done. There is no half-finished state to unwind and **no path where the
## player sees a different result for having been impatient.**
##
## That is asserted the only way it can honestly be asserted: one queue is run to
## the end, another is skipped at every possible point, and what the stage was
## told is compared. **A design where the animation computes the result will pass
## every other test and break the first time somebody skips.**
##
## 🔒 **A skipped beat's sound is dropped, not compressed.** Four skipped
## sentences must not fire four pen-scratches at once.
##
## 🔒 **A beat carries no prose**, and names assets through a reference rather
## than a path (SPEC §16.3).
##
## ⚠️ **The registry holds data or named static functions, never lambdas** —
## Godot 4.7 segfaults on shutdown with one held at exit.

const WRITE: StringName = &"write_a_line"
const SETTLE_TOWN: StringName = &"settle_a_town"


## A stage that records what it was told, in order.
##
## **Named methods, as §4 requires**: the registry holds the *name* and this
## holds the behaviour, so there is no `Callable` anywhere for a static table to
## be holding at shutdown.
class Stage:
	extends RefCounted

	var told: Array = []

	func write_a_line(beat: Beat) -> void:
		told.append("wrote:%s" % String(beat.outcome.get("text_id", "")))

	func settle_a_town(beat: Beat) -> void:
		told.append("settled:%s@%d,%d" % [beat.subject, beat.place.x, beat.place.y])


func before_each() -> void:
	BeatKinds.reset()
	BeatKinds.register(WRITE, "write_a_line", 0.4, "sound.pen", "sprite.hand")
	BeatKinds.register(SETTLE_TOWN, "settle_a_town", 0.8, "sound.settle", "sprite.town")


func after_each() -> void:
	BeatKinds.reset()


## Six beats a producer might hand over, mixing both kinds.
func _list() -> Array[Beat]:
	var out: Array[Beat] = []
	for index in 3:
		out.append(Beat.new(WRITE, &"letter", {"text_id": "line_%d" % index}, 1.0))
		out.append(Beat.new(
			SETTLE_TOWN, StringName("town_%d" % index), {}, 0.5, Vector2i(index, index)))
	return out


func _queue(stage: Stage) -> BeatQueue:
	var queue := BeatQueue.new(stage)
	queue.push_all(_list())
	return queue


# --- 🔒 A skip at any point leaves identical state -------------------------

func test_letting_it_run_and_skipping_at_any_point_end_the_same() -> void:
	# **The acceptance line, and the reason this file exists.** Run one to the
	# end; skip another after nought, one, two … beats; compare what the stage
	# was told. Any difference is a beat whose outcome depended on its animation.
	var played := Stage.new()
	var full := _queue(played)
	while not full.is_done():
		full.play_next()

	for stop_after in range(0, full.size() + 1):
		var impatient := Stage.new()
		var queue := _queue(impatient)
		for step in stop_after:
			queue.play_next()
		queue.skip()
		assert_eq(impatient.told, played.told,
			"skipping after %d beat(s) left a different world" % stop_after)


func test_beats_settle_in_the_order_they_were_pushed() -> void:
	var stage := Stage.new()
	var queue := _queue(stage)
	while not queue.is_done():
		queue.play_next()
	assert_eq(stage.told[0], "wrote:line_0")
	assert_eq(stage.told[1], "settled:town_0@0,0")
	assert_eq(stage.told.size(), 6, "six beats told the stage %d things" % stage.told.size())


func test_skipping_mid_beat_applies_the_rest_and_no_more() -> void:
	# 🔒 **Safe mid-beat**: the beat being animated was settled before its tween
	# started, so there is nothing half-applied and nothing to unwind.
	var stage := Stage.new()
	var queue := _queue(stage)
	queue.play_next()
	queue.play_next()
	assert_eq(stage.told.size(), 2)

	assert_eq(queue.skip(), 4, "the skip covered the wrong number of beats")
	assert_eq(stage.told.size(), 6, "a skipped beat was applied twice or not at all")
	assert_true(queue.is_done())


func test_skipping_twice_changes_nothing() -> void:
	var stage := Stage.new()
	var queue := _queue(stage)
	queue.skip()
	var after := stage.told.duplicate()
	assert_eq(queue.skip(), 0, "the second skip found something left to do")
	assert_eq(stage.told, after, "skipping again applied outcomes a second time")


func test_an_empty_queue_is_already_done() -> void:
	var queue := BeatQueue.new(Stage.new())
	assert_true(queue.is_done())
	assert_eq(queue.skip(), 0)
	assert_true(queue.play_next() == null, "an empty queue produced a beat")


# --- 🔒 A skipped beat's sound is dropped, not compressed ------------------

func test_the_sounds_of_skipped_beats_are_dropped() -> void:
	var queue := _queue(Stage.new())
	assert_eq(queue.sounds_remaining().size(), 6,
		"six beats wanted %d sounds" % queue.sounds_remaining().size())

	queue.skip()
	assert_empty(queue.sounds_remaining(),
		"four skipped sentences would fire four pen-scratches at once")
	assert_true(queue.was_skipped())


func test_playing_normally_keeps_every_sound() -> void:
	var queue := _queue(Stage.new())
	queue.play_next()
	assert_eq(queue.sounds_remaining().size(), 5,
		"playing a beat dropped somebody else's sound")


# --- 🔒 A beat carries no prose, and names assets rather than paths --------

func test_a_beat_carries_no_prose() -> void:
	# `SimEvent` holds the same line, for the same reason: a sentence here would
	# decide the language in code, in English. Where playback needs a caption it
	# comes from `data/` like a letter does.
	var beat := Beat.new(WRITE, &"letter", {"text_id": "line_0"}, 1.0)
	for entry in beat.get_property_list():
		var name := String(entry["name"])
		assert_false(name == "text" or name == "caption" or name == "prose",
			"a beat carries '%s', which is a sentence written in code" % name)
	for key in beat.outcome:
		var value: Variant = beat.outcome[key]
		if typeof(value) != TYPE_STRING:
			continue
		assert_false(String(value).contains(" "),
			"a beat's outcome carries the sentence '%s'" % value)


func test_a_beat_names_assets_and_never_paths_them() -> void:
	var beat := Beat.new(WRITE, &"letter", {}, 1.0)
	assert_eq(beat.sound(), "sound.pen")
	assert_eq(beat.sprite(), "sprite.hand")
	for id in [beat.sound(), beat.sprite()]:
		assert_false(String(id).begins_with("res://"), "a beat names a resource path")
		assert_false(String(id).contains("/"), "a beat names a file: %s" % id)


# --- 🔒 The registry holds data and method names, never callables ----------

func test_the_registry_holds_no_callables() -> void:
	# ⚠️ Godot 4.7 segfaults on shutdown with a `Callable` held in a static
	# registry (`CLAUDE.md`), and a beat registry is exactly the shape that
	# invites one. The entry holds a method *name*; the stage holds the method.
	assert_eq(BeatKinds.settles_with(WRITE), "write_a_line")
	assert_eq(typeof(BeatKinds.settles_with(WRITE)), TYPE_STRING,
		"a beat kind settles with something other than a method name")


func test_a_kind_nobody_registered_is_inert_rather_than_fatal() -> void:
	# §6: **a beat that did not play is not an event that did not happen.** The
	# sim's state is already correct, and taking a month's playback down over an
	# unknown kind would be the worse failure.
	var stage := Stage.new()
	var queue := BeatQueue.new(stage)
	queue.push(Beat.new(&"a_kind_nobody_has_registered", &"who", {}, 1.0))
	queue.push(Beat.new(WRITE, &"letter", {"text_id": "line_0"}, 1.0))
	queue.skip()
	assert_eq(stage.told, ["wrote:line_0"],
		"an unknown kind either crashed or settled something")
	assert_almost_eq(BeatKinds.seconds_of(&"a_kind_nobody_has_registered"), 0.0, 0.001)


func test_a_queue_with_no_stage_still_drains() -> void:
	# A harness, or a player who has turned animation off entirely.
	var queue := BeatQueue.new(null)
	queue.push_all(_list())
	assert_eq(queue.skip(), 6)
	assert_true(queue.is_done())


# --- The budget is time, not count ------------------------------------------

func test_a_beat_says_how_long_it_wants() -> void:
	# §6's budget is seconds, so a caller trimming a month's playback asks the
	# queue what it costs rather than counting beats.
	var loud := Beat.new(SETTLE_TOWN, &"town", {}, 1.0)
	var quiet := Beat.new(SETTLE_TOWN, &"town", {}, 0.0)
	assert_almost_eq(loud.seconds(), 0.8, 0.001)
	assert_true(quiet.seconds() < loud.seconds(),
		"a beat worth dwelling on took the same time as one that is not")
	assert_true(quiet.seconds() > 0.0, "a quiet beat took no time at all")


func test_the_queue_costs_what_is_left_and_not_what_it_held() -> void:
	var queue := _queue(Stage.new())
	var whole := queue.seconds_remaining()
	queue.play_next()
	assert_true(queue.seconds_remaining() < whole,
		"playing a beat did not reduce what the rest costs")
	queue.skip()
	assert_almost_eq(queue.seconds_remaining(), 0.0, 0.001)


func test_magnitude_is_a_share_of_one() -> void:
	assert_almost_eq(Beat.new(WRITE, &"a", {}, 4.0).magnitude, 1.0, 0.001)
	assert_almost_eq(Beat.new(WRITE, &"a", {}, -2.0).magnitude, 0.0, 0.001)


func test_a_beat_without_a_place_says_so() -> void:
	assert_false(Beat.new(WRITE, &"letter", {}, 1.0).has_a_place(),
		"a line of a letter was given somewhere on the map to be")
	assert_true(Beat.new(SETTLE_TOWN, &"town", {}, 1.0, Vector2i(3, 4)).has_a_place())
