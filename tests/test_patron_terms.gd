extends TestCase

## The six months that close (#283, `docs/mechanics/patrons.md` §8,
## `docs/mechanics/prestige.md` §5).
##
## 🔒 **No patron leaves before two years**, the extra term is drawn once and
## hidden, and the six months of notice keep trading.
##
## 🔒 **His final loyalty banks on departure and never moves again**, and the
## live term stops the month he goes.
##
## The offer object this file once also held (`PatronOffer`) was retired by
## #439: a patron's letters are his need, his gold, and his specialty offered
## (`patrons.md` §4).

const SEED: int = 4801

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


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## A patron who arrived in month `since`, at a known regard.
func _patron(run: RunState, since: int = 0, loyalty: float = 50.0) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, since)
	patron.relationship = Relationship.new(patron.id, loyalty)
	run.add_contact(patron)
	return patron


# --- 🔒 The term, and the hidden roll ---------------------------------------

func test_no_patron_settles_a_term_before_two_years() -> void:
	var run := _run()
	var patron := _patron(run, 0)
	for month in range(1, PatronTerm.STAYS_AT_LEAST):
		PatronTerm.advance(run, run.log, month)
		assert_eq(patron.leaves_month, -1,
			"he settled on a leaving date in month %d" % month)

	PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
	assert_true(patron.leaves_month >= 0, "two years passed and he settled nothing")


func test_the_extra_term_is_drawn_once_and_never_exceeds_two_more_years() -> void:
	var run := _run()
	var ends := PackedInt32Array()
	for index in 40:
		var patron := _patron(run, 0)
		patron.id = StringName("patron_probe_%d" % index)
		PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
		if patron.leaves_month < 0:
			continue
		# The notice comes after the term, so it is subtracted to read the term.
		var extra := patron.leaves_month \
			- PatronTerm.STAYS_AT_LEAST - PatronTerm.NOTICE_MONTHS
		assert_true(extra >= 0 and extra <= PatronTerm.AT_MOST_LONGER,
			"he settled on %d further months" % extra)
		ends.append(extra)
	assert_true(ends.size() > 1, "nobody settled a term, so this proves nothing")


func test_and_it_is_never_redrawn() -> void:
	var run := _run()
	var patron := _patron(run, 0)
	PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
	var settled := patron.leaves_month
	for month in range(PatronTerm.STAYS_AT_LEAST + 1, settled):
		PatronTerm.advance(run, run.log, month)
		assert_eq(patron.leaves_month, settled,
			"he changed his mind in month %d" % month)


func test_the_roll_is_not_in_the_log() -> void:
	# 🔒 §8: *the PC is told none of it*, and the log is what letters read. At two
	# years he cannot tell whether this man has a month left or another two.
	var run := _run()
	_patron(run, 0)
	PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
	var told := PackedStringArray()
	for event in run.log.all():
		if event.type == PatronTerm.EVENT_LEAVING:
			continue
		if event.payload.has("leaves_month"):
			told.append(String(event.type))
	assert_empty(told,
		"the leaving date reached the log before he announced it: %s" % [told])


func test_the_same_seed_gives_the_same_man_the_same_term() -> void:
	var settled := PackedInt32Array()
	for pass_index in 3:
		var run := _run()
		var patron := _patron(run, 0)
		PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
		settled.append(patron.leaves_month)
	for index in range(1, settled.size()):
		assert_eq(settled[index], settled[0],
			"one seed gave one man two terms: %s" % [settled])


func test_the_term_survives_a_save() -> void:
	var run := _run()
	var patron := _patron(run, 0)
	PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
	assert_eq(Contact.from_dict(patron.to_dict()).leaves_month, patron.leaves_month,
		"a saved run forgot when he meant to go")


func test_everybody_gets_his_six_months() -> void:
	# 🔒 §8's window is the point of the mechanic, and a man who settled on three
	# further months would be gone before he could give notice. The term runs out
	# and *then* the six begin.
	var run := _run()
	for index in 40:
		var patron := _patron(run, 0)
		patron.id = StringName("patron_notice_%d" % index)
		PatronTerm.advance(run, run.log, PatronTerm.STAYS_AT_LEAST)
		if patron.leaves_month < 0:
			continue
		assert_true(
			patron.leaves_month - PatronTerm.STAYS_AT_LEAST >= PatronTerm.NOTICE_MONTHS,
			"he settled on going in %d months and could never have given notice"
				% [patron.leaves_month - PatronTerm.STAYS_AT_LEAST])


