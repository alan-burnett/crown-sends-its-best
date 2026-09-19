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
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	book = PolicyBook.new()
	log = EventLog.new()
	enactor = Contact.new(&"steward")
	enactor.relationship = Relationship.new(&"steward", 70.0)


func after_each() -> void:
	ResourceCatalogue.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
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
	book.enact(Policy.new(&"steward", PolicyEffects.FAVOUR_OUR_MARKET, 80.0,
		Policy.ALL, {"resource": "horses"}), log, 3)
	for key in PolicyEffects.pressure(book):
		state.values[key] = float(PolicyEffects.pressure(book)[key])

	assert_almost_eq(Valuation.crown(&"furs", state), Valuation.crown(&"furs"), 0.0001,
		"a policy about horses moved the price of furs")


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
		assert_false(Objective.is_posture(StringName(id)),
			"the policy effect '%s' is a posture wearing a policy's coat" % id)
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
