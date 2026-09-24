extends TestCase

## Urging per author (#405, `docs/mechanics/governor-objectives.md` §4).
##
## 🔒 **Several may stand at once, and none erases another.** A town or a
## company holds one urging per author: a new one from the same author replaces
## that author's last, a different author's stands beside it, and each decays on
## its own. While only the PC urges, every decision is what it was.

const PROVOST: StringName = &"provost"


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()


func after_each() -> void:
	reset_world()


func _town() -> Town:
	return Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))


func _score(urgings: Array, toward: StringName, month: int) -> float:
	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	context.month = month
	context.data = {"urgings": urgings}
	return IntentConsiderations.CrownUrging.new().score(null, Candidate.new(toward, {}), context)


# --- 🔒 Keyed by author ------------------------------------------------------------

func test_a_new_urging_replaces_its_authors_last_and_nobody_elses() -> void:
	var town := _town()
	town.urge(Urging.from_pc(GovernorIntent.ECONOMY, 1, Tone.DUTIFUL))
	town.urge(Urging.make(PROVOST, GovernorIntent.POPULATION, 2))
	town.urge(Urging.from_pc(GovernorIntent.DEFENCE, 3, Tone.DESPERATE))

	assert_eq(town.urgings.size(), 2, "an author's second urging stood beside his first")
	assert_eq(town.urging_by().target, GovernorIntent.DEFENCE, "the PC's new letter did not replace his last")
	assert_eq(town.urging_by(PROVOST).target, GovernorIntent.POPULATION,
		"the PC's letter erased the Provost's")
	assert_eq(town.urging_by(PROVOST).month, 2)


func test_a_company_holds_them_the_same_way() -> void:
	var company := Company.new()
	company.urge(CommanderConsiderations.ATTACK, Tone.DUTIFUL, 1)
	company.stand(Urging.make(PROVOST, CommanderConsiderations.HOLD, 2))
	company.urge(CommanderConsiderations.WITHDRAW, Tone.DUTIFUL, 3)
	assert_eq(company.urgings.size(), 2)
	assert_eq(company.urging_by().target, CommanderConsiderations.WITHDRAW)
	assert_eq(company.urging_by(PROVOST).target, CommanderConsiderations.HOLD)


func test_the_order_they_arrived_in_does_not_matter() -> void:
	# Deterministic by construction: read in author order, not arrival order.
	var one := _town()
	one.urge(Urging.make(PROVOST, GovernorIntent.POPULATION, 2))
	one.urge(Urging.from_pc(GovernorIntent.ECONOMY, 1))
	var two := _town()
	two.urge(Urging.from_pc(GovernorIntent.ECONOMY, 1))
	two.urge(Urging.make(PROVOST, GovernorIntent.POPULATION, 2))
	assert_eq(Urging.list_to_dicts(one.urgings), Urging.list_to_dicts(two.urgings))


# --- 🔒 Each decays on its own, and several count ------------------------------------

func test_each_urging_decays_on_its_own() -> void:
	var early := Urging.from_pc(GovernorIntent.ECONOMY, 0)
	var late := Urging.make(PROVOST, GovernorIntent.ECONOMY, 10)
	assert_true(late.pull(12, IntentConsiderations.URGING_HALF_LIFE)
		> early.pull(12, IntentConsiderations.URGING_HALF_LIFE),
		"an urging from ten months later had faded as far as the first")


func test_two_urgings_toward_one_intent_both_count() -> void:
	# Old enough that neither is at the ceiling, so the sum is visible.
	var alone := _score([Urging.from_pc(GovernorIntent.ECONOMY, 0)], GovernorIntent.ECONOMY, 30)
	assert_true(alone > 0.0 and alone < 0.5, "the fixture is at the ceiling: %f" % alone)
	var together := _score([
		Urging.from_pc(GovernorIntent.ECONOMY, 0),
		Urging.make(PROVOST, GovernorIntent.ECONOMY, 0),
	], GovernorIntent.ECONOMY, 30)
	assert_true(together > alone, "a second author's urging toward the same intent counted for nothing")


func test_another_authors_urging_pulls_without_erasing_the_pcs() -> void:
	# The acceptance line: a non-PC urging moves a governor, and the PC's still
	# pulls toward what he asked.
	var urgings := [
		Urging.from_pc(GovernorIntent.ECONOMY, 5),
		Urging.make(PROVOST, GovernorIntent.POPULATION, 5),
	]
	assert_true(_score(urgings, GovernorIntent.POPULATION, 6) > 0.0,
		"the Provost's urging pulled on nothing")
	assert_true(_score(urgings, GovernorIntent.ECONOMY, 6) > 0.0,
		"the Provost's urging erased the PC's")
	assert_almost_eq(_score(urgings, GovernorIntent.DEFENCE, 6), 0.0, 0.000001,
		"an intent nobody urged was pulled toward")


# --- 🔒 While only the PC urges, nothing changed ---------------------------------------

func test_the_pcs_urging_scores_exactly_as_the_single_slot_did() -> void:
	# The single slot's formula, written out: one factor on the half-life from
	# the tone, clamped at one after the perk's weight.
	for tone in [Tone.DUTIFUL, Tone.DESPERATE, Tone.PLEASED, &""]:
		for age in [0, 3, 12, 40]:
			var then := IntentConsiderations.decayed(float(age),
				IntentConsiderations.URGING_HALF_LIFE * IntentConsiderations.intensity_of(tone))
			var expected := minf(1.0, then * IntentConsiderations.urging_weight())
			assert_almost_eq(
				_score([Urging.from_pc(GovernorIntent.ECONOMY, 0, tone)], GovernorIntent.ECONOMY, age),
				expected, 0.000001, "tone %s at %d months scored differently" % [tone, age])


# --- 🔒 The save ---------------------------------------------------------------------

func test_the_list_survives_a_save() -> void:
	var town := _town()
	town.urge(Urging.from_pc(GovernorIntent.DEFENCE, 4, Tone.DESPERATE))
	town.urge(Urging.make(PROVOST, GovernorIntent.POPULATION, 7, 1.5))
	var restored := Town.from_dict(town.to_dict())
	assert_eq(Urging.list_to_dicts(restored.urgings), Urging.list_to_dicts(town.urgings))


func test_an_old_single_slot_save_is_not_migrated() -> void:
	# `CLAUDE.md`: an older save is refused, not migrated. The version moved, and
	# a town written with the single slot reads back with no urging at all rather
	# than a guessed one.
	assert_true(RunState.SAVE_VERSION >= 3)
	var old := _town().to_dict()
	old.erase("urgings")
	old["urged_intent"] = String(GovernorIntent.DEFENCE)
	old["urged_month"] = 4
	assert_empty(Town.from_dict(old).urgings)


# --- 🔒 Nothing here reaches an objective ------------------------------------------

func test_an_urging_names_an_intent_or_an_order_and_never_an_objective() -> void:
	# SPEC §8.5. The plumbing is not the back door #401 worried about.
	var code := FileAccess.get_file_as_string("res://sim/intent/urging.gd")
	for token in ["objective =", ".objective", "set_objective"]:
		assert_false(code.contains(token), "the urging record reaches an objective: %s" % token)
