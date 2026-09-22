extends TestCase

## Refusal is not a branch (#221, `docs/mechanics/commanders.md` §5,
## SPEC §8.5, §12.6).
##
## 🔒 **There is no "will he obey" check anywhere.** A commander scores every
## option open to him — attack, hold, march, withdraw to the town and disband —
## and takes the best. **Refusing to attack is simply attack scoring below
## retreat**, and it needs no code of its own, no branch and no special outcome.
##
## 🔒 **Keeping his army alive is a consideration, weighted by personality.** A
## cautious man weights it heavily and will not spend his men on a fort; a
## glory-seeker weights it low and will. **Both are reading the same board.**
##
## 🔒 **The PC's letter moves the weights, it does not move the company** — which
## is what SPEC §8.5 means by an order being a request, and what §12.6 means by
## Crown troops refusing orders against Crown interests. One mechanism, not two.
##
## 🔒 **And the trace is the letter.** `choose()` emits its scoring, so when a
## commander writes to say he will not assault the fort, the reason in his prose
## is the reason in his trace.

const SEED: int = 2260

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
	NameBags.reset()
	Company.reset()
	Force.reset()
	Battle.reset()
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
	NameBags.reset()
	Company.reset()
	Force.reset()
	Battle.reset()
	content.free()


const MARCH_ON_THEM: StringName = &"march_on_them"

const CAUTIOUS: Dictionary = {
	"keeping_my_army_alive": 1.6,
	"the_prize_in_front_of_me": 0.5,
	"the_orders_i_was_given": 0.5,
	"the_crowns_urging": 1.0,
	"standing_about": 0.5,
}

const GLORY_SEEKING: Dictionary = {
	"keeping_my_army_alive": 0.5,
	"the_prize_in_front_of_me": 1.6,
	"the_orders_i_was_given": 1.6,
	"the_crowns_urging": 1.0,
	"standing_about": 1.6,
}


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	return context


func _deliberation(run: RunState) -> DeliberationContext:
	var context := DeliberationContext.new(
		DecisionKind.COMMANDER_ORDERS, run.world, run.log)
	context.phase = WorldPhase.MOVEMENT
	context.data = {"map": run.map}
	return context


func _raise(
	run: RunState, allegiance: StringName, size: int, at: Vector2i = Company.NOWHERE
) -> Company:
	var town := run.colony.in_order()[0]
	return run.companies.raise_company(
		allegiance, size, {}, town.id,
		town.at if at == Company.NOWHERE else at, _context(run), MARCH_ON_THEM)


## A commander with the weights this test wants, and nothing else different.
func _man(run: RunState, id: StringName, weights: Dictionary) -> Contact:
	var man := Contact.new(id, weights)
	man.role = Contact.ROLE_COMMANDER
	man.display_name = String(id).capitalize()
	run.add_contact(man)
	return man


## The board §5 describes: a company in front of something it cannot beat.
func _a_hopeless_assault(run: RunState) -> Dictionary:
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 20, home)
	mine.destination = home + Vector2i(4, 0)
	var theirs := _raise(run, Company.CROWN, 200, home + Vector2i(1, 0))
	return {"mine": mine, "theirs": theirs}


func _what_he_would_do(
	run: RunState, man: Contact, company: Company, enemy: Company
) -> Decision:
	return Deliberation.choose(
		man,
		CommanderConsiderations.options_for(company, enemy, true),
		_deliberation(run))


# --- 🔒 No branch tests whether he will comply -----------------------------

func test_nothing_anywhere_asks_whether_a_commander_will_obey() -> void:
	# 🔒 The acceptance line, asked of the codebase — because the failure is not a
	# wrong number, it is a branch somebody adds later called `_will_he_obey` and
	# nobody notices has replaced the deliberation.
	var found := PackedStringArray()
	for path in _scripts_in("res://sim/battle"):
		var code := _code_of(path)
		for token in ["will_obey", "will_he", "obeys", "refuses(", "is_refusing",
				"complies("]:
			if code.contains(token):
				found.append("%s has %s" % [path.get_file(), token])
	assert_empty(found, "something asks whether he will obey: %s" % ", ".join(found))


