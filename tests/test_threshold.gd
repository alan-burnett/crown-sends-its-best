extends TestCase

## Thresholds: role, redundancy, and why the third clergyman is quieter (#255,
## SPEC §9.6; `docs/mechanics/the-director.md` §4, §5).
##
## **Pressure is about the world. The threshold is about the man.**
##
## 🔒 **Redundancy is the only volume control that scales.** Your first church's
## man writes freely; the third church's clergyman needs a substantially bigger
## problem, because he knows the Crown hears from clergy already. It is what
## stops a wide colony producing a desk that grows with its towns.
##
## 🔒 **Ranked by arrival, not by id.** The man who was already writing keeps his
## low bar.

const SEED: int = 1649

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
	Threshold.reset()
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
	Threshold.reset()
	content.free()


## A man of a role, as ready to write as anybody.
func _man(id: StringName, role: StringName, since: int = 0) -> Contact:
	var contact := Contact.new(id)
	contact.role = role
	contact.known_since = since
	contact.relationship = Relationship.new(id, 55.0)
	return contact


## A roster of men of one role, arriving in order.
func _roster(role: StringName, count: int) -> Dictionary:
	var out: Dictionary = {}
	for index in count:
		var contact := _man(StringName("man_%d" % index), role, index)
		out[String(contact.id)] = contact
	return out


# --- 🔒 A base per role, in data --------------------------------------------

func test_the_bases_are_authored_rather_than_written_in_code() -> void:
	assert_true(content.has_record(Threshold.COLLECTION, Threshold.RECORD),
		"there is no threshold data to load")
	var record: Dictionary = content.record(Threshold.COLLECTION, Threshold.RECORD)
	assert_false(record.get("base", {}).is_empty(), "no role has a base")


func test_a_governor_reports_often_and_the_chancellor_almost_never() -> void:
	# §4, in as many words. The figures are tuning; the ordering is the design.
	assert_true(Threshold.base_for(Contact.ROLE_GOVERNOR)
			< Threshold.base_for(Contact.ROLE_CROWN_OFFICER),
		"a Crown officer writes as readily as the man on the spot")
	assert_true(Threshold.base_for(Contact.ROLE_CROWN_OFFICER)
			< Threshold.base_for(Contact.ROLE_RIVAL),
		"a foreign duke writes as readily as the Crown's own officers")


func test_a_role_nobody_authored_still_has_a_bar() -> void:
	assert_true(Threshold.base_for(&"a_role_from_a_later_milestone") > 0.0,
		"a contact of an unknown role could write about anything at all")


# --- 🔒 Redundancy ----------------------------------------------------------

func test_the_first_man_of_a_role_is_unaffected() -> void:
	assert_almost_eq(Threshold.redundancy_at(0), 1.0, 0.0001,
		"the first man of a role already has a raised bar")
	var alone := Threshold.for_contact(_man(&"him", Contact.ROLE_INSTITUTIONAL), 0)
	var crowd := _roster(Contact.ROLE_INSTITUTIONAL, 5)
	var ranks := Threshold.ranks_in(crowd)
	assert_almost_eq(
		Threshold.for_contact(crowd["man_0"], int(ranks["man_0"])), alone, 0.0001,
		"the man who was here first was quieted by the men who came after")


func test_the_third_clergyman_needs_a_bigger_problem() -> void:
	var crowd := _roster(Contact.ROLE_INSTITUTIONAL, 3)
	var ranks := Threshold.ranks_in(crowd)
	var bars: Array = []
	for index in 3:
		bars.append(Threshold.for_contact(
			crowd["man_%d" % index], int(ranks["man_%d" % index])))

	assert_true(float(bars[1]) > float(bars[0]) + 0.0001,
		"the second man of a role writes as freely as the first")
	assert_true(float(bars[2]) > float(bars[1]) + 0.0001,
		"the third man of a role writes as freely as the second")


func test_the_bar_stops_rising_rather_than_running_away() -> void:
	# A colony can hold a great many men of one role. Without a ceiling the
	# twentieth would need a pressure no world could produce, which is a contact
	# who exists and is silent for ever.
	var ceiling := Threshold.redundancy_at(400)
	assert_true(ceiling < 10.0, "the bar rises without limit")
	assert_almost_eq(Threshold.redundancy_at(400), Threshold.redundancy_at(40), 0.0001,
		"the ceiling is not a ceiling")


func test_a_crowd_of_one_role_does_not_write_a_crowd_of_letters() -> void:
	# 🔒 The acceptance, asked of the mechanism. **A nine-man roster clears the
	# bar no more often than a three-man one**, which is what stops a wide colony
	# producing a desk that grows with its towns.
	#
	# Asked of thresholds rather than of the post, because a letter names one
	# sender id — only Ashmere's governor has letters authored for him, so eight
	# more governors write nothing whatever their bars say. M8 authors the set;
	# the volume control has to be right before it does.
	var pressure := 34.0
	var wrote: Dictionary = {}
	for count in [1, 3, 9]:
		var crowd := _roster(Contact.ROLE_INSTITUTIONAL, count)
		var ranks := Threshold.ranks_in(crowd)
		var writers := 0
		for id in crowd:
			if pressure >= Threshold.for_contact(crowd[id], int(ranks[id])):
				writers += 1
		wrote[count] = writers

	assert_true(int(wrote[1]) >= 1, "not even the first man of a role would write")
	assert_true(int(wrote[9]) < int(wrote[1]) * 9,
		"nine men of a role wrote nine times as often as one")
	assert_true(int(wrote[9]) <= int(wrote[3]) + 1,
		"the desk still grows with the roster: %d wrote of nine against %d of three"
			% [wrote[9], wrote[3]])


