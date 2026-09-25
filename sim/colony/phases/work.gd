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
## ## Work assigns the hands; Convert is where the town ones do anything
##
## A worker is in the fields or in the town, never both, so tiles and recipes are
## still ranked in one list and the best taken. But a hand put on a recipe is
## **held back** and does nothing until phase 6 (`town-economy.md` §11), which is
## after the town has eaten — so a town cannot brew the grain its people need,
## and that stops being a term in the scorer and becomes arithmetic.
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

	# 🔒 **Every tile's yield, worked out once for this town this month** (#351).
	#
	# Experts do not move inside a phase, buildings do not go up inside a phase
	# and the map does not change inside one either — so what a hand would get
	# off a tile is the same number for the first hand and the twelfth, and
	# `_allocate` was computing it afresh for every tile for every hand.
	#
	# **Per town and per month, and it must stay that way.** A table that
	# outlived either would be reading one town's experts through another town's
	# buildings, which is why it is a local here rather than anything stored.
	#
	# Exactly equivalent: the same four factors in the same order, so the
	# product is the identical double rather than a close one.
	var yields := _yields_for(town, context, tiles)

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
	_allocate(town, before, context, work, desired, yields)

	# **The survival check, after scoring and before anybody goes out.** It may
	# reorder the list; it never rescores it.
	_redirect(town, before, context, work)

	var produced: Dictionary = {}
	# **Hands held back for town work** (`town-economy.md` §11). Work assigns
	# them and Convert, four phases later, is where they do anything — so the
	# grain a brewer would have used has been eaten by then, and the ore a smelter
	# wants may have been bought this month rather than last.
	var held_back: Array = []
	var tiles_worked := 0
	var hands := 0
	# **Which ground, not merely how much of it** (Seam A). Map playback wants
	# it, and so does any question about whether a town's assignment is settled
	# or reshuffling month to month (#116) — neither is answerable from a count.
	var worked: PackedStringArray = PackedStringArray()
	var by_tile: Dictionary = {}

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
			_harvest(at, yields, produced)
			by_tile[_tile_key(at)] = _yields_at(yields, at).duplicate()
		else:
			# **Assigned, not run.** Whether there is anything for him to work on
			# is Convert's question, asked of the stores as they stand then.
			held_back.append(entry["recipe"])
			hands += 1

	for resource in produced:
		town.store(StringName(resource), float(produced[resource]))
	# What the ground gave, for the menus' gates (#429) and, tile by tile, for
	# the governor's reckoning of what an improvement would add (#430).
	town.harvested = produced.duplicate()
	town.harvested_at = by_tile

	context.log.emit(EVENT_WORKED, town.id, context.state.month, {
		"town": String(town.id),
		"tiles_worked": tiles_worked,
		"tiles": worked,
		"tiles_available": tiles.size(),
		"converting": hands - tiles_worked,
		"workers": town.workable_tiles(),
		"produced": produced,
	}, WorldPhase.COLONY_MONTH)

	context.conversions[String(town.id)] = held_back


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
	return maxf(0.0, held - town.mouths() * per_head)


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

	# 🔒 **Food only** (`town-economy.md` §11, #185). No tile yields cloth, and
	# since Convert moved to phase 6 no hand sent to the loom today produces any
	# this month either — so a swap made to answer a clothing shortage moves a
	# man off food to fix nothing. A cold town's remedies are relief, purchase,
	# or next month's loom.
	#
	# **Do not widen this back.** It looks like a regression and is the stated
	# cost of the move.
	var needs := _survival_needs()
	var gives: Array = []
	for entry in work:
		gives.append(_contribution(town, before, context, entry, needs))

	# What the town is short of, before any of this month's work is counted.
	var owed: Dictionary = {}
	var mouths := town.mouths()
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


## What the survival swap can actually do something about, this month.
##
## Anything a tile yields. Cloth is woven rather than harvested and the loom's
## output now lands next month, so it is not among them.
func _survival_needs() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for resource in ColonyNeeds.needed_resources():
		if ResourceCatalogue.inputs_for(StringName(resource)).is_empty():
			out.append(String(resource))
	return out


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
	var ground := _ground_bonus(Building.tile_yield_rules(town), context.map, at, resource)
	return amount * expert_multiplier(town, resource) \
		* (1.0 + Building.yield_bonus_for(town, resource) + ground) * _fallback(town) \
		* _more(context, resource)