func test_withdrawing_and_disbanding_are_ordinary_candidates() -> void:
	# 🔒 §5: scored alongside attacking rather than reached by a branch when
	# things go badly.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var facing := _ids(CommanderConsiderations.options_for(
		board["mine"], board["theirs"], true))
	for wanted in [CommanderConsiderations.ATTACK, CommanderConsiderations.HOLD,
			CommanderConsiderations.WITHDRAW, CommanderConsiderations.DISBAND]:
		assert_true(facing.has(String(wanted)),
			"'%s' is not an option in front of an enemy: %s" % [wanted, facing])

	var alone := _ids(CommanderConsiderations.options_for(board["mine"], null, true))
	assert_true(alone.has(String(CommanderConsiderations.MARCH)),
		"a company with nobody in front of it cannot march: %s" % alone)


func test_marching_is_not_how_you_leave_a_fight() -> void:
	# 🔒 §6: there is no rout. The ways out of contact are withdrawing, which is
	# a decision and goes home, and dying — and offering both would let a man
	# with orders to press on walk around every enemy he met, which is neither a
	# refusal nor a battle.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var facing := _ids(CommanderConsiderations.options_for(
		board["mine"], board["theirs"], true))
	assert_false(facing.has(String(CommanderConsiderations.MARCH)),
		"he strolled past two hundred men: %s" % facing)


func _ids(options: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for option in options:
		out.append(String((option as Candidate).id))
	return out


func test_attack_is_not_offered_when_there_is_nobody_to_attack() -> void:
	# An option that could never be taken is noise in every trace.
	var run := _run()
	var alone := _raise(run, Company.REBEL, 20)
	var ids := PackedStringArray()
	for option in CommanderConsiderations.options_for(alone, null, true):
		ids.append(String((option as Candidate).id))
	assert_false(ids.has(String(CommanderConsiderations.ATTACK)))


# --- 🔒 Two commanders, one board, different answers -----------------------

func test_the_cautious_man_refuses_and_the_glory_seeker_attacks() -> void:
	# 🔒 The acceptance line, and the whole of §5. **Both are reading the same
	# board** — the only difference between them is what they weigh.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var careful := _man(run, &"careful", CAUTIOUS)
	var bold := _man(run, &"bold", GLORY_SEEKING)

	var his := _what_he_would_do(run, careful, board["mine"], board["theirs"])
	var theirs := _what_he_would_do(run, bold, board["mine"], board["theirs"])

	assert_ne(his.chosen_id(), CommanderConsiderations.ATTACK,
		"a cautious man threw twenty men at two hundred")
	assert_eq(theirs.chosen_id(), CommanderConsiderations.ATTACK,
		"a glory-seeker declined a fight: he chose %s" % theirs.chosen_id())


func test_refusing_is_attack_scoring_below_retreat_and_nothing_else() -> void:
	# 🔒 §5, stated as arithmetic. There is no refusal outcome — the trace shows
	# two totals and one of them is larger.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var careful := _man(run, &"careful", CAUTIOUS)

	var decision := _what_he_would_do(run, careful, board["mine"], board["theirs"])
	var totals: Dictionary = {}
	for entry in decision.entries:
		totals[String((entry as Dictionary).get("id", ""))] = \
			float((entry as Dictionary).get("total", 0.0))

	assert_true(totals.has(String(CommanderConsiderations.ATTACK)),
		"attacking was never scored at all, so he did not refuse it")
	assert_true(
		float(totals[String(CommanderConsiderations.WITHDRAW)])
			> float(totals[String(CommanderConsiderations.ATTACK)]),
		"he declined without retreat outscoring the attack: %s" % [totals])


func test_the_worse_the_odds_the_worse_attacking_looks_to_him() -> void:
	# 🔒 **Keeping his army alive is doing the work**, and this asks it directly
	# rather than through an outcome. A version that scored only the prize would
	# make a bigger enemy look *better*, and the outcome tests would still pass.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 40, home)
	mine.destination = home + Vector2i(4, 0)
	var careful := _man(run, &"careful", CAUTIOUS)

	var weak := _raise(run, Company.CROWN, 10, home + Vector2i(1, 0))
	var easy := _total_for(_what_he_would_do(run, careful, mine, weak),
		CommanderConsiderations.ATTACK)
	var strong := _raise(run, Company.CROWN, 400, home + Vector2i(1, 0))
	var hard := _total_for(_what_he_would_do(run, careful, mine, strong),
		CommanderConsiderations.ATTACK)

	assert_true(hard < easy,
		"a cautious man liked four hundred men better than ten: %f against %f"
			% [hard, easy])


func test_the_two_considerations_are_not_the_same_number_twice() -> void:
	# 🔒 A large enemy is a large prize **and** a large risk, so the pair pull
	# against each other. If both read the odds they would be perfectly
	# correlated and the glory-seeker would be the cautious man times a scalar.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var plain := _man(run, &"plain", {})
	var decision := _what_he_would_do(run, plain, board["mine"], board["theirs"])

	var scored: Dictionary = {}
	for entry in decision.entries:
		if String((entry as Dictionary).get("id", "")) != String(CommanderConsiderations.ATTACK):
			continue
		for one in (entry as Dictionary).get("considerations", []):
			scored[String((one as Dictionary).get("id", ""))] = 				float((one as Dictionary).get("raw", 0.0))

	var alive := float(scored.get("keeping_my_army_alive", 0.0))
	var prize := float(scored.get("the_prize_in_front_of_me", 0.0))
	assert_true(alive < 0.0, "twenty men against two hundred looked safe: %f" % alive)
	assert_true(prize > 0.0, "two hundred men were not worth beating: %f" % prize)


func test_the_same_man_attacks_when_the_odds_turn() -> void:
	# The other half: a cautious man is not a man who never fights.
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 200, home)
	mine.destination = home + Vector2i(4, 0)
	var theirs := _raise(run, Company.CROWN, 5, home + Vector2i(1, 0))
	var careful := _man(run, &"careful", CAUTIOUS)

	assert_eq(_what_he_would_do(run, careful, mine, theirs).chosen_id(),
		CommanderConsiderations.ATTACK,
		"a cautious man declined a walkover")


