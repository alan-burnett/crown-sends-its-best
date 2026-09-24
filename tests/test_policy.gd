extends TestCase

## How the Crown puts its thumb on the scale (#80,
## `docs/mechanics/policy.md`).
##
## 🔒 **A policy has an ongoing cost that somebody pays every month.** That is
## the whole of what separates it from an intent, which persists and costs
## nothing thereafter — and **who bears that bill is the whole of the mechanic**.
##
## 🔒 **Paying less never weakens it.** The policy does exactly what it does; the
## shortfall is borne by the enactor, in loyalty, every month. Underpaying is not
## a value-for-money calculation, it is a decision about a relationship.

const SEED: int = 4416

var content: ContentDatabase = null
var book: PolicyBook = null
var log: EventLog = null
var enactor: Contact = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	book = PolicyBook.new()
	log = EventLog.new()
	enactor = Contact.new(&"steward")
	enactor.relationship = Relationship.new(&"steward", 70.0)


func after_each() -> void:
	reset_world()
	content.free()


func _enact(split: StringName, cost: float = 100.0,
		effect: StringName = PolicyEffects.IMMIGRATION) -> Policy:
	return book.enact(Policy.new(&"steward", effect, cost, split), log, 3)


func _contacts() -> Dictionary:
	return {"steward": enactor}


func _state(month: int) -> WorldState:
	var state := WorldValues.initial_state()
	state.month = month
	return state


# --- 🔒 Somebody pays, every month -------------------------------------------

func test_the_crown_is_charged_for_what_it_agreed_to_bear() -> void:
	_enact(Policy.ALL, 120.0)
	assert_almost_eq(book.bill(_contacts(), log, 4), 120.0, 0.001,
		"the Crown bore the whole charge and paid nothing")


func test_half_is_half() -> void:
	_enact(Policy.HALF, 120.0)
	assert_almost_eq(book.bill(_contacts(), log, 4), 60.0, 0.001)


func test_paying_nothing_costs_the_treasury_nothing() -> void:
	_enact(Policy.NONE, 120.0)
	assert_almost_eq(book.bill(_contacts(), log, 4), 0.0, 0.001)


func test_it_is_charged_again_the_next_month() -> void:
	# **The line between a policy and an intent.** An intent persists and costs
	# nothing thereafter; this bills for as long as it stands.
	_enact(Policy.ALL, 50.0)
	var over_a_year := 0.0
	for month in range(4, 16):
		over_a_year += book.bill(_contacts(), log, month)
	assert_almost_eq(over_a_year, 600.0, 0.001,
		"a standing charge was charged once and then forgotten")


func test_the_charge_reaches_the_crowns_books() -> void:
	# A recurring charge the Ledger could not show would be the one commitment
	# the player never sees (§10).
	_enact(Policy.ALL, 120.0)
	book.bill(_contacts(), log, 4)
	assert_almost_eq(CrownAccounts.of(log).paid_in(4), 120.0, 0.001,
		"the Crown paid for a policy and its own books knew nothing about it")


# --- 🔒 The shortfall is borne in loyalty, not in effect ---------------------

func test_paying_in_full_costs_the_enactor_nothing() -> void:
	var before: float = enactor.relationship.loyalty
	_enact(Policy.ALL)
	book.bill(_contacts(), log, 4)
	assert_almost_eq(enactor.relationship.loyalty, before, 0.001,
		"a man whose policy the Crown funded entirely thought worse of it anyway")


func test_underpaying_drains_him_every_month() -> void:
	_enact(Policy.HALF)
	var after_one := 0.0
	var before: float = enactor.relationship.loyalty
	book.bill(_contacts(), log, 4)
	after_one = enactor.relationship.loyalty
	assert_true(after_one < before, "carrying half the charge cost him nothing")

	book.bill(_contacts(), log, 5)
	assert_true(enactor.relationship.loyalty < after_one,
		"it drained him once and then stopped")


