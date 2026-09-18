extends TestCase

## Collections, the language suffix, and the asset indirection layer (#1).
##
## Runs against the real `data/` tree rather than a fixture, so it also answers
## "does the content currently in the repo load".

var db: Node = null
var assets: Node = null


func before_each() -> void:
	db = load("res://core/content/content_db.gd").new()
	db.load_all("en")
	assets = load("res://core/assets/asset_registry.gd").new()
	assets.content_source = db


func after_each() -> void:
	db.free()
	assets.free()


func test_real_data_tree_loads_clean() -> void:
	assert_true(db.ok(), db.error_report())


func test_language_suffix_becomes_the_collection_name() -> void:
	# `data/letters_en/` is the collection `letters`. A second language is a
	# copied folder where only `text` fields change — no code, no new name.
	var names := db.collection_names()
	assert_true(names.has("letters"), "expected a 'letters' collection, got %s" % names)
	assert_false(names.has("letters_en"), "the language suffix must not leak into the name")


func test_unsuffixed_directories_keep_their_name() -> void:
	var names := db.collection_names()
	assert_true(names.has("assets"), "got %s" % names)
	assert_true(names.has("triggers"), "got %s" % names)


func test_other_languages_are_not_loaded() -> void:
	var other: Node = load("res://core/content/content_db.gd").new()
	other.load_all("fr")
	# No `letters_fr` folder exists yet, so selecting French yields no letters
	# rather than silently falling back to the English prose.
	assert_empty(other.collection("letters"), "selecting another language must not load English")
	other.free()


func test_collection_names_and_ids_are_sorted() -> void:
	var names := db.collection_names()
	var sorted_names := names.duplicate()
	sorted_names.sort()
	assert_eq(names, sorted_names)


func test_asset_ids_resolve_to_paths() -> void:
	# SPEC §16.3: nothing outside the registry names a file path, so swapping
	# placeholder art for final art is a change to a data file.
	assert_true(assets.has("icon.app"), "expected icon.app in data/assets")
	assert_eq(assets.resolve("icon.app"), "res://icon.svg")


func test_unregistered_asset_resolves_to_nothing() -> void:
	assert_eq(assets.resolve("portrait.nobody"), "")
	assert_false(assets.has("portrait.nobody"))


func test_missing_asset_falls_back_to_a_placeholder() -> void:
	# A typo in an art path must not cost a run (SPEC §16.2, ironman).
	var texture: Texture2D = assets.texture("portrait.nobody")
	assert_true(texture != null, "a missing asset must still return a texture")
	assert_eq(texture, assets.placeholder())
