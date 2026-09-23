extends TestCase

## Who arrives, and what they bring (#170, `docs/mechanics/immigration.md`).
##
## Immigration did not exist, and it is the single largest reason the balance
## harness found the colony static in #90 — population crawled from twelve to
## sixteen over five years because nobody ever came.

const SEED: int = 3311

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


func _town(id: StringName = &"ashmere", quality: float = 0.9, workers: int = 12) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = workers
	town.quality_of_life = quality
	town.receive_gold(5_000.0)
	return town


func _context(towns: Array) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	return context


## Run a year of arrivals and report how many landed.
func _over_a_year(town: Town, others: Array = []) -> int:
	var context := _context([town] + others)
	var before := town.population()
	for month in 12:
		context.state.month = month
		Immigration.arrive(town, context)
	return town.population() - before


# --- 🔒 The pull is steep -----------------------------------------------------

func test_nobody_emigrates_to_a_miserable_place() -> void:
	var wretched := _town(&"ashmere", 0.1)
	assert_almost_eq(Immigration.pull_of(wretched), 0.0, 0.0001,
		"settlers crossed an ocean for a town nobody would live in")
	assert_eq(_over_a_year(wretched), 0, "and a year of them arrived anyway")


func test_a_thriving_town_draws_people() -> void:
	assert_true(_over_a_year(_town(&"ashmere", 0.95)) > 0,
		"a year of a thriving colony drew nobody at all")


func test_the_pull_is_not_linear() -> void:
	# 🔒 Near zero below a floor and rising sharply above it, so a good town gets
	# a virtuous circle and a bad one a stagnation that letters can break.
	var low := Immigration.pull_of(_town(&"a", 0.5))
	var mid := Immigration.pull_of(_town(&"b", 0.7))
	var high := Immigration.pull_of(_town(&"c", 0.9))
	assert_true(mid - low < high - mid,
		"appeal climbed as fast at the bottom as at the top, so it is linear")


# --- 🔒 No pool, and no competition ------------------------------------------

func test_two_identical_towns_receive_identical_arrivals() -> void:
	# Settlers are not divided. A town worth coming to gets people whether or not
	# its neighbour does — a pool would make a good town's reward depend on
	# somebody else's failure.
	var alone := _town(&"ashmere", 0.9)
	var crowded_one := _town(&"bellhaven", 0.9)
	var neighbours: Array = []
	for i in 4:
		neighbours.append(_town(StringName("other%d" % i), 0.95))

	assert_eq(_over_a_year(alone), _over_a_year(crowded_one, neighbours),
		"a town received fewer settlers because its neighbours were also attractive")


# --- 🔒 Flat, not proportional ------------------------------------------------

func test_arrivals_do_not_scale_with_town_size() -> void:
	# **Immigration is flat; births are proportional** — so immigration dominates
	# when a town is small and natural growth when it is large, and a town founded
	# late in a run catches up instead of crawling forever behind.
	var hamlet := _town(&"ashmere", 0.9, 12)
	var city := _town(&"bellhaven", 0.9, 200)
	assert_eq(_over_a_year(hamlet), _over_a_year(city),
		"a town of two hundred drew more settlers than a town of twelve")


# --- What they bring ---------------------------------------------------------

func test_settlers_land_with_their_own_coin() -> void:
	# §6: every arrival is an injection of resources and coin, not merely a
	# mouth. That gold feeds `means`, so a wave is a windfall before it is a
	# burden.
	var town := _town(&"ashmere", 0.95)
	var context := _context([town])
	var before := town.prosperity(QualityOfLife.COMFORTABLE_PURSE)
	for month in 12:
		context.state.month = month
		Immigration.arrive(town, context)
	assert_true(town.prosperity(QualityOfLife.COMFORTABLE_PURSE) >= before,
		"settlers arrived empty-handed and left the town poorer per head")


func test_an_arrival_is_on_the_record() -> void:
	# Seam A. It is also the only way the player learns of them — §11 is explicit
	# that no letter announces settlers are sailing.
	var town := _town(&"ashmere", 0.95)
	var context := _context([town])
	for month in 12:
		context.state.month = month
		Immigration.arrive(town, context)

	var landings: Array = context.log.of_type(Immigration.EVENT_ARRIVED)
	assert_true(not landings.is_empty(), "a year of settlers landed and nothing said so")
	assert_eq(String(landings[0].phase), String(WorldPhase.ARRIVALS),
		"they landed somewhere other than phase 1")


# --- 🔒 Fractions are kept ----------------------------------------------------

