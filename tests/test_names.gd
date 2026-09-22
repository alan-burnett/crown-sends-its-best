extends TestCase

## Names, bags and the letterhead (#304, `docs/mechanics/names.md`).
##
## 🔒 **The first word is always the role.** No *Captain*, no *Lord*, no
## *Father*. It is there to be scanned, not to be flavour: an experienced player
## should read the stack and know what came in without opening anything, and a
## desk of honorifics tells him nothing.
##
## 🔒 **A bag is a register, and roles map onto it.** Not one bag per role —
## patrons and Crown commanders are aristocrats, governors and colony commanders
## and the institutional contacts are colonists.
##
## 🔒 **The qualifier is mutable state on the contact**, because a commander is
## one role with three allegiances and a town commander whose town revolts
## becomes *of the independent nation* — the same object serving somebody else.

const SEED: int = 8140

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
	NameBags.reset()
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
	NameBags.reset()
	content.free()


func _man(role: StringName, name: String, town: String = "") -> Contact:
	var contact := Contact.new(&"him", {})
	contact.role = role
	contact.display_name = name
	contact.qualifier = Letterhead.qualifier_for(role)
	contact.town = town
	return contact


# --- 🔒 The letterhead ------------------------------------------------------

func test_the_first_word_is_the_role() -> void:
	assert_eq(Letterhead.of(_man(Contact.ROLE_GOVERNOR, "Don Johnson", "Morrisville")),
		"Governor Don Johnson of Morrisville")
	assert_eq(Letterhead.of(_man(Contact.ROLE_COMMANDER, "Ames Harker", "Ashmere")),
		"Commander Ames Harker of the town of Ashmere")
	assert_eq(Letterhead.of(_man(Contact.ROLE_PATRON, "Mingle Welkington")),
		"Patron Mingle Welkington")


func test_a_rival_is_his_name_and_nothing_else() -> void:
	# 🔒 **His name is the whole letterhead.** No role word, because *Rival* is a
	# game term and no man was ever called one — and a rival's hand-written name
	# already carries his title, so the fiction has done the job the role word was
	# hired for.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for duke in RivalDuke.all_in(run):
		assert_eq(Letterhead.of(duke), duke.display_name,
			"a rival was given a role word or a qualifier")


func test_the_officers_keep_their_word_because_their_names_do_not_announce_them() -> void:
	# 🔒 The rival exception does not extend to them. *Master Corvyn Thrale* does
	# not say **Steward**, so he keeps his word. The test is whether the name
	# itself announces the man, and only a rival's does.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for id in ["chancellor", "steward", "marshal", "provost"]:
		var officer := run.contact(StringName(id))
		assert_true(Letterhead.of(officer).begins_with(officer.role_word),
			"%s does not lead with his office" % id)
		assert_false(officer.role_word.is_empty(),
			"%s shares a role with three other offices and has no word of his own" % id)


func test_four_offices_share_one_role_so_the_word_is_a_field() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var words: Dictionary = {}
	for id in ["chancellor", "steward", "marshal", "provost"]:
		var officer := run.contact(StringName(id))
		assert_eq(officer.role, Contact.ROLE_CROWN_OFFICER)
		words[officer.role_word] = true
	assert_eq(words.size(), 4,
		"the four Crown officers do not have four distinct words: %s" % words.keys())


func test_the_letterhead_never_reads_the_title_field() -> void:
	# 🔒 §2: `title` holds flavour like *Steward of the Revenue*, and the
	# letterhead must not use it.
	var contact := _man(Contact.ROLE_GOVERNOR, "Silas Pike", "Ashmere")
	contact.title = "Perpetual Grand Marshal of Everything"
	assert_false(Letterhead.of(contact).contains("Perpetual"),
		"the letterhead read the title field")


func test_a_qualifier_with_no_town_is_dropped_rather_than_left_gaping() -> void:
	assert_eq(Letterhead.of(_man(Contact.ROLE_GOVERNOR, "Silas Pike")),
		"Governor Silas Pike",
		"a governor with no town read as 'of' and then nothing")


# --- 🔒 The qualifier moves with the man ------------------------------------

