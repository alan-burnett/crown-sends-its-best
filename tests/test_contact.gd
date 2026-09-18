extends TestCase

## The contact model, personality and Relationship (#12).

const CONSIDERATIONS: PackedStringArray = PackedStringArray([
	"native_threat", "quality_of_life", "revenue",
])


# --- Personality -----------------------------------------------------------

func test_same_seed_gives_the_same_contact() -> void:
	# The acceptance criterion: two contacts generated from the same seed have
	# identical personalities across runs.
	var first := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	var second := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	assert_eq(first.weights, second.weights)


func test_a_contact_is_unaffected_by_other_contacts() -> void:
	# Per-contact streams, so the same seed yields the same Marshal regardless of
	# how many contacts were created before him or in what order.
	var alone := RngStreams.new(7)
	var expected := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, alone, CONSIDERATIONS)

	var busy := RngStreams.new(7)
	Contact.generate(&"steward", Contact.ROLE_CROWN_OFFICER, busy, CONSIDERATIONS)
	Contact.generate(&"chancellor", Contact.ROLE_CROWN_OFFICER, busy, CONSIDERATIONS)
	busy.stream("sim").randi()
	var actual := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, busy, CONSIDERATIONS)

	assert_eq(actual.weights, expected.weights)


func test_different_contacts_have_different_personalities() -> void:
	var streams := RngStreams.new(7)
	var marshal := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, streams, CONSIDERATIONS)
	var steward := Contact.generate(&"steward", Contact.ROLE_CROWN_OFFICER, streams, CONSIDERATIONS)
	assert_ne(marshal.weights, steward.weights)


func test_generation_does_not_depend_on_the_order_of_the_list() -> void:
	var forwards := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	var shuffled := PackedStringArray(["revenue", "native_threat", "quality_of_life"])
	var backwards := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), shuffled)
	assert_eq(backwards.weights, forwards.weights)


func test_generated_weights_stay_in_range() -> void:
	var contact := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	for id in contact.weighted_ids():
		var weight := contact.weight_for(StringName(id))
		assert_true(weight >= Contact.WEIGHT_MIN and weight <= Contact.WEIGHT_MAX, "%s = %f" % [id, weight])


func test_personality_is_only_weights() -> void:
	# No contact has bespoke behavioural code: a contact is its weights, and the
	# kernel is the only thing that reads them.
	var contact := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	assert_true(contact is DeliberationActor)
	assert_almost_eq(contact.weight_for(&"a_consideration_added_next_milestone"), DeliberationActor.DEFAULT_WEIGHT)


# --- Loading fixed contacts ------------------------------------------------

func test_a_fixed_contact_loads_from_data() -> void:
	# Crown Officers are the same in every run and are not randomised, so adding
	# the Provost and the Diplomat later is a data file and no new code.
	var contact := Contact.from_data({
		"id": "chancellor",
		"name": "Lord Marrable",
		"title": "Chancellor of the Exchequer",
		"role": "crown_officer",
		"portrait": "portrait.chancellor",
		"loyalty": 12.0,
		"weights": {"revenue": 1.3},
		"leans": {"crown_war": -0.2},
		"cares_about": ["crown_standing"],
	})

	assert_eq(contact.id, &"chancellor")
	assert_eq(contact.display_name, "Lord Marrable")
	assert_eq(contact.role, Contact.ROLE_CROWN_OFFICER)
	assert_almost_eq(contact.loyalty(), 12.0, 0.001, "the Chancellor's low loyalty is data, not a special case")
	assert_almost_eq(contact.weight_for(&"revenue"), 1.3)
	assert_almost_eq(contact.lean_for("crown_war"), -0.2)


func test_the_portrait_is_an_asset_id_not_a_path() -> void:
	# SPEC §16.3: swapping placeholder art for final art must not require code
	# changes, so nothing outside the asset registry names a file path.
	var contact := Contact.from_data({"id": "marshal", "portrait": "portrait.marshal"})
	assert_false(contact.portrait_asset.contains("res://"))


func test_leans_are_clamped() -> void:
	var contact := Contact.from_data({"id": "x", "leans": {"topic": 4.0}})
	assert_almost_eq(contact.lean_for("topic"), 1.0)
	assert_almost_eq(contact.lean_for("never_mentioned"), 0.0, 0.001, "an honest reporter by default")


# --- Loyalty ---------------------------------------------------------------

func test_deeds_outweigh_words() -> void:
	# SPEC §8.5. Asserting the relationship between them, not the numbers: the
	# numbers are tuning and a test against a moving value would be rejected.
	var by_deed := Relationship.new(&"marshal")
	var by_tone := Relationship.new(&"marshal")

	var deed_move: float = absf(by_deed.record_deed(Relationship.GRANTED))
	var tone_move: float = absf(by_tone.record_tone(Tone.PLEASED))

	assert_true(deed_move > tone_move, "granting moved loyalty %f, tone moved %f" % [deed_move, tone_move])