func test_paying_nothing_costs_three_times_paying_half() -> void:
	# **Not twice. Three times.** People want to feel you are working with them,
	# and a PC who contributes something — even plainly not enough — is treated
	# very differently from one who contributes nothing and expects the thing
	# done anyway. §9 marks the 3× as design rather than tuning.
	assert_almost_eq(
		float(Policy.DRAIN[Policy.NONE]),
		float(Policy.DRAIN[Policy.HALF]) * 3.0,
		0.0001,
		"the cheapest lesson in the game was priced linearly")


func test_it_works_at_full_strength_however_little_is_paid() -> void:
	var funded := PolicyBook.new()
	funded.enact(Policy.new(&"steward", PolicyEffects.IMMIGRATION, 100.0, Policy.ALL), log, 3)
	var unfunded := PolicyBook.new()
	unfunded.enact(Policy.new(&"steward", PolicyEffects.IMMIGRATION, 100.0, Policy.NONE), log, 3)

	assert_almost_eq(
		float(PolicyEffects.pressure(funded).get(WorldValues.IMMIGRATION, 0.0)),
		float(PolicyEffects.pressure(unfunded).get(WorldValues.IMMIGRATION, 0.0)),
		0.0001,
		"paying nothing quietly weakened the policy instead of costing a man his regard")


# --- 🔒 It moves the world, including its prices ----------------------------

func test_a_policy_can_move_what_the_crown_pays() -> void:
	# §8: a patron whose specialty is horses can be persuaded to have his Barony
	# buy from your colony instead. The game expresses that as the Crown's price
	# for horses going up — through the same `Valuation.crown` function #136 cut
	# for a harvest failure.
	var state := _state(4)
	var before := Valuation.crown(&"horses", state)

	book.enact(Policy.new(&"steward", PolicyEffects.FAVOUR_OUR_MARKET, 80.0,
		Policy.ALL, {"resource": "horses"}), log, 3)
	for key in PolicyEffects.pressure(book):
		state.values[key] = float(PolicyEffects.pressure(book)[key])

	assert_true(Valuation.crown(&"horses", state) > before,
		"a patron turned his Barony to your colony and the price did not move")


func test_it_moves_only_what_it_names() -> void:
	var state := _state(4)
	# A quiet year, so the only thing that could move a price is the policy. The
	# Crown's war lifts what an army consumes (#141) and would otherwise answer
	# for the difference.
	state.values[WorldValues.WAR] = 0.0
	book.enact(Policy.new(&"steward", PolicyEffects.FAVOUR_OUR_MARKET, 80.0,
		Policy.ALL, {"resource": "horses"}), log, 3)
	for key in PolicyEffects.pressure(book):
		state.values[key] = float(PolicyEffects.pressure(book)[key])

	assert_almost_eq(Valuation.crown(&"furs", state), Valuation.crown(&"furs"), 0.0001,
		"a policy about horses moved the price of furs")


# --- 🔒 A market policy needs its market (#396) ------------------------------

## The Order a reply option produces, built the way the desk builds it.
func _proposed(effect_id: String, args: Dictionary) -> Order:
	var context := LetterContext.new(_state(3), enactor, Tone.DUTIFUL)
	return ContentRegistry.run_effect(effect_id, args, context)


func test_a_market_policy_with_no_market_is_refused() -> void:
	# It used to be enacted, charged every month, and press on nothing.
	assert_true(null == _proposed("enact_policy", {
		"to": "steward", "effect": "favour_our_market", "cost": 80, "split": "all",
	}), "a market policy with no market was enacted")
	assert_true(null != _proposed("enact_policy", {
		"to": "steward", "effect": "encourage_immigration", "cost": 80, "split": "all",
	}), "an ordinary policy stopped being enactable")


