extends TestCase

## The natives reach the PC only through his own people (#208, SPEC §12.5;
## `docs/mechanics/natives.md` §1, §8, `docs/mechanics/perception.md`).
##
## 🔒 **He has no direct instrument and no direct sight.** No tribe writes to
## him. Everything he learns arrives through a man who lives there, through that
## man's lens, a month late.
##
## 🔒 **Standing is never shown and never named.** He sees a governor who is
## uneasy and a Diplomat who is blunt — never a number, a bar, or a word that
## maps one-to-one onto the figure.
##
## 🔒 **And the point of no return is never announced.** A people who have
## concluded the colony means their destruction read the same as a people who
## very nearly have, because the bottom rung of the ladder covers both. He finds
## out because nothing he does helps, and by then it cannot be mended.

const SEED: int = 8821

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## Move a village onto a town's doorstep, so its governor has neighbours.
func _put_a_village_beside(run: RunState, town: Town) -> Village:
	var village: Village = run.tribes.villages_in_order()[0]
	village.at = town.at + Vector2i(1, 0)
	village.people = 60
	return village


## The corner of the map furthest from this town.
##
## **Computed rather than written down.** A fixed corner was fine until #271 made
## the country out of two fields: the first town now lands wherever the geography
## puts it, and a village parked at `1,1` to be out of the way turned out to be
## next door.
func _far_from(run: RunState, town: Town, index: int = 0) -> Vector2i:
	var x := 2 if town.at.x > run.map.width / 2 else run.map.width - 3
	var y := 2 if town.at.y > run.map.height / 2 else run.map.height - 3
	return Vector2i(x, clampi(y - index * 2, 2, run.map.height - 3))


## And move every other village out of the way, so only one people is in view.
func _clear_the_rest(run: RunState, keep: Village) -> void:
	var town := run.colony.in_order()[0]
	var index := 0
	for village in run.tribes.villages_in_order():
		if (village as Village).id == keep.id:
			continue
		(village as Village).at = _far_from(run, town, index)
		index += 1


## A month lived in the town, so the "has he been there" half of the gate is
## satisfied and only the "has he neighbours" half can decide anything.
func _lived(run: RunState, town: Town) -> void:
	run.log.emit(SettlePhase.EVENT_LIVED, town.id, run.world.month, {},
		WorldPhase.COLONY_MONTH)


func _context_for(run: RunState, contact: Contact, town: Town) -> LetterContext:
	var context := LetterContext.new(run.world, contact)
	context.measures = ColonyMeasures.for_contact(run, contact)
	context.town = town
	context.natives = run.tribes
	context.colony = run.colony
	context.log = run.log
	return context


func _all_letters() -> Array:
	var out: Array = []
	for id in content.ids("letters"):
		out.append(Letter.from_record(content.record("letters", String(id))))
	return out


# --- 🔒 Only through his own people -----------------------------------------

func test_no_tribe_ever_writes_to_the_pc() -> void:
	# 🔒 §1, asserted against the content rather than against the code. A dev who
	# added a chief to the roster would trip this before anything else.
	var run := _run()
	var names: Dictionary = {}
	for tribe in run.tribes.in_order():
		names[String((tribe as Tribe).id)] = true
		names[(tribe as Tribe).display_name.to_lower()] = true

	for letter in _all_letters():
		var sender := String(letter.sender).to_lower()
		assert_false(names.has(sender),
			"%s is written by a people who have never heard of the PC" % letter.id)
		assert_false(sender.contains("tribe"),
			"%s is written by something calling itself a tribe" % letter.id)


func test_a_governor_with_no_neighbours_has_nothing_to_say_about_them() -> void:
	# 🔒 The acceptance. A governor who has never seen a tribe never mentions one,
	# and the way that is made true is that he has nothing to judge.
	var run := _run()
	var town := run.colony.in_order()[0]
	var index := 0
	for village in run.tribes.villages_in_order():
		(village as Village).at = _far_from(run, town, index)
		index += 1

	# **A month lived, so only the neighbours can decide this.** Without it the
	# gate says no for the other reason and the test passes for the wrong one.
	_lived(run, town)

	var measures := ColonyMeasures.for_contact(run, run.contact(town.governor_id))
	assert_false(measures.has(ColonyMeasures.NATIVE_REGARD),
		"a governor who has never seen a native had an opinion of one")

	var context := _context_for(run, run.contact(town.governor_id), town)
	assert_false(ContentRegistry.test_condition("i_have_neighbours", {}, context),
		"a governor with nobody next door was cleared to write about them")


