extends TestCase

## Companies on the map, before anything fights (#211,
## `docs/mechanics/battles.md` §1, §2, §3, §7, §8).
##
## 🔒 **Victualled continuously, equipped once.** A company launches with its
## arms and never resupplies them and never gains men — **it only dwindles.**
## There is deliberately no path that adds to either, and this file asks for one.
##
## 🔒 **Losses preserve ratios**, which is what makes a fully horsed company stay
## cavalry however badly it is mauled. There is no unit type and no flag, only a
## threshold on a ratio that attrition cannot move — and a dev who made losses
## take men without taking arms would make a mauled company *better* equipped
## than it started.
##
## 🔒 **A town cannot disband its way out of famine** (§3). If it cannot cover a
## company it sends nothing and that company goes unsupported, which costs the
## company and not the purse. Militia are a commitment, not a lever.
##
## 🔒 **Order is fixed and never incidental** (§7): factions in a set sequence,
## then earliest-created first, by the ordinal assigned at instantiation. It needs
## no tie-break and no seeded roll.
##
## 🔒 **And nothing here fights.** Battle resolution, casualties, forts and
## terrain defence are M6.

const SEED: int = 7741

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


## A company of `size` men, fully horsed unless told otherwise.
func _raise(
	run: RunState,
	size: int = 20,
	arms: Dictionary = {},
	allegiance: StringName = Company.COLONIAL,
	support: StringName = &"",
) -> Company:
	var town := run.colony.in_order()[0]
	return run.companies.raise_company(
		allegiance,
		size,
		arms,
		town.id if String(support).is_empty() else support,
		town.at,
		_context(run),
	)


func _horsed(size: int) -> Dictionary:
	var out: Dictionary = {}
	for resource in Company.armed_resources():
		out[String(resource)] = Company.want_per_head(StringName(resource)) * float(size)
	return out


# --- 🔒 The object, and what it is made of ----------------------------------

func test_a_company_carries_the_six_things_section_one_lists() -> void:
	var run := _run()
	var company := _raise(run, 30, _horsed(30))
	company.commander = &"commander_one"
	company.order = &"hold_the_town"

	assert_eq(company.size, 30)
	assert_true(company.held(&"guns") > 0.0, "it launched with no guns")
	assert_eq(company.support, run.colony.in_order()[0].id)
	assert_eq(company.commander, &"commander_one")
	assert_eq(company.order, &"hold_the_town")
	assert_eq(company.allegiance, Company.COLONIAL)


func test_allegiance_covers_all_five_and_the_order_names_them_all() -> void:
	# §12.3's locks are filters on this field and nothing else, so a faction the
	# order forgot would be one that never acted.
	for faction in [Company.COLONIAL, Company.CROWN, Company.REBEL,
			Company.RIVAL, Company.NATIVE]:
		assert_true(Company.FACTIONS.has(faction),
			"'%s' is an allegiance the resolution order does not name" % faction)
	assert_eq(Company.FACTIONS.size(), 5)


# --- 🔒 Arms are a supply ratio, and surplus does nothing -------------------

func test_arms_are_a_share_of_what_the_men_want() -> void:
	var run := _run()
	var half := _horsed(20)
	for resource in half:
		half[resource] = float(half[resource]) * 0.5
	var company := _raise(run, 20, half)

	for resource in Company.armed_resources():
		assert_almost_eq(company.armed_share(StringName(resource)), 0.5, 0.001,
			"half the %s read as %f" % [resource, company.armed_share(StringName(resource))])


func test_surplus_does_nothing() -> void:
	# 🔒 §2, stated directly. A company with ten times the guns is not ten times
	# the company, and the same shape `quality-of-life.md` uses for pleasure.
	var run := _run()
	var heaps := _horsed(20)
	for resource in heaps:
		heaps[resource] = float(heaps[resource]) * 10.0
	var company := _raise(run, 20, heaps)
	assert_almost_eq(company.armed_share(&"guns"), 1.0, 0.001,
		"ten times the guns read as more than fully armed")


func test_a_resource_nobody_wants_is_not_a_shortage() -> void:
	var run := _run()
	var company := _raise(run, 20, _horsed(20))
	assert_almost_eq(company.armed_share(&"rum"), 1.0, 0.001,
		"a company was judged short of rum")


