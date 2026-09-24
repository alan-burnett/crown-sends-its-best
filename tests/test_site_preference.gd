extends TestCase

## Where a town goes, and the window in which the PC can still say (#177,
## `founding-towns.md` §5, SPEC §11.4).
##
## 🔒 **The PC never chooses a tile.** He approves, refuses, or states a
## preference — toward the coast, near the ore, away from the tribes.
##
## 🔒 **The site cannot be fixed at launch**, or his preferences would arrive a
## month too late and be worth nothing. The governor sets out toward a region and
## a letter shifts him while he travels: `world-month.md` §3's interruptible
## multi-month action in its purest form, and the clearest case in the game of a
## letter arriving in time to matter.

const SEED: int = 8801

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


## A coast on the east, mountains on the west, and good plains between —
## **all of it within reach of the region the tests send him to**, which is the
## point: a preference with nothing to prefer proves nothing either way.
##
## Region (9, 7) with a radius of three covers x 6–12 and y 4–10, so the water at
## x 12 and the rock at x 6–7 are both inside it.
func _map() -> WorldMap:
	var map := WorldMap.new(20, 14, &"ocean")
	for y in range(1, 13):
		for x in range(1, 12):
			map.set_terrain(x, y, &"plains")
	for y in range(3, 11):
		for x in range(6, 8):
			map.set_terrain(x, y, &"mountains")
	return map


func _party(region: Vector2i) -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"expedition_test"
	party.parent = &"ashmere"
	party.people = 20
	party.at = Vector2i(11, 7)
	party.region = region
	return party


func _context() -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), _map())


# --- 🔒 No letter can name a tile -------------------------------------------

func test_no_registered_effect_lets_a_letter_name_a_site() -> void:
	# 🔒 SPEC §11.4 is locked and this is where it is kept rather than
	# remembered: the preference effect takes a **name**, and there is nowhere in
	# its params to put a coordinate. A dev who adds one breaks this by name.
	var params := ContentRegistry.effect_params("prefer_site")
	assert_false(params.is_empty(), "the PC cannot state a preference at all")
	for name in params:
		assert_false(String(params[name]) == "tile",
			"'prefer_site' takes a tile, which is the PC choosing the site")
	assert_true(params.has("preference"), "the preference is not what it carries")


func test_the_letter_offers_names_and_not_coordinates() -> void:
	var record := content.record("letters", "pc.state_a_preference")
	assert_false(record.is_empty(), "the PC has no way to say anything about the site")
	var offered: Dictionary = {}
	for step in record["reply"]["steps"]:
		for option in step["options"]:
			var effect: Dictionary = option["effect"]["prefer_site"]
			assert_false(effect.has("tile") or effect.has("at") or effect.has("site"),
				"an option names a place rather than a preference")
			offered[String(effect["preference"])] = true
	for preference in SitePreference.ALL:
		assert_true(offered.has(String(preference)),
			"the PC can never ask for '%s'" % preference)


# --- 🔒 The governor chooses, deterministically ----------------------------

func test_the_same_region_and_preference_give_the_same_ground() -> void:
	# No seed and no roll: a save reloaded mid-crossing founds the same town.
	var map := _map()
	var once := SitePreference.site_in(Vector2i(7, 7), SitePreference.GOOD_GROUND, map)
	var twice := SitePreference.site_in(Vector2i(7, 7), SitePreference.GOOD_GROUND, _map())
	assert_eq(once, twice, "the same region and the same preference gave two answers")
	assert_true(once != Vector2i(-1, -1), "he found nowhere at all to settle")


func test_he_settles_inside_the_region_he_was_sent_to() -> void:
	var region := Vector2i(7, 7)
	var site := SitePreference.site_in(region, SitePreference.GOOD_GROUND, _map())
	assert_true(absi(site.x - region.x) <= SitePreference.REGION_RADIUS
			and absi(site.y - region.y) <= SitePreference.REGION_RADIUS,
		"he wandered out of the country he was sent to")


func test_he_will_not_settle_in_the_sea() -> void:
	# **Sent out to sea**, where the water would win on every measure a coastal
	# preference cares about. He must find land or find nowhere — a weaker
	# fixture near the shore passes even with the land check taken out, because
	# the ground on the beach outscores the water anyway.
	var map := _map()
	var site := SitePreference.site_in(Vector2i(17, 7), SitePreference.THE_COAST, map)
	assert_true(site == Vector2i(-1, -1) or map.is_land(site.x, site.y),
		"he founded a town on the open water")

	var ashore := SitePreference.site_in(Vector2i(11, 7), SitePreference.THE_COAST, map)
	assert_true(ashore != Vector2i(-1, -1), "sent to the shore, he found nowhere at all")
	assert_true(map.is_land(ashore.x, ashore.y), "he founded a town on the water")


