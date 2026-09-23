extends TestCase

## What a contact remembers, as opposed to how often
## (#127, `docs/mechanics/contacts.md` §6).
##
## 🔒 **Counts answer *how often*. They cannot answer *what*.** A tally can tell
## a letter the PC has been generous four times; it cannot let a governor say
## *"Your Grace was good enough to send two hundred measures of iron in the
## spring, when we had none."*
##
## 🔒 **It is always true.** Naming a real past event is a fact about the past,
## which SPEC §9.1 requires letters to get right. The bias lives in *which* event
## a contact reaches for — one man the last kindness, a sourer one the last
## slight — and that is framing, which §9.1 allows.

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


func _contact(loyalty: float = 50.0) -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.relationship = Relationship.new(&"gov_ashmere", loyalty)
	return contact


func _context(sender: Contact, month: int) -> LetterContext:
	var state := WorldValues.initial_state()
	state.month = month
	var context := LetterContext.new(state, sender, &"dutiful")
	context.month = month
	return context


# --- 🔒 It can name the thing -----------------------------------------------

func test_a_contact_can_name_what_was_sent_and_when() -> void:
	# The sentence §6 asks for, in its parts. The letter builds the sentence;
	# **a stored string would be one no translation could reach**.
	var governor := _contact()
	governor.relationship.remember(Relationship.GRANTED, 4, 200.0, "iron")
	var context := _context(governor, 10)

	assert_eq(int(ColonyParamSources.recalled(
		{"reach": "kindness", "field": "amount"}, context)), 200)
	assert_eq(String(ColonyParamSources.recalled(
		{"reach": "kindness", "field": "resource"}, context)), "iron")
	assert_eq(int(ColonyParamSources.recalled(
		{"reach": "kindness", "field": "months_ago"}, context)), 6)


func test_nothing_is_named_when_there_is_nothing_to_name() -> void:
	# A letter that described a generosity which never happened would break SPEC
	# §9.1, so an empty memory answers emptily and the condition keeps the letter
	# from firing at all.
	var stranger := _contact()
	var context := _context(stranger, 10)
	assert_eq(int(ColonyParamSources.recalled(
		{"reach": "kindness", "field": "amount"}, context)), 0)
	assert_false(ColonyConditions.remembers_a_kindness({}, context),
		"a contact with no history was ready to reminisce")


func test_the_letter_only_fires_when_there_is_something_true_to_say() -> void:
	var governor := _contact()
	var context := _context(governor, 10)
	assert_false(ColonyConditions.remembers_a_kindness({}, context))

	governor.relationship.remember(Relationship.GRANTED, 4, 200.0, "iron")
	assert_true(ColonyConditions.remembers_a_kindness({}, context),
		"a governor with two hundred iron in his memory had nothing to say about it")


func test_a_kindness_with_no_subject_is_not_worth_naming() -> void:
	# "You were good enough to send 0 of  " is worse than not writing.
	var governor := _contact()
	governor.relationship.remember(Relationship.GRANTED, 4, 0.0, "")
	assert_false(ColonyConditions.remembers_a_kindness({}, _context(governor, 10)),
		"a contact offered to describe a kindness he could not describe")


# --- 🔒 What he reaches for ------------------------------------------------

func test_he_leads_with_the_largest_kindness() -> void:
	var governor := _contact()
	governor.relationship.remember(Relationship.GRANTED, 2, 20.0, "wood")
	governor.relationship.remember(Relationship.GRANTED, 6, 200.0, "iron")
	governor.relationship.remember(Relationship.GRANTED, 9, 40.0, "stone")

	var memory := governor.relationship.most_generous()
	assert_eq(String(memory.subject), "iron", "he reached for the smaller favour")


func test_a_slight_is_the_most_recent_rather_than_the_worst() -> void:
	# A kindness is remembered for its size and an injury for its freshness,
	# which is roughly how people work.
	var governor := _contact()
	governor.relationship.remember(Relationship.REFUSED, 2, 500.0, "guns")
	governor.relationship.remember(Relationship.IGNORED, 8, 0.0, "request")

	assert_eq(int(governor.relationship.most_recent_slight().month), 8,
		"he brought up an old grievance in preference to a fresh one")


