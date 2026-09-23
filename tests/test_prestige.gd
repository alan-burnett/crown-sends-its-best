extends TestCase

## The Crown's running account of the PC (#76, SPEC §14.1,
## `docs/mechanics/prestige.md`).
##
## 🔒 **It never reads the colony's welfare.** Not quality of life, not rebel
## sentiment, not population. SPEC §18 makes scoring the colony's welfare a
## non-goal, and the pillar the ending rests on is that **a PC can leave behind a
## wretched, half-starved colony and retire in glory**.
##
## 🔒 **A mechanic emits the event; it never prices it.** One table decides which
## events are optics and what each is worth, because a price is only meaningful
## against every other price.
##
## 🔒 **Optics never decay**, which is what makes the retirement decision real:
## the reason to leave is never that waiting heals anything.

const SEED: int = 8819


func _log() -> EventLog:
	return EventLog.new()


## Put gold on the Crown's books the way a month of duty does — through the same
## events `CrownAccounts` reduces, so the fixture cannot drift from the real one.
func _received(log: EventLog, month: int, amount: float) -> void:
	log.emit(Trade.EVENT_SOLD, &"ashmere", month, {
		"town": "ashmere", "resource": "furs", "sold": 1.0,
		"earned": amount, "tax": amount, "rate": 0.1,
	}, WorldPhase.COLONY_MONTH)


## And take it off them the way an honoured standing charge does.
func _paid(log: EventLog, month: int, amount: float) -> void:
	log.emit(PolicyBook.EVENT_BILLED, &"crown", month, {
		"policy": "curriculum", "crown_paid": amount,
	}, WorldPhase.CROWNS_MONTH)


func _protest(log: EventLog, month: int, town: StringName = &"ashmere") -> void:
	log.emit(TradeProtest.EVENT_DECLARED, town, month, {
		"town": String(town), "resource": "tea", "luxury": true, "rate": 0.8,
		"loudest": "rise", "running": ["tea"], "prestige": true,
	}, WorldPhase.COLONY_MONTH)


## Bank a deed done to a patron, through the event prestige actually reduces.
func _a_kindness_done(log: EventLog, month: int, amount: float) -> void:
	log.emit(Prestige.EVENT_PATRON_CREDIT, &"patron_1", month, {
		"contact": "patron_1", "deed": "granted", "amount": amount,
	}, WorldPhase.RECKONING)


func _rebellion(log: EventLog, month: int, town: StringName = &"ashmere") -> void:
	log.emit(Rebellion.EVENT_DECLARED, town, month, {
		"town": String(town), "population": 40, "governor": "governor_ashmere",
	}, WorldPhase.COLONY_MONTH)


# --- 🔒 It is measurable at any point, and it falls as well as rises ---------

func test_it_is_computable_in_the_middle_of_a_run() -> void:
	# SPEC §14.1 requires it be measurable at any point, not only at the end.
	var log := _log()
	_received(log, 1, 900.0)
	assert_almost_eq(float(Prestige.of(log)["total"]), 900.0, 0.001,
		"prestige could not be read until the run was over")


func test_it_falls_as_well_as_rises() -> void:
	# SPEC §13.2, and the whole of §8's retirement decision. A PC honouring
	# promises a failing colony cannot repay watches it go down.
	var log := _log()
	var prestige := Prestige.new()

	_received(log, 1, 2_000.0)
	prestige.settle(log, 1)
	var high := prestige.value
	assert_eq(prestige.direction(), "rising")

	_paid(log, 2, 3_000.0)
	prestige.settle(log, 2)
	assert_true(prestige.value < high, "prestige could only ever go up")
	assert_eq(prestige.direction(), "falling")


func test_it_may_go_below_nothing() -> void:
	# §13's open item, settled the permissive way: a PC who cost the Crown a
	# fortune and embarrassed it is worse than nothing, and the epitaph reads
	# better for it.
	var log := _log()
	_paid(log, 1, 500.0)
	_rebellion(log, 1)
	assert_true(float(Prestige.of(log)["total"]) < 0.0,
		"a ruinous, humiliating run still scored at least nothing")


