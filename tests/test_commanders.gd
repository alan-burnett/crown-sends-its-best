extends TestCase

## Commanders are contacts, and the standing order decides if one is needed
## (#220, `docs/mechanics/commanders.md` §1, §2, §3; `battles.md` §4).
##
## 🔒 **A commander is an ordinary contact with a company attached.** There is no
## commander machinery and there must not be, for the same reason
## `institutional-contacts.md` §1 refuses it for the clergy: every question he
## raises is answered somewhere `contacts.md` already has.
##
## 🔒 **Colonial, Crown and rebel commanders are the same object**, which is how
## a rebel general comes to be corresponding with the Crown about terms.
##
## 🔒 **The order decides whether one is needed, and it is not a size check.** A
## hundred men behind a stockade need nobody; twelve men marching on a village
## need someone to decide whether to press on when they find it defended.
##
## 🔒 **Orders are not objectives.** A town reconsiders its objective every
## Settle; a militia has a standing order given once and no reconsideration
## machinery touches it. A dev who wires it there has misread both docs.

const SEED: int = 6619

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


const MARCH: StringName = &"march_on_the_village"


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	return context


## Raise a company under an order, led as the raising settles it: by default a
## commander for a company sent somewhere and nobody for one that stays (#434
## makes that the raising's business, not the order's).
func _raise(
	run: RunState,
	order: StringName = StandingOrder.DEFEND_THE_TOWN,
	allegiance: StringName = Company.COLONIAL,
	size: int = 20,
	led_by: StringName = &"",
) -> Company:
	var town := run.colony.in_order()[0]
	var context := _context(run)
	if String(led_by).is_empty():
		led_by = Company.COMMANDED if StandingOrder.leaves_the_town(order) else Company.MILITIA
	var company := run.companies.raise_company(
		allegiance, size, {}, town.id, town.at, context, order, led_by)
	Commanders.take_command(company, town, run, context)
	return company


func _reckon(run: RunState) -> void:
	var driver := CompanyDriver.new()
	driver.companies = run.companies
	driver.colony = run.colony
	driver.map = run.map
	driver.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


# --- 🔒 The raising decides who leads it, not the order (#432, #434) ----------

func test_a_militia_is_given_nobody_whatever_its_order() -> void:
	# The rule that anything which leaves the town needs a man is retired (#434):
	# a militia sent to explore still has nobody deciding for it.
	var run := _run()
	var scouts := _raise(run, StandingOrder.EXPLORE, Company.COLONIAL, 12, Company.MILITIA)
	assert_true(scouts.is_headless(), "a militia sent to explore was given a general")
	assert_empty(Commanders.all_in(run), "a commander was made for nobody to lead")


func test_a_commanded_company_is_given_a_man_whatever_its_order() -> void:
	var run := _run()
	var garrison := _raise(run, StandingOrder.DEFEND_THE_TOWN, Company.COLONIAL, 100, Company.COMMANDED)
	assert_false(garrison.is_headless(),
		"a company raised to be commanded stayed behind its stockade with nobody")
	assert_eq(Commanders.all_in(run).size(), 1)


func test_nobody_settled_it_and_nobody_leads_it() -> void:
	# A company raised with no leadership said is a militia, whatever its order.
	var run := _run()
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		Company.COLONIAL, 12, {}, town.id, town.at, _context(run), StandingOrder.MARCH_ON_A_FOE)
	assert_false(company.wants_a_commander())
	assert_eq(Commanders.take_command(company, town, run, _context(run)), null)


func test_no_order_at_all_is_the_posture() -> void:
	# `battles.md` §4: a standing posture from whoever raised it and nothing else.
	assert_eq(StandingOrder.of(&""), StandingOrder.DEFEND_THE_TOWN)

	var run := _run()
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		Company.COLONIAL, 20, {}, town.id, town.at, _context(run), &"")
	assert_eq(company.order, StandingOrder.DEFEND_THE_TOWN,
		"a company was raised with no orders at all")


# --- 🔒 The three outcomes at raising ---------------------------------------

func test_a_new_commander_is_generated_when_no_veteran_is_waiting() -> void:
	var run := _run()
	var company := _raise(run, MARCH)
	var man := run.contact(company.commander)
	assert_true(man != null, "the company names a commander who does not exist")
	assert_eq(man.role, Contact.ROLE_COMMANDER)
	assert_false(man.display_name.is_empty(), "he has no name")
	assert_eq(man.town, run.colony.in_order()[0].display_name,
		"he was not dispatched from the town that raised him")


