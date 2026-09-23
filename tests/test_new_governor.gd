extends TestCase

## The governor a departing expedition elects (#178,
## `founding-towns.md` §4, SPEC §11.4).
##
## 🔒 **Generated the month it launches, not the month it arrives**, so he can
## write while there is still a journey in which to answer him.
##
## 🔒 **The PC has no say whatever in who he is.** He is elected by the people
## setting out.
##
## 🔒 **His loyalty is inherited from whoever launched him**, and that is more
## than flavour: it makes disloyalty propagate geographically. A sour governor
## seeds a sour daughter town, which will in turn seed another — so a colony with
## one bad town can be growing its second **before the PC has done anything wrong
## at all**. It runs the other way too.

const SEED: int = 5309

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
	var map := WorldMap.new(20, 14, &"ocean")
	for y in range(1, 13):
		for x in range(1, 12):
			map.set_terrain(x, y, &"plains")
	return map


func _town(id: StringName = &"ashmere") -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(9, 7))
	town.workers = 40
	town.governor_id = StringName("governor_%s" % id)
	town.objective_cargo = {"food": 60.0}
	town.store(&"food", 400.0)
	town.receive_gold(900.0)
	return town


func _parent(loyalty: float) -> Contact:
	var contact := Contact.new(&"governor_ashmere")
	contact.role = Governor.ROLE
	contact.display_name = "Mr Barrow"
	contact.relationship.loyalty = loyalty
	return contact


func _context(town: Town, parent: Contact) -> ColonyContext:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), _map())
	context.colony = colony
	context.run_seed = SEED
	context.contacts = {String(parent.id): parent}
	return context


func _launch(loyalty: float) -> Dictionary:
	var town := _town()
	var parent := _parent(loyalty)
	var context := _context(town, parent)
	var party := Expedition.launch(town, context)
	return {
		"party": party, "context": context, "parent": parent,
		"governor": context.contacts.get(String(party.governor)),
	}


# --- 🔒 He exists from the launch month -------------------------------------

func test_the_expedition_leaves_with_a_governor() -> void:
	var run := _launch(60.0)
	assert_true(run["party"] != null, "nothing set out")
	assert_false(String(run["party"].governor).is_empty(),
		"a hundred people walked into the country with nobody in charge")
	assert_true(run["governor"] != null, "he was elected and never written down")
	assert_eq(String(run["governor"].role), String(Governor.ROLE))


func test_the_launch_says_who_he_is() -> void:
	# The letter has to be able to find him, and it finds him off the record.
	var run := _launch(60.0)
	var launched: Array = run["context"].log.of_type(Expedition.EVENT_LAUNCHED)
	assert_eq(launched.size(), 1)
	assert_eq(String(launched[0].payload["governor"]), String(run["party"].governor))


func test_he_writes_the_month_he_is_elected() -> void:
	# 🔒 §4: **he writes to the PC immediately.** The point of that is the window
	# — a letter answered while he is still walking can shift where the town ends
	# up (#177), and a governor who waited for arrival would make it moot.
	var run := _launch(60.0)
	var letter := LetterContext.new(
		WorldValues.initial_state(), run["governor"], &"")
	letter.log = run["context"].log
	letter.month = 0
	assert_true(ColonyConditions.he_has_just_been_elected({"within": 2}, letter),
		"the people elected him and he never wrote home")

	letter.month = 40
	assert_false(ColonyConditions.he_has_just_been_elected({"within": 2}, letter),
		"he was still introducing himself three years later")


func test_his_letter_exists_and_reads_differently_by_tone() -> void:
	var record := content.record("letters", "governor.setting_out")
	assert_false(record.is_empty(), "the new governor never writes")
	var toned: Dictionary = {}
	for line in record["body"]:
		for tone in line.get("only_tones", []):
			toned[String(tone)] = true
	assert_true(toned.has(String(Tone.PLEASED)) and toned.has(String(Tone.HATEFUL)),
		"his first letter reads the same however he feels, so it warns the PC of nothing")


# --- 🔒 Loyalty is inherited ------------------------------------------------

