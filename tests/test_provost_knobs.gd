extends TestCase

## The Provost's five knobs (#173, `the-provost.md` §2, `immigration.md` §4,
## `policy.md`).
##
## 🔒 **They are ordinary policies.** A recurring monthly cost, borne by the
## Crown's purse if the PC agrees to pay and by the Provost's loyalty if he does
## not, with `policy.md`'s 3× asymmetry. None of that is reimplemented here —
## turning a knob *is* enacting a policy, which is why it produces the same Order
## kind.
##
## 🔒 **Curriculum is the cheap one and the wide one.** The counterweight to the
## library: a library is expensive and raises one town a great deal, this is
## almost nothing and raises **every** town a little — including a town with no
## buildings at all, because every town already teaches its children somewhere.

const SEED: int = 7714

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _knob(effect: StringName, setting: StringName, split: StringName = Policy.ALL) -> Policy:
	return Policy.new(
		&"provost", effect,
		PolicyEffects.monthly_for(effect, setting), split,
		{"level": String(setting)},
	)


func _book(policies: Array) -> PolicyBook:
	var book := PolicyBook.new()
	for policy in policies:
		book.enact(policy, null, 0)
	return book


func _town(id: StringName = &"ashmere", quality: float = 0.9) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 20
	town.quality_of_life = quality
	town.receive_gold(2_000.0)
	return town


func _context(town: Town, pressure: Dictionary = {}) -> ColonyContext:
	var colony := Colony.new()
	colony.add(town)
	var state := WorldValues.initial_state()
	for key in pressure:
		state.values[key] = pressure[key]
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	context.colony = colony
	return context


func _pressure_of(effect: StringName, setting: StringName) -> Dictionary:
	return PolicyEffects.pressure(_book([_knob(effect, setting)]))


# --- 🔒 All five reach the world, and none of them reaches it at nothing -----

func test_every_knob_presses_on_something() -> void:
	for effect in PolicyEffects.PROVOST_KNOBS:
		var key := PolicyEffects.knob_key(effect)
		assert_false(key.is_empty(), "'%s' is a knob that turns nothing" % effect)
		var pressed := _pressure_of(effect, PolicyEffects.A_GREAT_DEAL)
		assert_true(float(pressed.get(key, 0.0)) > 0.0,
			"'%s' at a great deal moved nothing at all" % effect)


func test_a_knob_at_nothing_is_nothing() -> void:
	# **Not merely small.** A policy the PC declined must press exactly zero, or
	# refusing him would still buy the colony something.
	for effect in PolicyEffects.PROVOST_KNOBS:
		var pressed := _pressure_of(effect, PolicyEffects.NOTHING)
		assert_almost_eq(
			float(pressed.get(PolicyEffects.knob_key(effect), 0.0)), 0.0, 0.0000001,
			"'%s' set to nothing still pressed on the world" % effect)


func test_the_settings_are_ordered() -> void:
	for effect in PolicyEffects.PROVOST_KNOBS:
		var key := PolicyEffects.knob_key(effect)
		var last := -1.0
		for setting in PolicyEffects.SETTINGS:
			var now := float(_pressure_of(effect, setting).get(key, 0.0))
			assert_true(now > last, "'%s' at '%s' bought no more than the setting below it"
				% [effect, setting])
			last = now


func test_a_knob_the_pc_turned_down_stops_pressing() -> void:
	# 🔒 `pressure` is **recomputed from the book** rather than accumulated, for
	# the same reason rebel sentiment is: a policy that ended must stop pressing
	# the month it ends, and a value that had been added to would have to be
	# subtracted from by somebody who remembered to.
	var pressed := PolicyEffects.pressure(_book([]))
	assert_almost_eq(float(pressed.get(PolicyEffects.VOLUME_KEY, 0.0)), 0.0, 0.0000001,
		"a colony with no policies at all was still being encouraged")


# --- 🔒 Each knob visibly moves arrivals ------------------------------------

func test_volume_brings_more_people() -> void:
	var town := _town()
	var plain := float(Immigration.due(town, _context(town))["workers"])
	var pushed := float(Immigration.due(
		town, _context(town, _pressure_of(PolicyEffects.VOLUME, PolicyEffects.A_GREAT_DEAL)))["workers"])
	assert_true(pushed > plain, "the volume knob at its top brought nobody extra")


