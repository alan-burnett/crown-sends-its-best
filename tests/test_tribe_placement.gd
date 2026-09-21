extends TestCase

## Where the tribes go, and the second question of run start (#274;
## `docs/mechanics/map.md` §8).
##
## 🔒 **Placed after the site and relative to it.** Searching for ground that
## happened to sit the right distance from a village would fight the terrain
## request and lose — a good defensive mountain that is *also* exactly six tiles
## from a tribe is a great deal to ask of one seed. Placing them afterwards
## honours both questions exactly, on every seed.
##
## 🔒 **Only the nearest neighbour is in question.** Two tribes are distant
## whatever the PC answers: what he is deciding is who is over the next ridge,
## not how many there are.
##
## 🔒 **And being placed near a tribe is not itself an offence.** The colony did
## not choose its neighbours' land; it was put there.

const SEED: int = 1649
const SEEDS: int = 40

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


func _run(seed_value: int, proximity: StringName) -> RunState:
	return RunState.new_run(
		seed_value, Vector2i(-1, -1), SiteRequest.QUICK_GROWTH, proximity)


## How far each tribe's nearest village is from the colony, nearest tribe first.
func _distances(run: RunState) -> Array:
	var out: Array = []
	for tribe in run.tribes.in_order():
		var nearest := 1.0e30
		for village in run.tribes.villages_of((tribe as Tribe).id):
			nearest = minf(nearest, sqrt(float(
				(village as Village).at.distance_squared_to(run.starting_site))))
		out.append(nearest)
	out.sort()
	return out


func _mean_nearest(proximity: StringName) -> float:
	var total := 0.0
	for index in SEEDS:
		total += float(_distances(_run(index * 131 + 7, proximity))[0])
	return total / float(SEEDS)


# --- 🔒 The question moves one tribe ----------------------------------------

func test_settling_near_puts_a_people_over_the_next_ridge() -> void:
	var near := _mean_nearest(Tribes.NEAR)
	var apart := _mean_nearest(Tribes.APART)
	assert_true(near < apart - 2.0,
		"the nearest tribe sits %.1f tiles off when we settle close and %.1f when we keep our distance"
			% [near, apart])


func test_the_other_two_are_distant_whatever_he_answered() -> void:
	# 🔒 §8: what he is deciding is **who is over the next ridge, not how many
	# there are.** The rest of the native game arrives in its own time.
	var near_second := 0.0
	var apart_second := 0.0
	var near_third := 0.0
	var apart_third := 0.0
	for index in SEEDS:
		var near := _distances(_run(index * 131 + 7, Tribes.NEAR))
		var apart := _distances(_run(index * 131 + 7, Tribes.APART))
		near_second += float(near[1])
		apart_second += float(apart[1])
		near_third += float(near[2])
		apart_third += float(apart[2])

	assert_true(absf(near_second - apart_second) / float(SEEDS) < 2.0,
		"the second tribe moved with the answer, and only the first should")
	assert_true(absf(near_third - apart_third) / float(SEEDS) < 2.0,
		"the third tribe moved with the answer, and only the first should")
	assert_true(near_third / float(SEEDS) > near_second / float(SEEDS),
		"the third tribe is no further off than the second")


func test_the_bands_are_ordered() -> void:
	assert_true(Tribes.CLOSE < Tribes.MEDIUM,
		"settling close is no closer than keeping a distance")
	assert_true(Tribes.MEDIUM < Tribes.FAR and Tribes.FAR < Tribes.VERY_FAR,
		"the bands do not run from near to far")
	assert_eq(Tribes.bands_for(Tribes.NEAR)[0], Tribes.CLOSE)
	assert_eq(Tribes.bands_for(Tribes.APART)[0], Tribes.MEDIUM)
	assert_eq(Tribes.bands_for(Tribes.NEAR).slice(1),
		Tribes.bands_for(Tribes.APART).slice(1),
		"the two answers disagree about where the distant tribes go")


# --- 🔒 After the site, and relative to it ----------------------------------

func test_the_site_is_chosen_before_anybody_is_placed() -> void:
	# The order is the whole of how the second question is honoured. If the site
	# moved with the tribes, the terrain request would be fighting them.
	for request in SiteRequest.ALL:
		var with_near := RunState.new_run(
			SEED, Vector2i(-1, -1), request, Tribes.NEAR)
		var with_apart := RunState.new_run(
			SEED, Vector2i(-1, -1), request, Tribes.APART)
		assert_eq(with_near.starting_site, with_apart.starting_site,
			"asking for %s landed the colony somewhere else when the tribes moved"
				% request)