func test_a_fort_on_a_mountain_turns_a_fight_into_a_refusal() -> void:
	# §5's own example: *a cautious man will not spend his men on a fort.* The
	# ground reaches him through `Force` and nowhere else (#214).
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 60, home)
	mine.destination = home + Vector2i(4, 0)
	var theirs := _raise(run, Company.CROWN, 40, home + Vector2i(1, 0))
	var careful := _man(run, &"careful", CAUTIOUS)

	var in_the_open := _what_he_would_do(run, careful, mine, theirs).chosen_id()
	run.map.set_terrain(theirs.at.x, theirs.at.y, &"mountains")
	run.map.improvements[run.map.index_of(theirs.at.x, theirs.at.y)] = "fort"
	var behind_a_wall := _what_he_would_do(run, careful, mine, theirs).chosen_id()

	assert_eq(in_the_open, CommanderConsiderations.ATTACK,
		"he would not fight them in the open either")
	assert_ne(behind_a_wall, CommanderConsiderations.ATTACK,
		"he assaulted a fort on a mountain at three to two")


# --- 🔒 The letter moves the weights, never the company --------------------

func test_the_order_changes_what_he_weighs_and_not_what_happens() -> void:
	# 🔒 SPEC §8.5: an order is a request. The standing order reaches him as a
	# consideration, so a man sent to attack weighs attacking higher — and a man
	# who weighs his army heavily still loses to the arithmetic in front of him.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var careful := _man(run, &"careful", CAUTIOUS)

	var sent := _what_he_would_do(run, careful, board["mine"], board["theirs"])
	board["mine"].order = StandingOrder.DEFEND_THE_TOWN
	var left_alone := _what_he_would_do(run, careful, board["mine"], board["theirs"])

	var attacking_when_sent := _total_for(sent, CommanderConsiderations.ATTACK)
	var attacking_at_home := _total_for(left_alone, CommanderConsiderations.ATTACK)
	assert_true(attacking_when_sent > attacking_at_home,
		"the order he was given counted for nothing: %f against %f"
			% [attacking_when_sent, attacking_at_home])
	assert_ne(sent.chosen_id(), CommanderConsiderations.ATTACK,
		"the order overruled the arithmetic, which makes it a command and not a request")


func test_a_man_with_no_weights_still_decides() -> void:
	# Weights default to one, so a contact nobody rolled is an average officer
	# rather than a crash.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var plain := _man(run, &"plain", {})
	assert_false(String(_what_he_would_do(
		run, plain, board["mine"], board["theirs"]).chosen_id()).is_empty())


# --- 🔒 The trace is the letter ---------------------------------------------