func test_a_veteran_waiting_in_the_town_takes_the_next_command() -> void:
	# 🔒 §7's first outcome, and the reason no resupply mechanic is needed: a
	# company only ever dwindles, so **the commander is the thing that persists.**
	var run := _run()
	var first := _raise(run, MARCH)
	var veteran := run.contact(first.commander)

	first.lose(1.0, &"wiped_out", _context(run))
	run.companies.bury_the_dead()
	assert_eq(Commanders.waiting_in(run.colony.in_order()[0], run).size(), 1,
		"the survivor is not waiting in his town")

	var second := _raise(run, MARCH)
	assert_eq(second.commander, veteran.id,
		"the town raised a second company and made a second general for it")
	assert_eq(Commanders.all_in(run).size(), 1, "a new man was generated anyway")


func test_a_commander_in_the_field_is_not_waiting_for_another() -> void:
	var run := _run()
	var first := _raise(run, MARCH)
	var second := _raise(run, MARCH)
	assert_ne(second.commander, first.commander,
		"one man was given two companies at once")
	assert_eq(Commanders.all_in(run).size(), 2)


func test_a_headless_militia_takes_nobody_even_with_a_veteran_idle() -> void:
	# 🔒 The order decides, and a veteran sitting in the town does not change it.
	var run := _run()
	var marching := _raise(run, MARCH)
	marching.lose(1.0, &"wiped_out", _context(run))
	run.companies.bury_the_dead()

	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN)
	assert_true(militia.is_headless(),
		"a defensive militia was given the idle veteran")


func test_the_raising_says_which_outcome_it_was() -> void:
	var run := _run()
	_raise(run, MARCH)
	var commanded := run.log.of_type(Company.EVENT_COMMANDED)
	assert_eq(commanded.size(), 1, "a man took a command and nothing said so")
	assert_false(bool(commanded[0].payload.get("veteran", true)),
		"a man made this month was reported as a veteran")


# --- 🔒 He is an ordinary contact -------------------------------------------

func test_he_is_on_the_roster_and_can_be_written_to() -> void:
	var run := _run()
	var company := _raise(run, MARCH)
	assert_true(run.contacts.has(String(company.commander)),
		"the commander is not in the correspondence at all")
	var man := run.contact(company.commander)
	assert_true(man.relationship != null, "he has no relationship with the PC")
	assert_true(man.weights.size() > 0, "he has no personality")
	assert_false(Letterhead.of(man).is_empty(), "his letters have no letterhead")


func test_he_carries_no_fields_a_governor_does_not() -> void:
	# The same property `test_residents` asks of the clergy, and for the same
	# reason: a change made for one kind of contact must not silently move
	# another.
	var run := _run()
	var company := _raise(run, MARCH)
	var commander := run.contact(company.commander)
	var governor := run.contact(run.colony.in_order()[0].governor_id)

	var his: Dictionary = {}
	for entry in commander.get_property_list():
		his[String(entry["name"])] = true
	for entry in governor.get_property_list():
		his.erase(String(entry["name"]))
	assert_true(his.is_empty(),
		"a commander carries fields a governor does not: %s" % ", ".join(his.keys()))


func test_a_rebel_commander_is_the_same_object() -> void:
	# 🔒 §1. A rebel general corresponding with the Crown about terms is the
	# mechanism working, not a special case — the channel SPEC §12.3 implies and
	# never names.
	var run := _run()
	var rebel := _raise(run, MARCH, Company.REBEL)
	var man := run.contact(rebel.commander)
	assert_eq(man.role, Contact.ROLE_COMMANDER,
		"a rebel general is a different kind of contact")
	assert_true(run.contacts.has(String(man.id)),
		"the PC cannot write to the man he will have to negotiate with")
	assert_eq(man.qualifier, Letterhead.REBEL_COMMANDER,
		"his letterhead does not say whose soldier he is")


func test_a_crown_commander_says_whose_service_he_is_in() -> void:
	var run := _run()
	var crown := _raise(run, MARCH, Company.CROWN)
	assert_eq(run.contact(crown.commander).qualifier, Letterhead.CROWN_COMMANDER)


func test_his_personality_comes_from_his_own_stream() -> void:
	# 🔒 `hash(run_seed, contact_id)`, so the same seed yields the same officer
	# however late in the run his town got round to raising him a company.
	var first := _run()
	var one := first.contact(_raise(first, MARCH).commander)
	var second := _run()
	var other := second.contact(_raise(second, MARCH).commander)

	assert_eq(other.display_name, one.display_name)
	assert_eq(other.weights, one.weights)
	assert_eq(other.traits, one.traits)


# --- 🔒 Orders are not objectives -------------------------------------------

func test_a_company_carries_an_order_and_never_an_objective() -> void:
	# SPEC §4's terminology, made mechanical. A field called `objective` here
	# would invite the reconsideration machinery that belongs to towns.
	var company := Company.new(&"probe", 1)
	for entry in company.get_property_list():
		assert_false(String(entry["name"]).contains("objective"),
			"a company carries '%s', and §3 says a militia has no objective"
				% entry["name"])


