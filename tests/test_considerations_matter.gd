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
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
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
func _ordinary(loyalty: float = 60.0) -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.relationship = Relationship.new(&"gov_ashmere", loyalty)
	for id in IntentConsiderations.ALL:
		contact.set_weight(StringName(id), 1.0)
	return contact


func _deaf_to(id: StringName, loyalty: float = 60.0) -> Contact:
	var contact := _ordinary(loyalty)
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
	town.workers = 20_000
	town.governor_id = &"gov_ashmere"
	town.quality_of_life = 0.8
	town.store(&"food", 400.0)
	town.store(&"clothing", 60.0)
	# **And comfortable** (#428): a town with an empty purse craves wealth so
	# hard that get rich wins every vote and nothing else can be shown to tip one.
	town.receive_gold(5_000.0)
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
## The peoples already here, put where they will be in a town's way.
##
## **Villages rather than a bare tribe**, because `native_land` measures fields
## and a tribe with nowhere to live holds none of them.
func _natives(where: Array = []) -> Tribes:
	var natives := Tribes.new()
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): 50.0}
	natives.all.append(tribe)
	for index in where.size():
		var village := Village.new()
		village.id = StringName("village_test_%d" % index)
		village.tribe = tribe.id
		village.at = where[index]
		village.people = 30_000
		natives.villages.append(village)
	return natives


func _context(
	town: Town,
	values: Dictionary = {},
	month: int = 6,
	natives: Tribes = null,
) -> DeliberationContext:
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
		"mandate": String(GovernorIntent.GET_RICH),
		"urgings": town.urgings,
		"natives": natives if natives != null else _natives(),
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
	# **Loyalty lives on the man, not the town** (#428), so a world that means to
	# vary it says how loyal both governors are.
	var loyalty := float(context.data.get(LOYAL, 60.0))
	return _wants(_ordinary(loyalty), context) != _wants(_deaf_to(id, loyalty), context)


## The key a world uses to say how loyal its governors are.
const LOYAL: String = "test_loyalty"


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
		IntentConsiderations.BASELINE:
			# **An untroubled town**, which is where the baseline speaks: every
			# problem row reads nought, and the mandate fades across the months.
			for month in MONTHS:
				worlds.append(_context(_town(), {}, month))
				worlds.append(_crowded_context(_town(), month))
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
		IntentConsiderations.WEALTH:
			# **The town's own purse**, from nothing to more than comfortable.
			for gold in [0.0, 300.0, 1_200.0, 6_000.0]:
				for month in MONTHS:
					var town := _town()
					town.spend_share(1.0)
					town.receive_gold(gold)
					worlds.append(_context(town, {}, month))
		IntentConsiderations.SAFETY:
			# **How unsafe the town felt**, from untouched to overrun.
			for safety in [1.0, 0.7, 0.3, 0.0]:
				for month in MONTHS:
					var town := _town()
					town.safety = safety
					worlds.append(_context(town, {}, month))
		IntentConsiderations.ROOM:
			# Open country, and the same town with nothing left to claim.
			for month in MONTHS:
				worlds.append(_context(_town(), {}, month))
				worlds.append(_crowded_context(_town(), month))
		IntentConsiderations.CROWDING:
			# **Mouths against workable ground**, so the worlds are towns of very
			# different sizes on the same country. A town of twenty thousand with
			# room to work is not crowded; the same country with two hundred
			# thousand in it is.
			for people in [8_000, 20_000, 60_000, 200_000]:
				for month in MONTHS:
					var packed := _town()
					packed.workers = people
					worlds.append(_context(packed, {}, month))
		IntentConsiderations.LOYALTY:
			# **From a contented man to one who loathes the PC**, stopping short
			# of the rebellion floor so the vote is between the ordinary intents.
			# Across how safe the town feels too: loyalty pushes away from the
			# Crown's purposes, and it tips a vote only where one is close.
			for loyalty in [70.0, 50.0, 30.0, 15.0]:
				for safety in [1.0, 0.6, 0.4]:
					for month in MONTHS:
						var town := _town()
						town.safety = safety
						var context := _crowded_context(town, month)
						context.data[LOYAL] = loyalty
						worlds.append(context)
		IntentConsiderations.MANDATE:
			for mandate in GovernorIntent.IN_ORDER:
				for month in MONTHS:
					var context := _context(_town(), {}, month)
					context.data["mandate"] = String(mandate)
					worlds.append(context)
		IntentConsiderations.URGING:
			for month in MONTHS:
				worlds.append(_context(_town(), {}, month))
				for urged in GovernorIntent.PC_URGES:
					var town := _town()
					town.urge(Urging.from_pc(urged, month))
					worlds.append(_context(town, {}, month))
	return worlds


func test_the_baseline_can_decide() -> void:
	# §13: **what an untroubled town wants.** Without it, tall and rich could win
	# a quiet town only through the mandate or a letter.
	assert_true(_matters_somewhere(IntentConsiderations.BASELINE,
		_worlds_for(IntentConsiderations.BASELINE)),
		"a governor who wants a quiet life of building and trade wanted what one who does not wanted")


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