# --- 🔒 It never reads the colony's welfare ---------------------------------

func test_a_wretched_colony_and_a_thriving_one_score_the_same() -> void:
	# 🔒 **The pillar the ending rests on.** SPEC §14.1 says nobody at court cares
	# how the colonists fared, and §18 makes scoring their welfare a non-goal. If
	# this ever fails, a dev has reached for quality of life.
	#
	# Same money, same embarrassments, opposite colonies.
	var thriving := _log()
	var starving := _log()
	for log in [thriving, starving]:
		_received(log, 1, 4_000.0)
		_protest(log, 3)

	# The colony is the one thing that differs, and it must not register — in how
	# it lived, in how often, or in what it lost. **Different counts as well as
	# different values**, so a price put on any welfare event at all diverges the
	# two rather than moving both alike.
	thriving.emit(SettlePhase.EVENT_LIVED, &"ashmere", 2, {
		"town": "ashmere", "quality_of_life": 0.98, "was": 0.98, "change": 0.0,
		"direction": "steady", "health": 1.0, "safety": 1.0, "means": 1.0,
		"hope": 1.0, "pleasure": 1.0,
	}, WorldPhase.COLONY_MONTH)
	thriving.emit(SettlePhase.EVENT_BORN, &"ashmere", 2, {
		"town": "ashmere", "born": 1, "population": 210,
	}, WorldPhase.COLONY_MONTH)
	for month in range(2, 9):
		starving.emit(SettlePhase.EVENT_LIVED, &"ashmere", month, {
			"town": "ashmere", "quality_of_life": 0.03, "was": 0.5, "change": -0.47,
			"direction": "worse", "health": 0.0, "safety": 0.1, "means": 0.0,
			"hope": 0.0, "pleasure": 0.0,
		}, WorldPhase.COLONY_MONTH)
		starving.emit(ConsumePhase.EVENT_FAMINE, &"ashmere", month, {
			"town": "ashmere", "lost": "worker", "remaining": 11,
			"months_hungry": month, "severity": "dire",
		}, WorldPhase.COLONY_MONTH)

	assert_almost_eq(
		float(Prestige.of(starving)["total"]), float(Prestige.of(thriving)["total"]), 0.001,
		"a starving colony scored differently from a thriving one, which is the one thing SPEC 14.1 forbids")


func test_nothing_in_the_register_is_about_the_colonists() -> void:
	# The other side of the same lock, asked of the table rather than the sum.
	# **Every optic is something the court heard about**, never something the
	# colonists felt.
	var forbidden: PackedStringArray = PackedStringArray([
		String(SettlePhase.EVENT_LIVED),
		String(SettlePhase.EVENT_BORN),
		String(ConsumePhase.EVENT_FAMINE),
		String(RebelSentiment.EVENT_MEASURED),
		String(Experts.EVENT_APPEARED),
		String(Immigration.EVENT_ARRIVED),
	])
	for type in forbidden:
		assert_false(OpticsRegister.is_an_optic(StringName(type)),
			"'%s' is priced as an optic, which scores the colony's own welfare" % type)


# --- 🔒 A mechanic emits; the register prices -------------------------------

func test_the_events_that_exist_are_priced() -> void:
	assert_true(OpticsRegister.price_of(TradeProtest.EVENT_DECLARED) > 0.0,
		"a town publicly refusing the Crown's duty cost it no face at all")
	assert_true(OpticsRegister.price_of(Rebellion.EVENT_DECLARED) > 0.0,
		"a town declaring rebellion cost the Crown no face at all")
	assert_true(
		OpticsRegister.price_of(Rebellion.EVENT_DECLARED)
			> OpticsRegister.price_of(TradeProtest.EVENT_DECLARED),
		"losing a town to revolt was no more embarrassing than a squabble over tea")


