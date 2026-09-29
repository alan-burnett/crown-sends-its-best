extends TestCase

## A tribe asks a governor for help with troubles abroad (#471, `natives.md` §7,
## §3, §11; SPEC §12.5).
##
## 🔒 A tribe at civil standing or better asks a governor for help, at most once a
## year. 🔒 A loyal governor asks the PC how to answer, in a letter of its own.
## 🔒 He gives or refuses, and nothing else. 🔒 Giving moves the goods and raises
## the tribe's standing; refusing changes nothing.

const SEED: int = 471

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.world.month = 30
	TribeAsks.set_chance(1.0)


func after_each() -> void:
	reset_world()
	content.free()


## One people of twenty thousand, met, beside the capital, at this standing.
func _tribe(trust: float = 60.0) -> Tribe:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): trust}
	tribe.met_month = 1
	natives.all.append(tribe)
	var village := Village.new()
	village.id = &"village_test"
	village.tribe = tribe.id
	village.at = (run.colony.in_order()[0] as Town).at + Vector2i(8, 0)
	village.people = 20_000
	natives.villages.append(village)
	run.tribes = natives
	return tribe


func _reckon() -> void:
	TribeGrievanceDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


func _asks() -> Array:
	return run.log.of_type(TribeAsks.EVENT_ASKED)


func _the_ask() -> TribeGrievance:
	for entry in run.tribes.grievances.list:
		if (entry as TribeGrievance).act == TribeGrievance.HELP_ABROAD:
			return entry
	return null


# --- 🔒 Civil or better, once a year -----------------------------------------------------

func test_a_civil_tribe_asks_at_most_once_a_year() -> void:
	_tribe(60.0)
	_reckon()
	assert_eq(_asks().size(), 1, "a civil tribe with troubles abroad never asked")
	var ask := _the_ask()
	assert_true(ask != null and TribeAsks.WHAT.has(String(ask.asked.get("resource", ""))),
		"it asked for something other than guns, tools or horses")
	assert_eq(ask.town, (run.colony.in_order()[0] as Town).id, "it asked a town that is not its neighbour")

	run.world.month += 1
	_reckon()
	assert_eq(_asks().size(), 1, "it asked twice in a year")
	run.world.month += TribeAsks.ONCE_IN
	_reckon()
	assert_eq(_asks().size(), 2, "a year on, it could not ask again")


func test_a_tribe_below_civil_never_asks() -> void:
	_tribe(Tribe.NEUTRAL - 5.0)
	_reckon()
	assert_empty(_asks(), "a tribe that thinks ill of the colony asked it for help")


# --- 🔒 A loyal governor asks the PC, in its own letter ----------------------------------

func test_a_loyal_governor_asks_the_pc_how_to_answer_their_ask() -> void:
	_tribe(60.0)
	var town: Town = run.colony.in_order()[0]
	run.contact(town.governor_id).relationship.loyalty = 80.0
	_reckon()
	run.world.month += 1
	TribeGrievanceDriver.new(run).on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)
	var asked := run.log.of_type(TribeGrievanceDriver.EVENT_ASKED)
	assert_eq(asked.size(), 1, "a loyal governor answered a tribe's ask without asking the PC")

	var machine := TurnMachine.new(run)
	machine.use_content(content)
	var post := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		post.append(inbound.letter_id)
	assert_true(post.has("governor.a_tribe_asks_for_help"), "he asked and no letter came")
	assert_false(post.has("governor.a_tribe_has_written"),
		"a request for help was passed on as a complaint about the town")


# --- 🔒 Given or refused, and nothing else ------------------------------------------------

func test_he_gives_or_refuses_and_nothing_else() -> void:
	var ask := TribeGrievance.new()
	ask.act = TribeGrievance.HELP_ABROAD
	var context := DeliberationContext.new(DecisionKind.TRIBE_GRIEVANCE, run.world, run.log)
	context.data = {"grievance": ask}
	var filter := GrievanceConsiderations.AnAskIsGivenOrRefused.new()
	for answer in TribeGrievance.ANSWERS:
		var allowed: bool = answer == TribeGrievance.GIFT or answer == TribeGrievance.REFUSE
		assert_eq(filter.permits(null, Candidate.new(answer), context), allowed,
			"an ask for help could be answered '%s'" % answer)


# --- 🔒 What giving does, and refusing does not --------------------------------------------

func _answered(answer: StringName) -> Dictionary:
	var tribe := _tribe(60.0)
	var town: Town = run.colony.in_order()[0]
	town.store(&"guns", 100.0)
	_reckon()
	var ask := _the_ask()
	ask.asked = {"resource": "guns", "amount": 20.0}
	ask.answer = answer
	var intent := Intent.new(&"", TribeGrievanceDriver.ANSWER_KIND, town.governor_id, ask.id, 1, {
		"grievance": String(ask.id),
		"answer": String(answer),
		"gift": GrievanceConsiderations.gift_for(ask, town, run.tribes.villages[0], run.map),
	})
	var executor := TribeAnswerExecutor.new()
	executor.run = run
	run.world.month += 1
	executor.execute(intent, run.world, run.log)
	var before := tribe.trust()
	_reckon()
	return {"town": town, "tribe": tribe, "before": before}


func test_giving_moves_the_goods_and_raises_their_standing() -> void:
	var given := _answered(TribeGrievance.GIFT)
	assert_almost_eq((given["town"] as Town).held(&"guns"), 80.0, 0.001, "the guns never left the town")
	assert_almost_eq(float(run.tribes.villages[0].stores.get("guns", 0.0)), 20.0, 0.001,
		"the guns never reached them")
	assert_true((given["tribe"] as Tribe).trust() > float(given["before"]),
		"meeting their ask did not raise their standing")


func test_refusing_changes_nothing() -> void:
	var refused := _answered(TribeGrievance.REFUSE)
	assert_almost_eq((refused["town"] as Town).held(&"guns"), 100.0, 0.001)
	assert_almost_eq((refused["tribe"] as Tribe).trust(), float(refused["before"]), 0.0001,
		"refusing a request cost standing as refusing a grievance does")
