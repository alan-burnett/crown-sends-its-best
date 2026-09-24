class_name ObjectiveSelector
extends RefCounted

## What the town does about its governor's intent
## (`docs/mechanics/governor-objectives.md` §5).
##
## ## 🔒 Deterministic. No personality, no weights, no dice.
##
## The governor has wise and honourable advisors. **He never picks a foolish
## project** — he picks an excellent project in service of a goal the player may
## think is completely wrong, and arguing with the goal is the game.
##
## A personality weight anywhere in this file breaks the design, and a town that
## builds badly reads as a bug rather than as character. The mechanics doc marks
## three rows *no*: choosing an objective, detecting a stall, choosing a tile.
## All three live here.
##
## ## How the scoring works
##
## Every candidate — a building, an improvement on a particular tile, a standing
## posture — is measured on the same six axes, and the intent says what the axes
## are worth (`GovernorIntent.PROFILES`). Adding an intent is adding a row;
## adding a kind of objective is teaching this to measure one more thing. Neither
## is a branch on which intent it is.
##
## ## Ties
##
## Broken by a **hash of the run seed with the town and the candidate**. Fixed by
## the seed, as the doc requires, but not *drawn* — nothing here consumes from an
## RNG stream, so a tie cannot shift every later draw in the colony.

const EVENT_CHOSEN: StringName = &"objective_chosen"

## How much a long or expensive project is marked down. Two identical benefits
## are not equally good if one takes four months (tuning).
const COST_PENALTY: float = 0.35

## Below this an objective is not worth starting at all.
const WORTH_DOING: float = 0.01

## What a share of every future month is worth beside a single month of it.
##
## A sawmill raising timber by three fifths does so **for the rest of the run**.
## Without this a permanent improvement scores like a good week and the town
## never builds anything (tuning).
const LASTING: float = 2.5

## What one unit of extra yield on one tile is worth.
const PER_UNIT_YIELD: float = 0.1

## What a standing posture is worth.
##
## **Deliberately modest.** A posture costs nothing and finishes instantly, so
## anything generous makes it beat every project on the board for ever, and a
## colony that only ever works harder at what it already does is not a colony
## with a governor. It is the answer when there is nothing worth building —
## which is exactly what it should be.
const POSTURE_WORTH: float = 0.08


## What the town should work on, given the intent. Returns `{id, target}`, with
## `target` a tile for an improvement and `Vector2i(-1, -1)` otherwise.
##
## `excluding` drops candidates the town has just given up on, so a stalled
## objective is not immediately chosen again.
static func choose(
	town: Town,
	intent: StringName,
	context: ColonyContext,
	excluding: PackedStringArray = PackedStringArray(),
) -> Dictionary:
	var nothing: Dictionary = {"id": &"", "target": Vector2i(-1, -1), "score": 0.0}
	if not GovernorIntent.is_intent(intent):
		return nothing

	var best: Dictionary = nothing
	var best_key: int = 0
	for candidate in candidates(town, context, intent):
		if excluding.has(String(candidate["id"])):
			continue
		var score := float(candidate["score"])
		if score <= WORTH_DOING:
			continue
		var key := _tiebreak(context.run_seed, town.id, StringName(candidate["id"]))
		if best["id"] == &"" or score > float(best["score"]) + 0.0001:
			best = candidate
			best_key = key
		elif absf(score - float(best["score"])) <= 0.0001 and key < best_key:
			best = candidate
			best_key = key
	return best