# --- 🔒 Ranked by arrival ---------------------------------------------------

func test_a_man_who_arrives_later_takes_the_higher_bar() -> void:
	# Ranking by id would let a governor founded in year six whose name sorts
	# early quietly raise the bar of one who has been writing since month one.
	var roster: Dictionary = {}
	var late := _man(&"aaa_arrived_last", Contact.ROLE_GOVERNOR, 40)
	var early := _man(&"zzz_arrived_first", Contact.ROLE_GOVERNOR, 1)
	roster[String(late.id)] = late
	roster[String(early.id)] = early

	var ranks := Threshold.ranks_in(roster)
	assert_eq(int(ranks[String(early.id)]), 0,
		"the man who has been writing since month one was ranked behind a newcomer")
	assert_eq(int(ranks[String(late.id)]), 1)


func test_a_contact_records_when_he_joined() -> void:
	var run := RunState.new_run(SEED)
	run.world.month = 17
	var joined := run.add_contact(_man(&"newcomer", Contact.ROLE_GOVERNOR, 0))
	assert_eq(joined.known_since, 17, "a contact joined the roster undated")


func test_the_crowns_offices_do_not_crowd_one_another() -> void:
	# 🔒 They share a role and they are four distinct offices doing different
	# work: the Steward's returns are not the Marshal's supplies.
	#
	# Ranking them against each other quieted three of the four on the arbitrary
	# grounds of how their names sort — and the one it silenced was the Marshal,
	# whose whole function is to ask.
	assert_false(Threshold.crowds(Contact.ROLE_CROWN_OFFICER),
		"a fourth Crown officer is treated as a third clergyman")
	assert_true(Threshold.crowds(Contact.ROLE_GOVERNOR),
		"a tenth town's governor writes as freely as the first")
	assert_true(Threshold.crowds(Contact.ROLE_INSTITUTIONAL),
		"a third church's clergyman writes as freely as the first")

	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var ranks := Threshold.ranks_in(run.contacts)
	for id in ["steward", "chancellor", "marshal", "provost"]:
		if run.contact(StringName(id)) == null:
			continue
		assert_eq(int(ranks.get(id, 0)), 0,
			"%s was ranked behind another of the Crown's offices" % id)


func test_men_of_different_roles_do_not_crowd_one_another() -> void:
	var roster: Dictionary = {}
	for index in 4:
		var officer := _man(StringName("officer_%d" % index), Contact.ROLE_CROWN_OFFICER, index)
		roster[String(officer.id)] = officer
	var governor := _man(&"governor_one", Contact.ROLE_GOVERNOR, 9)
	roster[String(governor.id)] = governor

	assert_eq(int(Threshold.ranks_in(roster)[String(governor.id)]), 0,
		"a governor was quieted by the Crown's officers, who do not share his work")


# --- 🔒 Personality -----------------------------------------------------------

func test_a_readier_man_writes_about_less() -> void:
	var eager := _man(&"eager", Contact.ROLE_GOVERNOR)
	eager.writes_readily = Contact.WRITES_READILY_MAX
	var reticent := _man(&"reticent", Contact.ROLE_GOVERNOR)
	reticent.writes_readily = Contact.WRITES_READILY_MIN

	assert_true(Threshold.for_contact(eager, 0) < Threshold.for_contact(reticent, 0),
		"a man apt to write needs as much provocation as one who keeps his counsel")


func test_two_men_of_one_role_in_one_run_differ() -> void:
	# 🔒 The acceptance, and most of why two clergymen in two runs feel
	# different. Generated men, not hand-set ones.
	var bars: Dictionary = {}
	for index in 8:
		var town := Town.new(StringName("t%d" % index), "T", Vector2i(4, 4))
		town.governor_id = StringName("gov_%d" % index)
		var governor := Governor.generate(town, RngStreams.new(SEED + index))
		bars["%.3f" % Threshold.for_contact(governor, 0)] = true
	assert_true(bars.size() > 1,
		"every governor in the game needs exactly the same provocation to write")


func test_an_importunate_man_is_a_low_bar_and_nothing_else() -> void:
	# §4: an importunate patron is exactly a very low threshold and needs no
	# mechanism of its own.
	var importunate := _man(&"patron", Contact.ROLE_PATRON)
	importunate.writes_readily = Contact.WRITES_READILY_MAX
	assert_true(Threshold.for_contact(importunate, 0)
			< Threshold.base_for(Contact.ROLE_PATRON),
		"an importunate man needs a mechanism, which §4 says he does not")


func test_a_temperament_survives_a_save() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var before := run.contact(run.colony.in_order()[0].governor_id)

	var after := RunState.from_dict(run.to_dict()).contact(before.id)
	assert_almost_eq(after.writes_readily, before.writes_readily, 0.0001,
		"a reload made him a different correspondent")
	assert_eq(after.known_since, before.known_since,
		"a reload forgot when he joined, which is what redundancy ranks by")
