extends TestCase

## Rival dukes: contacts with inverted values, and the four bands (#209,
## SPEC §12.4; `docs/mechanics/rival-pressure.md` §1, §2, §3).
##
## 🔒 **A duke is an ordinary contact.** Same loyalty, same deeds, same drift.
## The inversion is a measure with a name — he cares about the colony *not*
## having got far — and there is no second scalar and no bespoke machinery.
##
## 🔒 **Prospering is what he can see**: towns, population and territory. Never
## `net_position`, or the same number would drive Crown Standing, prestige and
## the rivals, and the PC would be punished three ways for one thing.
##
## 🔒 **Minimum is a latch**, built the way a tribe's conclusion is built.
##
## 🔒 **And there is no trade with a rival, ever.**

const SEED: int = 2711

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	return ColonyContext.new(run.world, run.log, run.streams, run.map)


# --- 🔒 Three of them, and they are ordinary contacts -----------------------

func test_three_dukes_exist_as_ordinary_contacts() -> void:
	var run := _run()
	var dukes := RivalDuke.all_in(run)
	# **Three, written out.** §12.4 says three empires; comparing against the
	# constant would assert that it equals itself.
	assert_eq(dukes.size(), 3, "there are not three rival empires")
	for duke in dukes:
		assert_true(duke.relationship != null, "%s has no loyalty" % duke.id)
		assert_true(duke.relationship.loyalty >= Relationship.MIN_LOYALTY
				and duke.relationship.loyalty <= Relationship.MAX_LOYALTY,
			"%s's loyalty is off the ordinary scale" % duke.id)


func test_a_duke_has_no_machinery_a_governor_does_not() -> void:
	# 🔒 "Almost nothing here is new machinery." A duke who had grown a field of
	# his own would be a second scalar, which §1 forbids in as many words.
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	var governor := run.contact(run.colony.in_order()[0].governor_id)

	var his: Dictionary = {}
	for entry in duke.get_property_list():
		his[String(entry["name"])] = true
	for entry in governor.get_property_list():
		his.erase(String(entry["name"]))
	assert_true(his.is_empty(),
		"a duke carries fields a governor does not: %s" % ", ".join(his.keys()))


func test_each_empire_has_exactly_one_man_the_pc_can_write_to() -> void:
	# 🔒 **One duke per rival** — the PC's only contact with that empire.
	var run := _run()
	var titles: Dictionary = {}
	for duke in RivalDuke.all_in(run):
		assert_false(titles.has(duke.title),
			"two men write to the PC for the same empire: %s" % duke.title)
		titles[duke.title] = true


# --- 🔒 Prospering drags him down, and it is not the Crown's ledger ---------

func test_a_prospering_colony_cools_a_duke() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]

	var small := ColonyMeasures.for_contact(run, duke)
	var when_small := LoyaltyDrift.for_contact(duke, small)

	# The same colony, further along.
	var big := small.duplicate()
	big[ColonyMeasures.COLONY_REACH] = 1.0
	big[ColonyMeasures.COLONY_IS_NO_THREAT] = 0.0
	var when_big := LoyaltyDrift.for_contact(duke, big)

	assert_true(when_big < when_small - 0.0001,
		"a duke was no cooler for the colony having doubled in size")


func test_the_same_growth_does_not_cool_a_governor() -> void:
	# The inversion, shown rather than described: one world, two men, opposite
	# readings, and no code anywhere asking which kind of man this is.
	var run := _run()
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	var duke: Contact = RivalDuke.all_in(run)[0]

	var big := ColonyMeasures.for_contact(run, governor)
	big[ColonyMeasures.COLONY_REACH] = 1.0
	big[ColonyMeasures.COLONY_IS_NO_THREAT] = 0.0

	assert_true(LoyaltyDrift.for_contact(duke, big)
			< LoyaltyDrift.for_contact(governor, big),
		"a duke and a governor read a growing colony the same way")


