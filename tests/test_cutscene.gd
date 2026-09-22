extends TestCase

## A cutscene is a painting and a line of text (#297,
## `docs/mechanics/cutscenes.md` §1).
##
## 🔒 **One image per panel and one caption per panel.** A panel with two
## captions is two panels; a caption with no image is not a cutscene. A panel
## that silently dropped half of itself would be a panel the player never sees
## the rest of — and one that rendered as a caption over a placeholder would look
## exactly like a missing art file, which is the failure the placeholder exists
## to make obvious, spent on the wrong problem.
##
## 🔒 **A single-panel cutscene and a three-panel one use the same path.** The
## first is one where the first panel is also the last, which needs no special
## case anywhere.
##
## 🔒 **The image is a reference, never a path** (SPEC §16.3), so the Author's
## final art lands as a change to a data file.
##
## **The screen itself is not tested**, per `CLAUDE.md`: tests on UI are not
## written here. What is tested is the content the screen consumes, which is
## exactly the sort of silent breakage that is expensive.

func _panels(count: int) -> Array:
	var out: Array = []
	for index in count:
		out.append({"image": "cutscene.panel_%d" % index, "text": "Panel %d." % index})
	return out


func _of(count: int) -> Cutscene:
	return Cutscene.from_data({"id": "probe", "panels": _panels(count)})


# --- 🔒 One image and one caption per panel --------------------------------

func test_a_panel_carries_an_image_and_a_caption() -> void:
	var cutscene := _of(1)
	assert_eq(cutscene.count(), 1)
	assert_eq(cutscene.image_at(0), "cutscene.panel_0")
	assert_eq(cutscene.text_at(0), "Panel 0.")


func test_a_panel_with_no_image_is_refused() -> void:
	# §1: a caption with no image is not a cutscene.
	var cutscene := Cutscene.from_data({
		"id": "probe", "panels": [{"text": "A line with nothing behind it."}],
	})
	assert_true(cutscene.is_empty(), "a caption alone was accepted as a panel")


func test_a_panel_with_no_caption_is_refused() -> void:
	var cutscene := Cutscene.from_data({
		"id": "probe", "panels": [{"image": "cutscene.silent"}],
	})
	assert_true(cutscene.is_empty(), "a painting with nothing to say was accepted")


func test_a_good_panel_survives_a_bad_one_beside_it() -> void:
	# **The rest of the cutscene still shows.** One malformed panel is an Author
	# mistake; losing the other four to it would be a second one.
	var cutscene := Cutscene.from_data({"id": "probe", "panels": [
		{"image": "cutscene.one", "text": "The first."},
		{"image": "cutscene.two"},
		{"image": "cutscene.three", "text": "The third."},
	]})
	assert_eq(cutscene.count(), 2, "the good panels did not survive: %d" % cutscene.count())
	assert_eq(cutscene.text_at(1), "The third.")


func test_a_record_with_no_panels_is_an_empty_cutscene() -> void:
	assert_true(Cutscene.from_data({"id": "probe"}).is_empty())
	assert_true(Cutscene.from_data({"id": "probe", "panels": "not a list"}).is_empty())
	assert_true(Cutscene.from_data({}).is_empty())


# --- 🔒 One panel and three take the same path ------------------------------

func test_the_last_panel_is_the_last_however_many_there_are() -> void:
	# The acceptance line. A single-panel cutscene is one where the first panel
	# is also the last, so nothing anywhere compares counts.
	var one := _of(1)
	assert_true(one.is_last(0), "the only panel was not the last one")

	var three := _of(3)
	assert_false(three.is_last(0))
	assert_false(three.is_last(1))
	assert_true(three.is_last(2), "the third of three was not the last")


func test_asking_past_the_end_is_not_a_crash() -> void:
	# The screen advances off the last panel, so the index it holds goes one
	# beyond what exists for exactly as long as it takes to emit.
	var cutscene := _of(2)
	assert_eq(cutscene.image_at(9), "")
	assert_eq(cutscene.text_at(9), "")
	assert_eq(cutscene.text_at(-1), "")
	assert_true(cutscene.is_last(9))


func test_an_empty_cutscene_is_already_over() -> void:
	# Rather than showing a blank page the player has to dismiss.
	var empty := Cutscene.new(&"nothing")
	assert_true(empty.is_empty())
	assert_true(empty.is_last(0), "an empty cutscene had a panel still to come")


# --- 🔒 The image is a reference, never a path ------------------------------

func test_an_image_is_an_asset_id_and_not_a_file() -> void:
	# SPEC §16.3: nothing outside `AssetRegistry` names a file path, so final art
	# lands as a change to `data/assets/` and not as a change to a cutscene.
	var cutscene := Cutscene.of(&"probe", "cutscene.arrival", "We made landfall.")
	var image := cutscene.image_at(0)
	assert_false(image.begins_with("res://"), "a cutscene names a resource path")
	assert_false(image.contains("/"), "a cutscene names a file: %s" % image)
	assert_true(image.begins_with("cutscene."),
		"an asset id is a dotted name in its own namespace: %s" % image)


func test_a_missing_asset_renders_as_the_placeholder() -> void:
	# **A missing asset is never fatal** — losing a run to a typo in an art path
	# would be a poor trade (SPEC §16.2, ironman).
	var registry := AssetRegistry.new()
	registry.content_source = ContentDatabase.new()
	registry.content_source.load_all("en")
	assert_false(registry.has("cutscene.a_painting_nobody_has_made"))
	assert_true(registry.texture("cutscene.a_painting_nobody_has_made") != null,
		"a missing painting rendered as nothing at all")
	registry.content_source.free()
	registry.free()


# --- The opening ------------------------------------------------------------

func test_the_opening_is_named_once() -> void:
	# SPEC §6.1: a run opens with one. The boot looks for this id and the file
	# that supplies it (#299) declares it, so neither names a string of its own.
	assert_eq(String(Cutscene.OPENING), "opening")
	assert_eq(Cutscene.COLLECTION, "cutscenes")
