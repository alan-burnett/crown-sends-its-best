extends TestCase

## Three layers of sound, and the bed that ignores the colony (#294,
## `docs/mechanics/beats.md` §2).
##
## 🔒 **The bed never reacts to the colony.** No darkening strings as things go
## wrong, no swell when a town is founded. The bed is the PC's taste, not the
## colony's mood — he is a pampered aristocrat an ocean away and this is his one
## chore of the month, and music that grieved for a famine would belong to
## somebody who cared.
##
## It also protects the letters: adaptive scoring would tell the player how bad
## things are **before he reads a word**, which is the post's job and nobody
## else's.
##
## 🔒 **Feedback is never queued.** A click that waits its turn behind an
## animation feels broken, and the desk is where a fast player clicks fast.
##
## 🔒 **The bed survives everything** — a fast-forward does not restart it, and
## moving between desk, map and cutscene cross-fades rather than cutting.
##
## The players themselves are not tested, per `CLAUDE.md`: what is tested is the
## arithmetic that decides what should be playing and how loud, which is the half
## that can break silently.

const DESK: String = SoundEngine.BED_DESK
const MAP: String = SoundEngine.BED_MAP


func _layers(playing: String = DESK) -> SoundLayers:
	var layers := SoundLayers.new()
	layers.request(playing)
	return layers


# --- 🔒 The bed survives everything ----------------------------------------

func test_the_first_bed_of_a_session_comes_up_rather_than_fading() -> void:
	# There is nothing to fade from, so cross-fading with silence would be half a
	# fade for no reason.
	var layers := SoundLayers.new()
	assert_true(layers.request(DESK))
	assert_eq(layers.playing, DESK)
	assert_false(layers.is_crossfading(), "the first track faded in from nothing")
	assert_almost_eq(layers.outgoing_level(), SoundLayers.FULL, 0.001)


func test_asking_for_the_track_already_playing_does_nothing() -> void:
	# 🔒 **The whole of "it does not restart moving between screens."** Every
	# screen asks for its bed when it opens; only one that wants a different
	# track gets a change.
	var layers := _layers()
	assert_false(layers.request(DESK), "asking again restarted the bed")
	assert_false(layers.is_crossfading())
	assert_eq(layers.playing, DESK)


func test_moving_between_screens_crossfades_rather_than_cutting() -> void:
	var layers := _layers()
	assert_true(layers.request(MAP), "asking for the map's bed changed nothing")
	assert_true(layers.is_crossfading())
	assert_eq(layers.playing, DESK, "the old track was cut rather than faded")
	assert_eq(layers.incoming, MAP)

	# Halfway: both are audible, and they are not both at full.
	layers.advance(SoundLayers.CROSSFADE_SECONDS * 0.5)
	assert_true(layers.outgoing_level() > 0.0 and layers.outgoing_level() < 1.0,
		"the old track was not fading: %f" % layers.outgoing_level())
	assert_true(layers.incoming_level() > 0.0 and layers.incoming_level() < 1.0,
		"the new track was not rising: %f" % layers.incoming_level())

	layers.advance(SoundLayers.CROSSFADE_SECONDS)
	assert_false(layers.is_crossfading(), "the fade never finished")
	assert_eq(layers.playing, MAP)
	assert_almost_eq(layers.outgoing_level(), SoundLayers.FULL, 0.001)


func test_asking_again_mid_fade_for_the_track_arriving_changes_nothing() -> void:
	# A player who moves desk → map → map should not restart the fade.
	var layers := _layers()
	layers.request(MAP)
	layers.advance(SoundLayers.CROSSFADE_SECONDS * 0.4)
	var reached := layers.incoming_level()
	assert_false(layers.request(MAP), "asking twice restarted the cross-fade")
	assert_almost_eq(layers.incoming_level(), reached, 0.001)


