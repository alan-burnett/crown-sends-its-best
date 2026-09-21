extends TestCase

## The letters that carry M3 (#82, SPEC §10.3, §12.3).
##
## 🔒 **Nothing in M3 is ever shown as a number**, so these letters *are* the
## interface. Standing is four invisible bands and rebel sentiment is invisible
## entirely; a player with no letters about them is a player flying blind.
##
## 🔒 **The ladder runs both ways.** A Crown that went quiet on the way back up
## would teach the player that recovering is not a thing that happens.

const SEED: int = 5501

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


func _context(log: EventLog, month: int = 3) -> LetterContext:
	var context := LetterContext.new(WorldValues.initial_state(), null, &"")
	context.log = log
	context.month = month
	return context


## The Crown thinks about the PC and reaches a verdict, as phase 6 does.
func _judged(log: EventLog, month: int, band: StringName, was: StringName) -> void:
	log.emit(CrownStanding.EVENT_MOVED, &"crown", month, {
		"band": String(band),
		"was": String(was),
		"changed_band": String(band) != String(was),
		"monthly_net": 0.0,
		"net_position": 0.0,
		"horizon": 0.0,
		"judgement": 0.0,
	}, WorldPhase.RUN_END_CHECK)


func _declared(log: EventLog, month: int, town: StringName) -> void:
	log.emit(Rebellion.EVENT_DECLARED, town, month, {
		"town": String(town), "population": 40, "governor": "governor_%s" % town,
	}, WorldPhase.COLONY_MONTH)


func _town(id: StringName) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = 20
	town.governor_id = StringName("governor_%s" % id)
	return town


# --- 🔒 Every band has a letter, and they are told apart by band -------------

func test_each_band_answers_for_itself_and_no_other() -> void:
	for band in CrownStanding.BANDS:
		var log := EventLog.new()
		_judged(log, 3, band, band)
		var context := _context(log)
		for other in CrownStanding.BANDS:
			var matched := ColonyConditions.crown_standing_is({"band": String(other)}, context)
			assert_eq(matched, String(other) == String(band),
				"in '%s' the letter for '%s' %s" % [
					band, other, "did not fire" if matched == false else "fired as well"])


func test_every_band_the_ticket_names_has_a_letter() -> void:
	# 🔒 The ladder is the whole interface. A band with no letter is a stretch of
	# a run in which the player is told nothing at all.
	var letters: Dictionary = {}
	for id in content.ids("triggers"):
		var trigger := content.record("triggers", id)
		for condition in trigger.get("conditions", []):
			if condition.has("crown_standing_is"):
				letters[String(condition["crown_standing_is"].get("band", ""))] = true
	for band in [CrownStanding.BAND_CONCERN, CrownStanding.BAND_ALARM]:
		assert_true(letters.has(String(band)),
			"nothing is ever written to a player whose standing sits at '%s'" % band)


func test_the_warnings_are_never_culled() -> void:
	# 🔒 §9.6: a mass promise break produces several aggrieved letters at once and
	# the budget culls `skippable` ones — **never the warnings**. A warning the
	# player never sees is a trap rather than a warning.
	for id in ["steward.standing_concern", "steward.standing_alarm",
			"chancellor.final_warning", "governor.town_has_declared"]:
		var record := content.record("letters", id)
		assert_false(record.is_empty(), "%s does not exist" % id)
		assert_false(bool(record.get("skippable", true)),
			"%s can be culled, so the player may never be told" % id)


# --- 🔒 The ladder runs both ways -------------------------------------------

func test_climbing_back_produces_a_letter() -> void:
	var log := EventLog.new()
	_judged(log, 3, CrownStanding.BAND_CONCERN, CrownStanding.BAND_ALARM)
	var context := _context(log)
	assert_true(ColonyConditions.crown_standing_changed({"direction": "up"}, context),
		"a colony that climbed out of Alarm heard nothing about it")
	assert_false(ColonyConditions.crown_standing_changed({"direction": "down"}, context))


func test_falling_produces_a_letter_too() -> void:
	var log := EventLog.new()
	_judged(log, 3, CrownStanding.BAND_ALARM, CrownStanding.BAND_CONCERN)
	var context := _context(log)
	assert_true(ColonyConditions.crown_standing_changed({"direction": "down"}, context))
	assert_false(ColonyConditions.crown_standing_changed({"direction": "up"}, context),
		"falling into Alarm was reported as an improvement")


