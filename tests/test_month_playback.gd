extends TestCase

## Map playback: which of a month's events the map plays, and for how long (#296,
## `docs/mechanics/beats.md` §6).
##
## 🔒 Filters, then scoring, then a budget — and the list is a pure function of
## the log and the map the colony knows, so it is asserted here without a
## viewport. Nothing here asserts a tuning figure: every number is read off
## `MonthPlayback`'s own constants.

const SEED: int = 2960

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


## A map the colony has explored around the origin, out to `reach` tiles.
func _known(reach: int = 8) -> MapKnowledge:
	var knowledge := MapKnowledge.new()
	for x in range(0, reach):
		for y in range(0, reach):
			knowledge.seen[Vector2i(x, y)] = true
	return knowledge


const TOWNS: Dictionary = {"ashmere": Vector2i(2, 2), "kettleburn": Vector2i(5, 5)}


## The events one month emitted, starting at `seq_mark` in `log`.
func _month(log: EventLog, from_seq: int) -> Array[SimEvent]:
	return log.since(from_seq)


# --- 🔒 Filters ----------------------------------------------------------------

func test_nothing_outside_the_known_map_is_drawn() -> void:
	# SPEC §11.2: the map shows what the colony knows. A battle in unexplored
	# country is not a beat however large it is.
	var log := EventLog.new()
	var mark := log.next_seq()
	log.emit(&"battle_fought", &"company_a", 3, {"at": [40, 40]})
	log.emit(&"battle_fought", &"company_b", 3, {"at": [3, 3]})
	var beats := MonthPlayback.select(_month(log, mark), log, _known(), TOWNS)
	assert_eq(beats.size(), 1, "a battle nobody saw was played back")
	for beat in beats:
		assert_ne(_known().state_of(beat.place), MapKnowledge.UNEXPLORED,
			"a beat was drawn on ground the colony has never explored")


func test_nothing_without_a_place() -> void:
	# Crown standing moving is not a map event; it belongs to the ledger and the
	# letters. Nor is a map event that cannot be put on a tile.
	var log := EventLog.new()
	var mark := log.next_seq()
	log.emit(&"crown_standing_moved", &"crown", 3, {"band": "concern"})
	log.emit(&"expedition_attacked", &"expedition_7", 3, {"town": "nowhere_known"})
	assert_empty(MonthPlayback.select(_month(log, mark), log, _known(), TOWNS),
		"something with no place on the map was played on it")


func test_a_subject_is_found_where_it_was_last_seen() -> void:
	# An expedition set upon says who, not where; its last march says where.
	var log := EventLog.new()
	log.emit(&"expedition_moved", &"expedition_7", 2, {"at": [6, 1]})
	var mark := log.next_seq()
	log.emit(&"expedition_attacked", &"expedition_7", 3, {"expedition": "expedition_7"})
	var beats := MonthPlayback.select(_month(log, mark), log, _known(), TOWNS)
	assert_eq(beats.size(), 1, "the attack was dropped for want of a place")
	if not beats.is_empty():
		assert_eq(beats[0].place, Vector2i(6, 1), "it was put somewhere it never was")


# --- 🔒 Scoring ----------------------------------------------------------------

func test_a_colony_growing_quietly_for_a_year_stops_spending_beats_on_it() -> void:
	# The acceptance line. Routine repetition is damped as the director damps a
	# topic, off the log, so the thirteenth month of the same growth plays nothing.
	var log := EventLog.new()
	var first := MonthPlayback.select(_grew(log, 0), log, _known(), TOWNS)
	assert_eq(first.size(), 1, "a town growing for the first time was not worth a beat")
	var later: Array[Beat] = []
	for month in range(1, MonthPlayback.DAMPER_MONTHS + 1):
		later = MonthPlayback.select(_grew(log, month), log, _known(), TOWNS)
	assert_empty(later, "a year of the same quiet growth was still being played back")


func _grew(log: EventLog, month: int) -> Array[SimEvent]:
	var mark := log.next_seq()
	log.emit(&"town_grew", &"ashmere", month, {"town": "ashmere", "born": 1, "population": 20})
	return _month(log, mark)


