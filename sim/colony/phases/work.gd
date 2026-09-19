class_name WorkPhase
extends ColonyPhase

## **Work.** Each town assigns its population between **working tiles** in its
## influence area and **converting** raw resources into processed ones
## (SPEC §11.3 step 1, §10.1).
##
## **The quality of the colony sim lives here.** A town that farms mountains
## while starving reads as broken however good the prose is, so the rule that
## picks work has to be one a player looking at the map would agree with.
##
## ## One list, two kinds of work
##
## A worker is in the fields or in the town, **never both**, so every conversion
## costs a worked tile. That is one labour allocation rather than two separate
## decisions — which is why tiles and recipes are scored in the same units, put
## in one list, and the best taken. A town with furs, no spare ground and cold
## people sends hands to the loom; a town with good land and nothing to process
## does not.
##
## ## What the score means, and what it deliberately leaves out
##
## Every piece of work is scored as **the weighted resources it adds this
## month**, where the weight is what the thing is worth and **triple that if the
## objective calls for it** (`town-economy.md` §4). A recipe subtracts what it
## consumes, so brewing the last of the grain into beer scores terribly in a
## hungry town — without anything in code knowing what beer is.
##
## **Hunger is not a weight.** It was one, and it is the reason this phase had to
## be rewritten: a weight that rises as the stores fall re-ranks every tile in
## the town every month, so a town near the edge reshuffles its whole workforce
## as its granary crosses a line and back. Measured over 25 seeds and five years,
## towns gave up 0.25 to 0.67 tiles a month, and the worst seeds three — a fifth
## of the workforce moved every month. With the weight taken out the same figure
## is 0.01 to 0.15. The churn was the weight (#116).
##
## ## The survival check, applied after scoring
##
## Need is handled instead as a **redirection with a stopping condition**, which
## is what SPEC §11.3's food-and-clothing lockstep actually asks for. If the
## chosen assignment cannot meet the town's **food and clothing**, take the hand
## off the work closing least of the gap and put it on the work closing most.
## Repeat.
##
## **If no swap would improve matters, the town does nothing and accepts the
## deficit.** It does not thrash, and it does not pretend. A town on poor ground
## settles into a sensible assignment and goes hungry, rather than sending men to
## tiles that yield one food for a gain that does not prevent the famine.
##
## Each hand moves at most once, so the loop terminates on its own rather than on
## a guard.
##
## One worker to a tile or a recipe, best first. Everything is scored from the
## colony as it stood when the phase began, never from what this town has already
## done this month.

const EVENT_WORKED: StringName = &"town_worked"
const EVENT_CONVERTED: StringName = &"town_converted"

## What the objective's needs are worth beside general value.
##
## ## Added, where `town-economy.md` §4 says tripled
##
## **The doc's `favour = 3` assumes its own scoring, which counts a tile's yields
## and nothing else.** Against a bare count, tripling is decisive. Against the
## weights actually used here it is not, because `value_of` already spreads a
## resource's worth over a five-to-one range and six furs outweigh six of
## anything cheap before any favour is applied at all. On the standard forest and
## plains fixture, a town ordered to stockpile food still goes to the forest at
## ×3; the multiplier would have to exceed 3.5 to turn it round, and choosing a
## number that clears one fixture is tuning rather than a rule.
##
## Added instead, because favour is a **tier** — needs, then the objective, then
## what the thing is worth — and a tier should mean the same thing to a cheap
## material as to a dear one. An objective wanting forty wood wants forty wood;
## it does not want it three times as much for wood being valuable.
const OBJECTIVE_WEIGHT: float = 2.5

## What a month spent fetching an input is worth against the need it becomes.
##
## Less than the need itself, because it still costs a worker and a month to turn
## one into the other — but most of it, or a cold town would never send anybody
## to the traplines, the loom would stand idle for want of furs, and the clothing
## half of the survival check could never be worked towards at all.
const INPUT_SHARE: float = 0.6

## Each expert raises his resource by this much, before diminishing returns.
const EXPERT_BONUS: float = 0.25

