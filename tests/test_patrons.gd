extends TestCase

## Patrons: specialty, need, vice, and arrival (#282, SPEC §8.3;
## `docs/mechanics/patrons.md` §1, §2, §3, §6, §7).
##
## 🔒 **Three things rolled at arrival, and specialty is never the need.** The
## mismatch is the whole reason a patron is interesting — he has what you may not
## want and wants what you may not have — and it is guaranteed by the draw rather
## than by a check anybody has to remember.
##
## 🔒 **Arrival is dimension 4 and there is no second clock** (§7). The same
## arithmetic the dukes use, against a later threshold.
##
## 🔒 **A vice names a knob.** Ten vices written as ten special cases is ten
## places a change to the contact model has to be remembered, which is the rule
## `perks-and-quirks.md` §2 already puts on a perk.
##
## 🔒 **Well-connected is one-directional and shallow.** A patron reaches the
## Crown officers; the officers reach nobody. Contagion between contacts
## generally is a spiral nobody has designed.
##
## 🔒 **Pragmatic reads `net_position` and never prestige**, because prestige
## would close a loop: pleasing a patron banks prestige, and his regard is itself
## part of prestige.

const SEED: int = 5507

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


## The REACH level at which the Squeeze has produced one patron.
func _level_for_one() -> int:
	return Patron.ASKERS_FOR_PATRONS - 1


