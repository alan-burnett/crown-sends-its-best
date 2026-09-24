extends TestCase

## The PC's only resident eyes (#81, SPEC §8.1;
## `docs/mechanics/the-diplomat.md`).
##
## 🔒 **Low loyalty spoils the intelligence, not the compliance.** Every other
## contact answers a letter worse when he is slighted. This one tells you less,
## and **the home-town detail goes first**.
##
## 🔒 **Rebellion kills him outright, with no roll.** That is what gives his
## rehoming letter teeth: the letter is the warning.
##
## 🔒 **Famine never endangers him. Only enemies do.**
##
## 🔒 **He is never replaced.** The run continues blind.

const SEED: int = 9042

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


func _town(
	id: StringName,
	sentiment: float = 10.0,
	safety: float = 0.9,
	quality: float = 0.8,
	people: int = 20,
) -> Town:
	var town := Town.new(id, String(id).capitalize(), Vector2i(0, 0))
	town.workers = people
	town.governor_id = StringName("governor_%s" % id)
	town.rebel_sentiment = sentiment
	town.safety = safety
	town.quality_of_life = quality
	return town


func _colony(towns: Array) -> Colony:
	var colony := Colony.new()
	for town in towns:
		colony.add(town)
	return colony


func _context(colony: Colony) -> ColonyContext:
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.run_seed = SEED
	context.colony = colony
	return context


func _him(town: Town, loyalty: float = 60.0) -> Contact:
	var contact := Contact.new(&"diplomat")
	contact.display_name = "Mr Ambrose Kettle"
	contact.role = Contact.ROLE_DIPLOMAT
	contact.relationship.loyalty = loyalty
	if town != null:
		contact.town = town.display_name
	return contact


## A letter context for a colony that has lived at least one month.
##
## **He reports what he has seen**, so a fixture where nothing has happened yet
## is a fixture where he correctly has nothing to say.
func _letter(him: Contact, colony: Colony, log: EventLog, month: int = 0) -> LetterContext:
	var context := LetterContext.new(WorldValues.initial_state(), him, &"")
	context.colony = colony
	context.log = log
	context.month = month
	context.contacts = {String(him.id): him}
	for town in colony.in_order():
		log.emit(SettlePhase.EVENT_LIVED, town.id, maxi(0, month - 1), {
			"town": String(town.id), "quality_of_life": town.quality_of_life,
			"was": town.quality_of_life, "change": 0.0, "direction": "steady",
			"health": 1.0, "safety": town.safety, "means": 1.0, "hope": 1.0, "pleasure": 1.0,
		}, WorldPhase.COLONY_MONTH)
	return context


func test_he_reports_nothing_about_a_colony_that_has_not_lived_yet() -> void:
	# 🔒 A town's quality of life and safety are written in Settle and are nothing
	# before the first one, so a colony in its first month reads as wretched on
	# every measure. He was writing home about a famine in a place nobody had
	# spent a night in — and doing it from two of the first month's six letters.
	var town := _town(&"ashmere", 0.0, 0.0, 0.0)
	var context := LetterContext.new(WorldValues.initial_state(), _him(town, 90.0), &"")
	context.colony = _colony([town])
	context.log = EventLog.new()
	context.month = 0

	assert_false(ColonyConditions.he_has_something_to_report({}, context),
		"he reported on a colony that had not yet lived a month")
	assert_false(ColonyConditions.he_still_writes({"about": "home"}, context),
		"he wrote about the town he had only just been put in")


# --- 🔒 Aware of every town, housed in one ----------------------------------

func test_he_lives_in_a_town_from_the_first_month() -> void:
	# Data cannot know which town, because the towns are made per run. He must
	# still have one: a Diplomat with no home reports the colony's business and
	# never the sharp half, which is the half worth having.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var him: Contact = run.contacts.get("diplomat")
	assert_true(him != null, "the colony has no Diplomat at all")
	assert_false(him.town.is_empty(), "the Diplomat was housed nowhere")
	assert_true(Diplomat.home_of(him, run.colony) != null,
		"he lives somewhere that is not one of the colony's towns")