## What every tile of this town would yield a hand, this month (#351).
##
## Keyed by tile, holding only the resources that come off it at all — which is a
## handful of the nineteen, so the scoring loop that used to walk the whole
## catalogue per tile per hand now walks what is actually there.
##
## The per-resource multiplier is worked out once as well: `expert_multiplier`
## walks the town's experts and `Building.yield_bonus_for` walks its buildings,
## and neither answer can change between two hands of one phase.
##
## 🔒 **Exactly equivalent, not an approximation.** The same four factors in the
## same order, so the product is the identical double rather than a close one.
func _yields_for(town: Town, context: ColonyContext, tiles: Array) -> Dictionary:
	var multiplier: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		multiplier[resource] = expert_multiplier(town, id) \
			* (1.0 + Building.yield_bonus_for(town, id)) * _fallback(town) * _more(context, id)

	var out: Dictionary = {}
	if context.map == null:
		return out
	# **And what its buildings add on particular ground** (#409). A tile they
	# say nothing about takes the town-wide multiplier exactly as before.
	var rules := Building.tile_yield_rules(town)
	for at in tiles:
		var here: Dictionary = {}
		for resource in ResourceCatalogue.ids():
			var id := StringName(resource)
			var amount := context.map.yield_at(at.x, at.y, id)
			if amount <= 0.0:
				continue
			var ground := _ground_bonus(rules, context.map, at, id)
			if ground == 0.0:
				here[resource] = amount * float(multiplier[resource])
			else:
				here[resource] = amount * expert_multiplier(town, id) \
					* (1.0 + Building.yield_bonus_for(town, id) + ground) * _fallback(town) \
					* _more(context, id)
		out[_tile_key(at)] = here
	return out


## 🔒 **More of a patron's kind, in every town** (#442, `patrons.md` §4): the
## share a standing policy of his adds, read off the world rather than the book.
## Last of the factors everywhere it is applied, so the product stays the
## identical double.
static func _more(context: ColonyContext, resource: StringName) -> float:
	return 1.0 + PolicyEffects.more_of(context.state if context != null else null, resource)


## What the town's buildings add to this resource on this tile's ground (#409):
## its terrain, and the improvement working on it.
static func _ground_bonus(rules: Array, map: WorldMap, at: Vector2i, resource: StringName) -> float:
	if rules.is_empty() or map == null:
		return 0.0
	var improvement := &"" if map.is_idle(at.x, at.y) else map.improvement_at(at.x, at.y)
	return Building.tile_yield_bonus(rules, resource, map.terrain_at(at.x, at.y), improvement)


## 🔒 **No building works every tile a tenth harder** (#429,
## `governor-agendas.md` §3): the town has nothing to build, so its people work
## the ground. One while anything else is the objective.
static func _fallback(town: Town) -> float:
	if town != null and town.objective == AgendaMenu.NO_BUILDING:
		return 1.0 + AgendaMenu.NO_BUILDING_YIELD
	return 1.0


## How a tile is looked up in the yield table.
static func _tile_key(at: Vector2i) -> String:
	return "%d,%d" % [at.x, at.y]