## A run in which the Squeeze has produced every patron it can.
func _run_with_patrons() -> RunState:
	var run := _run()
	run.demands.levels[String(DemandGrowth.REACH)] = 99
	PatronDriver.new(run).on_phase(
		WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	return run


func _with_vice(run: RunState, vice: StringName) -> Contact:
	var patron: Contact = Patron.all_in(run)[0]
	patron.vice = vice
	PatronVices.apply_to(patron)
	return patron


# --- 🔒 Three things rolled at arrival --------------------------------------

func test_a_patron_arrives_with_a_specialty_a_need_and_a_vice() -> void:
	for entry in Patron.all_in(_run_with_patrons()):
		var man: Contact = entry
		assert_false(man.specialty.is_empty(), "%s can supply nothing" % man.id)
		assert_false(man.need.is_empty(), "%s wants nothing" % man.id)
		assert_false(String(man.vice).is_empty(), "%s is not difficult at all" % man.id)
		assert_false(man.display_name.is_empty(), "%s has no name" % man.id)


func test_specialty_and_need_are_never_the_same() -> void:
	# 🔒 The acceptance line, and asked over enough men that a lucky seed cannot
	# carry it. Two hundred draws from two hundred streams, which is the whole
	# catalogue several times over.
	var run := _run()
	var seen: Dictionary = {}
	for index in range(200):
		var man := Patron.generate(StringName("probe_%d" % index), run.streams)
		assert_ne(man.specialty, man.need,
			"%s was given a need he already supplies: %s" % [man.id, man.specialty])
		seen[man.specialty] = true
	assert_true(seen.size() >= 3, (
		"two hundred men between them specialised in %d things, so the draw is "
		+ "not reaching the catalogue") % seen.size())


func test_the_same_seed_gives_the_same_man() -> void:
	# 🔒 Determinism: his stream is his own, so who he is cannot depend on what
	# else the run did before he turned up.
	var first: Contact = Patron.all_in(_run_with_patrons())[0]
	var again: Contact = Patron.all_in(_run_with_patrons())[0]
	assert_eq(again.display_name, first.display_name)
	assert_eq(again.specialty, first.specialty)
	assert_eq(again.need, first.need)
	assert_eq(again.vice, first.vice)


func test_the_catalogue_is_a_file_and_the_vices_are_a_file() -> void:
	assert_true(Patron.catalogue_ids().size() >= 2,
		"the catalogue holds fewer than two things, so §3's mismatch is impossible")
	assert_true(PatronVices.ids().size() >= 1, "there are no vices at all")
	assert_true(Patron.catalogue_ids().has("rivals"),
		"the catalogue has no rival specialty, which §5 calls the third door")


# --- 🔒 Arrival is dimension 4, with no second clock ------------------------

func test_nobody_is_asking_until_the_squeeze_has_reached_that_far() -> void:
	var growth := DemandGrowth.new()
	assert_eq(Patron.how_many_arrived(growth), 0,
		"a patron turned up in month one, before anybody had a hand out")
	assert_eq(Patron.how_many_arrived(null), 0, "a run with no growth state grew one")


func test_they_arrive_one_at_a_time_and_stop_at_three() -> void:
	# 🔒 **Staggered, and they cannot bunch** — both fall out of the bucket rather
	# than needing code, because dimension 4 comes up at most twice in four years.
	var growth := DemandGrowth.new()
	var seen := PackedInt32Array()
	for level in range(0, 12):
		growth.levels[String(DemandGrowth.REACH)] = level
		seen.append(Patron.how_many_arrived(growth))
	assert_eq(seen[seen.size() - 1], Patron.how_many(),
		"the Squeeze can never produce all three: %s" % [seen])
	for index in range(1, seen.size()):
		assert_true(seen[index] - seen[index - 1] <= 1,
			"two patrons arrived on one draw: %s" % [seen])


func test_the_driver_adds_nobody_the_squeeze_has_not_produced() -> void:
	var run := _run()
	var driver := PatronDriver.new(run)
	driver.on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	assert_empty(Patron.all_in(run), "a patron arrived with no hands out")

	run.demands.levels[String(DemandGrowth.REACH)] = _level_for_one()
	driver.on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	assert_eq(Patron.all_in(run).size(), 1, "the first draw produced more than one man")


func test_asking_every_month_brings_nobody_twice() -> void:
	# The same idempotence the residents have, and for the same reason: a run
	# loaded from a save must be correct without replaying its history.
	var run := _run_with_patrons()
	var before := Patron.all_in(run).size()
	for round in 5:
		PatronDriver.new(run).on_phase(
			WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	assert_eq(Patron.all_in(run).size(), before, "asking five times brought five men")


func test_his_arrival_is_an_event() -> void:
	# Seam A: what he is, said once, so the letters and the harness read the same
	# man.
	var run := _run_with_patrons()
	var arrivals := run.log.of_type(Patron.EVENT_ARRIVED)
	assert_eq(arrivals.size(), Patron.how_many(),
		"%d men arrived and %d events said so" % [Patron.how_many(), arrivals.size()])
	assert_false(String(arrivals[0].payload.get("vice", "")).is_empty(),
		"the arrival event does not say what makes him difficult")


# --- 🔒 A vice names a knob -------------------------------------------------

func test_every_knob_a_shipped_vice_names_is_turned_or_read() -> void:
	for id in PatronVices.ids():
		for entry in PatronVices.knobs_of(StringName(id)):
			for knob in entry:
				assert_true(PatronVices.is_knob(String(knob)),
					"'%s' names the knob '%s', which nothing turns and nothing reads"
						% [id, knob])


func test_thin_skinned_feels_a_refusal_through_the_line_everybody_feels() -> void:
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"thin_skinned")
	var ordinary := Relationship.new(&"ordinary")

	var his := patron.relationship.record_deed(Relationship.REFUSED)
	var theirs := ordinary.record_deed(Relationship.REFUSED)
	assert_true(his < theirs,
		"a thin-skinned man took a refusal no harder: %f against %f" % [his, theirs])


func test_importunate_reaches_for_a_pen_more_readily() -> void:
	var run := _run_with_patrons()
	var patron: Contact = Patron.all_in(run)[0]
	var before := patron.writes_readily
	patron.vice = &"importunate"
	PatronVices.apply_to(patron)
	assert_true(patron.writes_readily > before,
		"an importunate man is no likelier to write: %f" % patron.writes_readily)


func test_credulous_is_a_lean_and_not_an_escalation_rule() -> void:
	# 🔒 §6's pattern for the rest: he has a bias, and his asks grow on their own
	# because he sincerely believes the colony prospers.
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"credulous")
	assert_true(patron.lean_for("colony_revenue") > 0.0,
		"a credulous man reads the colony's returns exactly")


