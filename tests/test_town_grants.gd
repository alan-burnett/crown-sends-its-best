extends TestCase

## The Crown can give a town gold (#400, `town-economy.md` §4,
## `institutional-contacts.md` §3).
##
## 🔒 **It is a promise like any other.** Paid while the Crown honours payments,
## broken when it refuses them, and counted on the Crown's books exactly as any
## promise of the same gold. The only thing that differs is where the gold goes:
## into the town's purse.

const SEED: int = 400
const CHARITY := "trigger.clergyman.charity"

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

func _town() -> Town:
	return run.colony.in_order()[0]


## A promise of `amount` gold to `to`, naming `town` if one is given, made this
## month and due the next.
func _promise(book: PromiseBook, amount: int, town: String = "", to: StringName = &"steward") -> Promise:
	var args := {"to": String(to), "amount": amount}
	if not town.is_empty():
		args["town"] = town
	var order := Order.new(M1Registrations.ORDER_PROMISE_GOLD, to, args, run.world.month)
	return book.make(PromiseBook.from_order(order, run.world.month), run.contact(to), run.log, run.world.month)


## The Crown's month, when it falls due.
func _settle(book: PromiseBook, pays: bool = true, log: EventLog = null) -> void:
	var driver := PromiseDriver.new(book)
	driver.contacts = run.contacts
	driver.colony = run.colony
	driver.can_crown_pay = pays
	var state := run.world
	state.month += PromiseBook.DEFAULT_TERM_MONTHS
	driver.on_phase(WorldPhase.CROWNS_MONTH, state, log if log != null else run.log, run.streams)


func _with_a_church() -> Contact:
	var town := _town()
	town.add_building(&"church")
	ContactRoster.house_the_residents(run)
	return run.contacts.get(String(ContactRoster.resident_id(town, "clergyman")), null)


func _lived() -> void:
	for town in run.colony.in_order():
		run.log.emit(SettlePhase.EVENT_LIVED, town.id, run.world.month, {"town": String(town.id)})


# --- 🔒 Where the gold goes ----------------------------------------------------------

func test_a_kept_promise_to_a_town_lands_in_its_purse() -> void:
	var town := _town()
	var book := PromiseBook.new()
	var before := town._gold
	var promise := _promise(book, 100, town.display_name)
	_settle(book)
	assert_eq(String(promise.status), String(Promise.KEPT))
	assert_almost_eq(town._gold, before + 100.0, 0.001, "the Crown paid and the town is no richer")
	var granted: Array = run.log.of_type(PromiseDriver.EVENT_GRANTED)
	assert_eq(granted.size(), 1, "the town grew richer and nothing said so")
	assert_eq(String(granted[0].payload["town"]), String(town.id))


func test_the_ledger_shows_the_payment() -> void:
	var town := _town()
	var book := PromiseBook.new()
	_promise(book, 100, town.display_name)
	_settle(book)
	var page := Ledger.of(run.log).page(run.world.month)
	var out := 0.0
	for entry in page.entries:
		if entry.direction == Ledger.OUT:
			out += entry.amount
	assert_almost_eq(out, 100.0, 0.001, "the Ledger does not show what the Crown paid the town")


func test_a_promise_naming_nobody_leaves_every_purse_alone() -> void:
	var town := _town()
	var book := PromiseBook.new()
	var before := town._gold
	_promise(book, 100)
	_settle(book)
	assert_almost_eq(town._gold, before, 0.001, "a promise to a man put gold in a town")
	assert_empty(run.log.of_type(PromiseDriver.EVENT_GRANTED))


func test_the_turn_loop_pays_into_the_colonys_towns() -> void:
	# The driver above is built by hand; this is the one the game runs.
	assert_same(machine.promise_driver.colony, run.colony,
		"the turn loop settles promises with no colony to pay a town in")


# --- 🔒 A promise like any other ------------------------------------------------------

func test_while_the_crown_refuses_it_breaks_and_the_town_gets_nothing() -> void:
	var town := _town()
	var book := PromiseBook.new()
	var before := town._gold
	var promise := _promise(book, 100, town.display_name)
	_settle(book, false)
	assert_eq(String(promise.status), String(Promise.BROKEN))
	assert_almost_eq(town._gold, before, 0.001, "a refused payment reached the town")
	assert_empty(run.log.of_type(PromiseDriver.EVENT_GRANTED))


func test_it_costs_the_crown_exactly_what_any_promise_of_gold_does() -> void:
	# `net_position` reads the Crown's books, so the books are the question.
	var to_a_town := PromiseBook.new()
	var to_a_man := PromiseBook.new()
	var month := run.world.month + PromiseBook.DEFAULT_TERM_MONTHS
	_promise(to_a_town, 100, _town().display_name)
	var town_log := EventLog.new()
	_settle(to_a_town, true, town_log)
	run.world.month -= PromiseBook.DEFAULT_TERM_MONTHS
	_promise(to_a_man, 100)
	var man_log := EventLog.new()
	_settle(to_a_man, true, man_log)
	assert_almost_eq(CrownAccounts.of(town_log).paid_in(month), 100.0, 0.001)
	assert_almost_eq(CrownAccounts.of(town_log).paid_in(month), CrownAccounts.of(man_log).paid_in(month), 0.001,
		"a grant to a town cost the Crown something other than the same gold promised to a man")


func test_the_town_it_is_owed_to_survives_the_save() -> void:
	var town := _town()
	var book := PromiseBook.new()
	var before := town._gold
	_promise(book, 100, town.display_name)
	var restored := PromiseBook.from_dict(book.to_dict())
	_settle(restored)
	assert_almost_eq(town._gold, before + 100.0, 0.001, "the save forgot which town the gold was owed to")


# --- The clergyman's charity ------------------------------------------------------------

func test_the_clergyman_asks_when_his_town_lives_badly_and_not_otherwise() -> void:
	var clergyman := _with_a_church()
	assert_true(clergyman != null, "the church brought no clergyman")
	_lived()
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[CHARITY]
	_town().quality_of_life = 0.9
	assert_false(director._conditions_hold(trigger, director._context(run, clergyman)),
		"a priest in a comfortable town asked for charity")
	_town().quality_of_life = 0.2
	assert_true(director._conditions_hold(trigger, director._context(run, clergyman)),
		"a priest in a town living badly did not ask")


func test_agreeing_promises_the_gold_to_his_town() -> void:
	var clergyman := _with_a_church()
	_lived()
	_town().quality_of_life = 0.2
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[CHARITY]
	var letter := Letter.from_record(content.record("letters", "clergyman.charity"))
	var context := director._context(run, clergyman)
	context.params = director._inbound(trigger, letter, clergyman, context, run).params

	var effect: Dictionary = {}
	for option in content.record("letters", "clergyman.charity")["reply"]["steps"][0]["options"]:
		if String(option["id"]) == "give":
			effect = option["effect"]
	assert_false(effect.is_empty(), "the letter has no way to agree")
	var id := String(effect.keys()[0])
	var order := ContentRegistry.run_effect(id, effect[id], context)
	var promise := PromiseBook.from_order(order, run.world.month)
	assert_eq(String(promise.kind), "gold")
	assert_eq(String(promise.payer), String(Promise.PAYER_CROWN), "charity is not the Crown's money")
	assert_true(DiplomatMoveExecutor.town_named(run.colony, String(promise.terms.get("town", ""))) == _town(),
		"agreeing did not name his church's town")
