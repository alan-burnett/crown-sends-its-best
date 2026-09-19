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
## ## What the score means
##
## Every piece of work is scored as **the weighted resources it adds this
## month**. A recipe subtracts what it consumes, so brewing the last of the grain
## into beer scores terribly in a hungry town — without anything in code knowing
## what beer is.
##
## Weights, in order of how much they matter:
##
## 1. **Need outranks everything.** A town short of something it will die
##    without weights that thing far above anything else, and the shorter it is
##    the heavier the weight. **Food and clothing are lockstep** (SPEC §11.3
##    step 2), so this is one rule over both rather than a hunger rule and a
##    separate afterthought about cloth.
## 2. **Then what its objective calls for.** A construction wants its remaining
##    cost; a standing posture wants its focus resources and goes on wanting them.
## 3. **Then what the thing is worth**, so a town with nothing pressing still
##    works its best ground rather than standing about — and so that a recipe,
##    which always takes more raw than it makes processed, can be seen for the
##    gain it is.
##
## One worker to a tile or a recipe, best first. Everything is scored from the
## colony as it stood when the phase began, never from what this town has already
## done this month.

const EVENT_WORKED: StringName = &"town_worked"
const EVENT_CONVERTED: StringName = &"town_converted"

## How heavily an unmet need outranks everything else when a town is at nothing.
const NEED_WEIGHT: float = 8.0

## What the objective's needs are worth beside general value.
const OBJECTIVE_WEIGHT: float = 2.5

## What an input is worth against the need it becomes.
##
## Less than the need itself, because it still costs a worker and a month to turn
## one into the other — but most of it, or a cold town would never send anybody
## to the traplines.
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
	# Two readings of what a resource is worth, and the difference matters.
	#
	# `worth` is what the town wants of a thing in itself. `gathering` adds what
	# it is worth as an *input* to something the town needs, which is what sends
	# trappers out for furs when the people are cold.
	#
	# **Tiles are scored against `gathering`; a recipe pays `worth` for what it
	# consumes.** Charging the recipe the gathering price would double-count: furs
	# are dear precisely because they become cloth, so making the loom pay that
	# price makes weaving look barely worth doing and the cloth never gets woven.
	var worth := _worth(town, before, wanted, focus)
	var gathering := _gathering(town, before, worth)
	var tiles := context.tiles_of(town)

	# Tiles and recipes, scored the same way and ranked together. Ties break on a
	# fixed rule, so the choice is the colony's rather than the iteration order's.
	var work: Array = []
	for at in tiles:
		work.append({"kind": "tile", "at": at, "score": _score_tile(context, at, gathering)})
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

	var produced: Dictionary = {}
	var converted: Dictionary = {}
	# **The start-of-month stockpile**, spent down as recipes claim from it, so
	# two recipes cannot both smelt the same ore and nothing bought this month
	# can be processed this month.
	var available: Dictionary = {}
	var tiles_worked := 0
	var hands := 0

	for entry in work:
		if hands >= town.workable_tiles():
			break
		if float(entry["score"]) <= 0.0:
			break  # Nothing left here is worth a worker.
		if String(entry["kind"]) == "tile":
			hands += 1
			tiles_worked += 1
			_harvest(town, context, entry["at"], produced)
		elif _convert(town, before, entry["recipe"], available, converted):
			hands += 1

	for resource in produced:
		town.store(StringName(resource), float(produced[resource]))

	context.log.emit(EVENT_WORKED, town.id, context.state.month, {
		"town": String(town.id),
		"tiles_worked": tiles_worked,
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
## **Read from the snapshot**, so every town in this phase judges itself against
## the same month rather than against whatever the town before it did.
func _worth(town: Town, before: ColonySnapshot, wanted: Dictionary, focus: PackedStringArray) -> Dictionary:
	var weights: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		var weight := value_of(StringName(resource))
		weight += _urgency_of(town, before, StringName(resource)) * NEED_WEIGHT
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


## What a resource is worth to go out and fetch.
##
## **A town short of cloth values furs.** Urgency flows back along the conversion
## chains, or a need that is not a tile yield can never be worked towards: the
## loom stands idle for want of furs, and nobody traps furs because raw furs are
## not a need. That circle is exactly what SPEC §11.3's food-and-clothing
## lockstep requires be broken, and it is why the flow-back is part of the rule
## rather than a refinement of it.
func _gathering(town: Town, before: ColonySnapshot, worth: Dictionary) -> Dictionary:
	var weights := worth.duplicate()
	for output in ResourceCatalogue.processed():
		var urgency := _urgency_of(town, before, StringName(output))
		if urgency <= 0.0:
			continue
		for input in ResourceCatalogue.inputs_for(StringName(output)):
			weights[input] = maxf(
				float(weights.get(input, 1.0)),
				value_of(StringName(input)) + urgency * NEED_WEIGHT * INPUT_SHARE,
			)
	return weights


## How badly the town wants something it will die without, as `0.0` to `1.0`.
##
## **Food and clothing are lockstep.** Both are needs and both are measured the
## same way — not "is there any" but "how many months of it", which is the
## question a governor actually asks. This is what lets labour be redirected
## towards cloth, which it could not be while hunger was the only urgency in the
## phase and cloth was not a tile yield.
##
## A resource that is not a need scores zero and is left to its general value.
func _urgency_of(town: Town, before: ColonySnapshot, resource: StringName) -> float:
	var per_head := ColonyNeeds.per_head(resource)
	if per_head <= 0.0:
		return 0.0
	var monthly := maxf(1.0, float(town.population())) * per_head
	var months_held := before.held(town.id, resource) / maxf(0.001, monthly)
	var short_by := clampf(1.0 - months_held / ColonyNeeds.comfortable_months(), 0.0, 1.0)
	# **Scaled by how fast going without it kills you.** Hunger and cold are both
	# needs and both are counted, but they are not the same emergency.
	return short_by * ColonyNeeds.severity(resource)


# --- Scoring ----------------------------------------------------------------

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
		available[key] = before.held(town.id, recipe.input)

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
