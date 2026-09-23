extends TestCase

## Where a specialist comes from (#169, `the-provost.md` §4, `immigration.md` §7)
## and the growth he is a share of (#172, `immigration.md` §3 and §8).
##
## 🔒 **Education gates natural growth, not arrivals.** A town with no learning
## never raises an expert of its own, however long it waits. It can still be
## *sent* one, which `test_immigration` guards from the other side.
##
## 🔒 **His expertise is decided when he appears, not when it was earned**, and
## nothing about the list is authored. A town that changes character while the
## fraction accumulates gets an expert suited to what it has become.
##
## 🔒 **Population moves one at a time.** No month adds a crowd, exactly as no
## event takes more than one life.

const SEED: int = 5117

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


## Plains and forest, so there is ground with something on it to multiply.
func _map() -> WorldMap:
	var map := WorldMap.new(9, 9, &"ocean")
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_terrain(x, y, &"plains" if x <= 4 else &"forest")
	return map


func _town(id: StringName = &"ashmere", workers: int = 40, buildings: Array = []) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(4, 4))
	town.workers = workers
	town.quality_of_life = 0.9
	town.receive_gold(50_000.0)  # so upkeep leaves its buildings lit (#151)
	for name in buildings:
		town.add_building(StringName(name))
	return town


func _context(towns: Array) -> ColonyContext:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	var map := _map()
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map
	)
	context.run_seed = SEED
	context.colony = colony
	context.territory = Territory.compute(map, colony.in_order())
	return context


## Run `months` of natural growth and hand back the context, so a test can ask
## the log what happened rather than inferring it from the town.
func _years_of_growth(town: Town, months: int) -> ColonyContext:
	var context := _context([town])
	var settle := SettlePhase.new()
	for month in months:
		context.state.month = month
		town.education = Education.of(town, context)
		settle._grow(town, context)
	return context


func _raised(context: ColonyContext) -> Array:
	var out: Array = []
	for event in context.log.of_type(Experts.EVENT_APPEARED):
		if String(event.payload["origin"]) == String(Experts.RAISED):
			out.append(event)
	return out


# --- 🔒 Education gates natural growth --------------------------------------

func test_an_unlettered_town_never_raises_a_scholar_of_its_own() -> void:
	# Not slowly — **never**. A small positive share would only make it a matter
	# of waiting, and the whole point of the lock is that there is nothing to
	# wait for. Ten years is far past when a slow town would have produced one.
	var town := _town()
	assert_almost_eq(town.education, 0.0, 0.0001, "the fixture went to school")
	assert_almost_eq(Experts.share_of_growth(town), 0.0, 0.0000001,
		"a town with nothing worth teaching still converted some of its growth")

	var context := _years_of_growth(town, 120)
	assert_eq(town.expert_total(), 0, "a town with no learning raised a scholar anyway")
	assert_almost_eq(town.experts_accrued, 0.0, 0.0000001,
		"an unlettered town was saving up for a scholar it can never have")
	assert_empty(_raised(context), "an unlettered town announced a scholar")


func test_a_learned_town_raises_its_own() -> void:
	# The other half of the lock, and the reason the first half is a gate rather
	# than an off switch. Same fixture, same decade — one printing press apart.
	var town := _town(&"ashmere", 40, ["theatre", "printing_press"])
	town.education = Education.of(town, _context([town]))
	assert_true(Experts.share_of_growth(town) > 0.0, "a lettered town converts nothing")

	var context := _years_of_growth(town, 120)
	assert_true(town.expert_total() > 0, "a town of scholars raised none in ten years")
	assert_not_empty(_raised(context), "a scholar appeared and nothing said so")


func test_learning_more_converts_more() -> void:
	# What education is *for*: a learned town turns its growth into expertise and
	# an ignorant one turns it into hands.
	var modest := _town(&"ashmere", 40, ["theatre"])
	var learned := _town(&"brackwater", 40, ["theatre", "printing_press"])
	modest.education = Education.of(modest, _context([modest]))
	learned.education = Education.of(learned, _context([learned]))
	assert_true(Experts.share_of_growth(learned) > Experts.share_of_growth(modest),
		"a printing press converted no more of the town's growth than a theatre alone")


func test_the_share_is_never_all_of_it() -> void:
	# A town of nothing but scholars has nobody to work its ground, and §4's
	# compounding engine would run away without a ceiling on it.
	var town := _town()
	town.education = 10_000.0
	assert_true(Experts.share_of_growth(town) < 1.0,
		"an exceptionally learned town turned all of its growth into scholars")


# --- 🔒 The fraction accumulates --------------------------------------------

func test_a_fraction_of_a_scholar_is_saved_rather_than_lost() -> void:
	var town := _town(&"ashmere", 40, ["theatre", "printing_press"])
	var context := _context([town])
	town.education = Education.of(town, context)
	context.state.month = 0
	SettlePhase.new()._grow(town, context)

	assert_true(town.experts_accrued > 0.0,
		"a month of growth in a learned town put nothing aside at all")
	assert_eq(town.expert_total(), 0, "a whole scholar appeared out of one month")