func test_a_vice_nobody_has_written_turns_nothing() -> void:
	var run := _run_with_patrons()
	var patron: Contact = Patron.all_in(run)[0]
	var before := patron.writes_readily
	patron.vice = &"a_vice_nobody_has_written"
	PatronVices.apply_to(patron)
	assert_eq(patron.writes_readily, before, "an unknown vice turned something")
	assert_empty(PatronVices.knob_of(patron, "will_not_touch"),
		"an unknown vice answered a question about a knob")


func test_a_knob_that_is_read_rather_than_turned_answers_where_it_is_read() -> void:
	# 🔒 The other half of the contract. A knob is read rather than turned when
	# storing the answer would put it in two places, and the reader must find it.
	var run := _run_with_patrons()
	var loud := _with_vice(run, &"loudmouth")
	assert_true(PatronCredit.voice_of(loud) > 1.0,
		"a loudmouth speaks no louder at court: %f" % PatronCredit.voice_of(loud))

	var quiet := _with_vice(run, &"pragmatic")
	assert_almost_eq(PatronCredit.voice_of(quiet), 1.0,
		0.0001, "an ordinary patron is not at the ordinary volume")


func test_the_loudmouth_scales_a_term_that_is_really_there() -> void:
	# The knob would be a lie if the term it multiplies read zero.
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"loudmouth")
	var banked := PatronCredit.bank(patron, Relationship.GRANTED, run.log, 4)
	assert_true(banked > PatronCredit.GRANTED_WORTH,
		"a loudmouth banked the ordinary amount: %f" % banked)
	assert_almost_eq(Prestige.patron_credit_in(run.log), banked, 0.0001,
		"prestige did not read what was banked")


func test_a_favour_banks_and_a_refusal_costs() -> void:
	var run := _run_with_patrons()
	var patron: Contact = Patron.all_in(run)[0]
	patron.vice = &""
	assert_almost_eq(PatronCredit.bank(patron, Relationship.GRANTED, run.log, 1),
		PatronCredit.GRANTED_WORTH, 0.0001)
	assert_true(PatronCredit.bank(patron, Relationship.REFUSED, run.log, 2) < 0.0,
		"refusing a patron cost his prestige nothing")
	assert_almost_eq(PatronCredit.bank(patron, Relationship.IGNORED, run.log, 3),
		0.0, 0.0001, "a letter that never came was reported at court")


func test_nobody_but_a_patron_banks_anything() -> void:
	var run := _run_with_patrons()
	var steward := run.contact(&"steward")
	assert_almost_eq(PatronCredit.bank(steward, Relationship.GRANTED, run.log, 1),
		0.0, 0.0001, "the Steward banked prestige like a patron")
	assert_almost_eq(Prestige.patron_credit_in(run.log), 0.0, 0.0001)


# --- 🔒 Pragmatic reads the books, Respectable reads the streets ------------

func test_pragmatic_cares_about_net_position_and_never_prestige() -> void:
	# 🔒 The acceptance line. Prestige would close a loop: pleasing a patron banks
	# prestige, and his regard is itself part of prestige.
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"pragmatic")
	assert_true(patron.cares_about.has(ColonyMeasures.COLONY_NET_POSITION),
		"a pragmatic man does not read the Crown's books: %s" % [patron.cares_about])
	for measure in patron.cares_about:
		assert_false(String(measure).contains("prestige"),
			"a pragmatic man reads prestige, which closes the loop §6 forbids")