func test_the_trace_names_what_he_weighed() -> void:
	# 🔒 §5: when he writes to say he will not assault the fort, **the reason in
	# his prose is the reason in his trace.** He can name what he weighed because
	# the kernel recorded it.
	var run := _run()
	var board := _a_hopeless_assault(run)
	# **Urged, so the letter is among what he weighed.** A consideration that
	# does not apply is left out of the trace by design, and a commander nobody
	# has written to has no urging to weigh.
	(board["mine"] as Company).urge(
		CommanderConsiderations.ATTACK, Tone.DUTIFUL, run.world.month)
	var careful := _man(run, &"careful", CAUTIOUS)
	var decision := _what_he_would_do(run, careful, board["mine"], board["theirs"])

	var named: Dictionary = {}
	for entry in decision.entries:
		for scored in (entry as Dictionary).get("considerations", []):
			named[String((scored as Dictionary).get("id", ""))] = true
	for id in CommanderConsiderations.ALL:
		assert_true(named.has(String(id)),
			"'%s' was never weighed, so no letter could quote it" % id)


func test_the_trace_reaches_the_event_log() -> void:
	# `choose()` always emits its scoring (`CLAUDE.md`), which is what a refusal
	# letter reads.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var careful := _man(run, &"careful", CAUTIOUS)
	_what_he_would_do(run, careful, board["mine"], board["theirs"])

	var traces := run.log.of_type(Deliberation.TRACE_EVENT)
	assert_false(traces.is_empty(), "he weighed it all and nothing was recorded")


func test_a_commander_is_rolled_a_weight_for_each_of_them() -> void:
	# 🔒 Without this every commander weighs them identically and two men reading
	# the same board always agree — the cautious man and the glory-seeker would
	# be the same man.
	var run := _run()
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		Company.COLONIAL, 20, {}, town.id, town.at, _context(run), MARCH_ON_THEM)
	var man := Commanders.take_command(company, town, run, _context(run))

	for id in CommanderConsiderations.ALL:
		assert_true(man.weights.has(String(id)),
			"a commander has no opinion of his own about '%s'" % id)


# --- 🔒 Loyalty is what makes an order an argument ------------------------

## A commander whose regard for the PC is what this test is about.
func _at(run: RunState, id: StringName, loyalty: float, weights: Dictionary) -> Contact:
	var man := _man(run, id, weights)
	man.relationship = Relationship.new(id, loyalty)
	return man


func test_a_loyal_commander_weighs_the_order_and_a_bitter_one_barely_does() -> void:
	# 🔒 SPEC §8.5: **an order is a request**, and a request from a man you
	# despise is barely an argument at all. The same board, the same weights, the
	# same order — and only his regard is different.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var devoted := _at(run, &"devoted", 95.0, {})
	var bitter := _at(run, &"bitter", 5.0, {})

	var his := _what_he_would_do(run, devoted, board["mine"], board["theirs"])
	var theirs := _what_he_would_do(run, bitter, board["mine"], board["theirs"])

	assert_true(
		_consideration_in(his, CommanderConsiderations.ATTACK, "the_orders_i_was_given")
			> _consideration_in(theirs, CommanderConsiderations.ATTACK,
				"the_orders_i_was_given") * 3.0,
		"a bitter commander weighed his orders nearly as heavily as a devoted one")


func test_a_disloyal_commander_is_barely_moved_by_a_desperate_letter() -> void:
	# 🔒 The whole point. **Desperate pulls harder and for longer than any other
	# tone** (`tone.md` §4) — and there is no tone strong enough to make a man who
	# loathes the PC do as he is told.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var company: Company = board["mine"]
	company.urge(CommanderConsiderations.ATTACK, Tone.DESPERATE, run.world.month)

	var devoted := _at(run, &"devoted", 95.0, {})
	var bitter := _at(run, &"bitter", 5.0, {})

	var moved := _consideration_in(
		_what_he_would_do(run, devoted, company, board["theirs"]),
		CommanderConsiderations.ATTACK, "the_crowns_urging")
	var unmoved := _consideration_in(
		_what_he_would_do(run, bitter, company, board["theirs"]),
		CommanderConsiderations.ATTACK, "the_crowns_urging")

	assert_true(moved > 0.8, "a desperate letter barely reached a devoted man: %f" % moved)
	assert_true(unmoved < 0.2,
		"a desperate letter moved a man who loathes the PC: %f" % unmoved)


