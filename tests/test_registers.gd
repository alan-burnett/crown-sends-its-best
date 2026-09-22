extends TestCase

## A tuner personality writes a tone per letter kind (#317, `docs/mechanics/tone.md`
## §3, §5, §8, §9).
##
## 🔒 **Five tones times harsh-or-not is ten registers, and zero had evidence.**
## A personality carried one tone for a whole run and could not say *harsh* at
## all, so across 942 scorings every tone consideration and harshness read
## `0.0000` — the whole axis built and nothing exercising it.
##
## 🔒 **And one tone per run cannot measure it.** Answering has no compliance
## step, so a personality that writes `desperate` on everything is not the
## pleader — it is a **worse** pleader than one that pleads only where pleading
## buys something. Every extreme-tone personality has a naive version and a
## skilled version, and the harness could build only the naive one.

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	content.free()


func _letter(id: String) -> Letter:
	return Letter.from_record(content.record("letters", id))


func _policies() -> Dictionary:
	var out: Dictionary = {}
	for id in content.ids("balance"):
		out[String(id)] = content.record("balance", String(id))
	return out


# --- 🔒 A letter knows which of the three kinds it is -----------------------

func test_every_letter_with_a_reply_is_one_of_the_three_kinds() -> void:
	var seen: Dictionary = {}
	for id in content.ids("letters"):
		var letter := _letter(String(id))
		if not letter.has_reply():
			continue
		var kind := LetterKind.of_letter(letter)
		assert_true(LetterKind.ALL.has(kind),
			"%s is of no kind at all, so no register can reach it" % id)
		seen[String(kind)] = int(seen.get(String(kind), 0)) + 1

	# All three must actually occur, or a register keys on a kind nothing is.
	for kind in LetterKind.ALL:
		assert_true(int(seen.get(String(kind), 0)) > 0,
			"no letter in the corpus is %s, so that register is unreachable: %s"
				% [kind, seen])


func test_the_strongest_claim_in_a_letter_decides_its_kind() -> void:
	# A reply that mixes an answer with an instruction is an instruction, and one
	# that asks for something is an ask. Nothing in a letter file says which kind
	# it is, and nothing should.
	for id in content.ids("letters"):
		var letter := _letter(String(id))
		if not letter.has_reply():
			continue
		var kind := LetterKind.of_letter(letter)
		if kind != LetterKind.ANSWERING:
			assert_true(LetterKind.may_be_harsh(letter),
				"%s orders something and yet cannot be leaned on" % id)
		else:
			assert_false(LetterKind.may_be_harsh(letter),
				"%s orders nothing and yet can be leaned on" % id)


func test_a_letter_that_orders_nothing_is_answering() -> void:
	# The floor: the PC is the only person doing anything.
	var letter := Letter.from_record({
		"id": "test.nothing", "sender": "marshal", "type": "report",
		"body": [{"text": "A line."}],
		"reply": {"steps": [{"id": "s", "prompt": "p", "options": [
			{"id": "a", "label": "a", "text": "a"},
		]}], "closing": [{"text": "Yours,"}]},
	})
	assert_eq(LetterKind.of_letter(letter), LetterKind.ANSWERING)
	assert_eq(LetterKind.of_letter(null), LetterKind.ANSWERING)


# --- 🔒 The personalities exercise the registers ----------------------------

func test_the_corpus_of_personalities_reaches_every_tone() -> void:
	# The acceptance: the CSV can only show a tone a batch used.
	var written: Dictionary = {}
	for id in _policies():
		var policy: Dictionary = _policies()[id]
		for kind in policy.get("registers", {}):
			written[String((policy["registers"][kind] as Dictionary).get("tone", ""))] = true
		if policy.has("tone"):
			written[String(policy["tone"])] = true

	for tone in Tone.ALL:
		assert_true(written.has(String(tone)),
			"no reference player ever writes %s, so that register has no evidence: %s"
				% [tone, written.keys()])


