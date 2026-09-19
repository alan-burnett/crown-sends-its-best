class_name ConsumePhase
extends ColonyPhase

## **Consume.** People and livestock eat, clothing wears out, luxuries are
## enjoyed, and going without hurts (SPEC §11.3, §12.2, #48).
##
## ## Shortage is a gradient
##
## **This is the main pressure the player feels in M2**, and it reaches them
## entirely through the governor's letters. A letter that can only say "we are
## short of food" says the same thing whether the town missed a meal or is eating
## its plough horses — and a player who cannot tell those apart cannot act on the
## difference. So the unmet share is recorded as a number and named by `Shortage`,
## and the perception ladders have rungs to climb.
##
## ## Famine is sustained, not sudden
##
## One thin month is a thin month. **People die when hunger persists**, which is
## what `months_hungry` counts. A town that goes short, is relieved by a
## neighbour, and eats the next month has lost nothing — the counter resets. That
## asymmetry is what makes relief and a timely order *worth* something rather
## than merely nice.
##
## ## Livestock
##
## Stock eat unless the town has pasture for them. **A town that would otherwise
## go hungry eats them instead** (SPEC §12.2) — which is why slaughter happens
## before anybody sits down, not after the town has already starved. It is a
## last resort that works, and it costs the town its herd.
##
## ## Luxuries are capped
##
## Comfort from drink has a ceiling. Without one, a town with money buys its way
## to perfect contentment and quality of life stops being about how the colony is
## run.

const EVENT_CONSUMED: StringName = &"town_consumed"
const EVENT_WENT_SHORT: StringName = &"town_went_short"
const EVENT_SLAUGHTERED: StringName = &"livestock_slaughtered"
const EVENT_FAMINE: StringName = &"famine_deaths"

## Months of meaningful hunger before people start dying.
const FAMINE_MONTHS: int = 3

## Share of the population lost in a famine month, at total starvation. Tuning.
const FAMINE_DEATH_RATE: float = 0.12


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	var mouths := float(town.population())
	var record: Dictionary = {}

	var unmet_food := _eat(town, mouths, context, record)
	_wear(town, mouths, record)
	_enjoy(town, mouths, record)

	context.wellbeing[String(town.id)] = record

	context.log.emit(EVENT_CONSUMED, town.id, context.state.month, {
		"town": String(town.id),
		"population": town.population(),
		"consumed": record,
		"months_hungry": town.months_hungry,
	}, WorldPhase.COLONY_MONTH)

	_starve(town, unmet_food, context)


## Food, for people and stock. Returns the share of the people's need that went
## unmet.
func _eat(town: Town, mouths: float, context: ColonyContext, record: Dictionary) -> float:
	var for_people := mouths * ColonyNeeds.per_head(&"food")
	var for_stock := _feed_required(town)
	var short_by := (for_people + for_stock) - town.held(&"food")
	if short_by > 0.0:
		_slaughter(town, short_by, context)

	# **People before stock.** A town short of grain does not feed the cattle and
	# then wonder why.
	var eaten := town.take(&"food", for_people)
	var to_stock := town.take(&"food", for_stock)

	var unmet := Shortage.unmet(for_people, eaten)
	record["food"] = 1.0 - unmet
	record["stock_fed"] = 1.0 if for_stock <= 0.0 else to_stock / for_stock

	if Shortage.is_short(unmet):
		town.months_hungry += 1
		context.log.emit(EVENT_WENT_SHORT, town.id, context.state.month, {
			"town": String(town.id),
			"resource": "food",
			"needed": for_people,
			"had": eaten,
			"unmet": unmet,
			"severity": String(Shortage.grade_of(unmet)),
			"months_hungry": town.months_hungry,
		}, WorldPhase.COLONY_MONTH)
	else:
		town.months_hungry = 0

	return unmet


## Clothing. Nobody dies of it; they are simply cold, and say so.
func _wear(town: Town, mouths: float, record: Dictionary) -> void:
	var needed := mouths * ColonyNeeds.per_head(&"clothing")
	if needed <= 0.0:
		record["clothing"] = 1.0
		return
	var worn := town.take(&"clothing", needed)
	record["clothing"] = worn / needed


