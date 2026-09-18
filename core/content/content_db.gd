extends Node

## The loaded content of `data/`, as an autoload (`Content`).
##
## Every top-level directory under `data/` is a **collection**, named after the
## directory. A directory whose name ends in a two-letter language suffix —
## `letters_en` — is a localised collection, and only the one matching the
## selected language loads. That is what makes a second language "a copied
## folder where only `text` fields change" (`CLAUDE.md`): the folder carries the
## suffix, prose stays inline with its mechanics, and no code changes.
##
## Adding content means adding a file. Nothing here has to be told about it.

const DATA_ROOT: String = "res://data"
const DEFAULT_LANGUAGE: String = "en"

## Matches `<collection>_<lang>`, e.g. `letters_en`.
const LOCALISED_PATTERN: String = "^(?<name>.+)_(?<lang>[a-z]{2})$"

var language: String = DEFAULT_LANGUAGE

var _collections: Dictionary = {}  # String -> Dictionary(id -> record)
var _errors: Array[JsonLoader.LoadError] = []
var _loaded: bool = false


func _ready() -> void:
	# The validator CLI and the tests drive loading themselves, so starting the
	# game is the only case that needs it done automatically.
	if not _loaded:
		load_all()


## Load every collection under `data/`. Returns true when nothing went wrong.
func load_all(p_language: String = "") -> bool:
	if not p_language.is_empty():
		language = p_language
	_collections.clear()
	_errors.clear()
	_loaded = true

	var regex := RegEx.new()
	regex.compile(LOCALISED_PATTERN)

	for directory in _collection_directories():
		var match_result := regex.search(directory)
		var collection_name: String = directory
		if match_result != null:
			if match_result.get_string("lang") != language:
				continue
			collection_name = match_result.get_string("name")

		var result := JsonLoader.load_dir(DATA_ROOT.path_join(directory))
		for error in result.errors:
			_errors.append(error)
		if not _collections.has(collection_name):
			_collections[collection_name] = {}
		var target: Dictionary = _collections[collection_name]
		for id in result.ids():
			if target.has(id):
				_errors.append(JsonLoader.LoadError.new(
					result.records[id].get(JsonLoader.SOURCE_KEY, "?"),
					id,
					"duplicate id, already defined in %s" % target[id].get(JsonLoader.SOURCE_KEY, "?"),
				))
				continue
			target[id] = result.records[id]

	if not _errors.is_empty():
		push_error("Content failed to load:\n%s" % error_report())
	return _errors.is_empty()


## Top-level directory names under `data/`, sorted.
func _collection_directories() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(DATA_ROOT)
	if dir == null:
		_errors.append(JsonLoader.LoadError.new(DATA_ROOT, "", "data directory not found"))
		return names
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


# --- Reading ---------------------------------------------------------------

func collection(name: String) -> Dictionary:
	return _collections.get(name, {})


func collection_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(_collections.keys())
	names.sort()
	return names


## Record ids in a collection, sorted.
func ids(collection_name: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(collection(collection_name).keys())
	out.sort()
	return out


func has_record(collection_name: String, id: String) -> bool:
	return collection(collection_name).has(id)


## One record, or an empty dictionary. Asking for a record that is not there is
## a content mistake, so it reports rather than failing silently.
func record(collection_name: String, id: String) -> Dictionary:
	var records: Dictionary = collection(collection_name)
	if not records.has(id):
		push_error("No record '%s' in collection '%s'." % [id, collection_name])
		return {}
	return records[id]


# --- Errors ----------------------------------------------------------------

func ok() -> bool:
	return _errors.is_empty()


func errors() -> Array[JsonLoader.LoadError]:
	return _errors.duplicate()


func error_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for error in _errors:
		lines.append("  %s" % error)
	return "\n".join(lines)
