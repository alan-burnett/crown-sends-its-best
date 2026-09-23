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