func test_and_nobody_departs_before_two_years() -> void:
	var run := _run()
	var patron := _patron(run, 0)
	for month in range(1, PatronTerm.STAYS_AT_LEAST + 1):
		PatronTerm.advance(run, run.log, month)
	assert_empty(run.log.of_type(PatronTerm.EVENT_DEPARTED),
		"a patron went home inside two years")


# --- 🔒 Six months, announced, and still trading ----------------------------

func test_he_announces_the_date_six_months_out() -> void:
	var run := _run()
	var patron := _patron(run, 0)
	patron.leaves_month = 60

	for month in range(50, 61):
		PatronTerm.advance(run, run.log, month)
	var told := run.log.of_type(PatronTerm.EVENT_LEAVING)
	assert_eq(told.size(), 1, "he gave notice %d times" % told.size())
	assert_eq(told[0].month, 60 - PatronTerm.NOTICE_MONTHS)
	assert_eq(int(told[0].payload.get("leaves_month", 0)), 60,
		"his notice did not name the date")


func test_and_the_business_continues_as_normal() -> void:
	# 🔒 §8. A patron who stopped dealing the month he gave notice would make the
	# window worthless, which is the opposite of the point: a man on his way out
	# still has his market to offer.
	var run := _run()
	var patron := _patron(run, 0, 80.0)
	patron.specialty = "resources"
	patron.specialty_kind = "sugar"
	patron.specialty_bonus = Patron.BONUS_PRICE
	patron.leaves_month = 60
	var context := _context_for(run, patron, 56)
	context.policies = run.policies
	assert_true(PatronTerm.is_leaving(patron, 56))
	assert_true(ColonyConditions.his_barony_has_a_market({}, context),
		"a patron on his way out stopped offering")


func test_the_months_left_count_down_to_the_month() -> void:
	# 🔒 *The PC knows it to the month*, which is what makes the window a decision.
	var patron := Contact.new()
	patron.leaves_month = 60
	assert_eq(PatronTerm.months_left(patron, 40), -1)
	assert_eq(PatronTerm.months_left(patron, 54), 6)
	assert_eq(PatronTerm.months_left(patron, 59), 1)
	assert_eq(PatronTerm.months_left(patron, 60), 0)


# --- 🔒 Departure banks, and never moves again ------------------------------

func test_his_final_loyalty_banks_when_he_goes() -> void:
	var run := _run()
	var patron := _patron(run, 0, 90.0)
	patron.leaves_month = 30

	PatronTerm.advance(run, run.log, 30)
	assert_false(run.log.of_type(PatronTerm.EVENT_DEPARTED).is_empty(),
		"he never left")
	assert_true(Prestige.patron_credit_in(run.log) > 0.0,
		"a patron who left at ninety banked nothing")


func test_and_a_man_neglected_in_his_last_spring_banks_that() -> void:
	# 🔒 §8's whole argument. Two identical patrons, one pleased at the end and one
	# let go — and it is the *final* regard that goes to court.
	var pleased := _run()
	var neglected := _run()
	var one := _patron(pleased, 0, 90.0)
	var other := _patron(neglected, 0, 90.0)
	one.leaves_month = 30
	other.leaves_month = 30
	other.relationship = Relationship.new(other.id, 10.0)

	PatronTerm.advance(pleased, pleased.log, 30)
	PatronTerm.advance(neglected, neglected.log, 30)

	assert_true(Prestige.patron_credit_in(pleased.log)
			> Prestige.patron_credit_in(neglected.log),
		"three years of cultivation and a bad last spring banked the same")


func test_the_bank_never_moves_again() -> void:
	var run := _run()
	var patron := _patron(run, 0, 90.0)
	patron.leaves_month = 30
	PatronTerm.advance(run, run.log, 30)
	var banked := Prestige.patron_credit_in(run.log)

	for month in range(31, 60):
		PatronTerm.advance(run, run.log, month)
	assert_almost_eq(Prestige.patron_credit_in(run.log), banked, 0.0001,
		"a departed patron went on changing his mind at court")


func test_the_live_term_stops_the_month_he_goes() -> void:
	# 🔒 §5: his regard is live *while he is present*. Two terms, one handover,
	# and no arithmetic joining them.
	var run := _run()
	var patron := _patron(run, 0, 90.0)
	patron.leaves_month = 30
	assert_true(PatronTerm.live_regard(run) > 0.0, "a present patron counts nothing")

	PatronTerm.advance(run, run.log, 30)
	assert_almost_eq(PatronTerm.live_regard(run), 0.0, 0.0001,
		"a departed patron is still a live term")


