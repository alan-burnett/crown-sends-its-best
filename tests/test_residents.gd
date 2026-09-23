extends TestCase

## Institutional contacts: the framework, and residency (#276,
## `docs/mechanics/institutional-contacts.md` §1, §2).
##
## 🔒 **There is no institutional-contact machinery, and there must not be.**
## Every question one of them raises is answered somewhere `contacts.md` already
## has: what his loyalty does, how he gets it, what he asks for, what his bias
## is. **A change made for one of them must not silently move the others**, which
## is what building him out of the base contact guarantees.
##
## 🔒 **An extension never creates a second contact.** The cathedral widens the
## clergyman the church brought.
##
## 🔒 **And he is lost with his building or his town, with no successor.** The
## church rebuilt brings a new man who remembers nothing.

const SEED: int = 9931

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _with(run: RunState, buildings: Array) -> Town:
	var town := run.colony.in_order()[0]
	for id in buildings:
		town.add_building(StringName(id))
	ContactRoster.house_the_residents(run)
	ContactRoster.unhouse_the_lost(run)
	return town


# --- 🔒 Four buildings bring a man, and the theatre brings none -------------

func test_the_four_buildings_grant_and_the_theatre_does_not() -> void:
	for id in ["church", "gunsmith", "printing_press", "library"]:
		var building := Building.find(StringName(id))
		assert_false(building.grants_contact.is_empty(),
			"%s brings nobody, so its man can never arrive" % id)
	assert_true(Building.find(&"theatre").grants_contact.is_empty(),
		"the theatre brings a man, and §1 says it brings nobody")


func test_completing_a_church_brings_a_clergyman_who_lives_there() -> void:
	var run := _run()
	assert_empty(ContactRoster.residents_of(run.colony.in_order()[0], run),
		"a town with no buildings already had a resident")

	var town := _with(run, ["church"])
	var residents := ContactRoster.residents_of(town, run)
	assert_eq(residents.size(), 1, "the church brought %d men" % residents.size())

	var clergyman: Contact = residents[0]
	assert_eq(clergyman.role, Contact.ROLE_INSTITUTIONAL)
	assert_eq(clergyman.town, town.display_name,
		"he does not live in the town that built him a church")


func test_each_building_brings_its_own_man_and_not_another() -> void:
	var run := _run()
	var town := _with(run, ["church", "gunsmith", "printing_press", "library"])
	var kinds: Dictionary = {}
	for resident in ContactRoster.residents_of(town, run):
		kinds[resident.title] = true
	assert_eq(kinds.size(), 4,
		"four buildings brought %d kinds of man: %s" % [kinds.size(), kinds.keys()])


# --- 🔒 An extension widens, and creates no second man ----------------------

func test_the_extensions_name_the_man_they_widen_and_grant_nobody() -> void:
	for id in ["cathedral", "armoury", "college"]:
		var building := Building.find(StringName(id))
		assert_true(building.grants_contact.is_empty(),
			"%s grants a contact, so a town would end up with two" % id)
		assert_false(building.extends_contact.is_empty(),
			"%s widens nobody, so it is not an extension at all" % id)


func test_a_cathedral_widens_the_clergyman_the_church_brought() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var first: Contact = ContactRoster.residents_of(town, run)[0]

	_with(run, ["cathedral"])
	var after := ContactRoster.residents_of(town, run)
	assert_eq(after.size(), 1, "the cathedral brought a second clergyman")
	assert_eq((after[0] as Contact).id, first.id,
		"the cathedral replaced the man rather than widening him")


func test_housing_twice_changes_nothing() -> void:
	# The rule is idempotence, so a town loaded from a save is correct without
	# replaying its history.
	var run := _run()
	var town := _with(run, ["church", "library"])
	var before := ContactRoster.residents_of(town, run).size()
	for round in 4:
		ContactRoster.house_the_residents(run)
	assert_eq(ContactRoster.residents_of(town, run).size(), before,
		"asking four times brought four men")


# --- 🔒 Residency is prominence, through the path that already exists -------

func test_a_resident_carries_prominence_and_the_crowns_officers_do_not() -> void:
	# `rebel-sentiment.md` §4: a resident pushes his town's sentiment by loyalty
	# scaled by prominence. **A slighted clergyman is a mechanical problem**, and a
	# contented one holds his town down.
	var run := _run()
	var town := _with(run, ["church"])
	var clergyman: Contact = ContactRoster.residents_of(town, run)[0]
	assert_true(clergyman.prominence() > 0.0,
		"a resident looms not at all in the town he lives in")
	assert_eq(run.contact(&"steward").prominence(), 0.0,
		"an officer an ocean away pushes a town's sentiment")


func test_he_moves_sentiment_through_the_existing_path_and_no_other() -> void:
	# 🔒 **No file exists that only institutional contacts use.** He reaches the
	# town's sentiment through `_contacts`, exactly as the governor and the
	# Diplomat do, and there is no second route.
	var run := _run()
	var town := _with(run, ["church"])
	var clergyman: Contact = ContactRoster.residents_of(town, run)[0]
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony

	clergyman.relationship = Relationship.new(clergyman.id, 100.0)
	var contented := RebelSentiment.of(town, context, run.grievances, run.contacts)
	clergyman.relationship = Relationship.new(clergyman.id, 0.0)
	var slighted := RebelSentiment.of(town, context, run.grievances, run.contacts)

	assert_true(float(slighted["contacts"]) > float(contented["contacts"]),
		"slighting the clergyman did nothing to his town: %s against %s"
			% [slighted["contacts"], contented["contacts"]])


# --- 🔒 Lost with his building or his town, and no successor ---------------

func test_pulling_down_the_church_takes_the_clergyman() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	assert_eq(ContactRoster.residents_of(town, run).size(), 1)

	town.buildings.erase(&"church")
	ContactRoster.unhouse_the_lost(run)
	assert_empty(ContactRoster.residents_of(town, run),
		"the church came down and its man stayed on")


func test_losing_the_town_takes_him_too() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var clergyman: Contact = ContactRoster.residents_of(town, run)[0]

	run.colony.towns.clear()
	ContactRoster.unhouse_the_lost(run)
	assert_false(run.contacts.has(String(clergyman.id)),
		"a town fell and its clergyman was still writing home")


func test_the_church_rebuilt_brings_a_man_who_remembers_nothing() -> void:
	# 🔒 `contacts.md` §8: **no successor.** It falls out of him being a fresh
	# contact rather than needing a rule of its own.
	var run := _run()
	var town := _with(run, ["church"])
	var first: Contact = ContactRoster.residents_of(town, run)[0]
	first.relationship = Relationship.new(first.id, 3.0)
	first.relationship.record_deed(Relationship.REFUSED)

	town.buildings.erase(&"church")
	ContactRoster.unhouse_the_lost(run)
	_with(run, ["church"])

	var second: Contact = ContactRoster.residents_of(town, run)[0]
	assert_true(second.relationship.deeds.is_empty(),
		"the new clergyman remembers what the Crown did to the last one")
	assert_true(second.relationship.loyalty > first.relationship.loyalty,
		"the new man arrived as sour as his predecessor left")


# --- 🔒 And no machinery of his own ----------------------------------------

func test_he_is_an_ordinary_contact_with_no_fields_of_his_own() -> void:
	# The last acceptance line, stated as a property: a resident carries nothing a
	# governor does not, so a change made for one cannot silently move the other.
	var run := _run()
	var town := _with(run, ["church"])
	var clergyman: Contact = ContactRoster.residents_of(town, run)[0]
	var governor := run.contact(town.governor_id)

	var his: Dictionary = {}
	for entry in clergyman.get_property_list():
		his[String(entry["name"])] = true
	for entry in governor.get_property_list():
		his.erase(String(entry["name"]))
	assert_true(his.is_empty(),
		"a resident carries fields a governor does not: %s" % ", ".join(his.keys()))


func test_his_letterhead_says_what_he_is() -> void:
	# §2's table: *Journalist Aldous Crane of Kettleburn*. Four kinds share the
	# institutional role the way four offices share the Crown officer's, so the
	# word is his own.
	var run := _run()
	var town := _with(run, ["printing_press"])
	var journalist: Contact = ContactRoster.residents_of(town, run)[0]
	assert_eq(Letterhead.of(journalist),
		"Journalist %s of %s" % [journalist.display_name, town.display_name])


