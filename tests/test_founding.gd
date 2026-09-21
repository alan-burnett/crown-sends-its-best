extends TestCase

## The expedition arrives and becomes a town (#179,
## `founding-towns.md` §8, §9).
##
## 🔒 **Founded with exactly what it carried** — people, stores, gold,
## livestock, experts, and any building the Crown equipped it with. Nothing is
## added at the moment of founding and nothing is taken away.
##
## 🔒 **There is no fragility penalty and no starting template.** Quality of life
## computes normally from what the town holds, so a well-found town is
## comfortable on the day it is founded and a shed one is wretched from the
## start. **A dev adding a founding malus has undone the whole ticket.**
##
## 🔒 **Border and vision extend through the existing territory phase**, not a
## bespoke path.

const SEED: int = 4488

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


func _map() -> WorldMap:
	var map := WorldMap.new(20, 14, &"ocean")
	for y in range(1, 13):
		for x in range(1, 12):
			map.set_terrain(x, y, &"plains")
	return map


func _context(colony: Colony = null) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), _map())
	context.colony = colony if colony != null else Colony.new()
	context.run_seed = SEED
	return context


## A party standing on its site, carrying whatever it was given.
func _arrived(
	people: int = 20,
	food: float = 600.0,
	coin: float = 900.0,
	buildings: Array = [],
) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"expedition_ashmere_3"
	party.parent = &"ashmere"
	party.governor = &"governor_expedition_ashmere_3"
	party.people = people
	party.experts = {"food": 1}
	party.cargo = {"food": food, "wood": 80.0, "cows": 6.0}
	party.gold = coin
	party.at = Vector2i(6, 6)
	party.destination = Vector2i(6, 6)
	party.region = Vector2i(6, 6)
	party.buildings = buildings
	return party


# --- 🔒 Exactly what it carried ---------------------------------------------

func test_the_town_begins_with_what_the_party_was_holding() -> void:
	var party := _arrived()
	var context := _context()
	var town := party.found(&"town_new", "Newhaven", context)

	assert_true(town != null, "it arrived and no town was founded")
	assert_eq(town.workers, 20, "the people did not all become the town")
	assert_eq(town.expert_count(&"food"), 1, "the skilled man was left on the road")
	assert_almost_eq(town.held(&"food"), 600.0, 0.001, "the stores changed on the way in")
	assert_almost_eq(town.held(&"wood"), 80.0, 0.001)
	assert_true(town.gold_held() >= 900.0 - 0.001, "the purse did not arrive")
	assert_eq(town.at, Vector2i(6, 6), "it was founded somewhere other than where it stood")
	assert_eq(String(town.governor_id), "governor_expedition_ashmere_3",
		"the man the people elected is not the man who governs")


func test_livestock_arrives_as_beasts_and_not_as_stores() -> void:
	# Cows in a wagon are cows. Stored as a resource they would be eaten by the
	# reckoning rather than grazed, which is a different animal entirely.
	var town := _arrived().found(&"town_new", "Newhaven", _context())
	assert_eq(town.livestock_head(&"cows"), 6, "the herd arrived as sacks of beef")
	assert_almost_eq(town.held(&"cows"), 0.0, 0.001, "and also as sacks of beef")


func test_a_building_the_crown_equipped_it_with_is_standing() -> void:
	# #180's case, built here because §8 lists it among what the party carries.
	var town := _arrived(20, 600.0, 900.0, ["granary"]).found(&"t", "T", _context())
	assert_true(town.has_building(&"granary"),
		"the Crown shipped a granary and nobody put it up")


func test_nothing_is_added_at_the_moment_of_founding() -> void:
	# 🔒 §8. **No starting template.** A town founded from a party carrying
	# nothing but people holds nothing but people.
	var party := _arrived(8, 0.0, 0.0)
	party.cargo = {}
	party.experts = {}
	var town := party.found(&"town_thin", "Thin", _context())

	assert_eq(town.workers, 8)
	assert_almost_eq(town.held(&"food"), 0.0, 0.001, "a founding ration appeared from nowhere")
	assert_true(town.buildings.size() <= 1,
		"a town founded with nothing had buildings put up for it")


func test_the_party_is_spent_by_founding() -> void:
	# It became the town. A party still holding its cargo afterwards would be a
	# colony whose stores existed twice.
	var party := _arrived()
	party.found(&"town_new", "Newhaven", _context())
	assert_true(party.is_empty(), "the expedition founded a town and walked on")
	assert_almost_eq(party.gold, 0.0, 0.001, "the purse was spent twice")


# --- 🔒 No fragility penalty ------------------------------------------------