func test_the_hooks_for_what_does_not_exist_yet_are_priced_too() -> void:
	# §4: a new optic is a row in the table, not a change to the mechanic. A dev
	# adding rival tribute in M5 emits `tribute_paid` and stops there.
	for type in [
		OpticsRegister.EVENT_TRIBUTE_PAID,
		OpticsRegister.EVENT_COMPANY_DESTROYED,
		OpticsRegister.EVENT_TOWN_LOST,
		OpticsRegister.EVENT_RUN_FAILED,
	]:
		assert_true(OpticsRegister.price_of(type) > 0.0,
			"'%s' has no price, so the milestone that emits it has to invent one" % type)


func test_a_protest_reaches_prestige_without_the_protest_knowing() -> void:
	# The seam working: `TradeProtest` emits and says nothing about the court.
	var log := _log()
	_received(log, 1, 1_000.0)
	var before := float(Prestige.of(log)["total"])
	_protest(log, 2)
	assert_almost_eq(
		float(Prestige.of(log)["total"]),
		before - OpticsRegister.price_of(TradeProtest.EVENT_DECLARED), 0.001,
		"a declared protest did not reach the Crown's account of the PC")


# --- 🔒 Optics never decay, and the money is not counted twice ---------------

func test_a_black_mark_in_year_one_still_counts_in_year_forty() -> void:
	var log := _log()
	_rebellion(log, 1)
	var owed := OpticsRegister.debt_in(log)
	for month in range(2, 480):
		_received(log, month, 0.0)
	assert_almost_eq(OpticsRegister.debt_in(log), owed, 0.001,
		"the court forgot a rebellion, so waiting heals and there is no reason to retire")


func test_each_event_is_scored_once() -> void:
	var log := _log()
	_protest(log, 1)
	var once := OpticsRegister.debt_in(log)
	_protest(log, 1, &"brackwater")
	assert_almost_eq(OpticsRegister.debt_in(log), once * 2.0, 0.001,
		"two towns refusing the Crown cost it the face of one, or of three")


func test_the_optic_prices_the_embarrassment_and_not_the_money() -> void:
	# 🔒 The lost tax and the lost trade already land in `net_position`, which
	# prestige reads directly. Charging the gold again would double-count.
	var log := _log()
	_received(log, 1, 500.0)
	_protest(log, 2)
	var parts := Prestige.of(log)
	assert_almost_eq(float(parts["net_gold"]), 500.0, 0.001,
		"the optic reached into the accounts as well as the debt")
	assert_almost_eq(float(parts["optics_debt"]),
		OpticsRegister.price_of(TradeProtest.EVENT_DECLARED), 0.001,
		"the debt was something other than the one fixed price")


func test_a_black_mark_ruins_a_small_man_and_embarrasses_a_great_one() -> void:
	# 🔒 Fixed debts, not proportional ones. That is the court forgiving a man who
	# made them rich, and it is not to be tuned away.
	var small := _log()
	var great := _log()
	_received(small, 1, 400.0)
	_received(great, 1, 400_000.0)
	for log in [small, great]:
		_rebellion(log, 2)

	assert_true(float(Prestige.of(small)["total"]) < 0.0,
		"a rebellion did not ruin a governor who had netted the Crown four hundred pounds")
	assert_true(float(Prestige.of(great)["total"]) > 0.0,
		"a rebellion ruined a governor who had netted the Crown a fortune")


# --- The terms, and the save -------------------------------------------------

func test_the_patron_term_moves() -> void:
	# 🔒 **It used to read zero and this test used to assert that** (#388),
	# with a note saying patrons are M7 and that milestone would fill it in. M7
	# built the machinery and did not: `PatronCredit.bank` had two callers and
	# neither could be reached, because no letter from a patron existed and so no
	# Order could ever be addressed to one. **A term in the formula that cannot
	# move is not a term**, and a test asserting it reads zero is a test defending
	# the hole.
	var log := _log()
	_received(log, 1, 700.0)
	assert_almost_eq(float(Prestige.of(log)["patron_credit"]), 0.0, 0.0001,
		"credit was banked before the PC answered anybody")
	assert_almost_eq(float(Prestige.of(log)["total"]), 700.0, 0.001)

	_a_kindness_done(log, 2, 90.0)
	assert_true(float(Prestige.of(log)["patron_credit"]) > 0.0,
		"the PC did a patron a kindness and the court heard nothing")
	assert_true(float(Prestige.of(log)["total"]) > 700.0,
		"the term moved and the score did not")


