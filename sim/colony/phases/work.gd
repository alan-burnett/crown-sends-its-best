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
## ## One number decides it, and it is the town's valuation
##
## Every piece of work is scored as **the resources it adds this month, each at
## what the town thinks a unit of it is worth** (`town-economy.md` §3). A recipe
## subtracts what it consumes, so brewing the last of the grain into beer scores
## terribly in a hungry town — without anything in code knowing what beer is.
##
## **There is no objective term here any more.** There was one, a flat bonus on
## anything the build called for, and the doc's §3 subsumes it: the objective
## raises the town's *desired stock*, desired stock raises the valuation, and the
## tier it raises it at decides how steeply. A town raising a church values lumber
## at four times what the same town values it a year later, and the scoring never
## hears the word "church".
##
## That matters beyond tidiness. The old weight was a second opinion about what
## the town wanted, held only by this phase — so the tiles it worked and the
## goods it bought were ranked by two different rules that could disagree.
##
## **Hunger is still not a weight.** The need term moves with desired stock, which
## is a want rather than a larder reading: it changes when the town takes on a
## project or loses people, not every month as the granary crosses a line. That
## distinction is the whole of #116. Measured over 25 seeds and five years, the
## hunger weight cost towns 0.25 to 0.67 tiles a month and the worst seeds three;
## without it the figure is 0.01 to 0.15.
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
	# **What this town wants, and what that makes each resource worth to it.**
	# Both read from the state the month opened with, so Work and Reckon are
	# working from one account of the town rather than two (§3).
	var desired := DesiredStock.for_town(town, before)
	var tiles := context.tiles_of(town)

	# Tiles and recipes in one list, to be ranked together. `_allocate` scores
	# them; the score here is a placeholder it overwrites.
	var work: Array = []
	for at in tiles:
		work.append({"kind": "tile", "at": at, "score": 0.0})
	for recipe in Conversion.all():
		work.append({"kind": "convert", "recipe": recipe, "score": 0.0})

	# **Ranked a hand at a time, against what the hands before it already
	# produced.** The month's assignment is built by taking the best remaining
	# work, adding what it would yield to a running projection of the stores, and
	# asking again — so the second fur trapper is judged on a town that already
	# has the first trapper's furs.
	_allocate(town, before, context, work, desired)

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

## What a unit of each resource is worth to this town this month (§3).
##
## `Valuation.town` for every resource in the catalogue, computed once and looked
## up by the scoring — the town's one opinion of what it wants, not this phase's.
func _worth_of(held: Dictionary, desired: DesiredStock) -> Dictionary:
	var weights: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		weights[resource] = Valuation.town(
			StringName(resource), desired, float(held.get(resource, 0.0))
		)
	return weights


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
	var takes := recipe.consumes_for(town)
	if takes <= 0.0:
		return 0.0
	return clampf(_spare(town, before, recipe.input) / takes, 0.0, 1.0)



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
				gives[input] = float(gives[input]) - recipe.consumes_for(town) * share
		return gives

	var at: Vector2i = entry["at"]
	for resource in needs:
		gives[resource] = float(gives[resource]) + _yield_of(context, town, at, StringName(resource))
	for output in ResourceCatalogue.processed():
		if not gives.has(String(output)):
			continue
		var per_unit := maxf(0.001, Conversion.best_ratio(town, StringName(output)))
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


# --- Building the month's assignment ----------------------------------------