func test_nothing_adds_to_the_arms_or_to_the_men() -> void:
	# 🔒 **The acceptance line, asked of the type rather than of one run.** §2's
	# rule is only true if there is no method that could break it, so this walks
	# what a `Company` can be asked to do and refuses anything that grows it.
	var company := Company.new(&"probe", 1)
	var growers := PackedStringArray()
	for entry in company.get_method_list():
		var name := String(entry["name"])
		for word in ["reinforce", "resupply", "recruit", "rearm", "equip", "gain"]:
			if name.contains(word):
				growers.append(name)
	assert_empty(growers,
		"a company can be made larger by: %s" % ", ".join(growers))


# --- 🔒 Cavalry is a threshold, and it survives being mauled ---------------

func test_a_fully_horsed_company_is_cavalry_and_moves_twice() -> void:
	var run := _run()
	var mounted := _raise(run, 20, _horsed(20))
	assert_true(mounted.is_cavalry(), "a fully horsed company is not cavalry")
	assert_eq(mounted.tiles_this_month(), 2, "cavalry marches at a walk")
	assert_eq(mounted.attacks_this_month(), 2, "cavalry strikes once")


func test_a_company_short_of_horses_is_not_cavalry() -> void:
	var run := _run()
	var arms := _horsed(20)
	arms["horses"] = float(arms["horses"]) * 0.9
	var foot := _raise(run, 20, arms)
	assert_false(foot.is_cavalry(), "nine horses in ten made cavalry")
	assert_eq(foot.tiles_this_month(), 1)


func test_a_mauled_cavalry_company_is_still_cavalry() -> void:
	# 🔒 §8's whole point. Losses preserve ratios, so the threshold cannot be
	# crossed by attrition — a company of four that started as forty is still
	# mounted.
	var run := _run()
	var mounted := _raise(run, 40, _horsed(40))
	var context := _context(run)
	for round in 6:
		mounted.lose(0.25, &"mauled", context)
	assert_true(mounted.size < 40 and mounted.size > 0,
		"the company was not actually reduced: %d" % mounted.size)
	assert_true(mounted.is_cavalry(),
		"a mauled cavalry company dismounted: %d men, %f horsed"
			% [mounted.size, mounted.armed_share(&"horses")])


func test_losses_take_the_same_share_of_everything_carried() -> void:
	# `CLAUDE.md`: a company under arms loses a share of its people **and the
	# same share of its stores**. Not the men alone, or a mauled company would be
	# better equipped than it started.
	var run := _run()
	var company := _raise(run, 40, _horsed(40))
	var guns_before := company.held(&"guns")
	var share_before := company.armed_share(&"guns")

	company.lose(0.5, &"mauled", _context(run))
	assert_eq(company.size, 20, "half of forty is %d" % company.size)
	assert_true(company.held(&"guns") < guns_before,
		"the men were lost and their muskets walked home by themselves")
	assert_almost_eq(company.armed_share(&"guns"), share_before, 0.001,
		"the ratio moved: %f against %f"
			% [company.armed_share(&"guns"), share_before])


func test_a_share_always_costs_at_least_one_man() -> void:
	# A company of eight losing six per cent must not be immortal by rounding.
	var run := _run()
	var small := _raise(run, 8, _horsed(8))
	assert_eq(small.lose(Company.attrition(), &"unsupported", _context(run)), 1,
		"a small company took no losses at all")


func test_a_company_can_be_lost_entirely_and_says_so() -> void:
	var run := _run()
	var company := _raise(run, 4, _horsed(4))
	company.lose(1.0, &"wiped_out", _context(run))
	assert_true(company.is_empty())
	assert_eq(run.log.of_type(Company.EVENT_DESTROYED).size(), 1,
		"a company was destroyed and nothing said so")

	run.companies.bury_the_dead()
	assert_empty(run.companies.list, "an empty company was still on the map")


# --- 🔒 Support, and who eats first -----------------------------------------

## A town holding exactly this and nothing else.
##
## **The herd goes too.** Stock eat, and a town that would otherwise go hungry
## eats them instead (SPEC §12.2) — which is correct and would make the
## arithmetic below depend on whatever livestock the seed happened to give it.
func _fed(run: RunState, held: Dictionary) -> Town:
	var town := run.colony.in_order()[0]
	for resource in ResourceCatalogue.ids():
		town.stockpile[String(resource)] = 0.0
	town.livestock.clear()
	for resource in held:
		town.store(StringName(resource), float(held[resource]))
	return town


