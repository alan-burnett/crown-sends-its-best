extends TestCase

## The man behind the knobs (#174, `the-provost.md` §5–§8).
##
## 🔒 **Two things, and the pair is the whole man.** Gold, because he is a Crown
## officer; education, because he is a scholar. So there are two ways to keep
## him — pay his bills, or build his libraries — and the second works **whether
## or not the PC paid for it**.
##
## 🔒 **He never escalates on his own.** He will not enact a policy costlier than
## the one in place and will not spend the PC's money unasked. He advises, and
## when he advises he also advises that the PC pay for it.
##
## He is the opposite of the Steward, who raises duties over the PC's head once
## standing is lost. **The Provost does not act. He simply stops carrying.**

const SEED: int = 1184

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


func _town(id: StringName, education: float = 0.0) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 20
	town.education = education
	return town


func _colony(towns: Array) -> Colony:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	return colony


func _him(loyalty: float = 58.0) -> Contact:
	var contact := Contact.new(Provost.ID)
	contact.display_name = "Dr Silas Meakin"
	contact.role = Contact.ROLE_CROWN_OFFICER
	contact.relationship.loyalty = loyalty
	return contact


func _context(colony: Colony) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	context.colony = colony
	return context


func _knob(effect: StringName, setting: StringName, split: StringName) -> Policy:
	return Policy.new(
		Provost.ID, effect,
		PolicyEffects.monthly_for(effect, setting), split,
		{"level": String(setting)},
	)


func _book(policies: Array) -> PolicyBook:
	var book := PolicyBook.new()
	for policy in policies:
		book.enact(policy, null, 0)
	return book


# --- 🔒 Education warms him, with no payment involved -----------------------

func test_a_learned_colony_pleases_him_and_nobody_paid_for_it() -> void:
	# 🔒 The acceptance, and the design: **the curriculum is the cheapest way in
	# the game to keep him content**, and a colony that built its own libraries
	# pleases him exactly as much as one he was funded to supply.
	var colony := _colony([_town(&"ashmere", 6.0), _town(&"brackwater", 6.0)])
	var him := _him()
	var before := him.loyalty()
	Provost.settle_regard(him, colony, _context(colony))
	assert_true(him.loyalty() > before, "a colony of schools left the scholar cold")


func test_an_ignorant_colony_does_not() -> void:
	var colony := _colony([_town(&"ashmere"), _town(&"brackwater")])
	var him := _him()
	var before := him.loyalty()
	Provost.settle_regard(him, colony, _context(colony))
	assert_almost_eq(him.loyalty(), before, 0.0001,
		"a colony that teaches nothing pleased him anyway")


func test_it_is_a_mean_and_not_a_total() -> void:
	# **A colony does not please him by being large.** Ten ignorant towns are not
	# a scholarly province, and a total would have said they were.
	var small := _colony([_town(&"ashmere", 4.0)])
	var sprawling: Array = []
	for index in 10:
		sprawling.append(_town(StringName("town%d" % index), 0.4))
	assert_true(
		Provost.regard_from_education(small)
			> Provost.regard_from_education(_colony(sprawling)),
		"a big ignorant colony pleased him more than a small learned one")


func test_it_says_so_without_saying_how_much() -> void:
	# 🔒 Loyalty is not a number the player sees (SPEC §8.5). What the letters
	# need is that the schools have been noticed.
	var colony := _colony([_town(&"ashmere", 6.0)])
	var context := _context(colony)
	Provost.settle_regard(_him(), colony, context)
	var moved: Array = context.log.of_type(Provost.EVENT_PLEASED)
	assert_eq(moved.size(), 1, "his regard moved and the record says nothing")
	assert_false(moved[0].payload.has("loyalty"), "the payload carries the figure")
	assert_eq(String(moved[0].payload["why"]), "education")


func test_pleasing_him_is_worth_less_than_paying_him() -> void:
	# 🔒 Otherwise a PC could stiff him on every policy and buy him back with one
	# library, and the gold half of him would stop being a lever at all.
	var perfect := Provost.regard_from_education(_colony([_town(&"ashmere", 99.0)]))
	var unpaid := _knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.NONE)
	assert_true(unpaid.drains() > perfect,
		"a month of libraries outweighed a month of not being paid")


# --- 🔒 He never escalates -------------------------------------------------

func test_he_asks_for_the_charge_he_is_already_carrying() -> void:
	var book := _book([_knob(PolicyEffects.CURRICULUM, PolicyEffects.A_LOT, Policy.NONE)])
	var asking := Provost.advises(book)
	assert_false(asking.is_empty(), "he is paying for the Crown's schools and never mentions it")
	assert_eq(String(asking["effect"]), String(PolicyEffects.CURRICULUM))
	assert_eq(String(asking["level"]), String(PolicyEffects.A_LOT),
		"he asked about a setting other than the one in force")
	assert_true(float(asking["monthly"]) > 0.0, "he advised without naming the cost")


