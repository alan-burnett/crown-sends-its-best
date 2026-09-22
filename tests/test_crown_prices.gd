extends TestCase

## Crown valuations move with the war, and with a shortage at home (#141,
## `docs/mechanics/town-economy.md` §1, SPEC §10.2, §12.4).
##
## 🔒 **Necessities, never pleasures.** No luxury carries a war appetite and no
## luxury can be the subject of a shortage — which is what keeps the tea rule
## safe by construction rather than by clamp.
##
## 🔒 **Nothing in `sim/` names a resource.** Appetite is a data field.
##
## 🔒 **Neither driver may reach a demand's size** (`crown-demands.md` §10), or
## the Squeeze would ease off on its own the moment prices moved, invisibly.

const SEED: int = 3313

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
	NameBags.reset()
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
	NameBags.reset()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## A resource the data says a war wants, so the test names none itself.
func _wanted() -> StringName:
	var best := &""
	var most := 0.0
	for id in ResourceCatalogue.ids():
		var appetite := ResourceCatalogue.war_appetite(StringName(id))
		if appetite > most:
			most = appetite
			best = StringName(id)
	return best


func _indifferent() -> StringName:
	for id in ResourceCatalogue.ids():
		if ResourceCatalogue.war_appetite(StringName(id)) <= 0.0 \
				and not ResourceCatalogue.is_luxury(StringName(id)):
			return StringName(id)
	return &""


# --- 🔒 The war, with no new world value -----------------------------------

func test_a_war_lifts_what_an_army_consumes() -> void:
	var run := _run()
	var wanted := _wanted()
	assert_false(String(wanted).is_empty(), "no resource carries a war appetite")

	run.world.values[WorldValues.WAR] = 0.0
	var at_peace := Valuation.crown(wanted, run.world)
	run.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	var at_war := Valuation.crown(wanted, run.world)

	assert_true(at_war > at_peace,
		"%s cost %f at peace and %f at full war" % [wanted, at_peace, at_war])


func test_and_leaves_alone_what_it_does_not() -> void:
	var run := _run()
	var indifferent := _indifferent()
	assert_false(String(indifferent).is_empty(), "everything carries an appetite")

	run.world.values[WorldValues.WAR] = 0.0
	var at_peace := Valuation.crown(indifferent, run.world)
	run.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	assert_almost_eq(Valuation.crown(indifferent, run.world), at_peace, 0.0001,
		"a war moved the price of something no army wants")


func test_it_needs_no_world_value_of_its_own() -> void:
	# 🔒 §1: *the number is already there and already moving.* A second value
	# would be a second clock, and the two would disagree the first time one was
	# written without the other.
	var code := _code_of("res://sim/economy/crown_prices.gd")
	assert_true(code.contains("WorldValues.WAR"),
		"the war lift does not read the war")
	for token in ["war_intensity_", "crown_war_price", "WAR_PRICE"]:
		assert_false(code.contains(token),
			"the war lift keeps a figure of its own: %s" % token)


# --- 🔒 A shortage at home, and it decays back ------------------------------

func test_a_shortage_lifts_one_resource_and_decays_back() -> void:
	var run := _run()
	var short_of := _indifferent()
	run.world.values[CrownPrices.key_for(short_of)] = CrownPrices.SHORTAGE_LIFT
	var dear := Valuation.crown(short_of, run.world)
	assert_true(dear > ResourceCatalogue.price_of(short_of),
		"a shortage did not make it dearer")

	var was := dear
	for month in range(1, CrownPrices.SHORTAGE_MONTHS + 2):
		run.world.month = month
		CrownPrices.advance(run.world, run.log, null)
		var now := Valuation.crown(short_of, run.world)
		assert_true(now <= was + 0.0001, "the shortage got worse while easing")
		was = now
	assert_almost_eq(was, ResourceCatalogue.price_of(short_of), 0.0001,
		"the shortage never eased all the way back")


