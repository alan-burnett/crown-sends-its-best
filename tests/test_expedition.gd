extends TestCase

## A town setting out to found another (#175, `docs/mechanics/founding-towns.md`
## §2).
##
## 🔒 **One rule produces both kinds of expedition.** The governor sets his
## target cargo by what he can spare, and the town gathers toward it exactly as
## toward a building. A prosperous town therefore sends a colony that will leap
## ahead of its parent; a crowded, poor town shedding mouths it cannot feed sends
## people with what they can carry. Same objective, same machinery, opposite
## outcomes — and no branch anywhere asking which sort of town this is.

const SEED: int = 5507

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


func _town(id: StringName = &"ashmere", workers: int = 40, stock: Dictionary = {}) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(3, 3))
	# Fixture sizes are in thousands (#426).
	town.workers = workers * Population.THOUSAND
	town.receive_gold(1_000.0)
	for resource in stock:
		town.store(StringName(resource), float(stock[resource]))
	return town


func _context(towns: Array) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_terrain(x, y, &"plains")
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return context


## Reckon, so the town knows what it can spare, then size the cargo.
func _cargo(town: Town) -> Dictionary:
	var context := _context([town])
	var month := ColonyMonth.new()
	month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	month.run(context.colony, context)
	return Expedition.cargo_for(town, context)


func _total(cargo: Dictionary) -> float:
	var total := 0.0
	for resource in cargo:
		total += float(cargo[resource])
	return total


# --- 🔒 The target is derived, never authored -------------------------------

func test_a_rich_town_and_a_destitute_one_both_launch_with_different_cargo() -> void:
	var rich := _cargo(_town(&"ashmere", 40, {
		"food": 900.0, "wood": 400.0, "tools": 60.0, "clothing": 200.0,
	}))
	var shedding := _cargo(_town(&"bellhaven", 40, {"food": 30.0}))

	assert_true(_total(rich) > 0.0, "a prosperous town could spare nothing at all")
	assert_true(_total(rich) > _total(shedding),
		"a town with nine hundred grain sent no more than one with thirty")


func test_nothing_about_the_cargo_is_authored() -> void:
	# The same objective id produces different cargo in different towns, which is
	# the whole of "derived from what the town can spare".
	var one := _cargo(_town(&"ashmere", 40, {"food": 900.0, "wood": 400.0}))
	var two := _cargo(_town(&"bellhaven", 40, {"food": 900.0, "wood": 40.0}))
	assert_ne(_total(one), _total(two),
		"two very different towns sized the same expedition identically")


func test_the_target_does_not_move_once_he_has_set_it() -> void:
	# **Written down when he takes it.** Letting it track the stores would mean a
	# town that had a good month while gathering watched the bar rise with every
	# harvest and gathered for ever.
	var town := _town(&"ashmere", 40, {"food": 400.0, "wood": 200.0})
	town.objective = &"amass_expedition"
	town.objective_cargo = _cargo(town)
	var settled := _total(town.objective_cargo)

	town.store(&"food", 5_000.0)
	assert_almost_eq(_total(town.objective_cargo), settled, 0.0001,
		"a windfall raised the target the town was gathering toward")


# --- 🔒 It is an ordinary objective -----------------------------------------

func test_it_completes_like_a_building() -> void:
	var town := _town(&"ashmere", 40, {"food": 900.0, "wood": 400.0, "clothing": 200.0})
	town.objective = &"amass_expedition"
	town.objective_cargo = _cargo(town)
	assert_true(Objective.completes(town.objective), "an expedition never finishes")
	assert_true(not Objective.costed_resources(town).is_empty(),
		"an expedition costs nothing, so there is nothing to gather")

	var context := _context([town])
	var build := BuildPhase.new()
	for month in 12:
		if town.objective.is_empty():
			break
		build.run(town, ColonySnapshot.of(context.colony), context)

	assert_eq(context.log.of_type(Expedition.EVENT_LAUNCHED).size(), 1,
		"the town gathered for a year and never set out")


# --- 🔒 The parent pays in people and coin ----------------------------------

func test_the_parent_loses_people_and_the_matching_share_of_gold() -> void:
	var town := _town(&"ashmere", 40, {"food": 900.0, "clothing": 200.0})
	town.objective = &"amass_expedition"
	town.objective_cargo = _cargo(town)

	var before := town.population()
	var going := Expedition.people_for(town)
	var context := _context([town])
	Expedition.launch(town, context)

	assert_eq(town.population(), before - going,
		"the expedition set out and everybody stayed at home")

	var event: SimEvent = context.log.of_type(Expedition.EVENT_LAUNCHED)[0]
	var share := float(going) / float(before)
	assert_almost_eq(float(event.payload["gold"]), 1_000.0 * share, 1.0,
		"a fifth of the people left with something other than a fifth of the coin")


func test_what_it_carries_leaves_the_parent() -> void:
	var town := _town(&"ashmere", 40, {"food": 900.0, "clothing": 200.0})
	town.objective = &"amass_expedition"
	town.objective_cargo = _cargo(town)
	var before := town.held(&"food")

	Expedition.launch(town, _context([town]))
	assert_true(town.held(&"food") < before,
		"the expedition carried grain that never left the warehouse")


# --- 🔒 Rebel towns never found towns ---------------------------------------

func test_a_rebel_town_never_takes_the_objective() -> void:
	# SPEC §11.4, and a filter rather than a weight — a very expansionist rebel
	# governor must not be able to outvote it.
	var rebel := _town(&"ashmere", 40, {"food": 900.0})
	rebel.rebelling = true
	assert_false(Expedition.may_launch(rebel), "a town at war with the Crown went colonising")

	var chosen := ObjectiveSelector.choose(rebel, GovernorIntent.GO_WIDE, _context([rebel]))
	assert_false(Objective.is_expedition(StringName(chosen["id"])),
		"a rebel town took an expedition")


func test_a_town_too_small_to_spare_anybody_does_not_launch() -> void:
	assert_false(Expedition.may_launch(_town(&"ashmere", 8)),
		"a town of eight sent four people away and called the rest a town")


func test_the_cargo_survives_save_and_reload() -> void:
	var town := _town(&"ashmere", 40, {"food": 900.0, "wood": 400.0})
	town.objective = &"amass_expedition"
	town.objective_cargo = _cargo(town)
	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(_total(restored.objective_cargo), _total(town.objective_cargo), 0.0001,
		"a reloaded town forgot what it was gathering for")