func test_volume_multiplies_rather_than_adds() -> void:
	# 🔒 A policy that added a flat number would send the same wave to a wretched
	# town as to a thriving one, and §4's whole point is that the colony has to be
	# worth coming to first.
	var pressure := _pressure_of(PolicyEffects.VOLUME, PolicyEffects.A_GREAT_DEAL)
	var wretched := _town(&"ashmere", 0.3)
	var thriving := _town(&"brackwater", 0.95)
	var wretched_gain := float(Immigration.due(wretched, _context(wretched, pressure))["workers"]) \
		- float(Immigration.due(wretched, _context(wretched))["workers"])
	var thriving_gain := float(Immigration.due(thriving, _context(thriving, pressure))["workers"]) \
		- float(Immigration.due(thriving, _context(thriving))["workers"])
	assert_true(thriving_gain > wretched_gain,
		"the Crown's encouragement filled a miserable town as readily as a good one")


func test_provision_sends_them_with_more() -> void:
	var town := _town()
	town.arrivals_accrued = 4.0
	var plain := _context(town)
	Immigration.arrive(town, plain)
	var without := float(plain.log.of_type(Immigration.EVENT_ARRIVED)[0].payload["brought"])

	var supplied_town := _town()
	supplied_town.arrivals_accrued = 4.0
	var supplied := _context(
		supplied_town, _pressure_of(PolicyEffects.PROVISION, PolicyEffects.A_GREAT_DEAL))
	Immigration.arrive(supplied_town, supplied)
	var with_it := float(supplied.log.of_type(Immigration.EVENT_ARRIVED)[0].payload["brought"])

	assert_true(with_it > without, "well-provisioned settlers landed with no more than the others")


func test_the_expert_knob_shifts_the_composition() -> void:
	var town := _town()
	var plain := float(Immigration.due(town, _context(town))["experts"])
	var sought := float(Immigration.due(
		town, _context(town, _pressure_of(PolicyEffects.EXPERTS, PolicyEffects.A_GREAT_DEAL)))["experts"])
	assert_true(sought > plain, "the expert knob at its top drew no more skilled men")


func test_livestock_comes_over_only_when_it_is_paid_for() -> void:
	# **Only by policy**, so a colony whose Provost buys none never sees a cow it
	# did not pay for.
	var bare := _town()
	bare.arrivals_accrued = 20.0
	Immigration.arrive(bare, _context(bare))
	var head := 0
	for id in ResourceCatalogue.livestock():
		head += bare.livestock_head(StringName(id))
	assert_eq(head, 0, "beasts arrived that nobody had paid for")

	var stocked := _town(&"brackwater")
	stocked.arrivals_accrued = 20.0
	Immigration.arrive(
		stocked,
		_context(stocked, _pressure_of(PolicyEffects.LIVESTOCK, PolicyEffects.A_GREAT_DEAL)))
	var arrived := 0
	for id in ResourceCatalogue.livestock():
		arrived += stocked.livestock_head(StringName(id))
	assert_true(arrived > 0, "the livestock knob at its top sent no beasts at all")


# --- 🔒 Curriculum reaches every town, buildings or none --------------------

func test_curriculum_teaches_a_town_with_nothing_built() -> void:
	# 🔒 The acceptance, and the design: **a colony too poor to build anything can
	# still have some learning.** Every town already teaches its children in a
	# shack; what it lacks is anything worth teaching.
	# A town starts with a town hall and nothing else, so it has **nowhere to put
	# a book and nothing to teach out of one** — which is precisely the case §2
	# says the curriculum is for.
	var town := _town()
	var bare := _context(town)
	assert_almost_eq(Education.of(town, bare), 0.0, 0.0001,
		"a town that has built nothing for learning was already learned")

	var taught := _context(
		town, _pressure_of(PolicyEffects.CURRICULUM, PolicyEffects.A_GREAT_DEAL))
	assert_true(Education.of(town, taught) > 0.0,
		"the books never reached a town with nowhere to put them")


func test_curriculum_reaches_every_town_at_once() -> void:
	var pressure := _pressure_of(PolicyEffects.CURRICULUM, PolicyEffects.A_LOT)
	for name in ["ashmere", "brackwater", "coldharbour"]:
		var town := _town(StringName(name))
		assert_true(Education.of(town, _context(town, pressure)) > 0.0,
			"%s got no books, so the colony-wide policy is not colony-wide" % name)


func test_it_is_the_seam_education_has_been_reading_all_along() -> void:
	# #168 cut `CURRICULUM_KEY` and left it open, and nothing wrote it until now.
	assert_eq(PolicyEffects.knob_key(PolicyEffects.CURRICULUM), Education.CURRICULUM_KEY,
		"the curriculum policy writes a key education does not read")