## Reckon and Consume, which is where victualling actually happens.
##
## **The two real phases rather than the whole month**, so a failure here names
## the thing that went wrong rather than whatever Exchange happened to buy.
func _colony_month(run: RunState) -> void:
	var context := _context(run)
	context.run_seed = run.run_seed
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	month.run(run.colony, context)


func test_a_supporting_town_counts_company_men_as_mouths() -> void:
	var run := _run()
	var company := _raise(run, 10, _horsed(10))
	var town := _fed(run, {"food": 400.0, "clothing": 200.0})
	var before := town.held(&"food")

	_colony_month(run)
	assert_eq(company.supplied_month, run.world.month,
		"the town it belongs to did not feed it")
	assert_true(town.held(&"food") < before, "the food came from nowhere")


func test_a_town_that_cannot_cover_it_sends_nothing() -> void:
	# 🔒 §3. Not half rations — a third state the doc does not have, and one that
	# would let a town quietly meter its militia down.
	var run := _run()
	var company := _raise(run, 400, _horsed(400))
	var town := _fed(run, {"food": 30.0, "clothing": 10.0})
	var before := town.held(&"food")
	var the_towns_own := float(town.population()) * ColonyNeeds.per_head(&"food")

	_colony_month(run)
	assert_eq(company.supplied_month, -1, "a town covered a company it cannot feed")
	# **Asked before anything is taken**, so the only thing that left the
	# storehouse was the townspeople's own dinner. Taking what there was and then
	# finding the cloth short would leave the town poorer and the company
	# unsupported anyway, which is the worst of both.
	assert_almost_eq(town.held(&"food"), before - the_towns_own, 0.001,
		"the town spent its stores on a company it could not cover anyway")


func test_the_townspeople_eat_before_the_soldiers() -> void:
	# 🔒 A governor cannot starve his citizens to feed his soldiers (§3), and it
	# is the order the phases run in that makes it true.
	var run := _run()
	var town := run.colony.in_order()[0]
	var people := float(town.population())
	var men := 10
	var company := _raise(run, men, _horsed(men))
	var soldiers_eat := float(men) * ColonyNeeds.per_head(&"food")

	# 🔒 **Enough for either, and not for both**, which is the only arrangement
	# that can tell the two orders apart. Feeding the soldiers first would cover
	# them — there is plainly enough in the storehouse — and leave the town short;
	# feeding the town first leaves too little and the company goes without.
	_fed(run, {
		"food": people * ColonyNeeds.per_head(&"food") + soldiers_eat * 0.5,
		"clothing": (people + float(men)) * ColonyNeeds.per_head(&"clothing") + 1.0,
	})
	assert_true(town.held(&"food") > soldiers_eat,
		"the fixture cannot distinguish the two orders: %f in store against %f wanted"
			% [town.held(&"food"), soldiers_eat])

	_colony_month(run)
	assert_eq(town.months_hungry, 0,
		"the townspeople went hungry so that the militia could eat")
	assert_eq(company.supplied_month, -1, "the company ate first")


func test_a_crown_company_is_never_the_colonys_burden() -> void:
	# 🔒 `the-marshal.md` §3, locked. There is no state in which Crown troops
	# depend on the colony, so the filter is on support and not on where they
	# happen to be standing.
	var run := _run()
	var crown := _raise(run, 50, _horsed(50), Company.CROWN, Company.SUPPORTED_BY_CROWN)
	var town := _fed(run, {"food": 500.0, "clothing": 300.0})

	assert_empty(run.companies.supported_by(town.id),
		"a Crown company was on the town's books")
	assert_true(crown.is_supplied(run.world.month),
		"a Crown company was waiting on the colony to feed it")

	var before := town.held(&"food")
	_colony_month(run)
	var eaten := before - town.held(&"food")
	assert_true(eaten < float(crown.size) * ColonyNeeds.per_head(&"food"),
		"the town victualled the Crown's troops: %f gone" % eaten)


# --- 🔒 Unsupported: it bleeds, and it recovers -----------------------------

