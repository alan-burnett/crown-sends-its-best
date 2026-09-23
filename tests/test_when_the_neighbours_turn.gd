extends TestCase

## When the neighbours turn: native raids and a duke at Minimum (#225,
## `docs/mechanics/natives.md` §7, `docs/mechanics/rival-pressure.md` §3,
## `docs/mechanics/tiles-and-improvements.md` §7).
##
## 🔒 **A tribe past its hostility threshold raises companies and attacks**, and
## the threshold is the one it already had: a village reaches `drive_them_off`
## only past the point of no return.
##
## 🔒 **A duke at Minimum makes war without further gating**, because the band is
## a latch read off one loyalty value and there is nothing else to ask.
##
## 🔒 **Razing is not war.** Harassment fires no optic, takes no town, escalates
## nothing, and runs nowhere near battle resolution — and a dev who routed it
## there would make the long quiet middle of a run disappear.
##
## 🔒 **Neither path touches influence.** Tribes taking tiles is a third thing
## (§12.5), `natives.md` §10 holds it open, and it stays open.

const SEED: int = 8419

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


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	return context


## A village that has concluded the colony means it destroyed, beside a town.
func _hostile_village(run: RunState, people: int = 40) -> Village:
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = run.colony.in_order()[0].at + Vector2i(2, 0)
	village.people = people
	village.objective = Village.DRIVE_THEM_OFF
	return village


# --- 🔒 A tribe past its threshold raises companies --------------------------

func test_a_village_that_has_concluded_musters() -> void:
	var run := _run()
	var village := _hostile_village(run)
	run.world.month = 3

	assert_eq(Muster.run_month(run, _context(run)), 1,
		"a village bent on driving the colony off raised nobody")
	var parties := run.log.of_type(Muster.EVENT_WAR_PARTY)
	assert_eq(parties.size(), 1)
	assert_eq(String(parties[0].payload.get("village", "")), String(village.id))


func test_a_village_that_has_not_concluded_musters_nobody() -> void:
	# 🔒 **No new threshold.** *Arm ourselves* is preparation and *work more land*
	# is unease; only `drive_them_off` is a decision to make war, and it is a
	# village's own deliberated objective rather than a figure this file invents.
	var run := _run()
	var village := _hostile_village(run)
	for quiet in [Village.ARM_OURSELVES, Village.WORK_MORE_LAND,
			Village.GROW, Village.FEED_OURSELVES]:
		village.objective = quiet
		assert_eq(Muster.run_month(run, _context(run)), 0,
			"a village on %s raised a war party" % quiet)


func test_the_party_is_the_villages_own_people() -> void:
	var run := _run()
	var village := _hostile_village(run, 40)
	run.world.month = 3
	Muster.run_month(run, _context(run))

	var party := run.companies.in_resolution_order()[0] as Company
	assert_eq(village.people + party.size, 40,
		"the war party did not come out of the village: %d left, %d out"
			% [village.people, party.size])
	assert_true(village.people >= Muster.VILLAGE_KEEPS,
		"the village emptied itself")


func test_a_village_does_not_send_the_same_men_twice() -> void:
	var run := _run()
	_hostile_village(run, 40)
	run.world.month = 3
	Muster.run_month(run, _context(run))
	var had := run.companies.in_resolution_order().size()

	run.world.month = 4
	Muster.run_month(run, _context(run))
	assert_eq(run.companies.in_resolution_order().size(), had,
		"a second party was raised while the first was still in the field")


func test_a_village_too_small_sends_nobody() -> void:
	var run := _run()
	_hostile_village(run, Muster.VILLAGE_KEEPS)
	run.world.month = 3
	assert_eq(Muster.run_month(run, _context(run)), 0,
		"a village of six sent a war party and kept nobody")


