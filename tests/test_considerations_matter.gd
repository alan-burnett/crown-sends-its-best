extends TestCase

## Every consideration can change a decision (#90).
##
## 🔒 **A consideration that never changes an outcome is the deliberation
## layer's version of a registered effect no letter uses** (#139). It looks
## wired, it appears in every trace, and it decides nothing — and nothing fails.
##
## The balance harness reports which considerations actually drive behaviour, and
## it has consistently found some contributing a hundredth of what the others do.
## That report answers *are they mattering in play*, which is a tuning question.
## **This file answers a different and prior one: can they matter at all.**
##
## The distinction is the whole point. A consideration that cannot move an
## outcome under any input is broken. One that can, but whose input never varies
## in a real colony, is working correctly and telling us something about the
## world instead — which is a finding for the world rather than a bug in the
## consideration.

const SEED: int = 3307

## A fresh commission, a year in, and long after anybody remembers it.
const MONTHS: Array[int] = [2, 14, 48]

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


## A governor with an ordinary temperament, and one deaf to a single thing.
##
## **This is the question that matters, and my first version asked a different
## one.** Silencing everything but one consideration asks *which candidate does
## this one like best*, and several of them always like the same candidate —
## `Comfort` always leans towards the people, whether the town is wretched or
## merely tired. On its own it can never change a winner, which made it look
## broken when it is not.
##
## What a consideration is *for* is tipping a vote the others left close. So the
## honest test is to compare a governor who weighs it against the same governor,
## in the same world, who does not.
func _ordinary() -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.relationship = Relationship.new(&"gov_ashmere", 60.0)
	for id in IntentConsiderations.ALL:
		contact.set_weight(StringName(id), 1.0)
	return contact


func _deaf_to(id: StringName) -> Contact:
	var contact := _ordinary()
	contact.set_weight(id, 0.0)
	return contact


## An unremarkable town.
##
## **Fed, and that matters.** The first version of this fixture had an empty
## larder, so hunger pinned every decision to survival and silencing any other
## consideration changed nothing — which read as five broken considerations and
## was one broken fixture. A consideration can only be shown to tip a close vote
## in a world where the vote is close.
func _town() -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(4, 4))
	town.workers = 20
	town.governor_id = &"gov_ashmere"
	town.quality_of_life = 0.8
	town.store(&"food", 400.0)
	town.store(&"clothing", 60.0)
	return town


## A country with somewhere left to go.
##
## **Bigger than it looks necessary**, and that is the point: the first version
## of this map was a five-by-five block with the town in the middle of it, so
## every land tile the town could see was already inside its own border. `room`
## read zero, settling was filtered out of every decision, and `room_to_grow`
## looked inert when it was only boxed in.
func _map() -> WorldMap:
	var map := WorldMap.new(24, 24, &"ocean")
	for y in range(2, 22):
		for x in range(2, 22):
			map.set_terrain(x, y, &"plains")
	return map


## `month` matters more than it looks.
##
## **The Crown's mandate decays over a run** and it is the loudest voice in a
## governor's head while it is fresh — at month six it swings a full point
## between the candidate it names and every other, which is more than any single
## consideration can answer. So a world where anything else gets to decide is a
## world where the mandate has faded, and that is the design rather than a
## workaround: a letter from the PC matters more in year four than in year one.
func _context(town: Town, values: Dictionary = {}, month: int = 6) -> DeliberationContext:
	var state := WorldValues.initial_state()
	for key in values:
		state.values[key] = values[key]
	state.month = month

	var colony := Colony.new()
	colony.add(town)
	var map := _map()

	var context := DeliberationContext.new(DecisionKind.GOVERNOR_INTENT, state, EventLog.new())
	context.month = month
	context.rng = RngStreams.new(SEED).contact_stream("gov_ashmere")
	# **Exactly the keys `GovernorDriver` supplies**, and no others. A fixture
	# that invented its own would test a governor nobody ever deliberates as —
	# `CrownUrging` reads `urged` from the context rather than from the town, and
	# a fixture putting it only on the town had the PC's one lever scoring zero.
	context.data = {
		"town": town,
		"colony": colony,
		"map": map,
		"territory": Territory.compute(map, colony.in_order()),
		"mandate": String(GovernorIntent.ECONOMY),
		"urged": String(town.urged_intent),
		"urged_month": town.urged_month,
	}
	return context


func _candidates() -> Array:
	var out: Array = []
	for intent in GovernorIntent.IN_ORDER:
		out.append(Candidate.new(intent, {}))
	return out


func _wants(governor: Contact, context: DeliberationContext) -> String:
	var decision := Deliberation.choose(governor, _candidates(), context)
	return String(decision.chosen_id()) if decision.has_choice() else ""


## Whether caring about `id` changes what this governor wants, in this world.
##
## The two governors are identical but for one weight, and the world is the same
## world, so a difference in what they want is that consideration and nothing
## else.
func _changes_the_answer(id: StringName, context: DeliberationContext) -> bool:
	return _wants(_ordinary(), context) != _wants(_deaf_to(id), context)