func test_a_broken_word_is_its_own_accusation() -> void:
	# Being refused is disappointing; being promised is being lied to.
	var governor := _contact()
	governor.relationship.remember(Relationship.REFUSED, 9, 10.0, "food")
	governor.relationship.remember(Relationship.PROMISE_BROKEN, 5, 80.0, "iron")

	var broken := governor.relationship.last_broken_word()
	assert_true(broken != null, "a broken promise was not remembered as one")
	assert_eq(String(broken.subject), "iron")
	assert_eq(int(governor.relationship.most_recent_slight().month), 9,
		"the broken word crowded out the more recent refusal")


func test_the_same_log_makes_two_different_men() -> void:
	# **Free characterisation.** Same history, same queries, different weights:
	# a warm man leads with the kindness, a sour one with the slight, and neither
	# of them is lying.
	var warm := _contact(90.0)
	var sour := _contact(10.0)
	for governor in [warm, sour]:
		governor.relationship.remember(Relationship.GRANTED, 3, 200.0, "iron")
		governor.relationship.remember(Relationship.REFUSED, 7, 10.0, "guns")

	var warm_memory := warm.relationship.recalled(0.1)
	var sour_memory := sour.relationship.recalled(0.9)
	assert_true(warm_memory.is_a_kindness(), "a devoted man went straight to the grievance")
	assert_true(sour_memory.is_a_slight(), "a man who loathes the PC recalled his generosity")


func test_in_character_follows_the_man() -> void:
	var warm := _contact(95.0)
	var sour := _contact(5.0)
	for governor in [warm, sour]:
		governor.relationship.remember(Relationship.GRANTED, 3, 200.0, "iron")
		governor.relationship.remember(Relationship.REFUSED, 7, 10.0, "guns")

	var kind := String(ColonyParamSources.recalled(
		{"reach": "in_character", "field": "resource"}, _context(warm, 9)))
	var bitter := String(ColonyParamSources.recalled(
		{"reach": "in_character", "field": "resource"}, _context(sour, 9)))
	assert_true(kind != bitter,
		"two men of opposite temper reached for the same memory")


# --- 🔒 Bounded, and it forgets the middle ----------------------------------

func test_a_long_run_does_not_bloat_the_save() -> void:
	# A fifty-year run cannot keep every deed for every contact.
	var governor := _contact()
	for month in 600:
		governor.relationship.remember(Relationship.GRANTED, month, 1.0, "wood")
	assert_true(governor.relationship.history.size() <= Relationship.MEMORY_LIMIT,
		"six hundred months left %d memories in the save"
			% governor.relationship.history.size())


func test_it_keeps_the_great_kindness_and_the_last_slight() -> void:
	# **The middle falls away**, which is also how people remember.
	var governor := _contact()
	governor.relationship.remember(Relationship.PROMISE_BROKEN, 1, 400.0, "guns")
	for month in range(2, 40):
		governor.relationship.remember(Relationship.GRANTED, month, 1.0, "wood")
	governor.relationship.remember(Relationship.REFUSED, 41, 5.0, "food")

	var broken := governor.relationship.last_broken_word()
	assert_true(broken != null,
		"thirty-eight quiet months made him forget the promise that was broken")
	assert_eq(int(governor.relationship.most_recent_slight().month), 41,
		"he forgot last month")


func test_the_bound_is_a_tuning_value() -> void:
	assert_true(Relationship.MEMORY_LIMIT > Relationship.MEMORY_RECENT,
		"a contact would remember only the recent and never the remarkable")
	assert_true(Relationship.MEMORY_RECENT > 0,
		"a contact would remember four remarkable years and nothing about last month")


# --- 🔒 The tally is still there --------------------------------------------

func test_counts_remain() -> void:
	# History adds to the tally rather than replacing it; the letters that read
	# counts back still work.
	var governor := _contact()
	governor.relationship.record_deed(Relationship.GRANTED)
	governor.relationship.remember(Relationship.GRANTED, 3, 200.0, "iron")
	assert_eq(governor.relationship.deed_count(Relationship.GRANTED), 1,
		"recording a memory lost the count, or counting lost the memory")


