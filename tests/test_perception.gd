extends TestCase

## The perception resolver (#10), against `docs/mechanics/perception.md`.

const GOVERNOR_LADDER: PackedStringArray = ["starving", "hungry", "fed", "comfortable"]
const STEWARD_LADDER: PackedStringArray = ["in genuine want", "managing", "amply provisioned"]

## 180 food against a monthly consumption of 200, from the worked example.
const RATIO: float = 0.9


func before_each() -> void:
	MeasureRegistry.reset()
	MeasureRegistry.register_linear("food_security", 0.0, 3.0)


func after_each() -> void:
	MeasureRegistry.reset()


func test_the_worked_example_reproduces_exactly() -> void:
	# One sim number, 180 against 200. The Governor is aggrieved and wants relief,
	# so he makes his own town sound worse. The Steward minimises colony hardship
	# because it argues against his tax policy. Recognisably different, not
	# contradictory, and neither reports a false figure.
	assert_eq(Perception.word("food_security", RATIO, -0.18, GOVERNOR_LADDER), "starving")
	assert_eq(Perception.word("food_security", RATIO, 0.15, STEWARD_LADDER), "managing")


func test_the_truth_sits_between_them() -> void:
	# Both are one rung from the truth at most, which is the whole point.
	assert_eq(Perception.word("food_security", RATIO, 0.0, GOVERNOR_LADDER), "hungry")
	assert_eq(Perception.word("food_security", RATIO, 0.0, STEWARD_LADDER), "managing")


func test_a_lean_never_moves_more_than_one_rung() -> void:
	# Without the cap, two senders flatly contradict each other, which reads as
	# lying rather than framing and violates SPEC §9.1.
	var truth := Perception.truthful_rung("food_security", RATIO, GOVERNOR_LADDER.size())
	for lean in [-1.0, -0.9, -0.5, 0.5, 0.9, 1.0]:
		var rung := Perception.rung("food_security", RATIO, lean, GOVERNOR_LADDER.size())
		assert_true(absi(rung - truth) <= 1, "lean %f moved %d rungs" % [lean, absi(rung - truth)])


func test_the_steward_cannot_reach_the_top_rung_at_his_own_lean() -> void:
	# "Amply provisioned" is out of his reach at this ratio, because +0.15 on a
	# three-rung ladder does not span a rung — not because the cap forbids it.
	# The cap would allow one rung up; his lean simply is not strong enough.
	assert_ne(Perception.word("food_security", RATIO, 0.15, STEWARD_LADDER), "amply provisioned")
	assert_eq(Perception.word("food_security", RATIO, 1.0, STEWARD_LADDER), "amply provisioned",
		"a total distortion still gets exactly one rung, and no more")


func test_the_top_rung_is_reachable_well_below_one() -> void:
	# Rungs are evenly spaced points, not bands, and the index is the **nearest**
	# rung rather than the floor, so the top is reachable before the value is 1.0.
	MeasureRegistry.register_linear("plain", 0.0, 1.0)
	assert_eq(Perception.word("plain", 0.84, 0.0, GOVERNOR_LADDER), "comfortable")


func test_the_lowest_rung_is_not_unduly_favoured() -> void:
	MeasureRegistry.register_linear("plain", 0.0, 1.0)
	assert_eq(Perception.word("plain", 0.2, 0.0, GOVERNOR_LADDER), "hungry")


func test_a_two_rung_ladder_works() -> void:
	# Two rungs is legitimate for a yes/no flavour judgment.
	MeasureRegistry.register_linear("plain", 0.0, 1.0)
	var ladder := PackedStringArray(["poor", "good"])
	assert_eq(Perception.word("plain", 0.1, 0.0, ladder), "poor")
	assert_eq(Perception.word("plain", 0.9, 0.0, ladder), "good")


func test_a_long_ladder_makes_a_lean_more_visible() -> void:
	# Ladder length controls how visible a lean is. On a short ladder one rung
	# spans half the range and a small lean shows nothing; give it more rungs and
	# the same lean becomes legible.
	MeasureRegistry.register_linear("plain", 0.0, 1.0)
	var short_ladder := PackedStringArray(["low", "middling", "high"])
	var long_ladder := PackedStringArray(["a", "b", "c", "d", "e", "f"])

	# On three rungs a rung spans half the range, so +0.12 buys nothing. On six
	# it spans a fifth, and the same lean moves the word.
	assert_eq(
		Perception.rung("plain", 0.44, 0.12, short_ladder.size()),
		Perception.rung("plain", 0.44, 0.0, short_ladder.size()),
		"a tenth of lean shows nothing on three rungs",
	)
	assert_ne(
		Perception.rung("plain", 0.44, 0.12, long_ladder.size()),
		Perception.rung("plain", 0.44, 0.0, long_ladder.size()),
		"the same lean is visible on six rungs",
	)


func test_ladders_are_local_to_the_letter_that_uses_them() -> void:
	# The same measure carries entirely different words in different letters.
	var first := Perception.word("food_security", RATIO, 0.0, GOVERNOR_LADDER)
	var second := Perception.word("food_security", RATIO, 0.0, STEWARD_LADDER)
	assert_ne(first, second)


func test_an_honest_reporter_says_the_truth() -> void:
	var truth := Perception.truthful_rung("food_security", RATIO, GOVERNOR_LADDER.size())
	assert_eq(Perception.rung("food_security", RATIO, 0.0, GOVERNOR_LADDER.size()), truth)


func test_the_registry_is_extensible_without_touching_the_resolver() -> void:
	MeasureRegistry.register_linear("crown_war_intensity", 0.0, 100.0)
	assert_true(MeasureRegistry.has_measure("crown_war_intensity"))
	assert_eq(Perception.word("crown_war_intensity", 100.0, 0.0, PackedStringArray(["quiet", "raging"])), "raging")


func test_values_outside_the_range_are_clamped() -> void:
	assert_eq(Perception.word("food_security", -5.0, 0.0, GOVERNOR_LADDER), "starving")
	assert_eq(Perception.word("food_security", 99.0, 0.0, GOVERNOR_LADDER), "comfortable")


func test_a_ladder_needs_two_rungs() -> void:
	assert_eq(Perception.rung("food_security", RATIO, 0.0, 1), -1)


func test_resolution_is_deterministic() -> void:
	var first := Perception.word("food_security", RATIO, -0.18, GOVERNOR_LADDER)
	var second := Perception.word("food_security", RATIO, -0.18, GOVERNOR_LADDER)
	assert_eq(first, second)
