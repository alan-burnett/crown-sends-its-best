extends TestCase

## Battle resolution: deterministic, simultaneous, and no rout (#216,
## `docs/mechanics/battles.md` §6, §7).
##
## 🔒 **Deterministic. No dice at all.** Everything around a battle is chaotic —
## whether the order arrived, whether the commander agreed, whether the town
## could feed him. The battle itself is arithmetic. The PC never commands
## (SPEC §12.6), so he cannot be out-played, only under-prepared, and randomness
## would make what he spent on guns feel arbitrary.
##
## 🔒 **Both sides compute from the same force pair and suffer simultaneously**,
## so neither gets to swing at a man the other has already lost.
##
## 🔒 **Casualties are men, and they are fractional.** A company dwindling at 0.2
## a month is visibly dying for five months before it loses one.
##
## 🔒 **No rout.** Nobody retreats and nobody surrenders; a company fights until
## it is destroyed, and ground is taken only when the last defender is gone.
##
## 🔒 **And the order is §7's**, so three companies falling on one resolve as
## three battles against a defender who weakens as they come.

const SEED: int = 4409

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
	return context


## A company of `size` men, unarmed unless told otherwise, on its town's tile.
func _raise(
	run: RunState,
	allegiance: StringName,
	size: int,
	at: Vector2i = Company.NOWHERE,
) -> Company:
	var town := run.colony.in_order()[0]
	# Fixture sizes are in thousands (#426).
	return run.companies.raise_company(
		allegiance, size * Population.THOUSAND, {}, town.id,
		town.at if at == Company.NOWHERE else at, _context(run))


# --- 🔒 No dice ------------------------------------------------------------

func test_nothing_in_resolution_consults_an_rng() -> void:
	# The acceptance line, asked of the file. **Randomness would make what the PC
	# spent on guns feel arbitrary**, and it is the kind of thing that gets added
	# later to "make battles interesting".
	var code := FileAccess.get_file_as_string("res://sim/battle/battle.gd")
	for token in ["rng", "RngStreams", "randi", "randf", "stream(", "seed"]:
		assert_false(code.contains(token),
			"battle.gd names '%s', and §6 says the battle itself is arithmetic"
				% token)


func test_the_same_pair_fights_the_same_way_every_time() -> void:
	var results := PackedFloat32Array()
	for pass_index in 3:
		var run := _run()
		var attacker := _raise(run, Company.CROWN, 40)
		var defender := _raise(run, Company.REBEL, 20)
		var fought := Battle.resolve(attacker, defender, run.map, _context(run))
		results.append(float(fought["defender_casualties"]))
	for index in range(1, results.size()):
		assert_almost_eq(results[index], results[0], 0.000001,
			"the same battle came out differently: %s" % [results])


# --- The formula ------------------------------------------------------------

func test_casualties_are_lethality_times_the_force_ratio() -> void:
	# Lethality is men at parity, authored per thousand (#426).
	var per := Battle.lethality() * Population.THOUSAND
	assert_almost_eq(Battle.casualties_for(40.0, 20.0), per * 2.0, 0.0001)
	assert_almost_eq(Battle.casualties_for(40.0, 10.0), per * 4.0, 0.0001)
	assert_almost_eq(Battle.casualties_for(40.0, 4.0), per * 10.0, 0.0001)


func test_forty_against_four_is_dramatically_worse_than_forty_against_twenty() -> void:
	# 🔒 The acceptance line, **and without a special case**: it is worse because
	# the ratio is five times larger, not because anything notices one of them is
	# small.
	var even := Battle.casualties_for(40.0, 20.0)
	var lopsided := Battle.casualties_for(40.0, 4.0)
	assert_almost_eq(lopsided, even * 5.0, 0.0001,
		"the curve bends somewhere it should not: %f against %f" % [lopsided, even])


func test_a_side_facing_nothing_inflicts_nothing() -> void:
	# Dividing by a force of nought would put an infinity in the state.
	assert_almost_eq(Battle.casualties_for(40.0, 0.0), 0.0, 0.0001)
	assert_almost_eq(Battle.casualties_for(0.0, 40.0), 0.0, 0.0001)


# --- 🔒 Simultaneous --------------------------------------------------------

func test_both_sides_suffer_from_the_same_force_pair() -> void:
	# 🔒 **Neither gets to swing at a man the other has already lost.** If the
	# attacker's losses were computed after the defender had taken his, the
	# defender's force would already be lower and the attacker would be hurt
	# less — a first-mover advantage the design does not have.
	var run := _run()
	var attacker := _raise(run, Company.CROWN, 40)
	var defender := _raise(run, Company.REBEL, 40)

	var fought := Battle.resolve(attacker, defender, run.map, _context(run))
	assert_almost_eq(float(fought["attacker_casualties"]),
		float(fought["defender_casualties"]), 0.000001,
		"an even fight was not even: %s" % [fought])