func test_a_fast_forward_does_not_touch_the_bed() -> void:
	# 🔒 §3: fast-forward settles and never cancels, and the bed is not part of
	# what a skip settles. This exists so a dev reaching for `stop` finds it.
	var layers := _layers()
	var before := layers.playing
	layers.a_skip_happened()
	assert_eq(layers.playing, before, "a skip changed the music")
	assert_false(layers.is_crossfading(), "a skip started a cross-fade")


func test_only_the_end_of_a_run_silences_it() -> void:
	var layers := _layers()
	layers.silence()
	assert_eq(layers.playing, "")
	assert_almost_eq(layers.outgoing_level(), SoundLayers.SILENT, 0.001)


# --- 🔒 The bed never reads the colony -------------------------------------

func test_nothing_in_the_sound_layer_names_the_colony() -> void:
	# 🔒 **The acceptance line, asked of the codebase**, because the failure is
	# not a wrong number — it is music that tells the player how bad things are
	# before he has read a word, which no test of a return value would catch.
	var forbidden: PackedStringArray = [
		"Colony", "Town", "RunState", "RebelSentiment", "QualityOfLife",
		"Prestige", "CrownStanding", "ColonyMeasures", "WorldValues",
		"months_hungry", "rebel_sentiment", "quality_of_life",
	]
	var named := PackedStringArray()
	for path in _scripts_in("res://presentation/sound"):
		var code := _code_of(path)
		for token in forbidden:
			if code.contains(String(token)):
				named.append("%s names %s" % [path.get_file(), token])
	assert_empty(named,
		"the bed can see the colony: %s" % ", ".join(named))


func test_the_beds_are_named_by_screen_and_not_by_condition() -> void:
	# A bed per screen is the PC's taste. A bed per mood would be the colony's.
	for track in [SoundEngine.BED_DESK, SoundEngine.BED_MAP, SoundEngine.BED_CUTSCENE]:
		assert_true(String(track).begins_with("music."),
			"'%s' is not an asset id" % track)
		for mood in ["grim", "hopeful", "famine", "tense", "triumph"]:
			assert_false(String(track).contains(mood),
				"'%s' is a mood rather than a screen" % track)


# --- 🔒 Feedback is never queued -------------------------------------------

func test_the_sound_layers_know_nothing_of_the_beat_queue() -> void:
	# 🔒 **A click that waits its turn behind an animation feels broken.** The
	# way that stays true is that feedback has no path into the queue at all —
	# so neither file may so much as name it.
	var named := PackedStringArray()
	for path in _scripts_in("res://presentation/sound"):
		var code := _code_of(path)
		for token in ["BeatQueue", "BeatRunner", "push_all"]:
			if code.contains(token):
				named.append("%s names %s" % [path.get_file(), token])
	assert_empty(named, "feedback can reach the queue: %s" % ", ".join(named))


func test_feedback_has_more_than_one_voice() -> void:
	# So that clicking again does not cut off the last click, which is what a
	# single player would do and what a fast player at the desk would hear.
	assert_true(SoundLayers.FEEDBACK_VOICES > 1,
		"a fast player's second click would cut off the first")


# --- Assets are references --------------------------------------------------

func test_every_track_is_an_id_and_never_a_path() -> void:
	# SPEC §16.3. Placeholders are fine; the swap must need no code change.
	for id in [SoundEngine.BED_DESK, SoundEngine.BED_MAP, SoundEngine.BED_CUTSCENE,
			BeatRunner.RESOLUTION_SOUND]:
		assert_false(String(id).begins_with("res://"), "'%s' is a resource path" % id)
		assert_false(String(id).contains("/"), "'%s' names a file" % id)


## A script with its comments taken out.
##
## **The locks are about code, not prose.** Both files explain at length why they
## must not reach the queue or read the colony, and a scan that counted the
## explanation would forbid explaining it — so the comment lines come out first.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed := String(line).strip_edges()
		if not trimmed.begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _scripts_in(at: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			out.append(at.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	assert_false(out.is_empty(), "no scripts were found under %s to check" % at)
	return out