func test_a_month_that_changed_nothing_says_nothing() -> void:
	var log := EventLog.new()
	_judged(log, 3, CrownStanding.BAND_CONCERN, CrownStanding.BAND_CONCERN)
	var context := _context(log)
	assert_false(ColonyConditions.crown_standing_changed({"direction": "up"}, context))
	assert_false(ColonyConditions.crown_standing_changed({"direction": "down"}, context),
		"a steady month was reported as a change in either direction")


func test_it_reads_this_month_rather_than_the_worst_month() -> void:
	# The Crown's **current** view. A letter reading the whole log would be
	# writing about a crisis the player has already climbed out of.
	var log := EventLog.new()
	_judged(log, 1, CrownStanding.BAND_ALARM, CrownStanding.BAND_CONCERN)
	_judged(log, 2, CrownStanding.BAND_CONCERN, CrownStanding.BAND_ALARM)
	# And a month that has not happened yet, which a letter written now cannot
	# know about. The log outlives the month; the letter must not.
	_judged(log, 5, CrownStanding.BAND_LOST, CrownStanding.BAND_CONCERN)

	var context := _context(log, 2)
	assert_true(ColonyConditions.crown_standing_is({"band": "concern"}, context))
	assert_false(ColonyConditions.crown_standing_is({"band": "alarm"}, context),
		"the Steward was still writing about last month's crisis")
	assert_false(ColonyConditions.crown_standing_is({"band": "lost"}, context),
		"the Steward wrote in March about a verdict the Crown reaches in June")


# --- 🔒 A rebellion is news, and to more than one person ---------------------

func test_the_governor_of_the_town_that_declared_writes_and_the_others_do_not() -> void:
	var log := EventLog.new()
	_declared(log, 4, &"ashmere")

	var his := _context(log, 5)
	his.town = _town(&"ashmere")
	assert_true(ColonyConditions.my_town_declared({"within": 2}, his),
		"the town declared and its own governor wrote nothing")
	assert_false(ColonyConditions.a_neighbour_declared({"within": 3}, his),
		"he wrote about his own town's rebellion as though it were somebody else's")

	var theirs := _context(log, 5)
	theirs.town = _town(&"brackwater")
	assert_false(ColonyConditions.my_town_declared({"within": 2}, theirs),
		"every governor in the colony wrote a resignation letter")
	assert_true(ColonyConditions.a_neighbour_declared({"within": 3}, theirs),
		"the town next door declared and nobody mentioned it")


func test_a_rebellion_stops_being_news() -> void:
	var log := EventLog.new()
	_declared(log, 1, &"ashmere")
	var stale := _context(log, 40)
	stale.town = _town(&"brackwater")
	assert_false(ColonyConditions.a_neighbour_declared({"within": 3}, stale),
		"a governor was still writing about a rebellion three years old")


func test_the_return_has_a_letter_too() -> void:
	# The ladder of rebellion runs both ways as well — `rebel-sentiment.md` §2's
	# attribution exists so a rebel town **can** come home, and coming home has
	# to be audible or the player never learns that it is possible.
	assert_false(content.record("letters", "governor.we_are_coming_back").is_empty(),
		"a town can return to the Crown and nobody writes to say so")


# --- 🔒 Five tones, and no figures ------------------------------------------

func test_the_new_letters_carry_no_standing_figure() -> void:
	# 🔒 SPEC §10.3. These letters exist **because** the number may not be shown;
	# one that declared it as a param would be the number, in prose.
	for id in ["steward.standing_concern", "steward.standing_alarm",
			"steward.standing_recovering"]:
		var record := content.record("letters", id)
		for name in record.get("params", {}):
			assert_false(String(name).contains("standing"),
				"%s takes a standing figure as a param" % id)
		var text := JSON.stringify(record.get("body", []))
		assert_false(text.contains("{param:band}"), "%s renders the band as a figure" % id)


func test_the_colony_uses_all_five_tones_somewhere() -> void:
	# Not per letter — per body of content. A tone nothing is ever written in is
	# a tone the director can select and find nothing to say in.
	var seen: Dictionary = {}
	for id in content.ids("letters"):
		var record := content.record("letters", id)
		for line in record.get("body", []):
			for tone in line.get("only_tones", []):
				seen[String(tone)] = true
	for tone in Tone.ALL:
		assert_true(seen.has(String(tone)),
			"nothing anywhere in the colony's post is written in '%s'" % tone)
