extends TestCase

## The decisions that shape a run before it begins (#79, SPEC §5, §6.1, §16.1).
##
## 🔒 **The same seed and the same choices always produce the same run.** §16.1
## locks seeded generation, so everything that shapes a colony passes through
## `RunSetup` — a decision made anywhere else would be one a saved run could not
## reproduce.
##
## 🔒 **Name, title, portrait and colour are flavour.** SPEC §5 is explicit that
## they have no mechanical effect. They exist so letters can address the man, and
## `test_the_pcs_name_changes_nothing_at_all` is what keeps them that way.

const SEED: int = 20_260_918

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


func _setup() -> RunSetup:
	var setup := RunSetup.new()
	setup.seed_value = SEED
	return setup


func _run(setup: RunSetup) -> RunState:
	var run := RunState.from_setup(setup)
	ContactRoster.load_into(run, content)
	return run


func _first(run: RunState) -> Town:
	var towns := run.colony.in_order()
	return null if towns.is_empty() else towns[0]


# --- 🔒 Same seed, same choices, same run -----------------------------------

func test_the_same_seed_and_choices_produce_an_identical_run() -> void:
	var one := _run(_setup())
	var other := _run(_setup())
	assert_eq(other.world.state_hash(), one.world.state_hash(),
		"two runs from the same seed and the same choices differed")
	assert_eq(_first(other).at, _first(one).at, "the town was founded somewhere else")


func test_a_different_seed_produces_a_different_run() -> void:
	# The pair: without it the test above passes just as well if every run is
	# the same run.
	var here := _setup()
	var elsewhere := _setup()
	elsewhere.seed_value = SEED + 1
	assert_true(_first(_run(elsewhere)).at != _first(_run(here)).at,
		"two seeds put the colony on the same tile")


func test_a_different_choice_produces_a_different_run() -> void:
	var first := _setup()
	var second := _setup()
	second.site_choice = 2
	assert_true(_first(_run(second)).at != _first(_run(first)).at,
		"choosing a different site put the town in the same place")


# --- 🔒 The flavour is flavour ----------------------------------------------

func test_the_pcs_name_changes_nothing_at_all() -> void:
	# **SPEC §5.** A run made by a man called one thing must be identical to a run
	# made by a man called another, down to the state hash.
	var plain := _setup()
	var grand := _setup()
	grand.pc_name = "Marlborough-Vane"
	grand.pc_title = "Lord Proprietor"
	grand.portrait = "portrait_stern"
	grand.colour = Color(0.9, 0.1, 0.1)

	var one := _run(plain)
	var other := _run(grand)
	assert_eq(other.world.state_hash(), one.world.state_hash(),
		"changing the PC's name changed the world")
	assert_eq(_first(other).at, _first(one).at)
	assert_almost_eq(_first(other).held(&"food"), _first(one).held(&"food"), 0.001)
	assert_eq(_first(other).workers, _first(one).workers)


func test_the_letters_address_him_by_it() -> void:
	# The one thing flavour is for. Without this the name is a field nothing
	# reads, which is the fault #139 gates against.
	var setup := _setup()
	setup.pc_name = "Marlborough-Vane"
	setup.pc_title = "Lord Proprietor"
	var context := LetterContext.new(WorldValues.initial_state(), null, &"dutiful")
	context.pc = setup

	assert_eq(String(ColonyParamSources.pc({"field": "name"}, context)), "Marlborough-Vane")
	assert_eq(String(ColonyParamSources.pc({"field": "title"}, context)), "Lord Proprietor")


# --- 🔒 The perk does what it says ------------------------------------------

func test_the_first_day_grants_the_extra_warning() -> void:
	# #68 gave `CrownRefusal` a grace and nothing could switch it on. This is
	# what switches it on.
	assert_true(_run(_setup()).refusal.has_grace,
		"the only perk in the game did nothing")


func test_without_it_there_is_no_grace() -> void:
	var setup := _setup()
	setup.perk = &""
	assert_false(_run(setup).refusal.has_grace,
		"a run with no perk was given one anyway")


func test_only_the_one_perk_and_no_quirks_are_offered() -> void:
	# SPEC §6.1: at game start exactly one perk is unlocked and no quirks are.
	# M7 unlocks more, and **adding entries must never mean adding code**.
	assert_eq(_setup().quirks.size(), 0, "a quirk was unlocked at game start")
	assert_eq(String(_setup().perk), String(RunSetup.PERK_FIRST_DAY))


