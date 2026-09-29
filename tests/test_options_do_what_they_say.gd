extends TestCase

## A reply option does what its words say (#451, SPEC §9.2).
##
## 🔒 *Pay double* pays twice what *pay a fair price* pays. Both passed the same
## `{payment}`, so the Treasury's "twice over" was the fair price, and the choice
## the letter offered was one figure under two names.

const SEED: int = 451

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


## The Order a request_shipment option produces, at a fair price of `payment`.
func _order(option_id: String, payment: int) -> Order:
	var record: Dictionary = content.record("letters", "pc.request_shipment")
	var context := LetterContext.new(WorldValues.initial_state(), null, Tone.DUTIFUL)
	context.params = {"to": "governor_ashmere", "resource": "iron", "amount": 10, "payment": payment}
	for step in record["reply"]["steps"]:
		for option in step.get("options", []):
			if String(option.get("id", "")) != option_id:
				continue
			var effect: Dictionary = option["effect"]
			var id: String = effect.keys()[0]
			return ContentRegistry.run_effect(id, effect[id], context)
	return null


func test_pay_double_pays_twice_what_fair_pays() -> void:
	for fair_price in [50, 137, 4000]:
		var fair := _order("fair", fair_price)
		var double := _order("double", fair_price)
		assert_true(fair != null and double != null, "the letter lost an option")
		if fair == null or double == null:
			return
		assert_eq(String(double.kind), String(fair.kind), "doubling the price changed what was asked for")
		assert_eq(int(Compliance.payment_in(double)), 2 * int(Compliance.payment_in(fair)),
			"'pay double' paid %d where 'fair' paid %d" % [Compliance.payment_in(double), Compliance.payment_in(fair)])


func test_pay_nothing_pays_nothing() -> void:
	assert_eq(int(Compliance.payment_in(_order("nothing", 137))), 0)


func test_the_duty_on_tea_can_be_lowered() -> void:
	# 🔒 #452: tea could only go up, so a protest over tea could never be answered
	# with the one thing the protesters want.
	var record: Dictionary = content.record("letters", "steward.question_tea")
	var state := WorldValues.initial_state()
	var before := TaxRates.rate_for(state, &"tea")
	var context := LetterContext.new(state, null, Tone.DUTIFUL)
	var lowered := false
	for step in record["reply"]["steps"]:
		for option in step.get("options", []):
			var effect: Dictionary = option.get("effect", {})
			if not effect.has("set_tax_rate"):
				continue
			var order := ContentRegistry.run_effect("set_tax_rate", effect["set_tax_rate"], context)
			if order != null and float(order.get_param("rate", before)) < before:
				lowered = true
	assert_true(lowered, "the Steward's letter about tea offers no way to lower its duty")