# --- 🔒 His regard governs what he tells ------------------------------------

func test_the_home_town_detail_goes_first() -> void:
	# §5's ladder, and the order is the design: a cooling man stops telling you
	# **his own business** before he stops telling you the colony's.
	assert_eq(String(Diplomat.reporting_at(90.0)), String(Diplomat.EVERYTHING))
	assert_eq(String(Diplomat.reporting_at(30.0)), String(Diplomat.COLONY_ONLY),
		"a cooling Diplomat gave up the colony reports before his own town's")
	assert_eq(String(Diplomat.reporting_at(5.0)), String(Diplomat.SILENT))


func test_a_cooling_man_still_writes_about_the_colony() -> void:
	var town := _town(&"ashmere")
	var colony := _colony([town])
	var log := EventLog.new()

	var warm := _letter(_him(town, 80.0), colony, log)
	assert_true(ColonyConditions.he_still_writes({"about": "colony"}, warm))
	assert_true(ColonyConditions.he_still_writes({"about": "home"}, warm))

	var cool := _letter(_him(town, 30.0), colony, log)
	assert_true(ColonyConditions.he_still_writes({"about": "colony"}, cool),
		"a cooling Diplomat stopped reporting the colony, which is the wrong half")
	assert_false(ColonyConditions.he_still_writes({"about": "home"}, cool),
		"a cooling Diplomat was still handing over his sharpest intelligence")


func test_at_no_regard_at_all_only_the_two_requests_arrive() -> void:
	# 🔒 §5. **Both of those letters are a way back** — a PC who has neglected him
	# can buy his way back into being informed, which matters because a Diplomat
	# at zero is a PC flying blind in the milestone where rebellion loses runs.
	var town := _town(&"ashmere", 60.0, 0.2, 0.2)
	var colony := _colony([town])
	var him := _him(town, 0.0)
	var context := _letter(him, colony, EventLog.new())

	assert_false(ColonyConditions.he_still_writes({"about": "colony"}, context))
	assert_false(ColonyConditions.he_still_writes({"about": "home"}, context))
	assert_true(ColonyConditions.he_wants_moving({}, context),
		"a Diplomat at no regard stopped asking to be saved")
	assert_true(ColonyConditions.he_wants_paying({}, context),
		"a Diplomat at no regard stopped asking for money, so there is no way back")


func test_a_man_at_sea_writes_nothing() -> void:
	# 🔒 §3: agreeing to move him costs the PC a **real** blackout, and that is
	# what makes refusing a genuine option rather than a formality.
	var town := _town(&"ashmere", 60.0, 0.2, 0.2)
	var colony := _colony([town])
	var him := _him(town, 90.0)
	him.travelling_until = 5

	var at_sea := _letter(him, colony, EventLog.new(), 3)
	assert_false(ColonyConditions.he_still_writes({"about": "colony"}, at_sea),
		"a man on a ship filed a report")
	assert_false(ColonyConditions.he_wants_moving({}, at_sea),
		"a man already at sea asked to be moved again")

	var arrived := _letter(him, colony, EventLog.new(), 6)
	assert_true(ColonyConditions.he_still_writes({"about": "colony"}, arrived),
		"he never started writing again")


# --- 🔒 Rehoming -------------------------------------------------------------

func test_either_trouble_alone_is_enough_to_ask() -> void:
	assert_true(Diplomat.wants_to_move(_town(&"a", 80.0, 0.95)),
		"a seething but well-guarded town was somewhere he was happy to stay")
	assert_true(Diplomat.wants_to_move(_town(&"b", 5.0, 0.1)),
		"a quiet town nobody can defend was somewhere he was happy to stay")
	assert_false(Diplomat.wants_to_move(_town(&"c", 5.0, 0.95)),
		"he asked to leave a quiet, safe town")


