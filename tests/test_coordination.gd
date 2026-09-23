extends TestCase

## Commanders coordinate without a general staff (#222,
## `docs/mechanics/commanders.md` §4).
##
## 🔒 **No faction brain and no general staff.** The ordinary kernel with
## considerations that read the `IntentBook`. Coordination **emerges** rather
## than being directed, consistent with governors, who optimise independently
## while nobody plans the colony — and it has to be this way in fiction, because
## §12.6 locks that the PC never commands and the Marshal is an ocean away.
##
## 🔒 **A commander never reads another's decision from the same month.** Every
## commander commits in the same phase, so without that filter the ones going
## later would read the fresh plans of the ones before them and the company list
## would become a chain of command.
##
## 🔒 **And the two failure modes are measured**: everybody converging on one
## attractive target, and nobody covering a gap.

const SEED: int = 7711

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


const MARCH: StringName = &"march_on_them"


func _run() -> RunState:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	return run


func _context(run: RunState) -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	return context


## A commanded company of `allegiance`, standing at `at`.
func _raise(
	run: RunState, allegiance: StringName, size: int, at: Vector2i
) -> Company:
	var town := run.colony.in_order()[0]
	var company := run.companies.raise_company(
		allegiance, size, {"guns": float(size)}, town.id, at, _context(run), MARCH)
	Commanders.take_command(company, town, run, _context(run))
	return company


## A second town, so the colony has somewhere to be undefended and a road to lose.
func _outpost(run: RunState, offset: Vector2i, workers: int = 12) -> Town:
	var town := Town.new(
		StringName("outpost_%d_%d" % [offset.x, offset.y]),
		"Outpost %d" % offset.x,
		run.colony.in_order()[0].at + offset)
	town.workers = workers
	run.colony.add(town)
	return town


func _settle(run: RunState, company: Company) -> Vector2i:
	return MarchingOrders.settle(company, _context(run), run.intents, run.contacts)


# --- 🔒 No faction-level actor exists ---------------------------------------

func test_no_faction_level_actor_exists() -> void:
	# 🔒 §4 holds the faction-level assessment **in reserve**: *if the harness
	# shows either failure mode, the fallback is a faction-level assessment that
	# assigns roles before anyone deliberates. Do not build it pre-emptively.*
	#
	# Asked of the codebase, because it is the obvious thing to reach for the
	# first time two companies do something silly.
	var found := PackedStringArray()
	for path in _scripts_in("res://sim/battle"):
		var code := _code_of(path)
		for token in ["assign_role", "assign_roles", "army_plan", "campaign_plan",
				"general_staff", "faction_plan", "theatre", "high_command"]:
			if code.contains(token):
				found.append("%s has %s" % [path.get_file(), token])
	assert_empty(found, "something plans for a whole faction: %s" % ", ".join(found))


func test_nobody_is_scripted() -> void:
	# 🔒 §4: *do not paper over the symptom by scripting behaviour into particular
	# commanders. A scripted commander is a commander whose letters can lie about
	# why.* Every one of the four is a weight on the kernel.
	var registered: Dictionary = {}
	for entry in Deliberation.considerations_for(DecisionKind.COMMANDER_OBJECTIVE):
		registered[String((entry as Consideration).id)] = true
	for name in CoordinationConsiderations.ALL:
		assert_has(registered, String(name),
			"%s is not registered as a consideration on the kernel" % name)
	assert_eq(CoordinationConsiderations.ALL.size(), 4,
		"§4 names four questions and this file answers %d"
			% CoordinationConsiderations.ALL.size())


# --- 🔒 The one-month lag ---------------------------------------------------

func test_a_commander_never_reads_a_decision_from_this_month() -> void:
	# 🔒 The acceptance line. Both commanders commit in the same phase; the second
	# must not see the first's fresh plan.
	var run := _run()
	var target := _outpost(run, Vector2i(3, 0))
	var first := _raise(run, Company.COLONIAL, 20, target.at + Vector2i(1, 0))
	var second := _raise(run, Company.COLONIAL, 20, target.at + Vector2i(-1, 0))

	run.world.month = 5
	_settle(run, first)

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents}
	assert_empty(
		CoordinationConsiderations.plans_laid_before_now(
			deliberation, second.commander),
		"the second commander read a plan laid this month")