## Everything the town could work on, scored. Sorted by id, so the list itself
## carries no ordering information the scoring did not put there.
static func candidates(town: Town, context: ColonyContext, intent: StringName = &"") -> Array:
	var out: Array = []
	# Scored against the intent asked about, never against whatever the town
	# happens to hold — `choose()` is asked "what would serve this?", and a town
	# whose governor changed his mind this month must not be scored against last
	# month's answer.
	if String(intent).is_empty():
		intent = town.intent

	for id in Building.available_to(town):
		if not _can_obtain_all(town, Building.find(StringName(id)).cost, context):
			continue
		out.append({
			"id": StringName(id),
			"target": Vector2i(-1, -1),
			"score": _scored(
				_building_axes(StringName(id)), intent,
				_months_for(town, Building.find(StringName(id)).cost),
			),
		})

	for id in Improvement.ids():
		var improvement := Improvement.find(StringName(id))
		if improvement.natural:
			continue  # Roads come of trade, not of orders (SPEC §11.1).
		if not _can_obtain_all(town, improvement.cost, context):
			continue
		var sited := _best_tile_for(town, improvement, context)
		if sited["at"] == Vector2i(-1, -1):
			continue
		out.append({
			"id": StringName(id),
			"target": sited["at"],
			"score": _scored(sited["axes"], intent, _months_for(town, improvement.cost)),
		})

	# **An expedition is an ordinary candidate** (#175). It is scored on the same
	# axes as everything else, so a governor set on settling wants one for the
	# reason he wants one and nothing here branches on which intent it is.
	#
	# 🔒 A rebel town never takes it — a filter, not a weight, so a very
	# expansionist rebel governor cannot outvote SPEC §11.4.
	if Expedition.may_launch(town):
		for id in Objective.expedition_ids():
			out.append({
				"id": StringName(id),
				"target": Vector2i(-1, -1),
				"score": _scored(_expedition_axes(town), intent, EXPEDITION_MONTHS),
			})

	# 🔒 **Raising a company is an ordinary candidate too** (#342). Scored on the
	# same axes as a granary, which is the only way a governor can decline to
	# raise one because the harvest matters more — and that refusal is the thing
	# that makes raising one mean something.
	#
	# 🔒 A town that cannot keep enough workers to work never offers it, and a
	# rebel town never does: filters, not weights, for the same reason the
	# expedition's are.
	if Raising.may_raise(town):
		for id in Objective.company_ids():
			out.append({
				"id": StringName(id),
				"target": Vector2i(-1, -1),
				"score": _scored(_company_axes(town), intent, COMPANY_MONTHS),
			})

	for id in Objective.posture_ids():
		out.append({
			"id": StringName(id),
			"target": Vector2i(-1, -1),
			"score": _scored(_posture_axes(StringName(id), town, context), intent, 1),
		})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))
	return out


# --- Scoring ----------------------------------------------------------------

## Axes against the intent's profile, marked down for how long it takes.
static func _scored(axes: Dictionary, intent: StringName, months: int) -> float:
	var total := 0.0
	for axis in GovernorIntent.AXES:
		total += float(axes.get(axis, 0.0)) * GovernorIntent.value_of(intent, axis)
	return total / (1.0 + COST_PENALTY * float(maxi(0, months - 1)))


## How long this town would take over a thing costing this (#148).
##
## **Derived, never stored.** A building authors one number — its cost — and the
## schedule falls out of the town that is building it, so a large town really is
## quicker and the governor's preference for a short project means something
## different in a big town than a small one.
static func _months_for(town: Town, cost: Dictionary) -> int:
	var total := 0.0
	for resource in cost:
		total += float(cost[resource])
	return maxi(1, int(ceil(total / maxf(0.001, Objective.build_capacity(town)))))


## How many scholars a governor imagines his town might hold.
##
## **A library is worth nothing to a town with no experts and a great deal to one
## with several**, and the selector cannot know which this town will become. So
## it prices the building on a plausible few rather than on today's count, which
## is the difference between a tree a town can grow into and one it can only ever
## react to. Tuning.
const EXPERTS_A_TOWN_MIGHT_HOLD: float = 3.0


## What entertaining the whole town is worth beside a point of quality of life.
##
## Amusement is a share of the population rather than a flat figure, so it needs
## a scale to sit on the same axis. Generous, because unlike a comfort bought
## with gold it cannot be cut off — and tuning.
const AMUSEMENT_WORTH: float = 3.0


## What the comfort of a church is worth beside the amusement of one.
##
## **Less than amusement, deliberately.** Amusement is had every month; perceived
## safety only pays when the town has something to be frightened of, because it
## lifts what danger has left rather than adding to a town in no danger at all.
## A governor who could want a church as hard as a theatre would build one in a
## quiet valley and get nothing for it.
##
## Tuning.
const COMFORT_OF_FAITH: float = 1.8


## What one more unit a worker-month of a conversion is worth.
##
## A yield bonus is a share of everything the town will ever produce and is
## weighted by `LASTING` for it. A conversion margin is already in units a month,
## so it needs a scale of its own rather than that one — and it is lasting in the
## same way, which is why this is not small. Tuning (#311).
const CONVERSION_WORTH: float = 0.35