func test_he_keeps_clear_of_the_towns_already_there() -> void:
	# **The town sits on the best ground in the region**, so without the check it
	# is exactly where he would go — which is what makes this test bite rather
	# than pass on the terrain happening to be poor.
	var map := _map()
	# Wherever he would have gone, put the town there — so the check is the only
	# thing that can move him, and taking it out puts him straight back.
	var region := Vector2i(10, 7)
	var unguarded := SitePreference.site_in(region, SitePreference.GOOD_GROUND, map)
	assert_true(unguarded != Vector2i(-1, -1), "he found nowhere at all")

	var colony := Colony.new()
	var town := Town.new(&"ashmere", "Ashmere", unguarded)
	town.workers = 20_000
	colony.add(town)

	var site := SitePreference.site_in(region, SitePreference.GOOD_GROUND, map, colony)
	assert_true(site != unguarded,
		"he founded a new town on the old one's doorstep")
	assert_true(site.distance_squared_to(town.at) > 4,
		"he founded a new town in the old one's fields")


# --- 🔒 A preference moves the answer ---------------------------------------

func test_each_preference_can_pick_different_ground() -> void:
	# **A preference shades the answer; it does not replace it.** He still wants
	# ground a town can live on — he is simply weighing one thing more.
	var map := _map()
	var chosen: Dictionary = {}
	for preference in SitePreference.ALL:
		chosen[String(preference)] = SitePreference.site_in(Vector2i(9, 7), preference, map)
	assert_true(chosen[String(SitePreference.THE_COAST)]
			!= chosen[String(SitePreference.THE_ORE)],
		"the coast and the ore sent him to the same field")


func test_the_coast_puts_him_nearer_the_water() -> void:
	var map := _map()
	var plain := SitePreference.site_in(Vector2i(9, 7), SitePreference.GOOD_GROUND, map)
	var coastal := SitePreference.site_in(Vector2i(9, 7), SitePreference.THE_COAST, map)
	assert_true(_water_near(coastal, map) >= _water_near(plain, map),
		"asked for the coast, he went inland")


# --- 🔒 The window: it works while he walks and not after -------------------

func test_a_preference_letter_changes_where_he_ends_up() -> void:
	# 🔒 The whole of §5. If the site were fixed at launch this test could not be
	# written, because there would be nothing left to change.
	var context := _context()
	var party := _party(Vector2i(9, 7))
	party.settle_destination(context.map)
	var was := party.destination

	assert_true(party.prefer(SitePreference.THE_ORE, context), "he did not hear the letter")
	party.settle_destination(context.map)
	assert_true(party.destination != was,
		"the PC wrote while he was still on the road and it changed nothing")
	assert_not_empty(context.log.of_type(ExpeditionParty.EVENT_PREFERENCE))


func test_the_same_letter_after_he_has_settled_changes_nothing() -> void:
	# 🔒 **And the reply says so.** A letter that quietly did nothing would teach
	# the player that preferences do not work.
	var executor := PreferenceExecutor.new()
	executor.parties = []

	var intent := Intent.new()
	intent.kind = PreferenceExecutor.KIND
	intent.source = &"ashmere"
	intent.target = &"ashmere"
	intent.data = {"preference": String(SitePreference.THE_COAST)}

	var log := EventLog.new()
	var outcome := executor.execute(intent, WorldValues.initial_state(), log)
	assert_eq(String(outcome), String(Intent.OVERTAKEN_BY_EVENTS),
		"a letter to a governor who had already settled was treated as carried out")
	assert_not_empty(log.of_type(PreferenceExecutor.EVENT_TOO_LATE),
		"it came too late and nothing said so, so no reply can")


func test_a_party_that_has_turned_for_home_does_not_take_directions() -> void:
	var party := _party(Vector2i(9, 7))
	party.turning_back = true
	var executor := PreferenceExecutor.new()
	executor.parties = [party]

	var intent := Intent.new()
	intent.kind = PreferenceExecutor.KIND
	intent.source = &"ashmere"
	intent.target = &"ashmere"
	intent.data = {"preference": String(SitePreference.THE_ORE)}
	executor.execute(intent, WorldValues.initial_state(), EventLog.new())

	assert_eq(String(party.preference), String(SitePreference.GOOD_GROUND),
		"a party walking home was redirected to the ore")


