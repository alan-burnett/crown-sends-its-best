extends TestCase

## Tea is the cheapest luxury a town cannot produce (#113).
##
## **Load-bearing, not cosmetic.** The whole tea trade-protest design in SPEC
## §10.2 rests on it: tea is the cheap pleasure the colony can never make for
## itself, so taxing it is the point where taxation breaks first — and that
## emerges from the mechanics rather than being hardcoded.
##
## Stated as a rule rather than an ordering, because a later price change can
## honour the ordering by accident and still break the design.

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _luxuries_by_price() -> Array:
	var out: Array = []
	for id in ResourceCatalogue.luxuries():
		out.append([ResourceCatalogue.price_of(StringName(id)), String(id)])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		return String(a[1]) < String(b[1]))
	return out


# --- 🔒 The rule ------------------------------------------------------------

func test_nothing_cheaper_than_tea_is_beyond_the_colony_to_make() -> void:
	# **The rule the design actually needs**, as opposed to the ordering that
	# happens to satisfy it today. A luxury the colony cannot produce, priced
	# under tea, would become the cheap dependency instead — and the trade
	# protest would land somewhere the design did not intend.
	var tea := ResourceCatalogue.price_of(&"tea")
	assert_true(tea > 0.0, "tea has no price")

	for id in ResourceCatalogue.luxuries():
		if ResourceCatalogue.price_of(StringName(id)) >= tea:
			continue
		assert_true(ResourceCatalogue.is_producible(StringName(id)),
			"%s is cheaper than tea and the colony cannot make it" % id)


func test_tea_is_the_cheapest_thing_the_colony_cannot_make() -> void:
	var cheapest_unmakeable := ""
	var cheapest_price := INF
	for id in ResourceCatalogue.luxuries():
		if ResourceCatalogue.is_producible(StringName(id)):
			continue
		var price := ResourceCatalogue.price_of(StringName(id))
		if price < cheapest_price:
			cheapest_price = price
			cheapest_unmakeable = id

	assert_eq(cheapest_unmakeable, "tea",
		"the cheapest luxury the colony cannot make is %s" % cheapest_unmakeable)


func test_beer_is_cheapest_and_tea_is_second() -> void:
	# Beer first because it is made from food, which every town has. Tea second
	# because it can never be made at all.
	var ordered := _luxuries_by_price()
	assert_eq(String(ordered[0][1]), "beer")
	assert_eq(String(ordered[1][1]), "tea")


func test_a_town_reaches_for_tea_before_anything_it_could_grow() -> void:
	# The dependency the design needs: an early town with no plantations finds
	# tea is the second cheapest comfort on the list, so it starts buying it and
	# keeps buying it.
	var tea := ResourceCatalogue.price_of(&"tea")
	for id in ["sugar", "tobacco", "rum", "cigars"]:
		assert_true(ResourceCatalogue.price_of(StringName(id)) > tea,
			"%s undercuts tea, so a town buys that instead and never depends on tea" % id)


func test_every_luxury_still_has_a_price() -> void:
	for id in ResourceCatalogue.luxuries():
		assert_true(ResourceCatalogue.price_of(StringName(id)) > 0.0,
			"%s trades for nothing" % id)
