extends TestCase

## What each tone does to compliance's six outcomes (#261,
## `docs/mechanics/tone.md` §3, §4, §6, §8).
##
## 🔒 **The five are not ordered.** Each tone is a table per outcome, never a
## position on a scale — there is no "annoyed or worse" anywhere, and a test that
## asserted one tone sits between two others would be inventing the ordering §2
## forbids.
##
## 🔒 **Desperate removes delay. It does not weigh against it.** A large negative
## weight is not the same thing: a close vote could still land on delay, and the
## point of the tone is that a desperate letter is **never** put off.

const SEED: int = 3118
## How finely the regard sweep steps, which sets the size of every tally.
const REGARD_STEP: int = 5

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


func _an_order(kind: StringName, tone: StringName, params: Dictionary = {}) -> Order:
	var order := Order.new(kind, &"marshal", params.duplicate(), 0)
	order.id = StringName("order_%s_%s" % [kind, tone])
	order.tone = tone
	return order


## What the same letter, written five ways, actually gets you.
##
## 🔒 **The spread is across men, not across throws.** `choose()` takes the
## highest score; the stream only breaks ties. So four hundred letters to one
## contact are four hundred copies of one answer, and the distribution §5 means
## by *the centre of a distribution* is the one over personalities and regard.
##
## Every contact on the roster, at every regard from nothing to devotion.
func _outcomes_of(
	run: RunState,
	kind: StringName,
	tone: StringName,
	params: Dictionary = {},
) -> Dictionary:
	var tally: Dictionary = {}
	for outcome in Compliance.OUTCOMES:
		tally[outcome] = 0

	var ids: Array = run.contact_ids()
	ids.sort()
	for id in ids:
		var contact := run.contact(StringName(id))
		for step in range(0, 101, REGARD_STEP):
			contact.relationship = Relationship.new(StringName(id), float(step))
			var result := Compliance.resolve(
				_an_order(kind, tone, params), contact, run.intents,
				run.world, run.log, run.streams)
			tally[StringName(result["outcome"])] += 1
	return tally


## One world, loaded once, for a whole test.
func _a_world() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


# --- 🔒 Desperate removes delay ---------------------------------------------

func test_a_desperate_letter_is_never_put_off() -> void:
	# 🔒 A filter, not a weight. `deliberation.md` §5 keeps the two apart because
	# a weight can lose a close vote — and a desperate letter that lands in a
	# drawer one time in twenty is not the compliance tool §6 says it is.
	var tally := _outcomes_of(_a_world(),
		M1Registrations.ORDER_REQUEST_TROOPS, Tone.DESPERATE, {"amount": 100})
	assert_eq(int(tally[Compliance.DELAY]), 0,
		"a desperate letter was put in a drawer: %s" % tally)


