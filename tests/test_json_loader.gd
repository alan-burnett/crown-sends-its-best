extends TestCase

## The loader reads a tree keyed by id, and fails loudly and specifically (#1).

const FIXTURES: String = "res://tests/fixtures"


func test_loads_a_tree_keyed_by_id() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	assert_true(result.ok(), result.error_report())
	assert_eq(result.ids(), PackedStringArray(["alpha", "beta", "delta", "gamma"]))
	assert_eq(result.records["alpha"]["label"], "first")


func test_reads_arrays_of_records() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	assert_has(result.records, "beta")
	assert_has(result.records, "gamma")


func test_recurses_into_subdirectories() -> void:
	# "A dev can add a new JSON file to data/ and have it loaded without touching
	# engine code" — including in a new subfolder.
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	assert_has(result.records, "delta")


func test_records_name_their_source_file() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	var source: String = result.records["alpha"][JsonLoader.SOURCE_KEY]
	assert_true(source.ends_with("alpha.json"), "got %s" % source)


func test_malformed_file_fails_naming_the_file() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("malformed"))
	assert_false(result.ok(), "malformed JSON must not load quietly")
	assert_true(result.errors[0].file.ends_with("broken.json"), "the error must name the file")
	assert_not_empty(result.errors[0].message)


func test_duplicate_ids_are_an_error() -> void:
	# Not a silent overwrite: which file won would otherwise depend on the order
	# the filesystem happened to enumerate the directory.
	var result := JsonLoader.load_dir(FIXTURES.path_join("duplicate"))
	assert_false(result.ok(), "a duplicate id must be an error")
	assert_eq(result.errors[0].key, "clash", "the error must name the offending id")
	assert_true(result.errors[0].message.contains("one.json"), "and say where it was already defined")


func test_missing_id_names_the_key() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("no_id"))
	assert_false(result.ok())
	assert_eq(result.errors[0].key, "id")
	assert_true(result.errors[0].file.ends_with("anonymous.json"))


func test_missing_directory_is_an_error() -> void:
	assert_false(JsonLoader.load_dir(FIXTURES.path_join("not_here")).ok())


func test_file_order_is_sorted() -> void:
	var files := JsonLoader.find_json_files(FIXTURES.path_join("good"))
	var sorted_files := files.duplicate()
	sorted_files.sort()
	assert_eq(files, sorted_files, "load order must not depend on the filesystem")


func test_json_numbers_arrive_as_floats() -> void:
	# A guard, not a wish. Godot's parser has no integer type, so `"amount": 200`
	# arrives as 200.0. Everything that reads a number has to know this: left
	# alone it renders "200.0" in a letter and moves the state hash.
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	assert_eq(typeof(result.records["alpha"]["amount"]), TYPE_FLOAT)


func test_declared_types_recover_integers() -> void:
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	var amount := JsonTypes.to_int(result.records["alpha"]["amount"], "alpha.amount")
	assert_eq(amount, 200)
	assert_eq(typeof(amount), TYPE_INT)


func test_genuine_floats_survive_coercion_helpers() -> void:
	# A lean of 0.25 is a real float. `normalise_integers` must leave it alone
	# while recovering whole numbers.
	var result := JsonLoader.load_dir(FIXTURES.path_join("good"))
	var normalised: Dictionary = JsonTypes.normalise_integers(result.records["alpha"])
	assert_eq(normalised["amount"], 200)
	assert_eq(normalised["lean"], 0.25)


func test_is_int_like_rejects_fractions() -> void:
	assert_true(JsonTypes.is_int_like(200.0))
	assert_true(JsonTypes.is_int_like(200))
	assert_false(JsonTypes.is_int_like(200.5))
