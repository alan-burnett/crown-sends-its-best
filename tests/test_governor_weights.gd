extends TestCase

## A governor's personality is one weight per consideration the kernel scores
## (#462, `governor-agendas.md` §13).
##
## 🔒 **From the kernel's own list, never a copy**: every consideration the
## intent kernel registers, and none it has retired.

const SEED: int = 462


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()


func after_each() -> void:
	reset_world()


func _governor(town_id: StringName) -> Contact:
	return Governor.generate(Town.new(town_id, String(town_id)), RngStreams.new(SEED))


func test_a_governor_draws_every_consideration_the_intent_kernel_scores() -> void:
	var drawn := Governor.weighted()
	for id in IntentConsiderations.ALL:
		assert_true(drawn.has(id), "governors draw no weight for '%s'" % id)
	var governor := _governor(&"ashmere")
	for id in ["baseline", "wealth", "safety"]:
		assert_true(governor.weights.has(StringName(id)), "a governor has no weight for %s" % id)


func test_no_governor_carries_a_weight_nothing_scores() -> void:
	var registered: Dictionary = {}
	for kind in Deliberation._considerations:
		for consideration in Deliberation._considerations[kind]:
			registered[String(consideration.id)] = true
	for id in Governor.weighted():
		assert_true(registered.has(id), "governors draw a weight for '%s', which no decision kind scores" % id)


func test_two_governors_differ_on_baseline_wealth_and_safety() -> void:
	var one := _governor(&"ashmere")
	var two := _governor(&"brackwater")
	var differs := false
	for id in ["baseline", "wealth", "safety"]:
		differs = differs or not is_equal_approx(float(one.weights[StringName(id)]), float(two.weights[StringName(id)]))
	assert_true(differs, "two governors weigh baseline, wealth and safety identically")