## **Stacking experts has diminishing returns** (SPEC §12.2): each one after the
## first is worth this share of the one before.
const EXPERT_FALLOFF: float = 0.6


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	# What the objective still wants. A construction wants its remaining
	# materials; a standing posture wants its focus resources, every month,
	# forever.
	var wanted := Objective.still_to_gather(town)
	var focus := Objective.posture_focus(town)
	var worth := _worth(wanted, focus)
	var tiles := context.tiles_of(town)

	# Tiles and recipes, scored the same way and ranked together. Ties break on a
	# fixed rule, so the choice is the colony's rather than the iteration order's.
	var work: Array = []
	for at in tiles:
		work.append({"kind": "tile", "at": at, "score": _score_tile(context, at, worth)})
	for recipe in Conversion.all():
		work.append({"kind": "convert", "recipe": recipe, "score": _score_recipe(recipe, town, worth)})

	work.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) > float(b["score"])
		if String(a["kind"]) != String(b["kind"]):
			return String(a["kind"]) < String(b["kind"])
		if String(a["kind"]) == "convert":
			return String(a["recipe"].id()) < String(b["recipe"].id())
		var left: Vector2i = a["at"]
		var right: Vector2i = b["at"]
		return left.y < right.y or (left.y == right.y and left.x < right.x))

	# **The survival check, after scoring and before anybody goes out.** It may
	# reorder the list; it never rescores it.
	_redirect(town, before, context, work)

	var produced: Dictionary = {}
	var converted: Dictionary = {}
	# **The start-of-month stockpile**, spent down as recipes claim from it, so
	# two recipes cannot both smelt the same ore and nothing bought this month
	# can be processed this month.
	var available: Dictionary = {}
	var tiles_worked := 0
	var hands := 0
	# **Which ground, not merely how much of it** (Seam A). Map playback wants
	# it, and so does any question about whether a town's assignment is settled
	# or reshuffling month to month (#116) — neither is answerable from a count.
	var worked: PackedStringArray = PackedStringArray()

	for entry in work:
		if hands >= town.workable_tiles():
			break
		if float(entry["score"]) <= 0.0:
			break  # Nothing left here is worth a worker.
		if String(entry["kind"]) == "tile":
			hands += 1
			tiles_worked += 1
			var at: Vector2i = entry["at"]
			worked.append("%d,%d" % [at.x, at.y])
			_harvest(town, context, at, produced)
		elif _convert(town, before, entry["recipe"], available, converted):
			hands += 1

	for resource in produced:
		town.store(StringName(resource), float(produced[resource]))

	context.log.emit(EVENT_WORKED, town.id, context.state.month, {
		"town": String(town.id),
		"tiles_worked": tiles_worked,
		"tiles": worked,
		"tiles_available": tiles.size(),
		"converting": hands - tiles_worked,
		"workers": town.workable_tiles(),
		"produced": produced,
	}, WorldPhase.COLONY_MONTH)

	if not converted.is_empty():
		context.log.emit(EVENT_CONVERTED, town.id, context.state.month, {
			"town": String(town.id),
			"made": converted,
		}, WorldPhase.COLONY_MONTH)


# --- What the town wants more of -------------------------------------------

## How much a unit of each resource is worth to this town this month.
##
## **What the thing is worth, plus what the objective calls for**, and nothing
## else. There is deliberately no term here for hunger: need is a
## redirection applied afterwards, not a thumb on the scale, because a weight
## that moves with the stores re-ranks the whole town every month (#116).
func _worth(wanted: Dictionary, focus: PackedStringArray) -> Dictionary:
	var weights: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var weight := value_of(StringName(resource))
		if wanted.has(resource) or focus.has(resource):
			weight += OBJECTIVE_WEIGHT
		weights[resource] = weight
	return weights


## What a unit of a resource is worth in itself, measured in grain.
##
## **Conversion cannot be scored without this.** A recipe takes more raw than it
## makes processed — one and a half of ore for one of iron — so compared by the
## count it is always a loss, and no town would ever smelt anything. It is a gain
## because iron is worth twice what ore is, and that is a fact about the
## resource rather than about the town.
##
## `docs/mechanics/town-economy.md` §4 scores a tile by count alone. It was
## written before conversion existed, and §7 of the same doc says so: *"this
## doc's tile scoring stands on its own and the survival check's clothing half is
## incomplete."* SPEC §11.3 step 1 now requires one allocation across fields and
## town, and the two cannot be ranked together without a common unit.
static func value_of(resource: StringName) -> float:
	var grain := maxf(0.001, ResourceCatalogue.price_of(&"food"))
	return maxf(0.0, ResourceCatalogue.price_of(resource) / grain)


# --- The survival check -----------------------------------------------------

## What a recipe may take of its input, after the month's needs are set aside.
##
## **A filter, not a weight** (CLAUDE.md). SPEC §11.3 step 2 locks food and
## clothing ahead of everything, so a town does not brew its last grain into
## beer — and that has to be a rule about what the loom is *allowed* to take,
## because it used to be an effect of the hunger weight and the hunger weight is
## what was causing towns to reshuffle every month (#116). A filter is stable:
## it changes what is possible, not how everything else ranks.
func _spare(town: Town, before: ColonySnapshot, resource: StringName) -> float:
	var held := before.held(town.id, resource)
	var per_head := ColonyNeeds.per_head(resource)
	if per_head <= 0.0:
		return held
	return maxf(0.0, held - maxf(1.0, float(town.population())) * per_head)