func test_and_reads_it_the_month_after() -> void:
	var run := _run()
	var target := _outpost(run, Vector2i(3, 0))
	var first := _raise(run, Company.COLONIAL, 20, target.at + Vector2i(1, 0))
	var second := _raise(run, Company.COLONIAL, 20, target.at + Vector2i(-1, 0))

	run.world.month = 5
	_settle(run, first)
	run.world.month = 6

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents}
	assert_eq(
		CoordinationConsiderations.plans_laid_before_now(
			deliberation, second.commander).size(), 1,
		"a plan laid last month was still invisible")


func test_a_commander_does_not_coordinate_with_himself() -> void:
	var run := _run()
	_outpost(run, Vector2i(3, 0))
	var alone := _raise(run, Company.COLONIAL, 20, run.colony.in_order()[0].at)

	run.world.month = 5
	_settle(run, alone)
	run.world.month = 6

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents}
	assert_empty(
		CoordinationConsiderations.plans_laid_before_now(
			deliberation, alone.commander),
		"a commander counted his own objective as somebody else's")


func test_the_objective_becomes_an_intent_and_the_company_marches_next_month() -> void:
	# 🔒 The timing rule: committed in month N, executed in phase 2 of N+1.
	var run := _run()
	var target := _outpost(run, Vector2i(4, 0))
	var company := _raise(run, Company.COLONIAL, 20, run.colony.in_order()[0].at)

	run.world.month = 5
	var chosen := _settle(run, company)
	assert_ne(chosen, Company.NOWHERE, "he settled on nowhere at all")
	assert_eq(company.destination, chosen)

	var laid := run.intents.live_for_source(company.commander)
	assert_eq(laid.size(), 1, "his objective did not become an Intent")
	assert_eq(laid[0].kind, MarchingOrders.MARCH_ON)
	assert_eq(laid[0].committed_month, 5)


func test_changing_his_mind_supersedes_his_own_last_objective() -> void:
	var run := _run()
	_outpost(run, Vector2i(4, 0))
	var company := _raise(run, Company.COLONIAL, 20, run.colony.in_order()[0].at)

	run.world.month = 5
	_settle(run, company)
	run.world.month = 6
	company.at = company.at + Vector2i(1, 1)
	_settle(run, company)

	assert_true(run.intents.live_for_source(company.commander).size() <= 1,
		"a commander is marching on two places at once")


# --- 🔒 Failure mode one: everybody converges -------------------------------

func test_two_friendly_companies_do_not_both_march_on_one_village() -> void:
	# 🔒 The acceptance line, *in the ordinary case*. Three colonial companies at
	# equal distance from one undefended town and one other; the second and third
	# must not simply copy the first.
	var run := _run()
	var here := run.colony.in_order()[0].at
	var north := _outpost(run, Vector2i(0, -4))
	var south := _outpost(run, Vector2i(0, 4))

	var companies: Array[Company] = []
	for index in 3:
		companies.append(_raise(run, Company.COLONIAL, 20, here))

	var chosen := PackedStringArray()
	for month in range(5, 5 + companies.size()):
		# A month apart, so each reads the ones before it — which is the lag
		# working, not a contrivance: they would read each other a month later in
		# a real run too.
		run.world.month = month
		chosen.append(str(_settle(run, companies[month - 5])))

	var same := 0
	for one in chosen:
		if one == chosen[0]:
			same += 1
	assert_true(same < 3,
		"all three marched on the same place: %s (north %s, south %s)"
			% [chosen, north.at, south.at])


