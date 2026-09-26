extends TestCase

## The gunsmith's machines break (#438, `institutional-contacts.md` §3).
##
## 🔒 **The roll**: below 0.4 quality of life, never twice in a year, from the
## quartermaster's own stream. 🔒 **The answer**: paid, and the machines are
## mended and the gunsmith never goes dark; refused, ignored or broken, and it is
## dark for six months — no guns in the town, the armoury's included, and no
## upkeep paid for it. Then it lights as soon as the town can pay.

const SEED: int = 438
const TRIGGER := "trigger.quartermaster.machines_broken"

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
	run.world.month = 12


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


## A town with a gunsmith, an armoury and the quartermaster they bring, living at
## `quality`.
func _quartermaster(quality: float = 0.2) -> Contact:
	var town := _town()
	town.add_building(&"foundry")
	town.add_building(GunsmithMachines.GUNSMITH)
	town.add_building(&"armoury")
	town.quality_of_life = quality
	ContactRoster.house_the_residents(run)
	return run.contacts[String(ContactRoster.resident_id(town, "quartermaster"))]


func _month() -> void:
	GunsmithMachines.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


## Roll until his machines break, a month at a time. The month it happened.
func _break(qm: Contact) -> int:
	for _month_index in 240:
		_month()
		if qm.machines_waiting:
			return run.world.month
		run.world.month += 1
	return -1


func _shuts() -> Array:
	var out: Array = []
	for intent in run.intents.live():
		if intent.kind == ShutBuildingExecutor.KIND:
			out.append(intent)
	return out


func _land() -> void:
	var executor := ShutBuildingExecutor.new()
	executor.run = run
	for intent in _shuts():
		var resolution := executor.execute(intent, run.world, run.log)
		run.intents.resolve(intent, resolution, run.log, run.world.month)


func _guns_made() -> float:
	return Conversion.new(&"guns", &"iron").made_by(_town())


func _settle_upkeep() -> void:
	var context := ColonyContext.new(run.world, run.log, run.streams, null)
	Upkeep.settle(_town(), context)


# --- 🔒 The roll -----------------------------------------------------------------

func test_the_machines_break_below_the_line() -> void:
	var qm := _quartermaster(0.2)
	assert_true(_break(qm) >= 0, "twenty years below 0.4 and the machines never broke")
	assert_eq(run.log.of_type(GunsmithMachines.EVENT_BROKE).size(), 1)
	var broke: SimEvent = run.log.of_type(GunsmithMachines.EVENT_BROKE)[0]
	assert_eq(String(broke.subject), String(qm.id))
	assert_eq(String(broke.payload["town"]), String(_town().id))


func test_never_at_or_above_the_line() -> void:
	var qm := _quartermaster(GunsmithMachines.QUALITY_BELOW)
	assert_eq(_break(qm), -1, "a town living at 0.4 had its machines break")


func test_never_twice_within_a_year() -> void:
	var qm := _quartermaster(0.2)
	var months: Array = []
	for _month_index in 240:
		_month()
		if qm.machines_waiting:
			months.append(run.world.month)
			qm.machines_waiting = false  # Answered at once, so only the year holds him back.
		run.world.month += 1
	assert_true(months.size() >= 2, "too few breaks in twenty years to prove anything")
	for index in range(1, months.size()):
		assert_true(int(months[index]) - int(months[index - 1]) >= GunsmithMachines.COOLDOWN_MONTHS,
			"the machines broke twice within a year: months %d and %d" % [months[index - 1], months[index]])


func test_a_town_without_a_gunsmith_has_no_machines_to_break() -> void:
	var qm := _quartermaster(0.2)
	_town().buildings.remove_at(_town().buildings.find(String(GunsmithMachines.GUNSMITH)))
	assert_false(GunsmithMachines.may_break(qm, _town(), run.world.month))


# --- 🔒 The answer ---------------------------------------------------------------

func test_paid_and_the_machines_are_mended() -> void:
	var qm := _quartermaster(0.2)
	var broke := _break(qm)
	run.world.month = broke + 2
	run.log.emit(PromiseBook.EVENT_KEPT, qm.id, run.world.month,
		{"kind": "gold", "terms": {"amount": GunsmithMachines.REPAIR_GOLD}}, WorldPhase.CROWNS_MONTH)
	_month()

	assert_false(qm.machines_waiting)
	assert_eq(run.log.of_type(GunsmithMachines.EVENT_MENDED).size(), 1, "paid, and nothing was mended")
	assert_empty(_shuts(), "the Crown paid and the gunsmith was shut anyway")


