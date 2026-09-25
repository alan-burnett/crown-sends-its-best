extends TestCase

## A patron offers to trouble a duke, and the reply arranges it (#395,
## `patrons.md` §5).
##
## 🔒 **He interferes with a rival; he never touches the PC's relationship with
## him.** The offer is his letter; accepting is an Order to him; the trouble lands
## through an Intent (`SabotageDriver.arrange`) the month after. It costs nothing
## with the duke.

const SEED: int = 395
const OFFER := "trigger.patron.a_word_against_the_duke"

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


func _patron(specialty: String = "rivals") -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, 60.0)
	patron.specialty = specialty
	run.add_contact(patron)
	return patron


## Dukes arrive with the Squeeze; `count` of them are here.
func _dukes(count: int) -> Array:
	for _index in count:
		run.demands.sources.append(String(DemandGrowth.SOURCE_DUKE))
	return RivalDuke.arrived_in(run, run.demands)


func _true_for(patron: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[OFFER], director._context(run, patron))


func _written(patron: Contact) -> InboundLetter:
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[OFFER]
	var letter := Letter.from_record(content.record("letters", "patron.a_word_against_the_duke"))
	return director._inbound(trigger, letter, patron, director._context(run, patron), run)


# --- 🔒 Who offers, and against whom ----------------------------------------------------

func test_only_a_patron_of_the_rivals_offers_and_only_once_a_duke_is_here() -> void:
	var patron := _patron()
	assert_false(_true_for(patron), "he offered to trouble a duke before any had arrived")
	_dukes(1)
	assert_true(_true_for(patron), "a patron of the rivals had nothing to offer against a duke")
	assert_false(_true_for(_patron("gold")), "a patron dealing in gold offered to trouble a duke")


func test_he_names_the_duke_nearest_to_war_who_can_still_be_troubled() -> void:
	var dukes := _dukes(2)
	var hotter: Contact = dukes[1]
	(dukes[0] as Contact).relationship.loyalty = 55.0
	hotter.relationship.loyalty = 20.0
	var patron := _patron()
	var letter := _written(patron)
	assert_eq(String(letter.params.get("duke", "")), String(hotter.id))
	assert_eq(String(letter.params.get("duke_name", "")), hotter.display_name)
	# 🔒 A duke at minimum cannot be troubled (§5), so he is never offered.
	hotter.relationship.loyalty = 1.0
	assert_eq(String(_written(patron).params.get("duke", "")), String((dukes[0] as Contact).id))


func test_a_duke_already_troubled_is_not_offered_again() -> void:
	var dukes := _dukes(1)
	var patron := _patron()
	SabotageDriver.arrange(dukes[0], run.world, run.log, run.world.month)
	assert_false(_true_for(patron), "he offered to trouble a duke whose year was already ruined")


# --- 🔒 The reply arranges it, through an Intent ----------------------------------------

func test_accepting_arranges_it_the_month_after_and_costs_nothing_with_the_duke() -> void:
	var duke: Contact = _dukes(1)[0]
	var regard := duke.loyalty()
	var patron := _patron()
	var context := machine.director._context(run, patron)
	context.params = _written(patron).params
	var option: Dictionary = content.record("letters", "patron.a_word_against_the_duke")["reply"]["steps"][0]["options"][0]
	assert_eq(String(option["id"]), "accept")
	var order := ContentRegistry.run_effect("trouble_a_duke", option["effect"]["trouble_a_duke"], context)
	assert_eq(order.kind, M1Registrations.ORDER_TROUBLE_A_DUKE)
	assert_false(SabotageDriver.is_sabotaged(run.world, duke.id, run.world.month),
		"the reply itself troubled the duke, which an Order must never do")

	var intent := Compliance._intent_for(order, Compliance.COMPLY, patron)
	run.world.month += 1
	var executor := SabotageExecutor.new()
	executor.contacts = run.contacts
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.COMPLETED))
	assert_true(SabotageDriver.is_sabotaged(run.world, duke.id, run.world.month),
		"he accepted and the duke's year went on as before")
	assert_almost_eq(duke.loyalty(), regard, 0.0001, "the duke's regard moved: he put it together")


func test_a_duke_who_reached_minimum_meanwhile_cannot_be_troubled() -> void:
	var duke: Contact = _dukes(1)[0]
	var intent := Intent.new(&"", SabotageExecutor.KIND, &"patron_1", &"patron_1", 1, {"duke": String(duke.id)})
	duke.relationship.loyalty = 1.0
	var executor := SabotageExecutor.new()
	executor.contacts = run.contacts
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.STALLED))
	assert_false(SabotageDriver.is_sabotaged(run.world, duke.id, run.world.month))


func test_accepting_his_offer_is_a_favour_he_banks() -> void:
	var order := Order.new(M1Registrations.ORDER_TROUBLE_A_DUKE, &"patron_1", {"to": "patron_1", "duke": "x"}, 0)
	assert_eq(String(Compliance._deed_of(order)), String(Relationship.GRANTED))


func test_the_turn_loop_lands_it() -> void:
	var found := false
	for executor in machine.month_runner.executors:
		found = found or executor is SabotageExecutor
	assert_true(found, "nothing in the month lands a patron's trouble")


func test_a_patron_who_thinks_too_little_of_the_pc_offers_nothing() -> void:
	# 🔒 #443, `patrons.md` §4: he offers his specialty once his regard is high
	# enough, whatever it is.
	_dukes(1)
	var patron := _patron()
	patron.relationship.loyalty = Patron.OFFERS_AT - 1.0
	assert_false(_true_for(patron), "a patron who thinks little of the PC offered to trouble a duke")