## Whether it changes the answer in **any** of these worlds.
##
## A consideration only has to matter somewhere. One that matters nowhere is the
## thing this file is for.
func _matters_somewhere(id: StringName, worlds: Array) -> bool:
	for context in worlds:
		if _changes_the_answer(id, context):
			return true
	return false


# --- 🔒 Each one can move an outcome ----------------------------------------

## The range of worlds a colony actually passes through, as far as each
## consideration's own input is concerned. If caring about a thing never changes
## a governor's mind across all of them, it is decoration.
func _worlds_for(id: StringName) -> Array:
	var worlds: Array = []
	match id:
		IntentConsiderations.FOOD:
			for held in [0.0, 200.0, 1_200.0, 6_000.0]:
				for month in MONTHS:
					var town := _town()
					town.stockpile["food"] = held
					worlds.append(_context(town, {}, month))
		IntentConsiderations.COMFORT:
			for quality in [0.02, 0.25, 0.6, 0.85, 0.99]:
				for month in MONTHS:
					var town := _town()
					town.quality_of_life = quality
					worlds.append(_context(town, {}, month))
		IntentConsiderations.REVENUE:
			for revenue in [0.0, 40.0, 400.0, 4_000.0]:
				for month in MONTHS:
					worlds.append(_context(_town(), {WorldValues.REVENUE: revenue}, month))
		IntentConsiderations.ROOM:
			# **Across revenues as well as months.** A colony returning well makes
			# the economy so attractive that nothing else gets a hearing, and room
			# is the quietest voice in the room — worth at most a third of a point
			# to growing the population, since a one-town colony can never see
			# enough unclaimed land for settling itself to score positive.
			for month in MONTHS:
				for revenue in [0.0, 40.0, 400.0]:
					worlds.append(_context(_town(), {WorldValues.REVENUE: revenue}, month))
					worlds.append(_crowded_context(_town(), month, revenue))
		IntentConsiderations.CROWDING:
			# **Mouths against workable ground**, so the worlds are towns of very
			# different sizes on the same country. A town of twenty with room to
			# work is not crowded; the same country with two hundred in it is.
			for people in [8, 20, 60, 200]:
				for month in MONTHS:
					var packed := _town()
					packed.workers = people
					worlds.append(_context(packed, {}, month))
		IntentConsiderations.MANDATE:
			for mandate in GovernorIntent.IN_ORDER:
				for month in MONTHS:
					var context := _context(_town(), {}, month)
					context.data["mandate"] = String(mandate)
					worlds.append(context)
		IntentConsiderations.URGING:
			for month in MONTHS:
				worlds.append(_context(_town(), {}, month))
				for urged in GovernorIntent.IN_ORDER:
					var town := _town()
					town.urged_intent = urged
					town.urged_month = month
					worlds.append(_context(town, {}, month))
		IntentConsiderations.THREAT:
			for month in MONTHS:
				worlds.append(_context(_town(), {}, month))
	return worlds


func test_food_security_can_decide() -> void:
	assert_true(_matters_somewhere(IntentConsiderations.FOOD,
		_worlds_for(IntentConsiderations.FOOD)),
		"caring about food never changed a governor's mind, empty larder or full")


func test_comfort_can_decide() -> void:
	# **The one the harness keeps reporting as inert.** It is not broken: a
	# governor who weighs how his people live wants something different of a
	# wretched town than a governor who does not weigh it at all.
	#
	# What the harness is reporting is that **no colony is ever wretched** — mean
	# quality of life sits at 0.90 to 0.95 across every reference player and every
	# year. That is a finding about the world, not about this.
	assert_true(_matters_somewhere(IntentConsiderations.COMFORT,
		_worlds_for(IntentConsiderations.COMFORT)),
		"caring how the people live never changed a governor's mind at any quality of life")


func test_revenue_can_decide() -> void:
	assert_true(_matters_somewhere(IntentConsiderations.REVENUE,
		_worlds_for(IntentConsiderations.REVENUE)),
		"caring about the returns never changed a governor's mind, rich or poor")


func test_room_to_grow_cannot_decide_yet_and_here_is_why() -> void:
	# **Recorded rather than engineered around**, because it is a finding.
	#
	# Room speaks through two candidates and neither can hear it yet. Settling is
	# M4: a one-town colony never sees enough unclaimed land for `room * 2 - 1`
	# to go positive — the most a single town's own border leaves unclaimed
	# inside what it can see is about 0.44 — so settling scores negative in every
	# world reachable today. That leaves `room * 0.3` on growing the population,
	# about a tenth of a point, which is a third of what the quietest of the
	# others manages.
	#
	# So it is not broken and it is not tunable into relevance: **it is waiting
	# for a second town.** When M4 founds one this test will start failing, which
	# is exactly when somebody should look at it again.
	#
	# **That moment has been looked at** (#175). The answer was not to tune this
	# one into relevance but to add a second consideration beside it: `crowding`
	# measures mouths against workable ground and has no such floor, so a
	# pragmatic governor can settle before any frontier has been surveyed. Two
	# considerations mean two weights and therefore two kinds of man — the
	# ambitious one who goes because there is land, and the pragmatic one who
	# goes because there are too many mouths — where a single blended term would
	# have collapsed both into the same character.
	#
	# This case stays as it is until a second town exists, which is what it has
	# been correctly saying all along.
	assert_false(_matters_somewhere(IntentConsiderations.ROOM,
		_worlds_for(IntentConsiderations.ROOM)),
		"room to grow can now change a governor's mind — M4 has arrived, so move "
		+ "this case up with the others and give it a world where it decides")