func test_he_asks_for_the_least_troubled_town_and_breaks_ties_to_the_largest() -> void:
	var home := _town(&"ashmere", 80.0, 0.2)
	# Two equally quiet places, one of them larger.
	var small := _town(&"brackwater", 10.0, 0.9, 0.8, 12)
	var large := _town(&"coldharbour", 10.0, 0.9, 0.8, 90)
	var troubled := _town(&"dunmere", 55.0, 0.5)
	var colony := _colony([home, small, large, troubled])

	var to := Diplomat.destination_for(home, colony)
	assert_true(to != null, "he had nowhere to go in a colony of four towns")
	assert_eq(String(to.id), "coldharbour",
		"he chose %s, where the trouble is greater or the town smaller" % [to.id])


func test_he_never_asks_to_be_sent_where_he_already_is() -> void:
	var home := _town(&"ashmere", 80.0, 0.1)
	var other := _town(&"brackwater", 79.0, 0.1)
	var to := Diplomat.destination_for(home, _colony([home, other]))
	assert_eq(String(to.id), "brackwater",
		"the least troubled town he could find was the one he is trying to leave")


func test_moving_him_moves_the_sharp_reporting_with_him() -> void:
	# 🔒 §3: the home-town intelligence goes where he goes, and the PC probably
	# wanted it where the fire is. That is the third cost and the real one.
	var home := _town(&"ashmere", 80.0, 0.2)
	var quiet := _town(&"brackwater")
	var colony := _colony([home, quiet])
	var context := _context(colony)
	var him := _him(home, 70.0)

	Diplomat.rehome(him, quiet, context)
	assert_eq(String(Diplomat.home_of(him, colony).id), "brackwater")
	assert_true(Diplomat.is_travelling(him, context.state.month),
		"he arrived the same month he left")
	assert_false(Diplomat.is_travelling(him, context.state.month + Diplomat.MONTHS_TRAVELLING),
		"he never arrived at all")
	assert_not_empty(context.log.of_type(Diplomat.EVENT_MOVED))


# --- 🔒 His price ------------------------------------------------------------

func test_he_asks_for_himself_when_his_town_is_wretched() -> void:
	# The satire working as SPEC §3.2 intends: he reports the starving town
	# truthfully and asks for money for his own candles in the same post. **He is
	# never lying about the town.**
	assert_true(Diplomat.wants_paying(_town(&"a", 10.0, 0.9, 0.1)))
	assert_false(Diplomat.wants_paying(_town(&"b", 10.0, 0.9, 0.9)),
		"he asked for money out of a comfortable town")


# --- 🔒 His death ------------------------------------------------------------

func test_rebellion_kills_him_outright() -> void:
	var town := _town(&"ashmere", 70.0)
	var context := _context(_colony([town]))
	var him := _him(town, 90.0)

	assert_true(Diplomat.rebellion_took_him(him, town, context), "his town flipped and he lived")
	assert_true(him.is_dead)
	var died: Array = context.log.of_type(Diplomat.EVENT_DIED)
	assert_eq(died.size(), 1)
	assert_eq(String(died[0].payload["cause"]), "rebellion")
	# 🔒 SPEC §8.1: nobody will take the post.
	assert_false(bool(died[0].payload["replaced"]), "somebody was sent to replace him")


func test_a_rebellion_somewhere_else_does_not_touch_him() -> void:
	var home := _town(&"ashmere")
	var elsewhere := _town(&"brackwater", 70.0)
	var context := _context(_colony([home, elsewhere]))
	var him := _him(home, 90.0)
	assert_false(Diplomat.rebellion_took_him(him, elsewhere, context),
		"a rebellion two hundred miles away killed the Crown's man")
	assert_false(him.is_dead)