func test_some_personality_leans_on_people() -> void:
	var leans := false
	for id in _policies():
		for kind in (_policies()[id] as Dictionary).get("registers", {}):
			if bool(((_policies()[id]["registers"][kind]) as Dictionary).get("harsh", false)):
				leans = true
	assert_true(leans,
		"no reference player ever writes a threat, so harshness has no evidence")


func test_the_naive_and_the_skilled_pleader_differ_only_where_it_is_free() -> void:
	# 🔒 §3, stated as the pair the ticket asks for. They plead identically where
	# there is a compliance step to move, and differ only on answering — where
	# the plea buys nothing and costs a loyalty step and an undecaying mark.
	var naive: Dictionary = _policies()["pleader_naive"]["registers"]
	var skilled: Dictionary = _policies()["pleader_skilled"]["registers"]

	for kind in [LetterKind.DIRECTING, LetterKind.ASKING]:
		assert_eq(
			String((naive[String(kind)] as Dictionary)["tone"]),
			String((skilled[String(kind)] as Dictionary)["tone"]),
			"the two pleaders differ on %s, so the pair measures more than §3" % kind)
	assert_ne(
		String((naive[String(LetterKind.ANSWERING)] as Dictionary)["tone"]),
		String((skilled[String(LetterKind.ANSWERING)] as Dictionary)["tone"]),
		"the two pleaders answer alike, so there is no pair")


# --- 🔒 What the validator now refuses --------------------------------------

func _check(registers: Dictionary) -> ContentValidator:
	var db := ContentDatabase.new()
	db.load_all("en")
	db.collection("balance").clear()
	db.collection("balance")["made_up"] = {
		"id": "made_up",
		"_source_file": "res://data/balance/policies.json",
		"prefer": [],
		"registers": registers,
	}
	var validator := ContentValidator.new()
	validator.check_balance_policies(db)
	db.free()
	return validator


func _said(validator: ContentValidator) -> String:
	var out: PackedStringArray = PackedStringArray()
	for problem in validator.problems:
		out.append("%s %s" % [problem.path, problem.message])
	return " | ".join(out)


func test_a_register_in_a_tone_that_does_not_exist_is_refused() -> void:
	var validator := _check({"directing": {"tone": "furious"}})
	assert_false(validator.ok(), "a personality wrote in a sixth tone and nothing minded")
	assert_true(_said(validator).contains("furious"), _said(validator))


func test_a_register_for_a_kind_that_does_not_exist_is_refused() -> void:
	var validator := _check({"shouting": {"tone": "annoyed"}})
	assert_false(validator.ok(), "a personality keyed on a fourth kind of letter")
	assert_true(_said(validator).contains("shouting"), _said(validator))


func test_leaning_on_a_man_about_your_own_decision_is_refused() -> void:
	# 🔒 §9 does not offer harshness when answering — there is nothing to lean on.
	# The wizard refuses it silently, and a silently refused request is how this
	# ticket's whole class of bug happens.
	var validator := _check({"answering": {"tone": "hateful", "harsh": true}})
	assert_false(validator.ok(),
		"a personality asked to lean on a man about a decision the PC had made")
	assert_true(_said(validator).contains("answering"), _said(validator))


func test_the_shipped_personalities_all_pass() -> void:
	var db := ContentDatabase.new()
	db.load_all("en")
	var validator := ContentValidator.new()
	validator.check_balance_policies(db)
	assert_true(validator.ok(), _said(validator))
	db.free()


func test_a_personality_with_no_registers_still_plays() -> void:
	# Every policy written before this must play exactly as it did, because the
	# batches they produced are the baseline the new ones are read against.
	var validator := _check({})
	assert_true(validator.ok(), _said(validator))
	assert_true(_policies().has("steady"), "the plain reference player is gone")
	assert_false((_policies()["steady"] as Dictionary).has("registers"),
		"the plain reference player has been given registers, so the baseline moved")