func test_the_target_survives_a_save() -> void:
	book.enact(Policy.new(&"steward", PolicyEffects.FAVOUR_OUR_MARKET, 80.0,
		Policy.ALL, {"resource": "horses"}), log, 3)
	var restored := PolicyBook.from_dict(book.to_dict())
	assert_eq(PolicyEffects.world_key(restored.active()[0]),
		PolicyEffects.world_key(book.active()[0]),
		"the market a policy was aimed at did not survive the save")


func test_pressure_is_recomputed_rather_than_accumulated() -> void:
	# A policy that ended should stop pressing **the month it ends**. A value
	# that had been added to would have to be subtracted from by somebody who
	# remembered to.
	var policy := _enact(Policy.ALL)
	assert_true(PolicyEffects.pressure(book).has(WorldValues.IMMIGRATION))
	book.lapse(policy.id, log, 6)
	assert_false(PolicyEffects.pressure(book).has(WorldValues.IMMIGRATION),
		"a policy that had ended went on pressing")


# --- 🔒 When the Crown stops paying -----------------------------------------

func test_a_bounced_draft_makes_every_policy_a_renegotiation() -> void:
	# §5: not a silent collapse. It puts the PC in the same position as if he had
	# written to each enactor saying he would now pay nothing, and each decides
	# for himself.
	var funded := _enact(Policy.ALL)
	var half := _enact(Policy.HALF)
	var shaken := book.crown_stopped_paying(log, 9)

	assert_eq(shaken.size(), 2, "only %d of two funded policies were shaken" % shaken.size())
	assert_eq(String(funded.split), String(Policy.NONE))
	assert_eq(String(half.split), String(Policy.NONE))
	assert_true(funded.renegotiating, "nobody was told the cheque had bounced")


func test_a_policy_already_unfunded_is_not_shaken_twice() -> void:
	_enact(Policy.NONE)
	assert_empty(book.crown_stopped_paying(log, 9),
		"a man already carrying the whole charge was told his funding had stopped")


func test_the_enactor_is_written_to() -> void:
	_enact(Policy.ALL)
	book.crown_stopped_paying(log, 9)
	assert_eq(log.of_type(PolicyBook.EVENT_RENEGOTIATING).size(), 1,
		"the PC's cheque bounced and nobody mentioned it")


func test_a_man_who_thinks_well_of_you_covers_it() -> void:
	# 🔒 **Your policies survive in proportion to how well you have treated
	# people.** §5 calls this one of the best things loyalty does, and it is the
	# difference between a PC losing his apparatus in a season and losing it over
	# a year he can do something about.
	enactor.relationship.loyalty = 90.0
	var policy := _enact(Policy.ALL)
	book.crown_stopped_paying(log, 9, _contacts())
	assert_false(policy.is_warning(),
		"a devoted man named the month he would stop instead of covering it")


func test_a_man_who_does_not_names_the_month_it_ends() -> void:
	enactor.relationship.loyalty = 10.0
	var policy := _enact(Policy.ALL)
	book.crown_stopped_paying(log, 9, _contacts())
	assert_true(policy.is_warning(),
		"a man who loathes the PC quietly carried his debts for him")
	assert_eq(policy.ends_month, 9 + PolicyBook.GRACE,
		"he ended it without the grace the warning promises")


func test_either_way_the_pc_finds_out() -> void:
	# A policy apparatus that unwound silently would be the one thing in the game
	# that happened to the player without a letter.
	for loyalty in [90.0, 10.0]:
		var fresh := PolicyBook.new()
		var man := Contact.new(&"steward")
		man.relationship = Relationship.new(&"steward", loyalty)
		var quiet := EventLog.new()
		fresh.enact(Policy.new(&"steward", PolicyEffects.IMMIGRATION, 100.0, Policy.ALL), quiet, 3)
		fresh.crown_stopped_paying(quiet, 9, {"steward": man})

		var state := WorldValues.initial_state()
		state.month = 9
		var context := LetterContext.new(state, man, &"dutiful")
		context.month = 9
		context.log = quiet
		context.policies = fresh
		assert_true(ColonyConditions.his_draft_was_returned({"within": 2}, context),
			"a man at loyalty %d said nothing about the bounced draft" % int(loyalty))