func test_a_town_that_rebels_in_play_takes_him_with_it() -> void:
	# The wiring, not the rule: the rule is tested above, this is that Settle
	# actually asks. A phase that never called it would leave him immortal.
	# **Sentiment is recomputed in Settle**, so the fixture cannot simply assert
	# a figure: the town has to be genuinely wretched and genuinely badly led.
	var town := _town(&"ashmere", 0.0, 0.1, 0.0)
	town.intent = GovernorIntent.SEDITION
	var context := _context(_colony([town]))
	var him := _him(town, 90.0)
	var governor := Contact.new(&"governor_ashmere")
	governor.role = Contact.ROLE_GOVERNOR
	governor.relationship.loyalty = 0.0
	# **And the merchants have turned too.** A loved Diplomat resident in a town
	# holds it back (below), so a fixture with only a loathed governor in it stops
	# just short of the line.
	var merchant := Contact.new(&"merchant_ashmere")
	merchant.role = Contact.ROLE_INSTITUTIONAL
	merchant.town = town.display_name
	merchant.relationship.loyalty = 0.0
	context.contacts = {
		"diplomat": him, "governor_ashmere": governor, "merchant_ashmere": merchant,
	}
	context.grievances = Grievances.new()

	SettlePhase.new()._take_the_temperature(town, context)
	assert_true(town.rebelling,
		"the fixture town never declared; sentiment reached %.1f against %.1f"
			% [town.rebel_sentiment, Rebellion.DECLARES_AT])
	assert_true(him.is_dead, "his town declared against the Crown and he wrote home about it")


func test_a_well_liked_diplomat_holds_his_town_back() -> void:
	# Not designed, but a consequence worth holding: `rebel-sentiment.md` §4
	# counts **every resident** by prominence, and he is a resident Crown man. So
	# a Diplomat the PC has kept happy is a brake on the town he lives in — and
	# losing him takes the brake off, on top of everything else losing him costs.
	#
	# Found by a fixture that stopped 5.6 short of declaring for no reason I had
	# put there.
	var town := _town(&"ashmere", 0.0, 0.1, 0.0)
	var governor := Contact.new(&"governor_ashmere")
	governor.role = Contact.ROLE_GOVERNOR
	governor.relationship.loyalty = 0.0

	var without := _context(_colony([town]))
	without.contacts = {"governor_ashmere": governor}
	var alone := float(RebelSentiment.of(
		town, without, Grievances.new(), without.contacts)["total"])

	var with_him := _context(_colony([town]))
	with_him.contacts = {"governor_ashmere": governor, "diplomat": _him(town, 95.0)}
	var held := float(RebelSentiment.of(
		town, with_him, Grievances.new(), with_him.contacts)["total"])

	assert_true(held < alone,
		"a Diplomat the PC has kept happy did nothing for the town he lives in")


func test_a_storming_that_takes_a_fifth_kills_him_about_one_time_in_five() -> void:
	# 🔒 #427, `population.md` §6: **he dies as any man in the town might**, at
	# `people lost / the town before`, whatever the scale of the town.
	var died := 0
	var tries := 400
	for seed_value in tries:
		var town := _town(&"ashmere")
		var context := ColonyContext.new(
			WorldValues.initial_state(), EventLog.new(), RngStreams.new(seed_value), null
		)
		context.colony = _colony([town])
		var him := _him(town, 90.0)
		if Diplomat.attack_took_him(him, town, 40_000, 200_000, context):
			died += 1
	var share := float(died) / float(tries)
	assert_true(share > 0.13 and share < 0.27,
		"a fifth of the town fell and he died %d times in %d" % [died, tries])


func test_a_town_reduced_to_nothing_takes_him_with_it() -> void:
	var town := _town(&"ashmere")
	var context := _context(_colony([town]))
	var him := _him(town, 90.0)
	var everybody := town.population()
	assert_true(Diplomat.attack_took_him(him, town, everybody, everybody, context),
		"a town with nobody left in it still had a Diplomat in it")
	assert_true(him.is_dead)


