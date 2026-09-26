extends TestCase

## 🔒 Every `READ_BY` entry names a function that exists (#444).
##
## `PatronVices.READ_BY` and `CommanderExperience.READ_BY` are how the content
## validator knows a knob is read rather than turned, and it trusts them
## outright. An entry naming a reader nobody built lets a vice or a bonus through
## validation to do nothing at all — the one failure both tables exist to
## prevent. Four patron entries did exactly that, pointing at *"Patron
## cancellation, #283"* and the like, and three vices shipped as names.
##
## **A function existing is not proof that it reads the knob**, and this does not
## pretend otherwise. It is proof there is a file to open and a function to read,
## which a sentence and an issue number never were.


func test_every_vice_knob_names_a_reader_that_exists() -> void:
	_every_reader_exists(PatronVices.READ_BY, "PatronVices")


func test_every_commander_knob_names_a_reader_that_exists() -> void:
	_every_reader_exists(CommanderExperience.READ_BY, "CommanderExperience")


## Each entry is `Class.function`: a registered class, and a function its script
## declares.
func _every_reader_exists(table: Dictionary, owner: String) -> void:
	assert_not_empty(table, "%s.READ_BY is empty" % owner)

	var paths := {}
	for entry in ProjectSettings.get_global_class_list():
		paths[String(entry["class"])] = String(entry["path"])

	for knob in table:
		var reader := String(table[knob])
		var parts := reader.split(".")
		if parts.size() != 2:
			fail("%s.READ_BY says '%s' is read by '%s', which is not Class.function"
				% [owner, knob, reader])
			continue

		var path := String(paths.get(parts[0], ""))
		if path.is_empty():
			fail("%s.READ_BY says '%s' is read by '%s', and there is no class %s"
				% [owner, knob, reader, parts[0]])
			continue

		var script := load(path) as Script
		var declared := PackedStringArray()
		if script != null:
			for method in script.get_script_method_list():
				declared.append(String(method["name"]))
		assert_true(declared.has(parts[1]),
			"%s.READ_BY says '%s' is read by '%s', and %s declares no %s"
				% [owner, knob, reader, parts[0], parts[1]])
