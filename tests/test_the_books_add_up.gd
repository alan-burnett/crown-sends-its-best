extends TestCase

## The Ledger's rows add up to its total, and the summary's parts add up to the
## score (#463, SPEC §10.4, §14.1; `prestige.md` §2).
##
## 🔒 **Every Crown-side transaction is on the Ledger**, the charge on a policy
## included, and it reads the same books standing does.
##
## 🔒 **Every term of prestige is on the summary.**

const SEED: int = 463

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


## A few months of every kind of Crown-side money.
func _a_busy_log() -> EventLog:
	var log := EventLog.new()
	for month in [1, 2, 3]:
		log.emit(Trade.EVENT_SOLD, &"ashmere", month, {"resource": "furs", "quantity": 10.0, "tax": 12.0 * month})
		log.emit(Trade.EVENT_BOUGHT, &"ashmere", month, {"resource": "tools", "quantity": 2.0, "tax": 3.0})
	var book := PolicyBook.new()
	book.enact(Policy.new(&"steward", PolicyEffects.IMMIGRATION, 40.0, Policy.ALL), log, 1)
	for month in [2, 3]:
		book.bill({}, log, month)
	var kept := Promise.new(&"marshal", &"gold", {"amount": 25}, 2, 3)
	kept.payer = Promise.PAYER_CROWN
	log.emit(PromiseBook.EVENT_KEPT, &"marshal", 3, kept.to_dict())
	log.emit(GoldGiftExecutor.EVENT_GIVEN, &"patron_1", 2, {"from": "patron_1", "amount": 30.0})
	return log


func test_every_page_adds_up_to_the_months_net() -> void:
	var log := _a_busy_log()
	var ledger := Ledger.of(log)
	var accounts := CrownAccounts.of(log)
	assert_true(ledger.months().size() >= 3)
	for month in ledger.months():
		assert_almost_eq(ledger.page(month).net(), accounts.net_in(month), 0.001,
			"the rows of month %d do not add up to what the Crown's books say" % month)


func test_the_months_add_up_to_the_net_position_shown() -> void:
	var log := _a_busy_log()
	var ledger := Ledger.of(log)
	var sum := 0.0
	for month in ledger.months():
		sum += ledger.page(month).net()
	assert_almost_eq(sum, ledger.net_position(), 0.001,
		"the pages do not add up to the figure above them")


func test_a_policy_charge_is_a_line_out() -> void:
	var ledger := Ledger.of(_a_busy_log())
	var charged := 0.0
	for entry in ledger.page(2).entries:
		if entry.direction == Ledger.OUT:
			charged += entry.amount
	assert_almost_eq(charged, 40.0, 0.001, "the charge on a policy is missing from the Ledger")


func test_the_summarys_parts_add_up_to_the_score() -> void:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	run.add_contact(patron)
	PatronCredit.bank(patron, Relationship.GRANTED, run.log, 2)
	run.log.emit(Prestige.EVENT_PATRON_REGARD, &"crown", 3, {"amount": 75.0})
	run.log.emit(Trade.EVENT_SOLD, &"ashmere", 3, {"resource": "furs", "quantity": 10.0, "tax": 200.0})
	run.ending = RunEnding.end(RunEnding.FAILED, run.log, 4)

	var facts := RunSummary.of(run)
	var parts := float(facts["net_gold"]) + float(facts.get("patron_credit", 0.0)) \
		+ float(facts.get("patron_regard", 0.0)) - float(facts["optics_debt"])
	assert_true(absf(float(facts.get("patron_credit", 0.0))) > 0.0, "no patron credit, so this proves nothing")
	assert_almost_eq(parts, float(facts["score"]), 0.001, "the summary's parts do not add up to its score")
	var restored := RunEnding.from_dict(run.ending.to_dict())
	assert_almost_eq(restored.patron_regard, 75.0, 0.001, "the ending forgot its patron regard in the save")