func test_a_devoted_commander_does_what_he_is_asked_where_a_bitter_one_will_not() -> void:
	# The outcome, not only the weight: **the same board, decided differently by
	# two men who differ in nothing but their regard.**
	var run := _run()
	var home := run.colony.in_order()[0].at
	var mine := _raise(run, Company.REBEL, 50, home)
	mine.destination = home + Vector2i(4, 0)
	# A fight he would not pick on his own: dearer than even, not hopeless.
	var theirs := _raise(run, Company.CROWN, 90, home + Vector2i(1, 0))
	mine.urge(CommanderConsiderations.ATTACK, Tone.DUTIFUL, run.world.month)

	# **The same man twice, differing in nothing but his regard.** Both are
	# cautious, so both would decline this on their own judgement — which is what
	# leaves the letter as the only thing that could move either of them.
	var devoted := _at(run, &"devoted", 95.0, CAUTIOUS)
	var bitter := _at(run, &"bitter", 5.0, CAUTIOUS)

	assert_eq(_what_he_would_do(run, devoted, mine, theirs).chosen_id(),
		CommanderConsiderations.ATTACK,
		"a devoted commander ignored the letter he was sent")
	assert_ne(_what_he_would_do(run, bitter, mine, theirs).chosen_id(),
		CommanderConsiderations.ATTACK,
		"a bitter commander went in on the strength of a letter")


func test_a_letter_fades_and_a_desperate_one_fades_slower() -> void:
	# 🔒 **A letter is not a standing order** (`commanders.md` §8). He remembers
	# it, it fades, and how fast depends on how much he took it to mean.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var company: Company = board["mine"]
	var devoted := _at(run, &"devoted", 95.0, {})

	company.urge(CommanderConsiderations.ATTACK, Tone.DUTIFUL, 0)
	run.world.month = 0
	var fresh := _pull(run, devoted, board)
	run.world.month = int(CommanderConsiderations.URGING_HALF_LIFE) * 2
	var stale := _pull(run, devoted, board)
	assert_true(stale < fresh, "a year-old letter pulled as hard as a fresh one")

	company.urge(CommanderConsiderations.ATTACK, Tone.DESPERATE, 0)
	assert_true(_pull(run, devoted, board) > stale,
		"a desperate letter faded as fast as a dutiful one")


func test_a_commander_nobody_has_written_to_weighs_no_urging() -> void:
	var run := _run()
	var board := _a_hopeless_assault(run)
	var devoted := _at(run, &"devoted", 95.0, {})
	assert_almost_eq(_pull(run, devoted, board), 0.0, 0.0001,
		"a commander felt urged toward something nobody asked for")


func test_the_letter_says_nothing_about_what_it_did_not_mention() -> void:
	# Scoring the other options negatively would make the PC's letter an argument
	# against everything he did not write about.
	var run := _run()
	var board := _a_hopeless_assault(run)
	var company: Company = board["mine"]
	company.urge(CommanderConsiderations.ATTACK, Tone.DUTIFUL, run.world.month)
	var devoted := _at(run, &"devoted", 95.0, {})
	var decision := _what_he_would_do(run, devoted, company, board["theirs"])

	assert_almost_eq(
		_consideration_in(decision, CommanderConsiderations.WITHDRAW, "the_crowns_urging"),
		0.0, 0.0001,
		"the letter argued against an option it never named")


func test_the_urging_survives_the_save() -> void:
	var run := _run()
	var board := _a_hopeless_assault(run)
	var company: Company = board["mine"]
	company.urge(CommanderConsiderations.ATTACK, Tone.DESPERATE, 7)

	var back := Companies.from_dict(run.companies.to_dict()).find(company.id)
	assert_eq(back.urged, company.urged)
	assert_eq(back.urged_tone, company.urged_tone)
	assert_eq(back.urged_month, company.urged_month)


func _pull(run: RunState, man: Contact, board: Dictionary) -> float:
	return _consideration_in(
		_what_he_would_do(run, man, board["mine"], board["theirs"]),
		CommanderConsiderations.ATTACK, "the_crowns_urging")


## What one consideration scored, raw, for one option.
func _consideration_in(decision: Decision, option: StringName, id: String) -> float:
	for entry in decision.entries:
		if String((entry as Dictionary).get("id", "")) != String(option):
			continue
		for one in (entry as Dictionary).get("considerations", []):
			if String((one as Dictionary).get("id", "")) == id:
				return float((one as Dictionary).get("raw", 0.0))
	return 0.0


func _total_for(decision: Decision, option: StringName) -> float:
	for entry in decision.entries:
		if String((entry as Dictionary).get("id", "")) == String(option):
			return float((entry as Dictionary).get("total", 0.0))
	return 0.0


## A script with its comments taken out. **The lock is about code, not prose** —
## `commander_considerations.gd` explains at length that there is no obedience
## check, and a scan that counted the explanation would forbid explaining it.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _scripts_in(at: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			out.append(at.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	assert_false(out.is_empty(), "no scripts were found under %s to check" % at)
	return out