func test_an_attack_that_leaves_a_crowd_is_survivable() -> void:
	# A tenth of the town lost is a tenth's chance. Not a balance assertion — the
	# claim is that the roll exists and does not always kill.
	var survived := 0
	for seed_value in 40:
		var town := _town(&"ashmere")
		var context := ColonyContext.new(
			WorldValues.initial_state(), EventLog.new(), RngStreams.new(seed_value), null
		)
		context.colony = _colony([town])
		var him := _him(town, 90.0)
		if not Diplomat.attack_took_him(him, town, 20_000, 200_000, context):
			survived += 1
	assert_true(survived > 0, "an attack on a town of two hundred killed him every time")


func test_famine_never_endangers_him() -> void:
	# 🔒 §6. **Only enemies do.** Enforced by `attack_took_him` being the only
	# path — the famine in Consume does not call it, and this is the guard that
	# notices if somebody wires it up.
	var town := _town(&"ashmere", 10.0, 0.9, 0.1, 2)
	var context := _context(_colony([town]))
	var him := _him(town, 90.0)
	context.contacts = {"diplomat": him}
	town.months_hungry = 12
	town.store(&"food", 0.0)

	for month in 6:
		context.state.month = month
		ConsumePhase.new().run(town, ColonySnapshot.of(context.colony), context)
	assert_true(not context.log.of_type(ConsumePhase.EVENT_FAMINE).is_empty(),
		"the fixture town never starved, so this tests nothing")
	assert_false(him.is_dead, "a famine killed the Diplomat, and only enemies may")


func test_he_survives_a_save_dead_or_alive() -> void:
	var town := _town(&"ashmere")
	var him := _him(town, 40.0)
	him.is_dead = true
	him.travelling_until = 9
	var restored := Contact.from_dict(him.to_dict())
	assert_true(restored.is_dead, "a reload brought the Diplomat back to life")
	assert_eq(restored.travelling_until, 9)


# --- 🔒 His advice is locally correct and never false ------------------------

func test_he_names_the_town_in_the_worst_state_of_the_trouble() -> void:
	var mild := _town(&"ashmere", 35.0)
	var dire := _town(&"brackwater", 62.0)
	var context := _letter(_him(mild, 80.0), _colony([mild, dire]), EventLog.new())
	var worst := DiplomatReport.worst_for(DiplomatReport.SENTIMENT, context)
	assert_eq(String(worst.id), "brackwater",
		"he wrote about the town that was merely grumbling")


func test_he_says_nothing_about_a_colony_with_nothing_wrong() -> void:
	var fine := _town(&"ashmere", 5.0, 0.95, 0.95)
	var context := _letter(_him(fine, 80.0), _colony([fine]), EventLog.new())
	assert_false(ColonyConditions.he_has_something_to_report({}, context),
		"he found something to complain about in a thriving colony")
	for trouble in DiplomatReport.troubles():
		assert_true(DiplomatReport.worst_for(trouble, context) == null,
			"he found '%s' worth writing about in a thriving colony" % trouble)


func test_he_writes_about_the_worst_of_his_four_troubles_and_not_all_of_them() -> void:
	# 🔒 §2, and the post's limits. He watches four things; a resident writing
	# home picks the worst and says *that*. Four reports a month would crowd the
	# Crown's own business out of a post the player has to read in a minute.
	var nearly_out := _town(&"ashmere", 62.0, 0.9, 0.9)
	var a_bit_cold := _town(&"brackwater", 5.0, 0.9, 0.5)
	var context := _letter(
		_him(nearly_out, 80.0), _colony([nearly_out, a_bit_cold]), EventLog.new())

	var pressing := DiplomatReport.most_pressing(context)
	assert_false(pressing.is_empty(), "two troubled towns and he had nothing to say")
	assert_eq(String(pressing["trouble"]), DiplomatReport.SENTIMENT,
		"he wrote about a chilly town while another was about to leave the Crown")
	assert_eq(String(pressing["town"].id), "ashmere")


