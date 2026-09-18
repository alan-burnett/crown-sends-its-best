extends SceneTree

## The test runner.
##
##     godot --headless --script res://tools/run_tests.gd
##
## Finds every `tests/test_*.gd`, runs each `test_` method, and exits non-zero
## if any fail so CI (#26) can gate on it. A failure names the test and says
## what it expected, because a failure that needs the log opened is a failure
## that gets ignored.

const TESTS_ROOT: String = "res://tests"


func _init() -> void:
	var files := _discover(TESTS_ROOT)
	if files.is_empty():
		print("No tests found under %s" % TESTS_ROOT)
		quit(1)
		return

	var total_passed: int = 0
	var total_failed: int = 0
	var total_assertions: int = 0
	var failures: PackedStringArray = PackedStringArray()
	var started := Time.get_ticks_msec()

	for path in files:
		var script: Script = load(path)
		if script == null:
			failures.append("%s: could not be loaded" % path)
			total_failed += 1
			continue
		var test_case: TestCase = script.new()
		var result: Dictionary = test_case.run_all()
		total_passed += result["passed"]
		total_failed += result["failed"]
		total_assertions += result["assertions"]
		for failure in result["failures"]:
			failures.append(failure)
		print("%s  %s  %d passed, %d failed" % [
			"PASS" if result["failed"] == 0 else "FAIL",
			result["name"],
			result["passed"],
			result["failed"],
		])

	var elapsed := Time.get_ticks_msec() - started

	if not failures.is_empty():
		print("")
		print("Failures:")
		for failure in failures:
			print("  %s" % failure)

	print("")
	print("%d passed, %d failed, %d assertions, %dms" % [total_passed, total_failed, total_assertions, elapsed])
	quit(1 if total_failed > 0 else 0)


## `tests/test_*.gd`, sorted, so the run order is the same everywhere.
func _discover(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(dir_path, found)
	found.sort()
	return found


func _walk(dir_path: String, found: PackedStringArray) -> void:
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
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	directories.sort()
	for child in directories:
		_walk(child, found)
