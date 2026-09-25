extends TestCase

## The Provost presses a town toward learning (#401, `governor-agendas.md` §2,
## §13, `governor-objectives.md` §4).
##
## 🔒 He urges, as the PC can. At low regard, with a library buildable and none
## in the colony, an urging **in his name** reaches a governor's intent — never
## the town's objective (SPEC §8.5) — and the PC's own urging is still standing
## afterwards (#405).

const SEED: int = 401

var content: ContentDatabase = null
var run: RunState = null
var machine: TurnMachine = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

## The first town, quiet and well found, with a theatre and the makings of a
## library — and a Provost who thinks little of the PC.
func _ready_to_learn(theatre: bool = true) -> Town:
	var town: Town = run.colony.in_order()[0]
	if theatre:
		town.add_building(&"theatre")
	town.store(&"wood", 200.0)
	town.store(&"stone", 200.0)
	town.receive_gold(10_000.0)
	town.quality_of_life = 0.95
	town.safety = 1.0
	town.store(&"food", town.mouths() * ColonyNeeds.per_head(&"food") * 6.0)
	_regard(20.0)
	return town


func _regard(loyalty: float) -> void:
	run.contact(Provost.ID).relationship.loyalty = loyalty


## Phase 8: whatever he means to do, he commits to.
func _press() -> void:
	ProvostDriver.new(run).on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)


## Phase 2 of the month after: it lands.
func _land() -> void:
	run.world.month += 1
	var executor := UrgeIntentExecutor.new()
	executor.colony = run.colony
	IntentExecutor.run_month([executor], run.intents, run.world, run.log)


func _his() -> Array[Intent]:
	return run.intents.live_for_source(Provost.ID)


## A governor who weighs every consideration at one and has put the Crown's
## appointment behind him, so the question is only whether the urging reached him.
func _even_handed(town: Town) -> Contact:
	var contact := Contact.new(town.governor_id)
	contact.relationship = Relationship.new(town.governor_id, 60.0)
	for id in IntentConsiderations.ALL:
		contact.set_weight(StringName(id), 1.0)
	contact.set_weight(IntentConsiderations.MANDATE, 0.0)
	return contact


## Phase 8 of the month it landed: the governor re-deliberates.
func _deliberate(town: Town) -> void:
	var governors := GovernorDriver.new(run.colony, run.map)
	governors.actors[String(town.governor_id)] = _even_handed(town)
	governors.on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.contacts = run.contacts
	context.territory = run.territory_now()
	return context


# --- 🔒 He urges -------------------------------------------------------------------

func test_at_low_regard_he_urges_a_town_toward_learning() -> void:
	var town := _ready_to_learn()
	var objective := town.objective
	var held := town.intent
	_press()
	assert_eq(_his().size(), 1, "a Provost at low regard pressed nobody")
	_land()
	var his := town.urging_by(Provost.ID)
	assert_true(his != null, "his pressing never reached the town")
	assert_eq(String(his.target), String(GovernorIntent.EDUCATION))
	assert_true(his.strength > 1.0, "the Provost's act pulls no harder than a plain letter")
	assert_eq(String(town.intent), String(held), "the Provost set a governor's intent outright")
	assert_eq(String(town.objective), String(objective), "the Provost touched an objective")


func test_the_governor_turns_to_learning_and_the_walk_finds_the_library() -> void:
	var town := _ready_to_learn()
	var objective := town.objective
	_press()
	_land()
	_deliberate(town)
	assert_eq(String(town.intent), String(GovernorIntent.EDUCATION),
		"the governor was pressed toward learning and did not turn to it")
	assert_eq(String(town.objective), String(objective), "deliberating an intent touched the objective")
	assert_eq(String(AgendaMenu.walk(town, town.intent, _context())["id"]), "library",
		"the menu walk under learning did not come to the library")


func test_the_pcs_own_urging_still_stands_afterwards() -> void:
	var town := _ready_to_learn()
	town.urge(Urging.from_pc(GovernorIntent.MILITARY, run.world.month, Tone.DESPERATE))
	var month := run.world.month
	_press()
	_land()
	var pc := town.urging_by(Urging.PC)
	assert_true(pc != null, "the Provost's urging erased the PC's")
	assert_eq(String(pc.target), String(GovernorIntent.MILITARY))
	assert_eq(pc.month, month, "the PC's urging was refreshed or replaced")
	assert_eq(String(pc.tone), String(Tone.DESPERATE))


