extends TestCase

## High standing: their people join, and the colony is fed from outside the
## Crown (#207, SPEC §12.5, §12.6; `docs/mechanics/natives.md` §6).
##
## 🔒 **Contributed population is ordinary population.** Nothing on a town
## records where a man came from, and nothing afterwards can tell one of these
## apart from a settler off a ship.
##
## 🔒 **It costs the PC nothing.** There is no path from this to the Crown's
## books, so growth the natives provide does not move `net_position` — which
## makes the cheapest population in the game the people the colony is displacing.
##
## 🔒 **Troops are M6.** §12.6 permits them and there is nothing yet for them to
## supplement, so the hook reads nought and says so.

const SEED: int = 6203

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


func _map() -> WorldMap:
	var map := WorldMap.new(24, 24, &"ocean")
	for y in range(2, 22):
		for x in range(2, 22):
			map.set_terrain(x, y, &"plains")
	return map


func _context(map: WorldMap = null) -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), map)


func _tribe(standing: float) -> Tribe:
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): standing}
	return tribe


func _village(people: int = 80) -> Village:
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = &"tribe_test"
	village.at = Vector2i(5, 5)
	village.people = people
	village.stores = {"food": 4_000.0, "furs": 600.0}
	return village


func _town() -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(5, 5))
	town.workers = 40
	town.governor_id = &"gov_ashmere"
	return town


# --- 🔒 Above a threshold, their people come ---------------------------------

func test_a_people_who_barely_tolerate_the_colony_send_nobody() -> void:
	var town := _town()
	var had := town.population()
	for _month in 24:
		NativeHelp.join(_tribe(NativeHelp.JOIN_ABOVE - 1.0), _village(), town, _context())
	assert_eq(town.population(), had,
		"two years of cool civility filled a town with somebody else's children")


func test_a_people_on_good_terms_send_their_own() -> void:
	var town := _town()
	var tribe := _tribe(95.0)
	var village := _village()
	var had := town.population()

	var came := 0
	for _month in 24:
		came += NativeHelp.join(tribe, village, town, _context())

	assert_true(came > 0, "two years beside a people who trust us and nobody came")
	assert_eq(town.population(), had + came,
		"the town gained a different number of people than walked into it")


func test_they_come_one_at_a_time() -> void:
	# 🔒 `CLAUDE.md`: no single event moves a settlement by more than one
	# population, and the whole file has to obey it uniformly.
	var town := _town()
	var context := _context()
	# 🔒 **Their own remainder**, not immigration's. Priming the shared one used
	# to work and silently stopped meaning anything the day a colony attractive
	# enough to draw settlers spent it on them first.
	town.native_arrivals_accrued = 0.99
	assert_eq(NativeHelp.join(_tribe(100.0), _village(), town, context), 1,
		"a month brought a number of people other than one")

	for event in context.log.of_type(NativeHelp.EVENT_JOINED):
		assert_eq(int(event.payload["people"]), 1,
			"an event moved a town by more than one population")


func test_a_village_is_one_fewer_for_every_man_who_goes() -> void:
	# They are their people, not a fountain. A tribe that emptied itself into a
	# colony would be a tribe the colony had absorbed, which is a different thing
	# from a tribe that likes it.
	var town := _town()
	var village := _village()
	village.people = 30
	town.native_arrivals_accrued = 0.99
	NativeHelp.join(_tribe(100.0), village, town, _context())
	assert_eq(village.people, 29, "a man joined a town and stayed in his village too")


func test_a_people_who_have_concluded_send_nobody_whatever_the_figure_says() -> void:
	# 🔒 The latch. Standing may sit anywhere; the conclusion is what governs.
	var tribe := _tribe(95.0)
	tribe.irreconcilable[String(Tribe.COLONY)] = true
	assert_almost_eq(NativeHelp.warmth(tribe, NativeHelp.JOIN_ABOVE), 0.0, 0.0001,
		"a people past the point of no return sent the colony their sons")


func test_warmth_rises_across_what_is_left_of_the_scale() -> void:
	var barely := NativeHelp.warmth(_tribe(NativeHelp.JOIN_ABOVE + 1.0), NativeHelp.JOIN_ABOVE)
	var fond := NativeHelp.warmth(_tribe(Tribe.MAXIMUM), NativeHelp.JOIN_ABOVE)
	assert_true(barely > 0.0, "a people just over the line were treated as under it")
	assert_true(fond > barely + 0.0001,
		"a people who think the world of the colony help no more than one that just tolerates it")


# --- 🔒 Indistinguishable afterwards ----------------------------------------

func test_nothing_on_a_town_records_where_a_man_came_from() -> void:
	# 🔒 The acceptance, asserted on the object. A dev who added a tally of
	# native-born colonists would find out here.
	var town := _town()
	town.native_arrivals_accrued = 0.99
	NativeHelp.join(_tribe(100.0), _village(), town, _context())

	var fields: Dictionary = {}
	for entry in town.get_property_list():
		fields[String(entry["name"])] = true
	for forbidden in ["native_born", "natives", "from_tribe", "tribe", "joined_from"]:
		assert_false(fields.has(forbidden),
			"a town grew a '%s', so its people are no longer all its people" % forbidden)

	assert_false(town.to_dict().has("native_born"),
		"a save recorded which colonists were born in a village")