func test_a_sour_parent_seeds_a_sour_daughter() -> void:
	# 🔒 The claim §4 makes, and the reason it matters: **a colony with one bad
	# town can be growing its second before the PC has done anything wrong.**
	var sour := _launch(10.0)
	var warm := _launch(95.0)
	assert_true(sour["governor"].loyalty() < warm["governor"].loyalty(),
		"a hated governor and a loved one sent out men who felt the same way")


func test_it_runs_the_other_way_too() -> void:
	# A patron the PC has treated well hands him a man already inclined to listen.
	var warm := _launch(95.0)
	assert_true(warm["governor"].loyalty() > Governor.START_LOYALTY_MIN,
		"a well-kept governor's daughter town started no better than a stranger's")


func test_he_is_not_simply_his_father() -> void:
	# He was elected by the people setting out, not appointed by his old master.
	# Inheriting **all** of it would make him a copy rather than a consequence.
	var run := _launch(10.0)
	assert_true(run["governor"].loyalty() > run["parent"].loyalty(),
		"he is his father exactly, which makes the election a formality")


func test_a_launcher_nobody_knows_leaves_him_his_own_man() -> void:
	# The Crown-launched case (#180) will pass the proposing contact instead. A
	# launch with nobody behind it must not crash and must not invent a grudge.
	var town := _town()
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), _map())
	var colony := Colony.new()
	colony.add(town)
	context.colony = colony
	context.run_seed = SEED

	var party := Expedition.launch(town, context)
	var him: Contact = context.contacts.get(String(party.governor))
	assert_true(him != null, "nobody was elected at all")
	assert_true(him.loyalty() >= Governor.START_LOYALTY_MIN
			and him.loyalty() <= Governor.START_LOYALTY_MAX,
		"a governor with no parent started somewhere other than his own range")


# --- 🔒 The same seed yields the same man -----------------------------------

func test_the_same_seed_elects_the_same_man() -> void:
	# 🔒 `hash(run_seed, contact_id)` per contact, so what happened elsewhere in
	# the run cannot change who this is.
	var once := _launch(40.0)
	var twice := _launch(40.0)
	assert_eq(once["governor"].display_name, twice["governor"].display_name,
		"the same seed elected two different men")
	assert_almost_eq(once["governor"].loyalty(), twice["governor"].loyalty(), 0.0001)


func test_his_tone_follows_the_loyalty_he_inherited() -> void:
	# 🔒 The acceptance, and the whole point of the first letter: **its tone is
	# the player's only warning that the rot has spread**, and there is nothing
	# he can do to direct the man.
	var sour := Director.tone_for(_launch(5.0)["governor"])
	var warm := Director.tone_for(_launch(98.0)["governor"])
	assert_true(String(sour) != String(warm),
		"the daughter of a hated governor wrote in the same voice as the daughter of a loved one")


func test_the_run_actually_keeps_him() -> void:
	# The wiring, not the rule. A governor elected into a dictionary the run does
	# not share would exist for exactly one month and then be a dangling id on a
	# party — which nothing else would notice until a letter tried to find him.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var driver := ColonyDriver.new(run.colony, run.map, run.run_seed)
	driver.contacts = run.contacts

	var town := run.colony.in_order()[0]
	town.workers = 60
	town.objective_cargo = {"food": 40.0}
	town.store(&"food", 400.0)
	town.receive_gold(900.0)

	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.contacts = driver.contacts
	context.parties = run.parties
	var party := Expedition.launch(town, context)

	assert_true(run.contacts.has(String(party.governor)),
		"the man the people elected never reached the run, so no letter can find him")
	assert_eq(run.parties.size(), 1, "the party never reached the run either")


# --- The save ----------------------------------------------------------------

func test_he_survives_a_save_with_his_relationship_intact() -> void:
	var run := _launch(20.0)
	var him: Contact = run["governor"]
	var restored := Contact.from_dict(him.to_dict())
	assert_eq(restored.display_name, him.display_name)
	assert_almost_eq(restored.loyalty(), him.loyalty(), 0.0001,
		"a reload gave the new governor a fresh opinion of the Crown")

	var party := ExpeditionParty.from_dict(run["party"].to_dict())
	assert_eq(String(party.governor), String(him.id),
		"the party came back from the save with nobody in charge")
