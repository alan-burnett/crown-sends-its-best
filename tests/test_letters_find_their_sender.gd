extends TestCase

## A letter's sender is a man or a role (#361).
##
## 🔒 **A named man first.** Every letter addressed to one particular office —
## the Chancellor, the Steward, the Marshal — resolves exactly as it always did.
##
## 🔒 **A role expands to everybody holding it**, each with his own context. That
## is what the folder layout always implied and what the director never did: six
## governor letters could never fire, two of them SPEC §12.3's whole rebellion
## arc, and sixteen more were bound to the capital's fixed id so no second town's
## governor wrote anything at all.
##
## 🔒 **And everything downstream keys by the man**, not by the string the letter
## file happened to carry — the cooldown, the one-letter-a-month rule, redundancy
## ranks, and whether he is still consulting the Crown.
##
## 🔒 **No new volume control.** `Threshold` already raises a man's bar for each
## further contact of a redundant role. It has simply never had a second governor
## to apply it to.

const SEED: int = 6611

var content: ContentDatabase = null
var director: Director = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	director = Director.new(content)


func after_each() -> void:
	reset_world()
	content.free()


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


## A second town, with a governor of its own — which is the whole case.
func _another_town(run: RunState, id: StringName, name: String) -> Contact:
	var town := Town.new(id, name, Vector2i(6, 6))
	town.workers = 12
	run.colony.add(town)
	var governor := Governor.generate(town, run.streams)
	town.governor_id = governor.id
	run.add_contact(governor)
	return governor


## A resident, who comes with the building that grants him (#277) and is
## therefore never in a fresh run either. A church raises a clergyman.
func _a_clergyman(run: RunState) -> Contact:
	var town: Town = run.colony.in_order()[0]
	if not town.buildings.has("church"):
		town.buildings.append("church")
	ContactRoster.house_the_residents(run)
	return run.contact(ContactRoster.resident_id(town, "clergyman"))


## A patron, who arrives from the Squeeze and is therefore never in a fresh run.
func _a_patron(run: RunState) -> Contact:
	var patron := Patron.generate(run.patrons.next_id(), run.streams, 0)
	run.add_contact(patron)
	return patron


func _letter(id: String) -> Letter:
	return Letter.from_record(content.record("letters", id))


func _governors(run: RunState) -> Array:
	var out: Array = []
	var ids: Array = run.contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = run.contacts[id]
		if contact != null and contact.role == Contact.ROLE_GOVERNOR:
			out.append(contact)
	return out


# --- 🔒 A named man first ---------------------------------------------------

func test_a_letter_addressed_to_one_office_still_finds_him() -> void:
	var run := _run()
	var found := director.senders_of(_letter("chancellor.how_to_answer"), run)
	assert_eq(found.size(), 1, "the Chancellor's letter found %d senders" % found.size())
	assert_eq(String((found[0] as Contact).id), "chancellor")


func test_a_sender_that_is_neither_a_man_nor_a_role_finds_nobody() -> void:
	# It used to be skipped in silence, and a letter that can never fire should
	# still be a letter that fires nothing rather than one that fires for
	# everybody.
	var run := _run()
	var letter := _letter("chancellor.how_to_answer")
	letter.sender = "nobody_at_all"
	assert_empty(director.senders_of(letter, run))


# --- 🔒 A role expands ------------------------------------------------------

func test_a_role_expands_to_everybody_holding_it() -> void:
	var run := _run()
	var governors := _governors(run)
	assert_false(governors.is_empty(), "the colony has no governors")

	var found := director.senders_of(_letter("governor.report_shortage"), run)
	assert_eq(found.size(), governors.size(),
		"%d governors and %d senders" % [governors.size(), found.size()])