func test_every_trouble_has_a_remedy_and_none_of_them_is_a_tax_rise() -> void:
	# 🔒 §2. **He never suggests something mechanically false.** He will not
	# propose raising taxes to quell rebellion — that would be confusing rather
	# than characterful, and it would teach the player to stop reading him, which
	# is fatal for the one contact whose whole job is to be read.
	for trouble in DiplomatReport.troubles():
		var remedy := DiplomatReport.suggestion_for(trouble)
		assert_false(remedy.strip_edges().is_empty(),
			"he sees '%s' and has nothing to propose about it" % trouble)
		assert_false(remedy.to_lower().contains("raise the dut")
				or remedy.to_lower().contains("raise the tax"),
			"he proposed raising a duty to fix '%s', which would not work" % trouble)

# --- 🔒 He is paid to move, and he moves (#393) ------------------------------

## A run with the Diplomat housed in the capital and a second town to send him to.
func _two_town_run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := Town.new(&"kettleburn", "Kettleburn", Vector2i(6, 6))
	town.workers = 12
	run.colony.add(town)
	var governor := Governor.generate(town, run.streams)
	town.governor_id = governor.id
	run.add_contact(governor)
	return run


func _the_diplomat(run: RunState) -> Contact:
	return ColonyConditions.diplomat_in(run.contacts)


## A desk for this run at its first month, with every letter in it set aside.
func _desk(run: RunState) -> TurnMachine:
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.begin_turn()
	_set_aside(run)
	return machine


func _set_aside(run: RunState) -> void:
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE


## 🔒 **Through the desk, not beside it.** The Orders in a letter are built
## by `TurnMachine`, which is what stamps the letter they came in (#393). A helper
## that built them itself would pass against a desk that does not exist — and
## did, until the payment was found overtaking the move it paid for.
func _agree_to_move(run: RunState) -> TurnMachine:
	var him := _the_diplomat(run)
	var machine := _desk(run)
	var outgoing := OutgoingLetter.new("diplomat.ask_to_move", him.id)
	outgoing.params = {"town": him.town, "to": "Kettleburn", "amount": 240}
	var wizard := ReplyWizard.new(
		Letter.from_record(content.record("letters", "diplomat.ask_to_move")), outgoing)
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("move", "move_him")
	run.post.add(outgoing)
	machine.send_post()
	return machine


## The PC's own letter to Kettleburn's governor, composed as the desk composes it.
func _send_him_to_kettleburn(run: RunState) -> TurnMachine:
	var machine := _desk(run)
	var governor_id := run.colony.by_id(&"kettleburn").governor_id
	var wizard := Composer.new(content).begin(run, "pc.send_the_diplomat", governor_id)
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("resident", "send")
	machine.send_post()
	return machine


## What he made of the move, in the Reckoning of the month it was sent.
func _his_answer(machine: TurnMachine) -> String:
	for result in machine.orders.results:
		if (result["order"] as Order).kind == M1Registrations.ORDER_MOVE_DIPLOMAT:
			return String(result["outcome"])
	return ""


## The months after the post, with every letter they bring set aside.
func _wait(machine: TurnMachine, months: int = 4) -> void:
	for step in months:
		machine.begin_turn()
		_set_aside(machine.run)
		machine.send_post()


func _moves_in(orders: Array[Order]) -> Array[Order]:
	var out: Array[Order] = []
	for order in orders:
		if order.kind == M1Registrations.ORDER_MOVE_DIPLOMAT:
			out.append(order)
	return out