# --- 🔒 He writes before he stops -------------------------------------------

func test_he_carries_it_a_while_before_saying_anything() -> void:
	# An occasional lean month is not a crisis. A PC who is simply not paying
	# finds out inside a year.
	var policy := _enact(Policy.NONE)
	for month in range(4, 4 + PolicyBook.PATIENCE - 1):
		book.bill(_contacts(), log, month)
		book.take_stock(log, month)
	assert_false(policy.is_warning(),
		"he complained after %d months of carrying it" % (PolicyBook.PATIENCE - 1))


func test_eventually_he_says_he_will_not_go_on() -> void:
	var policy := _enact(Policy.NONE)
	for month in range(4, 4 + PolicyBook.PATIENCE + 1):
		book.bill(_contacts(), log, month)
		book.take_stock(log, month)
	assert_true(policy.is_warning(), "he carried it for ever without a word")
	assert_eq(log.of_type(PolicyBook.EVENT_WARNED).size(), 1,
		"he said it once a month instead of once")


func test_the_warning_always_comes_before_the_ending() -> void:
	# 🔒 **The same principle as the Chancellor's deadline.** A cost the player
	# cannot see coming is a trap, not a decision — so there is no month in which
	# a policy both first warns and ends.
	var policy := _enact(Policy.NONE)
	var warned_in := -1
	var ended_in := -1
	for month in range(4, 60):
		book.bill(_contacts(), log, month)
		var stock := book.take_stock(log, month)
		if not (stock["warned"] as Array).is_empty():
			warned_in = month
		if not (stock["ended"] as Array).is_empty():
			ended_in = month

	assert_true(warned_in > 0, "it never warned at all")
	assert_true(ended_in > warned_in,
		"it ended in month %d having warned in month %d" % [ended_in, warned_in])
	assert_true(ended_in - warned_in >= PolicyBook.GRACE,
		"the grace he gave was shorter than the grace he offered")
	assert_true(book.by_id(policy.id) == null, "it warned, ended, and stood anyway")


func test_a_funded_policy_never_warns() -> void:
	var policy := _enact(Policy.ALL)
	for month in range(4, 60):
		book.bill(_contacts(), log, month)
		book.take_stock(log, month)
	assert_false(policy.is_warning(), "a man being paid in full threatened to stop")
	assert_true(book.by_id(policy.id) != null, "a fully funded policy lapsed")


func test_paying_up_resets_everything() -> void:
	# **A policy made good is not a policy three months from lapsing**, or the PC
	# would have paid and watched it end anyway.
	var policy := _enact(Policy.NONE)
	for month in range(4, 4 + PolicyBook.PATIENCE + 1):
		book.bill(_contacts(), log, month)
		book.take_stock(log, month)
	assert_true(policy.is_warning())

	policy.made_good(Policy.ALL)
	assert_false(policy.is_warning(), "he was paid in full and went on threatening")
	assert_eq(policy.carried_months, 0, "he remembered months he was no longer carrying")

	for month in range(20, 60):
		book.bill(_contacts(), log, month)
		book.take_stock(log, month)
	assert_true(book.by_id(policy.id) != null, "a policy made good lapsed anyway")


func test_what_differs_between_half_and_nothing_is_his_regard() -> void:
	# The drain is three times at nothing, so the patience runs out at the same
	# count either way — **what differs is his regard**, which is the whole
	# lesson. Stated so that a future change making patience depend on the split
	# has to come past this test.
	var half := _enact(Policy.HALF)
	var none := PolicyBook.new()
	var other := Contact.new(&"marshal")
	other.relationship = Relationship.new(&"marshal", 70.0)
	none.enact(Policy.new(&"marshal", PolicyEffects.IMMIGRATION, 100.0, Policy.NONE), log, 3)

	for month in range(4, 4 + PolicyBook.PATIENCE):
		book.bill(_contacts(), log, month)
		none.bill({"marshal": other}, log, month)

	assert_true(other.relationship.loyalty < enactor.relationship.loyalty,
		"carrying the whole charge cost no more than carrying half of it")
	assert_eq(half.carried_months, PolicyBook.PATIENCE,
		"the months he carried it were not counted")