func _reckon(run: RunState) -> void:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


func test_an_unsupported_company_loses_effectiveness_and_men() -> void:
	var run := _run()
	var company := _raise(run, 40, _horsed(40))
	assert_almost_eq(company.effectiveness(), 1.0, 0.001)

	_reckon(run)
	assert_true(company.effectiveness() < 1.0,
		"a company nobody fed is as good as one that ate")
	assert_true(company.size < 40, "it went without and lost nobody")
	assert_eq(run.log.of_type(Company.EVENT_UNSUPPORTED).size(), 1,
		"it went hungry and nothing said so")


func test_it_bleeds_every_month_it_goes_without() -> void:
	var run := _run()
	var company := _raise(run, 100, _horsed(100))
	var sizes := PackedInt32Array()
	for month in 4:
		run.world.month = month
		_reckon(run)
		sizes.append(company.size)
	for index in range(1, sizes.size()):
		assert_true(sizes[index] < sizes[index - 1],
			"it stopped bleeding: %s" % [sizes])


func test_it_recovers_the_moment_supply_resumes() -> void:
	# §3, and the whole of the recovery rule: effectiveness reads
	# `unsupported_months` and nothing else, so feeding it is the recovery.
	var run := _run()
	var company := _raise(run, 40, _horsed(40))
	_reckon(run)
	assert_true(company.effectiveness() < 1.0)

	company.was_supplied(run.world.month)
	assert_almost_eq(company.effectiveness(), 1.0, 0.001,
		"a company fed again was still starving")


func test_a_company_that_ate_does_not_bleed() -> void:
	var run := _run()
	var company := _raise(run, 40, _horsed(40))
	company.was_supplied(run.world.month)
	_reckon(run)
	assert_eq(company.size, 40, "a fed company lost men")
	assert_empty(run.log.of_type(Company.EVENT_UNSUPPORTED))


# --- 🔒 Order of resolution -------------------------------------------------

func test_factions_go_in_sequence_and_the_earliest_raised_goes_first() -> void:
	var run := _run()
	var context := _context(run)
	var town := run.colony.in_order()[0]
	# Raised out of faction order on purpose.
	var native := run.companies.raise_company(
		Company.NATIVE, 10, {}, Company.SUPPORTED_BY_CROWN, town.at, context)
	var second_colonial := run.companies.raise_company(
		Company.COLONIAL, 10, {}, town.id, town.at, context)
	var rebel := run.companies.raise_company(
		Company.REBEL, 10, {}, town.id, town.at, context)
	var first_crown := run.companies.raise_company(
		Company.CROWN, 10, {}, Company.SUPPORTED_BY_CROWN, town.at, context)

	var order := run.companies.in_resolution_order()
	var ids := PackedStringArray()
	for entry in order:
		ids.append(String((entry as Company).id))
	assert_eq(ids, PackedStringArray([
		String(second_colonial.id), String(first_crown.id),
		String(rebel.id), String(native.id),
	]), "the order was %s" % [ids])


func test_two_of_one_faction_go_by_the_number_they_were_given() -> void:
	var run := _run()
	var context := _context(run)
	var town := run.colony.in_order()[0]
	var older := run.companies.raise_company(
		Company.REBEL, 10, {}, town.id, town.at, context)
	var newer := run.companies.raise_company(
		Company.REBEL, 10, {}, town.id, town.at, context)
	assert_true(older.ordinal < newer.ordinal)

	var order := run.companies.in_resolution_order()
	assert_eq((order[0] as Company).id, older.id, "the newer rebel company went first")


func test_a_number_is_never_handed_out_twice() -> void:
	# 🔒 The ordinal is the identity, not the index. Companies leave the list when
	# they are wiped out, and a position in an array is not stable.
	var run := _run()
	var context := _context(run)
	var town := run.colony.in_order()[0]
	var first := run.companies.raise_company(
		Company.REBEL, 4, {}, town.id, town.at, context)
	first.lose(1.0, &"wiped_out", context)
	run.companies.bury_the_dead()

	var second := run.companies.raise_company(
		Company.REBEL, 10, {}, town.id, town.at, context)
	assert_ne(second.ordinal, first.ordinal,
		"a destroyed company's number was handed to its successor")
	assert_ne(second.id, first.id)


