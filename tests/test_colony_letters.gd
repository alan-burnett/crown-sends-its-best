extends TestCase

## Colony letters and real perception measures (#54).
##
## M2's question is whether a real economy makes the letters matter. The colony
## can be perfectly simulated and the run will still feel flat if the governor's
## letters do not make the player care what happens to the town.

const SEED: int = 1649

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


func _governor_letters() -> Array:
	var out: Array = []
	for id in content.ids("letters"):
		if String(id).begins_with("governor."):
			out.append(Letter.from_record(content.record("letters", String(id))))
	return out


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


# --- 🔒 The PC argues for a goal and nothing else ---------------------------

func test_no_governor_reply_names_a_project_a_tile_or_a_month() -> void:
	# SPEC §8.5: *"An order reaches the governor's intent, never the town's
	# objective. The PC can argue for a goal; he cannot name the project, the
	# tile, or the month."*
	#
	# `tools/lint.gd` keeps the code side of this. **This is the content side**:
	# there must be no reply option anywhere that carries a project.
	var allowed: PackedStringArray = ["urge_intent", "refuse"]
	var letters := _governor_letters()
	assert_not_empty(letters, "there are no governor letters to check")

	var options_seen := 0
	for letter in letters:
		if not letter.has_reply():
			continue
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				options_seen += 1
				var effect: Dictionary = option.get("effect", {})
				for id in effect:
					assert_true(allowed.has(String(id)),
						"%s offers the effect '%s', which is not an intent-level pronouncement"
							% [letter.id, id])
	assert_true(options_seen > 0, "no reply options were examined")


func test_the_only_thing_a_letter_can_urge_is_a_real_intent() -> void:
	for letter in _governor_letters():
		if not letter.has_reply():
			continue
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				var effect: Dictionary = option.get("effect", {})
				if not effect.has("urge_intent"):
					continue
				var urged := StringName(effect["urge_intent"].get("intent", ""))
				assert_true(GovernorIntent.is_intent(urged),
					"%s urges '%s', which is not an intent" % [letter.id, urged])


func test_every_intent_is_something_the_pc_can_actually_say() -> void:
	# The purposes in `docs/mechanics/governor-objectives.md` §6. If one had no
	# letter option, that intent would exist in the sim and be unreachable by
	# correspondence, which is the one way the PC is allowed to act.
	#
	# **Sedition is the exception, and it is the interesting one** (#128). The PC
	# cannot argue for a governor to prepare his town for rebellion — there is no
	# letter in which the Crown asks a man to turn against it, and there should
	# not be. It is the one intent a governor reaches entirely on his own, which
	# is what makes it a consequence of how he has been treated rather than
	# another thing the PC decides.
	#
	# 🔒 **Driving off the natives is not an exception** (#204, Author). I had put
	# it in this list on the reasoning that the ticket says the PC may argue
	# against it and does not say he may ask for it. That was the wrong read of
	# what the game is about: *Natives you say? Why simply exterminate them and
	# farm me my sugar* is exactly what a man who has never seen one says from
	# three thousand miles away, and the governor who has to carry it out is the
	# one who decides what it actually means. Taking the instrument away took the
	# satire with it.
	var reachable: Dictionary = {}
	for letter in _governor_letters():
		if not letter.has_reply():
			continue
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				var effect: Dictionary = option.get("effect", {})
				if effect.has("urge_intent"):
					reachable[String(effect["urge_intent"].get("intent", ""))] = true

	for intent in GovernorIntent.IN_ORDER:
		if GovernorIntent.is_his_alone(intent):
			assert_false(reachable.has(String(intent)),
				"a letter lets the PC ask a governor for '%s', which is his alone" % intent)
			continue
		assert_has(reachable, String(intent),
			"no letter lets the PC argue for '%s'" % intent)


# --- Real measures ----------------------------------------------------------

func test_a_governor_reads_his_own_town_and_an_officer_reads_the_colony() -> void:
	# The Steward saying the colony is amply provisioned and the Governor saying
	# his people are in want are not a contradiction. They are two true
	# statements about different things, and the player has to hold both.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.quality_of_life = 0.11
	run.world.values[WorldValues.QUALITY_OF_LIFE] = 0.93

	var governor := ColonyMeasures.for_contact(run, run.contact(town.governor_id))
	var steward := ColonyMeasures.for_contact(run, run.contact(&"steward"))

	assert_almost_eq(float(governor[WorldValues.QUALITY_OF_LIFE]), 0.11, 0.001,
		"the governor reported the colony's figure rather than his town's")
	assert_almost_eq(float(steward[WorldValues.QUALITY_OF_LIFE]), 0.93, 0.001,
		"an officer of the Crown was given a town's figure")


func test_a_governor_has_measures_an_officer_does_not() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var governor := ColonyMeasures.for_contact(run, run.contact(town.governor_id))

	for id in [ColonyMeasures.OBJECTIVE_PROGRESS, ColonyMeasures.STOCKPILE_HEALTH,
			ColonyMeasures.TRADE_VOLUME]:
		assert_has(governor, id, "a governor cannot judge '%s'" % id)


func test_every_measure_a_letter_judges_is_registered() -> void:
	# A perception slot against an unregistered measure has no normaliser, so it
	# cannot pick a rung and the letter silently reads wrong.
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", String(id)))
		for slot in letter.perception:
			var measure := String(letter.perception[slot].get("measure", ""))
			assert_true(MeasureRegistry.has_measure(measure),
				"%s judges '%s', which no normaliser covers" % [letter.id, measure])