func test_the_letter_can_name_the_charge_and_the_deadline() -> void:
	var policy := _enact(Policy.NONE, 240.0)
	policy.warned_month = 10
	policy.ends_month = 13

	var state := WorldValues.initial_state()
	state.month = 11
	var context := LetterContext.new(state, enactor, &"dutiful")
	context.month = 11
	context.policies = book

	assert_true(ColonyConditions.will_not_carry_it_further({}, context),
		"a man three months from letting it lapse had nothing to say")
	assert_eq(int(ColonyParamSources.policy({"field": "cost"}, context)), 240)
	assert_eq(int(ColonyParamSources.policy({"field": "months"}, context)), 2)


func test_a_contented_enactor_writes_no_such_letter() -> void:
	_enact(Policy.ALL)
	var state := WorldValues.initial_state()
	state.month = 11
	var context := LetterContext.new(state, enactor, &"dutiful")
	context.month = 11
	context.policies = book
	assert_false(ColonyConditions.will_not_carry_it_further({}, context),
		"a man being paid in full wrote to complain about it")


# --- 🔒 Cancelling costs -----------------------------------------------------

func test_calling_one_off_costs_the_enactor() -> void:
	# **He put his name to the thing.** Men are appointed and dismissed over
	# these, and calling it off makes him look like a fool in front of people
	# whose opinion he minds a great deal more than he minds the PC's.
	var policy := _enact(Policy.ALL)
	var before: float = enactor.relationship.loyalty
	assert_true(book.cancel(policy.id, _contacts(), log, 8))
	assert_true(enactor.relationship.loyalty < before,
		"the PC called off a man's policy and he did not mind")
	assert_empty(book.active(), "the cancelled policy went on standing")


func test_he_remembers_being_made_a_fool_of() -> void:
	var policy := _enact(Policy.ALL, 400.0)
	book.cancel(policy.id, _contacts(), log, 8)
	var sore := enactor.relationship.most_recent_slight()
	assert_true(sore != null, "he forgot it the same month")
	assert_eq(String(sore.subject), String(PolicyEffects.IMMIGRATION))


# --- 🔒 It is not an intent and not an objective ----------------------------

func test_a_policy_names_no_project() -> void:
	# SPEC §8.5 locks that the PC cannot name a project, and a policy names none
	# — it is a rule the recipient follows until told otherwise.
	for id in PolicyEffects.ALL:
		assert_false(Building.find(StringName(id)) != null,
			"the policy effect '%s' is a project the PC may not name" % id)
		assert_false(GovernorIntent.is_intent(StringName(id)),
			"the policy effect '%s' is an intent wearing a policy's coat" % id)


func test_tax_rates_are_left_alone() -> void:
	# §1: tax rates are technically policy and are deliberately kept separate.
	# They have their own machinery in SPEC §10.2 and nothing here applies.
	for id in PolicyEffects.ALL:
		assert_false(String(id).contains("tax"),
			"a policy effect reached into the tax machinery")


# --- 🔒 It survives a reload -------------------------------------------------

func test_the_book_survives_a_round_trip() -> void:
	_enact(Policy.HALF, 120.0)
	book.enact(Policy.new(&"marshal", PolicyEffects.FAVOUR_OUR_MARKET, 80.0,
		Policy.NONE, {"resource": "guns"}), log, 5)

	var restored := PolicyBook.from_dict(book.to_dict())
	assert_eq(restored.active().size(), 2, "a reload forgot what the PC had taken on")
	assert_almost_eq(restored.bill({}, null, 9), book.bill({}, null, 9), 0.001,
		"the bill came back a different size")
	assert_eq(String(restored.active()[1].params.get("resource", "")), "guns")