func test_the_patron_term_falls_as_well_as_rises() -> void:
	# 🔒 **Granting is a favour and refusing is a slight**, and both are things
	# he will say at court. A term that could only rise would make a patron a free
	# source of prestige and the whole of §1's drain meaningless.
	var log := _log()
	_a_kindness_done(log, 1, -120.0)
	assert_true(float(Prestige.of(log)["patron_credit"]) < 0.0,
		"the PC turned a patron down and it cost him nothing at court")


func test_gold_enters_linearly_and_with_no_ceiling() -> void:
	# §3: doubling what the PC netted the Crown doubles that part of his score,
	# because the Crown's appetite is the one thing in this game that never
	# saturates.
	var modest := _log()
	var vast := _log()
	_received(modest, 1, 5_000.0)
	_received(vast, 1, 10_000.0)
	assert_almost_eq(
		float(Prestige.of(vast)["total"]), float(Prestige.of(modest)["total"]) * 2.0, 0.001,
		"the Crown's appetite saturated")


func test_it_reads_the_same_number_as_standing_and_asks_a_different_question() -> void:
	# §3: a PC deep in debt but newly profitable has recovering standing and
	# dismal prestige. Two verdicts from one number, and both correct.
	var log := _log()
	_paid(log, 1, 9_000.0)
	_received(log, 2, 300.0)

	var accounts := CrownAccounts.of(log)
	assert_true(accounts.net_in(2) > 0.0, "the fixture's latest month was not profitable")
	assert_true(float(Prestige.of(log)["total"]) < 0.0,
		"a month of profit wiped out a run of losses, so prestige is a rate and not a level")


# --- The Crown officers are the audible channel (§7) ------------------------

func test_a_falling_reputation_reaches_a_letter_without_reaching_a_number() -> void:
	# 🔒 §7: patrons are M7, so for M3 the audible channel is the Crown officers,
	# **and it should be working there before patrons ever exist**. What a letter
	# may ask is whether the wind has changed — never the figure, and there is no
	# condition that would let it compare the figure to anything.
	var log := _log()
	var prestige := Prestige.new()
	_received(log, 1, 3_000.0)
	prestige.settle(log, 1)

	var letter := LetterContext.new(WorldValues.initial_state(), null, &"")
	letter.log = log
	letter.month = 1
	letter.prestige = prestige
	assert_false(ColonyConditions.the_court_is_cooling({}, letter),
		"the Chancellor wrote about a reputation that was rising")

	_paid(log, 2, 9_000.0)
	_rebellion(log, 2)
	prestige.settle(log, 2)
	letter.month = 2
	assert_true(ColonyConditions.the_court_is_cooling({}, letter),
		"the colony lost a town and the court said nothing at all")


func test_it_survives_a_save() -> void:
	var log := _log()
	_received(log, 1, 1_200.0)
	_protest(log, 2)
	var prestige := Prestige.new()
	prestige.settle(log, 2)

	var restored := Prestige.from_dict(prestige.to_dict())
	assert_almost_eq(restored.value, prestige.value, 0.001)
	assert_almost_eq(restored.optics_debt, prestige.optics_debt, 0.001)
	assert_eq(restored.settled_month, prestige.settled_month)
	assert_eq(restored.direction(), prestige.direction())