func test_the_live_term_is_the_latest_reading_and_not_a_sum() -> void:
	# 🔒 Summing it would make a long-tolerated patron worth more than a beloved
	# one, which is the opposite of what §5 asks for.
	var run := _run()
	for month in range(1, 6):
		run.log.emit(Prestige.EVENT_PATRON_REGARD, &"crown", month,
			{"amount": 100.0}, WorldPhase.RECKONING)
	assert_almost_eq(Prestige.patron_regard_in(run.log), 100.0, 0.0001,
		"five quiet months made a patron five times as well regarded")


func test_prestige_counts_both_terms() -> void:
	var run := _run()
	run.log.emit(Prestige.EVENT_PATRON_REGARD, &"crown", 4,
		{"amount": 250.0}, WorldPhase.RECKONING)
	run.log.emit(Prestige.EVENT_PATRON_CREDIT, &"patron_1", 4,
		{"amount": 90.0}, WorldPhase.RECKONING)
	var parts := Prestige.of(run.log)
	assert_almost_eq(float(parts["patron_regard"]), 250.0, 0.0001)
	assert_almost_eq(float(parts["patron_credit"]), 90.0, 0.0001)
	assert_almost_eq(float(parts["total"]),
		float(parts["net_gold"]) + 340.0 - float(parts["optics_debt"]), 0.0001,
		"the two patron terms do not both reach the total")


# --- 🔒 He writes, and answering him reaches prestige (#388) ----------------

func _letter(id: String) -> Letter:
	return Letter.from_record(content.record("letters", id))


func _context_for(run: RunState, patron: Contact, month: int = 3) -> LetterContext:
	var context := LetterContext.new(run.world, patron, Tone.DUTIFUL)
	context.log = run.log
	context.month = month
	context.pc = run.setup
	context.demands = run.demands
	context.contacts = run.contacts
	return context


## Put an Order on a patron's desk the way answering his letter does, and run
## the month's compliance over it.
func _answer(run: RunState, patron: Contact, kind: StringName, params: Dictionary) -> Dictionary:
	var order := Order.new(kind, patron.id, params)
	return Compliance.resolve(
		order, patron, run.intents, run.world, run.log, run.streams)


func test_a_patron_has_letters_of_his_own() -> void:
	# 🔒 The acceptance line, and the whole of the finding: there was no
	# `data/letters_en/patron/` at all, and the only time one reached the desk was
	# a third party reporting that a man the PC had never met had been rude about
	# him at court.
	for id in ["patron.introduction", "patron.request_gold", "patron.taking_his_leave"]:
		assert_true(content.has_record("letters", id), "%s does not exist" % id)
		assert_eq(String(_letter(id).sender), "patron",
			"%s is not sent by a patron" % id)


func test_one_file_serves_every_patron() -> void:
	# 🔒 §7's template pattern: `sender` names no contact, so the director reads
	# it as a role and expands it to one candidate per man holding it, each with
	# his own context. Three patrons do not need three files.
	var run := _run()
	var first := _patron(run, 0, 60.0)
	var second := _patron(run, 0, 60.0)
	assert_ne(first.id, second.id, "the fixture made one man twice")

	var senders := Director.new(content).senders_of(_letter("patron.introduction"), run)
	var ids := PackedStringArray()
	for contact in senders:
		ids.append(String((contact as Contact).id))
	assert_true(ids.has(String(first.id)) and ids.has(String(second.id)),
		"one of the two patrons could not send his own introduction: %s" % ids)


func test_the_pc_still_cannot_write_to_a_patron_unprompted() -> void:
	# 🔒 §1, the Author's ruling: **the duke's model exactly.** You read what he
	# sends and you answer it. `data/letters_en/pc/` gains nothing, and the lever
	# is reactive rather than absent — a reply produces an Order addressed to the
	# sender, which is the same path every other contact's compliance runs.
	# A composable letter is one with `to_roles`; that list is the whole of who
	# the PC may pick from, so asking it is asking the question directly.
	var composable := 0
	for id in content.ids("letters"):
		var record: Dictionary = content.record("letters", String(id))
		var roles: Array = record.get("to_roles", [])
		if roles.is_empty():
			continue
		composable += 1
		assert_false(roles.has(String(Contact.ROLE_PATRON)),
			"%s lets the PC compose a letter to a patron" % id)
	assert_true(composable > 0, "no letter is composable at all, so this proves nothing")


func test_answering_him_well_banks_credit() -> void:
	# 🔒 The acceptance line. `PatronCredit.bank` had two callers and neither
	# could be reached: the offer object's `settle` (retired by #439), which
	# nothing called, and
	# `compliance.gd`, which banks on an Order addressed to a patron — and no
	# Order could be addressed to one, because no letter from one existed.
	var run := _run()
	var patron := _patron(run, 0, 60.0)

	assert_almost_eq(float(Prestige.of(run.log)["patron_credit"]), 0.0, 0.0001,
		"credit was banked before the PC answered anything")

	_answer(run, patron, M1Registrations.ORDER_GRANT_FAVOR,
		{"to": String(patron.id), "favor": "the colony's friendship"})

	assert_true(float(Prestige.of(run.log)["patron_credit"]) > 0.0,
		"the PC welcomed a patron and the court heard nothing of it")