## A consideration that wants delay above all else, and nothing else at all.
##
## Registered only inside the test below, so it exists to prove one thing: that
## the filter beats a **winning** score rather than merely adding to a pile that
## was already going the right way.
class NothingButDelay:
	extends Consideration

	func _init() -> void:
		super(&"nothing_but_delay")

	func score(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> float:
		return 1.0 if candidate.id == Compliance.DELAY else -1.0


func test_the_filter_beats_a_score_that_would_have_won() -> void:
	# 🔒 **This is the whole of the lock**, and it needs a rigged vote to show.
	#
	# Today desperate's other weights already push delay out everywhere the
	# roster reaches, so removing the filter changes no outcome and a test written
	# against outcomes cannot tell a filter from a weight. That is precisely the
	# case `deliberation.md` §5 is about: the weights happen to suffice, and a
	# consideration added next milestone could make them stop.
	#
	# So the vote is rigged toward delay and the two tones are asked the same
	# question. Dutiful takes the bait. Desperate cannot.
	var run := _a_world()
	var contact := run.contact(&"marshal")
	Deliberation.register_consideration(
		NothingButDelay.new(), [DecisionKind.ORDER_COMPLIANCE])

	var chose: Dictionary = {}
	for tone in [Tone.DUTIFUL, Tone.DESPERATE]:
		var candidates: Array = []
		for outcome in Compliance.OUTCOMES:
			candidates.append(Candidate.new(outcome, {"outcome": String(outcome)}))
		var context := DeliberationContext.new(
			DecisionKind.ORDER_COMPLIANCE, run.world, run.log)
		context.rng = run.streams.contact_stream("marshal")
		context.data = {"tone": tone, "loyalty": contact.loyalty()}
		chose[String(tone)] = String(Deliberation.choose(contact, candidates, context).chosen_id())

	assert_eq(String(chose[String(Tone.DUTIFUL)]), String(Compliance.DELAY),
		"the vote was not actually rigged toward delay, so this proves nothing")
	assert_false(String(chose[String(Tone.DESPERATE)]) == String(Compliance.DELAY),
		"a desperate letter was put in a drawer by a vote it should never have been in")


func test_the_other_four_can_all_be_put_off() -> void:
	# The other half. A filter that removed delay from every letter would pass the
	# test above and be an entirely different rule.
	var run := _a_world()
	var delayed: Dictionary = {}
	for tone in [Tone.PLEASED, Tone.DUTIFUL, Tone.ANNOYED, Tone.HATEFUL]:
		var tally := _outcomes_of(run,
			M1Registrations.ORDER_REQUEST_TROOPS, tone, {"amount": 100})
		delayed[String(tone)] = int(tally[Compliance.DELAY])
	var ever := 0
	for tone in delayed:
		ever += int(delayed[tone])
	assert_true(ever > 0,
		"nothing was ever delayed in any tone, so removing delay proves nothing: %s"
			% delayed)


func test_desperate_carries_no_weight_against_delay_as_well() -> void:
	# 🔒 The same rule written twice is the failure this guards. A heavy negative
	# weight alongside the filter would go on looking like it was doing the work
	# after somebody removed the filter.
	var desperate := ToneConsiderations.Desperate.new(
		ToneConsiderations.of(Tone.DESPERATE))
	assert_false(desperate.pull().has(Compliance.DELAY),
		"desperate weighs against delay as well as filtering it out")
	var registered: Dictionary = {}
	for consideration in Deliberation.considerations_for(DecisionKind.ORDER_COMPLIANCE):
		registered[String(consideration.id)] = true
	for tone in Tone.ALL:
		assert_true(registered.has(String(ToneConsiderations.of(tone))),
			"%s is not registered as a consideration" % tone)


# --- 🔒 A table per outcome, and not a scale --------------------------------

func test_each_tone_pushes_where_section_four_says_it_does() -> void:
	# §4's table, asked of the kernel rather than read off the class. Each of
	# these is a claim about what the letter *gets you*, which is the only form
	# the claim is worth making in.
	var run := _a_world()
	var by_tone: Dictionary = {}
	for tone in Tone.ALL:
		by_tone[String(tone)] = _outcomes_of(run,
			M1Registrations.ORDER_REQUEST_TROOPS, tone, {"amount": 100})

	var pleased: Dictionary = by_tone[String(Tone.PLEASED)]
	var dutiful: Dictionary = by_tone[String(Tone.DUTIFUL)]
	var annoyed: Dictionary = by_tone[String(Tone.ANNOYED)]
	var hateful: Dictionary = by_tone[String(Tone.HATEFUL)]

	# **pleased** — rarely refused, frequently put in a drawer.
	assert_true(int(pleased[Compliance.DELAY]) > int(dutiful[Compliance.DELAY]),
		"pleased was not put off more readily than the plain register: %s" % by_tone)
	assert_true(int(pleased[Compliance.REFUSE]) <= int(hateful[Compliance.REFUSE]),
		"a fond letter was refused more often than a contemptuous one: %s" % by_tone)

	# **annoyed** — half of it, promptly. Its niche is the other half of
	# pleased's: it pushes *away* from delay.
	assert_true(int(annoyed[Compliance.DELAY]) < int(pleased[Compliance.DELAY]),
		"annoyed sat in the drawer as readily as a pleased letter: %s" % by_tone)

	# **hateful** — more likely to be refused outright or simply acted around.
	var hateful_sideways := int(hateful[Compliance.REFUSE]) + int(hateful[Compliance.ACT_ALONE])
	var dutiful_sideways := int(dutiful[Compliance.REFUSE]) + int(dutiful[Compliance.ACT_ALONE])
	assert_true(hateful_sideways > dutiful_sideways,
		"contempt was answered no worse than the plain register: %s" % by_tone)

	# **dutiful** — excludes the sideways answers and buys nothing else. The safe
	# choice, and it should be.
	assert_true(dutiful_sideways < hateful_sideways,
		"the plain register was not the safe choice: %s" % by_tone)


func test_the_five_are_never_put_in_an_order() -> void:
	# 🔒 §2. Nothing anywhere asks whether one tone is worse than another, and
	# nothing derives one tone's table from another's position.
	var tables: Dictionary = {}
	for tone in Tone.ALL:
		var consideration: ToneConsiderations.OfTone = null
		match tone:
			Tone.PLEASED: consideration = ToneConsiderations.Pleased.new(&"x")
			Tone.DUTIFUL: consideration = ToneConsiderations.Dutiful.new(&"x")
			Tone.ANNOYED: consideration = ToneConsiderations.Annoyed.new(&"x")
			Tone.DESPERATE: consideration = ToneConsiderations.Desperate.new(&"x")
			Tone.HATEFUL: consideration = ToneConsiderations.Hateful.new(&"x")
		tables[String(tone)] = consideration.pull()

	# No two tones share a table, which is what would happen if one were derived
	# from another by a scale factor.
	var seen: Array = []
	for tone in tables:
		for other in seen:
			assert_false(tables[tone] == tables[other],
				"%s and %s have the same table, so one is a scaled copy" % [tone, other])
		seen.append(tone)


# --- 🔒 Directing and asking, never answering -------------------------------

func test_answering_has_no_compliance_step_at_all() -> void:
	# 🔒 §3: *you* are the one complying, and the deed dominates (SPEC §8.5). Not
	# a heavy push toward complying — none at all, in any tone, ever.
	var run := _a_world()
	for kind in LetterKind.ANSWERS:
		for tone in Tone.ALL:
			var result := Compliance.resolve(
				_an_order(StringName(kind), tone, {"amount": 100}),
				run.contact(&"marshal"), run.intents, run.world, run.log, run.streams)
			assert_eq(StringName(result["outcome"]), Compliance.COMPLY,
				"a %s letter written %s was deliberated over: %s"
					% [kind, tone, result["outcome"]])


func test_a_directing_letter_is_still_his_to_answer() -> void:
	# The other half: the bypass must not have swallowed the letters that *are*
	# his to answer, which would make every order obeyed and the game a spreadsheet.
	var run := _a_world()
	var answers: Dictionary = {}
	for tone in Tone.ALL:
		var tally := _outcomes_of(run, M1Registrations.ORDER_URGE_INTENT,
			tone, {"intent": String(GovernorIntent.GET_RICH)})
		for outcome in tally:
			if int(tally[outcome]) > 0:
				answers[String(outcome)] = true
	assert_true(answers.size() > 1,
		"every directing letter got the same answer, whatever the tone: %s" % answers)


func test_the_three_kinds_are_named_and_nothing_falls_through() -> void:
	# A kind not listed is directing, which is the safe reading — it deliberates,
	# which is what everything did before the table existed. But the two lists
	# must not overlap, or the answer depends on which was checked first.
	for kind in LetterKind.ANSWERS:
		assert_false(LetterKind.ASKS.has(kind),
			"%s is both an answer and an ask" % kind)
		assert_eq(LetterKind.of(StringName(kind)), LetterKind.ANSWERING)
	for kind in LetterKind.ASKS:
		assert_eq(LetterKind.of(StringName(kind)), LetterKind.ASKING)
	assert_eq(LetterKind.of(M1Registrations.ORDER_URGE_INTENT), LetterKind.DIRECTING)
	assert_eq(LetterKind.of(&"something_nobody_has_written_yet"), LetterKind.DIRECTING)


# --- 🔒 Partial magnitude, on asking letters --------------------------------

func test_how_much_of_a_partial_gets_done_moves_with_tone() -> void:
	# 🔒 §3, §4: annoyed's push toward a partial is worth less if the partial is a
	# tenth of what was asked, so the two knobs move together.
	var shares: Dictionary = {}
	for tone in Tone.ALL:
		shares[String(tone)] = Compliance.partial_share(
			_an_order(M1Registrations.ORDER_REQUEST_TROOPS, tone, {"amount": 100}))

	assert_true(float(shares[String(Tone.PLEASED)]) > float(shares[String(Tone.DUTIFUL)]),
		"a man glad to hear from you was no more generous with a half measure: %s" % shares)
	assert_true(float(shares[String(Tone.HATEFUL)]) < float(shares[String(Tone.DUTIFUL)]),
		"contempt bought as much of a partial as the plain register: %s" % shares)
	for tone in shares:
		assert_true(float(shares[tone]) > 0.0 and float(shares[tone]) <= 1.0,
			"%s makes a partial worth %s of the whole" % [tone, shares[tone]])


func test_a_partial_actually_delivers_what_the_tone_bought() -> void:
	# Through the resolution, not off the table — the share is worth nothing if
	# nothing reads it.
	#
	# Pleased against annoyed, because those are the two that reach a partial at
	# all. It is also the interaction §4 is about: **annoyed is what buys you the
	# half measure and pleased is what makes the half measure larger**, so the
	# player who wants most of it promptly has a genuine choice to get wrong.
	var run := _a_world()
	var delivered: Dictionary = {}
	for tone in [Tone.PLEASED, Tone.ANNOYED]:
		for step in range(0, 101, REGARD_STEP):
			var contact := run.contact(&"marshal")
			contact.relationship = Relationship.new(&"marshal", float(step))
			var result := Compliance.resolve(
				_an_order(M1Registrations.ORDER_REQUEST_TROOPS, tone, {"amount": 100}),
				contact, run.intents, run.world, run.log, run.streams)
			if StringName(result["outcome"]) != Compliance.PARTIAL:
				continue
			var intent: Intent = result["intent"]
			delivered[String(tone)] = int(intent.data["amount"])
			break

	assert_true(delivered.has(String(Tone.PLEASED)) and delivered.has(String(Tone.ANNOYED)),
		"no partial answer arrived in either tone, so nothing was measured: %s" % delivered)
	assert_true(int(delivered[String(Tone.PLEASED)]) > int(delivered[String(Tone.ANNOYED)]),
		"a grumbling letter got as many men as a fond one: %s" % delivered)


func test_a_directing_letter_has_no_magnitude_to_move() -> void:
	# 🔒 §3 gives partial magnitude to asking alone. A governor half-persuaded
	# toward profit is not chasing half a profit.
	for tone in Tone.ALL:
		assert_eq(Compliance.partial_share(
			_an_order(M1Registrations.ORDER_URGE_INTENT, tone)),
			Compliance.PARTIAL_SHARE,
			"tone moved the magnitude of a directing letter, which has none")


# --- 🔒 The same letter, two men -------------------------------------------

func test_the_same_letter_to_two_men_lands_differently() -> void:
	# §5: the tables are the centre of a distribution, and the three traits scale
	# them per contact. Two men of the same office, written to identically, must
	# be able to answer differently — that is the whole reason tone sits inside
	# the kernel rather than on top of it.
	var run := _a_world()
	var answers: Dictionary = {}
	for id in ["marshal", "steward", "provost", "chancellor", "diplomat"]:
		var contact := run.contact(StringName(id))
		var result := Compliance.resolve(
			_an_order(M1Registrations.ORDER_URGE_INTENT, Tone.HATEFUL,
				{"intent": String(GovernorIntent.GET_RICH)}),
			contact, run.intents, run.world, run.log, run.streams)
		answers[id] = String(result["outcome"])

	var distinct: Dictionary = {}
	for id in answers:
		distinct[String(answers[id])] = true
	assert_true(distinct.size() > 1,
		"one hateful letter got the same answer from every man alive: %s" % answers)