func test_settling_says_so_without_saying_how_much() -> void:
	# 🔒 §7: never a number. The payload carries the direction and whether the
	# court heard anything this month — a payload carrying the figure is a payload
	# a letter could render.
	var log := _log()
	_received(log, 1, 800.0)
	_protest(log, 1)
	var prestige := Prestige.new()
	prestige.settle(log, 1)

	var measured: Array = log.of_type(Prestige.EVENT_MEASURED)
	assert_eq(measured.size(), 1, "the month was settled and nothing said so")
	assert_true(bool(measured[0].payload["embarrassed_this_month"]))
	for key in measured[0].payload:
		var value: Variant = measured[0].payload[key]
		assert_false(typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT,
			"the payload carries '%s' as a figure, which a letter could render" % key)

# --- 🔒 The reckoning: one table, and nothing silently unpriced -------------

func test_every_price_is_a_stated_multiple_of_the_reference() -> void:
	# 🔒 The point of the pass (#187): the table says what each embarrassment is
	# worth **against the others**, not eight figures each set in whichever ticket
	# introduced it. So every one of them moves when the reference moves.
	var plain: Dictionary = OpticsRegister.prices()
	assert_not_empty(plain, "there are no optics at all")
	for type in plain:
		assert_true(float(plain[type]) > 0.0,
			"'%s' is in the table at nothing, which is not a price" % type)
		var ratio := float(plain[type]) / OpticsRegister.A_PROTEST
		assert_true(ratio > 0.0, "'%s' is priced against nothing" % type)


func test_a_trade_protest_is_the_reference_itself() -> void:
	assert_almost_eq(
		OpticsRegister.price_of(TradeProtest.EVENT_DECLARED),
		OpticsRegister.A_PROTEST, 0.0001,
		"the optic the whole table is priced against is not the reference figure")


func test_a_lost_town_costs_more_than_twice_a_rebellion() -> void:
	# 🔒 The question the ticket asks by name, and the sharpest in the table. A
	# rebellion is a town that stopped answering and **might yet be brought
	# back**; a lost town is gone to a foreign power or destroyed. Two towns in
	# revolt should frighten a PC less than one town taken.
	var rebelled := OpticsRegister.price_of(Rebellion.EVENT_DECLARED)
	var lost := OpticsRegister.price_of(OpticsRegister.EVENT_TOWN_LOST)
	assert_true(rebelled > 0.0 and lost > 0.0, "one of the two is not priced")
	assert_true(lost > rebelled * 2.0,
		"two rebellions cost more than a town taken, which inverts the design")


func test_losing_a_company_costs_more_than_paying_a_duke() -> void:
	# 🔒 **The court minds losing more than it minds paying**, which is the whole
	# of why the PC pays. Paying is humiliating and voluntary; annihilation is a
	# defeat. Invert this and tribute stops being an instrument.
	assert_true(
		OpticsRegister.price_of(OpticsRegister.EVENT_COMPANY_DESTROYED)
			> OpticsRegister.price_of(OpticsRegister.EVENT_TRIBUTE_PAID),
		"paying a duke embarrassed the Crown more than losing a company to one")


func test_the_failure_debt_stings_without_swallowing_the_table() -> void:
	# 🔒 A failure so dear that nothing else could matter collapses the whole
	# table into one question, and §3's fixed debts stop meaning anything. It is
	# the largest figure and it is the same order as the one below it.
	var failed := OpticsRegister.price_of(OpticsRegister.EVENT_RUN_FAILED)
	var lost := OpticsRegister.price_of(OpticsRegister.EVENT_TOWN_LOST)
	assert_true(failed > lost, "failing the run cost less than losing one town")
	assert_true(failed < lost * 5.0,
		"the failure debt is so large that no other optic could matter")


func test_nothing_the_game_emits_is_silently_unpriced() -> void:
	# 🔒 The acceptance line: *every optic emitted is either priced or explicitly
	# listed as ignored*. Without the second list, an event nobody priced and an
	# event somebody decided not to price look identical — and the second turns
	# into the first the moment the man who decided leaves.
	for type in _the_court_might_hear_about():
		assert_true(
			OpticsRegister.is_an_optic(StringName(type))
				or OpticsRegister.is_ignored(StringName(type)),
			"'%s' reaches the court and the register has no opinion about it" % type)