## What one tile yields this town, or nothing for ground it does not hold.
static func _yields_at(yields: Dictionary, at: Vector2i) -> Dictionary:
	return yields.get(_tile_key(at), {})


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
	yields: Dictionary,
) -> void:
	# What the town would be holding, updated as each hand is committed.
	var projected: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		projected[resource] = before.held(town.id, StringName(resource))

	# 🔒 **Valued once, and then only where it moved** (#351).
	#
	# `Valuation.town` over an unchanged `held` returns the identical double, so
	# a worth carried between rounds is the same number rather than a close one —
	# there is no drift to accumulate. What a committed hand touches is at most a
	# recipe's input and output, or the handful of resources one tile yields, and
	# everything else is worth exactly what it was worth a moment ago.
	var worth := _worth_of(projected, desired)

	var chosen: Array = []
	var rounds := mini(town.workable_tiles(), work.size())
	for _hand in rounds:
		var best := -1
		var best_score := 0.0
		for i in work.size():
			var score := _score(town, before, context, work[i], worth, yields)
			if best < 0 or score > best_score + 0.000001 \
					or (absf(score - best_score) <= 0.000001 and _before(work[i], work[best])):
				best = i
				best_score = score
		if best < 0:
			break

		var taken: Dictionary = work[best]
		taken["score"] = best_score
		chosen.append(taken)
		work.remove_at(best)
		_revalue(
			_project(town, before, context, taken, projected, yields),
			projected, desired, worth)

	# The rest, in the order they last scored, so the survival check has a ranked
	# tail to draw a replacement hand from.
	for entry in work:
		entry["score"] = _score(town, before, context, entry, worth, yields)
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
	yields: Dictionary,
) -> float:
	if String(entry["kind"]) == "convert":
		return _score_recipe(entry["recipe"], town, worth)
	return _score_tile(_yields_at(yields, entry["at"]), worth)


## Bring the worth of the resources a hand moved back up to date (#351).
##
## 🔒 **Only those, because only those can have changed.** `Valuation.town` reads
## `desired` and one resource's `held`, so a resource the committed hand did not
## touch values to the same double it did a round ago. Revaluing the other
## eighteen was the second half of §7's cost and none of the answer.
func _revalue(
	touched: PackedStringArray,
	projected: Dictionary,
	desired: DesiredStock,
	worth: Dictionary,
) -> void:
	for resource in touched:
		worth[resource] = Valuation.town(
			StringName(resource), desired, float(projected.get(resource, 0.0)))


## Add what a piece of work would yield to the running projection.
##
## Returns **which resources it moved**, so the valuation can be brought up to
## date where it matters and left alone everywhere else.
func _project(
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
	entry: Dictionary,
	projected: Dictionary,
	yields: Dictionary,
) -> PackedStringArray:
	if String(entry["kind"]) == "convert":
		var recipe: Conversion = entry["recipe"]
		# **Only what it could actually run.** A loom with no furs changes
		# nothing, so it must not look as though it did.
		var share := _feasible(town, before, recipe)
		if share <= 0.0:
			return PackedStringArray()
		var out := String(recipe.output)
		projected[out] = float(projected.get(out, 0.0)) + recipe.made_by(town) * share
		var into := String(recipe.input)
		projected[into] = maxf(0.0,
			float(projected.get(into, 0.0)) - recipe.consumes_for(town) * share)
		return PackedStringArray([out, into])

	var moved := PackedStringArray()
	var here := _yields_at(yields, entry["at"])
	for resource in here:
		projected[resource] = float(projected.get(resource, 0.0)) + float(here[resource])
		moved.append(String(resource))
	return moved


# --- Scoring ----------------------------------------------------------------

## What a month on this ground is worth to this town.
##
## **Scored on what the town would actually get**, experts and buildings
## included, because that is what the allocation then adds to its projection. A
## score that read the bare map while the projection read the town's real yield
## made a food expert *lower* the town's grain: the projection filled the want
## faster than the scoring knew, so the town gave up a field it was scoring as
## though nobody skilled worked it.
func _score_tile(here: Dictionary, weights: Dictionary) -> float:
	var score := 0.0
	for resource in here:
		score += float(here[resource]) * float(weights.get(resource, 1.0))
	return score


## What a month at the loom is worth, **net of what it uses up**.
##
## Subtracting the input is what stops a hungry town brewing its grain into beer,
## and it does so without anything here knowing what beer is.
func _score_recipe(recipe: Conversion, town: Town, weights: Dictionary) -> float:
	return recipe.made_by(town) * float(weights.get(String(recipe.output), 1.0)) \
		- recipe.consumes_for(town) * float(weights.get(String(recipe.input), 1.0))


# --- Doing the work ---------------------------------------------------------

func _harvest(at: Vector2i, yields: Dictionary, into: Dictionary) -> void:
	var here := _yields_at(yields, at)
	for resource in here:
		into[resource] = float(into.get(resource, 0.0)) + float(here[resource])


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