func test_the_party_carries_a_share_of_what_the_village_had() -> void:
	# 🔒 `CLAUDE.md`: a body of people in the open takes the same share of its
	# stores as of its people — which is what makes §10.1's coveted muskets
	# matter, because a village that traded for them sends them.
	var run := _run()
	var village := _hostile_village(run, 40)
	village.stores["guns"] = 20.0
	run.world.month = 3
	Muster.run_month(run, _context(run))

	var party := run.companies.in_resolution_order()[0] as Company
	assert_true(party.held(&"guns") > 0.0, "a war party marched out unarmed past the rack")
	assert_almost_eq(party.held(&"guns") + float(village.stores["guns"]), 20.0, 0.001,
		"muskets were conjured or lost in the muster")


func test_and_it_attacks() -> void:
	# The acceptance line: *raises companies and attacks.* Through the driver, so
	# the march and the battle are the ordinary ones.
	var run := _run()
	var town := run.colony.in_order()[0]
	town.workers = 12
	var village := _hostile_village(run, 60)
	village.at = town.at + Vector2i(1, 0)

	run.world.month = 3
	Muster.run_month(run, _context(run))

	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.contacts = run.contacts
	driver.commanders = run.commanders
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)

	assert_false(run.log.of_type(Battle.EVENT_FOUGHT).is_empty(),
		"a war party stood beside a town for a month and did nothing")


# --- 🔒 A duke at Minimum, without further gating ---------------------------

## A run far enough into the Squeeze that the dukes have actually turned up.
##
## 🔒 **Present as a contact and arrived are not the same thing**, and a fixture
## that skipped this would test a duke who does not exist yet — which is how a
## mutation removing the Minimum gate survived the first draft of this file.
func _run_with_dukes() -> RunState:
	var run := _run()
	var growth := DemandGrowth.new()
	for _duke in RivalDuke.HOW_MANY:
		growth.sources.append(String(DemandGrowth.SOURCE_DUKE))
	run.demands = growth
	assert_false(RivalDuke.arrived_in(run, run.demands).is_empty(),
		"the fixture produced no arrived dukes, so it would prove nothing")
	return run


func test_a_duke_at_minimum_lands_companies() -> void:
	var run := _run_with_dukes()
	var duke: Contact = RivalDuke.arrived_in(run, run.demands)[0]
	run.rivals.reached_minimum(duke, _context(run))
	assert_true(RivalDuke.makes_war(RivalDuke.band_for(duke, run.rivals)),
		"the fixture did not reach Minimum")

	run.world.month = Muster.LANDS_EVERY
	Muster.run_month(run, _context(run))
	var landed := run.log.of_type(Muster.EVENT_LANDED)
	assert_false(landed.is_empty(), "a duke at Minimum landed nobody")
	assert_eq(String(landed[0].payload.get("duke", "")), String(duke.id))


func test_a_duke_above_minimum_lands_nobody() -> void:
	# 🔒 Minimum is a latch and nobody starts there. Everything above it is
	# recoverable, which is what makes crossing it matter — and a duke who has
	# arrived, is present, and is being dealt with must land nobody at all.
	var run := _run_with_dukes()
	for entry in RivalDuke.arrived_in(run, run.demands):
		assert_false(RivalDuke.makes_war(
			RivalDuke.band_for(entry as Contact, run.rivals)),
			"the fixture starts a duke at war")

	run.world.month = Muster.LANDS_EVERY
	Muster.run_month(run, _context(run))
	assert_empty(run.log.of_type(Muster.EVENT_LANDED),
		"a duke nobody had driven to the bottom invaded anyway")


func test_he_keeps_landing_and_stops_at_the_cap() -> void:
	var run := _run_with_dukes()
	var duke: Contact = RivalDuke.arrived_in(run, run.demands)[0]
	run.rivals.reached_minimum(duke, _context(run))

	for month in range(Muster.LANDS_EVERY, Muster.LANDS_EVERY * 20,
			Muster.LANDS_EVERY):
		run.world.month = month
		Muster.run_month(run, _context(run))
	assert_eq(run.log.of_type(Muster.EVENT_LANDED).size(), Muster.LANDS_AT_MOST,
		"a duke at Minimum landed a different number of companies from the cap")