# --- 🔒 It survives a reload ------------------------------------------------

func test_a_memory_survives_a_round_trip() -> void:
	var governor := _contact()
	governor.relationship.remember(Relationship.GRANTED, 4, 200.0, "iron")
	governor.relationship.remember(Relationship.PROMISE_BROKEN, 11, 50.0, "guns")

	var restored := Relationship.from_dict(governor.relationship.to_dict())
	assert_eq(restored.history.size(), 2, "a reload emptied his memory")
	assert_eq(String(restored.most_generous().subject), "iron")
	assert_eq(int(restored.last_broken_word().month), 11)
	assert_almost_eq(restored.most_generous().magnitude, 200.0, 0.001)


# --- 🔒 A real deed reaches the memory --------------------------------------

func test_a_letter_the_pc_sends_is_what_he_remembers() -> void:
	# The whole path: an Order resolves, and the man on the other end can
	# describe it afterwards. Without this the log is a thing nothing writes to.
	var governor := _contact(95.0)
	var order := Order.new()
	order.kind = M1Registrations.ORDER_PROMISE_RESOURCE
	order.addressed_to = &"gov_ashmere"
	order.params = {"to": "gov_ashmere", "resource": "iron", "amount": 200}

	var state := WorldValues.initial_state()
	state.month = 4
	Compliance.resolve(order, governor, IntentBook.new(), state, EventLog.new(), RngStreams.new(3))

	var memory := governor.relationship.most_generous()
	assert_true(memory != null, "the PC sent two hundred iron and nobody remembered it")
	assert_eq(String(memory.subject), "iron")
	assert_almost_eq(memory.magnitude, 200.0, 0.001)
	assert_eq(memory.month, 4)


# --- 🔒 The sour half, and its gates (#391, `contacts.md` §7) ----------------

func test_a_refusal_he_can_name_opens_the_sour_letter() -> void:
	var marshal := _contact(40.0)
	var context := _context(marshal, 9)
	assert_false(ColonyConditions.remembers_a_slight({}, context),
		"a man with nothing on record was ready to say he was refused")

	marshal.relationship.remember(Relationship.REFUSED, 3, 40.0, "iron")
	assert_true(ColonyConditions.remembers_a_slight({}, context),
		"a man refused forty iron had nothing to say about it")
	assert_eq(int(ColonyParamSources.recalled({"reach": "slight", "field": "amount"}, context)), 40)
	assert_eq(String(ColonyParamSources.recalled({"reach": "slight", "field": "resource"}, context)), "iron")
	assert_eq(int(ColonyParamSources.recalled({"reach": "slight", "field": "months_ago"}, context)), 6)


func test_a_slight_he_cannot_name_says_nothing() -> void:
	# Being ignored is a slight, and a true one, but *"you refused me 0 of "* is
	# not a sentence (SPEC §9.1).
	var marshal := _contact(40.0)
	marshal.relationship.remember(Relationship.IGNORED, 5, 0.0, "request")
	assert_false(ColonyConditions.remembers_a_slight({}, _context(marshal, 9)),
		"he offered to name a slight that has nothing in it to name")


func test_a_broken_word_is_not_called_a_refusal_and_a_refusal_is_not_a_broken_word() -> void:
	# The two accusations are different letters. A man whose last grievance is a
	# broken promise writes the angrier one, and never the refusal.
	var promised := _contact(40.0)
	promised.relationship.remember(Relationship.REFUSED, 2, 10.0, "food")
	promised.relationship.remember(Relationship.PROMISE_BROKEN, 6, 80.0, "iron")
	var context := _context(promised, 9)
	assert_true(ColonyConditions.remembers_a_broken_word({}, context),
		"a broken promise was not remembered as one")
	assert_false(ColonyConditions.remembers_a_slight({}, context),
		"a broken promise was about to be described as a refusal")

	var refused := _contact(40.0)
	refused.relationship.remember(Relationship.REFUSED, 6, 10.0, "food")
	assert_false(ColonyConditions.remembers_a_broken_word({}, _context(refused, 9)),
		"a plain refusal was about to be called a broken word")


