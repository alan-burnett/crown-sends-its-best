extends TestCase

## The Steward's rates (#452, `the-steward.md` §2, §4, SPEC §10.2, §9.4).
##
## 🔒 His push names the resource with the most gold changing hands last month,
## never a literal. 🔒 While the Crown is still paying the PC's debts he never
## refuses a tax order and never acts alone on it.

const SEED: int = 452

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
	run.world.month = 12


func after_each() -> void:
	reset_world()
	content.free()


func _traded(type: StringName, resource: String, month: int, gross: float) -> void:
	run.log.emit(type, &"ashmere", month, {"town": "ashmere", "resource": resource, "gross": gross},
		WorldPhase.COLONY_MONTH)


func _steward_context() -> LetterContext:
	return machine.director._context(run, run.contact(&"steward"))


# --- 🔒 His push ------------------------------------------------------------------

func test_his_push_names_the_most_traded_resource() -> void:
	assert_eq(String(ColonyParamSources.most_traded_resource({}, _steward_context())), "",
		"a colony that traded nothing had a most-traded resource")
	assert_false(ColonyConditions.the_colony_traded_last_month({}, _steward_context()))

	_traded(Trade.EVENT_SOLD, "iron", run.world.month - 1, 5000.0)  # not last month
	# Food leads only when its purchases and sales are counted together: iron
	# leads the purchases alone, and tools the sales alone.
	_traded(Trade.EVENT_BOUGHT, "food", run.world.month, 100.0)
	_traded(Trade.EVENT_SOLD, "food", run.world.month, 50.0)
	_traded(Trade.EVENT_BOUGHT, "iron", run.world.month, 130.0)
	_traded(Trade.EVENT_SOLD, "tools", run.world.month, 140.0)
	assert_eq(String(ColonyParamSources.most_traded_resource({}, _steward_context())), "food",
		"bought and sold were not counted together")

	var trigger: Dictionary = content.collection("triggers")["trigger.steward.request_tax_rise"]
	assert_eq(String(trigger["params"]["resource"].get("from", "")), "most_traded_resource",
		"his push still names a literal")


# --- 🔒 He never refuses a tax order while standing holds ---------------------------

func _blocked(decision: Decision) -> Dictionary:
	var out: Dictionary = {}
	for entry in decision.entries:
		if String((entry as Dictionary).get("filtered_by", "")) == "the_steward_follows_a_tax_order":
			out[String(entry["id"])] = true
	return out


func _answer(to: Contact, loyalty: float, crown_pays: bool) -> Decision:
	to.relationship.loyalty = loyalty
	var order := Order.new(M1Registrations.ORDER_SET_TAX_RATE, to.id, {
		"to": String(to.id), "resource": "tea", "key": TaxRates.key_for(&"tea"), "rate": 0.0,
	}, run.world.month)
	return Compliance.resolve(order, to, run.intents, run.world, run.log, run.streams, null, crown_pays)["decision"]


func test_while_the_crown_pays_he_never_refuses_or_acts_alone() -> void:
	var steward := run.contact(&"steward")
	var holding := _blocked(_answer(steward, 5.0, true))
	assert_true(holding.has("refuse") and holding.has("act_alone"),
		"a Steward whose Crown still pays could refuse or ignore a tax order")

	var lost_but_loyal := _blocked(_answer(steward, 60.0, false))
	assert_false(lost_but_loyal.has("refuse"), "once the Crown refuses payments, so may he")
	assert_true(lost_but_loyal.has("act_alone"), "a Steward who still thinks well of the PC acted alone")

	var lost_and_sour := _blocked(_answer(steward, 5.0, false))
	assert_false(lost_and_sour.has("act_alone"), "standing lost and his regard low, and he could not act alone")

	var governor := run.contact(run.colony.in_order()[0].governor_id)
	assert_true(_blocked(_answer(governor, 5.0, true)).is_empty(), "the rule reached a man who is not the Steward")