func test_wealth_can_decide() -> void:
	# **Get rich serves the town's own purse** (§13), so it is the town's gold
	# that has to be able to move a man.
	assert_true(_matters_somewhere(IntentConsiderations.WEALTH,
		_worlds_for(IntentConsiderations.WEALTH)),
		"caring about the town's purse never changed a governor's mind, rich or poor")


func test_safety_can_decide() -> void:
	# **Military is always available and safety is what drives it** (§2).
	assert_true(_matters_somewhere(IntentConsiderations.SAFETY,
		_worlds_for(IntentConsiderations.SAFETY)),
		"caring how safe the town is never changed a governor's mind")


func test_room_to_grow_can_decide() -> void:
	# §13's one opportunity rather than problem: go wide's first move is a
	# scouting company to find land, so there is no floor under it any more.
	assert_true(_matters_somewhere(IntentConsiderations.ROOM,
		_worlds_for(IntentConsiderations.ROOM)),
		"land the colony could see and had not claimed never changed a governor's mind")


func test_loyalty_can_decide() -> void:
	# **New** (§13): a man whose regard for the PC has fallen wants the Crown's
	# purposes less, long before he wants to rebel.
	assert_true(_matters_somewhere(IntentConsiderations.LOYALTY,
		_worlds_for(IntentConsiderations.LOYALTY)),
		"how far a governor's loyalty had fallen never changed what he wanted")


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


func test_a_letter_is_not_a_standing_order_and_not_a_shout_either() -> void:
	# 🔒 The shape of the decay, not the figure. `URGING_HALF_LIFE` is tuning and
	# a test pinned to it would be a test against a moving value — but the
	# property either side of it is the design (#212):
	#
	# | | |
	# | :--- | :--- |
	# | Ruling | a governor urged this spring is still leaning that way in the autumn |
	# | Not nagging | and the PC did not have to write three times to get there |
	# | Not a standing order | and he is running his own town again years later |
	#
	# At six months the middle row failed: the PC re-sent the same instruction
	# two or three times a year to hold a man on course.
	var half_life := IntentConsiderations.URGING_HALF_LIFE
	assert_true(IntentConsiderations.decayed(6.0, half_life) > 0.5,
		"half a year on, the PC's letter is already spent and he must write again")
	assert_true(IntentConsiderations.decayed(60.0, half_life) < 0.1,
		"one letter was still steering the town five years later, which is a standing order")


func test_crown_urging_can_decide() -> void:
	# **The one the whole game rests on.** SPEC §8.5 makes a letter arguing for a
	# goal the PC's only lever on a town; a consideration that could not move a
	# decision would make every letter he writes decoration.
	assert_true(_matters_somewhere(IntentConsiderations.URGING,
		_worlds_for(IntentConsiderations.URGING)),
		"the PC wrote arguing for a goal and it changed nothing a governor wanted")


## The same town with nothing left to settle, so `room` reads zero.
func _crowded_context(town: Town, month: int = 6) -> DeliberationContext:
	var context := _context(town, {}, month)
	var map: WorldMap = context.get_value("map")
	var colony: Colony = context.get_value("colony")
	for y in map.height:
		for x in map.width:
			if map.is_land(x, y):
				map.set_terrain(x, y, &"ocean")
	context.data["territory"] = Territory.compute(map, colony.in_order())
	return context


# --- 🔒 And the ones that cannot, and why -----------------------------------

func test_a_row_whose_problem_is_absent_says_nothing() -> void:
	# 🔒 §13: a measure at nought **does nothing** — it does not push the other
	# way. A safe town's safety row scores nought for every intent.
	var town := _town()
	town.safety = 1.0
	for candidate in _candidates():
		var score := IntentConsiderations.Safety.new().score(_ordinary(), candidate, _context(town))
		assert_almost_eq(score, 0.0, 0.0001,
			"safety has an opinion about %s in a town nobody threatens" % candidate.id)


# --- 🔒 The whole set is accounted for --------------------------------------

func test_every_registered_consideration_is_covered_here() -> void:
	# **The gate.** A consideration added without a case in this file would be
	# one nobody had asked whether it can decide anything — which is how the four
	# on #90 got there.
	var covered: PackedStringArray = [
		IntentConsiderations.BASELINE,
		IntentConsiderations.FOOD,
		IntentConsiderations.COMFORT,
		IntentConsiderations.WEALTH,
		IntentConsiderations.SAFETY,
		IntentConsiderations.ROOM,
		IntentConsiderations.CROWDING,
		IntentConsiderations.LOYALTY,
		IntentConsiderations.MANDATE,
		IntentConsiderations.URGING,
	]
	for id in IntentConsiderations.ALL:
		assert_true(covered.has(String(id)),
			"'%s' is registered and this file does not ask whether it can decide anything" % id)
	assert_eq(covered.size(), IntentConsiderations.ALL.size(),
		"this file covers a consideration that is no longer registered")