func test_the_event_names_the_tribe_so_a_letter_can_say_who_helped() -> void:
	var town := _town()
	town.native_arrivals_accrued = 0.99
	var context := _context()
	NativeHelp.join(_tribe(100.0), _village(), town, context)

	var joined: Array = context.log.of_type(NativeHelp.EVENT_JOINED)
	assert_eq(joined.size(), 1, "somebody joined a town in silence")
	assert_eq(String(joined[0].payload["tribe"]), "tribe_test")
	assert_eq(String(joined[0].payload["town"]), "ashmere")


# --- 🔒 Gifts are gated higher than people ----------------------------------

func test_a_people_send_their_sons_before_they_send_their_stores() -> void:
	assert_true(NativeHelp.GIVE_ABOVE > NativeHelp.JOIN_ABOVE,
		"a people part with their winter stores as readily as with their children")

	var town := _town()
	var village := _village()
	var between := (NativeHelp.JOIN_ABOVE + NativeHelp.GIVE_ABOVE) * 0.5
	assert_true(NativeHelp.gifts(_tribe(between), village, town, _context()).is_empty(),
		"a people who would send a son also emptied their granary")
	assert_true(NativeHelp.warmth(_tribe(between), NativeHelp.JOIN_ABOVE) > 0.0,
		"the fixture sat below the joining band too, so it proves nothing")


func test_a_people_who_think_the_world_of_the_colony_send_what_they_have() -> void:
	var town := _town()
	var village := _village()
	var context := _context()
	var given := NativeHelp.gifts(_tribe(Tribe.MAXIMUM), village, town, context)

	assert_false(given.is_empty(), "a people who could not do enough for us sent nothing")
	for id in given:
		assert_true(town.held(StringName(id)) > 0.0,
			"the town was recorded as receiving %s it does not have" % id)
	assert_eq(context.log.of_type(NativeHelp.EVENT_GAVE).size(), 1,
		"a granary changed hands in silence")


func test_a_gift_comes_out_of_what_they_can_spare_and_no_more() -> void:
	var town := _town()
	var village := _village()
	village.stores = {"food": 1.0}
	assert_true(NativeHelp.gifts(_tribe(Tribe.MAXIMUM), village, town, _context()).is_empty(),
		"a starving village gave away its last grain")


func test_a_teacher_they_send_is_a_teacher_like_any_other() -> void:
	# Through `Experts`, so a man the natives sent and a man a library raised are
	# the same man arriving by two roads.
	var town := _town()
	var before := town.experts_accrued
	NativeHelp.gifts(_tribe(Tribe.MAXIMUM), _village(), town, _context())
	assert_true(town.experts_accrued > before,
		"a people who knew the country sent nobody who knew it")


# --- 🔒 Troops are M6, and say so -------------------------------------------

func test_troops_are_a_named_hook_reading_nought() -> void:
	# §12.6 permits them — *colonial forces can be supplemented by friendly
	# natives* — and a company is #214. A hook that quietly did nothing would be
	# indistinguishable from one nobody wired up, so this says it out loud.
	assert_eq(NativeHelp.troops(_tribe(Tribe.MAXIMUM), _town()), 0,
		"friendly natives turned out for a war nobody can fight yet")


# --- 🔒 And it costs the PC nothing -----------------------------------------

func test_their_people_do_not_move_the_crowns_books() -> void:
	# 🔒 `immigration.md` §9: growth the PC asked the Crown for moves
	# `net_position` and costs him standing. This does not, and the way that is
	# made true is that there is no path from here to the accounts.
	var run := RunState.new_run(SEED)
	var town := run.colony.in_order()[0]
	var tribe: Tribe = run.tribes.in_order()[0]
	tribe.standing[String(Tribe.COLONY)] = Tribe.MAXIMUM
	var village: Village = run.tribes.villages_of(tribe.id)[0]
	village.at = town.at
	village.people = 200

	var before := run.standing.net_position
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	town.native_arrivals_accrued = 0.99
	assert_eq(NativeHelp.join(tribe, village, town, context), 1, "nobody came")
	NativeHelp.gifts(tribe, village, town, context)

	assert_almost_eq(run.standing.net_position, before, 0.0001,
		"the Crown was billed for people who walked in from next door")


# --- A party in the field ----------------------------------------------------

func test_a_party_crossing_their_country_picks_up_guides() -> void:
	var party := ExpeditionParty.new()
	party.id = &"party_test"
	party.people = 20
	party.at = Vector2i(5, 5)
	var village := _village()
	var tribe := _tribe(Tribe.MAXIMUM)

	var joined := 0
	for _month in 40:
		joined += NativeHelp.join_party(tribe, village, party, _context())
	assert_true(joined > 0,
		"a party walked through their country for three years and met nobody")
	assert_eq(party.people, 20 + joined,
		"the party gained a different number of people than joined it")


func test_a_party_crossing_a_cold_country_walks_alone() -> void:
	var party := ExpeditionParty.new()
	party.id = &"party_test"
	party.people = 20
	party.at = Vector2i(5, 5)

	for _month in 40:
		NativeHelp.join_party(
			_tribe(NativeHelp.JOIN_ABOVE - 1.0), _village(), party, _context())
	assert_eq(party.people, 20,
		"a people who distrust the colony guided its expeditions anyway")


# --- Through the real loop ---------------------------------------------------

func test_a_well_liked_colony_grows_from_its_neighbours() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]
	for tribe in run.tribes.in_order():
		(tribe as Tribe).standing[String(Tribe.COLONY)] = Tribe.MAXIMUM
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = town.at + Vector2i(1, 0)
	village.people = 400

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	for _month in 24:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	assert_true(run.log.of_type(NativeHelp.EVENT_JOINED).size() > 0,
		"two years beside a people who could not do enough for us and nobody came")