func test_the_diplomats_letterhead_moves_when_he_is_rehomed() -> void:
	# SPEC §8.1: he lives in a town and asks to be moved when it turns dangerous.
	# A player who notices *of Ashmere* become *of Kettleburn* has been told
	# something real before he reads a word — and nothing special-cases him.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var diplomat := run.contact(&"diplomat")
	assert_false(diplomat.town.is_empty(), "the Diplomat was never housed")
	assert_true(Letterhead.of(diplomat).ends_with(" of %s" % diplomat.town),
		"the Diplomat's letterhead does not say where he lives")

	diplomat.town = "Kettleburn"
	assert_true(Letterhead.of(diplomat).ends_with(" of Kettleburn"),
		"rehoming him did not move his letterhead")


func test_a_commander_who_turns_serves_a_nation() -> void:
	# 🔒 §2: same contact, same company, different master. The thing that turns
	# him rewrites the field, and nothing else in the game needs to know what a
	# rebellion is.
	var commander := _man(Contact.ROLE_COMMANDER, "Ames Harker", "Ashmere")
	assert_eq(Letterhead.of(commander), "Commander Ames Harker of the town of Ashmere")

	commander.qualifier = Letterhead.REBEL_COMMANDER
	assert_eq(Letterhead.of(commander), "Commander Ames Harker of the independent nation",
		"a commander who turned was still the town's man")

	commander.qualifier = Letterhead.CROWN_COMMANDER
	assert_eq(Letterhead.of(commander), "Commander Ames Harker of the Crown's service")


func test_the_qualifier_is_one_field_and_adding_a_role_needs_no_code() -> void:
	# The acceptance. A role nobody has written gets an empty qualifier rather
	# than an error, and a role that wants one says so in the table.
	assert_eq(Letterhead.qualifier_for(&"a_role_nobody_has_written"), "")
	for role in [Contact.ROLE_GOVERNOR, Contact.ROLE_INSTITUTIONAL, Contact.ROLE_DIPLOMAT]:
		assert_true(Letterhead.qualifier_for(role).contains(Letterhead.TOWN_SLOT),
			"%s does not name where he lives" % role)


func test_a_qualifier_survives_the_save() -> void:
	var commander := _man(Contact.ROLE_COMMANDER, "Ames Harker", "Ashmere")
	commander.qualifier = Letterhead.REBEL_COMMANDER
	commander.role_word = "Commander"
	var restored := Contact.from_data(commander.to_dict())
	assert_eq(restored.qualifier, Letterhead.REBEL_COMMANDER,
		"a commander who turned was the town's man again after a reload")
	assert_eq(restored.role_word, "Commander")


# --- 🔒 Bags are registers --------------------------------------------------

func test_the_three_bags_exist_and_are_large_enough() -> void:
	for bag in NameBags.ALL:
		assert_true(NameBags.has(bag), "there is no %s bag" % bag)
	assert_true(NameBags.entries(NameBags.COLONISTS, "given").size() >= 12)
	assert_true(NameBags.entries(NameBags.COLONISTS, "family").size() >= 12)
	assert_true(NameBags.entries(NameBags.TOWNS, "names").size() >= 12)


func test_two_roles_share_each_bag() -> void:
	# 🔒 §3: **not one bag per role.** A company is given to the same sort of man
	# either way — the Marshal's commander from the pool a patron comes from, a
	# colonial company to one of the well-to-do colonists a governor comes from.
	assert_eq(NameBags.bag_for(Contact.ROLE_PATRON), NameBags.ARISTOCRATS)
	assert_eq(NameBags.bag_for(Contact.ROLE_COMMANDER, true), NameBags.ARISTOCRATS)
	assert_eq(NameBags.bag_for(Contact.ROLE_GOVERNOR), NameBags.COLONISTS)
	assert_eq(NameBags.bag_for(Contact.ROLE_COMMANDER, false), NameBags.COLONISTS)
	assert_eq(NameBags.bag_for(Contact.ROLE_INSTITUTIONAL), NameBags.COLONISTS)


func test_the_fixed_cast_draws_from_nothing() -> void:
	# The five Crown officers and the three rival dukes are hand-written.
	assert_eq(NameBags.bag_for(Contact.ROLE_CROWN_OFFICER), "")
	assert_eq(NameBags.bag_for(Contact.ROLE_RIVAL), "")
	assert_eq(NameBags.bag_for(Contact.ROLE_DIPLOMAT), "")