## How long a governor reckons an expedition takes to gather.
##
## Not derived from its cargo, because the cargo is derived from what the town
## can spare and a town that can spare a great deal would otherwise reckon its
## expedition *quick* — the opposite of true. Tuning.
const EXPEDITION_MONTHS: int = 4


## What founding another town is good for.
##
## **Expansion, and nothing else.** It costs the parent people, stores and coin,
## so a governor who is not trying to grow the colony should never want one, and
## the axes say so rather than a rule saying so.
static func _expedition_axes(town: Town) -> Dictionary:
	# A crowded town gets more out of shedding people than a roomy one, which is
	# the overflow case arriving through the same scoring as the deliberate one.
	var crowding := clampf(float(town.population()) / CROWDED, 0.0, 2.0)
	return {"expansion": 0.5 + 0.5 * crowding}


## How long a governor reckons putting men under arms takes.
##
## **Quicker than an expedition**, because the men are already here and the arms
## are already in the warehouse — what takes the months is deciding, arming and
## drilling rather than crossing country. Tuning.
const COMPANY_MONTHS: int = 2


## What a company is good for.
##
## **Defence, and a little capacity denied.** It costs the town workers it will
## not get back and stores it has been holding, so a governor who is not thinking
## about being attacked should never want one — and the axes say so rather than a
## rule saying so.
##
## The negative on capacity is the honest half: men under arms are men not
## working tiles, which is what a governor weighing a company against a granary
## is actually weighing.
static func _company_axes(town: Town) -> Dictionary:
	# A town with the guns already bought gets more out of raising than one that
	# would send a mob — which is what the defensive intents' stockpiling was
	# always for.
	var armed := clampf(
		town.held(&"guns") / maxf(1.0, float(Raising.size_for(town))), 0.0, 1.0)
	return {"defence": 0.6 + 0.4 * armed, "capacity": -0.3}


## The population at which a governor starts thinking about room.
##
## **The shared open item** between this and `immigration.md` §10 — how crowded
## and how poor before a town sheds people — and it wants tuning against #170
## rather than being settled here.
const CROWDED: float = 60_000.0


## What a building is good for, read out of its effects rather than its name.
##
## Nothing here knows what a granary is. Add a building to the data and the
## governor can already want it for the right reasons.
## What a building is good for, for anything outside this file (#151).
##
## **Upkeep asks it what the governor would give up first**, and asking it here
## rather than scoring a building twice is the difference between a man who lets
## the church go dark because he is at war and a man who does it because a second
## table happened to rate churches low.
static func building_axes(id: StringName) -> Dictionary:
	return _building_axes(id)


static func improvement_axes_at(
	at: Vector2i, improvement: Improvement, context: ColonyContext
) -> Dictionary:
	return _improvement_axes(at, improvement, context)


## 🔒 **Every effect key this function knows how to value** (#311).
##
## **An effect `_building_axes` is not told about is an effect no governor can
## pursue, and nothing fails when it happens.** It has happened three times:
##
## - **amusement** — the colony built fourteen of the eighteen buildings in the
##   tree and never the two that exist to make people happy (#153).
## - **reserve_months** — read as a float after it became a dictionary, so a
##   governor stopped being able to want a granary for the reason a granary
##   exists (#148).
## - **conversions** — a governor could want a foundry as a shed that holds two
##   months of ore, and not as a foundry (#311).
##
## Each was found by a five-year harness run. `test_objective_selector` now fails
## if the building data uses a key that is not here, so **the fourth is a failing
## test instead.**
##
## A key listed here and then ignored below would still slip through, which is
## why it sits against the function rather than somewhere tidier: the list and the
## body are meant to be read together.
const EFFECTS_READ: PackedStringArray = [
	"amusement", "build_speed", "conversions", "counts_distant_experts",
	"defence", "draws_experts", "education", "education_per_expert",
	"growth", "immigration", "pasture", "perceived_safety", "quality_of_life",
	"reserve_months", "yield_bonus",
]