func test_wiping_out_a_company_still_costs_the_men_who_did_it() -> void:
	# 🔒 **The sharp end of "simultaneously"**, and the case that tells the two
	# implementations apart. Four men against four hundred die to the last in one
	# exchange — and if the attacker's losses were worked out *after* that, he
	# would be dividing by a force of nought and annihilating them would be free.
	#
	# Both sides read the same pair before either is touched, so it is not.
	var run := _run()
	var overwhelming := _raise(run, Company.CROWN, 400)
	var doomed := _raise(run, Company.REBEL, 4)

	var fought := Battle.resolve(overwhelming, doomed, run.map, _context(run))
	assert_true(doomed.is_empty(), "four against four hundred survived")
	assert_true(float(fought["attacker_casualties"]) > 0.0,
		"killing every man opposite cost nothing: %s" % [fought])
	assert_almost_eq(float(fought["attacker_casualties"]),
		Battle.casualties_for(4.0, 400.0), 0.000001,
		"the attacker's losses were worked out against a company already dead")


func test_the_larger_company_suffers_less() -> void:
	var run := _run()
	var big := _raise(run, Company.CROWN, 40)
	var small := _raise(run, Company.REBEL, 10)
	var fought := Battle.resolve(big, small, run.map, _context(run))
	assert_true(float(fought["defender_casualties"]) > float(fought["attacker_casualties"]),
		"the small company gave as good as it got: %s" % [fought])


func test_the_battle_says_what_both_sides_brought() -> void:
	# #214: force rides along so a letter can describe a mismatch truthfully —
	# *they were four to our one, and on a mountain.*
	var run := _run()
	var attacker := _raise(run, Company.CROWN, 40)
	var defender := _raise(run, Company.REBEL, 10)
	Battle.resolve(attacker, defender, run.map, _context(run))

	var fought := run.log.of_type(Battle.EVENT_FOUGHT)
	assert_eq(fought.size(), 1, "a battle was fought and nothing said so")
	for side in ["attacker_force", "defender_force"]:
		var parts: Dictionary = fought[0].payload.get(side, {})
		assert_true(float(parts.get("force", 0.0)) > 0.0,
			"the event does not say what the %s brought" % side)
		assert_has(parts, "terrain", "the event cannot say the ground mattered")


# --- 🔒 Casualties are fractional and they accumulate ----------------------

func test_a_slow_grind_takes_nobody_for_months_and_then_takes_somebody() -> void:
	# 🔒 §6's sentence, made mechanical: *a company dwindling at 0.2 a month is
	# visibly dying for five months before it loses a man.*
	var run := _run()
	var company := _raise(run, Company.REBEL, 40)
	var context := _context(run)

	for month in 4:
		assert_eq(company.take_casualties(0.2, &"ground_down", context), 0,
			"a fifth of a man was rounded up in month %d" % month)
		assert_eq(company.size, 40_000)
	assert_eq(company.take_casualties(0.2, &"ground_down", context), 1,
		"five months at a fifth of a man cost nobody")
	assert_eq(company.size, 39_999)


func test_what_is_left_over_is_kept() -> void:
	var run := _run()
	var company := _raise(run, Company.REBEL, 40)
	var context := _context(run)
	company.take_casualties(1.5, &"mauled", context)
	assert_eq(company.size, 39_999, "one and a half men cost %d" % (40_000 - company.size))
	assert_almost_eq(company.casualties_owed, 0.5, 0.0001,
		"the half man was forgiven")


func test_losses_in_battle_take_the_arms_with_them() -> void:
	# `CLAUDE.md`, and §6: a company that loses a third of its people loses a
	# third of everything it carries, so a fully supplied company stays fully
	# supplied with less of everything.
	var run := _run()
	var town := run.colony.in_order()[0]
	var arms: Dictionary = {}
	for resource in Company.armed_resources():
		arms[String(resource)] = Company.want_per_head(StringName(resource)) * 40.0
	var company := run.companies.raise_company(
		Company.REBEL, 40, arms, town.id, town.at, _context(run))
	var horsed := company.armed_share(&"horses")

	company.take_casualties(10.0, &"mauled", _context(run))
	assert_eq(company.size, 30)
	assert_almost_eq(company.armed_share(&"horses"), horsed, 0.001,
		"a mauled company came out better horsed than it went in")


# --- 🔒 No rout -------------------------------------------------------------

