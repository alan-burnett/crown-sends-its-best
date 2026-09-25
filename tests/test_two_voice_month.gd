extends TestCase

## The two-voice month (#404; the Author's ruling is on the ticket).
##
## 🔒 **A paired letter never arrives alone**: the companion is composed only
## beside its lead, in the same post, and never in the ordinary sweep.
##
## 🔒 **Neither bypasses its own conditions**: the companion's must hold, or the
## lead goes alone.
##
## 🔒 **The pair counts as one** against the budget: a lead culled brings nobody,
## and a lead kept brings its companion even when it filled the last place.

const SEED: int = 404
const LEAD := "trigger.steward.request_tax_rise"
const COMPANION := "trigger.governor.a_rise_would_be_felt"

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
	run.world.month = 2


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


func _governor() -> Contact:
	return run.contact(_town().governor_id)


## The Steward's proposed rise, as the director would compose it.
func _lead() -> InboundLetter:
	var director := machine.director
	var steward := run.contact(&"steward")
	var letter := Letter.from_record(content.record("letters", "steward.request_tax_rise"))
	return director._inbound(content.collection("triggers")[LEAD], letter, steward,
		director._context(run, steward), run)


## The governor's town bought clothing last month.
func _his_town_trades_clothing() -> void:
	run.log.emit(Trade.EVENT_BOUGHT, _town().id, run.world.month - 1, {
		"town": String(_town().id), "resource": "clothing", "quantity": 5.0, "tax": 1.0,
	}, WorldPhase.COLONY_MONTH)


func _paired(letters: Array[InboundLetter]) -> Array[InboundLetter]:
	return machine.director._with_companions(letters, run)


## Letters the budget must keep, that bring nobody.
func _unskippable(count: int) -> Array[InboundLetter]:
	var out: Array[InboundLetter] = []
	for index in count:
		out.append(InboundLetter.new("chancellor.standing_warning", &"chancellor", Tone.DUTIFUL))
	return out


# --- 🔒 It brings its companion ----------------------------------------------------------

func test_the_lead_brings_its_companion_naming_what_it_names() -> void:
	_his_town_trades_clothing()
	var lead := _lead()
	var letters := _paired([lead])
	assert_eq(letters.size(), 2, "the Steward's rise came without the governor's warning")
	var companion: InboundLetter = letters[1]
	assert_eq(companion.letter_id, "governor.a_rise_would_be_felt")
	assert_eq(companion.sender, _governor().id)
	assert_eq(String(companion.params.get("resource", "")), String(lead.params.get("resource", "")),
		"the governor warned about a different resource from the one the Steward named")


func test_without_its_conditions_the_lead_goes_alone() -> void:
	# Another town's clothing, and this town's iron, are not his town trading it.
	run.log.emit(Trade.EVENT_BOUGHT, &"elsewhere", run.world.month - 1, {
		"town": "elsewhere", "resource": "clothing"}, WorldPhase.COLONY_MONTH)
	run.log.emit(Trade.EVENT_BOUGHT, _town().id, run.world.month - 1, {
		"town": String(_town().id), "resource": "iron"}, WorldPhase.COLONY_MONTH)
	var letters := _paired([_lead()])
	assert_eq(letters.size(), 1, "a governor whose town never trades it warned about it")


func test_it_respects_its_own_cooldown() -> void:
	_his_town_trades_clothing()
	run.letters_sent[Director.sent_key("governor.a_rise_would_be_felt", _governor().id)] = run.world.month - 1
	assert_eq(_paired([_lead()]).size(), 1, "he warned twice inside his cooldown")


# --- 🔒 Never alone ------------------------------------------------------------------------

func test_a_companion_is_never_composed_in_the_ordinary_sweep() -> void:
	# Even one whose conditions would hold on their own: it is the lead's
	# occasion or nobody's.
	(content.collection("triggers")[COMPANION] as Dictionary)["conditions"] = []
	(content.collection("triggers")[COMPANION] as Dictionary)["params"]["resource"] = {"from": "literal", "value": "clothing"}
	for inbound in machine.director._fired_triggers(run):
		assert_ne(inbound.letter_id, "governor.a_rise_would_be_felt", "the companion fired on its own")


func test_the_post_carries_the_pair_together() -> void:
	# The lead made unskippable here, so it is on the desk whatever the Steward's
	# pressure; the pairing is what is under test.
	content.record("letters", "steward.request_tax_rise")["skippable"] = false
	# The Steward waits for the colony to have lived a month (#365).
	run.log.emit(SettlePhase.EVENT_LIVED, _town().id, 1, {}, WorldPhase.COLONY_MONTH)
	_his_town_trades_clothing()
	var ids := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		ids.append(inbound.letter_id)
	var at := ids.find("steward.request_tax_rise")
	assert_true(at >= 0, "the Steward's rise was never sent, so this proves nothing")
	assert_true(at + 1 < ids.size() and ids[at + 1] == "governor.a_rise_would_be_felt",
		"the governor's warning did not travel with the Steward's rise: %s" % [ids])


# --- 🔒 One letter of budget -----------------------------------------------------------------

func test_a_culled_lead_brings_nobody() -> void:
	_his_town_trades_clothing()
	var budget := Director.budget_for_year(run.world.year_index())
	var kept := machine.director._cull([_lead()], _unskippable(budget), run)
	var letters := _paired(kept)
	for inbound in letters:
		assert_ne(inbound.letter_id, "governor.a_rise_would_be_felt", "a culled lead brought its companion")


func test_the_pair_counts_as_one() -> void:
	_his_town_trades_clothing()
	var budget := Director.budget_for_year(run.world.year_index())
	var letters := _paired(machine.director._cull([_lead()], _unskippable(budget - 1), run))
	assert_eq(letters.size(), budget + 1,
		"the lead took the last place and its companion was not carried with it")


# --- 🔒 The validator ------------------------------------------------------------------------

func test_the_shipped_pairs_validate() -> void:
	var validator := ContentValidator.new()
	validator.check_companions(content)
	assert_true(validator.ok())


func test_a_lead_naming_a_companion_that_does_not_name_it_back_is_refused() -> void:
	(content.collection("triggers")[LEAD] as Dictionary)[Director.COMPANION_KEY] = "trigger.steward.question_tea"
	(content.collection("triggers")[COMPANION] as Dictionary)[Director.COMPANION_OF_KEY] = "trigger.steward.question_tea"
	(content.collection("triggers")["trigger.steward.question_tea"] as Dictionary)[Director.COMPANION_KEY] = COMPANION
	var validator := ContentValidator.new()
	validator.check_companions(content)
	assert_false(validator.ok(), "a lead named a companion that did not name it back")


func test_a_companion_its_lead_does_not_bring_is_refused() -> void:
	(content.collection("triggers")[LEAD] as Dictionary).erase(Director.COMPANION_KEY)
	var validator := ContentValidator.new()
	validator.check_companions(content)
	assert_false(validator.ok(), "a companion nothing will ever send passed")


func test_a_trigger_that_is_no_companion_cannot_read_a_lead() -> void:
	(content.collection("triggers")[LEAD] as Dictionary)["params"]["resource"] = {"from": "lead", "param": "resource"}
	var validator := ContentValidator.new()
	validator.check_companions(content)
	assert_false(validator.ok(), "a trigger with no lead read one")