func test_every_deed_outweighs_every_tone() -> void:
	for deed in Relationship.DEEDS:
		for tone in Tone.ALL:
			var deed_move: float = absf(float(Relationship.DEED_WEIGHT[deed]))
			var tone_move: float = absf(float(Relationship.TONE_WEIGHT[tone]))
			assert_true(deed_move > tone_move, "%s (%f) must outweigh %s (%f)" % [deed, deed_move, tone, tone_move])


func test_tone_is_a_table_not_a_scale() -> void:
	# The five tones are not ordered. Anything keyed on tone is a lookup, so
	# there is no "annoyed or worse" to be written by accident.
	for tone in Tone.ALL:
		assert_true(Relationship.TONE_WEIGHT.has(tone), "no entry for %s" % tone)
	assert_eq(Relationship.TONE_WEIGHT.size(), Tone.ALL.size())


func test_silence_has_its_own_effect() -> void:
	# SPEC §9.3: ignoring a request is a rude refusal, and costs loyalty.
	var relationship := Relationship.new(&"marshal")
	assert_true(relationship.record_deed(Relationship.IGNORED) < 0.0)


func test_loyalty_is_clamped_and_reports_what_really_happened() -> void:
	var relationship := Relationship.new(&"marshal", Relationship.MAX_LOYALTY)
	assert_almost_eq(relationship.record_deed(Relationship.DELIVERED), 0.0, 0.001, "already at the ceiling")
	assert_almost_eq(relationship.loyalty, Relationship.MAX_LOYALTY)


func test_a_bigger_deed_moves_loyalty_further() -> void:
	var small := Relationship.new(&"marshal")
	var large := Relationship.new(&"marshal")
	small.record_deed(Relationship.GRANTED, 0.5)
	large.record_deed(Relationship.GRANTED, 2.0)
	assert_true(large.loyalty > small.loyalty)


func test_deeds_are_counted() -> void:
	var relationship := Relationship.new(&"marshal")
	relationship.record_deed(Relationship.REFUSED)
	relationship.record_deed(Relationship.REFUSED)
	assert_eq(relationship.deed_count(Relationship.REFUSED), 2)
	assert_eq(relationship.deed_count(Relationship.GRANTED), 0)


# --- Promises --------------------------------------------------------------

func test_a_broken_promise_costs_loyalty() -> void:
	# Whether it broke through lack of means or a Crown refusal (SPEC §9.5, §10.3).
	var relationship := Relationship.new(&"marshal")
	relationship.add_promise("promise_1")
	var before := relationship.loyalty
	relationship.settle_promise("promise_1", false)
	assert_true(relationship.loyalty < before)
	assert_empty(relationship.outstanding_promises)


func test_a_kept_promise_is_a_delivery() -> void:
	var relationship := Relationship.new(&"marshal")
	relationship.add_promise("promise_1")
	var before := relationship.loyalty
	relationship.settle_promise("promise_1", true)
	assert_true(relationship.loyalty > before)


func test_promises_are_not_added_twice() -> void:
	var relationship := Relationship.new(&"marshal")
	relationship.add_promise("promise_1")
	relationship.add_promise("promise_1")
	assert_eq(relationship.outstanding_promises.size(), 1)


# --- Months silent ---------------------------------------------------------

func test_months_silent_is_derivable() -> void:
	# Feeds the `{sender:months_silent}` slot on the whitelist (#9).
	var relationship := Relationship.new(&"marshal")
	assert_eq(relationship.months_silent(5), 5, "never written to since the run began")

	relationship.note_letter_sent(4)
	assert_eq(relationship.months_silent(4), 0)
	assert_eq(relationship.months_silent(9), 5)


# --- Serialisation ---------------------------------------------------------

func test_relationship_survives_a_round_trip() -> void:
	var relationship := Relationship.new(&"marshal", 61.0)
	relationship.record_deed(Relationship.GRANTED)
	relationship.add_promise("promise_1")
	relationship.note_letter_sent(3)

	var restored := Relationship.from_dict(relationship.to_dict())
	assert_eq(restored.to_dict(), relationship.to_dict())
	assert_eq(restored.outstanding_promises, relationship.outstanding_promises)
	assert_almost_eq(restored.loyalty, relationship.loyalty)


func test_contact_survives_a_round_trip_with_its_relationship() -> void:
	var contact := Contact.generate(&"marshal", Contact.ROLE_CROWN_OFFICER, RngStreams.new(7), CONSIDERATIONS)
	contact.display_name = "Sir Aldous Vane"
	contact.relationship.record_deed(Relationship.PROMISE_BROKEN)
	contact.relationship.note_letter_sent(2)

	var restored := Contact.from_dict(contact.to_dict())
	assert_eq(restored.to_dict(), contact.to_dict())
	assert_eq(restored.weights, contact.weights)
	assert_almost_eq(restored.loyalty(), contact.loyalty())