## What share of a month's batch this recipe could actually run.
func _feasible(town: Town, before: ColonySnapshot, recipe: Conversion) -> float:
	if recipe.consumed <= 0.0:
		return 0.0
	return clampf(_spare(town, before, recipe.input) / recipe.consumed, 0.0, 1.0)



## Move hands onto need, one at a time, and stop when moving another would not
## help (`town-economy.md` §4).
##
## **The stopping condition is the whole point.** A town that cannot close its
## food gap is supposed to settle into a sensible assignment and go hungry. The
## alternative — a hunger term inside the score — keeps biasing toward food
## whether or not more food is actually to be had, so a town on poor ground gives
## up the ore it was raising for one more grain that does not prevent the famine,
## and does it again the following month in the other direction (#116).
##
## ## Judged on the whole assignment, not on what is left of the gap
##
## The obvious reading of the doc — take the hand closing least of the *remaining*
## shortfall and move it to the work closing most — swaps back and forth within a
## single month. Once the food is covered, the tile covering it is the one
## contributing least to what remains, so the next pass moves that hand onto furs
## and re-opens the hunger it had just closed.
##
## So a swap is accepted only when it lowers the town's **total unmet need**, over
## food and clothing together (SPEC §11.3 step 2). That is strictly decreasing and
## bounded below, so the loop ends on its own and lands somewhere it will land
## again next month from the same position.
func _redirect(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	work: Array,
) -> void:
	var hands := town.workable_tiles()
	if hands <= 0 or work.size() <= hands:
		return  # Every hand is already on the best there is; there is nothing to swap.

	var needs := ColonyNeeds.needed_resources()
	var gives: Array = []
	for entry in work:
		gives.append(_contribution(town, before, context, entry, needs))

	# What the town is short of, before any of this month's work is counted.
	var owed: Dictionary = {}
	var mouths := maxf(1.0, float(town.population()))
	for resource in needs:
		# **Measured against a comfortable store, not against this month's meal.**
		# A town producing exactly what it eats and holding nothing is one bad
		# month from famine, and a check that called that "needs met" would let a
		# town quarry while it lived hand to mouth.
		owed[resource] = mouths * ColonyNeeds.per_head(StringName(resource)) \
			* ColonyNeeds.comfortable_months() \
			- before.held(town.id, StringName(resource))

	var balance: Dictionary = owed.duplicate()
	for i in hands:
		for resource in needs:
			balance[resource] = float(balance[resource]) - float(gives[i][resource])

	for _move in hands:
		var unmet := _unmet(balance, needs)
		if unmet <= 0.000001:
			return  # Needs are met. The assignment stands.

		var take := -1
		var put := -1
		var best := unmet
		for i in hands:
			for j in range(hands, work.size()):
				var after := 0.0
				for resource in needs:
					after += maxf(0.0, float(balance[resource])
						+ float(gives[i][resource]) - float(gives[j][resource]))
				if after < best - 0.000001:
					best = after
					take = i
					put = j

		# **No swap would improve matters. Do nothing and accept the deficit.**
		if take < 0:
			return

		for resource in needs:
			balance[resource] = float(balance[resource]) \
				+ float(gives[take][resource]) - float(gives[put][resource])

		var moved: Dictionary = work[take]
		work[take] = work[put]
		work[put] = moved
		var swapped: Dictionary = gives[take]
		gives[take] = gives[put]
		gives[put] = swapped


## How much of the town's total need is still unmet.
##
## A surplus of grain does not feed anybody cloth, so each need is counted at
## zero or worse and never against another.
func _unmet(balance: Dictionary, needs: PackedStringArray) -> float:
	var total := 0.0
	for resource in needs:
		total += maxf(0.0, float(balance[resource]))
	return total


