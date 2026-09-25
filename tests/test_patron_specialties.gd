extends TestCase

## A patron's resource and livestock specialties, offered (#442,
## `patrons.md` §4 *What his specialty does*, *One is enough*).
##
## 🔒 **He offers when his regard is high enough and the prerequisite exists
## somewhere in the colony.** No sugar plantation anywhere, and a sugar man never
## offers; one anywhere, and the bonus reaches every town. The town hall never
## counts.
##
## 🔒 **More of his kind** is every town's yield of it, what its conversions
## make, and for livestock how fast every herd breeds.

const SEED: int = 442
const MARKET := "trigger.patron.his_barony_would_buy"
const MORE := "trigger.patron.more_of_his_kind"
const HERDS := "trigger.patron.his_herds_would_thrive"

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.territory.on_phase(WorldPhase.TERRITORY, run.world, run.log, run.streams)


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town(index: int = 0) -> Town:
	return run.colony.in_order()[index]


func _patron(category: String, kind: String, bonus: String, loyalty: float = 80.0) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, loyalty)
	patron.specialty = category
	patron.specialty_kind = kind
	patron.specialty_bonus = bonus
	run.add_contact(patron)
	return patron


## An improvement on a tile the town holds, as though it had been built.
func _improve(town: Town, improvement: String) -> void:
	var at: Vector2i = run.territory_now().tiles_of(town.id)[0]
	run.map.improvements[run.map.index_of(at.x, at.y)] = improvement


func _true(trigger_id: String, patron: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[trigger_id], director._context(run, patron))


## A standing policy of his, pressing on the world as phase 5 leaves it.
func _more_of(patron: Contact, kind: String) -> Policy:
	var policy := run.policies.enact(Policy.new(patron.id, PolicyEffects.MORE_OF_HIS_KIND, 90.0,
		Policy.ALL, {"resource": kind}), run.log, 1)
	_press()
	return policy


func _press() -> void:
	var driver := PolicyDriver.new(run.policies)
	driver.contacts = run.contacts
	driver.on_phase(WorldPhase.CROWNS_MONTH, run.world, run.log, run.streams)


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.territory = run.territory_now()
	return context


# --- 🔒 What meets the prerequisite ---------------------------------------------------------

func test_the_prerequisites_are_the_tables() -> void:
	assert_eq(Patron.prerequisite_of("sugar")["improvements"], PackedStringArray(["plantation_sugar"]))
	assert_eq(Patron.prerequisite_of("ore")["improvements"], PackedStringArray(["mine"]))
	assert_eq(Patron.prerequisite_of("food")["improvements"], PackedStringArray(["farm"]))
	for kind in ["wood", "stone", "furs"]:
		var needed := Patron.prerequisite_of(kind)
		assert_true((needed["buildings"] as PackedStringArray).is_empty()
			and (needed["improvements"] as PackedStringArray).is_empty(), "%s needs something" % kind)
	for kind in ["rum", "cigars", "clothing", "beer", "iron", "tools", "guns"]:
		var buildings: PackedStringArray = Patron.prerequisite_of(kind)["buildings"]
		assert_false(buildings.is_empty(), "nothing makes %s" % kind)
		assert_false(buildings.has(String(Building.BASE)), "the town hall meets a %s man's condition" % kind)
	assert_true((Patron.prerequisite_of("horses")["improvements"] as PackedStringArray).has("pasture"))
	assert_true((Patron.prerequisite_of("horses")["buildings"] as PackedStringArray).has("town_pasture"))


func test_without_the_prerequisite_his_offer_never_comes() -> void:
	var sugar := _patron("resources", "sugar", Patron.BONUS_PRICE)
	assert_false(_true(MARKET, sugar), "a sugar man offered his market to a colony with no plantation")
	_improve(_town(), "plantation_sugar")
	assert_true(_true(MARKET, sugar), "a plantation stood and he never offered")


func test_one_anywhere_is_enough() -> void:
	# A second town, last in order, and the only one with the building.
	var second := run.colony.add(Town.new(&"second_town", "Second", _town().at + Vector2i(6, 0)))
	machine.territory.on_phase(WorldPhase.TERRITORY, run.world, run.log, run.streams)
	var rum := _patron("resources", "rum", Patron.BONUS_MORE)
	assert_false(_true(MORE, rum))
	second.buildings.append("distillery")
	assert_true(_true(MORE, rum), "a distillery in the last town did not count")

	var sugar := _patron("resources", "sugar", Patron.BONUS_MORE)
	assert_false(_true(MORE, sugar))
	assert_false(run.territory_now().tiles_of(second.id).is_empty(), "the second town holds no ground")
	_improve(second, "plantation_sugar")
	assert_true(_true(MORE, sugar), "a plantation on the last town's ground did not count")


func test_the_town_hall_does_not_count() -> void:
	var rum := _patron("resources", "rum", Patron.BONUS_PRICE)
	assert_false(_true(MARKET, rum), "the town hall's base ratio met a rum man's condition")
	_town().buildings.append("distillery")
	assert_true(_true(MARKET, rum), "a distillery stood and he never offered")


func test_wood_needs_nothing() -> void:
	assert_true(_true(MARKET, _patron("resources", "wood", Patron.BONUS_PRICE)))


func test_a_pasture_meets_a_breeders_condition() -> void:
	var horses := _patron("livestock", "horses", Patron.BONUS_MORE)
	assert_false(_true(HERDS, horses))
	_improve(_town(), "pasture")
	assert_true(_true(HERDS, horses), "a pasture stood and the breeder never offered")


# --- 🔒 His regard -----------------------------------------------------------------------------

