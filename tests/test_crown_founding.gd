extends TestCase

## The Crown sends a town (#180, `founding-towns.md` §1, §3;
## `the-provost.md` §8).
##
## 🔒 **It arrives with a character.** This is what a parent town can never do —
## a building standing, an expert, an intent already set. The same shape runs the
## other way: a parcel of poor souls arrives with very little and no specialism.
##
## 🔒 **It appears. There is no journey and no map unit at any point.** The Crown
## managed the ships and the guards, which is exactly what the standing paid for:
##
## > Crown expeditions are slow and safe and cost standing. Town expeditions are
## > free and go across open country.
##
## 🔒 **The PC may dissuade, but he does not decide.** SPEC §11.4 presses these
## on the colony; his objection is an Order like any other, and a determined
## contact founds his town over it.

const SEED: int = 6120

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


## A coastline down the east, and **the best ground well inland** — so that the
## coast is not simply where the good land happens to be. A map where the shore
## was also the richest field would pass even with the coastal rule taken out.
func _map() -> WorldMap:
	var map := WorldMap.new(20, 14, &"ocean")
	for y in range(1, 13):
		for x in range(1, 12):
			map.set_terrain(x, y, &"forest")
	for y in range(2, 12):
		for x in range(1, 5):
			map.set_terrain(x, y, &"plains")
	return map


func _colony() -> Colony:
	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(3, 3))
	town.workers = 30
	colony.add(town)
	return colony


func _context(colony: Colony = null) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), _map())
	context.colony = colony if colony != null else _colony()
	context.run_seed = SEED
	return context


## **The same letter every time**, so what differs between the answers is what
## the terms buy and not what the fixture chose to pass in. A fixture that only
## offered a granary to the handsome option would never notice the cheap one
## arriving with a mill.
func _proposed(equipped: String, context: ColonyContext) -> CrownFounding:
	return CrownFounding.proposed(
		&"provost", equipped,
		&"sugar" if equipped != "meanly" else &"",
		&"granary",
		GovernorIntent.ECONOMY if equipped != "meanly" else &"",
		context,
	)


# --- 🔒 It arrives with a character -----------------------------------------

func test_a_handsome_founding_arrives_already_being_something() -> void:
	# 🔒 §3, and the whole reason the Crown route exists: **a parent town can
	# never do this.** It walks its people across country and they arrive as
	# people; this arrives as a sugar colony.
	var colony := _colony()
	var context := _context(colony)
	var founding := _proposed("handsomely", context)
	context.state.month = founding.arrives_month

	var town := founding.arrive(colony, context.map, context)
	assert_true(town != null, "the Crown's ships never put anybody down")
	assert_eq(town.expert_count(&"sugar"), 1, "the botanist did not get off the boat")
	assert_true(town.has_building(&"granary"), "the granary in the hold was never unloaded")
	assert_eq(String(town.intent), String(GovernorIntent.ECONOMY),
		"a town founded for its sugar arrived with no idea what it was for")
	assert_true(town.held(&"food") > 0.0 and town.gold_held() > 0.0)


func test_a_parcel_of_poor_souls_arrives_with_nothing_of_the_kind() -> void:
	# 🔒 The same shape the other way. **What separates them is what the PC
	# promised**, and nothing else.
	var colony := _colony()
	var context := _context(colony)
	var founding := _proposed("meanly", context)
	context.state.month = founding.arrives_month
	var town := founding.arrive(colony, context.map, context)

	assert_true(town != null)
	assert_eq(town.expert_total(), 0, "the cheapest option still sent a specialist")
	assert_false(town.has_building(&"granary"),
		"a parcel of poor souls arrived with a granary the PC never paid for")
	assert_true(String(town.intent).is_empty(),
		"a parcel of poor souls arrived with a specialism")
	assert_true(town.workers > 0, "nobody came at all")


func test_the_correspondence_determines_what_it_starts_with() -> void:
	var context := _context()
	var handsome := _proposed("handsomely", context)
	var mean := _proposed("meanly", context)
	assert_true(handsome.people > mean.people, "both answers sent the same number of people")
	assert_true(handsome.gold > mean.gold, "both answers sent the same purse")
	assert_true(
		float(handsome.cargo.get("food", 0.0)) > float(mean.cargo.get("food", 0.0)),
		"both answers sent the same stores")