func test_a_second_governor_is_a_sender_too() -> void:
	# 🔒 The heart of it. Before this, a second town's governor wrote nothing at
	# all — not a shortage, not an objective, not an acknowledgement of an order
	# the PC had sent him.
	var run := _run()
	var before := director.senders_of(_letter("governor.report_month"), run).size()

	var second := _another_town(run, &"riverbend", "Riverbend")
	assert_true(second != null)
	var after := director.senders_of(_letter("governor.report_month"), run)

	assert_eq(after.size(), before + 1, "a new governor was not a candidate")
	var ids := PackedStringArray()
	for entry in after:
		ids.append(String((entry as Contact).id))
	assert_true(ids.has(String(second.id)), "he is not among them: %s" % [ids])


func test_a_dead_man_writes_nothing() -> void:
	var run := _run()
	var governors := _governors(run)
	assert_false(governors.is_empty())
	(governors[0] as Contact).is_dead = true
	assert_eq(director.senders_of(_letter("governor.report_month"), run).size(),
		governors.size() - 1,
		"a dead governor was still a candidate")


func test_the_expansion_is_sorted() -> void:
	# Determinism: the same seed must offer the same candidates in the same
	# order, or the culling below them would differ between two runs of one seed.
	var run := _run()
	_another_town(run, &"zzz_end", "Zedford")
	_another_town(run, &"aaa_start", "Ardley")

	var ids := PackedStringArray()
	for entry in director.senders_of(_letter("governor.report_month"), run):
		ids.append(String((entry as Contact).id))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "the candidates came out unsorted: %s" % [ids])


# --- 🔒 Every governor letter can now fire ----------------------------------

func test_no_governor_letter_is_bound_to_the_capital_any_more() -> void:
	# 🔒 Sixteen of the twenty-two were `governor_ashmere`, which is the first
	# town's fixed id, and that is the only reason they ever fired.
	var stranded := PackedStringArray()
	for id in content.ids("letters"):
		var record: Dictionary = content.collection("letters")[id]
		if String(record.get("sender", "")).begins_with("governor_"):
			stranded.append(String(id))
	assert_empty(stranded,
		"a governor letter is still bound to one town: %s" % ", ".join(stranded))


func test_every_letter_that_ships_has_somebody_who_could_send_it() -> void:
	# 🔒 The measurement in #361, turned into a guard. Six letters could never
	# fire — including `town_has_declared` and `we_are_coming_back`, which are how
	# the player finds out a town has gone and come back.
	#
	# **A run with everybody in it who ever turns up**, not a run on its first
	# month. A patron arrives from the Squeeze rather than at founding (#388,
	# `patrons.md` §7), so a fresh colony has none — and the guard is about a
	# sender nobody could *ever* hold, not about who happens to be here in month
	# zero. Asking the empty run would have this fail for every role that arrives
	# later, which is most of them.
	var run := _run()
	_a_patron(run)
	_a_clergyman(run)
	var orphaned := PackedStringArray()
	for id in content.ids("letters"):
		var letter := _letter(String(id))
		if String(letter.sender).is_empty():
			continue
		if director.senders_of(letter, run).is_empty():
			orphaned.append("%s (sender %s)" % [id, letter.sender])
	assert_empty(orphaned,
		"letters nobody can send: %s" % ", ".join(orphaned))


func test_the_rebellion_letters_have_a_sender() -> void:
	# Named, because they are the ones that mattered: SPEC §12.3's whole arc had
	# never reached a desk.
	var run := _run()
	for id in ["governor.town_has_declared", "governor.we_are_coming_back"]:
		assert_false(director.senders_of(_letter(id), run).is_empty(),
			"%s still has nobody to send it" % id)


# --- 🔒 Downstream keys by the man ------------------------------------------

func test_the_cooldown_remembers_the_letter_and_the_man() -> void:
	# 🔒 Two governors both have a shortage to report. One reporting his must not
	# silence the other's for the length of the cooldown — it is the same letter
	# about a different town.
	assert_ne(Director.sent_key("governor.report_shortage", &"governor_one"),
		Director.sent_key("governor.report_shortage", &"governor_two"))
	assert_eq(Director.sent_key("a", &"b"), Director.sent_key("a", &"b"))