static func _building_axes(id: StringName) -> Dictionary:
	var building := Building.find(id)
	if building == null:
		return {}
	var axes: Dictionary = {}

	var bonuses: Dictionary = building.effect("yield_bonus", {})
	for resource in bonuses:
		var amount := float(bonuses[resource])
		# A yield bonus is a share of everything the town will ever produce of
		# that resource, for the rest of the run. It is worth a great deal more
		# than the number looks.
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + amount * LASTING
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + amount * LASTING * _trade_weight(StringName(resource))

	axes["defence"] = float(building.effect("defence", 0.0)) * 0.5
	# **Amusement is comfort a governor can want for its own sake** (#153).
	# Nothing here knows what a theatre is, but a building that entertains half
	# the town has to reach this or no governor could ever choose one — which is
	# what happened when the effect was added and this was not told: the colony
	# built fourteen of the eighteen buildings in the tree and never the two that
	# exist to make people happy.
	# **Perceived safety is comfort and not defence** (`buildings.md` §4). A
	# church stops nothing; it makes people feel less alone about what is coming,
	# and it reaches quality of life through the safety component rather than
	# through `Force`. Scoring it on `defence` would let a governor answer *raise
	# the walls* with a chapel, which is exactly the misunderstanding the two
	# words exist to keep apart.
	axes["comfort"] = (
		float(building.effect("quality_of_life", 0.0)) * 0.5
		+ float(building.effect("amusement", 0.0)) * AMUSEMENT_WORTH
		+ float(building.effect("perceived_safety", 0.0)) * COMFORT_OF_FAITH
	)
	# **A reserve is per-resource now** (#148). Read as a float this silently
	# became zero the month the effect turned into a dictionary, and a governor
	# stopped being able to want a granary for the reason a granary exists.
	var reserved := 0.0
	for resource in building.effect("reserve_months", {}):
		reserved += float(building.effect("reserve_months", {})[resource])

	# **Education is capacity** (#168). It decides whether a town's growth arrives
	# as expertise or as hands, which is a fact about what the town will be able
	# to do — and a governor who wants his people to amount to something can want
	# a library for that reason without anything here knowing what a library is.
	var learning := (
		float(building.effect("education", 0.0))
		+ float(building.effect("education_per_expert", 0.0)) * EXPERTS_A_TOWN_MIGHT_HOLD
		+ float(building.effect("counts_distant_experts", 0.0)) * EXPERTS_A_TOWN_MIGHT_HOLD
	)

	# **Drawing people is expansion** (#170). A fairgrounds brings settlers and a
	# printing press brings the kind worth having, and a governor set on growing
	# his population can want either for that reason.
	axes["expansion"] = float(axes.get("expansion", 0.0)) + (
		float(building.effect("immigration", 0.0)) * 0.6
		+ float(building.effect("draws_experts", 0.0)) * 0.3
	)

	axes["capacity"] = (
		learning * 0.4
		+ reserved * 0.5
		# In thousands of head, the scale the weight was set at (#426).
		+ Population.thousands(float(building.effect("pasture", 0))) * 0.03
		# **A granary is capacity and not expansion** (#172). It grows the town
		# from inside, which is what `POPULATION` wants; `expansion` is the axis
		# for founding a second town, and it is weighed by `SETTLEMENT` alone. A
		# governor told to settle who answered with a granary would be a governor
		# who had not understood the order.
		#
		# **Small against the same building's reserve**, deliberately. Half again
		# on the birth rate of a town of twenty is under a person a year; the food
		# that granary is holding matters to the same governor every month. He
		# wants it for the store first and the children second.
		+ float(building.effect("growth", 0.0)) * 0.25
		+ float(building.effect("build_speed", 0.0)) * 0.5
	)

	# 🔒 **A conversion building has a worth, and it is the margin it adds**
	# (#311, `buildings.md` §6).
	#
	# This function was told about thirteen effects and not this one, so a foundry
	# reached a governor only through its `reserve_months` — he could want it as a
	# shed that holds two months of ore, and not as a foundry. Over three seeds
	# and five years a town raised thirteen buildings and **not one** of the nine
	# that convert anything, while finishing four *works*-band buildings at the
	# same price and ending ninety tools in hand.
	#
	# **The third time this has happened**, after amusement and per-resource
	# reserves. `test_objective_selector` now fails if the data uses an effect key
	# this function has never heard of, so the fourth is a failing test rather
	# than a five-year harness run.
	_add_conversion_axes(building, axes)
	return axes