# --- 🔒 What his loyalty does: the building works as well as he is treated ---
#
# `institutional-contacts.md` §3: the church gives **perceived safety**, and a
# contented clergyman gives more of it. **A church with a slighted priest in it
# is a building the town has stopped believing in.**
#
# One rule for every building that brings a man, not a clergy rule: §3 asks for
# it twice, and a second copy written for the scholar's library would be the
# first place the two could disagree.

func _clergyman(run: RunState, town: Town) -> Contact:
	return run.contacts.get(
		String(ContactRoster.resident_id(town, "clergyman")), null)


func _comfort(run: RunState, town: Town) -> float:
	return Building.perceived_safety_for(town, run.contacts)


func test_a_church_comforts_the_town_at_all() -> void:
	# The effect `buildings.md` §4 has always listed and nothing ever built.
	var run := _run()
	var town := run.colony.in_order()[0]
	var bare := _comfort(run, town)
	_with(run, ["church"])
	assert_true(_comfort(run, town) > bare,
		"a church gives the town no comfort, so §4's perceived safety is unbuilt")


func test_a_contented_priest_gives_more_of_it_and_a_slighted_one_less() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	assert_true(priest != null, "the church brought nobody")

	priest.relationship = Relationship.new(priest.id, Relationship.NEUTRAL_LOYALTY)
	var neutral := _comfort(run, town)

	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)
	var contented := _comfort(run, town)

	priest.relationship = Relationship.new(priest.id, Relationship.MIN_LOYALTY)
	var slighted := _comfort(run, town)

	assert_true(contented > neutral,
		"a contented priest's church comforts no more than an indifferent one's")
	assert_true(slighted < neutral,
		"a slighted priest's church comforts just as much, so his regard does nothing")


func test_neutral_regard_is_the_building_exactly_as_authored() -> void:
	# 🔒 The authored figures in `buildings.md` §4 go on meaning what they say for
	# a man nobody has dealt with either way.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.NEUTRAL_LOYALTY)
	assert_almost_eq(_comfort(run, town),
		float(Building.find(&"church").effect("perceived_safety", 0.0)), 0.0001,
		"an indifferent priest's church is not worth what the data says it is")


func test_a_building_that_brings_nobody_is_not_scaled_by_anybody() -> void:
	# One is the answer for everything else, or every effect in the game would
	# quietly depend on whoever happened to live in the town.
	var run := _run()
	var town := run.colony.in_order()[0]
	assert_eq(Building.regard_scale(Building.find(&"theatre"), town, run.contacts), 1.0,
		"a theatre's worth depends on a contact it never brought")
	assert_eq(Building.regard_scale(Building.find(&"granary"), town, run.contacts), 1.0)


func test_a_church_whose_priest_has_not_arrived_is_worth_what_it_says() -> void:
	# A town that has just built a church is not penalised for the month before
	# its priest is housed.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.add_building(&"church")
	assert_almost_eq(_comfort(run, town),
		float(Building.find(&"church").effect("perceived_safety", 0.0)), 0.0001,
		"a church with nobody in it yet was docked for it")


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	# **Ground, because `Experts.worth_of` reads what a town can work.** Without
	# it every town is worth nothing to every expert and nowhere is ever better
	# than anywhere — which made the travel tests pass by arranging nothing.
	context.territory = Territory.compute(run.map, run.colony.in_order())
	return context


## A town with four hundred armed men at the gate, so safety is genuinely below
## one and there is something for a church to be a comfort about.
##
## 🔒 **Without this the test cannot fail.** A quiet town is already at one and
## cannot be lifted, so the first version of this passed with `safety_of`
## ignoring the comfort entirely — caught by mutation, not by reading.
func _besieged(run: RunState) -> Town:
	var town := run.colony.in_order()[0]
	town.workers = 20
	run.companies.raise_company(
		Company.NATIVE, 400, {"guns": 400.0, "tools": 400.0},
		Company.SUPPORTED_BY_CROWN, town.at, _context(run))
	return town


func test_the_comfort_reaches_the_town_s_quality_of_life() -> void:
	# 🔒 The point of all of it. A knob nothing reads is a number in a file, and
	# this has to arrive through `safety_of` or the priest's regard buys nothing.
	var run := _run()
	var town := _besieged(run)
	var context := _context(run)

	var bare := QualityOfLife.safety_of(town, context)
	assert_true(bare < 1.0,
		"the town is in no danger, so a comfort cannot lift it and this proves nothing")

	town.add_building(&"church")
	ContactRoster.house_the_residents(run)
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)

	assert_true(QualityOfLife.safety_of(town, context) > bare,
		"the church's comfort never reached the town's quality of life")


func test_a_slighted_priest_leaves_the_besieged_town_less_comforted() -> void:
	# 🔒 The whole of what his loyalty buys, asked where it can be seen.
	var run := _run()
	var town := _besieged(run)
	var context := _context(run)
	town.add_building(&"church")
	ContactRoster.house_the_residents(run)
	var priest := _clergyman(run, town)

	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)
	var contented := QualityOfLife.safety_of(town, context)
	priest.relationship = Relationship.new(priest.id, Relationship.MIN_LOYALTY)
	var slighted := QualityOfLife.safety_of(town, context)

	assert_true(contented > slighted,
		"the town felt exactly as safe whether its priest was contented or slighted")


func test_comfort_never_makes_a_doomed_town_read_as_safe() -> void:
	# 🔒 It lifts what danger has left rather than being added to it, the same
	# shape `combine` uses for pleasure — so a church is never a garrison.
	assert_true(Building.perceived_safety_for(
		Town.new(&"nowhere", "Nowhere", Vector2i(0, 0)), {}) >= 0.0)
	var run := _run()
	var town := _with(run, ["church", "cathedral"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)
	assert_true(_comfort(run, town) < 2.0,
		"two buildings and a devoted priest produced a comfort that would swamp any danger")


# --- 🔒 The cathedral widens him and brings no second man -------------------

func test_the_cathedral_widens_the_church_and_brings_nobody_new() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.NEUTRAL_LOYALTY)
	var one := _comfort(run, town)
	var before := run.contacts.size()

	town.add_building(&"cathedral")
	ContactRoster.house_the_residents(run)

	assert_eq(run.contacts.size(), before,
		"the cathedral brought a second clergyman")
	assert_same(_clergyman(run, town), priest,
		"the cathedral replaced the man the church brought")
	assert_true(_comfort(run, town) > one,
		"the cathedral widened nothing")


# --- 🔒 How he gets loyalty: the town read from the bottom ------------------

func test_he_is_among_the_most_prominent_men_in_the_colony() -> void:
	# 🔒 §3: very influential, so his regard moves his town's sentiment hard
	# either way. Above the Diplomat and the commander; below the governor, whose
	# prominence only the journalist matches.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	assert_true(priest.prominence() > Contact.prominence_of(Contact.ROLE_DIPLOMAT),
		"the clergyman looms smaller than the Crown's resident")
	assert_true(priest.prominence() > Contact.prominence_of(Contact.ROLE_COMMANDER),
		"the clergyman looms smaller than a commander")
	assert_true(priest.prominence() <= Contact.prominence_of(Contact.ROLE_GOVERNOR),
		"the clergyman looms larger than the man who governs the town")
	assert_true(priest.prominence() > Contact.prominence_of(Contact.ROLE_INSTITUTIONAL),
		"he carries the bare institutional prominence, so nothing was authored for him")


func test_what_he_judges_the_pc_by_is_the_poorest_and_not_the_average() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	assert_true(priest.cares_about.has(ColonyMeasures.POOREST_QUALITY_OF_LIFE),
		"the clergyman judges the Crown by nothing, so nothing will ever move him")


func test_he_reads_his_own_town_and_the_reading_reaches_him() -> void:
	# 🔒 A resident used to get no town measures at all — only governors did — so
	# a `cares_about` naming one would have drifted on a measure nobody supplied.
	var run := _run()
	var town := _with(run, ["church"])
	town.poorest_quality_of_life = 0.2
	var priest := _clergyman(run, town)

	var measures := ColonyMeasures.for_contact(run, priest)
	assert_has(measures, ColonyMeasures.POOREST_QUALITY_OF_LIFE,
		"the clergyman was handed no reading of the town he lives in")
	assert_almost_eq(float(measures[ColonyMeasures.POOREST_QUALITY_OF_LIFE]), 0.2, 0.0001)


