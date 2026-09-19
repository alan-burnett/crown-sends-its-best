class_name JsonLoader
extends RefCounted

## Reads a directory tree of JSON files into memory, keyed by id.
##
## Adding content is adding a file (SPEC §9.7, §16.1). Nothing here knows what a
## letter is — the loader's whole job is to turn a tree of files into a
## dictionary of records and to be loud and specific when a file is wrong.
##
## **Failures name the file and the key.** The Author writes hundreds of these
## by hand, and "Invalid JSON" with no file name costs more to chase than the
## mistake cost to make.

class LoadError:
	extends RefCounted

	var file: String
	var key: String
	var message: String

	func _init(p_file: String, p_key: String, p_message: String) -> void:
		file = p_file
		key = p_key
		message = p_message

	func _to_string() -> String:
		if key.is_empty():
			return "%s: %s" % [file, message]
		return "%s [%s]: %s" % [file, key, message]


class LoadResult:
	extends RefCounted

	## id -> record. Every record carries `_source_file` naming where it came from.
	var records: Dictionary = {}
	var errors: Array[LoadError] = []

	func ok() -> bool:
		return errors.is_empty()

	func ids() -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray(records.keys())
		out.sort()
		return out

	func error_report() -> String:
		var lines: PackedStringArray = PackedStringArray()
		for error in errors:
			lines.append("  %s" % error)
		return "\n".join(lines)


const ID_KEY: String = "id"
const SOURCE_KEY: String = "_source_file"


## Load every `.json` file under `dir_path`, recursively.
##
## Each file holds either one record with an `id`, or an array of such records.
## Ids must be unique across the whole tree: a duplicate is an error rather than
## a silent overwrite, because the file that wins would otherwise depend on
## directory iteration order.
static func load_dir(dir_path: String) -> LoadResult:
	var result := LoadResult.new()
	if not DirAccess.dir_exists_absolute(dir_path):
		result.errors.append(LoadError.new(dir_path, "", "directory does not exist"))
		return result
	var files: PackedStringArray = find_json_files(dir_path)
	for file_path in files:
		_load_file(file_path, result)
	return result


## Every `.json` file under `dir_path`, sorted, so load order never depends on
## how the filesystem happens to enumerate a directory.
static func find_json_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(dir_path, found)
	found.sort()
	return found


static func _walk(dir_path: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var directories: PackedStringArray = PackedStringArray()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			directories.append(full_path)
		elif entry.get_extension().to_lower() == "json":
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	directories.sort()
	for child in directories:
		_walk(child, found)


static func _load_file(file_path: String, result: LoadResult) -> void:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		result.errors.append(LoadError.new(file_path, "", "could not be read (%s)" % error_string(FileAccess.get_open_error())))
		return

	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		result.errors.append(LoadError.new(file_path, "", "line %d: %s" % [parser.get_error_line(), parser.get_error_message()]))
		return

	var data: Variant = parser.data
	match typeof(data):
		TYPE_DICTIONARY:
			_add_record(data, file_path, result)
		TYPE_ARRAY:
			for index in data.size():
				var entry: Variant = data[index]
				if typeof(entry) != TYPE_DICTIONARY:
					result.errors.append(LoadError.new(file_path, "[%d]" % index, "expected an object, got %s" % type_string(typeof(entry))))
					continue
				_add_record(entry, file_path, result)
		_:
			result.errors.append(LoadError.new(file_path, "", "expected an object or an array of objects, got %s" % type_string(typeof(data))))


static func _add_record(record: Dictionary, file_path: String, result: LoadResult) -> void:
	if not record.has(ID_KEY):
		result.errors.append(LoadError.new(file_path, ID_KEY, "record has no id"))
		return
	var id: Variant = record[ID_KEY]
	if typeof(id) != TYPE_STRING or String(id).is_empty():
		result.errors.append(LoadError.new(file_path, ID_KEY, "id must be a non-empty string, got %s" % type_string(typeof(id))))
		return

	var id_text: String = String(id)
	if result.records.has(id_text):
		var existing: String = result.records[id_text].get(SOURCE_KEY, "?")
		result.errors.append(LoadError.new(file_path, id_text, "duplicate id, already defined in %s" % existing))
		return

	var stored: Dictionary = record.duplicate(true)
	stored[SOURCE_KEY] = file_path
	result.records[id_text] = stored
