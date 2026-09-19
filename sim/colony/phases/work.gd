class_name WorkPhase
extends ColonyPhase

## **Work.** Each town assigns its population to tiles in its influence area,
## chosen by its objective, each tile's potential, and what the town needs
## (SPEC §11.3). Yields go into the stockpile.
##
## **The quality of the colony sim lives here.** A town that farms mountains
## while starving reads as broken however good the prose is, so the rule that
## picks tiles has to be one a player looking at the map would agree with.
##
## The rule, in order of how much it matters:
##
## 1. **Hunger outranks everything.** A town short of food weights food far above
##    anything else, and the shorter it is the heavier that weight. This is what
##    stops the famine-while-quarrying case.
## 2. **Then what it is building.** Its objective's remaining cost is what it
##    actually wants, so tiles yielding those resources come next.
## 3. **Then value in general**, so a town with nothing pressing still works its
##    best ground rather than standing about.
##
## One worker to a tile, best tiles first. Tiles are scored from the colony as it
## stood when the phase began, never from what this town has already done.

const EVENT_WORKED: StringName = &"town_worked"

## How heavily hunger outranks everything else when a town is at nothing.
const HUNGER_WEIGHT: float = 8.0

## What the objective's needs are worth beside general value.
const OBJECTIVE_WEIGHT: float = 2.5

## Each expert raises his resource by this much, before diminishing returns.
const EXPERT_BONUS: float = 0.25

## **Stacking experts has diminishing returns** (SPEC §12.2): each one after the
## first is worth this share of the one before.
const EXPERT_FALLOFF: float = 0.6


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var tiles := context.tiles_of(town)
	if tiles.is_empty():
		return

	var hunger := _hunger_of(town, before)
	var wanted := _wanted_by_objective(town)

	# Score every tile the town can reach, then take the best ones. Ties break on
	# position so the choice is the map's rather than the iteration order's.
	var scored: Array = []
	for at in tiles:
		scored.append([_score_tile(context, at, hunger, wanted), at])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) > float(b[0])
		var left: Vector2i = a[1]
		var right: Vector2i = b[1]
		return left.y < right.y or (left.y == right.y and left.x < right.x))

	var produced: Dictionary = {}
	var worked := 0
	for entry in scored:
		if worked >= town.workable_tiles():
			break
		var at: Vector2i = entry[1]
		if float(entry[0]) <= 0.0:
			break  # Nothing worth working here.
		worked += 1
		_harvest(town, context, at, produced)

	for resource in produced:
		town.store(StringName(resource), float(produced[resource]))

	context.log.emit(EVENT_WORKED, town.id, context.state.month, {
		"town": String(town.id),
		"tiles_worked": worked,
		"tiles_available": tiles.size(),
		"produced": produced,
	}, WorldPhase.COLONY_MONTH)


## How badly the town wants food, as `0.0` to `1.0`.
##
## Read from the snapshot, so every town in this phase judges its hunger against
## the same month rather than against whatever the town before it did.
func _hunger_of(town: Town, before: ColonySnapshot) -> float:
	var mouths := maxf(1.0, float(town.population()))
	var monthly := mouths * ColonyNeeds.per_head(&"food")
	# Not "is there any food" but "how many months of it", which is the question
	# a governor actually asks.
	var months_held := before.held(town.id, &"food") / maxf(0.001, monthly)
	return clampf(1.0 - months_held / ColonyNeeds.comfortable_months(), 0.0, 1.0)


## The rest of what the town's objective costs it.
func _wanted_by_objective(town: Town) -> Dictionary:
	var building := Building.find(town.objective)
	if building == null:
		return {}
	var wanted: Dictionary = {}
	for resource in building.costed_resources():
		var still_needed := building.cost_of(StringName(resource)) - town.held(StringName(resource))
		if still_needed > 0.0:
			wanted[resource] = still_needed
	return wanted


func _score_tile(context: ColonyContext, at: Vector2i, hunger: float, wanted: Dictionary) -> float:
	var score := 0.0
	for resource in ResourceCatalogue.ids():
		var amount := context.map.yield_at(at.x, at.y, StringName(resource))
		if amount <= 0.0:
			continue
		var weight := 1.0
		if resource == "food":
			weight += hunger * HUNGER_WEIGHT
		if wanted.has(resource):
			weight += OBJECTIVE_WEIGHT
		score += amount * weight
	return score


func _harvest(town: Town, context: ColonyContext, at: Vector2i, into: Dictionary) -> void:
	for resource in ResourceCatalogue.ids():
		var amount := context.map.yield_at(at.x, at.y, StringName(resource))
		if amount <= 0.0:
			continue
		amount *= expert_multiplier(town, StringName(resource))
		amount *= 1.0 + Building.yield_bonus_for(town, StringName(resource))
		into[resource] = float(into.get(resource, 0.0)) + amount


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