func test_a_wretched_town_cools_him_and_a_comfortable_one_warms_him() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)

	town.poorest_quality_of_life = 0.05
	var wretched := LoyaltyDrift.for_contact(priest, ColonyMeasures.for_contact(run, priest))
	town.poorest_quality_of_life = 0.95
	var kindly := LoyaltyDrift.for_contact(priest, ColonyMeasures.for_contact(run, priest))

	assert_true(wretched < 0.0, "a town of hungry people did not cool the priest")
	assert_true(kindly > wretched,
		"the priest thinks no better of a town that looks after its poor")


# --- 🔒 Blind to pleasure, which is the trap he does not fall into ----------

func test_rum_and_a_theatre_do_not_please_him() -> void:
	# 🔒 `quality-of-life.md` §8's trap, and **the clergy is the one voice that
	# will not be fooled by it** (§3). A town scoring well on pleasure and badly
	# on health must not read to him as a town doing well.
	var comfortable := {
		"health": 0.15, "safety": 0.8, "means": 0.2, "hope": 0.5, "pleasure": 1.0,
	}
	var plain := comfortable.duplicate()
	plain["pleasure"] = 0.0

	assert_eq(QualityOfLife.from_below(comfortable), QualityOfLife.from_below(plain),
		"a cellar of rum improved how the poorest of the town were judged to live")

	# And the ordinary reading *is* lifted by it, or the test above proves only
	# that pleasure does nothing anywhere.
	assert_true(
		QualityOfLife.combine(
			QualityOfLife.substance_of(comfortable), float(comfortable["pleasure"]))
		> QualityOfLife.combine(
			QualityOfLife.substance_of(plain), float(plain["pleasure"])),
		"pleasure lifts nothing at all, so being blind to it means nothing")


func test_he_weighs_health_and_means_over_the_rest() -> void:
	var weights := QualityOfLife.poorest_weights()
	for lighter in ["safety", "hope"]:
		assert_true(float(weights["health"]) > float(weights[lighter]),
			"health weighs no more to him than %s" % lighter)
		assert_true(float(weights["means"]) > float(weights[lighter]),
			"means weighs no more to him than %s" % lighter)
	assert_false(weights.has("pleasure"),
		"pleasure has a weight in a reading that is supposed to be blind to it")


func test_a_hungry_town_with_a_theatre_reads_worse_to_him_than_to_anyone() -> void:
	# The whole point, as a comparison rather than a magnitude.
	var parts := {
		"health": 0.1, "safety": 0.9, "means": 0.15, "hope": 0.6, "pleasure": 1.0,
	}
	var ordinary := QualityOfLife.combine(
		QualityOfLife.substance_of(parts), float(parts["pleasure"]))
	assert_true(QualityOfLife.from_below(parts) < ordinary,
		"the priest is no harder to satisfy than the town's own reckoning")


# --- 🔒 His bias: every welfare measure leans dark --------------------------

func test_every_welfare_measure_he_reports_leans_dark() -> void:
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	assert_not_empty(priest.leans, "the clergyman has no bias at all")
	for topic in priest.leans:
		assert_true(priest.lean_for(String(topic)) < 0.0,
			"the clergyman leans bright on '%s', and §3 has him dark on every welfare measure"
				% topic)
	assert_true(priest.lean_for(ColonyMeasures.POOREST_QUALITY_OF_LIFE) < 0.0,
		"he reports the thing he cares most about without any bias at all")


func test_his_gloom_is_bounded_by_the_one_rung_cap() -> void:
	# 🔒 `perception.md`'s cap is what keeps him readable: reliably one notch
	# bleaker than the truth rather than hysterical. A PC who discounts him
	# entirely is the one who misses the famine.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	for raw in [0.1, 0.35, 0.6, 0.9]:
		var truth := Perception.truthful_rung(
			ColonyMeasures.POOREST_QUALITY_OF_LIFE, raw, 5)
		var his := Perception.rung(
			ColonyMeasures.POOREST_QUALITY_OF_LIFE, raw,
			priest.lean_for(ColonyMeasures.POOREST_QUALITY_OF_LIFE), 5)
		assert_true(his <= truth,
			"the priest reported a town at %f as better than it is" % raw)
		assert_true(truth - his <= 1,
			"the priest was more than one rung bleaker than the truth at %f" % raw)


# --- 🔒 The journalist: the sharpest sword in the tree ----------------------

func _journalist(run: RunState, town: Town) -> Contact:
	return run.contacts.get(
		String(ContactRoster.resident_id(town, "journalist")), null)


func test_his_prominence_equals_a_governors() -> void:
	# 🔒 §3, and everything about him follows from it. No other resident comes
	# close, and a press gives one building a second voice as loud as the man who
	# runs the town.
	var run := _run()
	var town := _with(run, ["printing_press"])
	var press := _journalist(run, town)
	assert_true(press != null, "the printing press brought nobody")
	assert_eq(press.prominence(), Contact.prominence_of(Contact.ROLE_GOVERNOR),
		"the journalist does not carry a governor's weight")
	assert_true(press.prominence() > _clergyman(run, _with(run, ["church"])).prominence(),
		"the clergyman is louder than the press, and §3 has it the other way")


func test_he_reads_the_worst_town_and_not_the_average() -> void:
	var run := _run()
	var town := _with(run, ["printing_press"])
	var press := _journalist(run, town)
	assert_true(press.cares_about.has(ColonyMeasures.WORST_QUALITY_OF_LIFE),
		"the journalist judges the Crown by nothing")

	town.quality_of_life = 0.9
	var narrow: float = ColonyMeasures.for_contact(run, press)[ColonyMeasures.WORST_QUALITY_OF_LIFE]

	var hamlet := Town.new(&"gallows_end", "Gallows End", Vector2i(6, 6))
	hamlet.quality_of_life = 0.1
	run.colony.add(hamlet)
	var wide: float = ColonyMeasures.for_contact(run, press)[ColonyMeasures.WORST_QUALITY_OF_LIFE]

	assert_true(float(wide) < float(narrow),
		"one wretched hamlet did not reach the man who prints what people send him")
	assert_almost_eq(float(wide), 0.1, 0.0001,
		"he read something other than the worst town in the colony")


func test_a_wide_colony_is_harder_to_please_at_the_same_average() -> void:
	# 🔒 The acceptance line, and the whole of why the minimum is not the mean.
	# Two colonies of equal average quality of life, one of them holding a
	# neglected hamlet, must not read the same to him.
	var run := _run()
	var town := _with(run, ["printing_press"])
	town.quality_of_life = 0.5

	var even: float = ColonyMeasures.for_contact(run, _journalist(run, town))[
		ColonyMeasures.WORST_QUALITY_OF_LIFE]

	# Same average of 0.5 across two towns, arranged badly.
	town.quality_of_life = 0.9
	var hamlet := Town.new(&"gallows_end", "Gallows End", Vector2i(6, 6))
	hamlet.quality_of_life = 0.1
	run.colony.add(hamlet)
	var lopsided: float = ColonyMeasures.for_contact(run, _journalist(run, town))[
		ColonyMeasures.WORST_QUALITY_OF_LIFE]

	assert_true(float(lopsided) < float(even),
		"a colony that neglects one town reads to him exactly as one that does not")


func test_he_is_alarmed_and_the_clergyman_is_not() -> void:
	var run := _run()
	var town := _with(run, ["printing_press", "church"])
	assert_eq(_journalist(run, town).lean_shape, Perception.SHAPE_ALARMED,
		"the journalist reads the world like everybody else")
	assert_eq(_clergyman(run, town).lean_shape, Perception.SHAPE_FLAT,
		"the clergyman picked up a shape that was never authored for him")


# --- 🔒 The shape of a lean is not its size ---------------------------------

## How much alarm a man of this shape feels, where the truth is `p`.
func _alarm(shape: StringName, p: float) -> float:
	return 1.0 - Perception.trouble_seen(shape, p)


