extends TestCase

## `WorldDiff` is computable and deterministic (#3).


func test_detects_changed_added_and_removed() -> void:
	var before := WorldState.new(1, {"revenue": 100, "war": 0.2, "gone": true})
	var after := WorldState.new(2, {"revenue": 140, "war": 0.2, "arrived": "yes"})
	var diff := WorldDiff.between(before, after)

	assert_true(diff.has_change("values.revenue"), "a changed value")
	assert_true(diff.has_change("values.gone"), "a removed value")
	assert_true(diff.has_change("values.arrived"), "an added value")
	assert_false(diff.has_change("values.war"), "an unchanged value must not appear")

	assert_eq(diff.changes["values.gone"]["to"], null, "removed values go to null")
	assert_eq(diff.changes["values.arrived"]["from"], null, "added values come from null")


func test_month_is_a_change_like_any_other() -> void:
	var diff := WorldDiff.between(WorldState.new(1, {}), WorldState.new(2, {}))
	assert_eq(diff.month_from, 1)
	assert_eq(diff.month_to, 2)
	assert_true(diff.has_change("month"))


func test_identical_states_produce_an_empty_diff() -> void:
	var before := WorldState.new(4, {"revenue": 100})
	var after := WorldState.new(4, {"revenue": 100})
	assert_true(WorldDiff.between(before, after).is_empty())


func test_is_independent_of_key_order() -> void:
	var forwards := WorldDiff.between(
		WorldState.new(1, {"a": 1, "b": 2}),
		WorldState.new(1, {"a": 9, "b": 2}),
	)
	var backwards := WorldDiff.between(
		WorldState.new(1, {"b": 2, "a": 1}),
		WorldState.new(1, {"b": 2, "a": 9}),
	)
	assert_eq(forwards.to_dict(), backwards.to_dict())


func test_changed_paths_are_sorted() -> void:
	var diff := WorldDiff.between(
		WorldState.new(1, {"zeta": 1, "alpha": 1, "mu": 1}),
		WorldState.new(1, {"zeta": 2, "alpha": 2, "mu": 2}),
	)
	var paths := diff.changed_paths()
	var sorted_paths := paths.duplicate()
	sorted_paths.sort()
	assert_eq(paths, sorted_paths)


func test_delta_reports_signed_change() -> void:
	# "Revenue fell by a third this month" is a different letter from "revenue is
	# low", which is why the correspondence layer reads the diff as well as state.
	var diff := WorldDiff.between(
		WorldState.new(1, {"revenue": 300}),
		WorldState.new(2, {"revenue": 200}),
	)
	assert_almost_eq(diff.delta("values.revenue"), -100.0)
	assert_almost_eq(diff.delta("values.nothing_here"), 0.0)


func test_delta_is_zero_for_non_numbers() -> void:
	var diff := WorldDiff.between(
		WorldState.new(1, {"supply": "strained"}),
		WorldState.new(2, {"supply": "easy"}),
	)
	assert_true(diff.has_change("values.supply"))
	assert_almost_eq(diff.delta("values.supply"), 0.0)


func test_int_and_float_are_not_the_same_value() -> void:
	# A number that changed type between a save and a load is a real difference.
	# Hiding it here would hide a save bug.
	var diff := WorldDiff.between(
		WorldState.new(1, {"revenue": 100}),
		WorldState.new(1, {"revenue": 100.0}),
	)
	assert_true(diff.has_change("values.revenue"))


func test_round_trips_without_loss() -> void:
	var diff := WorldDiff.between(
		WorldState.new(1, {"revenue": 100}),
		WorldState.new(2, {"revenue": 140}),
	)
	assert_eq(WorldDiff.from_dict(diff.to_dict()).to_dict(), diff.to_dict())