## Luxuries, up to the cap. The share of the cap actually met is what Settle
## reads; a town with no luxuries at all is not *suffering*, merely dull.
func _enjoy(town: Town, mouths: float, record: Dictionary) -> void:
	var cap := mouths * ColonyNeeds.luxury_per_head()
	if cap <= 0.0:
		record["luxury"] = 0.0
		return
	var taken := 0.0
	for id in ResourceCatalogue.ids():
		if taken >= cap:
			break
		if not ResourceCatalogue.is_luxury(StringName(id)):
			continue
		taken += town.take(StringName(id), cap - taken)
	record["luxury"] = clampf(taken / cap, 0.0, 1.0)


## What the town's herds eat, over what its pasture supports.
func _feed_required(town: Town) -> float:
	var pastured := float(Building.pasture_capacity_for(town))
	var total := 0.0
	for id in _livestock_by_price():
		var head := float(town.livestock_head(StringName(id)))
		var grazing := minf(head, pastured)
		pastured -= grazing
		total += (head - grazing) * ResourceCatalogue.feed_of(StringName(id))
	return total


## Eat the herd, cheapest beast first, until the gap is closed.
##
## **Only ever called when the town would otherwise go hungry.** A town with
## grain in the store does not touch its cattle.
func _slaughter(town: Town, short_by: float, context: ColonyContext) -> void:
	var killed: Dictionary = {}
	var gained := 0.0
	for id in _livestock_by_price():
		if gained >= short_by:
			break
		var kind := StringName(id)
		var per_head := ResourceCatalogue.slaughter_yield_of(kind)
		if per_head <= 0.0:
			continue
		var wanted := int(ceil((short_by - gained) / per_head))
		var head := mini(wanted, town.livestock_head(kind))
		if head <= 0:
			continue
		town.add_livestock(kind, -head)
		var food := float(head) * per_head
		town.store(&"food", food)
		gained += food
		killed[id] = head

	if killed.is_empty():
		return

	context.log.emit(EVENT_SLAUGHTERED, town.id, context.state.month, {
		"town": String(town.id),
		"killed": killed,
		"food": gained,
		"short_by": short_by,
	}, WorldPhase.COLONY_MONTH)


## The severe end. Rare in M2 given a sensible objective, and it should read as
## a disaster when it happens rather than as a number ticking down.
func _starve(town: Town, unmet: float, context: ColonyContext) -> void:
	if town.months_hungry < FAMINE_MONTHS or unmet <= 0.0:
		return
	var lost := maxi(1, int(round(float(town.population()) * unmet * FAMINE_DEATH_RATE)))
	lost = _take_lives(town, lost)
	if lost <= 0:
		return
	context.log.emit(EVENT_FAMINE, town.id, context.state.month, {
		"town": String(town.id),
		"lost": lost,
		"remaining": town.population(),
		"months_hungry": town.months_hungry,
		"severity": String(Shortage.grade_of(unmet)),
	}, WorldPhase.COLONY_MONTH)


## Workers first, then experts. **A colony loses its skilled men last** — they
## are fed by the rest as long as there is anything to feed them with, and losing
## one is a blow the town feels for years.
func _take_lives(town: Town, count: int) -> int:
	var taken := mini(count, town.workers)
	town.workers -= taken
	var left := count - taken

	var kinds: PackedStringArray = PackedStringArray(town.experts.keys())
	kinds.sort()
	for kind in kinds:
		if left <= 0:
			break
		var here := mini(left, town.expert_count(StringName(kind)))
		if here <= 0:
			continue
		town.add_experts(StringName(kind), -here)
		left -= here
		taken += here
	return taken


## Livestock kinds, cheapest first, then by name.
func _livestock_by_price() -> PackedStringArray:
	var entries: Array = []
	for id in ResourceCatalogue.ids():
		if ResourceCatalogue.is_livestock(StringName(id)):
			entries.append([ResourceCatalogue.price_of(StringName(id)), String(id)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		return String(a[1]) < String(b[1]))

	var out: PackedStringArray = PackedStringArray()
	for entry in entries:
		out.append(String(entry[1]))
	return out