func test_what_the_director_records_is_keyed_that_way() -> void:
	var run := _run()
	_another_town(run, &"riverbend", "Riverbend")
	var sent: Array[InboundLetter] = []
	for month in range(1, 13):
		run.world.month = month
		run.turn = month
		sent.append_array(director.compose_inbox(run))
	assert_false(sent.is_empty(), "nothing was sent, so this proves nothing")
	for letter in sent:
		assert_has(run.letters_sent,
			Director.sent_key(letter.letter_id, letter.sender),
			"%s was recorded under something else" % letter.letter_id)


func test_an_inbound_carries_the_man_and_not_the_authored_string() -> void:
	# 🔒 Everything downstream keys by sender — the one-letter-a-month rule,
	# redundancy ranks, whether he is still consulting. With a role in that field
	# two governors would be one correspondent who wrote twice.
	var run := _run()
	_another_town(run, &"riverbend", "Riverbend")

	var from_a_role := 0
	for month in range(1, 13):
		run.world.month = month
		run.turn = month
		for letter in director.compose_inbox(run):
			assert_false(Contact.is_role(letter.sender),
				"%s came from a role rather than from a man" % letter.letter_id)
			assert_true(run.contact(letter.sender) != null,
				"%s came from nobody: %s" % [letter.letter_id, letter.sender])
			var authored := String(content.record(
				"letters", letter.letter_id).get("sender", ""))
			if Contact.is_role(StringName(authored)):
				from_a_role += 1
	assert_true(from_a_role > 0,
		"a year went by and no role-addressed letter was sent, so this proves nothing")


func test_two_men_sending_one_letter_do_not_share_an_id() -> void:
	var run := _run()
	_another_town(run, &"riverbend", "Riverbend")
	var seen: Dictionary = {}
	var sent := 0
	for month in range(1, 13):
		run.world.month = month
		run.turn = month
		for letter in director.compose_inbox(run):
			assert_false(seen.has(String(letter.id)),
				"two letters share the id %s" % letter.id)
			seen[String(letter.id)] = true
			sent += 1
	assert_true(sent > 0, "nothing was sent, so this proves nothing")


# --- 🔒 No new volume control -----------------------------------------------

func test_the_threshold_already_holds_a_crowd_back() -> void:
	# 🔒 #255 built this and it has never had a second governor to apply to. A
	# further contact of a redundant role has to mind more before he writes.
	assert_true(Threshold.crowds(Contact.ROLE_GOVERNOR),
		"governors are not a role the colony accumulates")
	assert_true(Threshold.redundancy_at(1) > Threshold.redundancy_at(0),
		"the second man of a role writes as readily as the first")
	assert_true(Threshold.redundancy_at(2) > Threshold.redundancy_at(1),
		"the third is no quieter than the second")


func test_the_director_added_no_volume_rule_of_its_own() -> void:
	# A second rule would be a second place the answer lived, and the first time
	# one was tuned the other would not know.
	var code := _code_of("res://correspondence/director/director.gd")
	for token in ["per_role", "role_cap", "at_most_per_role", "role_budget"]:
		assert_false(code.contains(token),
			"the director keeps a volume rule of its own: %s" % token)


func test_a_wide_colony_does_not_flood_the_desk() -> void:
	# Not a number — a shape. Four governors must not put four times the paper on
	# the desk, because the threshold rises for each of them.
	var narrow := _run()
	var one := director.compose_inbox(narrow).size()

	var wide := _run()
	for index in 3:
		_another_town(wide, StringName("town_%d" % index), "Town %d" % index)
	var many := Director.new(content)
	var four := many.compose_inbox(wide).size()

	assert_true(four >= one, "adding governors made the desk thinner")
	assert_true(four < one * 4,
		"four governors put %d letters on a desk one put %d on" % [four, one])


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)