func test_a_shortage_is_reported_when_it_begins_and_when_it_ends() -> void:
	# Seam A: the Steward's letter about a failed harvest reads the log.
	var run := _run()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for month in range(1, 400):
		run.world.month = month
		CrownPrices.advance(run.world, run.log, rng)
	var began := run.log.of_type(CrownPrices.EVENT_SHORTAGE_BEGAN).size()
	assert_true(began > 0, "four hundred months and the Crown never went short")
	assert_false(run.log.of_type(CrownPrices.EVENT_SHORTAGE_EASED).is_empty(),
		"a shortage began and nothing ever eased")


func test_the_same_seed_shorts_the_same_harvest() -> void:
	var seen: Array = []
	for pass_index in 3:
		var run := _run()
		var rng := RandomNumberGenerator.new()
		rng.seed = 404
		for month in range(1, 120):
			run.world.month = month
			CrownPrices.advance(run.world, run.log, rng)
		var names := PackedStringArray()
		for event in run.log.of_type(CrownPrices.EVENT_SHORTAGE_BEGAN):
			names.append(String(event.subject))
		seen.append(names)
	for index in range(1, seen.size()):
		assert_eq(seen[index], seen[0],
			"one seed produced two histories: %s" % [seen])


# --- 🔒 Necessities, never pleasures ----------------------------------------

func test_no_luxury_carries_a_war_appetite() -> void:
	# A test, not a convention.
	var offenders := PackedStringArray()
	for id in ResourceCatalogue.luxuries():
		if ResourceCatalogue.war_appetite(StringName(id)) > 0.0:
			offenders.append(id)
	assert_empty(offenders,
		"a Crown at war prices iron, not tea: %s" % ", ".join(offenders))


func test_and_a_war_cannot_move_one_however_the_data_reads() -> void:
	# 🔒 Guarded as well as validated, because the validator runs on the build
	# and this runs on every price.
	var run := _run()
	var luxuries := ResourceCatalogue.luxuries()
	assert_false(luxuries.is_empty())

	run.world.values[WorldValues.WAR] = 0.0
	var quiet: Dictionary = {}
	for id in luxuries:
		quiet[id] = Valuation.crown(StringName(id), run.world)

	run.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	for id in luxuries:
		assert_almost_eq(Valuation.crown(StringName(id), run.world),
			float(quiet[id]), 0.0001,
			"a war moved the price of %s" % id)


func test_and_no_luxury_can_be_the_subject_of_a_shortage() -> void:
	var run := _run()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for month in range(1, 600):
		run.world.month = month
		CrownPrices.advance(run.world, run.log, rng)

	var offenders := PackedStringArray()
	for event in run.log.of_type(CrownPrices.EVENT_SHORTAGE_BEGAN):
		if ResourceCatalogue.is_luxury(StringName(event.subject)):
			offenders.append(String(event.subject))
	assert_empty(offenders,
		"the Crown went short of a pleasure: %s" % ", ".join(offenders))


func test_the_tea_rule_survives_a_war_and_a_shortage_together() -> void:
	# 🔒 SPEC §10.2, and the rule is **nothing the colony cannot make is cheaper
	# than tea** — beer is cheaper and that is intended, because a town can brew
	# it. Break it and the cheap dependency moves somewhere the design did not
	# intend, and the trade protest lands there instead.
	#
	# It is safe **by construction**: neither driver may touch a luxury, so the
	# whole ordering of pleasures is the same under a war and a shortage of
	# everything else as it is in a quiet year.
	var run := _run()
	var quiet := _luxuries_by_price(run)

	run.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	for id in ResourceCatalogue.ids():
		if not ResourceCatalogue.is_luxury(StringName(id)):
			run.world.values[CrownPrices.key_for(StringName(id))] = 				CrownPrices.SHORTAGE_LIFT

	assert_eq(_luxuries_by_price(run), quiet,
		"a war and a shortage reordered the pleasures")

	var tea := Valuation.crown(&"tea", run.world)
	for id in ResourceCatalogue.luxuries():
		if ResourceCatalogue.is_producible(StringName(id)):
			continue
		assert_true(Valuation.crown(StringName(id), run.world) >= tea,
			"%s is cheaper than tea and the colony cannot make it" % id)