func test_a_small_trouble_moves_him_nearly_as_far_as_a_large_one() -> void:
	# 🔒 §3: *small troubles move him nearly as far as large ones*. A tenth of
	# the trouble there could be already reads to him as a large share of the
	# alarm of all of it — which is what "steep near zero and flattening out"
	# means, and it is the opposite of everybody else.
	var slight := _alarm(Perception.SHAPE_ALARMED, 0.9)
	var total := _alarm(Perception.SHAPE_ALARMED, 0.0)
	var truthful := _alarm(Perception.SHAPE_FLAT, 0.9)

	assert_true(slight > 3.0 * truthful,
		"a tenth of the trouble there could be read to him as a tenth of the alarm")
	assert_true(slight > 0.25 * total,
		"a slight trouble barely registered with the man who prints every one")


func test_the_sanguine_shape_is_its_mirror() -> void:
	# The Marshal's curve, built here because it is the same machinery and a
	# second copy written later would be the first place the two disagreed.
	var slight := 0.9
	assert_true(_alarm(Perception.SHAPE_SANGUINE, slight)
			< _alarm(Perception.SHAPE_FLAT, slight),
		"the man who minimises every threat did not minimise a small one")
	assert_true(_alarm(Perception.SHAPE_ALARMED, slight)
			> _alarm(Perception.SHAPE_SANGUINE, slight),
		"the press and the Marshal saw the same small trouble the same way")

	# 🔒 And they agree about the ends, because neither invents trouble that is
	# not there nor overlooks a colony in ruins.
	for p in [0.0, 1.0]:
		assert_almost_eq(_alarm(Perception.SHAPE_ALARMED, p),
			_alarm(Perception.SHAPE_SANGUINE, p), 0.0001,
			"two men disagreed about a colony that is plainly fine or plainly lost")


func test_a_flat_shape_changes_nothing_at_all() -> void:
	# 🔒 Almost every contact in the game is flat, and this must stay exactly what
	# the pipeline always did.
	for p in [0.0, 0.25, 0.5, 0.75, 1.0]:
		assert_almost_eq(Perception.trouble_seen(Perception.SHAPE_FLAT, p), p, 0.0001,
			"a flat reader stopped seeing the truth as it is")


func test_the_shape_never_carries_a_lean_past_the_one_rung_cap() -> void:
	# 🔒 What keeps him readable. He is reliably one notch bleaker than the truth,
	# never two, whatever the shape does to where his lean bites.
	MeasureRegistry.register_linear("probe", 0.0, 1.0)
	for raw in [0.05, 0.2, 0.45, 0.7, 0.95]:
		var truth := Perception.truthful_rung("probe", raw, 5)
		for shape in Perception.SHAPES:
			var his := Perception.rung("probe", raw, -0.9, 5, shape)
			assert_true(absi(truth - his) <= 1,
				"a %s lean moved the word more than one rung at %f" % [shape, raw])


func test_the_shape_reaches_the_word_a_letter_prints() -> void:
	# 🔒 **Asked of `rung`, not of `shape_scale`.** A curve nothing applies is a
	# function nobody calls: the first version of the tests above checked the
	# shape in isolation and passed with `rung` ignoring it entirely, which
	# mutation caught and reading did not.
	#
	# At a level where there is little wrong, the alarmed man must reach a
	# different rung from the flat one carrying the same lean.
	# 🔒 **With no lean at all**, which is the whole of what *the shape of his
	# lean rather than its size* means: the curve is the bias, and a man carrying
	# none of the second still reports differently because of the first.
	MeasureRegistry.register_linear("probe", 0.0, 1.0)
	var raw := 0.9

	var flat := Perception.rung("probe", raw, 0.0, 5, Perception.SHAPE_FLAT)
	var alarmed := Perception.rung("probe", raw, 0.0, 5, Perception.SHAPE_ALARMED)
	var sanguine := Perception.rung("probe", raw, 0.0, 5, Perception.SHAPE_SANGUINE)

	assert_true(alarmed < flat,
		"the man who prints every trouble said the same word as the truth")
	assert_eq(flat, Perception.truthful_rung("probe", raw, 5),
		"a flat reader with no lean said something other than the truth")
	assert_true(sanguine >= flat,
		"the man who minimises every threat was bleaker than a plain reading")


func test_the_shape_is_the_senders_and_travels_with_his_lean() -> void:
	# It belongs to the man rather than to the ladder, so two men reading one
	# measure through one letter can still disagree about how loudly to say it.
	var run := _run()
	var town := _with(run, ["printing_press", "church"])
	var press := _journalist(run, town)
	var priest := _clergyman(run, town)

	MeasureRegistry.register_linear("probe", 0.0, 1.0)
	var raw := 0.97
	var his := Perception.rung("probe", raw, -0.34, 5, press.lean_shape)
	var the_priests := Perception.rung("probe", raw, -0.34, 5, priest.lean_shape)
	assert_true(his <= the_priests,
		"the press was no quicker to print trouble than the pulpit was to preach it")


func test_an_unknown_shape_falls_back_to_flat() -> void:
	# A content mistake must not silently change what a man sees.
	assert_almost_eq(Perception.trouble_seen(&"wishful", 0.4), 0.4, 0.0001)
	assert_false(Perception.is_shape(&"wishful"))
	for shape in Perception.SHAPES:
		assert_true(Perception.is_shape(shape))


# --- 🔒 The scholar: education, peace, and the experts he gathers -----------

func _scholar(run: RunState, town: Town) -> Contact:
	return run.contacts.get(String(ContactRoster.resident_id(town, "scholar")), null)


func _lines_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func test_a_slighted_scholar_teaches_badly() -> void:
	# 🔒 §3: the library turns resident experts into education, and his regard
	# scales it. **The building stands and the learning stops.** Asked of
	# `Education.of` rather than of the knob — the same rule the church's comfort
	# goes through, because §3 asks for it twice.
	var run := _run()
	var town := _with(run, ["theatre", "library"])
	town.add_experts(&"furs", 3)
	var man := _scholar(run, town)
	assert_true(man != null, "the library brought nobody")

	var context := _context(run)
	man.relationship = Relationship.new(man.id, Relationship.NEUTRAL_LOYALTY)
	var indifferent := Education.of(town, context)
	assert_true(indifferent > 0.0, "the library taught nothing at all")

	man.relationship = Relationship.new(man.id, Relationship.MAX_LOYALTY)
	var contented := Education.of(town, context)
	man.relationship = Relationship.new(man.id, Relationship.MIN_LOYALTY)
	var slighted := Education.of(town, context)

	assert_true(contented > indifferent, "a contented scholar taught no better")
	assert_true(slighted < indifferent,
		"a slighted scholar taught just as well, so his regard does nothing")


func test_he_judges_the_colony_by_its_schooling_and_its_quiet() -> void:
	var run := _run()
	var town := _with(run, ["theatre", "library"])
	var man := _scholar(run, town)
	assert_true(man.cares_about.has(WorldValues.EDUCATION),
		"the scholar does not care whether anybody is taught")
	assert_true(man.cares_about.has(ColonyMeasures.COLONY_AT_PEACE),
		"the scholar does not mind the fighting")
	assert_true(man.prominence() < _clergyman(run, _with(run, ["church"])).prominence(),
		"the scholar looms as large as the priest, and §3 has him smaller")


# --- 🔒 He does not ask who started it --------------------------------------

func test_an_attack_on_the_colony_costs_him_as_much_as_one_by_it() -> void:
	# 🔒 §3, and a deliberate inversion of `rebel-sentiment.md` §2. Sentiment
	# measures **who is blamed**; the scholar measures how bad it is and blames
	# whoever is in charge. He blames the PC when a rival attacks an expedition,
	# which is not the PC's aggression by any reading.
	var run := _run()
	var quiet := ColonyMeasures.at_peace(run)
	assert_almost_eq(quiet, 1.0, 0.0001, "a colony that has fought nobody is not at peace")

	run.world.month = 6
	for round in 3:
		run.log.emit(Battle.EVENT_FOUGHT, &"somewhere", 5, {}, WorldPhase.MOVEMENT)
	assert_true(ColonyMeasures.at_peace(run) < quiet,
		"three battles did not trouble a man who wants everyone to get along")


func test_nothing_in_the_peace_measure_can_name_an_aggressor() -> void:
	# 🔒 **Attribution-blind by construction**, not by a rule somebody remembers.
	# A later dev who wanted to excuse the PC a battle he did not start would
	# have nowhere to put the exception.
	var code := _lines_of("res://correspondence/perception/colony_measures.gd")
	var from := code.find("func at_peace")
	assert_true(from >= 0, "the peace measure has gone")
	var body := code.substr(from)
	var ends := body.find("\nstatic func ", 10)
	if ends > 0:
		body = body.substr(0, ends)
	for token in ["aggressor", "attacker", "provoked", "blame", "defender"]:
		assert_false(body.contains(token),
			"the peace measure asks who began it: %s" % token)


