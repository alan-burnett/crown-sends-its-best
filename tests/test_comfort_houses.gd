extends TestCase

## The tea house and the ale house (#414, `docs/mechanics/quality-of-life.md` §4,
## `buildings.md` §8 *The two comfort traps*).
##
## 🔒 **Each measure of that luxury serves more of the town** — twice as many,
## a placeholder. Variety is unchanged: tea is still one kind. And because the
## buying side reads the same draw, a tea-house town values tea more and loses
## more when a duty or a protest takes it away. That is §8's trap, working.

const SEED: int = 414

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


func _town(house: String = "") -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 12_000
	if not house.is_empty():
		town.add_building(StringName(house))
	return town


## A cellar well short of the month's want, so going further shows.
func _little(of: String) -> Dictionary:
	var mouths := _town().mouths()
	return {of: mouths * ColonyNeeds.luxury_per_head() * 0.2}


func _pleasure(town: Town, held: Dictionary) -> float:
	return QualityOfLife.pleasure_from(town.mouths(), held, {}, Building.luxury_serves_for(town))


func test_a_tea_house_makes_tea_go_further_and_not_beer() -> void:
	assert_true(_pleasure(_town("tea_house"), _little("tea")) > _pleasure(_town(), _little("tea")),
		"the same tea gave a tea-house town no more pleasure")
	assert_almost_eq(_pleasure(_town("tea_house"), _little("beer")), _pleasure(_town(), _little("beer")), 0.000001,
		"a tea house made beer go further")


func test_an_ale_house_makes_beer_go_further_and_not_tea() -> void:
	assert_true(_pleasure(_town("ale_house"), _little("beer")) > _pleasure(_town(), _little("beer")))
	assert_almost_eq(_pleasure(_town("ale_house"), _little("tea")), _pleasure(_town(), _little("tea")), 0.000001,
		"an ale house made tea go further")


func test_with_tea_to_spare_a_tea_house_town_drinks_half_as_much() -> void:
	# The tea goes further: the same month's pleasure from half the measures.
	var mouths := _town().mouths()
	var plenty := {"tea": mouths * ColonyNeeds.luxury_per_head() * 3.0}
	var plain := QualityOfLife.draw_from(mouths, plenty)
	var housed := QualityOfLife.draw_from(mouths, plenty, Building.luxury_serves_for(_town("tea_house")))
	assert_almost_eq(float(housed["tea"]), float(plain["tea"]) / 2.0, 0.0001,
		"a tea-house town drank as much tea as any other for the same month")


func test_variety_is_unchanged_tea_is_still_one_kind() -> void:
	var drawn := QualityOfLife.draw_from(_town().mouths(), _little("tea"), Building.luxury_serves_for(_town("tea_house")))
	assert_eq(drawn.size(), 1)


func test_losing_the_tea_costs_a_tea_house_town_more() -> void:
	# §8's trap: the town that has come to depend on the Crown's tea feels a duty
	# or a protest that takes it away harder.
	var mouths := _town().mouths()
	var housed := Building.luxury_serves_for(_town("tea_house"))
	var loss_housed := QualityOfLife.marginal_pleasure(mouths, {}, &"tea", float(_little("tea")["tea"]), {}, housed)
	var loss_plain := QualityOfLife.marginal_pleasure(mouths, {}, &"tea", float(_little("tea")["tea"]), {}, {})
	assert_true(loss_housed > loss_plain, "a tea-house town lost no more for going without its tea")


func test_consume_serves_more_from_the_same_tea() -> void:
	# Through the month itself, not only the buying side's reckoning.
	var plain := _town()
	var housed := _town("tea_house")
	for town in [plain, housed]:
		town.store(&"tea", float(_little("tea")["tea"]))
	var record_plain := {}
	var record_housed := {}
	ConsumePhase.new()._enjoy(plain, plain.mouths(), record_plain)
	ConsumePhase.new()._enjoy(housed, housed.mouths(), record_housed)
	assert_true(float(record_housed["luxury"]) > float(record_plain["luxury"]),
		"a tea-house town was served no more by the same tea")
