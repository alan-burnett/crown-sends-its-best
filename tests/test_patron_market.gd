extends TestCase

## A patron's specialty names one kind, and his Barony's market can be turned
## toward the colony for it (#396, `patrons.md` §3, §10; `policy.md` §7, §8).
##
## 🔒 **A category names one kind**, drawn at arrival: what he ships, what he
## wants and which Crown price his market lifts are all fixed by the roll. And
## **he writes; the PC answers** — the market is a reply to a letter he sent.

const SEED: int = 396
const MARKET := "trigger.patron.his_barony_would_buy"

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


func _patron(specialty: String = "", kind: String = "") -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	patron.relationship = Relationship.new(patron.id, 60.0)
	if not specialty.is_empty():
		patron.specialty = specialty
		patron.specialty_kind = kind
	run.add_contact(patron)
	return patron


func _true_for(patron: Contact) -> bool:
	var director := machine.director
	return director._conditions_hold(content.collection("triggers")[MARKET], director._context(run, patron))


# --- 🔒 A category names one kind -----------------------------------------------------

func test_a_category_with_kinds_names_one_and_the_others_name_none() -> void:
	var seen: Dictionary = {}
	for index in 60:
		var patron := Patron.generate(StringName("patron_probe_%d" % index), run.streams, 0)
		for pair in [[patron.specialty, patron.specialty_kind], [patron.need, patron.need_kind]]:
			var category := String(pair[0])
			var kind := String(pair[1])
			seen[category] = true
			if Patron.kinds_of(category).is_empty():
				assert_eq(kind, "", "%s came in a kind" % category)
			else:
				assert_true(Patron.kinds_of(category).has(kind),
					"a %s patron's kind '%s' is not one of its kinds" % [category, kind])
	for category in ["resources", "livestock", "experts"]:
		assert_true(seen.has(category), "sixty patrons and none dealt in %s" % category)


func test_livestock_is_livestock_and_a_resource_is_not() -> void:
	for kind in Patron.kinds_of("livestock"):
		assert_true(ResourceCatalogue.is_livestock(StringName(kind)))
	for kind in Patron.kinds_of("resources"):
		assert_false(ResourceCatalogue.is_livestock(StringName(kind)))
	assert_empty(Patron.kinds_of("gold"))
	assert_empty(Patron.kinds_of("troops"))
	assert_empty(Patron.kinds_of("rivals"))


func test_the_same_seed_gives_the_same_kinds() -> void:
	var one := Patron.generate(&"patron_same", RngStreams.new(SEED), 0)
	var two := Patron.generate(&"patron_same", RngStreams.new(SEED), 0)
	assert_eq(one.specialty_kind, two.specialty_kind)
	assert_eq(one.need_kind, two.need_kind)


func test_the_kinds_survive_a_save() -> void:
	var patron := _patron("livestock", "horses")
	patron.need = "experts"
	patron.need_kind = "tobacco"
	var restored := Contact.from_data(patron.to_dict())
	assert_eq(restored.specialty_kind, "horses")
	assert_eq(restored.need_kind, "tobacco")


# --- 🔒 His Barony's market --------------------------------------------------------------

func test_a_horse_breeder_offers_his_market_and_a_gold_man_does_not() -> void:
	assert_true(_true_for(_patron("livestock", "horses")), "a horse breeder had no market to offer")
	assert_true(_true_for(_patron("resources", "sugar")), "a sugar man had no market to offer")
	assert_false(_true_for(_patron("gold", "")), "a patron dealing in gold offered a market")
	assert_false(_true_for(_patron("experts", "tobacco")), "an experts patron offered a Crown price")


func test_accepting_raises_the_crowns_price_for_his_kind() -> void:
	var patron := _patron("livestock", "horses")
	var director := machine.director
	var trigger: Dictionary = content.collection("triggers")[MARKET]
	var letter := Letter.from_record(content.record("letters", "patron.his_barony_would_buy"))
	var context := director._context(run, patron)
	context.params = director._inbound(trigger, letter, patron, context, run).params
	assert_eq(String(context.params.get("resource", "")), "horses", "the letter does not name his kind")

	var effect: Dictionary = {}
	for option in content.record("letters", "patron.his_barony_would_buy")["reply"]["steps"][0]["options"]:
		if String(option["id"]) == "all":
			effect = option["effect"]
	var order := ContentRegistry.run_effect("enact_policy_on", effect["enact_policy_on"], context)
	assert_true(order != null, "accepting produced no Order")

	var orders := OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	orders.policies = run.policies
	orders._enact_if_agreed(order, patron, {"outcome": String(Compliance.COMPLY)}, run.world, run.log)
	assert_eq(run.policies.held_by(patron.id).size(), 1, "he agreed and no market policy stands")

	var state := WorldValues.initial_state()
	var before := Valuation.crown(&"horses", state)
	var pressure := PolicyEffects.pressure(run.policies)
	for key in pressure:
		state.values[key] = float(pressure[key])
	assert_true(Valuation.crown(&"horses", state) > before,
		"his Barony bought horses and the Crown's price for them did not move")
	assert_false(_true_for(patron), "he offered a second market while carrying the first")