func test_the_measures_a_patron_reads_are_his_alone() -> void:
	# 🔒 The other side of `rival-pressure.md` §2's lock: the Crown's ledger is
	# the Crown's, and a duke has no sight of it.
	var run := _run_with_patrons()
	var patron: Contact = Patron.all_in(run)[0]
	assert_has(ColonyMeasures.for_contact(run, patron),
		ColonyMeasures.COLONY_NET_POSITION)

	for id in run.contact_ids():
		var other: Contact = run.contacts[id]
		if Patron.is_patron(other):
			continue
		assert_false(
			ColonyMeasures.for_contact(run, other).has(ColonyMeasures.COLONY_NET_POSITION),
			"%s (%s) can read the Crown's books" % [id, other.role])


func test_respectable_watches_the_worst_town_and_not_the_average() -> void:
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"respectable")
	assert_true(patron.cares_about.has(ColonyMeasures.COLONY_IS_QUIET),
		"a respectable man does not watch how the colony is governed")

	var quiet := ColonyMeasures.quiet_of(run)
	run.colony.in_order()[0].rebel_sentiment = RebelSentiment.MAXIMUM
	assert_true(ColonyMeasures.quiet_of(run) < quiet,
		"one town at the point of going changed nothing")

	run.colony.in_order()[0].rebelling = true
	assert_almost_eq(ColonyMeasures.quiet_of(run), 0.0, 0.0001,
		"a town actually declared and the colony still read as quiet")


# --- 🔒 Well-connected: one-directional and shallow -------------------------

func _gossiping(run: RunState) -> Contact:
	var patron := _with_vice(run, &"well_connected")
	run.patrons.note(patron)
	return patron


func test_a_well_connected_patrons_fall_moves_the_crowns_officers() -> void:
	# 🔒 The acceptance line, and the one new mechanic in the ticket.
	var run := _run_with_patrons()
	var patron := _gossiping(run)
	var before := run.contact(&"steward").relationship.loyalty

	patron.relationship.drift(-20.0)
	PatronGossip.spread(run, run.log, 6)

	assert_true(run.contact(&"steward").relationship.loyalty < before,
		"the court heard nothing: %f" % run.contact(&"steward").relationship.loyalty)
	assert_eq(run.log.of_type(PatronGossip.EVENT_SPREAD).size(), 1,
		"the regard moved and no event said so")


func test_nothing_propagates_further_than_the_officers() -> void:
	# 🔒 **One-directional and shallow.** Contagion between contacts generally is
	# a spiral nobody has designed and must not arrive by accident.
	var run := _run_with_patrons()
	var patron := _gossiping(run)
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	var before := governor.relationship.loyalty
	var other: Contact = Patron.all_in(run)[1]
	other.vice = &""
	var others_regard := other.relationship.loyalty

	patron.relationship.drift(-30.0)
	PatronGossip.spread(run, run.log, 6)

	assert_almost_eq(governor.relationship.loyalty, before, 0.0001,
		"a governor an ocean away heard the court's gossip")
	assert_almost_eq(other.relationship.loyalty, others_regard, 0.0001,
		"one patron's fall moved another patron")


func test_only_a_fall_travels() -> void:
	var run := _run_with_patrons()
	var patron := _gossiping(run)
	var before := run.contact(&"steward").relationship.loyalty

	patron.relationship.drift(25.0)
	PatronGossip.spread(run, run.log, 6)

	assert_almost_eq(run.contact(&"steward").relationship.loyalty, before, 0.0001,
		"paying a patron raised five loyalties at once")
	assert_empty(run.log.of_type(PatronGossip.EVENT_SPREAD))


func test_a_patron_without_the_vice_says_nothing() -> void:
	var run := _run_with_patrons()
	var patron: Contact = Patron.all_in(run)[0]
	patron.vice = &"thin_skinned"
	run.patrons.note(patron)
	var before := run.contact(&"steward").relationship.loyalty

	patron.relationship.drift(-40.0)
	PatronGossip.spread(run, run.log, 6)

	assert_almost_eq(run.contact(&"steward").relationship.loyalty, before, 0.0001,
		"a man with no voice at court was heard at court")