func test_the_order_is_given_once_and_nothing_reconsiders_it() -> void:
	# 🔒 §3: *defend the town* is never complete and never stalls, and no
	# reconsideration machinery applies to a headless company.
	var run := _run()
	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN)
	for month in 4:
		run.world.month = month
		_reckon(run)
		if militia.is_empty():
			break
		assert_eq(militia.order, StandingOrder.DEFEND_THE_TOWN,
			"something reconsidered a headless militia's order in month %d" % month)


func test_no_reconsideration_machinery_names_a_company() -> void:
	# The lock asked of the codebase, because the failure §3 warns about is a dev
	# wiring a town's machinery to a militia — which would not show up as a wrong
	# number, only as a militia that one day decided to do something else.
	var readers := PackedStringArray()
	for path in ["res://sim/colony/govern/objective_selector.gd",
			"res://sim/colony/phases/settle.gd", "res://sim/colony/objective.gd"]:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("Company") or text.contains("StandingOrder"):
			readers.append(path.get_file())
	assert_empty(readers,
		"a town's objective machinery names a company: %s" % ", ".join(readers))


# --- 🔒 Headless companies disband on a timer, returning survivors ---------

func test_a_militia_stands_its_time_and_goes_home() -> void:
	var run := _run()
	var town := run.colony.in_order()[0]
	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN, Company.COLONIAL, 15)
	var before := town.workers

	run.world.month = Company.militia_months()
	# **Fed on its last month**, so the arithmetic below is the whole company
	# rather than the whole company less whoever the hunger took. A militia that
	# went without on the way home still went without, and that is asked for
	# separately.
	militia.was_supplied(run.world.month)
	_reckon(run)

	assert_true(militia.is_empty(), "it stood its time and stayed under arms")
	assert_eq(town.workers, before + 15,
		"the survivors did not come home: %d against %d" % [town.workers, before])
	assert_eq(run.log.of_type(Company.EVENT_DISBANDED).size(), 1,
		"a company went home and nothing said so")
	assert_empty(run.log.of_type(Company.EVENT_DESTROYED),
		"going home was reported as being destroyed")


func test_it_does_not_go_home_early() -> void:
	var run := _run()
	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN)
	run.world.month = Company.militia_months() - 1
	_reckon(run)
	assert_false(militia.is_empty(), "it went home a month early")


func test_a_commanded_company_is_on_no_clock() -> void:
	# 🔒 §4's whole difference: a commander deliberates afresh every month, so
	# there is nothing for a timer to end.
	var run := _run()
	var marching := _raise(run, MARCH)
	run.world.month = Company.militia_months() * 3
	_reckon(run)
	assert_false(marching.is_empty(),
		"a company with a commander disbanded itself")


func test_going_home_and_being_destroyed_are_different_events() -> void:
	# 🔒 `commanders.md` §7 leans on the difference: a commander whose company
	# stood down needs no coin flip, and the ticket that brings the flip has to be
	# able to tell the two apart.
	var run := _run()
	var wiped := _raise(run, MARCH)
	wiped.lose(1.0, &"wiped_out", _context(run))
	assert_eq(run.log.of_type(Company.EVENT_DESTROYED).size(), 1)
	assert_empty(run.log.of_type(Company.EVENT_DISBANDED),
		"a company destroyed to the last man was reported as having gone home")


func test_a_militia_whose_town_is_gone_has_nowhere_to_send_its_men() -> void:
	var run := _run()
	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN)
	run.colony.towns.clear()
	run.world.month = Company.militia_months()
	_reckon(run)
	assert_true(militia.is_empty(), "it went on standing for a town that had gone")


func test_defence_has_a_running_cost() -> void:
	# §4: a militia eats for every month it stands, so a town under sustained
	# threat must keep re-raising and keep re-feeding. The raising is the cost,
	# and the timer is what makes it recur.
	var run := _run()
	var militia := _raise(run, StandingOrder.DEFEND_THE_TOWN, Company.COLONIAL, 10)
	assert_eq(run.companies.supported_by(run.colony.in_order()[0].id).size(), 1,
		"a militia standing in its town is not on that town's books")
	assert_true(militia.victuals().size() > 0, "it stands there eating nothing")


# --- Saving -----------------------------------------------------------------

func test_the_order_and_the_commander_survive_the_save() -> void:
	var run := _run()
	var marching := _raise(run, MARCH)
	var restored := Companies.from_dict(run.companies.to_dict())
	var back := restored.find(marching.id)
	assert_eq(back.order, marching.order, "it forgot what it was raised to do")
	assert_eq(back.commander, marching.commander, "it forgot who was leading it")
	assert_eq(restored.commanders_raised, run.companies.commanders_raised,
		"the count of commanders did not survive, so a number could be reused")