func test_the_move_he_asked_for_is_a_move_and_not_only_a_payment() -> void:
	# 🔒 The defect. "Move him" was `promise_gold` and nothing else, and
	# `Diplomat.rehome` had no caller but its tests — so the PC paid 240 gold
	# for a move that never happened.
	var run := _two_town_run()
	var him := _the_diplomat(run)
	var machine := _agree_to_move(run)

	var moves := _moves_in(machine.issued_orders)
	assert_eq(moves.size(), 1, "agreeing to move him still produces nothing but a payment")
	assert_eq(String(moves[0].addressed_to), String(him.id),
		"the move was addressed to somebody other than the man who is moving")
	assert_eq(String(moves[0].get_param("town", "")), "Kettleburn",
		"the move named a town other than the one he asked for")
	var paid := false
	for order in machine.issued_orders:
		paid = paid or order.kind == M1Registrations.ORDER_PROMISE_GOLD
	assert_true(paid, "the journey stopped costing the Crown anything (`the-diplomat.md` §3)")


func test_agreeing_to_his_request_moves_him() -> void:
	# The acceptance line, end to end: the letter's option, the Order, his
	# decision in Reckoning, and the move in phase 2 of a later month — with the
	# payment in the same letter, which is what used to overtake it.
	var run := _two_town_run()
	var him := _the_diplomat(run)
	him.relationship.loyalty = 90.0
	var home := him.town
	assert_ne(home, "Kettleburn", "he already lives there, so this proves nothing")

	var machine := _agree_to_move(run)
	var answer := _his_answer(machine)
	assert_ne(answer, "", "his Order was never read")
	assert_ne(answer, String(Compliance.REFUSE),
		"a contented man refused the move he asked for, so this proves nothing")
	_wait(machine)

	assert_eq(him.town, "Kettleburn", "he was paid to move and is still in %s" % home)
	assert_eq(run.log.of_type(Diplomat.EVENT_MOVED).size(), 1,
		"he moved and nobody was told")


func test_the_same_answer_next_month_is_a_different_letter() -> void:
	# 🔒 The post is new each turn and numbers its letters from the start
	# again, so an Order's id repeats from month to month. The letter it came in
	# must not, or a letter could never contradict one sent before it.
	var run := _two_town_run()
	var first := _agree_to_move(run).issued_orders
	var second := _agree_to_move(run).issued_orders
	assert_eq(String(first[0].id), String(second[0].id),
		"the post stopped repeating its numbering, so this proves nothing")
	assert_ne(String(first[0].letter), String(second[0].letter),
		"two posts a month apart were read as one letter")


func test_he_goes_quiet_while_he_travels() -> void:
	# §3's other price: *a couple of months without reports.*
	var run := _two_town_run()
	var him := _the_diplomat(run)
	him.relationship.loyalty = 90.0
	_wait(_agree_to_move(run))

	var moved := run.log.of_type(Diplomat.EVENT_MOVED)
	assert_eq(moved.size(), 1, "he never moved")
	if moved.is_empty():
		return
	assert_true(Diplomat.is_travelling(him, (moved[0] as SimEvent).month),
		"he moved and was writing the same month")


# --- 🔒 And the PC can send him toward trouble (the-diplomat.md §7) --------

func test_the_pc_chooses_the_town_by_choosing_its_governor() -> void:
	# The composer offers recipients and nothing else, so *send the Resident to
	# Kettleburn* is a letter to Kettleburn's governor — and never to the
	# governor of the town he already lives in.
	var run := _two_town_run()
	var him := _the_diplomat(run)
	var composer := Composer.new(content)
	var offered: Array[StringName] = []
	for purpose in composer.purposes(run):
		if String(purpose["letter_id"]) == "pc.send_the_diplomat":
			offered = purpose["recipients"]
	assert_not_empty(offered, "the PC cannot send the Diplomat anywhere")

	var there := run.colony.by_id(&"kettleburn")
	assert_true(offered.has(there.governor_id),
		"Kettleburn's governor cannot be told the Resident is coming")
	var home := Diplomat.home_of(him, run.colony)
	assert_false(offered.has(home.governor_id),
		"the PC was offered to send him where he already lives")