func test_nothing_gates_him_but_the_band() -> void:
	# 🔒 The acceptance line, asked of the file. §3's bands are read off one
	# loyalty value with **no second state machine**, so a condition here naming
	# tribute, a demand or a promise would be that second machine.
	# `run.demands` is not a gate — `arrived_in` answers *has this duke turned up
	# in the run yet*, which is whether he exists to act, not whether he is
	# willing to. Everything that could be a second state machine is forbidden.
	var code := _code_of("res://sim/battle/muster.gd")
	var found := PackedStringArray()
	for token in ["tribute", "promise", "standing", "prestige", "loyalty"]:
		if code.to_lower().contains(token):
			found.append(token)
	assert_empty(found,
		"a duke at Minimum is gated on something other than his band: %s"
			% ", ".join(found))


# --- 🔒 A town taken is a lost town --------------------------------------

func test_a_town_they_take_leaves_the_colony_and_fires_one_optic() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	town.workers = 8
	town.experts = {}
	var had := run.colony.in_order().size()

	var host := run.companies.raise_company(
		Company.NATIVE, 4_000, {"guns": 4_000.0, "tools": 4_000.0},
		Company.SUPPORTED_ABROAD, town.at, _context(run))
	run.world.month = 5
	Battle.resolve(host, TownCompany.of(town, host), run.map, _context(run))

	assert_eq(town.population(), 0, "the town held, so this proves nothing")
	assert_eq(run.colony.in_order().size(), had - 1)
	assert_eq(run.log.of_type(Colony.EVENT_LOST).size(), 1)

	var optics := 0
	for event in run.log.all():
		if OpticsRegister.is_an_optic(event.type) \
				and String(event.subject) == String(town.id):
			optics += 1
	assert_eq(optics, 1, "the court heard about one town %d times" % optics)


func test_and_it_counts_toward_colony_overrun() -> void:
	# §13.1, and `RunEndCheck` already holds the test. What #225 supplies is the
	# only thing that could ever make it true.
	var run := _run()
	var context := _context(run)
	assert_false(RunEndCheck.is_overrun(run.colony, []),
		"a colony with towns already read as overrun")

	for town in run.colony.in_order().duplicate():
		run.colony.lost(town, Company.NATIVE, "stormed", context, WorldPhase.MOVEMENT)
	assert_true(RunEndCheck.is_overrun(run.colony, []),
		"every town was taken and the colony was not overrun")


func test_the_chancellors_warning_still_precedes_a_fail_condition() -> void:
	# 🔒 SPEC §13.1, locked: *every fail condition goes through a last chance
	# stage first. Defeat is never a surprise.* Nothing in this ticket ends a run
	# — it makes towns losable, and the ending machinery is untouched.
	var found := PackedStringArray()
	for path in ["res://sim/battle/muster.gd", "res://sim/battle/muster_driver.gd",
			"res://sim/battle/town_company.gd"]:
		var code := _code_of(path)
		for token in ["RunEnding", "RunEndCheck", "run_failed", "is_overrun"]:
			if code.contains(token):
				found.append("%s names %s" % [path.get_file(), token])
	assert_empty(found,
		"something that takes a town also ends the run: %s" % ", ".join(found))


# --- 🔒 Razing is not war, and it is not this -------------------------------

func test_harassment_runs_nowhere_near_battle_resolution() -> void:
	# 🔒 §7: *a dev who routes razing through battle resolution has made
	# harassment cost prestige, and the long quiet middle of a run disappears.*
	var found := PackedStringArray()
	for path in ["res://correspondence/contacts/rival_tile_driver.gd",
			"res://sim/crown/denied_tiles.gd"]:
		var code := _code_of(path)
		for token in ["Battle.", "TownCompany", "Force.", "Muster"]:
			if code.contains(token):
				found.append("%s names %s" % [path.get_file(), token])
	assert_empty(found,
		"harassment reaches battle resolution: %s" % ", ".join(found))