# --- 🔒 He can move an expert, and nothing else can -------------------------

func _two_towns(run: RunState) -> Array:
	var home := run.colony.in_order()[0]
	var frontier := Town.new(&"gallows_end", "Gallows End", Vector2i(6, 6))
	frontier.workers = 8
	run.colony.add(frontier)
	return [home, frontier]


func test_he_moves_a_man_and_the_colony_keeps_the_same_number() -> void:
	var run := _run()
	var towns := _two_towns(run)
	var home: Town = towns[0]
	var frontier: Town = towns[1]
	home.add_experts(&"furs", 2)

	var before := home.expert_count(&"furs") + frontier.expert_count(&"furs")
	assert_true(ExpertTransfer.move(home, frontier, &"furs", _context(run)),
		"the scholar could not move a trapper to a town that wanted one")

	assert_eq(home.expert_count(&"furs"), 1, "he took more than one man")
	assert_eq(frontier.expert_count(&"furs"), 1, "nobody arrived")
	assert_eq(home.expert_count(&"furs") + frontier.expert_count(&"furs"), before,
		"moving a man made or unmade one")


func test_he_cannot_move_a_man_who_is_not_there() -> void:
	var run := _run()
	var towns := _two_towns(run)
	assert_false(ExpertTransfer.move(towns[0], towns[1], &"tobacco", _context(run)),
		"a town with no tobacco expert sent one anyway")
	assert_false(ExpertTransfer.may_move(towns[0], towns[0], &"furs"),
		"a town moved a man to itself")


func test_the_move_is_in_the_log_for_the_letters_to_read() -> void:
	var run := _run()
	var towns := _two_towns(run)
	(towns[0] as Town).add_experts(&"furs", 1)
	ExpertTransfer.move(towns[0], towns[1], &"furs", _context(run))

	var moved := run.log.of_type(ExpertTransfer.EVENT_MOVED)
	assert_eq(moved.size(), 1, "moving a man emitted %d events" % moved.size())
	assert_eq(String(moved[0].payload["to"]), "gallows_end")


func test_nothing_else_in_the_game_takes_an_expert_off_a_town() -> void:
	# 🔒 Two ways to move a man is two rules about who may, and the first time one
	# is tuned the other will not know. `Experts` makes them and `ExpertTransfer`
	# moves them.
	# **Taking one off is the distinctive act**, so the scan is for a negative
	# count rather than for the word — `Experts.materialise` calls `add_experts`
	# every month and is not moving anybody, which a cruder guard flagged.
	# ⚠️ **`town.gd` is deliberately not scanned.** `take_one_life` removes an
	# expert when a town has no worker left to lose, which is `CLAUDE.md`'s
	# workers-before-experts rule and is a death rather than a relocation. The
	# distinction is the whole point: this guard is about a man arriving
	# somewhere else, and nobody arrives from that one.
	var movers := PackedStringArray()
	for path in ["res://sim/colony/experts.gd", "res://sim/colony/education.gd",
			"res://sim/colony/phases/settle.gd", "res://sim/colony/colony.gd"]:
		for line in _lines_of(path).split("\n"):
			var text := String(line)
			if text.contains("add_experts(") and text.contains(", -"):
				movers.append("%s: %s" % [path, text.strip_edges()])
	assert_empty(movers,
		"something other than ExpertTransfer takes an expert off a town: %s" % [movers])

	# And the one that does, does. Or the scan above proves only that nobody
	# anywhere moves an expert, which was true before this ticket.
	assert_true(_lines_of("res://sim/colony/expert_transfer.gd").contains(", -1"),
		"ExpertTransfer no longer takes the man off the town he left")


# --- 🔒 Unprompted he gathers them; asked, he complies ----------------------

func test_he_sends_a_man_where_he_would_be_worth_more() -> void:
	# 🔒 *Send them where they will be most useful* — and **asked of
	# `Experts.worth_of`**, which is the same reading a town uses to decide what
	# expertise it wants. A second opinion here would be a second answer to what
	# an expert is for.
	var run := _run()
	var home := run.colony.in_order()[0]
	home.add_experts(&"furs", 3)

	var frontier := _frontier(run, &"gallows_end")
	var context := _context(run)

	# 🔒 **A town with none of them comes first**, whatever the arithmetic says:
	# the first expert is the difference between a trade the town can work and
	# one it cannot, and `worth_of`'s diminishing returns describe the second.
	assert_same(ExpertTransfer.most_useful_elsewhere(home, &"furs", context), frontier,
		"he passed over the town that had no trapper at all")

	# Once it has one, it is only worth more where it is worth more.
	frontier.add_experts(&"furs", 1)
	var second := ExpertTransfer.most_useful_elsewhere(home, &"furs", _context(run))
	if second != null:
		assert_true(
			Experts.worth_of(second, &"furs", context)
			> Experts.worth_of(home, &"furs", context),
			"he moved a man somewhere he would be worth less")


func test_he_sends_nobody_when_nowhere_is_better() -> void:
	# A colony of one town has nowhere to send anybody, and a man already in the
	# best place for him stays there.
	var run := _run()
	var home := run.colony.in_order()[0]
	home.add_experts(&"furs", 3)
	assert_eq(ExpertTransfer.most_useful_elsewhere(home, &"furs", _context(run)), null,
		"a colony of one town found somewhere else to send a trapper")


func test_asked_he_sends_the_man_where_he_is_told() -> void:
	# 🔒 The capability stays the PC's instrument. Nothing consults his
	# preference when a letter names a destination — exactly as the Steward
	# follows an instruction he disagrees with.
	var run := _run()
	var towns := _two_towns(run)
	var home: Town = towns[0]
	var frontier: Town = towns[1]
	home.add_building(&"theatre")
	home.add_building(&"library")
	home.add_experts(&"furs", 1)
	ContactRoster.house_the_residents(run)

	assert_true(ExpertTransfer.move(home, frontier, &"furs", _context(run)),
		"the scholar refused to send a man away from his own library")
	assert_eq(frontier.expert_count(&"furs"), 1,
		"the man went somewhere other than where he was sent")


func test_only_a_town_with_more_than_one_has_anybody_to_spare() -> void:
	# 🔒 *If I have more than one expert of a particular type.* The last weaver a
	# town has is not spare, however badly somewhere else wants one.
	var run := _run()
	var towns := _two_towns(run)
	var home: Town = towns[0]

	assert_empty(ExpertTransfer.spare_kinds(home),
		"a town with no experts had somebody to spare")
	home.add_experts(&"furs", 1)
	assert_empty(ExpertTransfer.spare_kinds(home),
		"a town with one trapper counted him as spare")
	home.add_experts(&"furs", 1)
	assert_true(ExpertTransfer.spare_kinds(home).has("furs"),
		"a town with two trappers had nobody to spare")

	home.add_experts(&"ore", 2)
	var spare := ExpertTransfer.spare_kinds(home)
	var sorted := spare.duplicate()
	sorted.sort()
	assert_eq(spare, sorted,
		"the kinds came out unsorted, so two runs of one seed would differ")


# --- 🔒 The college widens him and brings no second scholar -----------------

func test_the_college_widens_the_scholar_and_brings_nobody_new() -> void:
	var run := _run()
	var town := _with(run, ["theatre", "library"])
	town.add_experts(&"furs", 2)
	var man := _scholar(run, town)
	man.relationship = Relationship.new(man.id, Relationship.NEUTRAL_LOYALTY)
	var before := run.contacts.size()
	var narrow := Education.of(town, _context(run))

	town.add_building(&"college")
	ContactRoster.house_the_residents(run)

	assert_eq(run.contacts.size(), before, "the college brought a second scholar")
	assert_same(_scholar(run, town), man, "the college replaced the man the library brought")
	assert_true(Education.of(town, _context(run)) > narrow,
		"the college widened nothing")


# --- 🔒 Travelling experts: the scholar's policy (#280) ---------------------
#
# *"I would like our experts to spread knowledge around the colony. We just need
# a little gold for their travel expenses. I will arrange all the travel and
# send them where they will be most useful."*