## What a conversion building is worth, on the axes §6 names.
##
## **It adds its margin twice**: a better ratio means less input per unit, and
## doubled throughput means more units a worker-month. Both are already derived
## by `Building.conversion_terms`, so this asks rather than recomputing — the
## throughput and the ratio cannot drift apart here either.
##
## 🔒 **The axis follows the output, and the output already knows what it is.**
## Nothing below names a resource:
##
## | The output | Axis | Because |
## | :--- | :--- | :--- |
## | anything | **trade** | it is sellable, weighted by price as a yield bonus is |
## | appears in a building's cost | **capacity** | the chain feeds construction |
## | a luxury | **comfort** | the town drinks it rather than shipping it |
##
## A building may score on more than one. Rum is a luxury and a cash crop, and a
## distillery is wanted for both reasons by governors who want different things.
static func _add_conversion_axes(building: Building, axes: Dictionary) -> void:
	for recipe in building.effect("conversions", {}):
		var terms := building.conversion_terms(StringName(recipe))
		if terms.is_empty():
			continue
		var gain := _conversion_gain(StringName(recipe), terms)
		if gain <= 0.0:
			# 🔒 **The town hall's own terms are the base, not an improvement on
			# it.** It performs every ungated conversion at the worst terms in the
			# tree, which is what *base* means — so it must not read as nine
			# conversion buildings in one.
			#
			# The arithmetic already gives it nought, so what this actually buys is
			# that it is not scored **at all**: no axis appears, rather than one
			# appearing and reading zero. A building that improves nothing has
			# nothing to say about trade, and saying it quietly is a different
			# claim from not saying it.
			continue

		var output := StringName(String(recipe).split("<-")[0])
		axes["trade"] = float(axes.get("trade", 0.0)) \
			+ gain * CONVERSION_WORTH * _trade_weight(output)
		if _feeds_construction(output):
			axes["capacity"] = float(axes.get("capacity", 0.0)) \
				+ gain * CONVERSION_WORTH
		if ResourceCatalogue.is_luxury(output):
			axes["comfort"] = float(axes.get("comfort", 0.0)) \
				+ gain * CONVERSION_WORTH


## How much more of the output one worker turns out in a month, for the building.
##
## Base is two a month by `town-economy.md` §11, whatever the recipe; with the
## building it is `throughput / ratio`. The difference is the margin.
static func _conversion_gain(recipe: StringName, terms: Dictionary) -> float:
	var ratio := maxf(0.0001, float(terms.get("ratio", 1.0)))
	var base := maxf(0.0001, Building.base_ratio_for(recipe))
	var with_it := float(terms.get("throughput", 0.0)) / ratio
	var without := (2.0 * base) / base
	return with_it - without


## 🔒 **Whether this output feeds construction, derived and never asserted.**
##
## §5 claims the mineworks → foundry → toolworks chain *pays for itself in
## construction*, and a governor can only act on that if a toolworks reads as
## capacity to him. It reads as capacity because tools appear in the cost of half
## the tree — which this asks the tree, so a building priced in a new resource
## tomorrow makes that resource capacity without anybody editing this.
static func _feeds_construction(output: StringName) -> bool:
	for id in Building.ids():
		var building := Building.find(StringName(id))
		if building != null and building.cost.has(String(output)):
			return true
	return false


## What raising this improvement on this tile would actually change.
##
## Measured as the **difference in what the tile yields**, not as a property of
## the improvement, which is what makes a farm on plains worth more than a farm
## on scrubland without anything in code knowing which is which.
static func _improvement_axes(at: Vector2i, improvement: Improvement, context: ColonyContext) -> Dictionary:
	var terrain := Terrain.find(context.map.terrain_at(at.x, at.y))
	if terrain == null:
		return {}
	var axes: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var before := context.map.yield_at(at.x, at.y, id)
		var after := improvement.yield_of(terrain, id)
		var change := after - before
		if is_zero_approx(change):
			continue
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + change * PER_UNIT_YIELD
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + change * PER_UNIT_YIELD * _trade_weight(id)
	# In thousands of head, the scale the weight was set at (#426).
	axes["capacity"] = Population.thousands(float(improvement.capacity_on(terrain.id))) * 0.05
	axes["expansion"] = 0.0
	return axes