# --- 🔒 And only when all three hold ---------------------------------------------

func test_not_above_low_regard() -> void:
	_ready_to_learn()
	_regard(Relationship.MEDIUM_AT)
	_press()
	assert_empty(_his(), "a Provost on ordinary terms with the PC went round him")


func test_not_while_a_library_stands_anywhere() -> void:
	_ready_to_learn()
	var learned := Town.new(&"zz_learned", "Learned", run.colony.in_order()[0].at + Vector2i(6, 0))
	learned.workers = 1_000
	learned.add_building(&"library")
	run.colony.add(learned)
	_press()
	assert_empty(_his(), "he pressed for a library with one already in the colony")


func test_not_where_no_town_could_build_one() -> void:
	# No theatre, so no library yet: the theatre comes first.
	_ready_to_learn(false)
	_press()
	assert_empty(_his(), "he pressed a town that could not build a library")


func test_once_until_it_has_faded() -> void:
	var town := _ready_to_learn()
	_press()
	_press()
	# Every Intent he ever committed, not only the live ones: a second pressing
	# would overtake the first and leave one live all the same.
	var ever := 0
	for intent in run.intents.all():
		if intent.source == Provost.ID:
			ever += 1
	assert_eq(ever, 1, "he pressed twice before the first had landed")
	_land()
	_press()
	assert_empty(_his(), "he pressed again while his urging still stood")
	run.world.month += 240
	_press()
	assert_eq(_his().size(), 1, "a long-faded urging kept him quiet for ever")
	assert_true(town.urging_by(Provost.ID) != null)


# --- 🔒 Both letters, and neither without the act ---------------------------------
#
# Whether a letter is **true** is the question here. Whether the man bothers to
# send it that month is the director's (#254), and neither letter is exempt from
# it: going round the PC is a man choosing to write, not a warning the Crown would
# be wronged by missing (#366).

const HE_WENT_ROUND := "trigger.provost.i_went_round_you"
const HE_GAVE_WAY := "trigger.governor.i_have_been_pressed"


func _true(trigger_id: String, contact: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(
		content.collection("triggers")[trigger_id], director._context(run, contact))


## The letter as it would land, values supplied.
func _written(trigger_id: String, contact: Contact) -> InboundLetter:
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[trigger_id]
	var letter := Letter.from_record(content.record("letters", String(trigger["letter"])))
	return director._inbound(trigger, letter, contact, director._context(run, contact), run)


func test_both_letters_are_true_once_it_has_landed() -> void:
	var town := _ready_to_learn()
	var provost := run.contact(Provost.ID)
	var governor := run.contact(town.governor_id)
	_press()
	_land()
	_deliberate(town)
	assert_true(_true(HE_WENT_ROUND, provost), "the Provost could not say what he had done")
	assert_true(_true(HE_GAVE_WAY, governor), "the governor could not say he had been pressed")
	assert_eq(String(_written(HE_WENT_ROUND, provost).params.get("town", "")), town.display_name)
	assert_eq(String(_written(HE_GAVE_WAY, governor).params.get("who", "")), provost.display_name)


func test_neither_is_true_without_the_act() -> void:
	var town := _ready_to_learn()
	_regard(Relationship.HIGH_AT)
	_press()
	# The PC's own letter urging the same governor, landed the way his letters
	# land, is not the Provost going round him.
	run.intents.commit(Intent.new(
		&"", UrgeIntentExecutor.KIND, town.governor_id, town.governor_id, 1,
		{"intent": String(GovernorIntent.GO_TALL)}), run.log, run.world.month)
	_land()
	assert_true(town.urging_by(Urging.PC) != null, "the fixture's PC letter never landed")
	assert_false(_true(HE_WENT_ROUND, run.contact(Provost.ID)), "the Provost reported an act he never did")
	assert_false(_true(HE_GAVE_WAY, run.contact(town.governor_id)), "a governor reported being pressed by nobody")


func test_the_governor_does_not_claim_to_have_given_way_when_he_has_not() -> void:
	# SPEC §9.1: the letter says the town is to see to its learning, so it is
	# true only once it is.
	var town := _ready_to_learn()
	_press()
	_land()
	assert_ne(String(town.intent), String(GovernorIntent.EDUCATION), "the fixture's governor had already turned")
	assert_true(_true(HE_WENT_ROUND, run.contact(Provost.ID)))
	assert_false(_true(HE_GAVE_WAY, run.contact(town.governor_id)),
		"a governor who had not turned to learning wrote that he had given way")