func _with_library(run: RunState) -> Town:
	var home := run.colony.in_order()[0]
	home.add_building(&"theatre")
	home.add_building(&"library")
	ContactRoster.house_the_residents(run)
	return home


## A second town on real ground, far enough from the capital to hold its own
## tiles — so `Experts.worth_of` has something to read about it.
func _frontier(run: RunState, id: StringName, _at: Vector2i = Vector2i.ZERO) -> Town:
	var home := run.colony.in_order()[0]
	var site := _land_away_from(run, home.at)
	var town := Town.new(id, String(id).capitalize(), site)
	town.workers = 10
	run.colony.add(town)
	return town


func _land_away_from(run: RunState, from: Vector2i) -> Vector2i:
	var best := from + Vector2i(5, 5)
	for radius in [6, 7, 5, 8, 4]:
		for step in 8:
			var at := from + Vector2i(radius, step - 4)
			if run.map.in_bounds(at.x, at.y) and run.map.is_land(at.x, at.y):
				return at
	return best


func _reckon(run: RunState) -> void:
	ExpertTravelDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)


func test_the_policy_presses_a_flag_the_sim_can_read() -> void:
	# The rule every other policy follows: the sim reads a world value and never
	# the policy book, so a policy that lapses stops arranging travel without
	# anybody being told.
	var book := PolicyBook.new()
	book.enact(Policy.new(
		&"scholar_ashmere", PolicyEffects.TRAVELLING_EXPERTS, 20.0, Policy.ALL),
		EventLog.new(), 3)
	assert_has(PolicyEffects.pressure(book), PolicyEffects.TRAVELLING_EXPERTS_KEY,
		"the scholar's policy presses on nothing, so nobody will ever travel")


func test_without_the_policy_nobody_goes_anywhere() -> void:
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"furs", 3)
	_frontier(run, &"gallows_end", Vector2i(6, 6))

	_reckon(run)
	assert_eq(home.expert_count(&"furs"), 3,
		"experts travelled with no policy paying for the journey")


func test_with_it_the_spare_man_goes_where_he_is_worth_more() -> void:
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"furs", 3)
	_frontier(run, &"gallows_end", Vector2i(6, 6))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	_reckon(run)
	assert_true(home.expert_count(&"furs") < 3,
		"the scholar was paid to arrange travel and arranged none")
	assert_not_empty(run.log.of_type(ExpertTransfer.EVENT_MOVED),
		"somebody moved and the log does not say so")


func test_he_never_sends_the_last_man_of_a_kind() -> void:
	# 🔒 *If I have more than one expert of a particular type.* A town holding the
	# colony's only weaver keeps him however badly somewhere else wants one.
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"furs", 1)
	_frontier(run, &"gallows_end", Vector2i(6, 6))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	_reckon(run)
	assert_eq(home.expert_count(&"furs"), 1,
		"the scholar sent away the only trapper in the colony")


func test_a_town_with_no_scholar_arranges_nothing() -> void:
	# He is the one who arranges it, so a colony that has not built him a library
	# has nobody to do it — and a town whose library burned down stops.
	var run := _run()
	var home := run.colony.in_order()[0]
	home.add_experts(&"furs", 4)
	_frontier(run, &"gallows_end", Vector2i(6, 6))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	_reckon(run)
	assert_eq(home.expert_count(&"furs"), 4,
		"experts travelled in a colony with no scholar to arrange it")


func test_the_colony_keeps_every_man_it_had() -> void:
	# 🔒 It moves a man and never makes or unmakes one, so this cannot become a
	# second source of experts beside the Provost's.
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"furs", 3)
	home.add_experts(&"ore", 2)
	_frontier(run, &"gallows_end", Vector2i(6, 6))
	_frontier(run, &"thornwick", Vector2i(2, 7))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	var before := 0
	for town in run.colony.in_order():
		before += town.expert_total()

	for month in 4:
		run.world.month = month + 1
		_reckon(run)

	var after := 0
	for town in run.colony.in_order():
		after += town.expert_total()
	assert_eq(after, before, "arranging travel made or unmade an expert")


func test_he_offers_only_when_he_has_somebody_to_spare() -> void:
	# 🔒 §3's condition, and the reason the letter cannot fire on a colony where
	# accepting it would do nothing.
	var run := _run()
	var home := _with_library(run)
	var man := _scholar(run, home)
	assert_true(man != null, "the library brought nobody")

	var context := LetterContext.new()
	context.town = home
	assert_false(ColonyConditions.i_have_experts_to_spare({}, context),
		"a town with no experts at all had somebody to spare")

	home.add_experts(&"furs", 1)
	assert_false(ColonyConditions.i_have_experts_to_spare({}, context),
		"a town with one trapper offered to send him away")

	home.add_experts(&"furs", 1)
	assert_true(ColonyConditions.i_have_experts_to_spare({}, context),
		"a town with two trappers had nobody to spare")


func test_a_resident_gets_the_town_he_lives_in() -> void:
	# 🔒 The director asked `governed_by`, which is governors only — so every
	# resident's letter was composed with no town at all, and any condition that
	# mentioned the place he lives could never be true.
	var run := _run()
	var home := _with_library(run)
	assert_same(ColonyMeasures.home_of(_scholar(run, home), run), home,
		"the scholar lives nowhere as far as his letters are concerned")
	assert_same(ColonyMeasures.home_of(_clergyman(run, _with(run, ["church"])), run), home,
		"the clergyman lives nowhere either")


# --- 🔒 It settles, and never shuffles ---------------------------------------
#
# Five towns and eight food experts must not spend the run passing men back and
# forth. Three things hold it still: a town never sends its last of a kind, an
# empty town is a one-way destination that stops being empty the moment he
# arrives, and the fallback requires strictly more than standing still.

func test_a_town_with_none_of_them_is_preferred_over_a_richer_one() -> void:
	# 🔒 **The first expert a town has is worth more than the arithmetic admits.**
	# He is the difference between a trade the town can work at all and one it
	# cannot, and `worth_of`'s diminishing returns describe the second.
	var run := _run()
	var home := run.colony.in_order()[0]
	home.add_experts(&"furs", 3)

	var bare := _frontier(run, &"gallows_end")
	var stocked := _frontier(run, &"thornwick")
	stocked.add_experts(&"furs", 1)

	assert_same(ExpertTransfer.most_useful_elsewhere(home, &"furs", _context(run)), bare,
		"he sent a second trapper to a town that had one, over a town with none")


func test_once_everybody_has_one_he_needs_a_reason_to_move_anybody() -> void:
	# 🔒 Strictly more than standing still, or the colony shuffles for ever.
	var run := _run()
	var home := run.colony.in_order()[0]
	home.add_experts(&"furs", 2)
	var other := _frontier(run, &"gallows_end")
	other.add_experts(&"furs", 1)

	# **Asserted either way**, because both answers are correct and a test that
	# skipped the null case would pass whatever the fallback did.
	var context := _context(run)
	var chosen := ExpertTransfer.most_useful_elsewhere(home, &"furs", context)
	var staying := Experts.worth_of(home, &"furs", context)
	assert_true(
		chosen == null or Experts.worth_of(chosen, &"furs", context) > staying,
		"he moved a man to a town where he was worth no more than where he was")


func test_a_colony_left_alone_stops_moving_people() -> void:
	# 🔒 **The anti-churn guarantee, asked of the driver over many months.** A
	# settled arrangement must reach a month where nobody travels and stay there.
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"food", 8)
	for id in ["gallows_end", "thornwick", "marlow", "penhale"]:
		_frontier(run, StringName(id))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	var moves_by_month := PackedInt32Array()
	for month in 10:
		run.world.month = month + 1
		var before := run.log.of_type(ExpertTransfer.EVENT_MOVED).size()
		_reckon(run)
		moves_by_month.append(
			run.log.of_type(ExpertTransfer.EVENT_MOVED).size() - before)

	assert_true(moves_by_month[0] > 0,
		"eight experts and four empty towns and nobody went anywhere")
	assert_eq(moves_by_month[moves_by_month.size() - 1], 0,
		"the colony was still shuffling experts in the tenth month: %s" % [moves_by_month])