func test_the_purse_is_a_set_sum_and_not_a_share() -> void:
	# 🔒 §3. The Crown is not dividing a town's savings; it is spending. A rich
	# colony and a poor one are sent the same money.
	var rich := _colony()
	rich.in_order()[0].receive_gold(90_000.0)
	var poor := _colony()

	var one := _proposed("handsomely", _context(rich))
	var two := _proposed("handsomely", _context(poor))
	assert_almost_eq(one.gold, two.gold, 0.001,
		"the Crown's purse depended on what the colony already had")


# --- 🔒 It appears: no journey, no map unit --------------------------------

func test_it_takes_months_and_then_is_simply_there() -> void:
	var context := _context()
	var founding := _proposed("adequately", context)
	assert_true(founding.arrives_month > context.state.month,
		"the Crown's ships arrived the month they were asked for")
	assert_false(founding.is_due(context.state.month), "it was due before it sailed")
	assert_true(founding.is_due(founding.arrives_month), "it never became due")


func test_no_map_unit_exists_at_any_point() -> void:
	# 🔒 **None of §7's dangers apply**, and the way that is kept true is that
	# there is nothing on the map to attack. A Crown founding never touches the
	# array expeditions live in.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var executor := FoundingExecutor.new()
	executor.foundings = run.foundings

	var intent := Intent.new()
	intent.kind = FoundingExecutor.KIND_FUND
	intent.target = &"provost"
	intent.data = {"equipped": "handsomely", "expert": "sugar", "building": "granary"}
	executor.execute(intent, run.world, run.log)

	assert_eq(run.foundings.size(), 1, "the PC paid for a town and none was arranged")
	assert_true(run.parties.is_empty(),
		"a Crown founding put a wagon train on the map, where something can ambush it")


func test_it_appears_on_the_coast() -> void:
	var colony := _colony()
	var context := _context(colony)
	var founding := _proposed("adequately", context)
	context.state.month = founding.arrives_month
	var town := founding.arrive(colony, context.map, context)

	var water := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := town.at + Vector2i(dx, dy)
			if context.map.in_bounds(near.x, near.y) and not context.map.is_land(near.x, near.y):
				water += 1
	assert_true(water > 0, "the Crown's ships landed them a week inland")

	# And it is a **guarantee**, not a preference: the best ground on this map is
	# well inland, and they were still put down on the shore.
	assert_true(
		context.map.yield_around(town.at.x, town.at.y, &"food")
			< context.map.yield_around(3, 7, &"food"),
		"the fixture's shore is also its best ground, so this proves nothing")


func test_it_joins_the_colony_through_the_ordinary_driver() -> void:
	var colony := _colony()
	var driver := CrownFoundingDriver.new()
	driver.colony = colony
	driver.map = _map()
	driver.contacts = {}
	var context := _context(colony)
	driver.foundings = [_proposed("adequately", context)]

	var state := WorldValues.initial_state()
	var log := EventLog.new()
	state.month = CrownFounding.MONTHS_AT_SEA + 1
	driver.on_phase(WorldPhase.ARRIVALS, state, log, RngStreams.new(SEED))

	assert_eq(colony.in_order().size(), 2, "it was due and nothing appeared")
	assert_true(driver.foundings.is_empty(), "it arrived and is still at sea")
	assert_not_empty(log.of_type(CrownFounding.EVENT_ARRIVED))


func test_nothing_appears_before_it_is_due() -> void:
	var colony := _colony()
	var driver := CrownFoundingDriver.new()
	driver.colony = colony
	driver.map = _map()
	driver.foundings = [_proposed("adequately", _context(colony))]

	driver.on_phase(
		WorldPhase.ARRIVALS, WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED))
	assert_eq(colony.in_order().size(), 1, "the ships arrived the week they left")
	assert_eq(driver.foundings.size(), 1, "it was dropped rather than kept waiting")


# --- 🔒 He may dissuade, but he does not decide ----------------------------

func test_a_contact_who_relents_drops_it() -> void:
	var context := _context()
	var executor := FoundingExecutor.new()
	executor.foundings = [_proposed("handsomely", context)]

	var intent := Intent.new()
	intent.kind = FoundingExecutor.KIND_DISSUADE
	intent.target = &"provost"
	intent.data = {"relented": true}
	assert_eq(String(executor.execute(intent, context.state, context.log)),
		String(Intent.COMPLETED))
	assert_true(executor.foundings[0].abandoned, "he agreed to drop it and did not")
	assert_not_empty(context.log.of_type(CrownFounding.EVENT_ABANDONED))