## Put the best work first, each hand judged on what the hands before it did.
##
## ## 🔒 Marginal, because one tile can overshoot a want twelvefold
##
## Scoring every tile once against the stores as the month opened, and taking the
## top twelve, is what the doc's `yield x valuation` reads like — and it
## oscillates, hard. A town of twelve wants about four furs and a single forest
## tile brings in four; twelve hands bring in fifty-one. So the planning
## valuation says furs are worth three times base, the month lands twelve times
## the want, and next month the same tiles are worth the surplus floor. The town
## abandons the forest, comes back the month after, and does it forever.
##
## Measured: flat scoring took tile churn from 0.25 abandoned tiles a month to
## 1.87, which is #116's regression arriving by a different road. Ranking at the
## margin puts it back, because the assignment stops piling onto a want the
## moment it is met and moves to the next thing — so the month ends near the
## target instead of far past it, and next month's ranking is the same ranking.
##
## This is not a second opinion about value. It is the same valuation asked the
## only question that makes sense of a whole month's labour at once: not *what is
## a fur worth*, but *what is the fifteenth fur worth*.
##
## Leaves `work` with the chosen assignment in its first `workable_tiles()`
## slots, exactly as a sort would, so the survival check downstream is unchanged.
func _allocate(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	work: Array,
	desired: DesiredStock,
) -> void:
	# What the town would be holding, updated as each hand is committed.
	var projected: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		projected[resource] = before.held(town.id, StringName(resource))

	var chosen: Array = []
	var rounds := mini(town.workable_tiles(), work.size())
	for _hand in rounds:
		var worth := _worth_of(projected, desired)
		var best := -1
		var best_score := 0.0
		for i in work.size():
			var score := _score(town, before, context, work[i], worth)
			if best < 0 or score > best_score + 0.000001 					or (absf(score - best_score) <= 0.000001 and _before(work[i], work[best])):
				best = i
				best_score = score
		if best < 0:
			break

		var taken: Dictionary = work[best]
		taken["score"] = best_score
		chosen.append(taken)
		work.remove_at(best)
		_project(town, before, context, taken, projected)

	# The rest, in the order they last scored, so the survival check has a ranked
	# tail to draw a replacement hand from.
	var worth := _worth_of(projected, desired)
	for entry in work:
		entry["score"] = _score(town, before, context, entry, worth)
	work.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) > float(b["score"])
		return _before(a, b))

	work.assign(chosen + work)


## A fixed order for work that scores the same, so the choice is the colony's
## rather than the iteration order's.
func _before(a: Dictionary, b: Dictionary) -> bool:
	if String(a["kind"]) != String(b["kind"]):
		return String(a["kind"]) < String(b["kind"])
	if String(a["kind"]) == "convert":
		return String(a["recipe"].id()) < String(b["recipe"].id())
	var left: Vector2i = a["at"]
	var right: Vector2i = b["at"]
	return left.y < right.y or (left.y == right.y and left.x < right.x)


func _score(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	entry: Dictionary,
	worth: Dictionary,
) -> float:
	if String(entry["kind"]) == "convert":
		return _score_recipe(entry["recipe"], town, worth)
	var at: Vector2i = entry["at"]
	return _score_tile(town, context, at, worth)


## Add what a piece of work would yield to the running projection.
func _project(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	entry: Dictionary,
	projected: Dictionary,
) -> void:
	if String(entry["kind"]) == "convert":
		var recipe: Conversion = entry["recipe"]
		# **Only what it could actually run.** A loom with no furs changes
		# nothing, so it must not look as though it did.
		var share := _feasible(town, before, recipe)
		if share <= 0.0:
			return
		var out := String(recipe.output)
		projected[out] = float(projected.get(out, 0.0)) + recipe.made_by(town) * share
		var into := String(recipe.input)
		projected[into] = maxf(0.0,
			float(projected.get(into, 0.0)) - recipe.consumes_for(town) * share)
		return

	var at: Vector2i = entry["at"]
	for resource in ResourceCatalogue.ids():
		var amount := context.map.yield_at(at.x, at.y, StringName(resource))
		if amount <= 0.0:
			continue
		projected[resource] = float(projected.get(resource, 0.0)) 			+ amount * expert_multiplier(town, StringName(resource)) 			* (1.0 + Building.yield_bonus_for(town, StringName(resource)))


# --- Scoring ----------------------------------------------------------------

## What a month on this ground is worth to this town.
##
## **Scored on what the town would actually get**, experts and buildings
## included, because that is what the allocation then adds to its projection. A
## score that read the bare map while the projection read the town's real yield
## made a food expert *lower* the town's grain: the projection filled the want
## faster than the scoring knew, so the town gave up a field it was scoring as
## though nobody skilled worked it.
func _score_tile(town: Town, context: ColonyContext, at: Vector2i, weights: Dictionary) -> float:
	var score := 0.0
	for resource in ResourceCatalogue.ids():
		var amount := _yield_of(context, town, at, StringName(resource))
		if amount > 0.0:
			score += amount * float(weights.get(resource, 1.0))
	return score


## What a month at the loom is worth, **net of what it uses up**.
##
## Subtracting the input is what stops a hungry town brewing its grain into beer,
## and it does so without anything here knowing what beer is.
func _score_recipe(recipe: Conversion, town: Town, weights: Dictionary) -> float:
	return recipe.made_by(town) * float(weights.get(String(recipe.output), 1.0)) \
		- recipe.consumes_for(town) * float(weights.get(String(recipe.input), 1.0))


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
	var takes := recipe.consumes_for(town)
	if takes <= 0.0:
		return false
	var share := clampf(on_hand / takes, 0.0, 1.0)
	var used := takes * share
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
