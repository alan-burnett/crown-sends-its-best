extends SceneTree

## Run one test file, or a few.
##
##     ./tools/godot.sh --script res://tools/run_test.gd -- raising
##     ./tools/godot.sh --script res://tools/run_test.gd -- raising coordination
##
## The name is the file without `test_` or `.gd`; `test_raising` and
## `tests/test_raising.gd` are both accepted, so a path pasted out of a failure
## works unchanged.
##
## **Why this exists.** The full suite is 2300 tests and takes about nine
## minutes, which is the right price to pay before a commit and much too high to
## pay inside a mutation test — where the whole method is to break a line, run,
## confirm a specific test fails, and restore. A dev who cannot afford to check
## stops checking, and `CLAUDE.md`'s standard of proving a test bites quietly
## becomes a standard of hoping it does.
##
## 🔒 **It is not a substitute for the full suite.** Running one file in
## isolation is exactly the condition under which a test that depends on another
## file's leaked static state still passes — which is the bug
## `TestCase.reset_world()` exists to prevent. Run the whole suite before
## committing.

func _init() -> void:
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		print("usage: run_test.gd -- <name> [name...]")
		quit(2)
		return

	var passed: int = 0
	var failed: int = 0
	var missing := PackedStringArray()
	var failures := PackedStringArray()

	for name in names:
		var path := _path_for(String(name))
		if not ResourceLoader.exists(path):
			missing.append(path)
			continue
		var script: Script = load(path)
		var case: TestCase = script.new()
		var result: Dictionary = case.run_all()
		passed += int(result["passed"])
		failed += int(result["failed"])
		for failure in result["failures"]:
			failures.append(String(failure))
		var verdict := "PASS" if int(result["failed"]) == 0 else "FAIL"
		print("%s  %s  %d passed, %d failed"
			% [verdict, path.get_file(), result["passed"], result["failed"]])

	for path in missing:
		print("no such test: %s" % path)
	for failure in failures:
		print("  %s" % failure)

	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or not missing.is_empty() else 0)


## Accept `raising`, `test_raising`, `test_raising.gd` or the whole res:// path.
static func _path_for(name: String) -> String:
	if name.begins_with("res://"):
		return name
	var file := name.get_file().trim_suffix(".gd")
	if not file.begins_with("test_"):
		file = "test_%s" % file
	return "res://tests/%s.gd" % file
