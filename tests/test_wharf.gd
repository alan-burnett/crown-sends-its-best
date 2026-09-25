extends TestCase

## The wharf (#411, `docs/mechanics/buildings.md` §4 *Trade*): all gold received
## in trade with the Crown +10%.
##
## 🔒 **What the town receives, never the Crown's duty.** The Crown takes its
## duty as before; the town simply sells better. And buying is untouched.

const SEED: int = 411

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
	var context := ColonyContext.new(WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)
	context.run_seed = SEED
	return context


func _town(wharf: bool, gold: float = 0.0, stock: Dictionary = {}) -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 12_000
	town.receive_gold(gold)
	if wharf:
		town.add_building(&"dock")
		town.add_building(&"wharf")
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func test_a_wharf_sells_better_and_the_crowns_duty_is_unchanged() -> void:
	var without := _context()
	var plain := Trade.sell(_town(false, 0.0, {"furs": 50.0}), &"furs", 50.0, without)
	var with := _context()
	var better := Trade.sell(_town(true, 0.0, {"furs": 50.0}), &"furs", 50.0, with)

	assert_true(float(plain["earned"]) > 0.0, "the fixture sold nothing, so this compares nothing")
	assert_almost_eq(float(better["earned"]), float(plain["earned"]) * 1.1, 0.0001,
		"a wharf town was paid something other than a tenth more for the same furs")
	assert_almost_eq(float(better["tax"]), float(plain["tax"]), 0.0001, "the wharf changed the duty")
	assert_almost_eq(with.crown_tax, without.crown_tax, 0.0001, "the Crown collected a different sum")


func test_and_it_buys_exactly_as_dear() -> void:
	var plain := Trade.buy(_town(false, 5_000.0), &"tools", 20.0, _context())
	var wharfed := Trade.buy(_town(true, 5_000.0), &"tools", 20.0, _context())
	assert_true(float(plain["received"]) > 0.0, "the fixture bought nothing, so this compares nothing")
	assert_almost_eq(float(wharfed["spent"]), float(plain["spent"]), 0.0001, "a wharf changed what buying costs")
	assert_almost_eq(float(wharfed["received"]), float(plain["received"]), 0.0001)


func test_the_event_says_what_the_wharf_added() -> void:
	var context := _context()
	Trade.sell(_town(true, 0.0, {"furs": 50.0}), &"furs", 50.0, context)
	var sold: Array = context.log.of_type(Trade.EVENT_SOLD)
	assert_eq(sold.size(), 1)
	assert_true(float(sold[0].payload["better_sold"]) > 0.0, "the sale did not say the wharf paid")