func test_the_stockpile_reads_the_worst_need_not_the_average() -> void:
	# A town with a year of grain and no cloth is not four-fifths well. It is a
	# town with no cloth, and a governor writing home says so.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.store(&"food", 1000.0)
	town.take(&"clothing", 10_000.0)
	assert_almost_eq(ColonyMeasures.stockpile_health(town), 0.0, 0.001)

	town.store(&"clothing", 1000.0)
	assert_almost_eq(ColonyMeasures.stockpile_health(town), 1.0, 0.001)


# --- 🔒 Announced before acted on -------------------------------------------

func test_an_objective_is_announced_before_a_plank_is_cut() -> void:
	# The governor settles on the work in Settle (phase 4) and writes in Dispatch
	# (phase 9); Build advances it in phase 4 of the *next* month. That window is
	# the player's chance to object, and it is what makes the loop feel
	# responsive rather than reportorial.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.objective = &"granary"
	town.objective_since = run.world.month
	town.objective_progress = 0

	var context := LetterContext.new(run.world, run.contact(town.governor_id), &"")
	context.town = town
	context.month = run.world.month

	assert_true(ColonyConditions.town_objective_is_new({}, context),
		"the announcement never fires, so nothing is ever announced")

	# A month in, it is no longer news.
	town.objective_progress = 1
	assert_false(ColonyConditions.town_objective_is_new({}, context),
		"the governor announces the same work every month it is under way")


func test_a_finished_objective_is_still_reportable_after_build_clears_it() -> void:
	# Build clears the objective the moment it completes, so a letter that asked
	# the town what it was building would find nothing and never fire.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.clear_objective()
	town.last_completed = &"granary"
	town.last_completed_month = run.world.month

	var context := LetterContext.new(run.world, run.contact(town.governor_id), &"")
	context.town = town
	context.month = run.world.month

	assert_true(ColonyConditions.town_finished_something({}, context))
	assert_eq(String(ColonyParamSources.finished_name({"fallback": "x"}, context)),
		Objective.display_name(&"granary"))

	# Last month's news is not this month's.
	context.month = run.world.month + 1
	assert_false(ColonyConditions.town_finished_something({}, context))


# --- The letter says what it counts -----------------------------------------

func test_the_shortage_letter_counts_the_thing_it_names() -> void:
	# Naming the shortage and then counting the grain is the sort of mismatch a
	# player notices and a validator cannot.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.store(&"food", 900.0)
	town.take(&"clothing", 10_000.0)
	town.store(&"clothing", 7.0)

	var context := LetterContext.new(run.world, run.contact(town.governor_id), &"")
	context.town = town

	assert_eq(String(ColonyParamSources.town_lacks({"fallback": ""}, context)), "clothing")
	assert_eq(int(ColonyParamSources.town_lacking_stock({}, context)), 7)


func test_a_letter_reports_this_month_of_trade_and_not_the_run() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	town.traded_value = 140.0

	var context := LetterContext.new(run.world, run.contact(town.governor_id), &"")
	context.town = town
	assert_eq(int(ColonyParamSources.town_trade({}, context)), 140)


# --- Conditions belong to towns ---------------------------------------------

func test_a_town_shaped_condition_is_false_without_a_town() -> void:
	# Otherwise a Crown officer's trigger could borrow one and fire on a
	# colony-wide reading of a question about a place.
	var run := _run()
	var context := LetterContext.new(run.world, run.contact(&"steward"), &"")
	assert_false(ColonyConditions.town_is_building({}, context))
	assert_false(ColonyConditions.town_finished_something({}, context))
	assert_false(ColonyConditions.town_objective_is_new({}, context))
	assert_false(ColonyConditions.town_disagrees_with_the_crown({}, context))


func test_the_governor_says_so_when_he_is_going_his_own_way() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var context := LetterContext.new(run.world, run.contact(town.governor_id), &"")
	context.town = town

	town.intent = GovernorIntent.ECONOMY
	town.urged_intent = GovernorIntent.ECONOMY
	assert_false(ColonyConditions.town_disagrees_with_the_crown({}, context),
		"he reported a disagreement he is not having")

	town.urged_intent = GovernorIntent.SURVIVAL
	assert_true(ColonyConditions.town_disagrees_with_the_crown({}, context),
		"he was asked for one thing, is doing another, and says nothing")


# --- An intent is not vague --------------------------------------------------

func test_urging_an_intent_is_a_specific_order() -> void:
	# "Your people's survival must come first" is one of exactly five things the
	# PC can say and there is nothing in it to misread. Judging it vague made
	# every governor reinterpret or refuse every priority he was ever sent, which
	# read as a man who could not follow plain English.
	var order := Order.new(
		M1Registrations.ORDER_URGE_INTENT, &"governor_ashmere",
		{"to": "governor_ashmere", "intent": String(GovernorIntent.SURVIVAL)},
	)
	assert_almost_eq(Compliance.vagueness_of(order), 0.0, 0.001)


func test_being_told_what_matters_costs_a_governor_nothing() -> void:
	# It cost something once, and `payment_offered` then decided every priority
	# letter in the game: the PC sends no gold with a pronouncement, so refusing
	# scored highest every month.
	var order := Order.new(
		M1Registrations.ORDER_URGE_INTENT, &"governor_ashmere",
		{"to": "governor_ashmere", "intent": String(GovernorIntent.DEFENCE)},
	)
	assert_almost_eq(Compliance.cost_of(order), 0.0, 0.001)
	assert_almost_eq(Compliance.payment_ratio(order), 1.0, 0.001,
		"a free request reads as one the PC underpaid for")
