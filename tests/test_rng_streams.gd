extends TestCase

## Determinism (SPEC §16.1, `CLAUDE.md` Determinism).
##
## This is one of the places `CLAUDE.md` marks as worth testing: the values are
## stable, and breakage is silent. A determinism bug does not crash — it quietly
## makes a seed stop reproducing, and is found much later by someone trying to
## reproduce a bug report.

const SEED: int = 481_516


func test_stable_hash_is_fixed() -> void:
	# Pinned so that a change to the hash is a deliberate act. Every stream seed
	# in every run descends from this, so changing it invalidates every save.
	assert_eq(StableHash.of_string(""), 0x811C9DC5, "empty string is the FNV offset basis")
	assert_eq(StableHash.of_string("marshal"), StableHash.of_string("marshal"), "same input, same hash")
	assert_ne(StableHash.of_string("marshal"), StableHash.of_string("steward"))
	# Stays inside 32 bits, so no overflow and no reliance on wrapping.
	assert_true(StableHash.of_string("chancellor") >= 0)
	assert_true(StableHash.of_string("chancellor") <= 0xFFFFFFFF)


func test_same_seed_reproduces() -> void:
	var first := RngStreams.new(SEED)
	var second := RngStreams.new(SEED)
	for i in 20:
		assert_eq(first.stream("sim").randi(), second.stream("sim").randi())


func test_different_seeds_diverge() -> void:
	var first := RngStreams.new(SEED)
	var second := RngStreams.new(SEED + 1)
	assert_ne(first.stream("sim").randi(), second.stream("sim").randi())


func test_streams_are_independent() -> void:
	# The acceptance criterion from #2: adding a draw to one system must not
	# change another system's sequence. This is the throwaway draw.
	var baseline := RngStreams.new(SEED)
	var expected: Array = []
	for i in 10:
		expected.append(baseline.stream("sim").randi())

	var perturbed := RngStreams.new(SEED)
	perturbed.stream("letters").randi()
	perturbed.stream("mapgen").randf()
	perturbed.stream("letters").randi()
	var actual: Array = []
	for i in 10:
		actual.append(perturbed.stream("sim").randi())

	assert_eq(actual, expected, "a draw in letters/mapgen moved the sim stream")


func test_contact_streams_derive_independently() -> void:
	# The same seed must yield the same Marshal whatever happened elsewhere in
	# the run, including contacts created at different times in different orders.
	var early := RngStreams.new(SEED)
	var marshal_first: Array = []
	for i in 5:
		marshal_first.append(early.contact_stream("marshal").randi())

	var late := RngStreams.new(SEED)
	late.contact_stream("steward").randi()
	late.contact_stream("chancellor").randi()
	late.stream("sim").randi()
	var marshal_second: Array = []
	for i in 5:
		marshal_second.append(late.contact_stream("marshal").randi())

	assert_eq(marshal_second, marshal_first, "the Marshal changed because of other contacts")


func test_contacts_differ_from_each_other() -> void:
	var streams := RngStreams.new(SEED)
	assert_ne(streams.contact_stream("marshal").randi(), streams.contact_stream("steward").randi())


func test_round_trip_resumes_mid_sequence() -> void:
	# Suspend and resume (SPEC §16.2) has to continue the sequence, not restart
	# it. Restoring only the seed would replay draws the run already spent.
	var original := RngStreams.new(SEED)
	for i in 7:
		original.stream("sim").randi()
	original.contact_stream("marshal").randi()

	var expected_sim: Array = []
	var expected_marshal: Array = []
	var reference := RngStreams.from_dict(original.to_dict())
	for i in 5:
		expected_sim.append(original.stream("sim").randi())
		expected_marshal.append(original.contact_stream("marshal").randi())

	var actual_sim: Array = []
	var actual_marshal: Array = []
	for i in 5:
		actual_sim.append(reference.stream("sim").randi())
		actual_marshal.append(reference.contact_stream("marshal").randi())

	assert_eq(actual_sim, expected_sim, "sim stream did not resume where it left off")
	assert_eq(actual_marshal, expected_marshal, "contact stream did not resume where it left off")


func test_round_trip_preserves_run_seed_and_keys() -> void:
	var original := RngStreams.new(SEED)
	original.stream("letters").randi()
	original.contact_stream("marshal").randi()

	var restored := RngStreams.from_dict(original.to_dict())
	assert_eq(restored.run_seed(), SEED)
	assert_eq(restored.active_keys(), original.active_keys())


func test_active_keys_are_sorted() -> void:
	var streams := RngStreams.new(SEED)
	streams.contact_stream("steward")
	streams.stream("sim")
	streams.contact_stream("marshal")
	var keys := streams.active_keys()
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	assert_eq(keys, sorted_keys, "active_keys() must not depend on insertion order")