# --- 🔒 The mandate is the founding governor's starting intent --------------

func test_the_mandate_sets_what_the_first_governor_wants() -> void:
	for mandate in RunSetup.MANDATES:
		var setup := _setup()
		setup.mandate = mandate
		var run := _run(setup)
		assert_eq(String(_first(run).intent), String(mandate),
			"the Crown said %s and the governor wanted something else" % mandate)


func test_the_world_and_the_town_agree_about_it() -> void:
	# The mandate consideration reads the world; the governor reads the town.
	# **They must never disagree**, or a governor would be pulled towards a goal
	# he was never given.
	var setup := _setup()
	setup.mandate = GovernorIntent.DEFENCE
	var run := _run(setup)
	assert_eq(String(run.world.get_value(WorldValues.MANDATE, "")),
		String(_first(run).intent),
		"the Crown's stated goal and the governor's starting intent differed")


func test_every_offered_mandate_is_a_real_intent() -> void:
	for mandate in RunSetup.MANDATES:
		assert_true(GovernorIntent.is_intent(mandate),
			"'%s' is offered as a mandate and is not an intent" % mandate)
	assert_false(RunSetup.MANDATES.has(GovernorIntent.SEDITION),
		"the Crown offered to found a colony for the purpose of rebelling against it")


# --- 🔒 The split is visible in the opening position ------------------------

func test_taking_the_grant_in_people_puts_more_hands_on_the_ground() -> void:
	var people := _setup()
	people.split = RunSetup.SPLIT_PEOPLE
	var stores := _setup()
	stores.split = RunSetup.SPLIT_STORES

	assert_true(_first(_run(people)).workers > _first(_run(stores)).workers,
		"taking the grant in people brought no more people")


func test_taking_it_in_stores_fills_the_warehouse() -> void:
	var stores := _setup()
	stores.split = RunSetup.SPLIT_STORES
	var people := _setup()
	people.split = RunSetup.SPLIT_PEOPLE

	assert_true(_first(_run(stores)).held(&"food") > _first(_run(people)).held(&"food"),
		"taking the grant in stores brought no more stores")


func test_every_split_is_offered_and_each_does_something() -> void:
	var seen: Dictionary = {}
	for split in RunSetup.SPLITS:
		var setup := _setup()
		setup.split = split
		var town := _first(_run(setup))
		seen[String(split)] = "%d|%f" % [town.workers, town.held(&"food")]
	assert_eq(seen.size(), RunSetup.SPLITS.size())
	assert_true(String(seen[String(RunSetup.SPLIT_PEOPLE)])
		!= String(seen[String(RunSetup.SPLIT_STORES)]),
		"two different splits opened the colony in the same position")


# --- 🔒 The sites are a choice ----------------------------------------------

func test_three_sites_are_offered_and_they_differ() -> void:
	# Three neighbouring tiles of the same good ground is not a decision. They
	# are spread across the ranked list so one is rich, one middling, one hard.
	var offered := RunSetup.sites_for(SEED)
	assert_eq(offered.size(), RunSetup.SITES_OFFERED)
	var distinct: Dictionary = {}
	for at in offered:
		distinct[str(at)] = true
	assert_eq(distinct.size(), offered.size(), "two of the offered sites were the same tile")


func test_the_same_seed_offers_the_same_sites() -> void:
	assert_eq(str(RunSetup.sites_for(SEED)), str(RunSetup.sites_for(SEED)),
		"the choice on offer changed between asking twice")


func test_an_out_of_range_choice_lands_somewhere_real() -> void:
	# A save from a build that offered more sites must not put a town in the sea.
	var setup := _setup()
	setup.site_choice = 99
	assert_true(_first(_run(setup)) != null, "a stale choice founded no town at all")


# --- 🔒 It survives a reload ------------------------------------------------

func test_the_setup_survives_a_round_trip() -> void:
	var setup := _setup()
	setup.pc_name = "Marlborough-Vane"
	setup.mandate = GovernorIntent.SETTLEMENT
	setup.split = RunSetup.SPLIT_GOLD
	setup.site_choice = 2

	var restored := RunSetup.from_dict(setup.to_dict())
	assert_eq(restored.pc_name, setup.pc_name)
	assert_eq(String(restored.mandate), String(setup.mandate))
	assert_eq(String(restored.split), String(setup.split))
	assert_eq(restored.site_choice, setup.site_choice)
	assert_eq(restored.seed_value, setup.seed_value)