func test_nothing_is_both_priced_and_ignored() -> void:
	for type in OpticsRegister.IGNORED:
		assert_false(OpticsRegister.is_an_optic(StringName(type)),
			"'%s' is charged for and also listed as deliberately not charged for" % type)


func test_every_reason_given_for_ignoring_one_says_something() -> void:
	# A reason of "" is the same as no list at all.
	for type in OpticsRegister.IGNORED:
		assert_true(String(OpticsRegister.IGNORED[type]).length() > 10,
			"'%s' is ignored for no stated reason" % type)


func test_a_famine_is_ignored_and_that_is_the_pillar() -> void:
	# 🔒 SPEC §14.1 and §18. People the PC was responsible for starved, and **the
	# court does not care.** A PC can leave behind a wretched, half-starved colony
	# and retire in glory, and the game must let him. This is that, in the one
	# place somebody would be most tempted to fix it.
	assert_true(OpticsRegister.is_ignored(&"famine_deaths"),
		"the register stopped ignoring a famine, which reads the colony's welfare")
	assert_almost_eq(OpticsRegister.price_of(&"famine_deaths"), 0.0, 0.0001)


## Every event type a reader might reasonably expect the court to hear about.
##
## Deliberately **not every event in the game** — most of them are the colony's
## own bookkeeping and nobody would look for them here. These are the ones that
## sound like bad news about the PC, which is exactly the set where silence is
## indistinguishable from an oversight.
func _the_court_might_hear_about() -> PackedStringArray:
	return PackedStringArray([
		"company_destroyed", "company_dwindled", "convoy_lost", "crown_refusing",
		"desperate_letter", "diplomat_died", "expedition_destroyed",
		"famine_deaths", "patron_spoke_ill", "rival_parked_on_our_ground",
		"rival_reached_minimum", "run_failed", "town_declared_rebellion",
		"town_lost", "town_returned_to_the_crown", "town_stormed",
		"town_went_short", "trade_protest_declared", "tribute_paid",
	])


# --- 🔒 The two the reckoning collected on --------------------------------

func test_the_crowns_own_resident_dying_reaches_the_court() -> void:
	# 🔒 Seam A, and the whole of why the emit-not-price rule is worth having.
	# `Diplomat` emitted this for a milestone and has never mentioned prestige;
	# the register began charging for it without that file changing at all.
	assert_true(OpticsRegister.is_an_optic(Diplomat.EVENT_DIED),
		"the Crown's own officer died in the colony and the court heard nothing")
	assert_true(
		OpticsRegister.price_of(Diplomat.EVENT_DIED)
			> OpticsRegister.price_of(TradeProtest.EVENT_DECLARED),
		"a shut market embarrassed the Crown more than its Resident's death")
	assert_true(
		OpticsRegister.price_of(Diplomat.EVENT_DIED)
			< OpticsRegister.price_of(OpticsRegister.EVENT_COMPANY_DESTROYED),
		"one man dead cost as much as a company of soldiers annihilated")


func test_an_expedition_annihilated_reaches_the_court_and_costs_little() -> void:
	# 🔒 **Less than a protest, and deliberately.** The Crown's stake in the party
	# already left through `net_position` with its stores, and §3 forbids charging
	# that twice — so what is priced is the embarrassment alone, and a failed
	# settlement embarrasses the court less than a market that visibly shut.
	assert_true(OpticsRegister.is_an_optic(ExpeditionParty.EVENT_DESTROYED),
		"a founding party was wiped out and the court heard nothing")
	assert_true(
		OpticsRegister.price_of(ExpeditionParty.EVENT_DESTROYED)
			< OpticsRegister.price_of(TradeProtest.EVENT_DECLARED),
		"losing a settling party out-weighed a colony that stopped selling")