func test_a_governor_who_has_only_just_landed_writes_about_the_harvest() -> void:
	# The other half of the gate, and #81's lesson learned again: a man writing
	# home about the neighbours in the month he stepped off the boat has not met
	# them, he has seen smoke.
	var run := _run()
	var town := run.colony.in_order()[0]
	_put_a_village_beside(run, town)

	var context := _context_for(run, run.contact(town.governor_id), town)
	assert_true(context.measures.has(ColonyMeasures.NATIVE_REGARD),
		"the fixture did not put anybody next door")
	assert_false(ContentRegistry.test_condition("i_have_neighbours", {}, context),
		"a governor wrote home about the natives before his first harvest")

	_lived(run, town)
	assert_true(ContentRegistry.test_condition("i_have_neighbours", {}, _context_for(
		run, run.contact(town.governor_id), town)),
		"a governor who has lived a year beside them still had nothing to say")


func test_a_governor_with_a_village_in_his_fields_does() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	_put_a_village_beside(run, town)

	var measures := ColonyMeasures.for_contact(run, run.contact(town.governor_id))
	assert_true(measures.has(ColonyMeasures.NATIVE_REGARD),
		"a governor with a village at the end of his street had nothing to report")
	assert_true(float(measures[ColonyMeasures.NATIVE_PRESSURE]) > 0.0,
		"their fields were in his and he did not notice")


func test_an_officer_an_ocean_away_knows_nothing_of_them() -> void:
	# The Crown's officers write about the colony. Nobody in London has seen a
	# native, and no ladder of theirs should pretend otherwise.
	var run := _run()
	_put_a_village_beside(run, run.colony.in_order()[0])
	for id in ["steward", "chancellor", "marshal", "provost"]:
		var officer := run.contact(StringName(id))
		if officer == null:
			continue
		assert_false(
			ColonyMeasures.for_contact(run, officer).has(ColonyMeasures.NATIVE_REGARD),
			"%s, three thousand miles off, had a view of the natives" % id)


func test_the_diplomat_reports_more_widely_than_his_own_doorstep() -> void:
	# 🔒 §8.1: he is the one man who reports more widely and more sharply, which
	# is what he is for — and he governs nothing, so he would otherwise fall out
	# with the Crown's officers.
	var run := _run()
	var town := run.colony.in_order()[0]
	_put_a_village_beside(run, town)
	var diplomat := run.contact(&"diplomat")
	assert_true(diplomat != null, "there is no Diplomat to ask")

	assert_true(
		ColonyMeasures.for_contact(run, diplomat).has(ColonyMeasures.NATIVE_REGARD),
		"the one man paid to go out and look had nothing to say")


func test_the_diplomat_names_the_people_the_colony_has_most_to_fear() -> void:
	var run := _run()
	_put_a_village_beside(run, run.colony.in_order()[0])
	var angriest := run.tribes.the_angriest()
	angriest.standing[String(Tribe.COLONY)] = 6.0

	var context := LetterContext.new(run.world, run.contact(&"diplomat"))
	context.natives = run.tribes
	context.measures = ColonyMeasures.for_contact(run, run.contact(&"diplomat"))
	assert_eq(
		String(ContentRegistry.supply_param(
			"neighbour_tribe", {"fallback": "natives"}, context)),
		angriest.display_name,
		"he wrote about whichever people were nearest rather than the worst of them")


# --- 🔒 Two men, one tribe, two true accounts -------------------------------

func test_two_governors_can_describe_the_same_tribe_differently() -> void:
	# 🔒 SPEC §9.1 working rather than failing. Both words are true of the same
	# state: the resolver caps a lean at one rung, so they may differ and may
	# never flatly contradict.
	var ladder := PackedStringArray([
		"settled on being rid of us", "cold", "wary", "civil enough", "friendly",
	])
	var regard := 46.0

	var gloomy := Perception.word(
		ColonyMeasures.NATIVE_REGARD, regard, -0.3, ladder)
	var hopeful := Perception.word(
		ColonyMeasures.NATIVE_REGARD, regard, 0.3, ladder)
	assert_true(gloomy != hopeful,
		"two men of opposite temperament described the same people identically")

	var truth := Perception.truthful_rung(
		ColonyMeasures.NATIVE_REGARD, regard, ladder.size())
	for lean in [-1.0, -0.3, 0.0, 0.3, 1.0]:
		var said := Perception.rung(
			ColonyMeasures.NATIVE_REGARD, regard, float(lean), ladder.size())
		assert_true(absi(said - truth) <= 1,
			"a governor's temperament moved the account more than one rung")


func test_a_governor_leans_on_the_neighbours_like_everything_else() -> void:
	# `contacts.md`: what makes him a lens rather than a readout. Without the
	# topic in his `cares_about` the ladder would read straight, and two
	# governors could never disagree about a people they both border.
	var run := _run()
	var governor := run.contact(run.colony.in_order()[0].governor_id)
	assert_true(governor.cares_about.has(ColonyMeasures.NATIVE_REGARD),
		"a governor reported the natives as a clerk reports a total")


