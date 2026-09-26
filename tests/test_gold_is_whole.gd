extends TestCase

## Gold on the desk is whole gold, and a promise of none is not offered (#460).
##
## 🔒 **Every numeric param a letter declares reaches the director whole.** The
## director coerces `gold` and `integer` params to integers; a fractional figure
## used to come out as nought, so a patron asked for 0 gold at three sizes of the
## Squeeze in four.
##
## 🔒 **A promise of no gold gives nothing**: it is never offered, and one that
## reached a man anyway earns no gratitude, no memory and no promise to keep.

const SEED: int = 460

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


func _at_size(level: int) -> void:
	run.demands.levels[String(DemandGrowth.SIZE)] = level


func _patron() -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, 60.0)
	run.add_contact(patron)
	return patron


# --- 🔒 Whole gold ----------------------------------------------------------------------------

func test_a_patrons_ask_is_a_positive_whole_number_at_every_size() -> void:
	var context := machine.director._context(run, _patron())
	for level in 13:
		_at_size(level)
		var ask: Variant = ColonyParamSources.patron_ask({}, context)
		assert_eq(typeof(ask), TYPE_INT, "the ask at size %d is not whole" % level)
		assert_true(int(ask) > 0, "a patron asked for nothing at size %d" % level)
		assert_almost_eq(float(ask), DemandSchedule.gold_target(run.demands) * ColonyParamSources.PATRON_ASK_SHARE,
			0.51, "the ask at size %d is not the ask" % level)


func test_a_dukes_tribute_is_a_positive_whole_number_at_every_size_and_band() -> void:
	run.demands.sources.append(String(DemandGrowth.SOURCE_DUKE))
	var duke: Contact = RivalDuke.arrived_in(run, run.demands)[0]
	for loyalty in range(0, 101, 5):
		duke.relationship.loyalty = float(loyalty)
		var context := machine.director._context(run, duke)
		for level in 9:
			_at_size(level)
			var tribute: Variant = ColonyParamSources.tribute_amount({}, context)
			assert_eq(typeof(tribute), TYPE_INT, "the tribute at size %d, regard %d is not whole" % [level, loyalty])
			assert_true(int(tribute) > 0)


func test_every_numeric_param_a_trigger_supplies_is_whole_at_every_size() -> void:
	# Everybody who could be asked: a patron, and dukes arrived.
	_patron()
	for _index in 2:
		run.demands.sources.append(String(DemandGrowth.SOURCE_DUKE))
	var director := machine.director
	var checked := 0
	for level in [0, 1, 2, 3, 5, 7]:
		_at_size(level)
		for trigger_id in content.ids("triggers"):
			var trigger: Dictionary = content.collection("triggers")[trigger_id]
			var letter_id := String(trigger.get("letter", ""))
			if letter_id.is_empty() or not content.has_record("letters", letter_id):
				continue
			var declared: Dictionary = content.record("letters", letter_id).get("params", {})
			var letter := Letter.from_record(content.record("letters", letter_id))
			var senders := director.senders_of(letter, run)
			var sender: Contact = senders[0] if not senders.is_empty() else run.contact(&"steward")
			var context := director._context(run, sender)
			for name in (trigger.get("params", {}) as Dictionary):
				if not LetterSchema.NUMERIC_PARAM_TYPES.has(StringName(declared.get(name, ""))):
					continue
				var spec: Variant = trigger["params"][name]
				if typeof(spec) != TYPE_DICTIONARY or not (spec as Dictionary).has("from"):
					continue
				var args: Dictionary = (spec as Dictionary).duplicate()
				var source := String(args["from"])
				args.erase("from")
				var value: Variant = ContentRegistry.supply_param(source, args, context)
				checked += 1
				# A literal comes as its text, which the coercion reads when whole.
				var whole := typeof(value) == TYPE_INT \
					or (typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value)))) \
					or (typeof(value) == TYPE_STRING and String(value).is_valid_int())
				assert_true(whole, "%s.%s from '%s' is %s at size %d" % [trigger_id, name, source, value, level])
	assert_true(checked > 20, "only %d numeric params were checked, so this proves little" % checked)


func test_a_fractional_figure_rounds_rather_than_vanishing() -> void:
	# Still a defect, and it still says so; but never a demand for no gold.
	assert_eq(JsonTypes.to_int(12.0, "whole"), 12)


# --- 🔒 A promise of no gold -------------------------------------------------------------------

func _pay_option_offered(amount: int) -> bool:
	var patron := _patron()
	var letter := Letter.from_record(content.record("letters", "patron.request_gold"))
	var wizard := ReplyWizard.new(letter)
	var context := machine.director._context(run, patron)
	context.params = {"patron": String(patron.id), "amount": amount}
	for option in wizard.options_for(0, context):
		if String(option["id"]) == "pay":
			return true
	return false


func test_a_promise_of_no_gold_is_never_offered() -> void:
	assert_true(_pay_option_offered(120), "a real sum was not offered, so this proves nothing")
	assert_false(_pay_option_offered(0), "the PC was offered a promise of no gold")


func test_a_promise_of_no_gold_earns_nothing() -> void:
	var patron := _patron()
	var before := patron.relationship.loyalty
	var order := Order.new(M1Registrations.ORDER_PROMISE_GOLD, patron.id, {"to": String(patron.id), "amount": 0})
	order.tone = Tone.DUTIFUL
	assert_true(PromiseBook.from_order(order, 1) == null, "a promise of no gold is a promise to keep")
	Compliance.resolve(order, patron, run.intents, run.world, run.log, run.streams)
	assert_almost_eq(patron.relationship.loyalty, before, 0.0001, "he was grateful for nothing")
	assert_empty(patron.relationship.history, "he remembers being given nothing")
	assert_almost_eq(float(Prestige.of(run.log)["patron_credit"]), 0.0, 0.0001, "the court heard of a gift of nothing")
