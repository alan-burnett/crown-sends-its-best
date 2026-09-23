class_name TestCase
extends RefCounted

## Base class for tests. No framework, no addon — `tools/run_tests.gd` finds
## every `tests/test_*.gd`, instantiates it, and runs each `test_` method.
##
## `CLAUDE.md` keeps the test surface deliberately narrow: determinism, save
## round-trip, content validation, and the invariants the spec locks. A
## dependency CI has to install and pin would cost more than it returns at that
## size.

var _failures: PackedStringArray = PackedStringArray()
var _assertions: int = 0
var _current: String = ""


## Override for setup shared by every test method in the class.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


## Put every class that holds tuning in static state back to its declared
## defaults.
##
## ## 🔒 One list, in one place
##
## This used to be hand-rolled in each test file, and **each file reset only the
## classes its author happened to know about**. The lists drifted: `Deliberation`
## appeared in 111 files, `Threshold` in twelve, `Raising` in one, and `Spending`
## and `DemandSchedule` in none at all — though `M1Registrations.load_resources`
## loads both.
##
## That is not a tidiness problem. A class left un-reset carries whatever the
## previous test loaded into the next one, so a test can pass on state it never
## set up and fail only when the suite is reordered. **It is the exact shape of a
## test that looks like it bites and does not**, and it gets worse with every
## knob moved out of a `const` and into a `static var`.
##
## **Adding a resettable class means adding one line here**, and every test gets
## it. A class with a `load_from` and no `reset` is the bug this cannot catch, so
## `ColonyNeeds` gained one.
func reset_world() -> void:
	# Content definitions, in load order: the catalogue first, because terrain and
	# improvements name resources.
	ResourceCatalogue.reset()
	CrownPrices.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ColonyNeeds.reset()
	QualityOfLife.reset()
	RebelSentiment.reset()
	Immigration.reset()
	Spending.reset()
	DemandSchedule.reset()

	# The registries letters and deliberation resolve against.
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	BeatKinds.reset()

	# The post: who writes, how readily, and in what words.
	Threshold.reset()
	Consultation.reset()
	HarshClause.reset()
	Salutation.reset()
	Crossing.reset()
	Silence.reset()
	Pressure.reset()
	IndependenceClause.reset()
	NameBags.reset()
	ContactRoster.reset()
	Perception.reset()
	Contact.reset()
	LoyaltyDrift.reset()
	Relationship.reset()
	OpticsRegister.reset()
	IntentConsiderations.reset_urging()

	# Contacts that carry tuning of their own.
	Patron.reset()
	PatronVices.reset()

	# Force.
	Company.reset()
	Raising.reset()
	Force.reset()
	Battle.reset()
	CommanderExperience.reset()
	CommanderFate.reset()
	Muster.reset()

	# The neighbours.
	Tribes.reset()
	Village.reset()
	TradeAgreement.reset()

	# Player-level state that outlives a run. In memory only — neither touches
	# disk here, and both reload on next access.
	Records.reset()
	Settings.reset()


## Run every `test_` method. Returns {passed, failed, assertions, failures}.
func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var all_failures: PackedStringArray = PackedStringArray()

	for method_name in _test_methods():
		_current = method_name
		_failures = PackedStringArray()
		var before_count := _assertions
		before_each()
		call(method_name)
		after_each()
		# A GDScript runtime error aborts the method without raising anything a
		# runner can catch, so a test that blew up looks exactly like a test that
		# passed. A method that recorded no assertion did not run, and saying so
		# is the only way this runner can go red on an error rather than green.
		if _assertions == before_count:
			fail("no assertions ran — the method aborted, or it asserts nothing")
		if _failures.is_empty():
			passed += 1
		else:
			failed += 1
			for failure in _failures:
				all_failures.append("%s.%s: %s" % [_class_label(), method_name, failure])

	return {
		"name": _class_label(),
		"passed": passed,
		"failed": failed,
		"assertions": _assertions,
		"failures": all_failures,
	}


## Test methods, sorted, so the run order never depends on reflection order.
func _test_methods() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			names.append(method_name)
	names.sort()
	return names


func _class_label() -> String:
	var script: Script = get_script()
	return script.resource_path.get_file().get_basename() if script != null else "TestCase"


# --- Assertions ------------------------------------------------------------

func fail(message: String) -> void:
	# Counts as an assertion, so a deliberate failure does not also trip the
	# "no assertions ran" guard and get reported twice.
	_assertions += 1
	_failures.append(message)


func assert_true(value: bool, message: String = "") -> void:
	_assertions += 1
	if not value:
		fail("expected true. %s" % message)


func assert_false(value: bool, message: String = "") -> void:
	_assertions += 1
	if value:
		fail("expected false. %s" % message)


## Compared through the canonical encoding, so `1` and `1.0` are not equal and a
## dictionary's insertion order does not matter.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions += 1
	var actual_text := Canonical.encode(actual)
	var expected_text := Canonical.encode(expected)
	if actual_text != expected_text:
		fail("expected %s, got %s. %s" % [expected_text, actual_text, message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assertions += 1
	if Canonical.encode(actual) == Canonical.encode(unexpected):
		fail("expected something other than %s. %s" % [Canonical.encode(unexpected), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	_assertions += 1
	if absf(actual - expected) > tolerance:
		fail("expected %f +/- %f, got %f. %s" % [expected, tolerance, actual, message])


## Object identity. `assert_eq` compares through the canonical encoding, which
## is for plain data — an Object has no meaningful encoding there.
func assert_same(actual: Object, expected: Object, message: String = "") -> void:
	_assertions += 1
	if actual != expected:
		fail("expected the same object. %s" % message)


func assert_has(container: Variant, key: Variant, message: String = "") -> void:
	_assertions += 1
	if not container.has(key):
		fail("expected to contain %s. %s" % [key, message])


func assert_empty(container: Variant, message: String = "") -> void:
	_assertions += 1
	if not container.is_empty():
		fail("expected empty, got %s. %s" % [Canonical.encode(container), message])


func assert_not_empty(container: Variant, message: String = "") -> void:
	_assertions += 1
	if container.is_empty():
		fail("expected not empty. %s" % message)