func test_nothing_retreats_surrenders_or_routs() -> void:
	# A company fights until it is destroyed. There is no morale here, no
	# withdrawal and no terms, and a dev adding one has left the spec.
	var code := FileAccess.get_file_as_string("res://sim/battle/battle.gd")
	var kept := PackedStringArray()
	for line in code.split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	var body := "\n".join(kept)
	for token in ["retreat", "surrender", "rout", "morale", "withdraw"]:
		assert_false(body.to_lower().contains(token),
			"battle.gd has a '%s', and §6 says nobody does" % token)


func test_a_company_fights_until_the_last_man() -> void:
	var run := _run()
	var overwhelming := _raise(run, Company.CROWN, 400)
	var doomed := _raise(run, Company.REBEL, 2)
	var context := _context(run)

	var rounds := 0
	while not doomed.is_empty() and rounds < 200:
		Battle.resolve(overwhelming, doomed, run.map, context)
		rounds += 1
	assert_true(doomed.is_empty(),
		"a hopeless company was still standing after %d months" % rounds)
	assert_true(rounds < 200, "it never died at all")


func test_ground_is_taken_only_when_the_last_defender_is_gone() -> void:
	var run := _run()
	var attacker := _raise(run, Company.CROWN, 400)
	var defender := _raise(run, Company.REBEL, 1)
	var fought := Battle.resolve(attacker, defender, run.map, _context(run))
	assert_true(bool(fought["defender_destroyed"]) == defender.is_empty(),
		"the battle disagreed with the company about whether it still held the ground")


# --- 🔒 SPEC §12.3's locks --------------------------------------------------

func test_colonists_do_not_fight_colonists() -> void:
	var run := _run()
	var loyal := _raise(run, Company.COLONIAL, 20)
	var rebel := _raise(run, Company.REBEL, 20)
	var crown := _raise(run, Company.CROWN, 20)

	assert_false(Battle.may_fight(loyal, rebel),
		"a loyal town's militia marched on a rebel town")
	assert_false(Battle.may_fight(rebel, loyal),
		"a rebel town fought a loyal one")
	assert_false(Battle.may_fight(loyal, crown),
		"the colony's militia fought the Crown's troops")


func test_a_rebel_town_fights_the_crowns_forces() -> void:
	# The consequence worth naming: **the colony's own militia cannot put down a
	# rebellion.** Only Crown troops can, so the PC has to ask the Marshal.
	var run := _run()
	var crown := _raise(run, Company.CROWN, 20)
	var rebel := _raise(run, Company.REBEL, 20)
	assert_true(Battle.may_fight(crown, rebel))
	assert_true(Battle.may_fight(rebel, crown))


func test_rivals_and_natives_fight_the_colony() -> void:
	var run := _run()
	var rival := _raise(run, Company.RIVAL, 20)
	var natives := _raise(run, Company.NATIVE, 20)
	var loyal := _raise(run, Company.COLONIAL, 20)
	var crown := _raise(run, Company.CROWN, 20)
	var rebel := _raise(run, Company.REBEL, 20)
	for theirs in [rival, natives]:
		for ours in [loyal, crown, rebel]:
			assert_true(Battle.may_fight(theirs, ours))
			assert_true(Battle.may_fight(ours, theirs))


func test_a_tribe_and_a_duke_never_fight() -> void:
	# 🔒 #402, `natives.md` §7: a tribe's diplomacy is with the colony alone.
	var run := _run()
	var rival := _raise(run, Company.RIVAL, 20)
	var natives := _raise(run, Company.NATIVE, 20)
	assert_false(Battle.may_fight(rival, natives), "a duke's company fell on a war party")
	assert_false(Battle.may_fight(natives, rival), "a war party fell on a duke's company")
	assert_empty(Battle.resolve(rival, natives, run.map, _context(run)),
		"a battle was fought between a tribe and a duke")


func test_a_war_party_and_a_dukes_company_in_contact_are_not_offered_each_other() -> void:
	# ATTACK is on a commander's ballot only when `_in_contact_with` finds him
	# somebody, so this is the question of whether it is ever offered.
	var run := _run()
	var far := run.colony.in_order()[0].at + Vector2i(12, 0)
	var rival := _raise(run, Company.RIVAL, 20, far)
	var natives := _raise(run, Company.NATIVE, 20, far + Vector2i(1, 0))
	assert_true(Battle.are_in_contact(rival, natives), "the fixture did not put them in contact")
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	assert_true(driver._in_contact_with(rival) == null, "a duke's commander was offered the war party beside him")
	assert_true(driver._in_contact_with(natives) == null, "a war party was offered the duke's company beside it")