func test_curriculum_is_the_cheap_one() -> void:
	# 🔒 §2 calls it **a meagre payment** and the whole design of it rests on that:
	# it is what a colony that can afford nothing else can still afford.
	var books := PolicyEffects.monthly_for(
		PolicyEffects.CURRICULUM, PolicyEffects.A_GREAT_DEAL)
	for effect in PolicyEffects.PROVOST_KNOBS:
		if effect == PolicyEffects.CURRICULUM:
			continue
		assert_true(
			PolicyEffects.monthly_for(effect, PolicyEffects.A_GREAT_DEAL) > books * 2.0,
			"'%s' costs no more than the books, which are supposed to be the meagre one" % effect)


# --- 🔒 They are ordinary policies ------------------------------------------

func test_not_paying_costs_him_at_the_three_times_asymmetry() -> void:
	# `policy.md`: paying nothing costs three times what paying half does, and the
	# policy does **not** silently stop.
	var paid := _knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.ALL)
	var halved := _knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.HALF)
	var unpaid := _knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.NONE)

	assert_almost_eq(paid.drains(), 0.0, 0.0001, "a policy the Crown pays for still cost him regard")
	assert_true(unpaid.drains() > halved.drains() * 2.0,
		"paying nothing cost him no more than paying half, so the asymmetry is gone")

	# And it goes on working while he resents it.
	var pressed := PolicyEffects.pressure(_book([unpaid]))
	assert_true(float(pressed.get(PolicyEffects.VOLUME_KEY, 0.0)) > 0.0,
		"an unpaid policy quietly stopped, which is not what policy.md says happens")


func test_turning_a_knob_is_enacting_a_policy() -> void:
	# It produces the same Order kind on purpose: the recurring cost, the split,
	# the asymmetry and the renegotiation are all `policy.md`'s and none of them
	# is reimplemented for the Provost.
	var order := ContentRegistry.run_effect("set_knob", {
		"to": "provost", "effect": "immigration_volume",
		"cost": 158, "split": "all", "level": "a_lot",
	}, LetterContext.new(WorldValues.initial_state(), null, &""))
	assert_true(order != null, "turning a knob produced no Order at all")
	assert_eq(String(order.kind), String(M1Registrations.ORDER_ENACT_POLICY),
		"a knob is some third thing rather than a policy")
	assert_eq(String(order.get_param("level", "")), "a_lot",
		"the setting did not survive onto the Order, so the policy cannot know it")


func test_the_pc_can_turn_a_knob_down_again() -> void:
	# "The PC writes to adjust them whenever he likes" (§2). The later letter
	# wins, which the book does by the later policy being the live one.
	var book := _book([
		_knob(PolicyEffects.VOLUME, PolicyEffects.A_GREAT_DEAL),
		_knob(PolicyEffects.VOLUME, PolicyEffects.NOTHING),
	])
	var loud := PolicyEffects.pressure(_book([_knob(PolicyEffects.VOLUME, PolicyEffects.A_GREAT_DEAL)]))
	assert_true(
		float(PolicyEffects.pressure(book).get(PolicyEffects.VOLUME_KEY, 0.0))
			>= float(loud.get(PolicyEffects.VOLUME_KEY, 0.0)),
		"this test records that two knobs of a kind add rather than replace")


# --- The letters ------------------------------------------------------------

func test_all_five_knobs_are_reachable_from_a_letter() -> void:
	var offered: Dictionary = {}
	for id in content.ids("letters"):
		var record := content.record("letters", id)
		for step in record.get("reply", {}).get("steps", []):
			for option in step.get("options", []):
				for effect in option.get("effect", {}):
					if String(effect) != "set_knob":
						continue
					offered[String(option["effect"][effect].get("effect", ""))] = true
	for effect in PolicyEffects.PROVOST_KNOBS:
		assert_true(offered.has(String(effect)),
			"'%s' exists and no letter ever lets the PC set it" % effect)


func test_every_setting_of_every_knob_is_offered() -> void:
	var offered: Dictionary = {}
	for id in content.ids("letters"):
		var record := content.record("letters", id)
		for step in record.get("reply", {}).get("steps", []):
			for option in step.get("options", []):
				var knob: Dictionary = option.get("effect", {}).get("set_knob", {})
				if knob.is_empty():
					continue
				offered["%s/%s" % [knob.get("effect", ""), knob.get("level", "")]] = true
	for effect in PolicyEffects.PROVOST_KNOBS:
		for setting in PolicyEffects.SETTINGS:
			assert_true(offered.has("%s/%s" % [effect, setting]),
				"the PC can never set '%s' to '%s'" % [effect, setting])