func test_the_order_goes_to_him_and_he_decides() -> void:
	# 🔒 Seam B. The letter is written to the governor; the Order in it is
	# addressed to the Diplomat, whose regard and temper decide whether he goes.
	var run := _two_town_run()
	var machine := _send_him_to_kettleburn(run)

	var moves := _moves_in(machine.issued_orders)
	assert_eq(moves.size(), 1, "sending him produced no move")
	assert_eq(String(moves[0].addressed_to), String(_the_diplomat(run).id),
		"the governor was asked to move the Diplomat, which is not his to decide")
	assert_eq(String(moves[0].get_param("town", "")), "Kettleburn",
		"the letter to Kettleburn's governor sent him to some other town")


func test_sent_toward_trouble_he_goes() -> void:
	var run := _two_town_run()
	var him := _the_diplomat(run)
	him.relationship.loyalty = 90.0

	var machine := _send_him_to_kettleburn(run)
	var answer := _his_answer(machine)
	assert_ne(answer, "", "his Order was never read")
	assert_ne(answer, String(Compliance.REFUSE),
		"a contented man refused to go, so this proves nothing")
	_wait(machine)
	assert_eq(him.town, "Kettleburn", "the PC sent him and he stayed where he was")


func test_he_is_not_offered_while_at_sea_or_dead() -> void:
	var run := _two_town_run()
	var him := _the_diplomat(run)
	var governor := run.contact(run.colony.by_id(&"kettleburn").governor_id)
	var context := LetterContext.new(run.world, governor, &"")
	context.colony = run.colony
	context.contacts = run.contacts
	context.month = run.world.month
	assert_true(ColonyConditions.the_diplomat_could_come_here({}, context),
		"he cannot be sent to a town he has never been to, so this proves nothing")

	him.travelling_until = run.world.month + 2
	assert_false(ColonyConditions.the_diplomat_could_come_here({}, context),
		"he was offered a new posting while still at sea from the last one")
	him.travelling_until = -1
	him.is_dead = true
	assert_false(ColonyConditions.the_diplomat_could_come_here({}, context),
		"the PC was offered to send a dead man somewhere")


func test_a_move_to_a_town_that_is_gone_is_overtaken() -> void:
	var run := _two_town_run()
	var him := _the_diplomat(run)
	var intent := Intent.new(&"", DiplomatMoveExecutor.KIND, him.id, him.id, 1,
		{"town": "Nowhere-on-Sea"})
	var mover := DiplomatMoveExecutor.new()
	mover.colony = run.colony
	mover.contacts = run.contacts
	var home := him.town
	assert_eq(mover.execute(intent, run.world, run.log), Intent.OVERTAKEN_BY_EVENTS,
		"he set off for a town that is not there")
	assert_eq(him.town, home, "he moved to a town that is not there")


func test_cultivation_follows_him() -> void:
	# §7: he can only cultivate the governor he lives with, and the target is
	# worked out from where he is each month (#285) — so moving him is all it
	# takes. Asked of the driver, not of where he lives: the claim is that the
	# regard he buys lands on the new governor.
	var run := _two_town_run()
	var him := _the_diplomat(run)
	var there := run.colony.by_id(&"kettleburn")
	var newcomer := run.contact(there.governor_id)
	var old_host := run.contact(Diplomat.home_of(him, run.colony).governor_id)
	run.world.values[PolicyEffects.CULTIVATE_GOVERNOR_KEY] = 1.0

	CultivationDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_true(old_host.relationship.cultivated > 0.0,
		"he was cultivating nobody before he moved, so this proves nothing")
	assert_almost_eq(newcomer.relationship.cultivated, 0.0, 0.0001)

	Diplomat.rehome(him, there, _context(run.colony))
	run.world.month += 1
	CultivationDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)
	assert_true(newcomer.relationship.cultivated > 0.0,
		"he moved and went on buying regard for the governor he left")
	assert_almost_eq(old_host.relationship.cultivated, 0.0, 0.0001,
		"the governor he left kept what the Diplomat was buying him")
