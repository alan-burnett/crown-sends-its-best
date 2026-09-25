extends TestCase

## Population counts people (#426, `docs/mechanics/population.md` §1–§5).
##
## 🔒 **A town holds people, a thousand to what one used to be**, and experts
## are individuals among them. What these pin is the arithmetic of the change —
## a tile per thousand, a rate per thousand, shares that no longer round to
## nothing, experts that stay rare — never a tuning figure.

const SEED: int = 4260

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


func _town(workers: int) -> Town:
	var town := Town.new(&"t", "Testbury", Vector2i(4, 4))
	town.workers = workers
	return town


# --- 🔒 A tile per thousand ------------------------------------------------------

func test_a_town_works_a_tile_per_thousand_workers_floored() -> void:
	assert_eq(_town(1_999).workable_tiles(), 1, "1,999 workers work one tile (§3)")
	assert_eq(_town(2_000).workable_tiles(), 2)
	assert_eq(_town(999).workable_tiles(), 0)


func test_the_first_town_works_as_many_tiles_as_it_ever_did() -> void:
	var run := RunState.new_run(SEED)
	var town: Town = run.colony.in_order()[0]
	assert_eq(town.workers, RunState.STARTING_WORKERS)
	assert_eq(town.workable_tiles(), RunState.STARTING_WORKERS / Population.THOUSAND,
		"the landing party works a tile per thousand of them")


# --- 🔒 A rate per thousand -----------------------------------------------------------

func test_a_rate_per_head_is_a_rate_per_thousand_people() -> void:
	# §4: *one food per head a month* reads as one food per thousand people.
	assert_almost_eq(Population.of(1.0, 12_000.0), 12.0)
	assert_almost_eq(_town(12_000).mouths(), 12.0)


func test_livestock_is_counted_by_the_head_and_priced_per_thousand() -> void:
	# §2 and §4: a horse per man stays a horse per man; a horse's price is a
	# thousandth of what the data says a thousand of them cost.
	assert_almost_eq(Population.amount_for(&"horses", 1.0, 3_000.0), 3_000.0)
	assert_almost_eq(Population.amount_for(&"guns", 1.0, 3_000.0), 3.0)
	var kind := ResourceCatalogue.get_kind(&"horses")
	assert_almost_eq(ResourceCatalogue.price_of(&"horses") * Population.THOUSAND, kind.price)


func test_a_head_nobody_wants_is_worth_a_thousandth_of_a_unit_nobody_wants() -> void:
	# The surplus floor is a town worth like any other (#430): absolute, it made
	# an unwanted sheep worth many times its own base.
	var nothing := DesiredStock.new()
	assert_almost_eq(Valuation.town(&"sheep", nothing, 1_000_000.0) * Population.THOUSAND,
		Valuation.town(&"wood", nothing, 1_000_000.0), 0.0001)
	assert_true(Valuation.town(&"sheep", nothing, 1_000_000.0) <= ResourceCatalogue.town_base(&"sheep"),
		"a sheep nobody wanted was worth more than a sheep")


# --- 🔒 Shares no longer round to nothing ---------------------------------------------

func test_a_share_of_thousands_loses_nobody_to_rounding() -> void:
	# §1's example: a share of an odd number of people is a number of people,
	# not a number of thousands rounded down.
	var town := _town(39_999)
	assert_eq(Expedition.people_for(town, &"lean_expedition"),
		int(floorf(39_999.0 * Objective.share_of_people(&"lean_expedition"))))


# --- 🔒 Experts stay rare ------------------------------------------------------------------

func test_an_expert_is_one_man_among_thousands_of_births() -> void:
	# §5: the expert share of births falls by a thousand, or a learned town
	# would raise hundreds a month.
	var town := _town(12_000)
	town.education = 1_000.0
	assert_true(Experts.share_of_growth(town) < 1.0 / float(Population.THOUSAND),
		"more than one birth in a thousand becomes an expert: %f" % Experts.share_of_growth(town))


func test_an_expert_is_one_man_among_thousands_of_settlers() -> void:
	var run := RunState.new_run(SEED)
	var town: Town = run.colony.in_order()[0]
	town.quality_of_life = 1.0
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	var due := Immigration.due(town, context)
	assert_true(float(due["workers"]) > 0.0, "a happy town drew nobody, so this proves nothing")
	assert_true(float(due["experts"]) < float(due["workers"]) / float(Population.THOUSAND) * 2.0,
		"settlers bring experts by the hundred: %s" % [due])


# --- 🔒 What the player reads did not move --------------------------------------------------

func test_a_head_count_reads_as_it_did_before_the_change() -> void:
	# The display's thousand moved into the sim: *12,000 settlers* still reads so.
	assert_eq(Config.PEOPLE_PER_POPULATION, 1)
	assert_eq(Figures.people(12_000), "12,000")
	# A painting says it in words since #437 (`population.md` §7), and the
	# thousand is still in the sim: twelve thousand, not twelve.
	assert_eq(CutsceneParams.written(12_000, "people", null), "some twelve thousand")


# --- 🔒 Saves from before are refused -----------------------------------------------------

func test_the_save_version_moved() -> void:
	# `CLAUDE.md`: during development an older save is refused, not migrated —
	# and a save counted in thousands read as people would be a colony of twelve.
	assert_true(RunState.SAVE_VERSION >= 2)