## What a month of this work adds towards each of the town's needs.
##
## Counts what the work fetches *towards* a need as well as the need itself: a
## cold town values furs, or the loom stands idle and the clothing half of the
## check can never be worked towards, since cloth is not a tile yield. Discounted
## by `INPUT_SHARE`, because it still costs another worker and another month to
## turn one into the other.
func _contribution(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	entry: Dictionary,
	needs: PackedStringArray,
) -> Dictionary:
	var gives: Dictionary = {}
	for resource in needs:
		gives[resource] = 0.0

	if String(entry["kind"]) == "convert":
		# **Scaled by what the town can actually feed it.** A loom with no furs
		# makes no cloth, and moving a hand onto it would give up good ground for
		# work that will not happen.
		var recipe: Conversion = entry["recipe"]
		var share := _feasible(town, before, recipe)
		if share > 0.0:
			var output := String(recipe.output)
			if gives.has(output):
				gives[output] = float(gives[output]) + recipe.made_by(town) * share
			var input := String(recipe.input)
			if gives.has(input):
				gives[input] = float(gives[input]) - recipe.consumed * share
		return gives

	var at: Vector2i = entry["at"]
	for resource in needs:
		gives[resource] = float(gives[resource]) + _yield_of(context, town, at, StringName(resource))
	for output in ResourceCatalogue.processed():
		if not gives.has(String(output)):
			continue
		var per_unit := maxf(0.001, ResourceCatalogue.input_per_unit_of(StringName(output)))
		for input in ResourceCatalogue.inputs_for(StringName(output)):
			var fetched := _yield_of(context, town, at, StringName(input)) / per_unit
			gives[String(output)] = float(gives[String(output)]) + fetched * INPUT_SHARE
	return gives


## What a tile gives this town of one resource, experts and buildings included.
func _yield_of(context: ColonyContext, town: Town, at: Vector2i, resource: StringName) -> float:
	var amount := context.map.yield_at(at.x, at.y, resource)
	if amount <= 0.0 or town == null:
		return amount
	return amount * expert_multiplier(town, resource) \
		* (1.0 + Building.yield_bonus_for(town, resource))


# --- Scoring ---# --- Scoring ----------------------------------------------------------------

func _score_tile(context: ColonyContext, at: Vector2i, weights: Dictionary) -> float:
	var score := 0.0
	for resource in ResourceCatalogue.ids():
		var amount := context.map.yield_at(at.x, at.y, StringName(resource))
		if amount > 0.0:
			score += amount * float(weights.get(resource, 1.0))
	return score


## What a month at the loom is worth, **net of what it uses up**.
##
## Subtracting the input is what stops a hungry town brewing its grain into beer,
## and it does so without anything here knowing what beer is.
func _score_recipe(recipe: Conversion, town: Town, weights: Dictionary) -> float:
	return recipe.made_by(town) * float(weights.get(String(recipe.output), 1.0)) \
		- recipe.consumed * float(weights.get(String(recipe.input), 1.0))


# --- Doing the work ---------------------------------------------------------

func _harvest(town: Town, context: ColonyContext, at: Vector2i, into: Dictionary) -> void:
	for resource in ResourceCatalogue.ids():
		var amount := context.map.yield_at(at.x, at.y, StringName(resource))
		if amount <= 0.0:
			continue
		amount *= expert_multiplier(town, StringName(resource))
		amount *= 1.0 + Building.yield_bonus_for(town, StringName(resource))
		into[resource] = float(into.get(resource, 0.0)) + amount


## Put a worker on a recipe, if there is anything for him to work on.
##
## Returns whether he was actually employed. A recipe the town has no input for
## costs no labour, which keeps "every conversion costs a worked tile" true
## without also letting an *impossible* conversion cost one.
func _convert(
	town: Town,
	before: ColonySnapshot,
	recipe: Conversion,
	available: Dictionary,
	into: Dictionary,
) -> bool:
	var key := String(recipe.input)
	if not available.has(key):
		# **The month's needs come off the top.** A town with two days of grain
		# has none to spare for the brewhouse, whatever beer is worth.
		available[key] = _spare(town, before, recipe.input)

	var on_hand := float(available[key])
	if on_hand <= 0.0:
		return false

	# A part-supplied worker does part of the work rather than none of it.
	var share := clampf(on_hand / recipe.consumed, 0.0, 1.0)
	var used := recipe.consumed * share
	var made := recipe.made_by(town) * share
	if made <= 0.0:
		return false

	available[key] = on_hand - used
	town.take(recipe.input, used)
	town.store(recipe.output, made)
	into[String(recipe.output)] = float(into.get(String(recipe.output), 0.0)) + made
	return true


## What this town's experts are worth on a resource.
##
## **Diminishing returns when stacked** (SPEC §12.2): the second expert is worth
## less than the first, the third less again. Two mediocre towns beat one with
## every expert in the colony crammed into it.
static func expert_multiplier(town: Town, resource: StringName) -> float:
	var count := town.expert_count(resource)
	var bonus := 0.0
	var step := EXPERT_BONUS
	for i in count:
		bonus += step
		step *= EXPERT_FALLOFF
	return 1.0 + bonus