func test_crowding_can_decide() -> void:
	# **The consideration that unblocks settling** (#175). `room_to_grow` cannot
	# fire in a one-town colony by construction — the most unclaimed land a single
	# town's border leaves inside what it can see is about 0.44, so `room * 2 - 1`
	# is negative in every world reachable before a second town exists.
	#
	# Crowding has no such floor. **A town too full for its fields is too full
	# whether or not anyone has surveyed the frontier**, so the chicken and egg
	# breaks: the pragmatic governor settles because there are too many mouths,
	# and the ambitious one can start wanting land once there is a colony to see
	# it from.
	assert_true(_matters_somewhere(IntentConsiderations.CROWDING,
		_worlds_for(IntentConsiderations.CROWDING)),
		"a town of two hundred on one town's ground wanted exactly what a hamlet wanted")


func test_the_mandate_can_decide() -> void:
	assert_true(_matters_somewhere(IntentConsiderations.MANDATE,
		_worlds_for(IntentConsiderations.MANDATE)),
		"caring what the Crown sent him for never changed what a governor wanted")


func test_crown_urging_can_decide() -> void:
	# **The one the whole game rests on.** SPEC §8.5 makes a letter arguing for a
	# goal the PC's only lever on a town; a consideration that could not move a
	# decision would make every letter he writes decoration.
	assert_true(_matters_somewhere(IntentConsiderations.URGING,
		_worlds_for(IntentConsiderations.URGING)),
		"the PC wrote arguing for a goal and it changed nothing a governor wanted")


## The same town with nothing left to settle, so `room` reads zero.
func _crowded_context(town: Town, month: int = 6, revenue: float = 40.0) -> DeliberationContext:
	var context := _context(town, {WorldValues.REVENUE: revenue}, month)
	var map: WorldMap = context.get_value("map")
	var colony: Colony = context.get_value("colony")
	for y in map.height:
		for x in map.width:
			if map.is_land(x, y):
				map.set_terrain(x, y, &"ocean")
	context.data["territory"] = Territory.compute(map, colony.in_order())
	return context


# --- 🔒 And the ones that cannot, and why -----------------------------------

func test_native_threat_is_inert_and_that_is_correct() -> void:
	# **Distinct from a bug.** Natives are M5. `deliberation.md` requires a
	# consideration whose inputs do not move yet to read as *no opinion* rather
	# than as *no* — a consideration quietly scoring against a candidate because
	# its system does not exist would suppress intents for a reason nobody
	# intended.
	var town := _town()
	for candidate in _candidates():
		var score := IntentConsiderations.NativeThreat.new().score(
			_ordinary(), candidate, _context(town)
		)
		assert_almost_eq(score, 0.0, 0.0001,
			"native threat has an opinion about %s before natives exist" % candidate.id)


# --- 🔒 The whole set is accounted for --------------------------------------

func test_every_registered_consideration_is_covered_here() -> void:
	# **The gate.** A consideration added without a case in this file would be
	# one nobody had asked whether it can decide anything — which is how the four
	# on #90 got there.
	# The two that cannot decide anything yet, each waiting on a milestone rather
	# than on a tuning pass. **Anything else joining them is a bug**, and
	# anything leaving them means its milestone has landed.
	var waiting: PackedStringArray = [
		IntentConsiderations.THREAT,  # natives are M5
		IntentConsiderations.ROOM,    # a second town is M4
	]
	for id in waiting:
		assert_false(_matters_somewhere(StringName(id), _worlds_for(StringName(id))),
			"'%s' can decide something now, so it is no longer waiting on anything" % id)

	var covered: PackedStringArray = [
		IntentConsiderations.FOOD,
		IntentConsiderations.COMFORT,
		IntentConsiderations.REVENUE,
		IntentConsiderations.ROOM,
		IntentConsiderations.CROWDING,
		IntentConsiderations.MANDATE,
		IntentConsiderations.URGING,
		IntentConsiderations.THREAT,
	]
	for id in IntentConsiderations.ALL:
		assert_true(covered.has(String(id)),
			"'%s' is registered and this file does not ask whether it can decide anything" % id)
	assert_eq(covered.size(), IntentConsiderations.ALL.size(),
		"this file covers a consideration that is no longer registered")