func test_nobody_is_ever_sent_away_from_a_town_that_has_one_of_him() -> void:
	# The invariant underneath the settling: after any number of months, no town
	# has been stripped of a kind it holds.
	var run := _run()
	var home := _with_library(run)
	home.add_experts(&"food", 5)
	home.add_experts(&"ore", 3)
	for id in ["gallows_end", "thornwick"]:
		_frontier(run, StringName(id))
	run.world.values[PolicyEffects.TRAVELLING_EXPERTS_KEY] = 1.0

	for month in 8:
		run.world.month = month + 1
		_reckon(run)
		for town in run.colony.in_order():
			for kind in ["food", "ore"]:
				assert_true(town.expert_count(StringName(kind)) >= 0,
					"a town ended the month owing an expert")
	assert_true(home.expert_count(&"food") >= 1,
		"the town that started with every food expert was stripped of all of them")


# --- 🔒 A rebel town reads his regard from the other end --------------------

func test_a_slighted_priest_runs_a_better_church_once_the_town_rebels() -> void:
	# 🔒 Under the Crown he runs a good church because the Crown gives him what he
	# needs. **Once the town has flipped there is no Crown to be slighted by** —
	# so the priest who detested the PC is the one who can finally get on with it.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.MIN_LOYALTY)

	town.rebelling = false
	var under_the_crown := Building.regard_scale(
		Building.find(&"church"), town, run.contacts)
	town.rebelling = true
	var independent := Building.regard_scale(
		Building.find(&"church"), town, run.contacts)

	assert_true(under_the_crown < 1.0,
		"a slighted priest ran the church as well as a contented one")
	assert_true(independent > 1.0,
		"the town threw off the Crown and its priest went on sulking about it")


func test_a_devoted_priest_loses_heart_when_his_town_goes() -> void:
	# And the mirror: the man who loved being a Crown parish has lost everything.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.MAX_LOYALTY)

	town.rebelling = true
	assert_true(
		Building.regard_scale(Building.find(&"church"), town, run.contacts) < 1.0,
		"a priest devoted to the Crown was delighted by his town leaving it")


func test_an_indifferent_man_is_unmoved_either_way() -> void:
	# 🔒 Neutral is the hinge, so the authored figures still mean what they say
	# whichever side of the rebellion the town is on.
	var run := _run()
	var town := _with(run, ["church"])
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.NEUTRAL_LOYALTY)

	for rebelling in [false, true]:
		town.rebelling = rebelling
		assert_almost_eq(
			Building.regard_scale(Building.find(&"church"), town, run.contacts),
			1.0, 0.0001,
			"an indifferent priest's church moved when the town's allegiance did")


func test_the_inversion_reaches_what_the_town_actually_feels() -> void:
	# Asked of the safety the town reads, not of the scale — a knob nothing reads
	# is a number in a file.
	var run := _run()
	var town := _besieged(run)
	town.add_building(&"church")
	ContactRoster.house_the_residents(run)
	var priest := _clergyman(run, town)
	priest.relationship = Relationship.new(priest.id, Relationship.MIN_LOYALTY)
	var context := _context(run)

	town.rebelling = false
	var loyal := QualityOfLife.safety_of(town, context)
	town.rebelling = true
	var rebel := QualityOfLife.safety_of(town, context)

	assert_true(rebel > loyal,
		"the church comforted a rebel town no more than it comforted a Crown one")


# --- 🔒 The quartermaster: a contract that unmakes the man who grants it ----
#
# ⚠️ Placeholder at the Author's direction — what guns are *for* is a larger
# question than this contact, so expect the particulars to move. What is locked
# here is the shape, not the figures.

func _quartermaster(run: RunState, town: Town) -> Contact:
	return run.contacts.get(
		String(ContactRoster.resident_id(town, "quartermaster")), null)


func test_a_contract_is_a_price_and_instructs_no_town_to_make_anything() -> void:
	# 🔒 SPEC §11.3 locks that towns run themselves and the PC never manages them
	# directly. A contract raises what the Crown pays; **town valuation does the
	# rest**, and towns turn to muskets because muskets are suddenly worth making.
	var book := PolicyBook.new()
	book.enact(Policy.new(
		&"quartermaster_ashmere", PolicyEffects.GUN_CONTRACT, 0.0, Policy.ALL),
		EventLog.new(), 3)

	var pressing := PolicyEffects.pressure(book)
	var key := PolicyEffects.PRICE_PREFIX + "guns"
	assert_has(pressing, key, "a gun contract raises nobody's price for guns")
	assert_true(float(pressing[key]) > 0.0, "the contract was worth nothing")


func test_the_contract_reaches_what_a_town_is_paid_for_a_musket() -> void:
	# A knob nothing reads is a number in a file: it has to arrive through
	# `Valuation.crown`, the same door the war lift and a patron's barony use.
	var run := _run()
	var plain := Valuation.crown(&"guns", run.world)
	run.world.values[PolicyEffects.PRICE_PREFIX + "guns"] = PolicyEffects.CONTRACT_LIFT
	assert_true(Valuation.crown(&"guns", run.world) > plain,
		"the Crown paid a town no more for a musket under contract")


func test_it_raises_guns_and_nothing_else() -> void:
	# A contract for muskets is not a contract for grain.
	var run := _run()
	var food := Valuation.crown(&"food", run.world)
	run.world.values[PolicyEffects.PRICE_PREFIX + "guns"] = PolicyEffects.CONTRACT_LIFT
	assert_almost_eq(Valuation.crown(&"food", run.world), food, 0.0001,
		"a gun contract moved the price of food")


func test_nothing_in_the_contract_tells_a_town_to_build_anything() -> void:
	# 🔒 The guard. The moment somebody reaches for an objective or a stockpile
	# here, §11.3 is broken and a governor has stopped running his own town.
	var code := _lines_of("res://sim/crown/policy_effects.gd")
	for token in ["objective", "add_building", "town.store", "Objective."]:
		assert_false(code.contains(token),
			"the policy effects reach into a town directly: %s" % token)


# --- 🔒 He gains regard from the colony being armed -------------------------

func test_he_judges_the_crown_by_how_well_armed_the_colony_is() -> void:
	var run := _run()
	var town := _with(run, ["gunsmith"])
	var man := _quartermaster(run, town)
	assert_true(man != null, "the gunsmith brought nobody")
	assert_true(man.cares_about.has(ColonyMeasures.COLONY_IS_ARMED),
		"the quartermaster does not mind whether anybody has a musket")


func test_the_measure_counts_the_stores_and_the_companies_both() -> void:
	# 🔒 Counting only the stores would let a colony that had armed every company
	# read as defenceless; counting only the companies would let one sitting on a
	# mountain of muskets read the same. He wants the guns to exist.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.workers = 20
	town.stockpile = {}
	var bare := ColonyMeasures.armed_of(run)

	town.store(&"guns", 10.0)
	var stored := ColonyMeasures.armed_of(run)
	assert_true(stored > bare, "ten muskets in the storehouse armed nobody")

	town.take(&"guns", 10.0)
	run.companies.raise_company(
		Company.COLONIAL, 10, {"guns": 10.0}, town.id, town.at, _context(run))
	var carried := ColonyMeasures.armed_of(run)
	assert_true(carried > bare,
		"ten muskets in a company's hands armed nobody")


func test_shipping_the_guns_away_is_the_opposite_of_being_armed() -> void:
	# 🔒 **The whole of why the instrument closes itself.** No cap and no cooldown
	# are needed; this is the brake.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.workers = 20
	town.stockpile = {}
	town.store(&"guns", 30.0)
	var armed := ColonyMeasures.armed_of(run)

	town.take(&"guns", 25.0)
	assert_true(ColonyMeasures.armed_of(run) < armed,
		"the colony shipped its muskets abroad and read as well armed as ever")


func test_a_colony_that_ships_its_guns_cools_the_man_who_signed_for_them() -> void:
	# The closure, asked of his drift rather than of the measure — a measure
	# nothing reads would not cost him a thing.
	var run := _run()
	var town := _with(run, ["gunsmith"])
	town.workers = 20
	town.stockpile = {}
	var man := _quartermaster(run, town)

	town.store(&"guns", 40.0)
	var armed := LoyaltyDrift.for_contact(man, ColonyMeasures.for_contact(run, man))
	town.take(&"guns", 38.0)
	var stripped := LoyaltyDrift.for_contact(man, ColonyMeasures.for_contact(run, man))

	assert_true(stripped < armed,
		"selling the colony's muskets to the Crown did not cool the quartermaster")