func test_the_saved_fraction_survives_a_save() -> void:
	# Ironman. Years of slow learning must not be lost to a reload.
	var town := _town(&"ashmere", 40, ["theatre", "printing_press"])
	_years_of_growth(town, 6)
	assert_true(town.experts_accrued > 0.0, "nothing was saved to lose")

	var restored := Town.from_dict(town.to_dict())
	assert_almost_eq(restored.experts_accrued, town.experts_accrued, 0.0001)
	assert_almost_eq(restored.growth_accrued, town.growth_accrued, 0.0001)


# --- 🔒 The specialism is chosen, never authored ----------------------------

func test_a_multiplier_on_nothing_is_worth_nothing() -> void:
	# **The lock.** Every town may weave — a building improves the terms rather
	# than unlocking them (#152) — so what separates a cloth town from a town that
	# would merely like to be one is **having the furs**. A weaver in a town with
	# an empty store multiplies nothing, however dear cloth is.
	var idle := _town(&"ashmere")
	var working := _town(&"brackwater")
	working.store(&"cotton", 400.0)

	assert_almost_eq(Experts.worth_of(idle, &"clothing", _context([idle])), 0.0, 0.0000001,
		"a town with nothing to weave still valued a weaver")
	assert_true(Experts.worth_of(working, &"clothing", _context([working])) > 0.0,
		"a town with four hundred cotton valued a weaver at nothing")
	assert_true(String(Experts.specialism_for(idle, _context([idle]))) != "clothing",
		"a town with nothing to weave raised a weaver anyway")


func test_a_better_loom_is_worth_a_better_weaver() -> void:
	# The other half of the same reading: the building is a term in what he is
	# worth rather than a gate on whether he can exist.
	var plain := _town(&"ashmere")
	var equipped := _town(&"brackwater", 40, ["weaving_shed"])
	for town in [plain, equipped]:
		town.store(&"cotton", 400.0)

	assert_true(
		Experts.worth_of(equipped, &"clothing", _context([equipped]))
			> Experts.worth_of(plain, &"clothing", _context([plain])),
		"a weaving shed made no difference to what a weaver would be worth")


func test_the_specialism_follows_the_town_it_has_become() -> void:
	# Fixed at the moment he materialises rather than when the fraction was
	# earned, so a town that changes character while accumulating gets an expert
	# suited to what it is now. The fraction carries no memory of what earned it.
	var town := _town(&"ashmere", 40, ["weaving_shed"])
	town.store(&"cotton", 400.0)
	assert_true(Experts.worth_of(town, &"clothing", _context([town])) > 0.0,
		"the fixture was not a cloth town to begin with")

	# The loom burns down before he finishes his apprenticeship.
	town.buildings.erase("weaving_shed")
	town.experts_accrued = 1.0
	var context := _context([town])
	context.state.month = 1
	var appeared := Experts.materialise(town, context, Experts.RAISED, WorldPhase.COLONY_MONTH)

	assert_eq(town.expert_total(), 1, "the accumulated scholar was lost with the loom")
	assert_true(String(appeared["specialism"]) != "clothing",
		"the town got the weaver it was going to be rather than the man it now needs")


func test_stacking_turns_the_town_to_something_else() -> void:
	# Diminishing returns (SPEC §12.2) reach the choice as well as the yield, so
	# a town lucky in one trade starts turning out another.
	var town := _town(&"ashmere", 40, ["weaving_shed"])
	town.store(&"cotton", 400.0)
	town.store(&"food", 4_000.0)
	var first := Experts.specialism_for(town, _context([town]))
	town.add_experts(first, 12)
	var later := Experts.specialism_for(town, _context([town]))
	assert_true(String(later) != String(first),
		"a town with twelve %s men wanted a thirteenth" % [first])


func test_every_appearance_is_on_the_record() -> void:
	var town := _town()
	town.experts_accrued = 1.0
	var context := _context([town])
	context.state.month = 3
	Experts.materialise(town, context, Experts.RAISED, WorldPhase.COLONY_MONTH)

	var appeared: Array = context.log.of_type(Experts.EVENT_APPEARED)
	assert_eq(appeared.size(), 1, "a scholar appeared and the map heard nothing of it")
	assert_eq(String(appeared[0].payload["town"]), "ashmere")
	assert_true(not String(appeared[0].payload["specialism"]).is_empty(),
		"he is an expert in nothing at all")
	assert_eq(String(appeared[0].payload["origin"]), String(Experts.RAISED))


# --- 🔒 Population moves one at a time --------------------------------------