func test_something_new_is_not_damped_by_something_old() -> void:
	# The damper is per subject: a year of Ashmere growing says nothing about
	# Kettleburn growing for the first time.
	var log := EventLog.new()
	for month in MonthPlayback.DAMPER_MONTHS:
		_grew(log, month)
	var mark := log.next_seq()
	log.emit(&"town_grew", &"kettleburn", MonthPlayback.DAMPER_MONTHS, {"town": "kettleburn"})
	assert_eq(MonthPlayback.select(_month(log, mark), log, _known(), TOWNS).size(), 1)


# --- 🔒 The budget is time ------------------------------------------------------

func test_a_violent_month_is_trimmed_to_its_time() -> void:
	var log := EventLog.new()
	var mark := log.next_seq()
	for index in 40:
		log.emit(&"battle_fought", StringName("company_%d" % index), 3,
			{"at": [index % 8, (index / 8) % 8]})
	var beats := MonthPlayback.select(_month(log, mark), log, _known(), TOWNS)
	assert_true(beats.size() < 40, "forty battles all played, so nothing was trimmed")
	assert_true(MonthPlayback.seconds_of(beats) <= MonthPlayback.TARGET_SECONDS + 0.001,
		"a violent month ran past its time: %.1fs" % MonthPlayback.seconds_of(beats))


func test_a_quiet_month_and_a_violent_one_take_about_as_long() -> void:
	# §6: ten short beats and four long ones should take about as long. A thin
	# month is paced out toward the target rather than flashing past.
	var quiet_log := EventLog.new()
	var quiet_mark := quiet_log.next_seq()
	for index in 6:
		quiet_log.emit(&"settlers_arrived", StringName("town_%d" % index), 3,
			{"at": [index, 1]})
	var quiet := MonthPlayback.seconds_of(
		MonthPlayback.select(_month(quiet_log, quiet_mark), quiet_log, _known(), TOWNS))

	var violent_log := EventLog.new()
	var violent_mark := violent_log.next_seq()
	for index in 40:
		violent_log.emit(&"battle_fought", StringName("company_%d" % index), 3,
			{"at": [index % 8, (index / 8) % 8]})
	var violent := MonthPlayback.seconds_of(
		MonthPlayback.select(_month(violent_log, violent_mark), violent_log, _known(), TOWNS))

	assert_true(absf(quiet - violent) <= MonthPlayback.BEAT_CEILING,
		"a quiet month took %.1fs and a violent one %.1fs" % [quiet, violent])


func test_the_month_is_played_in_the_order_it_happened() -> void:
	var log := EventLog.new()
	var mark := log.next_seq()
	log.emit(&"town_grew", &"ashmere", 3, {"town": "ashmere"})
	log.emit(&"battle_fought", &"company_a", 3, {"at": [3, 3]})
	log.emit(&"building_completed", &"kettleburn", 3, {"town": "kettleburn"})
	var kinds := PackedStringArray()
	for beat in MonthPlayback.select(_month(log, mark), log, _known(), TOWNS):
		kinds.append(String(beat.kind))
	assert_eq(kinds, PackedStringArray(["grew", "battle", "built"]),
		"the month was told by importance rather than in order")


# --- 🔒 Deterministic, from a real run ------------------------------------------

func test_the_same_seed_plays_the_same_months() -> void:
	# Same seed and decisions, same beat list — asserted over real months, since
	# a fixture cannot find an iteration-order bug the sim does not have.
	assert_eq(_played(SEED), _played(SEED), "two identical runs played different months")
	assert_false(_played(SEED).is_empty(), "six months played nothing, so this proves nothing")


func _played(seed_value: int) -> Array:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var played: Array = []
	for turn in 6:
		machine.begin_turn()
		for inbound in run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		var mark := run.log.next_seq()
		machine.send_post()
		var towns: Dictionary = {}
		for town in run.colony.in_order():
			towns[String((town as Town).id)] = (town as Town).at
		for beat in MonthPlayback.select(run.log.since(mark), run.log, run.knowledge, towns):
			played.append(beat.to_dict())
	return played