func test_a_company_never_fights_its_own_faction_or_itself() -> void:
	var run := _run()
	var one := _raise(run, Company.RIVAL, 20)
	var other := _raise(run, Company.RIVAL, 20)
	assert_false(Battle.may_fight(one, other),
		"two companies of one empire fought each other")
	assert_false(Battle.may_fight(one, one), "a company fought itself")


func test_an_empty_company_is_not_a_battle() -> void:
	var run := _run()
	var alive := _raise(run, Company.CROWN, 20)
	var gone := _raise(run, Company.REBEL, 1)
	gone.lose(1.0, &"wiped_out", _context(run))
	assert_false(Battle.may_fight(alive, gone))
	assert_empty(Battle.resolve(alive, gone, run.map, _context(run)))


# --- 🔒 Order of resolution -------------------------------------------------

func _attack(attacker: Company, defender: Company) -> Dictionary:
	return {"attacker": attacker, "defender": defender}


func test_three_attacks_resolve_against_a_weakening_defender() -> void:
	# 🔒 §7: each attack is a **separate battle**, so the second falls on a
	# defender the first has already hurt and hurts him harder for it.
	#
	# The numbers are chosen so that men actually die between the battles. At a
	# gentler ratio the defender's losses are fractional, his force is unchanged
	# and the three exchanges are identical — which is correct, and is the
	# *visibly dying for five months* property rather than a failure of this one.
	var run := _run()
	var defender := _raise(run, Company.CROWN, 20)
	var context := _context(run)
	var attacks: Array = []
	for index in 3:
		attacks.append(_attack(_raise(run, Company.REBEL, 200), defender))

	var fought := Battle.resolve_all(attacks, run.companies, run.map, context)
	assert_eq(fought.size(), 3, "three attacks resolved as %d battles" % fought.size())
	var suffered := PackedFloat32Array()
	for entry in fought:
		suffered.append(float((entry as Dictionary)["defender_casualties"]))
	for index in range(1, suffered.size()):
		assert_true(suffered[index] > suffered[index - 1],
			"the defender did not weaken as they came: %s" % [suffered])
	assert_true(defender.size < 20_000, "three battles cost him nobody")


func test_a_company_surrounded_can_be_destroyed_in_a_single_month() -> void:
	# 🔒 §7 says so in as many words, and **that is the design.**
	var run := _run()
	var defender := _raise(run, Company.CROWN, 4)
	var context := _context(run)
	var attacks: Array = []
	for index in 3:
		attacks.append(_attack(_raise(run, Company.REBEL, 400), defender))

	var fought := Battle.resolve_all(attacks, run.companies, run.map, context)
	assert_true(defender.is_empty(), "he held out with %d men" % defender.size)
	# **The later attacks find nobody**, which is no rout and no pursuit: there
	# is simply nothing left to fight.
	assert_eq(fought.size(), 1,
		"somebody went on fighting a company that no longer existed")


func test_the_order_is_faction_then_creation_and_never_the_list() -> void:
	var run := _run()
	var defender := _raise(run, Company.CROWN, 40)
	var context := _context(run)
	var native := _raise(run, Company.NATIVE, 20)
	var older_rebel := _raise(run, Company.REBEL, 20)
	var rival := _raise(run, Company.RIVAL, 20)
	var newer_rebel := _raise(run, Company.REBEL, 20)

	# Offered in the wrong order on purpose.
	Battle.resolve_all([
		_attack(newer_rebel, defender), _attack(native, defender),
		_attack(rival, defender), _attack(older_rebel, defender),
	], run.companies, run.map, context)

	var order := PackedStringArray()
	for event in run.log.of_type(Battle.EVENT_FOUGHT):
		order.append(String(event.payload.get("attacker", "")))
	assert_eq(order, PackedStringArray([
		String(older_rebel.id), String(newer_rebel.id),
		String(rival.id), String(native.id),
	]), "they attacked in the order %s" % [order])


func test_the_same_seed_resolves_a_month_identically() -> void:
	var seen: Array = []
	for pass_index in 2:
		var run := _run()
		var defender := _raise(run, Company.CROWN, 12)
		var context := _context(run)
		var attacks: Array = []
		for index in 3:
			attacks.append(_attack(_raise(run, Company.REBEL, 30), defender))
		Battle.resolve_all(attacks, run.companies, run.map, context)
		seen.append({"size": defender.size, "owed": defender.casualties_owed})
	assert_almost_eq(float(seen[1]["owed"]), float(seen[0]["owed"]), 0.000001,
		"two runs of one seed left the defender differently: %s" % [seen])
	assert_eq(seen[1]["size"], seen[0]["size"])