func test_below_his_regard_he_offers_nothing() -> void:
	var cold := _patron("resources", "wood", Patron.BONUS_PRICE, Patron.OFFERS_AT - 1.0)
	assert_false(_true(MARKET, cold), "a man who thinks too little of the PC offered his market")
	var warm := _patron("resources", "wood", Patron.BONUS_MORE, Patron.OFFERS_AT)
	assert_true(_true(MORE, warm))


# --- 🔒 Each bonus has its own letter -----------------------------------------------------

func test_the_more_bonus_comes_by_its_own_letter_and_never_the_market() -> void:
	var wood := _patron("resources", "wood", Patron.BONUS_MORE)
	assert_true(_true(MORE, wood))
	assert_false(_true(MARKET, wood), "a man rolled with more of it offered the price")
	assert_false(_true(HERDS, wood), "a wood man offered to breed")
	_improve(_town(), "pasture")
	var horses := _patron("livestock", "horses", Patron.BONUS_MORE)
	assert_true(_true(HERDS, horses))
	assert_false(_true(MORE, horses), "a breeder wrote the resource letter")


func test_not_while_he_already_carries_it() -> void:
	var wood := _patron("resources", "wood", Patron.BONUS_MORE)
	_more_of(wood, "wood")
	assert_false(_true(MORE, wood), "he offered what he was already doing")


# --- 🔒 What more of it does ---------------------------------------------------------------

func test_every_towns_yield_of_his_kind_rises() -> void:
	var town := _town()
	var context := _context()
	var at := Vector2i(-1, -1)
	for tile in context.tiles_of(town):
		if run.map.yield_at(tile.x, tile.y, &"food") > 0.0:
			at = tile
			break
	assert_ne(at, Vector2i(-1, -1), "the town holds no ground that grows food, so this proves nothing")
	var work := WorkPhase.new()
	var before := work._yield_of(context, town, at, &"food")
	var table_before := float(work._yields_for(town, context, [at])[WorkPhase._tile_key(at)]["food"])

	_more_of(_patron("resources", "food", Patron.BONUS_MORE), "food")
	assert_almost_eq(work._yield_of(context, town, at, &"food"), before * (1.0 + PolicyEffects.MORE_LIFT), 0.0001,
		"his policy stood and the town's harvest did not rise")
	assert_almost_eq(float(work._yields_for(town, context, [at])[WorkPhase._tile_key(at)]["food"]),
		table_before * (1.0 + PolicyEffects.MORE_LIFT), 0.0001, "the hands were scored on the old harvest")


func _smelt(town: Town) -> float:
	town.store(&"ore", 500.0)
	var held := town.held(&"iron")
	var context := _context()
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if String(recipe.id()) == "iron<-ore":
			context.conversions[String(town.id)] = [recipe]
	ConvertPhase.new().run(town, ColonySnapshot.of(run.colony), context)
	return town.held(&"iron") - held


func test_its_conversions_make_more() -> void:
	var town := _town()
	var plain := _smelt(town)
	assert_true(plain > 0.0, "the town smelted nothing, so this proves nothing")
	_more_of(_patron("resources", "iron", Patron.BONUS_MORE), "iron")
	assert_almost_eq(_smelt(town), plain * (1.0 + PolicyEffects.MORE_LIFT), 0.0001,
		"his policy stood and the furnace made no more")


func test_every_herd_of_his_kind_breeds_faster() -> void:
	var town := _town()
	town.buildings.append("town_pasture")
	town.add_livestock(&"horses", 200 - town.livestock_head(&"horses"))
	var settle := SettlePhase.new()
	settle._breed(town, _context())
	var plain := float(town.livestock_accrued.get("horses", 0.0)) \
		+ float(town.livestock_head(&"horses") - 200)
	town.livestock_accrued.clear()
	town.add_livestock(&"horses", 200 - town.livestock_head(&"horses"))

	_more_of(_patron("livestock", "horses", Patron.BONUS_MORE), "horses")
	settle._breed(town, _context())
	var faster := float(town.livestock_accrued.get("horses", 0.0)) \
		+ float(town.livestock_head(&"horses") - 200)
	assert_almost_eq(faster, plain * (1.0 + PolicyEffects.MORE_LIFT), 0.0001,
		"his policy stood and the horses bred no faster")


# --- 🔒 And stops when it ends --------------------------------------------------------------

func test_a_policy_that_ends_stops_pressing_on_the_world() -> void:
	var policy := _more_of(_patron("resources", "wood", Patron.BONUS_MORE), "wood")
	assert_true(PolicyEffects.more_of(run.world, &"wood") > 0.0, "the policy never reached the world")
	run.policies.lapse(policy.id, run.log, 2)
	_press()
	assert_almost_eq(PolicyEffects.more_of(run.world, &"wood"), 0.0, 0.0001,
		"a lapsed policy went on making more wood")


func test_every_policy_value_is_cleared_when_its_policy_ends() -> void:
	# #442 found the journalist's press, the Provost's knobs, the scholar's
	# travel and the Diplomat's dinners pressing at their last figure for ever.
	var press := run.policies.enact(Policy.new(&"journalist", PolicyEffects.PUBLIC_RELATIONS, 50.0,
		Policy.ALL), run.log, 1)
	_press()
	assert_true(float(run.world.get_value(PolicyEffects.PUBLIC_RELATIONS_KEY, 0.0)) > 0.0)
	run.policies.lapse(press.id, run.log, 2)
	_press()
	assert_almost_eq(float(run.world.get_value(PolicyEffects.PUBLIC_RELATIONS_KEY, 0.0)), 0.0, 0.0001,
		"the journalist's press went on after his policy ended")