func test_a_village_still_stands_on_land() -> void:
	for index in SEEDS:
		var run := _run(index * 131 + 7, Tribes.NEAR)
		for village in run.tribes.villages_in_order():
			var at: Vector2i = (village as Village).at
			assert_true(run.map.is_land(at.x, at.y),
				"seed %d put a village in the sea at %d,%d" % [index, at.x, at.y])


func test_a_people_keep_their_villages_together() -> void:
	# They are one people. A tribe with a village at each end of the map is two
	# peoples wearing one name.
	for index in SEEDS:
		var run := _run(index * 131 + 7, Tribes.APART)
		for tribe in run.tribes.in_order():
			var theirs := run.tribes.villages_of((tribe as Tribe).id)
			if theirs.size() < 2:
				continue
			var apart := sqrt(float((theirs[0] as Village).at.distance_squared_to(
				(theirs[1] as Village).at)))
			assert_true(apart <= float(Tribes.VILLAGES_APART) * 2.0,
				"seed %d scattered %s across %.0f tiles" % [index, tribe.id, apart])


func test_there_are_still_three_peoples_with_two_villages_each() -> void:
	for index in 10:
		var run := _run(index * 131 + 7, Tribes.NEAR)
		assert_eq(run.tribes.in_order().size(), 3, "seed %d lost a people" % index)
		assert_eq(run.tribes.villages_in_order().size(), 6,
			"seed %d lost a village to the banding" % index)


# --- 🔒 Being put there is not an offence -----------------------------------

func test_settling_close_does_not_itself_lower_standing() -> void:
	# 🔒 §8. The colony did not choose its neighbours' land — it was put there.
	# Standing starts where it starts, and what the colony does next is what
	# moves it.
	for index in 12:
		var close := _run(index * 131 + 7, Tribes.NEAR)
		var distant := _run(index * 131 + 7, Tribes.APART)
		for rank in 3:
			assert_almost_eq(
				(close.tribes.in_order()[rank] as Tribe).trust(),
				(distant.tribes.in_order()[rank] as Tribe).trust(), 0.0001,
				"seed %d: a people thought worse of the colony for being settled near"
					% index)


func test_nothing_in_placement_reaches_the_standing_movers() -> void:
	# Asserted on the source, because the tempting place to put it is exactly
	# here: the villages are being placed and the offence is right there.
	#
	# **A call, not a mention.** Searching for the bare word tripped on the note
	# in that file saying there is no call to it — a test failing on its own
	# documentation, which is the second time this batch.
	var source := FileAccess.get_file_as_string("res://sim/natives/tribes.gd")
	assert_not_empty(source, "the tribes could not be read")
	assert_false(source.contains("TribeStanding."),
		"placing the villages moves a people's regard, which being put somewhere must not")
	assert_false(source.contains(".move("),
		"placing the villages moves a standing directly")


func test_no_run_begins_with_anybody_already_irreconcilable() -> void:
	for index in SEEDS:
		for proximity in Tribes.PROXIMITIES:
			var run := _run(index * 131 + 7, proximity)
			for tribe in run.tribes.in_order():
				assert_false((tribe as Tribe).is_irreconcilable_with(Tribe.COLONY),
					"seed %d began with a people already past saving" % index)


# --- The choice, and the save ------------------------------------------------

func test_the_answer_survives_a_save() -> void:
	var setup := RunSetup.new()
	setup.proximity = RunSetup.PROXIMITY_NEAR
	assert_eq(RunSetup.from_dict(setup.to_dict()).proximity, RunSetup.PROXIMITY_NEAR,
		"a reload forgot how close we meant to settle")


func test_a_setup_from_an_older_build_keeps_its_distance() -> void:
	var setup := RunSetup.from_dict({"seed_value": SEED})
	assert_true(Tribes.is_proximity(setup.proximity),
		"a setup that said nothing about the neighbours has no answer at all")


func test_the_same_seed_and_answer_place_them_the_same_way() -> void:
	for proximity in Tribes.PROXIMITIES:
		var once := _run(SEED, proximity)
		var twice := _run(SEED, proximity)
		for rank in once.tribes.villages_in_order().size():
			assert_eq((once.tribes.villages_in_order()[rank] as Village).at,
				(twice.tribes.villages_in_order()[rank] as Village).at,
				"the same seed put a village in two places")
