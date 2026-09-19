extends TestCase

## The Chancellor announces that the bar started moving (#69,
## `docs/mechanics/crown-demands.md` §3).
##
## 🔒 **The player has to be told the rules changed.** A bar that moves without
## announcement reads as the game cheating, which is why the letter is never
## skippable and why it lands in the month of the first draw rather than
## whenever the director next has room.
##
## He is the right voice for it: SPEC §8.1 gives him the Crown's political voice
## and a taste for delivering the PC bad news, and §3.1 opens the game at the
## Crown's peak — which is the moment before a decline.

const SEED: int = 4071
const MONTHS: int = 12

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


func _context(growth: DemandGrowth, month: int) -> LetterContext:
	var state := WorldValues.initial_state()
	state.month = month
	var context := LetterContext.new(state, null, &"dutiful")
	context.month = month
	context.demands = growth
	return context


## Advance a growth to the month its first draw lands in.
func _first_draw(seed_value: int = SEED) -> DemandGrowth:
	var growth := DemandGrowth.new()
	var streams := RngStreams.new(seed_value)
	growth.advance(DemandGrowth.FIRST_GROWTH_YEAR, streams, null,
		DemandGrowth.FIRST_GROWTH_YEAR * MONTHS)
	return growth


func _fires(growth: DemandGrowth, month: int) -> bool:
	return ColonyConditions.crown_first_leaned_harder({}, _context(growth, month))


# --- 🔒 Once, in the right month --------------------------------------------

func test_it_does_not_fire_before_the_bar_moves() -> void:
	var growth := DemandGrowth.new()
	var streams := RngStreams.new(SEED)
	for year in range(1, DemandGrowth.FIRST_GROWTH_YEAR):
		growth.advance(year, streams, null, year * MONTHS)
		assert_false(_fires(growth, year * MONTHS),
			"the Chancellor announced the squeeze in year %d, before there was one" % year)


func test_it_fires_in_the_month_the_bar_first_moves() -> void:
	var growth := _first_draw()
	assert_true(_fires(growth, DemandGrowth.FIRST_GROWTH_YEAR * MONTHS),
		"year four came, the bar moved, and the Chancellor said nothing")


func test_it_does_not_fire_again_for_the_rest_of_that_year() -> void:
	# **The failure this test exists for.** The levels read the same all year, so
	# a condition written against them would put the same letter on the desk
	# twelve months running.
	var growth := _first_draw()
	var opened := DemandGrowth.FIRST_GROWTH_YEAR * MONTHS
	for month in range(opened + 1, opened + MONTHS):
		assert_false(_fires(growth, month),
			"the announcement came round again in month %d" % month)


func test_it_does_not_fire_on_later_growth() -> void:
	# The bar moves every year from the fourth. The *announcement* happens once:
	# it is news that the game changed, and it can only be news the first time.
	var growth := DemandGrowth.new()
	var streams := RngStreams.new(SEED)
	for year in range(1, 12):
		growth.advance(year, streams, null, year * MONTHS)
		if year > DemandGrowth.FIRST_GROWTH_YEAR:
			assert_false(_fires(growth, year * MONTHS),
				"the Chancellor announced it all over again in year %d" % year)


# --- 🔒 He names what changed ------------------------------------------------

func test_exactly_one_of_the_four_letters_matches() -> void:
	# Four letters, one per axis, so the Chancellor says what direction the
	# Crown's governance took rather than that things are harder now. Two
	# matching would put two announcements on one desk; none would put the bar in
	# motion silently.
	for seed_value in 40:
		var growth := _first_draw(seed_value)
		var context := _context(growth, DemandGrowth.FIRST_GROWTH_YEAR * MONTHS)
		var matched := 0
		for axis in DemandGrowth.DIMENSIONS:
			if ColonyConditions.crown_leaned_on({"axis": axis}, context):
				matched += 1
		assert_eq(matched, 1,
			"seed %d matched %d of the four announcements" % [seed_value, matched])


func test_the_axis_it_names_is_the_axis_that_grew() -> void:
	var growth := _first_draw()
	var drawn := String(growth.history[0])
	var context := _context(growth, DemandGrowth.FIRST_GROWTH_YEAR * MONTHS)
	assert_true(ColonyConditions.crown_leaned_on({"axis": drawn}, context),
		"the bar moved along %s and no letter said so" % drawn)


func test_a_run_that_never_grew_names_nothing() -> void:
	var context := _context(DemandGrowth.new(), MONTHS)
	for axis in DemandGrowth.DIMENSIONS:
		assert_false(ColonyConditions.crown_leaned_on({"axis": axis}, context),
			"a colony in its first year was told the Crown had leaned on %s" % axis)


# --- 🔒 Never skippable ------------------------------------------------------

func test_the_announcement_cannot_be_set_aside() -> void:
	# SPEC §9.3 lets the post pile up, and this is one of the letters it may not.
	for axis in DemandGrowth.DIMENSIONS:
		var id := "chancellor.squeeze_%s" % axis
		var letter := Letter.from_record(content.record("letters", id))
		assert_true(letter != null, "%s is not in the content" % id)
		assert_false(letter.skippable, "%s can be left unread" % id)
		assert_true(letter.has_reply(), "%s gives the player nothing to say back" % id)