# --- 🔒 The journalist's two (#279) -----------------------------------------
#
# `institutional-contacts.md` §3. **Neither policy is the trap.** What the PC
# must do to keep him loyal is the trap; what he gets for it is not, and neither
# of these is tuned down to compensate for one.

func test_public_relations_presses_where_governors_read() -> void:
	_enact(Policy.ALL, 100.0, PolicyEffects.PUBLIC_RELATIONS)
	var pressing := PolicyEffects.pressure(book)
	assert_has(pressing, PolicyEffects.PUBLIC_RELATIONS_KEY,
		"good press presses on nothing, so no governor will ever feel it")
	assert_true(float(pressing[PolicyEffects.PUBLIC_RELATIONS_KEY]) > 0.0,
		"a month of good press was worth nothing to anybody")


func test_public_relations_raises_a_governor_and_not_a_crown_officer() -> void:
	# 🔒 §3: it sways **public** opinion. A governor is the town's leader and its
	# voice; the Crown's officers are an ocean away and do not read the colony's
	# papers.
	# **Against each man's own ordinary drift**, not against a standing figure —
	# everybody moves a little every month anyway, and a test that compared
	# against a fixed number would be measuring the month rather than the policy.
	var quiet := _month_of_drift(false)
	var printed := _month_of_drift(true)

	assert_true(printed["governor"] > quiet["governor"],
		"a month of good press bought the governor nothing")
	assert_almost_eq(printed["steward"], quiet["steward"], 0.0001,
		"the Steward read the colony's newspapers")


## What one Reckoning does to a governor and to a Crown officer, with the press
## running or not.
func _month_of_drift(printing: bool) -> Dictionary:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var governor: Contact = run.contacts[String(run.colony.in_order()[0].governor_id)]
	var steward := run.contact(&"steward")
	var before := {"governor": governor.loyalty(), "steward": steward.loyalty()}

	if printing:
		run.world.values[PolicyEffects.PUBLIC_RELATIONS_KEY] = \
			PolicyEffects.PUBLIC_RELATIONS_LIFT
	DriftDriver.new(run).on_phase(
		WorldPhase.RECKONING, run.world, run.log, run.streams)

	return {
		"governor": governor.loyalty() - float(before["governor"]),
		"steward": steward.loyalty() - float(before["steward"]),
	}


func test_the_lift_is_worth_having_and_is_not_tuned_to_nothing() -> void:
	# 🔒 §3: **do not tune the benefits down to compensate for the trap.** A lift
	# smaller than the noise of an ordinary month would be a policy the player
	# pays for every month and cannot tell is running.
	assert_true(PolicyEffects.PUBLIC_RELATIONS_LIFT
			> LoyaltyDrift.MONTHLY_REACH * 0.25,
		"a month of good press is worth less than a quarter of an ordinary month's drift")


# --- 🔒 Crown Sentiment: a quarter off the rate, and the Crown still collects -

func test_crown_sentiment_presses_a_quarter_and_never_more_than_all_of_it() -> void:
	_enact(Policy.ALL, 100.0, PolicyEffects.CROWN_SENTIMENT)
	assert_almost_eq(
		float(PolicyEffects.pressure(book)[PolicyEffects.CROWN_SENTIMENT_KEY]),
		0.25, 0.0001,
		"it is a quarter of the rate, not some other share of it")

	# 🔒 No arrangement of policies may make a town grateful for being taxed.
	for round in 8:
		book.enact(Policy.new(
			&"steward", PolicyEffects.CROWN_SENTIMENT, 10.0, Policy.ALL), log, 3)
	assert_true(
		float(PolicyEffects.pressure(book)[PolicyEffects.CROWN_SENTIMENT_KEY]) <= 1.0,
		"enough policies talked a town out of more duty than it paid")
