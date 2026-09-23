extends TestCase

## Why should I be loyal to the Crown? (#126, SPEC §8.5,
## `docs/mechanics/contacts.md` §5.)
##
## 🔒 **Loyalty has two sources and neither alone works.** Deeds are memory —
## what the PC granted, refused, delivered, broke and ignored. Drift is the
## world — whether the things this contact judges the Crown by are going well.
##
## Deeds without drift means a contact is indifferent to a colony falling apart
## around him so long as the PC is polite. Drift without deeds means the PC's
## choices stop mattering, which is the game.

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


## A contact who judges the Crown by one thing, so a test can move that one
## thing and see what it does to him.
func _contact(cares: Array, loyalty: float = 50.0) -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.cares_about = PackedStringArray(cares)
	contact.relationship = Relationship.new(&"gov_ashmere", loyalty)
	return contact


## A measure at a given point of its own range, `0.0` worst to `1.0` best.
func _at(measure: String, where: float) -> Dictionary:
	# Walk the raw range until the normalised value lands where the test wants,
	# rather than assuming the normaliser is linear or knowing its bounds.
	var best := 0.0
	var closest := 1.0
	for step in 4001:
		var raw := -2_000.0 + float(step)
		var distance := absf(MeasureRegistry.normalize(measure, raw) - where)
		if distance < closest:
			closest = distance
			best = raw
	return {measure: best}


# --- 🔒 The world moves him -------------------------------------------------

func test_a_world_going_badly_costs_the_crown_his_regard() -> void:
	var contact := _contact(["colony_revenue"])
	assert_true(LoyaltyDrift.for_contact(contact, _at("colony_revenue", 0.0)) < 0.0,
		"a man who judges the Crown by its revenue thought no worse of it at nothing")


func test_a_world_going_well_earns_his_regard() -> void:
	var contact := _contact(["colony_revenue"])
	assert_true(LoyaltyDrift.for_contact(contact, _at("colony_revenue", 1.0)) > 0.0,
		"a man watching the Crown's business thrive thought no better of it")


func test_an_untouched_world_moves_nobody() -> void:
	# **The one case §5 allows.** A measure sitting at its middling value is not
	# news either way, and a contact with nothing happening to him and no
	# correspondence should hold exactly where he is.
	var contact := _contact(["colony_revenue"])
	assert_almost_eq(LoyaltyDrift.for_contact(contact, _at("colony_revenue", 0.5)), 0.0, 0.01,
		"a middling month quietly moved a man who had heard nothing from anybody")


func test_a_man_with_no_stake_does_not_drift() -> void:
	# Not a failure: a contact who judges the Crown by nothing is a man the PC's
	# letters are the only thing that will ever move.
	var contact := _contact([])
	assert_almost_eq(LoyaltyDrift.for_contact(contact, _at("colony_revenue", 0.0)), 0.0, 0.0001,
		"a man who cares about nothing took offence at something")


func test_he_is_only_moved_by_what_he_cares_about() -> void:
	var soldier := _contact(["crown_war_intensity"])
	var untouched := LoyaltyDrift.for_contact(soldier, _at("colony_revenue", 0.0))
	assert_almost_eq(untouched, 0.0, 0.0001,
		"a man who judges the Crown by its wars minded about its books")


func test_two_cares_are_averaged_rather_than_added() -> void:
	# A contact who cares about two things is not twice as moveable as one who
	# cares about one; he weighs them together.
	var single := _contact(["colony_revenue"])
	var double := _contact(["colony_revenue", "supply_situation"])
	var world := _at("colony_revenue", 0.0)
	world.merge(_at("supply_situation", 0.0))

	assert_almost_eq(
		LoyaltyDrift.for_contact(double, world),
		LoyaltyDrift.for_contact(single, world),
		0.05,
		"caring about two things going badly hurt twice as much as caring about one")


# --- 🔒 Drift and deeds are separate, and both move him ---------------------

func test_drift_does_not_look_like_a_deed() -> void:
	# **A deed is a thing the PC did.** Recording a bad winter among them would
	# have a contact remembering it as though the PC had refused him something,
	# and the letters read the deed counts back.
	var contact := _contact(["colony_revenue"], 60.0)
	contact.relationship.drift(-4.0)
	assert_true(contact.relationship.loyalty < 60.0, "drift did not move his regard")
	assert_empty(contact.relationship.deeds,
		"a bad month was written into the ledger of what the PC did")


func test_deeds_still_move_him() -> void:
	var contact := _contact(["colony_revenue"], 50.0)
	var before: float = contact.relationship.loyalty
	contact.relationship.record_deed(Relationship.GRANTED)
	assert_true(contact.relationship.loyalty > before,
		"drift replaced deeds instead of joining them")


func test_the_two_combine() -> void:
	var granted_only := _contact(["colony_revenue"], 50.0)
	granted_only.relationship.record_deed(Relationship.GRANTED)

	var granted_in_a_bad_year := _contact(["colony_revenue"], 50.0)
	granted_in_a_bad_year.relationship.record_deed(Relationship.GRANTED)
	granted_in_a_bad_year.relationship.drift(
		LoyaltyDrift.for_contact(granted_in_a_bad_year, _at("colony_revenue", 0.0)))

	assert_true(granted_in_a_bad_year.relationship.loyalty < granted_only.relationship.loyalty,
		"a favour granted in a collapsing colony was worth as much as one granted in a good year")


func test_the_balance_is_a_tuning_value() -> void:
	# Criterion: not a constant buried in a formula. It is the first thing to
	# reach for if the PC's letters start to feel weightless.
	assert_true(LoyaltyDrift.MONTHLY_REACH > 0.0)
	assert_true(LoyaltyDrift.MONTHLY_REACH < float(Relationship.DEED_WEIGHT[Relationship.GRANTED]),
		"a month of weather moved a man more than a favour did")


# --- 🔒 He can say what is wrong, never how wrong ---------------------------

func test_he_can_name_what_is_troubling_him() -> void:
	var contact := _contact(["colony_revenue", "crown_war_intensity"])
	var world := _at("colony_revenue", 0.5)
	world.merge(_at("crown_war_intensity", 1.0))
	assert_eq(LoyaltyDrift.loudest(contact, world), "crown_war_intensity",
		"he blamed the wrong thing for his mood")


func test_a_man_with_nothing_on_his_mind_names_nothing() -> void:
	assert_eq(LoyaltyDrift.loudest(_contact([]), {}), "",
		"a man who cares about nothing named something")


# --- 🔒 Deterministic ------------------------------------------------------

func test_the_same_month_moves_him_the_same_way_twice() -> void:
	var contact := _contact(["colony_revenue", "supply_situation"])
	var world := _at("colony_revenue", 0.2)
	world.merge(_at("supply_situation", 0.8))
	assert_almost_eq(
		LoyaltyDrift.for_contact(contact, world),
		LoyaltyDrift.for_contact(contact, world),
		0.0000001, "the same month read differently the second time")


func test_the_order_he_lists_his_cares_in_does_not_matter() -> void:
	var one := _contact(["colony_revenue", "supply_situation"])
	var other := _contact(["supply_situation", "colony_revenue"])
	var world := _at("colony_revenue", 0.2)
	world.merge(_at("supply_situation", 0.9))
	assert_almost_eq(
		LoyaltyDrift.for_contact(one, world),
		LoyaltyDrift.for_contact(other, world),
		0.0000001, "the order a contact's cares were written in changed his mind")
