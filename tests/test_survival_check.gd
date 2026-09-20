extends TestCase

## The survival check in Work (#116, `docs/mechanics/town-economy.md` §4).
##
## Need used to be a weight inside the score, rising as the stores fell. That
## re-ranked every tile in the town every month, so a town near the edge
## reshuffled its whole workforce as its granary crossed a line and back — 0.25
## to 0.67 tiles given up a month across 25 seeds, and three a month in the worst
## of them.
##
## It is now a **redirection with a stopping condition**: move hands onto need
## while doing so lowers the town's total unmet need, and when no move would,
## **do nothing and accept the deficit**.
##
## 🔒 The stopping condition is the property these tests exist for. A town on
## poor ground must settle into a sensible assignment and go hungry rather than
## thrash, and it must land in the same place next month from the same position.

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


# --- Ground a town cannot live on -------------------------------------------

## Poor ground with one rich seam in it: desert yields a single food, mountains
## yield none at all but a great deal of stone and ore. A town here cannot feed
## itself however it arranges its hands, which is exactly the case the stopping
## condition is about.
func _poor() -> WorldMap:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(3, 6):
		for x in range(3, 6):
			map.set_terrain(x, y, &"desert")
	map.set_terrain(3, 4, &"mountains")
	map.set_terrain(5, 4, &"mountains")
	return map


## Good ground: plains to the west, forest to the east, so there is a real
## choice between food and timber.
func _mixed() -> WorldMap:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(3, 6):
		for x in range(3, 6):
			map.set_terrain(x, y, &"plains" if x <= 4 else &"forest")
	return map


func _harness(map: WorldMap, workers: int, stock: Dictionary = {}, phases: Array = []) -> Dictionary:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = workers
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))

	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())

	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	for phase in phases:
		if phase == ColonyMonth.CONSUME:
			month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	return {"town": town, "colony": colony, "context": context, "month": month, "seen": 0}


## Run one month and return the tiles the town worked.
func _worked(harness: Dictionary) -> PackedStringArray:
	harness["month"].run(harness["colony"], harness["context"])
	var context: ColonyContext = harness["context"]
	var tiles: PackedStringArray = PackedStringArray()
	for event in context.log.since(int(harness["seen"])):
		if event.type == WorkPhase.EVENT_WORKED:
			tiles = PackedStringArray(event.payload.get("tiles", []))
	harness["seen"] = context.log.next_seq()
	# **Which ground, not the order hands were put on it.** The payload lists
	# tiles in assignment order, which is how the greedy allocation happened to
	# reach them and means nothing to a player looking at the map. Churn is
	# ground given up, and that is what `tools/balance.gd` counts too.
	tiles.sort()
	return tiles


# --- 🔒 It settles, and it stays settled ------------------------------------

func test_a_town_that_cannot_feed_itself_settles_and_stays_settled() -> void:
	# **The property the whole rewrite is for.** Three hands on ground that
	# yields one food a tile, eating everything they raise, so the town's position
	# at the start of each month is the position it was in last month. From the
	# same position it must reach the same assignment — otherwise the map shows
	# men marching back and forth for no reason a player could name.
	var harness := _harness(_poor(), 3, {}, [ColonyMonth.CONSUME])
	var first := _worked(harness)
	assert_true(first.size() > 0, "the town worked nothing at all")

	var settled := 0
	for _month in 8:
		var again := _worked(harness)
		assert_eq(",".join(again), ",".join(first),
			"the assignment moved from %s to %s with nothing about the town changed" % [
				",".join(first), ",".join(again)])
		settled += 1
	assert_eq(settled, 8, "the months did not run")


func test_it_goes_hungry_rather_than_pretending() -> void:
	# The other half of settling: it settles *short*. A town that quietly found
	# the food would prove nothing about the stopping condition.
	var harness := _harness(_poor(), 3, {}, [ColonyMonth.CONSUME])
	for _month in 4:
		_worked(harness)
	var town: Town = harness["town"]
	assert_true(town.held(&"food") < float(town.population()) * ColonyNeeds.per_head(&"food")
		* ColonyNeeds.comfortable_months(),
		"the town on ground that yields one food a tile ended up comfortable")


func test_the_same_position_twice_gives_the_same_answer() -> void:
	# Seed stability, stated as the fixed point it actually is: the redirection
	# is a function of the town's position and nothing else.
	var first := _worked(_harness(_poor(), 3))
	var second := _worked(_harness(_poor(), 3))
	assert_eq(",".join(second), ",".join(first), "the same town twice worked different ground")


# --- 🔒 It moves when moving helps, and not otherwise -----------------------

func test_a_hungry_town_leaves_the_seam_for_the_field() -> void:
	# The redirection doing its job. Four hands, good ground, nothing in the
	# store: the town must end up on the plains rather than all in the forest,
	# which is where the score alone would put it.
	var hungry := _harness(_mixed(), 4)
	var tiles := _worked(hungry)

	var fields := 0
	var map := _mixed()
	for at in tiles:
		var parts := String(at).split(",")
		if map.terrain_at(int(parts[0]), int(parts[1])) == &"plains":
			fields += 1
	assert_true(fields > 0, "a town with nothing in the granary put nobody in the fields")


func test_a_town_with_its_stores_full_is_left_alone() -> void:
	# **No swap improves matters, so none is made.** A comfortable town's
	# assignment is exactly what the score chose, with the survival check standing
	# aside — which is what stops need being a permanent thumb on the scale.
	var fed := _harness(_mixed(), 4, {"food": 900.0, "clothing": 300.0})
	var hungry := _harness(_mixed(), 4)
	assert_true(",".join(_worked(fed)) != ",".join(_worked(hungry)),
		"the survival check made no difference to a town that had nothing")


func test_a_comfortable_town_works_its_best_ground() -> void:
	# Stated the other way round, because the test above would also pass if the
	# fed town were the one behaving oddly. Forest outscores plains on this map.
	var fed := _harness(_mixed(), 3, {"food": 900.0, "clothing": 300.0})
	var map := _mixed()
	for at in _worked(fed):
		var parts := String(at).split(",")
		assert_eq(String(map.terrain_at(int(parts[0]), int(parts[1]))), "forest",
			"a town with full stores worked %s instead of its best ground" % at)


# --- 🔒 Need is not a weight ------------------------------------------------

func test_hunger_does_not_re_rank_the_town() -> void:
	# The regression that started this. Two towns on the same ground with the
	# same orders, one starving and one fed, must **rank** the work identically —
	# they may end up assigned differently, but only by the swap, and a swap moves
	# one hand at a time rather than turning the list inside out.
	var fed := _harness(_mixed(), 9, {"food": 900.0, "clothing": 300.0})
	var starving := _harness(_mixed(), 9)
	var comfortable := _worked(fed)
	var hungry := _worked(starving)

	var shared := 0
	for at in hungry:
		if comfortable.has(at):
			shared += 1
	assert_true(shared >= hungry.size() - 2,
		"hunger moved %d of %d hands, which is a re-ranking rather than a redirection" % [
			hungry.size() - shared, hungry.size()])


func test_a_town_does_not_brew_the_grain_it_needs() -> void:
	# The rule that used to fall out of the hunger weight and is now a filter:
	# the month's needs come off the top before the brewhouse may touch the
	# granary (SPEC §11.3 step 2).
	var thin := _harness(_poor(), 4, {"food": 2.0})
	_worked(thin)
	assert_almost_eq(thin["town"].held(&"beer"), 0.0, 0.0001,
		"a town with two days of grain turned it into drink")