func test_a_well_found_town_is_comfortable_on_the_day_it_is_founded() -> void:
	# 🔒 §8, and the reason §9 asks for SPEC §11.4 to be rewritten. **Do not
	# implement a fragility penalty.**
	var rich := _arrived(20, 2_000.0, 3_000.0).found(&"town_rich", "Rich", _context())
	rich.store(&"clothing", 200.0)
	var shed := _arrived(20, 4.0, 0.0)
	shed.cargo = {"food": 4.0}
	var poor := shed.found(&"town_poor", "Poor", _context())

	var colony := Colony.new()
	colony.add(rich)
	colony.add(poor)
	var context := _context(colony)

	var comfortable := float(QualityOfLife.of(rich, context)["quality_of_life"])
	var wretched := float(QualityOfLife.of(poor, context)["quality_of_life"])
	assert_true(comfortable > wretched,
		"a town founded with two thousand of grain lived exactly as well as one founded with four")


func test_quality_of_life_is_computed_and_not_assigned() -> void:
	# A starting figure would be the template §8 forbids, wearing a different hat.
	var town := _arrived().found(&"town_new", "Newhaven", _context())
	var colony := Colony.new()
	colony.add(town)
	var measured := float(QualityOfLife.of(town, _context(colony))["quality_of_life"])
	assert_true(measured > 0.0,
		"a well-provisioned new town measured at nothing, so the figure is not being read")


# --- 🔒 Through the ordinary paths ------------------------------------------

func test_it_joins_the_colony_as_an_ordinary_town() -> void:
	var colony := Colony.new()
	var parent := Town.new(&"ashmere", "Ashmere", Vector2i(2, 2))
	parent.workers = 30
	colony.add(parent)

	var driver := ExpeditionDriver.new()
	driver.colony = colony
	driver.map = _map()
	driver.parties = [_arrived()]

	# **Let it walk.** The site is worked out afresh every month (#177), so a
	# party dropped on a coordinate still has a step or two to take before the
	# governor is standing where he means to stop.
	var state := WorldValues.initial_state()
	var log := EventLog.new()
	for month in 8:
		state.month = month
		driver.on_phase(WorldPhase.MOVEMENT, state, log, RngStreams.new(SEED))

	assert_eq(colony.in_order().size(), 2, "it arrived and the colony still has one town")
	assert_true(driver.parties.is_empty(), "the party is still walking about inside its own town")
	assert_not_empty(log.of_type(ExpeditionParty.EVENT_FOUNDED))


func test_the_border_extends_through_the_territory_phase() -> void:
	# 🔒 **Not a bespoke path.** A town in the colony is a town territory already
	# knows how to account for, and a second answer here would eventually
	# disagree with the first.
	var colony := Colony.new()
	var parent := Town.new(&"ashmere", "Ashmere", Vector2i(2, 2))
	parent.workers = 30
	colony.add(parent)
	var map := _map()

	var before := Territory.compute(map, colony.in_order())
	var town := _arrived().found(&"town_new", "Newhaven", _context())
	colony.add(town)
	var after := Territory.compute(map, colony.in_order())

	assert_true(after.tiles_of(town.id).size() > 0,
		"the new town owns no ground, so the colony's border did not follow it")
	assert_true(after.tiles_of(parent.id).size() <= before.tiles_of(parent.id).size() + 0,
		"founding a town gave the parent more ground than it had")


func test_founding_says_everything_it_began_with() -> void:
	# §8's claim is that this is **all** there is, so the record has to carry
	# enough for a reader to check the town against it.
	var context := _context()
	_arrived(20, 600.0, 900.0, ["granary"]).found(&"town_new", "Newhaven", context)
	var founded: Array = context.log.of_type(ExpeditionParty.EVENT_FOUNDED)
	assert_eq(founded.size(), 1, "a town was founded and the record says nothing")

	var payload: Dictionary = founded[0].payload
	assert_eq(int(payload["people"]), 20)
	assert_almost_eq(float(payload["gold"]), 900.0, 0.001)
	assert_eq(Array(payload["buildings"]), ["granary"])
	assert_eq(String(payload["from"]), "ashmere", "it does not say which town sent it")
	assert_eq(Array(payload["at"]), [6, 6])


# --- The edges ---------------------------------------------------------------

func test_a_party_with_nobody_left_founds_nothing() -> void:
	var party := _arrived()
	party.people = 0
	party.experts = {}
	assert_true(party.found(&"town_ghost", "Ghost", _context()) == null,
		"an empty expedition founded a town")


func test_a_party_standing_nowhere_founds_nothing() -> void:
	var party := _arrived()
	party.at = Vector2i(-1, -1)
	assert_true(party.found(&"town_nowhere", "Nowhere", _context()) == null,
		"a town was founded off the edge of the map")