func test_a_fraction_of_a_settler_is_carried_rather_than_lost() -> void:
	var town := _town(&"ashmere", 0.6)
	var context := _context([town])
	Immigration.arrive(town, context)
	assert_true(town.arrivals_accrued > 0.0 or town.population() > 12,
		"a town drawing half a settler a month drew nobody, for ever")


func test_the_accrued_fractions_survive_a_save() -> void:
	var town := _town(&"ashmere", 0.6)
	Immigration.arrive(town, _context([town]))
	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(restored.arrivals_accrued, town.arrivals_accrued, 0.0001)
	assert_almost_eq(restored.experts_accrued, town.experts_accrued, 0.0001)


# --- 🔒 Crown flow rises as the Crown declines -------------------------------

func test_a_declining_crown_sends_more_people() -> void:
	# 🔒 §5, and the town is **identical**: same quality of life, same buildings,
	# same everything. The only difference is how bad things have got at home.
	var town := _town(&"ashmere", 0.9)
	var settled := _context([town])
	var declining := _context([town])
	declining.state.values[Immigration.FLOW_KEY] = 1.0

	assert_true(float(Immigration.due(town, declining)["workers"])
			> float(Immigration.due(town, settled)["workers"]),
		"the Crown fell apart and nobody left it")


func test_the_flow_comes_off_the_same_decline_as_the_demands() -> void:
	# 🔒 The acceptance, and the reason it is worth stating: the Crown's
	# obligations growing and its people leaving are **one fact about the
	# Crown**, and two independent curves would eventually disagree about how bad
	# things have got at home.
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var streams := RngStreams.new(SEED)
	var affairs := CrownAffairs.new()
	affairs.growth = DemandGrowth.new()

	state.month = 12
	affairs.on_phase(WorldPhase.CROWNS_MONTH, state, log, streams)
	var early := float(state.get_value(Immigration.FLOW_KEY, 0.0))
	assert_almost_eq(early, 0.0, 0.0001,
		"people were leaving before the Crown was past its peak")

	# Years four onward: the bar moves once a year, and the flow moves with it.
	for year in range(DemandGrowth.FIRST_GROWTH_YEAR, DemandGrowth.FIRST_GROWTH_YEAR + 5):
		state.month = year * 12
		affairs.on_phase(WorldPhase.CROWNS_MONTH, state, log, streams)
	var late := float(state.get_value(Immigration.FLOW_KEY, 0.0))
	assert_true(late > early, "five years of decline sent nobody anywhere")
	assert_almost_eq(late, float(affairs.growth.history.size()) * CrownAffairs.FLOW_PER_DECLINE,
		0.0001, "the flow is on a schedule of its own rather than on the Crown's decline")


func test_a_flow_that_has_not_moved_says_nothing() -> void:
	# It is settled every month and writes only when it changes, so a quiet
	# decade does not fill the log with a figure repeating itself.
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	var affairs := CrownAffairs.new()
	affairs.growth = DemandGrowth.new()
	for month in 24:
		state.month = month
		affairs.on_phase(WorldPhase.CROWNS_MONTH, state, log, RngStreams.new(SEED))
	assert_true(log.of_type(CrownAffairs.EVENT_EMIGRATION).size() <= 6,
		"the emigration figure was written to the log every month it did not move")


# --- 🔒 Education gates growth, not arrivals ---------------------------------

func test_an_unlettered_town_can_still_be_sent_scholars() -> void:
	# `the-provost.md` §3: a town with no learning never raises an expert of its
	# own, but it is not shut out of expertise — it must be sent what it gets.
	var unlettered := _town(&"ashmere", 0.95)
	assert_almost_eq(unlettered.education, 0.0, 0.0001, "the fixture went to school")
	var owed := Immigration.due(unlettered, _context([unlettered]))
	assert_true(float(owed["experts"]) > 0.0,
		"a town with no library was sent no scholars either, which gates the wrong thing")


func test_a_scholar_takes_up_whatever_the_town_most_wants() -> void:
	# Decided at the moment he appears, by the same measure the town values
	# anything else. Nothing about the list is authored.
	var town := _town(&"ashmere", 0.95)
	town.experts_accrued = 0.99
	var context := _context([town])
	Immigration.arrive(town, context)

	var landings: Array = context.log.of_type(Immigration.EVENT_ARRIVED)
	assert_true(not landings.is_empty(), "nobody landed at all")
	assert_true(not String(landings[0].payload["expert_in"]).is_empty(),
		"a scholar arrived expert in nothing")