func test_a_preference_nobody_has_heard_of_is_abandoned() -> void:
	var executor := PreferenceExecutor.new()
	executor.parties = [_party(Vector2i(9, 7))]
	var intent := Intent.new()
	intent.kind = PreferenceExecutor.KIND
	intent.target = &"ashmere"
	intent.data = {"preference": "somewhere nice"}
	assert_eq(
		String(executor.execute(intent, WorldValues.initial_state(), EventLog.new())),
		String(Intent.ABANDONED),
		"an instruction nobody could carry out was reported as carried out")


# --- 🔒 Away from the tribes has a price -----------------------------------

func test_a_country_with_nobody_in_it_offends_nobody() -> void:
	# This test used to say the seam was cut and read zero everywhere, and that it
	# was the one function M5 would have to teach about natives. **M5 taught it**
	# (#204): it now answers zero only where there is genuinely nobody, which is a
	# different claim and the honest one.
	var map := _map()
	for at in [Vector2i(3, 3), Vector2i(7, 7), Vector2i(12, 11)]:
		assert_almost_eq(SitePreference.intrusion_at(at, map, null), 0.0, 0.0001,
			"an empty country offended somebody")


func test_the_intrusion_seam_now_costs_something_where_somebody_lives() -> void:
	var map := _map()
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = tribe.id
	village.at = Vector2i(7, 7)
	village.people = 30
	natives.villages.append(village)

	assert_true(SitePreference.intrusion_at(Vector2i(7, 7), map, natives) > 0.5,
		"settling on their houses read as an empty field")
	assert_almost_eq(SitePreference.intrusion_at(Vector2i(20, 20), map, natives),
		0.0, 0.0001, "a tile nowhere near them was an intrusion")


func test_away_from_the_tribes_now_steers_away_from_a_village() -> void:
	# 🔒 The preference SPEC §11.4 locks, doing the thing its name says at last.
	var map := _map()
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test_0"
	village.tribe = tribe.id
	village.at = Vector2i(9, 7)
	village.people = 30
	natives.villages.append(village)

	var safe := SitePreference.site_in(
		Vector2i(9, 7), SitePreference.AWAY_FROM_TRIBES, map, null, natives)
	assert_true(Intrusion.depth_at(safe, natives)
			< Intrusion.depth_at(Vector2i(9, 7), natives) - 0.0001,
		"a governor told to keep clear of them settled in their village")


func test_going_wide_of_the_tribes_is_not_free() -> void:
	# The design, asserted on the shape rather than on a number: the preference
	# pays nothing for good ground and buys distance instead, so a PC steering
	# his people to safety is knowingly steering them to worse land.
	var map := _map()
	var best := SitePreference.site_in(Vector2i(9, 7), SitePreference.GOOD_GROUND, map)
	var safe := SitePreference.site_in(Vector2i(9, 7), SitePreference.AWAY_FROM_TRIBES, map)
	assert_true(
		map.yield_around(best.x, best.y, &"food")
			>= map.yield_around(safe.x, safe.y, &"food"),
		"the safest ground was also the best, which makes the choice free")


# --- Launch, and the save ----------------------------------------------------

func test_a_launched_party_sets_out_for_a_region_and_not_a_tile() -> void:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(11, 7))
	town.workers = 40_000
	town.objective_cargo = {"food": 50.0}
	town.store(&"food", 300.0)
	town.receive_gold(500.0)
	var colony := Colony.new()
	colony.add(town)
	var context := _context()
	context.colony = colony

	var party := Expedition.launch(town, context)
	assert_true(party != null, "nothing set out")
	assert_true(party.region != Vector2i(-1, -1), "it set out for nowhere")
	assert_eq(String(party.preference), String(SitePreference.GOOD_GROUND),
		"it left with an opinion the PC never gave it")
	assert_eq(party.destination, Vector2i(-1, -1),
		"the site was fixed at launch, which makes the PC's letter a month too late")


func test_the_region_and_the_preference_survive_a_save() -> void:
	var party := _party(Vector2i(9, 7))
	party.preference = SitePreference.THE_ORE
	var restored := ExpeditionParty.from_dict(party.to_dict())
	assert_eq(restored.region, party.region)
	assert_eq(String(restored.preference), String(SitePreference.THE_ORE),
		"a reload lost what the PC had asked for")


func _water_near(at: Vector2i, map: WorldMap) -> int:
	var water := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := at + Vector2i(dx, dy)
			if map.in_bounds(near.x, near.y) and not map.is_land(near.x, near.y):
				water += 1
	return water