## What a standing posture is good for.
static func _posture_axes(id: StringName, town: Town, context: ColonyContext) -> Dictionary:
	var pretend := Town.new(town.id, town.display_name, town.at)
	pretend.objective = id
	var axes: Dictionary = {}

	for resource in Objective.posture_focus(pretend):
		var source := StringName(resource)
		# What the town can actually get more of by trying. A posture towards a
		# resource the land does not carry is worth nothing.
		var reachable := 0.0
		for at in context.tiles_of(town):
			reachable += context.map.yield_at(at.x, at.y, source)
		if reachable <= 0.0:
			continue
		if resource == "food":
			axes["food"] = float(axes.get("food", 0.0)) + POSTURE_WORTH
			axes["capacity"] = float(axes.get("capacity", 0.0)) + POSTURE_WORTH * 0.7
		else:
			axes["trade"] = float(axes.get("trade", 0.0)) + POSTURE_WORTH * _trade_weight(source)

	if id == &"amass_expedition":
		axes["expansion"] = 1.0
	return axes


## How much a resource is worth bothering with, relative to grain.
static func _trade_weight(resource: StringName) -> float:
	var food := maxf(0.001, ResourceCatalogue.price_of(&"food"))
	return clampf(ResourceCatalogue.price_of(resource) / food, 0.0, 4.0) * 0.5


# --- 🔒 The governor picks the tile -----------------------------------------

## The best tile in the town's reach for this improvement.
##
## **Deterministic, and the PC never sees this function.** SPEC §11.4 locks tile
## choice to the governor; the player may write that he wants more grain, and
## may not write *where*.
static func _best_tile_for(town: Town, improvement: Improvement, context: ColonyContext) -> Dictionary:
	var none: Dictionary = {"at": Vector2i(-1, -1), "axes": {}}
	if context.map == null:
		return none

	var best := none
	var best_value := 0.0
	for at in context.tiles_of(town):
		if not context.map.can_build(at.x, at.y, improvement.id):
			continue
		if context.map.improvement_at(at.x, at.y) == improvement.id:
			continue  # Already there.
		var axes := _improvement_axes(at, improvement, context)
		var value := float(axes.get("food", 0.0)) + float(axes.get("trade", 0.0)) + float(axes.get("capacity", 0.0))
		# Ties break north-west first, so the choice is the map's rather than the
		# iteration order's.
		if value > best_value + 0.0001 or (
			absf(value - best_value) <= 0.0001
			and best["at"] != Vector2i(-1, -1)
			and (at.y < best["at"].y or (at.y == best["at"].y and at.x < best["at"].x))
		):
			best = {"at": at, "axes": axes}
			best_value = value
	return best


# --- Feasibility ------------------------------------------------------------

## Whether the town could ever get all of this.
##
## **A hard stall before it starts.** The militia needs guns, guns need iron, the
## town produces no ore and has no money — that objective is unreachable and no
## amount of patience fixes it, so it never becomes the objective in the first
## place.
static func _can_obtain_all(town: Town, cost: Dictionary, context: ColonyContext) -> bool:
	var ids: PackedStringArray = PackedStringArray(cost.keys())
	ids.sort()
	for resource in ids:
		if not can_obtain(town, StringName(resource), context):
			return false
	return true


static func can_obtain(town: Town, resource: StringName, context: ColonyContext) -> bool:
	if town.held(resource) > 0.0 or town.invested(resource) > 0.0:
		return true
	for at in context.tiles_of(town):
		if context.map != null and context.map.yield_at(at.x, at.y, resource) > 0.0:
			return true
	# Otherwise it has to be bought, which needs somebody to buy from and the
	# money to do it with.
	return Trade.may_trade_with_crown(town, resource, context) \
		and town.can_afford(ResourceCatalogue.price_of(resource))


## A tie broken by the seed rather than by a die.
##
## Different seeds break the same tie differently, which is what the doc asks
## for; the same seed breaks it the same way every time, and **no stream is
## consumed**, so a tie here cannot shift a draw somewhere else in the colony.
static func _tiebreak(run_seed: int, town_id: StringName, candidate: StringName) -> int:
	return StableHash.of_string("%d:%s:%s" % [run_seed, town_id, candidate])