func test_he_never_names_a_setting_above_the_one_in_force() -> void:
	# 🔒 §7. **He does not act.** There is no state of the world in which he asks
	# for more than he is already carrying — which is what makes him the opposite
	# of the Steward, who raises duties over the PC's head.
	for effect in PolicyEffects.PROVOST_KNOBS:
		for held in PolicyEffects.SETTINGS:
			var book := _book([_knob(effect, held, Policy.NONE)])
			for wanted in PolicyEffects.SETTINGS:
				var asked := Provost.asks_for(book, effect, wanted)
				if String(wanted) == String(held) and float(
						PolicyEffects.SETTING_STRENGTH.get(String(held), 0.0)) > 0.0:
					assert_true(asked,
						"carrying '%s' at '%s', he never mentions it" % [effect, held])
				else:
					assert_false(asked,
						"carrying '%s' at '%s', he asked for '%s'" % [effect, held, wanted])


func test_he_says_nothing_about_a_policy_the_crown_is_paying_for() -> void:
	# He is not a nag. A charge the Crown has taken up is a charge he has no
	# opinion about.
	var book := _book([_knob(PolicyEffects.VOLUME, PolicyEffects.A_GREAT_DEAL, Policy.ALL)])
	assert_true(Provost.advises(book).is_empty(),
		"he wrote to complain about a bill somebody else was paying")


func test_he_asks_about_the_one_costing_him_most() -> void:
	var book := _book([
		_knob(PolicyEffects.CURRICULUM, PolicyEffects.A_LITTLE, Policy.NONE),
		_knob(PolicyEffects.EXPERTS, PolicyEffects.A_GREAT_DEAL, Policy.NONE),
	])
	assert_eq(String(Provost.advises(book)["effect"]), String(PolicyEffects.EXPERTS),
		"he raised the trivial charge and let the ruinous one stand")


# --- 🔒 His bias is permanent and in one direction --------------------------

func test_every_measure_he_reports_leans_the_same_way() -> void:
	# 🔒 §6. He thinks the colony is under-educated, under-peopled and poorly
	# provisioned **at every level of investment**, so his advice is predictably
	# "spend more" — something the player learns to discount rather than merely
	# resent, like the Steward's appetite for duties.
	var record := content.record("contacts", "provost")
	assert_false(record.is_empty(), "there is no Provost")
	var leans: Dictionary = record.get("leans", {})
	assert_false(leans.is_empty(), "the Provost has no opinions about anything")
	for measure in leans:
		assert_true(float(leans[measure]) < 0.0,
			"he reports '%s' cheerfully, so his bias is not in one direction" % measure)


func test_he_is_gloomier_about_the_schools_than_about_anything_else() -> void:
	# He is a scholar first. It is the measure his own regard answers to, and the
	# one he presses hardest.
	var leans: Dictionary = content.record("contacts", "provost").get("leans", {})
	var schools := absf(float(leans.get(WorldValues.EDUCATION, 0.0)))
	assert_true(schools > 0.0, "he has no opinion about the schools")
	for measure in leans:
		if String(measure) == WorldValues.EDUCATION:
			continue
		assert_true(schools >= absf(float(leans[measure])),
			"he minds '%s' more than he minds the schools" % measure)


# --- 🔒 He advises, and the cost is always in it ----------------------------

func test_his_advice_letter_names_the_figure() -> void:
	var record := content.record("letters", "provost.advice")
	assert_false(record.is_empty(), "he never advises at all")
	assert_true(record.get("params", {}).has("amount"),
		"his advice does not name what it costs, so it is a favour and not a bill")
	var text := JSON.stringify(record.get("body", []))
	assert_true(text.contains("{param:amount}"),
		"the figure is declared and never said out loud")


func test_his_advice_asks_to_be_funded_and_never_to_be_enlarged() -> void:
	# 🔒 The whole of §7 in one assertion: every answer to his advice is about
	# **who pays for what is already agreed**, and none of them turns a knob up.
	var record := content.record("letters", "provost.advice")
	for step in record["reply"]["steps"]:
		for option in step["options"]:
			for effect in option.get("effect", {}):
				assert_false(String(effect) == "set_knob",
					"his advice offers to enlarge a policy, which he does not do")


func test_the_letter_fires_only_while_he_is_out_of_pocket() -> void:
	var paid := LetterContext.new(WorldValues.initial_state(), _him(), &"")
	paid.policies = _book([_knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.ALL)])
	assert_false(ColonyConditions.he_is_carrying_the_cost({}, paid),
		"he complained about a charge the Crown had taken up")

	var carrying := LetterContext.new(WorldValues.initial_state(), _him(), &"")
	carrying.policies = _book([_knob(PolicyEffects.VOLUME, PolicyEffects.A_LOT, Policy.NONE)])
	assert_true(ColonyConditions.he_is_carrying_the_cost({}, carrying),
		"he paid for the Crown's business in silence")
	assert_true(int(ColonyParamSources.what_he_carries({}, carrying)) > 0,
		"the letter would have gone out quoting nothing")