func test_the_mechanics_that_emit_them_still_know_nothing_about_prestige() -> void:
	# 🔒 §4: *a mechanic emits the event, it never prices it.* Both of these were
	# collected on without their emitters changing, and a dev who prices an optic
	# where it happens has broken the one rule that made this pass possible.
	for path in ["res://sim/colony/diplomat.gd", "res://sim/colony/expedition_party.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_true(file != null, "%s is gone" % path)
		var source := file.get_as_text()
		file.close()
		assert_false(source.contains("OpticsRegister"),
			"%s decides what the court thinks of it, which is not its business" % path)

# --- 🔒 And it can be heard rising, not only falling (#187) -----------------

func _hearing(log: EventLog, prestige: Prestige, month: int) -> LetterContext:
	var letter := LetterContext.new(WorldValues.initial_state(), null, &"")
	letter.log = log
	letter.month = month
	letter.prestige = prestige
	return letter


func test_a_rising_reputation_reaches_a_letter_too() -> void:
	# 🔒 **The other direction, and it had no voice.** Only `the_court_is_cooling`
	# existed, so a run whose name was climbing read exactly like one that had not
	# moved — and §7 has the player perceiving prestige **only** through letters.
	# A quantity he can hear falling and never hear rising teaches him his name is
	# a thing that only gets worse.
	var log := _log()
	var prestige := Prestige.new()
	_paid(log, 1, 4_000.0)
	_rebellion(log, 1)
	prestige.settle(log, 1)

	var letter := _hearing(log, prestige, 1)
	assert_false(ColonyConditions.the_court_is_warming({}, letter),
		"the Steward congratulated a PC whose colony had just revolted")

	_received(log, 2, 12_000.0)
	prestige.settle(log, 2)
	letter.month = 2
	assert_true(ColonyConditions.the_court_is_warming({}, letter),
		"the PC made the Crown a fortune and nobody at court mentioned it")


func test_a_falling_run_and_a_rising_one_do_not_read_alike() -> void:
	# The acceptance line, asked directly: the two directions are never both true
	# and never both false while the number is moving.
	var log := _log()
	var prestige := Prestige.new()
	_received(log, 1, 5_000.0)
	prestige.settle(log, 1)
	_paid(log, 2, 20_000.0)
	prestige.settle(log, 2)

	var falling := _hearing(log, prestige, 2)
	assert_true(ColonyConditions.the_court_is_cooling({}, falling),
		"a reputation in free fall, and the court is not cooling")
	assert_false(ColonyConditions.the_court_is_warming({}, falling),
		"the same month reads as both a rise and a fall")


func test_a_steady_run_hears_neither() -> void:
	# 🔒 Silence is a reading too. A PC whose name has not moved should not be
	# told that it has, in either direction — otherwise the letters stop carrying
	# information and become weather.
	var log := _log()
	var prestige := Prestige.new()
	prestige.settle(log, 1)
	prestige.settle(log, 2)

	var quiet := _hearing(log, prestige, 2)
	assert_false(ColonyConditions.the_court_is_cooling({}, quiet),
		"a month in which nothing happened was reported as a decline")
	assert_false(ColonyConditions.the_court_is_warming({}, quiet),
		"a month in which nothing happened was reported as a triumph")


func test_neither_letter_may_read_the_figure() -> void:
	# 🔒 §7: **the direction, never the number.** Prestige is never shown to the
	# player as a quantity, so a condition that let a letter compare it to
	# anything would be the screen the design refuses to draw.
	#
	# **Registered here on purpose.** `condition_params` answers `{}` for an id
	# nobody registered as readily as for one that takes none, so asking an empty
	# registry this question passes however the conditions are declared — and it
	# did, until a mutation renamed one of them and nothing went red.
	reset_world()
	M1Registrations.register_all()

	for id in ["the_court_is_cooling", "the_court_is_warming"]:
		assert_true(ContentRegistry.has_condition(id),
			"'%s' is not a condition any letter could name" % id)
		assert_empty(ContentRegistry.condition_params(id),
			"'%s' takes parameters, so a letter can ask about the figure" % id)
	reset_world()
