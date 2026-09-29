extends TestCase

## A duke asks tribute once he has arrived, and only in the bands that ask
## (#458, `rival-pressure.md` §3, §6).
##
## 🔒 All three dukes are on the roster from the first month, and the first
## arrival used to qualify every one of their tribute letters. 🔒 A duke at Low
## attacks improvements and one at Minimum makes war; neither asks, and a Low duke
## used to ask 1 gold.

const SEED: int = 458
const DUKES: Array = ["rival_duke", "rival_duke_montargis", "rival_duke_vasterholm"]

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
	for id in DUKES:
		run.contact(StringName(id)).relationship.loyalty = 80.0


func after_each() -> void:
	reset_world()
	content.free()


func _asks(duke: String) -> bool:
	var trigger: Dictionary = content.collection("triggers")["trigger.%s.tribute_demand" % duke]
	var director := machine.director
	return director._conditions_hold(trigger, director._context(run, run.contact(StringName(duke))))


func _arrive(count: int) -> Array:
	for _index in count:
		run.demands.sources.append(String(DemandGrowth.SOURCE_DUKE))
	return RivalDuke.arrived_in(run, run.demands)


func test_no_duke_asks_before_any_has_arrived() -> void:
	for duke in DUKES:
		assert_false(_asks(duke), "%s asked for tribute before any duke had come" % duke)


func test_only_the_duke_who_has_arrived_asks() -> void:
	var arrived: Contact = _arrive(1)[0]
	for duke in DUKES:
		assert_eq(_asks(duke), duke == String(arrived.id),
			"%s: one duke arrived and it was not only he who asked" % duke)


func test_he_asks_at_high_and_medium_and_never_at_low_or_minimum() -> void:
	var duke: Contact = _arrive(1)[0]
	var bands := {
		RivalDuke.HIGH_AT + 5.0: true,
		RivalDuke.MEDIUM_AT + 5.0: true,
		RivalDuke.LOW_AT + 5.0: false,
		RivalDuke.LOW_AT - 5.0: false,
	}
	for loyalty in bands:
		duke.relationship.loyalty = float(loyalty)
		var band := RivalDuke.band_of(float(loyalty))
		assert_eq(_asks(String(duke.id)), bool(bands[loyalty]), "a duke at %s: wrong whether he asks" % band)


func test_a_duke_latched_at_minimum_never_asks_again() -> void:
	var duke: Contact = _arrive(1)[0]
	assert_true(_asks(String(duke.id)))
	run.log.emit(RivalBook.EVENT_LATCHED, duke.id, run.world.month,
		{"rival": String(duke.id), "name": duke.display_name}, WorldPhase.RECKONING)
	assert_false(_asks(String(duke.id)), "a duke past the point of no return asked to be paid")
