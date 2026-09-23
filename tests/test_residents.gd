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