func test_the_same_slight_is_not_carried_twice() -> void:
	# 🔒 Gossip is a **movement**, not a level. A patron who is merely low is one
	# the court has already heard about, and he must not go on costing the PC
	# every month for the same slight.
	var run := _run_with_patrons()
	var patron := _gossiping(run)

	patron.relationship.drift(-20.0)
	PatronGossip.spread(run, run.log, 6)
	var after_the_first := run.contact(&"steward").relationship.loyalty

	PatronGossip.spread(run, run.log, 7)
	PatronGossip.spread(run, run.log, 8)
	assert_almost_eq(run.contact(&"steward").relationship.loyalty, after_the_first,
		0.0001, "the court repeated a slight the PC had already paid for")


func test_a_man_the_court_has_never_heard_of_arrives_owing_nothing() -> void:
	# A patron who turns up already out of sorts has not been slighted by anybody.
	var run := _run_with_patrons()
	var patron := _with_vice(run, &"well_connected")
	patron.relationship.loyalty = 5.0
	var before := run.contact(&"steward").relationship.loyalty

	PatronGossip.spread(run, run.log, 6)
	assert_almost_eq(run.contact(&"steward").relationship.loyalty, before, 0.0001,
		"the court held a new arrival's mood against the PC")


func test_what_the_court_remembers_survives_the_save() -> void:
	# Ironman (SPEC §16.2). A book kept on a driver would reset the court's memory
	# on every load, and the next month would repeat a paid-for slight.
	var run := _run_with_patrons()
	var patron := _gossiping(run)
	patron.relationship.drift(-15.0)
	PatronGossip.spread(run, run.log, 6)

	var restored := PatronBook.from_dict(run.patrons.to_dict())
	assert_eq(restored.arrived, run.patrons.arrived,
		"the count of arrivals did not survive the save")
	assert_almost_eq(restored.fall_of(patron), 0.0, 0.0001,
		"a reloaded run owes the court a slight it has already paid")


# --- 🔒 The validator ------------------------------------------------------

func _said(validator: ContentValidator) -> String:
	var out := PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func test_the_shipped_patrons_pass() -> void:
	var validator := ContentValidator.new()
	validator.check_patrons(content)
	assert_true(validator.ok(), _said(validator))


func test_a_knob_nothing_turns_and_nothing_reads_is_refused() -> void:
	# 🔒 The failure this shape exists to prevent: a vice the Author wrote, the
	# player met, and that did nothing at all.
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(PatronVices.COLLECTION, PatronVices.RECORD)["entries"].append({
		"id": "wishful", "knobs": [{"just_be_generous": {}}],
	})
	var validator := ContentValidator.new()
	validator.check_patrons(db)
	assert_false(validator.ok(), "a vice naming a knob nothing turns passed")
	assert_true(_said(validator).contains("just_be_generous"), _said(validator))
	db.free()


func test_a_vice_that_names_no_knobs_is_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(PatronVices.COLLECTION, PatronVices.RECORD)["entries"].append({
		"id": "merely_a_word", "knobs": [],
	})
	var validator := ContentValidator.new()
	validator.check_patrons(db)
	assert_false(validator.ok(), "a vice that does nothing passed")
	db.free()


func test_a_catalogue_of_one_is_refused() -> void:
	# §3's mismatch is impossible with one entry, so the man could have no need.
	var db := ContentDatabase.new()
	db.load_all("en")
	db.record(Patron.COLLECTION, Patron.CATALOGUE_RECORD)["entries"] = [
		{"id": "gold", "kind": "shipment"},
	]
	var validator := ContentValidator.new()
	validator.check_patrons(db)
	assert_false(validator.ok(), "a catalogue with nothing to mismatch passed")
	db.free()


func test_a_missing_vices_file_is_refused() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.collection(PatronVices.COLLECTION).erase(PatronVices.RECORD)
	var validator := ContentValidator.new()
	validator.check_patrons(db)
	assert_false(validator.ok(),
		"a missing vices file passed, so every patron would arrive with no vice")
	db.free()