func test_the_order_is_the_same_twice_over_on_one_seed() -> void:
	var first := PackedStringArray()
	var again := PackedStringArray()
	for pass_index in 2:
		var run := _run()
		var context := _context(run)
		var town := run.colony.in_order()[0]
		for faction in [Company.RIVAL, Company.COLONIAL, Company.RIVAL, Company.CROWN]:
			run.companies.raise_company(faction, 10, {}, town.id, town.at, context)
		for entry in run.companies.in_resolution_order():
			var into := first if pass_index == 0 else again
			into.append(String((entry as Company).id))
	assert_eq(again, first, "the same seed produced two different orders")


# --- Movement ---------------------------------------------------------------

func _march(run: RunState) -> void:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.on_phase(WorldPhase.MOVEMENT, run.world, run.log, run.streams)


## The march itself, asked of the company rather than of the driver.
##
## **Whether it marches at all is a decision** (#221) and belongs to
## `test_cavalry` with the rest of the month; what is asked here is how far a
## company gets once somebody has decided it is going.
func test_a_company_marches_toward_its_destination_over_months() -> void:
	var run := _run()
	var company := _raise(run, 20, {})
	var start := company.at
	var context := _context(run)

	company.advance(start + Vector2i(4, 0), context)
	assert_eq(company.at, start + Vector2i(1, 0), "it did not march")
	company.advance(start + Vector2i(4, 0), context)
	assert_eq(company.at, start + Vector2i(2, 0))
	assert_eq(run.log.of_type(Company.EVENT_MOVED).size(), 2,
		"it moved and the map was not told")


func test_cavalry_covers_twice_the_ground() -> void:
	var run := _run()
	var mounted := _raise(run, 20, _horsed(20))
	var start := mounted.at

	mounted.advance(start + Vector2i(6, 0), _context(run))
	assert_eq(mounted.at, start + Vector2i(2, 0),
		"cavalry marched at a walk: %s" % [mounted.at])


func test_a_company_with_nowhere_to_go_stands_still() -> void:
	var run := _run()
	var company := _raise(run, 20, {})
	var start := company.at
	_march(run)
	assert_eq(company.at, start, "a company with no orders wandered off")
	assert_empty(run.log.of_type(Company.EVENT_MOVED))


func test_it_stops_when_it_arrives() -> void:
	var run := _run()
	var company := _raise(run, 20, {})
	var context := _context(run)
	var toward := company.at + Vector2i(1, 0)
	company.advance(toward, context)
	var arrived := company.at
	company.advance(toward, context)
	assert_eq(company.at, arrived, "it marched past its destination")


# --- 🔒 Save and load -------------------------------------------------------

func test_a_company_mid_march_survives_the_save() -> void:
	# Ironman, one save per run (SPEC §16.2). A company that forgot where it was
	# going, or how many horses it had, would be a different company.
	var run := _run()
	var company := _raise(run, 33, _horsed(33))
	company.destination = company.at + Vector2i(5, 2)
	company.commander = &"commander_one"
	company.order = &"relieve_the_town"
	_march(run)
	_reckon(run)

	var restored := Companies.from_dict(run.companies.to_dict())
	var back := restored.find(company.id)
	assert_true(back != null, "the company was not in the save at all")
	assert_eq(back.size, company.size)
	assert_eq(back.at, company.at, "it forgot where it was")
	assert_eq(back.destination, company.destination, "it forgot where it was going")
	assert_eq(back.ordinal, company.ordinal, "it lost its place in the order")
	assert_eq(back.commander, company.commander)
	assert_eq(back.order, company.order)
	assert_eq(back.unsupported_months, company.unsupported_months)
	assert_almost_eq(back.armed_share(&"horses"), company.armed_share(&"horses"), 0.001,
		"it came back a different sort of company")
	assert_eq(restored.raised, run.companies.raised,
		"the count of raisings did not survive, so a number could be reused")


func test_the_whole_run_round_trips_with_companies_in_it() -> void:
	var run := _run()
	_raise(run, 20, _horsed(20), Company.REBEL)
	var restored := RunState.from_dict(run.to_dict())
	assert_eq(restored.companies.list.size(), 1,
		"the companies did not survive the run's own save")
	assert_eq((restored.companies.list[0] as Company).allegiance, Company.REBEL)