func test_a_determined_contact_founds_it_over_the_objection() -> void:
	# 🔒 SPEC §11.4. **The decision remains the contact's**, and the PC's only
	# real instrument is the regard he built with the man beforehand.
	var colony := _colony()
	var context := _context(colony)
	var founding := _proposed("handsomely", context)
	var executor := FoundingExecutor.new()
	executor.foundings = [founding]

	var intent := Intent.new()
	intent.kind = FoundingExecutor.KIND_DISSUADE
	intent.target = &"provost"
	intent.data = {"relented": false}
	executor.execute(intent, context.state, context.log)

	assert_false(founding.abandoned, "the PC said no and that was the end of it")
	context.state.month = founding.arrives_month
	assert_true(founding.arrive(colony, context.map, context) != null,
		"a town the PC failed to talk him out of never turned up")


func test_an_abandoned_founding_never_appears() -> void:
	var colony := _colony()
	var context := _context(colony)
	var founding := _proposed("handsomely", context)
	founding.abandoned = true
	context.state.month = founding.arrives_month
	assert_true(founding.arrive(colony, context.map, context) == null,
		"a founding the PC talked him out of turned up anyway")


# --- 🔒 Its governor inherits from the man who proposed it -----------------

func test_the_governor_inherits_from_the_proposer() -> void:
	# #178's rule, asked of a different man. A patron the PC has treated well
	# hands him a governor already inclined to listen.
	var warm := _governor_from(95.0)
	var sour := _governor_from(5.0)
	assert_true(warm.loyalty() > sour.loyalty(),
		"a town the Provost was pleased to send arrived as hostile as one he resented")


func _governor_from(loyalty: float) -> Contact:
	var provost := Contact.new(&"provost")
	provost.role = Contact.ROLE_CROWN_OFFICER
	provost.relationship.loyalty = loyalty

	var colony := _colony()
	var driver := CrownFoundingDriver.new()
	driver.colony = colony
	driver.map = _map()
	driver.contacts = {"provost": provost}
	driver.foundings = [_proposed("adequately", _context(colony))]

	var state := WorldValues.initial_state()
	state.month = CrownFounding.MONTHS_AT_SEA + 1
	driver.on_phase(WorldPhase.ARRIVALS, state, EventLog.new(), RngStreams.new(SEED))

	var town := colony.in_order()[colony.in_order().size() - 1]
	return driver.contacts.get(String(town.governor_id))


# --- The letter and the save ------------------------------------------------

func test_the_cost_lands_on_the_ordinary_promise_path() -> void:
	# 🔒 **Not a bespoke deduction.** The letter's other effect is a plain
	# `promise_gold`, so `CrownAccounts` sees it exactly as it sees every other
	# promise — a second set of books would eventually disagree with the first.
	var record := content.record("letters", "provost.propose_a_founding")
	assert_false(record.is_empty(), "nobody ever proposes a Crown founding")
	var paid := 0
	for option in record["reply"]["steps"][0]["options"]:
		if option["effect"].has("fund_founding"):
			assert_true(option["effect"].has("promise_gold"),
				"'%s' equips a town and nothing is ever charged for it" % option["id"])
			paid += 1
	assert_true(paid >= 3, "the PC is not offered a real choice about how handsomely")


func test_the_letter_offers_arguing_against_it() -> void:
	var record := content.record("letters", "provost.propose_a_founding")
	var argued := false
	for option in record["reply"]["steps"][0]["options"]:
		argued = argued or option["effect"].has("dissuade_founding")
	assert_true(argued, "the PC cannot even argue, which is the one thing he can do")


func test_a_founding_survives_a_save() -> void:
	# He has already promised gold for it. A reload that forgot one would be a
	# reload that spent his standing on nothing.
	var founding := _proposed("handsomely", _context())
	var restored := CrownFounding.from_dict(founding.to_dict())
	assert_eq(restored.people, founding.people)
	assert_eq(String(restored.expert_in), "sugar")
	assert_eq(String(restored.building), "granary")
	assert_eq(restored.arrives_month, founding.arrives_month)
	assert_almost_eq(restored.gold, founding.gold, 0.001)