# --- 🔒 Never shown, never named --------------------------------------------

func test_nothing_in_any_letter_renders_a_standing() -> void:
	# 🔒 The acceptance, against the content. A `{param:}` is exact and truthful,
	# so a param carrying standing would put the number on the page — which is
	# why there is no param source that could produce one.
	for letter in _all_letters():
		for name in letter.params:
			var kind := String(letter.params[name])
			assert_false(kind == "regard" and String(letter.id).contains("tribe"),
				"%s declares a tribe's regard as an exact figure" % letter.id)

	# And the only measures that touch a tribe are judged, never printed.
	for letter in _all_letters():
		var judged: Dictionary = {}
		for slot in letter.perception:
			judged[String(letter.perception[slot].get("measure", ""))] = true
		if not judged.has(ColonyMeasures.NATIVE_REGARD):
			continue
		for line in letter.body:
			assert_false(String(line.get("text", "")).contains("{param:regard}"),
				"%s prints what a people think of the colony" % letter.id)


func test_no_ladder_rung_about_them_is_a_number() -> void:
	for letter in _all_letters():
		for slot in letter.perception:
			var entry: Dictionary = letter.perception[slot]
			if String(entry.get("measure", "")) != ColonyMeasures.NATIVE_REGARD:
				continue
			var ladder: Array = entry.get("ladder", [])
			assert_true(ladder.size() >= 2, "%s judges them on no ladder" % letter.id)
			for rung in ladder:
				assert_true(String(rung).strip_edges().is_valid_float() == false,
					"%s puts a figure on the page as a rung" % letter.id)


func test_the_point_of_no_return_is_never_announced() -> void:
	# 🔒 The sharpest case. A people who have concluded the colony means their
	# destruction and a people who very nearly have get **the same word** — so the
	# player cannot read off which it is, and finds out because nothing he does
	# helps.
	var ladder := PackedStringArray([
		"settled on being rid of us", "cold", "wary", "civil enough", "friendly",
	])
	var concluded := Perception.word(
		ColonyMeasures.NATIVE_REGARD, Tribe.MINIMUM, 0.0, ladder)
	var nearly := Perception.word(
		ColonyMeasures.NATIVE_REGARD, Tribe.IRRECONCILABLE_BELOW, 0.0, ladder)
	assert_eq(concluded, nearly,
		"the ladder tells the player which of two peoples is past saving")


func test_no_event_the_player_can_read_says_they_have_concluded() -> void:
	# The latch emits, because the sim needs it — but the payload carries no
	# figure and nothing renders it. Asserted here so a later letter that fired
	# on it has to argue with this test first.
	var run := _run()
	var tribe := run.tribes.the_angriest()
	tribe.standing[String(Tribe.COLONY)] = Tribe.IRRECONCILABLE_BELOW + 1.0
	var context := ColonyContext.new(
		run.world, run.log, run.streams, run.map)
	TribeStanding.aggression(tribe, 4.0, "a village burned", context)
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY), "the fixture did nothing")

	for id in content.ids("triggers"):
		var trigger: Dictionary = content.record("triggers", String(id))
		for entry in trigger.get("conditions", []):
			for condition in entry:
				assert_false(String(condition).contains("irreconcilable"),
					"%s fires a letter announcing a conclusion" % id)


# --- Through the real post ---------------------------------------------------

func test_a_governor_beside_a_village_writes_home_about_it() -> void:
	# The whole ticket end to end: the simulation of #203 to #205 becomes
	# something the player can actually see.
	var run := _run()
	var town := run.colony.in_order()[0]
	var village := _put_a_village_beside(run, town)
	_clear_the_rest(run, village)
	var tribe := run.tribes.find(village.tribe)

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	# **Four years, not two** (#254). A governor writes one letter a month now,
	# about whichever of his concerns is loudest, and this one has a year's
	# cooldown besides — so it waits its turn among the harvest, the shortages
	# and the men in his fields. Two years was enough when every true letter
	# fired; it is not enough when he has to *want* to send this one.
	var wrote := false
	var named := false
	for _month in 48:
		machine.begin_turn()
		for inbound in run.inbox:
			if inbound.letter_id == "governor.the_people_next_door":
				wrote = true
				# 🔒 **The one exact fact about a people**: which people they are.
				named = named or String(inbound.params.get("tribe", "")) \
					== tribe.display_name
				assert_false(inbound.params.has("regard"),
					"the letter carried what they think of him as a figure")
			inbound.status = InboundLetter.SET_ASIDE
		machine.send_post()

	assert_true(wrote,
		"four years beside a village and no governor mentioned it once")
	assert_true(named, "he wrote about the natives without saying which people")