func test_temper_does_not_stand_in_for_the_gate() -> void:
	# The acceptance line: a sour man with a slight and no kindness still sends;
	# a warm one with only a kindness does not send the sour letter.
	var sour := _contact(5.0)
	sour.relationship.remember(Relationship.REFUSED, 3, 40.0, "iron")
	assert_true(ColonyConditions.remembers_a_slight({}, _context(sour, 9)))
	assert_true(ColonyConditions.remembers_in_character({}, _context(sour, 9)),
		"a sour man with a slight was held back because he had no kindness")

	var warm := _contact(95.0)
	warm.relationship.remember(Relationship.GRANTED, 3, 200.0, "iron")
	assert_false(ColonyConditions.remembers_a_slight({}, _context(warm, 9)),
		"a man with nothing but kindness on record was ready to complain")
	assert_true(ColonyConditions.remembers_in_character({}, _context(warm, 9)))


func test_a_refusal_at_the_desk_remembers_what_it_refused() -> void:
	# 🔒 Through the desk. `refuse` carries nothing but its addressee, so until
	# the desk stamped what was asked, every refusal was remembered as a refusal
	# of nothing, and the sour letter could never fire.
	var run := RunState.new_run(1649)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false
	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE

	var outgoing := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	outgoing.params = {"resource": "iron", "amount": 40}
	var wizard := ReplyWizard.new(
		Letter.from_record(content.record("letters", "marshal.request_supplies")), outgoing)
	wizard.choose_tone(Tone.DUTIFUL)
	wizard.choose("grant", "none")
	run.post.add(outgoing)
	machine.send_post()

	var marshal := run.contact(&"marshal")
	var slight := marshal.relationship.most_recent_slight()
	assert_true(slight != null and slight.kind == Relationship.REFUSED, "the refusal was not remembered")
	if slight == null:
		return
	assert_eq(String(slight.subject), "iron", "he could not say what he had been refused")
	assert_almost_eq(slight.magnitude, 40.0, 0.001, "he could not say how much")
	assert_true(ColonyConditions.remembers_a_slight({}, _context(marshal, run.world.month)),
		"a refusal he can name did not open the sour letter")


func test_a_broken_promise_of_gold_is_remembered_as_gold() -> void:
	# A gold promise has no resource in its terms, so the broken word was about
	# nothing — and gold is the promise the Crown breaks most.
	var marshal := _contact(40.0)
	var book := PromiseBook.new()
	book.make(Promise.new(&"gov_ashmere", &"gold", {"amount": 300.0}, 1, 2),
		marshal, EventLog.new(), 1)
	book.settle_due({"gov_ashmere": marshal}, EventLog.new(), 3, false)
	var broken := marshal.relationship.last_broken_word()
	assert_true(broken != null, "the Crown's refusal was not remembered as a broken word")
	if broken == null:
		return
	assert_eq(String(broken.subject), "gold")
	assert_true(ColonyConditions.remembers_a_broken_word({}, _context(marshal, 9)),
		"a broken promise of three hundred gold could not be named")


func test_a_trigger_that_reaches_for_a_memory_carries_its_gate() -> void:
	# 🔒 The validator's half of the lock: without the gate the params read zero
	# and an empty string, and the letter says so to the player.
	var ungated := ContentValidator.new()
	ungated.validate_trigger({
		"id": "trigger.test.ungated", "letter": "marshal.you_refused_me",
		"params": {"last_amount": {"from": "recalled", "reach": "slight", "field": "amount"}},
		"conditions": [{"always": {}}],
	})
	assert_false(ungated.ok(), "a trigger recalled a slight with nothing to say there was one")

	var gated := ContentValidator.new()
	gated.validate_trigger({
		"id": "trigger.test.gated", "letter": "marshal.you_refused_me",
		"params": {"last_amount": {"from": "recalled", "reach": "slight", "field": "amount"}},
		"conditions": [{"remembers_a_slight": {}}],
	})
	assert_true(gated.ok(), gated.report())