func test_no_cap_or_cooldown_limits_the_contract() -> void:
	# 🔒 §3: **his loyalty is the only brake.** A cap here would be a second brake
	# and the first thing a tuner would reach for.
	var code := _lines_of("res://sim/crown/policy_effects.gd")
	var from := code.find("GUN_CONTRACT:")
	assert_true(from >= 0, "the contract has gone")
	var body := code.substr(from, 400)
	for token in ["cooldown", "months_left", "cap", "at_most", "limit"]:
		assert_false(body.contains(token),
			"something other than his regard brakes the contract: %s" % token)


# --- 🔒 His bias holds at every level ---------------------------------------

func test_the_stores_are_always_low_and_the_duty_always_high() -> void:
	var run := _run()
	var town := _with(run, ["gunsmith"])
	var man := _quartermaster(run, town)

	assert_true(man.lean_for(ColonyMeasures.COLONY_IS_ARMED) < 0.0,
		"the quartermaster is content with the stockpiles")
	assert_true(man.lean_for("tax_burden") > 0.0,
		"the quartermaster thinks the duty on iron is fair")


func test_his_alarm_is_bounded_at_every_level_of_supply() -> void:
	# 🔒 Unlike the Provost's certainty about education, **the player can check**.
	# So he must be reliably one rung out rather than hysterical, or the number
	# the letters quote and the word he uses stop agreeing.
	var run := _run()
	var town := _with(run, ["gunsmith"])
	var man := _quartermaster(run, town)
	var lean := man.lean_for(ColonyMeasures.COLONY_IS_ARMED)

	for raw in [0.0, 0.2, 0.5, 0.8, 1.0]:
		var truth := Perception.truthful_rung(ColonyMeasures.COLONY_IS_ARMED, raw, 5)
		var his := Perception.rung(
			ColonyMeasures.COLONY_IS_ARMED, raw, lean, 5, man.lean_shape)
		assert_true(truth - his <= 1,
			"he was more than one rung bleaker than the truth at %f" % raw)
		assert_true(his <= truth,
			"he reported the stockpiles as better than they are at %f" % raw)


# --- 🔒 The Diplomat cultivates the governor he lives with (#285) -----------

func _cultivating(run: RunState) -> void:
	run.world.values[PolicyEffects.CULTIVATE_GOVERNOR_KEY] = 1.0


func _reckon_cultivation(run: RunState) -> void:
	CultivationDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)


func _the_governor(run: RunState) -> Contact:
	return run.contact(run.colony.in_order()[0].governor_id)


func _house_the_diplomat_here(run: RunState) -> Town:
	var town := run.colony.in_order()[0]
	run.contact(&"diplomat").town = town.display_name
	return town


func test_the_policy_presses_a_flag_and_nothing_else() -> void:
	var book := PolicyBook.new()
	book.enact(Policy.new(
		&"diplomat", PolicyEffects.CULTIVATE_GOVERNOR, 60.0, Policy.ALL),
		EventLog.new(), 3)
	assert_has(PolicyEffects.pressure(book), PolicyEffects.CULTIVATE_GOVERNOR_KEY,
		"the Diplomat's policy presses on nothing, so nobody is ever cultivated")


func test_it_raises_the_governor_of_the_town_he_lives_in() -> void:
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)
	var before := governor.loyalty()

	_cultivating(run)
	_reckon_cultivation(run)

	assert_true(governor.loyalty() > before,
		"the Crown's man dined the governor all month and bought nothing")


func test_it_targets_the_governor_and_no_other_contact() -> void:
	# 🔒 **The only policy that buys another contact's regard**, and it buys
	# exactly one man's.
	var run := _run()
	_house_the_diplomat_here(run)
	var steward := run.contact(&"steward")
	var marshal := run.contact(&"marshal")
	var before := {"steward": steward.loyalty(), "marshal": marshal.loyalty()}

	_cultivating(run)
	_reckon_cultivation(run)

	assert_eq(steward.loyalty(), float(before["steward"]),
		"the Steward was cultivated from an ocean away")
	assert_eq(marshal.loyalty(), float(before["marshal"]),
		"the Marshal was cultivated from an ocean away")


func test_without_the_policy_nobody_is_cultivated() -> void:
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)
	var before := governor.loyalty()

	_reckon_cultivation(run)
	assert_eq(governor.loyalty(), before,
		"a governor was dined by a policy nobody was paying for")


func test_it_stops_rising_when_the_policy_lapses() -> void:
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)

	_cultivating(run)
	for month in 3:
		run.world.month = month + 1
		_reckon_cultivation(run)
	var bought := governor.loyalty()

	run.world.values[PolicyEffects.CULTIVATE_GOVERNOR_KEY] = 0.0
	run.world.month = 9
	_reckon_cultivation(run)
	assert_true(governor.loyalty() < bought,
		"the table was cleared and the governor went on feeling cultivated")


func test_what_it_buys_never_runs_away_with_itself() -> void:
	# 🔒 Bounded, because it is flattery and not friendship. A governor dined for
	# ten years likes the Crown's man; he has not forgotten what the Crown did to
	# his town.
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)
	_cultivating(run)

	for month in 60:
		run.world.month = month + 1
		_reckon_cultivation(run)
	assert_true(governor.relationship.cultivated <= PolicyEffects.CULTIVATION_CEILING,
		"five years at his table bought more than the ceiling allows")


# --- 🔒 Rehoming moves the target, and death ends it ------------------------

func test_rehoming_moves_who_is_being_cultivated() -> void:
	# 🔒 **He can only cultivate the governor he lives with**, which is what turns
	# rehoming into a decision rather than a courtesy — the PC now has a reason to
	# move him *toward* trouble.
	var run := _run()
	var home := _house_the_diplomat_here(run)
	var first := _the_governor(run)

	var other := Town.new(&"gallows_end", "Gallows End", Vector2i(6, 6))
	other.workers = 10
	run.colony.add(other)
	var second := Governor.generate(other, run.streams)
	other.governor_id = second.id
	run.add_contact(second)

	_cultivating(run)
	_reckon_cultivation(run)
	assert_true(first.relationship.cultivated > 0.0, "nobody was cultivated at all")

	run.contact(&"diplomat").town = other.display_name
	run.world.month = 4
	_reckon_cultivation(run)

	assert_true(second.relationship.cultivated > 0.0,
		"he moved towns and cultivated nobody there")
	assert_eq(first.relationship.cultivated, 0.0,
		"the governor he left behind went on feeling dined")
	assert_true(home != other)


func test_his_death_ends_it_and_what_he_bought_does_not_persist() -> void:
	# 🔒 **A Diplomat kept in a rebellious town is one the PC may lose, and the
	# loyalty he was buying dies with him.**
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)
	_cultivating(run)

	for month in 4:
		run.world.month = month + 1
		_reckon_cultivation(run)
	var dined := governor.loyalty()
	assert_true(governor.relationship.cultivated > 0.0, "nobody was cultivated")

	run.contact(&"diplomat").is_dead = true
	run.world.month = 9
	_reckon_cultivation(run)

	assert_eq(governor.relationship.cultivated, 0.0,
		"the Crown's man was killed and the governor went on liking the Crown for it")
	assert_true(governor.loyalty() < dined,
		"what the Diplomat bought outlived him")


func test_what_the_governor_himself_felt_is_untouched() -> void:
	# 🔒 It is held apart from the man's own regard, which is the only reason it
	# can be taken away again without unpicking anything he actually feels.
	var run := _run()
	_house_the_diplomat_here(run)
	var governor := _the_governor(run)
	var his_own := governor.relationship.loyalty
	_cultivating(run)

	for month in 3:
		run.world.month = month + 1
		_reckon_cultivation(run)

	assert_eq(governor.relationship.loyalty, his_own,
		"cultivating a man changed what he himself thought of the Crown")
	assert_true(governor.loyalty() > his_own,
		"the cultivated figure never reached anybody reading his regard")


func test_it_survives_the_save() -> void:
	# Ironman: a run that forgot what was being bought would quietly become a
	# different run.
	var relationship := Relationship.new(&"gov", 40.0)
	relationship.cultivated = 7.5
	assert_almost_eq(
		Relationship.from_dict(relationship.to_dict()).cultivated, 7.5, 0.0001,
		"what the Diplomat bought did not survive the save")