func test_the_convergence_pressure_is_a_weight_and_not_a_ban() -> void:
	# 🔒 §4 forbids the faction-level assignment, and a hard ban would be one
	# wearing a consideration's coat. Two companies converging on one village is
	# sometimes exactly right, and a commander who wants it enough still takes it.
	var run := _run()
	var target := _outpost(run, Vector2i(3, 0))
	var company := _raise(run, Company.COLONIAL, 20, target.at + Vector2i(1, 0))

	var candidate := Candidate.new(
		StringName("go_to:%d,%d" % [target.at.x, target.at.y]),
		{"company": company, "at": target.at, "town": target, "other": null})

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	run.world.month = 9
	deliberation.data = {"book": run.intents, "map": run.map, "context": _context(run)}

	var alone := CoordinationConsiderations.AlreadyGoingConsideration.new(&"x").score(
		run.contact(company.commander), candidate, deliberation)
	assert_almost_eq(alone, 0.0, 0.0001, "an empty book already discouraged him")

	_lay(run, &"someone_else", Company.COLONIAL, target.at, 3)
	var crowded := CoordinationConsiderations.AlreadyGoingConsideration.new(&"x").score(
		run.contact(company.commander), candidate, deliberation)
	assert_true(crowded < 0.0, "an ally already going there discouraged nobody")
	assert_true(crowded > -100.0 and is_finite(crowded),
		"the discouragement is a veto rather than a weight: %f" % crowded)


# --- 🔒 Failure mode two: nobody covers a gap -------------------------------

func test_a_gap_in_the_line_draws_somebody() -> void:
	# 🔒 The acceptance line. An undefended town with nobody near it must draw a
	# company that has no better reason to be anywhere else.
	var run := _run()
	var capital := run.colony.in_order()[0]
	capital.workers = 40
	var gap := _outpost(run, Vector2i(3, 0))

	# Somebody already stands in the capital, so it is not the gap.
	run.companies.raise_company(
		Company.COLONIAL, 20, {}, capital.id, capital.at, _context(run))
	var free := _raise(run, Company.COLONIAL, 20, capital.at)

	run.world.month = 5
	assert_eq(_settle(run, free), gap.at,
		"a town with nobody in it drew nobody")


func test_a_town_with_somebody_standing_in_it_is_not_a_gap() -> void:
	var run := _run()
	var capital := run.colony.in_order()[0]
	var covered := _outpost(run, Vector2i(3, 0))
	run.companies.raise_company(
		Company.COLONIAL, 20, {}, covered.id, covered.at, _context(run))

	var candidate := Candidate.new(&"go_to", {
		"company": _raise(run, Company.COLONIAL, 20, capital.at),
		"at": covered.at, "town": covered, "other": null})
	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents, "map": run.map, "context": _context(run)}

	assert_almost_eq(
		CoordinationConsiderations.UndefendedConsideration.new(&"x").score(
			null, candidate, deliberation),
		0.0, 0.0001,
		"a garrisoned town still read as undefended")


func test_a_friend_about_to_be_overwhelmed_draws_somebody() -> void:
	var run := _run()
	var capital := run.colony.in_order()[0]
	var beset := _raise(run, Company.COLONIAL, 6, capital.at + Vector2i(2, 0))
	run.companies.raise_company(
		Company.NATIVE, 300, {"guns": 300.0, "tools": 300.0},
		Company.SUPPORTED_BY_CROWN, beset.at, _context(run))

	var rescuer := _raise(run, Company.COLONIAL, 40, capital.at)
	var candidate := Candidate.new(&"go_to", {
		"company": rescuer, "at": beset.at, "town": null, "other": beset})
	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents, "map": run.map, "context": _context(run)}

	assert_true(
		CoordinationConsiderations.OverwhelmedConsideration.new(&"x").score(
			null, candidate, deliberation) > 0.0,
		"a company about to be destroyed called nobody")


func test_a_friend_holding_his_own_calls_nobody() -> void:
	var run := _run()
	var capital := run.colony.in_order()[0]
	var steady := _raise(run, Company.COLONIAL, 300, capital.at + Vector2i(2, 0))
	run.companies.raise_company(
		Company.NATIVE, 6, {}, Company.SUPPORTED_BY_CROWN, steady.at, _context(run))

	var candidate := Candidate.new(&"go_to", {
		"company": _raise(run, Company.COLONIAL, 40, capital.at),
		"at": steady.at, "town": null, "other": steady})
	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents, "map": run.map, "context": _context(run)}

	assert_almost_eq(
		CoordinationConsiderations.OverwhelmedConsideration.new(&"x").score(
			null, candidate, deliberation),
		0.0, 0.0001,
		"a company winning comfortably cried for help")