func test_a_bag_holds_given_and_family_and_no_titles() -> void:
	# 🔒 §3: twenty of each is four hundred men, and there are no titles because
	# the letterhead's first word is the role.
	for bag in [NameBags.ARISTOCRATS, NameBags.COLONISTS]:
		for key in ["given", "family"]:
			for entry in NameBags.entries(bag, key):
				var name := String(entry)
				assert_false(name.contains(" "),
					"'%s' in %s.%s is more than one word, so it is a whole name" % [name, bag, key])
				for title in ["Lord", "Sir", "Master", "Mr", "Dr", "Captain", "Father"]:
					assert_ne(name, title, "%s holds the title '%s'" % [bag, title])


# --- 🔒 The same seed gives the same men and towns --------------------------

func test_a_name_comes_from_the_subjects_own_stream() -> void:
	# §5: the same seed gives the same men **whatever else happens in the run**,
	# and naming somebody never shifts another system's rolls.
	var first := RngStreams.new(SEED)
	var second := RngStreams.new(SEED)
	# The second draws something else first, which must not move the answer.
	second.stream("sim").randi()
	second.stream("mapgen").randi()
	assert_eq(
		NameBags.person(NameBags.COLONISTS, first.contact_stream("governor_x")),
		NameBags.person(NameBags.COLONISTS, second.contact_stream("governor_x")),
		"a governor's name moved because something else rolled a die")


func test_a_town_takes_its_own_stream_and_not_a_contacts() -> void:
	# 🔒 A prefix of its own: a town called `ashmere` and a contact called
	# `ashmere` must not draw the same numbers.
	var streams := RngStreams.new(SEED)
	assert_ne(streams.place_stream("ashmere").seed,
		streams.contact_stream("ashmere").seed,
		"a town and a contact of the same name share a stream")


func test_the_same_seed_founds_the_same_town() -> void:
	var names: Array = []
	for pass_index in 2:
		var run := RunState.new_run(SEED)
		names.append(run.colony.in_order()[0].display_name)
	assert_eq(names[0], names[1], "two identical runs founded differently named towns")
	assert_false(String(names[0]).is_empty(), "the first town has no name")


func test_two_live_towns_never_share_a_name() -> void:
	# §5: a redraw rather than a property the bags must guarantee.
	var streams := RngStreams.new(SEED)
	var taken := PackedStringArray()
	for step in 8:
		var drawn := NameBags.place(streams.place_stream("town_%d" % step), taken)
		assert_false(taken.has(drawn), "'%s' was founded twice" % drawn)
		taken.append(drawn)


func test_a_generated_governor_is_named_from_the_bag() -> void:
	var streams := RngStreams.new(SEED)
	var drawn := NameBags.person(NameBags.COLONISTS, streams.contact_stream("governor_x"))
	assert_false(drawn.is_empty(), "a governor drew no name at all")
	var parts := drawn.split(" ")
	assert_eq(parts.size(), 2, "a name is a given and a family name joined")
	assert_true(NameBags.entries(NameBags.COLONISTS, "given").has(parts[0]))
	assert_true(NameBags.entries(NameBags.COLONISTS, "family").has(parts[1]))


func test_a_missing_bag_is_empty_rather_than_a_crash() -> void:
	NameBags.reset()
	assert_eq(NameBags.person(NameBags.COLONISTS, RngStreams.new(SEED).stream("sim")), "")
	assert_eq(NameBags.place(RngStreams.new(SEED).stream("sim")), "")


# --- 🔒 The validator covers them -------------------------------------------

func test_the_shipped_bags_pass() -> void:
	var validator := ContentValidator.new()
	validator.check_name_bags(content)
	var said: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		said.append("%s %s" % [problem.path, problem.message])
	assert_true(validator.ok(), " | ".join(said))


func test_a_missing_bag_is_caught() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.collection(NameBags.COLLECTION).erase(NameBags.TOWNS)
	var validator := ContentValidator.new()
	validator.check_name_bags(db)
	assert_false(validator.ok(), "a missing bag passed, so towns would be nameless")
	db.free()


func test_a_bag_too_small_for_a_long_run_is_caught() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.collection(NameBags.COLLECTION)[NameBags.COLONISTS] = {
		"id": NameBags.COLONISTS, "given": ["Abel"], "family": ["Barrow"],
	}
	var validator := ContentValidator.new()
	validator.check_name_bags(db)
	assert_false(validator.ok(), "one name in a bag passed as enough for a long run")
	db.free()
