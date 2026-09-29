extends TestCase

## Four patron vices do something (#444, `patrons.md` §4, §6; `policy.md` §4).
##
## 🔒 Respectable: the month after any declaration, 30 regard, a letter, and his
## policies end with it — every declaration again. 🔒 Doctrinaire: his need and
## specialty never name what he will not touch, and a month the colony sells it
## costs his regard. 🔒 Dilatory: what he gives lands three months after it is
## accepted. 🔒 Impatient: he offers his specialty once; an ordinary man may again.
## 🔒 Every vice is drawn, and every knob names a reader that exists.

const SEED: int = 444

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


func after_each() -> void:
	reset_world()
	content.free()


## A patron here, with this vice.
func _patron(vice: StringName, id: StringName = &"patron_test") -> Contact:
	var patron := Patron.generate(id, run.streams, run.world.month)
	patron.vice = vice
	PatronVices.apply_to(patron)
	patron.relationship.loyalty = 70.0
	run.contacts[String(id)] = patron
	return patron


func _post() -> PackedStringArray:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	var post := PackedStringArray()
	for inbound in machine.director.compose_inbox(run):
		post.append(inbound.letter_id)
	return post


func _declared(month: int) -> void:
	var town: Town = run.colony.in_order()[0]
	run.log.emit(Rebellion.EVENT_DECLARED, town.id, month, {"town": String(town.id)}, WorldPhase.COLONY_MONTH)


# --- 🔒 Respectable -----------------------------------------------------------------

func test_a_declaration_costs_a_respectable_man_and_ends_his_policies_with_a_letter() -> void:
	var patron := _patron(&"respectable")
	var ordinary := _patron(&"thin_skinned", &"patron_other")
	run.policies.enact(Policy.new(patron.id, PolicyEffects.IMMIGRATION, 50.0, Policy.ALL), run.log, 20)
	var before := patron.loyalty()
	var unmoved := ordinary.loyalty()
	_declared(29)

	PatronDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_almost_eq(patron.loyalty(), before - 30.0, 0.0001, "a declaration cost a respectable man nothing")
	assert_almost_eq(ordinary.loyalty(), unmoved, 0.0001, "a man with another vice withdrew")
	assert_empty(run.policies.held_by(patron.id), "his policies outlived his withdrawal")
	assert_true(_post().has("patron.no_longer_associated"), "he withdrew without a word")

	# **Every declaration does it again.**
	run.world.month = 32
	_declared(31)
	PatronDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_almost_eq(patron.loyalty(), before - 60.0, 0.0001, "a second declaration was forgiven")


func test_nothing_happens_before_the_month_after() -> void:
	var patron := _patron(&"respectable")
	var before := patron.loyalty()
	_declared(30)
	PatronDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_almost_eq(patron.loyalty(), before, 0.0001, "he withdrew the month it happened")


# --- 🔒 Doctrinaire -----------------------------------------------------------------

func test_his_need_and_specialty_never_name_what_he_will_not_touch() -> void:
	var seen := 0
	for index in 200:
		var patron := Patron.generate(StringName("patron_%d" % index), run.streams)
		if String(patron.disapproves).is_empty():
			continue
		seen += 1
		assert_true(["rum", "beer", "tobacco", "cigars"].has(patron.disapproves))
		assert_ne(patron.need_kind, patron.disapproves, "%s needs what he will not touch" % patron.id)
		assert_ne(patron.specialty_kind, patron.disapproves, "%s offers what he will not touch" % patron.id)
	assert_true(seen > 0, "no doctrinaire man was drawn in two hundred")
	# **And the specialty draw itself** never offers it, whatever the dice: a
	# kind he shuns is not open to him in any category.
	for shunned in ["rum", "beer", "tobacco", "cigars"]:
		for category in Patron.catalogue_ids():
			assert_false(Patron._open_kinds(category, {}, shunned).has(shunned),
				"%s is open to a man who will not touch it" % shunned)


func test_a_month_the_colony_sells_it_costs_his_regard() -> void:
	var patron := _patron(&"doctrinaire")
	patron.disapproves = "rum"
	var before := patron.loyalty()
	PatronDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_almost_eq(patron.loyalty(), before, 0.0001, "a month without a sale cost him")

	var town: Town = run.colony.in_order()[0]
	run.log.emit(Trade.EVENT_SOLD, town.id, run.world.month, {"resource": "rum", "quantity": 10.0},
		WorldPhase.COLONY_MONTH)
	PatronDriver.new(run).on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_almost_eq(patron.loyalty(), before - 2.0, 0.0001, "the colony sold rum and he minded nothing")
	assert_true(_post().has("patron.he_will_not_touch_it"), "he minded in silence")