func test_refused_ignored_or_broken_darkens_the_gunsmith_for_six_months() -> void:
	var answers := {
		"refused": [Compliance.OUTCOME_EVENTS[Compliance.COMPLY],
			{"order": {"kind": String(M1Registrations.ORDER_REFUSE)}, "outcome": "comply"}],
		"ignored": [Silence.EVENT_IGNORED, {"letter": GunsmithMachines.LETTER}],
		"broken": [PromiseBook.EVENT_BROKEN, {"kind": "gold", "reason": "the Crown refuses"}],
	}
	var first := true
	for answer in answers:
		# A fresh run for each answer; the harness sets up the first and tears
		# down the last.
		if not first:
			after_each()
			before_each()
		first = false
		var qm := _quartermaster(0.2)
		var broke := _break(qm)
		run.world.month = broke + 1
		run.log.emit(StringName(answers[answer][0]), qm.id, run.world.month,
			answers[answer][1], WorldPhase.RECKONING)
		_month()
		assert_false(qm.machines_waiting, "%s, and he is still waiting" % answer)
		assert_eq(_shuts().size(), 1, "%s, and the gunsmith was not shut" % answer)

		run.world.month += 1
		_land()
		assert_true(_town().is_shut(GunsmithMachines.GUNSMITH, run.world.month), "%s: not dark" % answer)
		assert_true(_town().is_shut(GunsmithMachines.GUNSMITH,
			run.world.month + GunsmithMachines.DARK_MONTHS - 1), "%s: lit again early" % answer)
		assert_false(_town().is_shut(GunsmithMachines.GUNSMITH,
			run.world.month + GunsmithMachines.DARK_MONTHS), "%s: dark past six months" % answer)


func test_the_promise_reaching_him_is_not_a_refusal() -> void:
	# Agreeing is an order too, and it reaches him as one. What settles it is
	# whether the promise is then kept, not the order arriving.
	var qm := _quartermaster(0.2)
	_break(qm)
	run.log.emit(Compliance.OUTCOME_EVENTS[Compliance.COMPLY], qm.id, run.world.month,
		{"order": {"kind": String(M1Registrations.ORDER_PROMISE_GOLD)}, "outcome": "comply"},
		WorldPhase.RECKONING)
	assert_eq(String(GunsmithMachines.answer_to(qm, run.log)), "", "agreeing to pay was read as a refusal")


func test_an_answer_before_the_break_answers_nothing() -> void:
	var qm := _quartermaster(0.2)
	run.log.emit(Silence.EVENT_IGNORED, qm.id, run.world.month,
		{"letter": GunsmithMachines.LETTER}, WorldPhase.RECKONING)
	run.world.month += 1
	var broke := _break(qm)
	assert_true(broke > 0)
	assert_eq(String(GunsmithMachines.answer_to(qm, run.log)), "", "an old silence answered a new break")


# --- 🔒 Dark means no guns, and no upkeep ----------------------------------------

func test_a_dark_gunsmith_makes_no_guns_the_armourys_included() -> void:
	_quartermaster(0.2)
	var town := _town()
	town.receive_gold(10_000.0)
	_settle_upkeep()
	assert_true(_guns_made() > 0.0, "a lit gunsmith and armoury made no guns, so this proves nothing")

	town.shut(GunsmithMachines.GUNSMITH, run.world.month + GunsmithMachines.DARK_MONTHS)
	_settle_upkeep()
	assert_true(town.dark_buildings.has(String(GunsmithMachines.GUNSMITH)),
		"a town with the gold to pay paid for a shut gunsmith")
	assert_false(town.dark_buildings.has("armoury"), "the armoury went dark with it")
	assert_almost_eq(_guns_made(), 0.0, 0.0001, "the armoury made guns with the gunsmith dark")


func test_after_six_months_it_lights_when_the_town_can_pay() -> void:
	_quartermaster(0.2)
	var town := _town()
	town.receive_gold(10_000.0)
	town.shut(GunsmithMachines.GUNSMITH, run.world.month + GunsmithMachines.DARK_MONTHS)
	run.world.month += GunsmithMachines.DARK_MONTHS
	_settle_upkeep()
	assert_false(town.dark_buildings.has(String(GunsmithMachines.GUNSMITH)), "six months on and still dark")
	assert_true(_guns_made() > 0.0)


# --- 🔒 His letter ---------------------------------------------------------------

func test_the_quartermaster_writes_about_it() -> void:
	var qm := _quartermaster(0.2)
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[TRIGGER]
	assert_false(director._conditions_hold(trigger, director._context(run, qm)))
	_break(qm)
	var context := director._context(run, qm)
	assert_true(director._conditions_hold(trigger, context), "the machines broke and he said nothing")
	var letter := Letter.from_record(content.record("letters", GunsmithMachines.LETTER))
	var params := director._inbound(trigger, letter, qm, context, run).params
	assert_eq(String(params.get("town", "")), _town().display_name)
	assert_eq(int(params.get("amount", 0)), GunsmithMachines.REPAIR_GOLD)


# --- 🔒 Saved, and wired ---------------------------------------------------------

func test_what_is_broken_and_what_is_dark_survive_a_save() -> void:
	var qm := _quartermaster(0.2)
	var broke := _break(qm)
	var restored_qm := Contact.from_data(bytes_to_var(var_to_bytes(qm.to_dict())))
	assert_eq(restored_qm.machines_broke, broke)
	assert_true(restored_qm.machines_waiting)

	_town().shut(GunsmithMachines.GUNSMITH, run.world.month + GunsmithMachines.DARK_MONTHS)
	var restored := Town.from_dict(bytes_to_var(var_to_bytes(_town().to_dict())))
	assert_true(restored.is_shut(GunsmithMachines.GUNSMITH, run.world.month), "a reload lit the gunsmith")


func test_the_turn_loop_rolls_and_shuts() -> void:
	var rolls := false
	var shuts := false
	for driver in machine.month_runner.drivers:
		rolls = rolls or driver is GunsmithMachines
	for executor in machine.month_runner.executors:
		shuts = shuts or executor is ShutBuildingExecutor
	assert_true(rolls and shuts, "nothing in the month breaks the machines or shuts the gunsmith")