func test_each_birth_is_its_own_event() -> void:
	# The mirror of the loss rule, and the same reason for it: per-population
	# consequences stay uniform and legible because nothing ever reports a batch.
	# A town of four hundred is owed more than one child a month and gets them —
	# **one event each**, so a letter naming a birth never has to read a count.
	var town := _town(&"ashmere", 400)
	var context := _context([town])
	context.state.month = 0
	var before := town.population()
	SettlePhase.new()._grow(town, context)

	var births: Array = context.log.of_type(SettlePhase.EVENT_BORN)
	assert_true(births.size() > 1, "the fixture town was not owed more than one child")
	assert_eq(births.size(), town.population() - before,
		"the town gained people the log does not account for one at a time")
	for event in births:
		assert_eq(int(event.payload["born"]), 1, "an event reported a batch of children")


func test_the_remainder_is_carried_rather_than_lost() -> void:
	var town := _town(&"ashmere", 40)
	var context := _context([town])
	context.state.month = 0
	SettlePhase.new()._grow(town, context)
	assert_eq(town.population(), 40, "a town of forty produced a whole child in one month")
	assert_true(town.growth_accrued > 0.0, "the remainder was thrown away")


func test_births_scale_with_population() -> void:
	# 🔒 **Proportional, where arrivals are flat.** The one difference that makes
	# immigration dominate at twelve and natural growth at two hundred.
	var small := _town(&"ashmere", 10)
	var large := _town(&"brackwater", 200)
	_years_of_growth(small, 24)
	_years_of_growth(large, 24)
	assert_true(large.population() - 200 > small.population() - 10,
		"a town of two hundred grew no faster in absolute terms than a town of ten")


func test_a_wretched_town_does_not_grow() -> void:
	var town := _town(&"ashmere", 200)
	town.quality_of_life = 0.05
	_years_of_growth(town, 60)
	assert_eq(town.population(), 200, "people had children in a town nobody wants to live in")


func test_a_granary_raises_the_birth_rate() -> void:
	var bare := _town(&"ashmere", 200)
	var stored := _town(&"brackwater", 200, ["granary"])
	_years_of_growth(bare, 36)
	_years_of_growth(stored, 36)
	assert_true(stored.population() > bare.population(),
		"a granary made no difference to how fast the town grew")


# --- The herds ---------------------------------------------------------------

func test_a_pastured_herd_breeds() -> void:
	var town := _town(&"ashmere", 40, ["town_pasture"])
	town.add_livestock(&"cows", 10)
	_years_of_growth(town, 120)
	assert_true(town.livestock_head(&"cows") > 10,
		"ten cows with a pasture to graze on produced no calf in a decade")


func test_a_herd_with_nowhere_to_graze_does_not() -> void:
	# 🔒 **Pasture is the ceiling.** Beasts over capacity are the ones Consume is
	# buying grain for; they are a cost, not a herd with a future.
	var town := _town(&"ashmere", 40)
	town.add_livestock(&"cows", 10)
	_years_of_growth(town, 120)
	assert_eq(town.livestock_head(&"cows"), 10,
		"a herd with no pasture at all bred anyway")


func test_the_beasts_over_the_pasture_do_not_breed() -> void:
	# 🔒 **Pasture is the ceiling, not the rate.** The beasts beyond capacity are
	# the ones Consume is buying grain to feed — a cost, not a herd with a future
	# — so four times the cows on the same ground is not four times the calves.
	var within := _town(&"ashmere", 40, ["town_pasture"])
	var overflowing := _town(&"brackwater", 40, ["town_pasture"])
	var room := Building.pasture_capacity_for(within)
	within.add_livestock(&"cows", room)
	overflowing.add_livestock(&"cows", room * 4)
	_years_of_growth(within, 12)
	_years_of_growth(overflowing, 12)

	assert_eq(overflowing.livestock_head(&"cows") - room * 4,
		within.livestock_head(&"cows") - room,
		"a herd four times its pasture bred as though the ground had grown with it")


func test_a_granary_speeds_the_herd_too() -> void:
	# One figure for people and beasts both: stored food is what carries a
	# household through a winter and a herd through a lean spring.
	var bare := _town(&"ashmere", 40, ["town_pasture"])
	var stored := _town(&"brackwater", 40, ["town_pasture", "granary"])
	bare.add_livestock(&"cows", 10)
	stored.add_livestock(&"cows", 10)
	_years_of_growth(bare, 240)
	_years_of_growth(stored, 240)
	assert_true(stored.livestock_head(&"cows") > bare.livestock_head(&"cows"),
		"a granary did nothing for the herd it is supposed to be feeding")


func test_the_calves_owed_survive_a_save() -> void:
	var town := _town(&"ashmere", 40, ["town_pasture"])
	town.add_livestock(&"cows", 10)
	_years_of_growth(town, 6)

	var restored := Town.from_dict(town.to_dict())
	assert_eq(restored.livestock_accrued.size(), town.livestock_accrued.size(),
		"the herd's remainder was lost in the save")
	for kind in town.livestock_accrued:
		assert_almost_eq(
			float(restored.livestock_accrued[kind]), float(town.livestock_accrued[kind]), 0.0001)
