extends TestCase

## The Steward raises a duty over the PC's head (#452, `the-steward.md` §3,
## SPEC §10.2).
##
## 🔒 **Standing lost and his regard low**, as a filter, or he does not. 🔒 **The
## rate he has been advising**, one step, as his own will (Seam C), and a letter
## after the fact. Not again while one is on its way, nor within the year.

const SEED: int = 452

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
	run.world.month = 30


func after_each() -> void:
	reset_world()
	content.free()


func _steward() -> Contact:
	return run.contact(StewardRaise.STEWARD)


## He pushed for `resource`, and the push went out.
func _advised(resource: String) -> void:
	run.log.emit(Director.EVENT_DISPATCHED, StewardRaise.STEWARD, run.world.month - 3, {
		"letter": StewardRaise.PUSH_LETTER, "tone": "dutiful", "params": {"resource": resource},
	}, WorldPhase.DISPATCH)


## Standing lost, and his regard low.
func _sour() -> void:
	run.standing.band = CrownStanding.BAND_LOST
	_steward().relationship.loyalty = Relationship.MEDIUM_AT - 10.0


func _month() -> void:
	StewardRaise.new(run).on_phase(WorldPhase.INTENT, run.world, run.log, run.streams)


func _his_raises() -> Array:
	var out: Array = []
	for intent in run.intents.live():
		if intent.kind == M1Registrations.ORDER_SET_TAX_RATE and intent.source == StewardRaise.STEWARD \
				and intent.origin == Intent.ORIGIN_WILL:
			out.append(intent)
	return out


func test_with_standing_lost_and_his_regard_low_he_raises_what_he_advised() -> void:
	_advised("rum")
	_sour()
	_month()
	var raises := _his_raises()
	assert_eq(raises.size(), 1, "standing lost, his regard low, and he raised nothing")
	if raises.size() != 1:
		return
	assert_eq(String(raises[0].data.get("key", "")), TaxRates.key_for(&"rum"),
		"he raised a rate other than the one he had been advising")
	assert_almost_eq(float(raises[0].data.get("rate", 0.0)), TaxRates.moved(run.world, &"rum", 1.0), 0.0001,
		"he raised it by other than a step")
	assert_eq(run.log.of_type(StewardRaise.EVENT_RAISED).size(), 1)


func test_not_while_the_crown_still_stands_behind_the_pc() -> void:
	_advised("rum")
	_sour()
	run.standing.band = CrownStanding.BAND_ALARM
	_month()
	assert_empty(_his_raises(), "he raised a duty with standing not yet lost")


func test_not_while_he_still_thinks_well_of_the_pc() -> void:
	_advised("rum")
	_sour()
	_steward().relationship.loyalty = Relationship.MEDIUM_AT + 5.0
	_month()
	assert_empty(_his_raises(), "a Steward who still thought well of the PC went over his head")


func test_a_steward_who_never_pushed_has_nothing_to_raise() -> void:
	_sour()
	_month()
	assert_empty(_his_raises())


func test_not_again_within_the_year() -> void:
	_advised("rum")
	_sour()
	_month()
	run.intents = IntentBook.new()   # the first has landed
	run.world.month += StewardRaise.COOLDOWN_MONTHS - 1
	_month()
	assert_empty(_his_raises(), "he raised again within the year")
	run.world.month += 1
	_month()
	assert_eq(_his_raises().size(), 1, "a year on, and he did not raise again")


func test_he_writes_to_say_so_after() -> void:
	_advised("rum")
	_sour()
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")["trigger.steward.i_raised_the_duty"]
	assert_false(director._conditions_hold(trigger, director._context(run, _steward())))
	_month()
	var context := director._context(run, _steward())
	assert_true(director._conditions_hold(trigger, context), "he raised a duty and did not say so")
	var letter := Letter.from_record(content.record("letters", "steward.i_raised_the_duty"))
	assert_eq(String(director._inbound(trigger, letter, _steward(), context, run).params.get("resource", "")), "rum")


func test_the_turn_loop_asks_him() -> void:
	var asks := false
	for driver in machine.month_runner.drivers:
		asks = asks or driver is StewardRaise
	assert_true(asks, "nothing in the month lets the Steward act alone")