func test_nothing_a_duke_reads_is_the_crowns_ledger() -> void:
	# 🔒 §2, and the lock. If rival aggression read net position, one number
	# would drive Crown Standing, prestige and the rivals at once.
	var run := _run()
	for duke in RivalDuke.all_in(run):
		for topic in duke.cares_about:
			assert_false(String(topic) == WorldValues.REVENUE,
				"%s judges the PC by the Crown's returns" % duke.id)
			assert_false(String(topic).contains("net_position"),
				"%s reads the Crown's ledger" % duke.id)


func test_reach_is_towns_and_people_and_ground() -> void:
	var run := _run()
	var small := ColonyMeasures.reach_of(run)

	run.colony.in_order()[0].workers += 600
	assert_true(ColonyMeasures.reach_of(run) > small + 0.0001,
		"six hundred more colonists did not make the colony any bigger")

	var with_people := ColonyMeasures.reach_of(run)
	run.colony.add(Town.new(&"second", "Second", Vector2i(12, 12)))
	assert_true(ColonyMeasures.reach_of(run) > with_people + 0.0001,
		"a second town did not make the colony any wider")


func test_the_two_readings_of_reach_cannot_disagree() -> void:
	var run := _run()
	var measures := ColonyMeasures.for_contact(run, RivalDuke.all_in(run)[0])
	assert_almost_eq(
		float(measures[ColonyMeasures.COLONY_REACH])
			+ float(measures[ColonyMeasures.COLONY_IS_NO_THREAT]),
		1.0, 0.0001,
		"how far the colony has got and whether it is still small disagree")


# --- 🔒 The four bands, off the one value -----------------------------------

func test_the_bands_are_a_function_of_loyalty_and_nothing_else() -> void:
	assert_eq(RivalDuke.band_of(90.0), RivalDuke.HIGH)
	assert_eq(RivalDuke.band_of(45.0), RivalDuke.MEDIUM)
	assert_eq(RivalDuke.band_of(20.0), RivalDuke.LOW)
	assert_eq(RivalDuke.band_of(2.0), RivalDuke.MINIMUM)

	# And they are ordered all the way down, with no gap and no overlap.
	var seen: Array = []
	for step in 101:
		var band := RivalDuke.band_of(float(step))
		if seen.is_empty() or seen[seen.size() - 1] != band:
			seen.append(band)
	assert_eq(seen, [RivalDuke.MINIMUM, RivalDuke.LOW, RivalDuke.MEDIUM, RivalDuke.HIGH],
		"the bands do not run once from the bottom to the top")


func test_no_band_is_stored_anywhere() -> void:
	# 🔒 **No second state machine.** A stored band would be a second place the
	# truth lived, and the two would eventually disagree.
	var run := _run()
	for duke in RivalDuke.all_in(run):
		for entry in duke.get_property_list():
			assert_false(String(entry["name"]).contains("band"),
				"%s stores a band instead of deriving it" % duke.id)
	assert_false(run.rivals.to_dict().has("bands"), "a save recorded a band")


func test_what_each_band_does() -> void:
	assert_false(RivalDuke.denies_tiles(RivalDuke.HIGH))
	assert_false(RivalDuke.denies_tiles(RivalDuke.MEDIUM))
	assert_true(RivalDuke.denies_tiles(RivalDuke.LOW),
		"a duke who has stopped being paid left the colony's ground alone")
	assert_true(RivalDuke.denies_tiles(RivalDuke.MINIMUM))

	assert_false(RivalDuke.makes_war(RivalDuke.LOW),
		"a duke short of his cut made open war on towns")
	assert_true(RivalDuke.makes_war(RivalDuke.MINIMUM))

	assert_true(RivalDuke.forgives_a_missed_payment(RivalDuke.HIGH))
	assert_false(RivalDuke.forgives_a_missed_payment(RivalDuke.MEDIUM),
		"a duke on medium terms let a missed payment go")
	assert_true(RivalDuke.tribute_multiple(RivalDuke.MEDIUM)
			> RivalDuke.tribute_multiple(RivalDuke.HIGH),
		"he asks no more of a man he is less pleased with")


# --- 🔒 Minimum is a latch ---------------------------------------------------