func test_refusing_him_costs_credit_and_his_regard() -> void:
	# 🔒 **The difference from a duke is what refusal costs.** A duke's costs
	# prestige through an optic; a patron's costs his regard, which is a live
	# term — so refusing a patron is a prestige loss that arrives quietly,
	# through the man, rather than as a debt entered against the PC.
	var run := _run()
	var patron := _patron(run, 0, 60.0)
	var before := patron.loyalty()

	_answer(run, patron, M1Registrations.ORDER_REFUSE, {"to": String(patron.id)})

	assert_true(patron.loyalty() < before,
		"the PC turned him down flat and he thought no less of him")
	assert_true(float(Prestige.of(run.log)["patron_credit"]) < 0.0,
		"a refusal cost nothing at court")


func test_nothing_banks_for_a_man_who_is_not_a_patron() -> void:
	# 🔒 One guard in one place. `compliance.gd` calls `bank` on every deed and it
	# returns at once for everybody else, rather than compliance knowing which
	# contacts are patrons — a guard at the call site is a rule somebody has to
	# remember at the next call site.
	var run := _run()
	var steward := run.contact(&"steward")
	assert_true(steward != null, "there is no Steward to answer")

	_answer(run, steward, M1Registrations.ORDER_REFUSE, {"to": "steward"})
	assert_almost_eq(float(Prestige.of(run.log)["patron_credit"]), 0.0, 0.0001,
		"refusing a Crown officer banked patron credit")


# --- 🔒 The six months, and the date he names ------------------------------

func test_the_window_opening_is_a_letter_and_not_only_an_event() -> void:
	# 🔒 §8: the PC is supposed to know it **to the month**, because his final
	# loyalty banks permanently when he goes. `patron_leaving` had been emitted
	# since #283 and read by nothing, so the deadline the doc designed as
	# actionable was a number in a log.
	var run := _run()
	var patron := _patron(run, 0, 60.0)
	var context := _context_for(run, patron)

	assert_false(ColonyConditions.he_is_taking_his_leave({}, context),
		"a man who has given no notice is already saying goodbye")

	patron.leaves_month = context.month + PatronTerm.NOTICE_MONTHS
	assert_true(ColonyConditions.he_is_taking_his_leave({}, context),
		"he gave his notice and the letter could not tell")


func test_the_letter_can_say_how_long_is_left() -> void:
	var run := _run()
	var patron := _patron(run, 0, 60.0)
	var context := _context_for(run, patron)
	patron.leaves_month = context.month + PatronTerm.NOTICE_MONTHS

	assert_eq(int(ColonyParamSources.patron_leaves_in({}, context)),
		PatronTerm.NOTICE_MONTHS,
		"he named a date that is not the one he sails on")


func test_the_introduction_is_asked_of_the_man_and_not_the_colony() -> void:
	# 🔒 Every other patron in the post is a different man with a different
	# arrival. A condition reading *any* arrival would have all of them
	# introducing themselves at once on the month the third one came.
	var run := _run()
	var old_hand := _patron(run, 0, 60.0)
	var newcomer := _patron(run, 0, 60.0)
	run.log.emit(Patron.EVENT_ARRIVED, newcomer.id, 9, {}, WorldPhase.ARRIVALS)

	var about_the_newcomer := _context_for(run, newcomer, 9)
	assert_true(ColonyConditions.he_has_just_arrived({"within": 2}, about_the_newcomer),
		"the man who just landed does not introduce himself")

	var about_the_old_hand := _context_for(run, old_hand, 9)
	assert_false(ColonyConditions.he_has_just_arrived({"within": 2}, about_the_old_hand),
		"a patron of long standing introduced himself again because somebody else arrived")


func test_any_patron_may_ask_for_gold_at_any_regard() -> void:
	# 🔒 #439 retired the offer model this letter's gate once asked, and kept the
	# gate it had: a bare request was open to every patron at every regard.
	var run := _run()
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	var trigger: Dictionary = content.collection("triggers")["trigger.patron.request_gold"]
	for loyalty in [1.0, 50.0, 99.0]:
		var patron := _patron(run, 0, loyalty)
		assert_true(machine.director._conditions_hold(trigger, machine.director._context(run, patron)),
			"a patron at regard %d may not ask for gold" % int(loyalty))