## Every pleasure, cheapest first, as the Crown prices it right now.
func _luxuries_by_price(run: RunState) -> PackedStringArray:
	var entries: Array = []
	for id in ResourceCatalogue.luxuries():
		entries.append([Valuation.crown(StringName(id), run.world), String(id)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		return String(a[1]) < String(b[1]))
	var out := PackedStringArray()
	for entry in entries:
		out.append(String(entry[1]))
	return out


# --- 🔒 Nothing in sim names a resource -------------------------------------

func test_no_resource_is_named_in_the_price_movement() -> void:
	var code := _code_of("res://sim/economy/crown_prices.gd")
	var found := PackedStringArray()
	for id in ResourceCatalogue.ids():
		if code.contains('&"%s"' % id) or code.contains('"%s"' % id):
			found.append(id)
	assert_empty(found,
		"a resource is named in code rather than authored: %s" % ", ".join(found))


# --- 🔒 It composes, it does not replace -------------------------------------

func test_a_barony_and_a_war_can_both_act_at_once() -> void:
	var run := _run()
	var wanted := _wanted()
	var base := ResourceCatalogue.price_of(wanted)

	run.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	var war_only := Valuation.crown(wanted, run.world)

	run.world.values[PolicyEffects.PRICE_PREFIX + String(wanted)] = 0.5
	var both := Valuation.crown(wanted, run.world)

	assert_true(war_only > base, "the war did nothing")
	assert_true(both > war_only,
		"a patron's barony was swallowed by the war rather than added to it")
	assert_almost_eq(both, war_only * 1.5, 0.0001,
		"the two do not multiply")


# --- 🔒 A demand's size is untouched ----------------------------------------

func test_a_demand_is_the_same_size_whatever_prices_do() -> void:
	# 🔒 `crown-demands.md` §10. If a shortage doubled the grain price and a
	# demand asked for grain, it is the same demand — otherwise the draw eases off
	# on its own the moment prices move, invisibly, which §10 forbids outright.
	#
	# **It cannot even be asked**: `DemandBook.advance` takes no `WorldState`, so
	# there is nothing in scope for a price to move. Two books, one seed, and one
	# world at full war and short of everything.
	var quiet := _run()
	var at_war := _run()
	at_war.world.values[WorldValues.WAR] = CrownAffairs.WAR_MAX
	for id in ResourceCatalogue.ids():
		if not ResourceCatalogue.is_luxury(StringName(id)):
			at_war.world.values[CrownPrices.key_for(StringName(id))] = 2.0

	var growth := DemandGrowth.new()
	growth.levels[String(DemandGrowth.REACH)] = 4

	var one := _asks_over(240, growth, quiet)
	var other := _asks_over(240, growth, at_war)

	assert_false(one.is_empty(), "no demand was ever issued, so this proves nothing")
	assert_eq(one, other,
		"a demand changed size because prices moved:
  %s
  %s"
			% [", ".join(one), ", ".join(other)])


## Every ask the Crown made, in order, recorded before it was answered.
func _asks_over(
	months: int, growth: DemandGrowth, run: RunState
) -> PackedStringArray:
	var book := DemandBook.new()
	var out := PackedStringArray()
	for month in range(1, months):
		if book.advance(month, growth, run.streams, run.log):
			out.append("%s %s:%d"
				% [String(book.kind), String(book.resource), int(book.amount)])
		if book.is_pending(month):
			book.answer()
	return out


func test_and_the_demand_book_reads_the_authored_price() -> void:
	# Asked of the file, because the tempting change is one word.
	var code := _code_of("res://sim/crown/demand_book.gd")
	assert_false(code.contains("Valuation.crown"),
		"the demand book sizes its asks off a moving price")


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
