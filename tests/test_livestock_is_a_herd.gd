extends TestCase

## Livestock is a herd, however it came to the town (#461, `population.md` §2).
##
## 🔒 *Horses bought or sold are counted the same way* as a pasture's head. A
## horse the Crown sold a town grazes, breeds, eats and can be slaughtered like
## one it bred — Settle and Consume only ever read the herd — and the company it
## arms draws it from that same herd. A warehouse of horses beside the herd was
## two counts of one thing, and the one the town bought never ate.

const SEED: int = 461

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


func _context() -> ColonyContext:
	var state := WorldValues.initial_state()
	state.values[TaxRates.BASE_KEY] = 0.0
	var context := ColonyContext.new(state, EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	return context


func _town() -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 4 * Population.THOUSAND
	town.receive_gold(50_000.0)
	return town


func test_horses_bought_join_the_herd() -> void:
	var town := _town()
	var deal := Trade.buy(town, &"horses", 300.0, _context())
	var received := float(deal["received"])
	assert_true(received >= 1.0, "the Crown sold no horses to prove anything with")
	assert_eq(town.livestock_head(&"horses"), int(floorf(received)),
		"the horses bought are not in the herd")
	assert_almost_eq(float(town.stockpile.get("horses", 0.0)), 0.0, 0.0001,
		"the horses bought were put in the warehouse beside the herd")


func test_a_herd_is_what_the_town_holds() -> void:
	# Bred, not bought: the herd is the only count of horses the town has.
	var town := _town()
	town.add_livestock(&"horses", 2_000)
	assert_almost_eq(town.held(&"horses"), 2_000.0, 0.0001, "a bred herd is not horses held")

	var colony := Colony.new()
	colony.add(town)
	assert_almost_eq(ColonySnapshot.of(colony).held(town.id, &"horses"), 2_000.0, 0.0001,
		"a phase reading the colony as it stood cannot see the herd")


func test_a_company_is_horsed_from_the_herd() -> void:
	var town := _town()
	town.add_livestock(&"horses", 2_000)
	var arms := Raising.arms_for(town, 1_000)
	var horses := float(arms.get("horses", 0.0))
	assert_true(horses > 0.0, "a town with a herd of horses raised a company on foot")

	# And what the company rides away on has left the herd.
	town.take(&"horses", horses)
	assert_almost_eq(town.held(&"horses"), 2_000.0 - horses, 0.0001,
		"the horses a company took did not leave the herd")
	assert_eq(town.livestock_head(&"horses"), int(floorf(2_000.0 - horses)))


func test_a_part_bought_beast_is_saved() -> void:
	# The Crown sells by the gold and not the head, so a purchase leaves a
	# fraction over. It is carried, as a calf owed is, and it survives a save.
	var town := _town()
	town.store(&"cows", 10.6)
	town.add_livestock(&"cows", 3)
	assert_eq(town.livestock_head(&"cows"), 13)
	var restored := Town.from_dict(bytes_to_var(var_to_bytes(town.to_dict())))
	assert_almost_eq(restored.held(&"cows"), 13.6, 0.0001, "the fraction of a cow was lost")
	assert_eq(restored.livestock_head(&"cows"), 13)