# --- 🔒 Dilatory ----------------------------------------------------------------------

func _accepted(patron: Contact, kind: StringName, params: Dictionary) -> Dictionary:
	var order := Order.new(kind, patron.id, params, run.world.month)
	return Compliance.resolve(order, patron, run.intents, run.world, run.log, run.streams)


func test_what_a_dilatory_man_gives_lands_three_months_late() -> void:
	var patron := _patron(&"dilatory")
	var result := _accepted(patron, &"give_the_crown_gold", {"to": String(patron.id), "amount": 300.0})
	var intent: Intent = result["intent"]
	assert_eq(intent.months_required, 3, "a dilatory man's gift was on time")

	var ordinary := _patron(&"thin_skinned", &"patron_other")
	var prompt := _accepted(ordinary, &"give_the_crown_gold", {"to": String(ordinary.id), "amount": 300.0})
	assert_eq((prompt["intent"] as Intent).months_required, 1, "an ordinary man's gift was late")

	var executor := GoldGiftExecutor.new()
	for month in 2:
		assert_eq(executor.execute(intent, run.world, run.log), Intent.IN_PROGRESS,
			"a dilatory man's gift landed in month %d" % (month + 1))
	assert_eq(executor.execute(intent, run.world, run.log), Intent.COMPLETED)


func test_a_dilatory_mans_policy_is_not_enacted_the_month_it_is_agreed() -> void:
	var patron := _patron(&"dilatory")
	var order := Order.new(&"enact_policy", patron.id,
		{"to": String(patron.id), "effect": String(PolicyEffects.IMMIGRATION), "cost": 50.0, "split": "all"},
		run.world.month)
	var driver := OrderDriver.new(run.intents, run.promises)
	driver.policies = run.policies
	driver.contacts = run.contacts
	driver.carry(order)
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_empty(run.policies.held_by(patron.id), "a dilatory man's policy took effect at once")


# --- 🔒 Impatient ----------------------------------------------------------------------

func test_an_impatient_man_offers_his_specialty_once_and_an_ordinary_man_again() -> void:
	var impatient := _patron(&"impatient")
	var ordinary := _patron(&"thin_skinned", &"patron_other")
	assert_true(PatronVices.may_offer_his_specialty(impatient, run.log))
	for man in [impatient, ordinary]:
		run.log.emit(Director.EVENT_DISPATCHED, (man as Contact).id, 20,
			{"letter": "patron.an_expert_for_you"}, WorldPhase.DISPATCH)
	assert_false(PatronVices.may_offer_his_specialty(impatient, run.log),
		"an impatient man offered his specialty twice")
	assert_true(PatronVices.may_offer_his_specialty(ordinary, run.log),
		"an ordinary man may not offer again")
	for trigger in Patron.SPECIALTY_OFFERS:
		var gates: Array = []
		for entry in content.collection("triggers")["trigger.%s" % trigger].get("conditions", []):
			gates.append_array((entry as Dictionary).keys())
		assert_true(gates.has("he_may_offer_his_specialty"), "%s is offered however often" % trigger)


# --- 🔒 All ten drawn, every knob read ------------------------------------------------

func test_every_vice_is_drawn_and_every_knob_names_a_reader_that_exists() -> void:
	assert_eq(PatronVices.ids().size(), 10)
	var classes: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		classes[String(entry["class"])] = String(entry["path"])
	for knob in PatronVices.READ_BY:
		var named := String(PatronVices.READ_BY[knob]).split(".")
		assert_eq(named.size(), 2, "'%s' names no Class.method" % knob)
		if named.size() != 2 or not classes.has(named[0]):
			assert_true(false, "'%s' names a class that does not exist" % knob)
			continue
		var methods: Array = []
		for method in (load(classes[named[0]]) as Script).get_script_method_list():
			methods.append(String(method["name"]))
		assert_true(methods.has(named[1]), "'%s' names %s, which does not exist" % [knob, READ_BY_ENTRY(knob)])


func READ_BY_ENTRY(knob: String) -> String:
	return String(PatronVices.READ_BY[knob])