func test_a_duke_at_the_bottom_stays_there_however_much_he_is_paid() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = 2.0
	run.rivals.reached_minimum(duke, _context(run))

	duke.relationship.loyalty = 100.0
	assert_eq(RivalDuke.band_for(duke, run.rivals), RivalDuke.MINIMUM,
		"a duke who had gone to war was bought back with a shipment")
	assert_true(RivalDuke.makes_war(RivalDuke.band_for(duke, run.rivals)),
		"paying a man at the bottom stopped the war")


func test_there_is_no_way_out_of_the_book() -> void:
	# 🔒 Ids go in and never come out. A dev who wanted a duke talked back from
	# the bottom would have to add the method and argue with this.
	# Its own methods, not the ones every `RefCounted` in Godot carries.
	var inherited: Dictionary = {}
	for entry in RefCounted.new().get_method_list():
		inherited[String(entry["name"])] = true

	var found := false
	for entry in RivalBook.new().get_method_list():
		var name := String(entry["name"])
		if name.begins_with("_") or inherited.has(name):
			continue
		for way_out in ["release", "clear", "forgive", "remove", "erase", "reset"]:
			if name.contains(way_out):
				found = true
	assert_false(found,
		"RivalBook grew a way out, so the point of no return has a way back")

	# And the only writer takes a duke and sets it true. There is no overload
	# that could take `false`.
	var book := RivalBook.new()
	var duke := Contact.new(&"rival_test")
	duke.relationship = Relationship.new(&"rival_test", 1.0)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	assert_true(book.reached_minimum(duke, context), "the fixture did nothing")
	assert_false(book.reached_minimum(duke, context),
		"a duke reached the bottom a second time, which means it is not a latch")
	assert_true(book.is_at_minimum(duke.id))


func test_reaching_the_bottom_is_announced_once_and_carries_no_figure() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = 1.0

	var driver := RivalDriver.new(run)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)

	var latched: Array = run.log.of_type(RivalBook.EVENT_LATCHED)
	assert_eq(latched.size(), 1, "a duke reached the bottom twice, or in silence")
	assert_false(latched[0].payload.has("loyalty"),
		"the payload carries the figure, which a letter could then render")


func test_a_duke_who_is_merely_cold_is_not_latched() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = RivalDuke.LOW_AT + 1.0

	RivalDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_false(run.rivals.is_at_minimum(duke.id),
		"a duke who was merely short of his cut was written off for the run")


func test_the_latch_survives_a_save() -> void:
	var run := _run()
	var duke: Contact = RivalDuke.all_in(run)[0]
	duke.relationship.loyalty = 1.0
	run.rivals.reached_minimum(duke, _context(run))

	var restored := RunState.from_dict(run.to_dict())
	assert_true(restored.rivals.is_at_minimum(duke.id),
		"a reload talked a duke back from a point of no return")


# --- 🔒 What a duke never does ----------------------------------------------

func test_no_letter_from_a_duke_offers_the_pc_anything() -> void:
	# 🔒 **There is no trade with a rival, ever**, and he never asks for help
	# against another rival or the natives. Asserted against the content, which
	# is where such a thing would be written.
	var run := _run()
	var dukes: Dictionary = {}
	for duke in RivalDuke.all_in(run):
		dukes[String(duke.id)] = true

	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", String(id)))
		if not dukes.has(String(letter.sender)):
			continue
		for step in letter.steps():
			for option in step.get(LetterSchema.KEY_OPTIONS, []):
				var effect: Dictionary = option.get("effect", {})
				for name in effect:
					assert_true(String(name) in ["pay_tribute", "refuse"],
						"%s lets a duke and the PC do '%s' to one another"
							% [letter.id, name])


func test_a_duke_asks_and_never_offers() -> void:
	var run := _run()
	var dukes: Dictionary = {}
	for duke in RivalDuke.all_in(run):
		dukes[String(duke.id)] = true

	var asked := 0
	for id in content.ids("letters"):
		var record := content.record("letters", String(id))
		if not dukes.has(String(record.get("sender", ""))):
			continue
		asked += 1
		assert_eq(String(record.get("type", "")), "demand",
			"%s is a rival writing something other than a demand" % id)
	assert_eq(asked, 3,
		"the three empires do not have one letter each to reach the PC with")
