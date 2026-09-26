extends TestCase

## A favour is one deed, and an apology is a word (#459, `contacts.md` §7;
## SPEC §8.5 🔒 *deeds outweigh words*).
##
## 🔒 **A favour with no effect in the world moves loyalty once**, at compliance.
## It is no promise as well, so nothing banks it again the month after, and a
## Crown that has closed its purse cannot break it.
##
## 🔒 **Owning a broken promise never leaves him better disposed** than before
## the promise was broken: an apology moves him as the letter's tone does.

const SEED: int = 459

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


func after_each() -> void:
	reset_world()
	content.free()


func _marshal() -> Contact:
	return run.contact(&"marshal")


## Carry an order to him and read it this month, as the post does.
func _read(order: Order, month: int) -> void:
	run.world.month = month
	order.issued_month = month
	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.carry(order)
	orders.on_phase(WorldPhase.RECKONING, run.world, run.log, run.streams)


func _settle(month: int, crown_pays: bool = true) -> void:
	run.world.month = month
	var driver := PromiseDriver.new(run.promises)
	driver.contacts = run.contacts
	driver.can_crown_pay = crown_pays
	driver.on_phase(WorldPhase.CROWNS_MONTH, run.world, run.log, run.streams)


# --- 🔒 A favour is one deed ----------------------------------------------------------------

func test_a_favour_with_no_effect_moves_loyalty_once() -> void:
	var marshal := _marshal()
	var before := marshal.relationship.loyalty
	var favour := Order.new(M1Registrations.ORDER_GRANT_FAVOR, marshal.id,
		{"to": "marshal", "favor": "a kindness"})
	favour.tone = Tone.DUTIFUL
	_read(favour, 3)
	var granted := marshal.relationship.loyalty
	assert_true(granted > before, "a favour moved him not at all")
	assert_empty(run.promises.outstanding(), "a favour became a promise as well")
	_settle(4)
	_settle(5, false)
	assert_almost_eq(marshal.relationship.loyalty, granted, 0.0001,
		"the favour banked a second time, or the Crown's refusal broke it")


# --- 🔒 An apology is a word ----------------------------------------------------------------

func test_owning_a_broken_promise_never_leaves_him_better_disposed() -> void:
	var marshal := _marshal()
	var before := marshal.relationship.loyalty
	_read(Order.new(M1Registrations.ORDER_PROMISE_GOLD, marshal.id, {"to": "marshal", "amount": 200}), 3)
	# A promise falls due the month after it is made.
	_settle(4, false)
	assert_true(marshal.relationship.promises_broken > 0, "the promise was never broken, so this proves nothing")
	var apology := Order.new(M1Registrations.ORDER_APOLOGISE, marshal.id, {"to": "marshal"})
	apology.tone = Tone.PLEASED
	_read(apology, 5)
	assert_true(marshal.relationship.loyalty <= before + 0.0001,
		"owning a broken promise left him better disposed than before it was made")


func test_an_apology_is_remembered_as_nothing_and_the_court_hears_nothing() -> void:
	var marshal := _marshal()
	var memories := marshal.relationship.history.size()
	var apology := Order.new(M1Registrations.ORDER_APOLOGISE, marshal.id, {"to": "marshal"})
	apology.tone = Tone.DUTIFUL
	var before := marshal.relationship.loyalty
	_read(apology, 3)
	assert_eq(marshal.relationship.history.size(), memories, "an apology was remembered as a deed")
	assert_almost_eq(marshal.relationship.loyalty, before, 0.0001,
		"a dutiful apology moved him as a deed would")
	assert_true(PromiseBook.from_order(apology, 3) == null)


func test_the_marshal_is_owned_with_an_apology() -> void:
	for option in content.record("letters", "marshal.your_word")["reply"]["steps"][0]["options"]:
		if String(option["id"]) == "own_it":
			assert_true((option["effect"] as Dictionary).has("apologise"),
				"owning it is still a deed")
			return
	assert_true(false, "marshal.your_word has no own_it answer")