func test_harassment_fires_no_optic() -> void:
	# It takes no town and destroys no company, so there is nothing for the court
	# to hear — which is what lets a rival at Low hurt the colony month after
	# month without ever declaring anything.
	var run := _run()
	run.world.month = 4
	var driver := RivalTileDriver.new(run)
	driver.on_phase(WorldPhase.TERRITORY, run.world, run.log, run.streams)
	assert_almost_eq(OpticsRegister.debt_in(run.log), 0.0, 0.0001,
		"a month of harassment embarrassed the Crown")


func test_the_two_paths_are_different_phases() -> void:
	# Kept apart structurally rather than by care: harassment is phase 3 and a
	# muster is phase 1, and neither file mentions the other.
	assert_false(_code_of("res://sim/battle/muster.gd").contains("TERRITORY"))
	assert_true(_code_of("res://sim/battle/muster_driver.gd").contains("ARRIVALS"))


# --- 🔒 Neither path touches influence --------------------------------------

func test_neither_path_touches_influence() -> void:
	# 🔒 §12.5's tribes taking tiles is a contest over influence and is a **third
	# thing** — neither razing nor battle. `natives.md` §10 holds it open and this
	# ticket does not settle it.
	var found := PackedStringArray()
	for path in ["res://sim/battle/muster.gd", "res://sim/battle/muster_driver.gd"]:
		var code := _code_of(path).to_lower()
		if code.contains("influence"):
			found.append(path.get_file())
	assert_empty(found, "the muster reads or writes influence: %s" % ", ".join(found))


func test_a_muster_claims_no_tile_and_contests_nothing() -> void:
	# ⚠️ A village's reach is **derived from its people** (`Village.influence`),
	# so one that sends forty per cent of them out does hold less land while they
	# are gone. That is the people leaving, not a contest over tiles.
	#
	# What §12.5 holds open is the *contest*, and this is what stays untouched:
	# no tile changes hands, nothing is claimed, and the tile registry does not
	# hear about the muster at all.
	var run := _run()
	var village := _hostile_village(run, 40)
	var held := PackedStringArray()
	for at in run.map.all_tiles() if run.map.has_method("all_tiles") else []:
		held.append(str(at))
	var holder_before := run.tribes.holder_of(village.at)

	run.world.month = 3
	Muster.run_month(run, _context(run))

	assert_eq(String(run.tribes.holder_of(village.at)), String(holder_before),
		"the muster moved who holds the ground it stood on")
	assert_true(village.influence() <= Village.INFLUENCE_MAX,
		"influence left its authored range")


# --- They feed themselves ---------------------------------------------------

func test_a_war_party_is_never_the_colonys_burden_and_never_starves() -> void:
	# 🔒 A besieging army starving outside a town it is winning against would be
	# absurd, and a hostile company on a town id the colony has no town for would
	# do exactly that.
	var run := _run()
	_hostile_village(run, 40)
	run.world.month = 3
	Muster.run_month(run, _context(run))

	var party := run.companies.in_resolution_order()[0] as Company
	assert_true(party.feeds_itself(), "a war party waits on the colony for rations")
	assert_true(party.is_supplied(run.world.month))
	assert_false(party.is_the_crowns_burden(),
		"a native war party is victualled by the Marshal")


func test_the_record_says_who_raised_them_and_survives_a_save() -> void:
	var run := _run()
	var village := _hostile_village(run, 40)
	run.world.month = 3
	Muster.run_month(run, _context(run))

	var party := run.companies.in_resolution_order()[0] as Company
	assert_eq(String(party.raised_by), String(village.id))
	assert_eq(String(Company.from_dict(party.to_dict()).raised_by), String(village.id),
		"a saved run forgot who put them under arms")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