func test_the_road_that_carries_the_most_is_worth_the_most() -> void:
	var run := _run()
	var capital := run.colony.in_order()[0]
	var east := _outpost(run, Vector2i(6, 0))
	var west := _outpost(run, Vector2i(-6, 0))

	var company := _raise(run, Company.COLONIAL, 20, capital.at)
	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, run.world, run.log)
	deliberation.data = {"book": run.intents, "map": run.map, "context": _context(run)}

	var crossroads := Candidate.new(&"go_to", {
		"company": company, "at": capital.at + Vector2i(3, 0),
		"town": null, "other": null})
	var nowhere := Candidate.new(&"go_to", {
		"company": company, "at": capital.at + Vector2i(0, 5),
		"town": null, "other": null})

	var road := CoordinationConsiderations.OnlyRoadConsideration.new(&"x")
	assert_true(
		road.score(null, crossroads, deliberation)
			> road.score(null, nowhere, deliberation),
		"a tile on the road between %s and %s was worth no more than empty country"
			% [east.at, west.at])


# --- 🔒 The considerations read the IntentBook and nothing else -------------

func test_coordination_reads_plans_and_never_the_companies_own_decisions() -> void:
	# 🔒 The acceptance line. A consideration that reached into another company's
	# *state* — its destination field, say — would be reading a decision with no
	# lag on it at all, and the whole one-month property would be gone.
	var found := PackedStringArray()
	var code := _code_of("res://sim/battle/coordination_considerations.gd")
	for token in [".destination", "urged", "order ="]:
		if code.contains(token):
			found.append(token)
	assert_empty(found,
		"coordination reads a company's own decision rather than its Intent: %s"
			% ", ".join(found))


# --- Measuring the two failure modes ----------------------------------------

func test_the_two_failure_modes_are_measured() -> void:
	# 🔒 §4's acceptance: *both failure modes are measured and reported, whether
	# or not they appear.* A scenario rather than a harness sweep — the balance
	# job owns long runs — but the instrument is here and says a number.
	#
	# Six companies, three undefended towns, every company equidistant. Perfect
	# coordination puts two on each; total convergence puts six on one; nobody
	# covering leaves towns empty.
	var run := _run()
	var here := run.colony.in_order()[0].at
	var targets: Array[Town] = [
		_outpost(run, Vector2i(0, -4)),
		_outpost(run, Vector2i(4, 0)),
		_outpost(run, Vector2i(0, 4)),
	]

	var companies: Array[Company] = []
	for index in 6:
		companies.append(_raise(run, Company.COLONIAL, 20, here))

	var going: Dictionary = {}
	for index in companies.size():
		run.world.month = 5 + index
		var chosen := _settle(run, companies[index])
		going[chosen] = int(going.get(chosen, 0)) + 1

	var covered := 0
	for target in targets:
		if going.has(target.at):
			covered += 1
	var worst := 0
	for place in going:
		worst = maxi(worst, int(going[place]))

	# Reported whether or not they appear, which is what §4 asks for.
	print("    coordination: %d of %d towns covered, worst pile-up %d of %d"
		% [covered, targets.size(), worst, companies.size()])

	assert_true(worst < companies.size(),
		"convergence: all %d marched on one place" % companies.size())
	assert_true(covered > 0,
		"the gap: %d towns stood open and nobody went to any of them"
			% targets.size())


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


## Put a plan in the book as though somebody else had laid it, months ago.
func _lay(
	run: RunState, source: StringName, allegiance: StringName,
	at: Vector2i, month: int
) -> void:
	var intent := Intent.new(
		&"", MarchingOrders.MARCH_ON, source,
		StringName("%d,%d" % [at.x, at.y]), 12,
		{"allegiance": String(allegiance), "at": [at.x, at.y]})
	run.intents.commit(intent, run.log, month)


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
	assert_false(out.is_empty(), "no scripts were found under %s" % at)
	return out
