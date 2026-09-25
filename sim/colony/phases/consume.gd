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
	# Thousands of people: every per-head rate is written per thousand (#426).
	var mouths := Population.thousands(float(town.population()))
	var record: Dictionary = {}

	var unmet_food := _eat(town, mouths, context, record)
	_wear(town, mouths, record)
	# 🔒 **After the townspeople and before anything else** (#211, `battles.md`
	# §3). A governor cannot starve his citizens to feed his soldiers, and the
	# order is enforced by the order these run in rather than by a rule anybody
	# has to remember.
	record["companies_fed"] = _victual(town, context)
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
	var for_stock := _feed_required(town, context)
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


## The companies this town supports, fed out of what the people left.
##
## 🔒 **All of it or none of it, per company** (§3). A town that cannot cover a
## company *sends nothing* and that company goes unsupported — half rations would
## be a third state the doc does not have, and it would let a town quietly meter
## its militia down instead of facing the choice.
##
## 🔒 **And it cannot disband its way out of famine.** There is deliberately no
## path here by which a hungry town sheds a company: the failure costs the
## company, never the purse, and the men are still on the map next month.
##
## Returns the share of its companies the town actually managed to victual, for
## the record a governor's letter reads.
func _victual(town: Town, context: ColonyContext) -> float:
	if context.companies == null:
		return 1.0
	var supported := context.companies.supported_by(town.id)
	if supported.is_empty():
		return 1.0

	var fed := 0
	for entry in supported:
		var company: Company = entry
		var rations := company.victuals()
		# **Asked before anything is taken.** Taking what there was and then
		# finding the cloth short would leave the town poorer and the company
		# unsupported anyway, which is the worst of both.
		var can_cover := true
		for resource in rations:
			if town.held(StringName(resource)) < float(rations[resource]):
				can_cover = false
				break
		if not can_cover:
			continue
		for resource in rations:
			town.take(StringName(resource), float(rations[resource]))
		company.was_supplied(context.state.month)
		fed += 1

	return float(fed) / float(supported.size())


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
##
## **The draw itself lives in `QualityOfLife`**, because Exchange needs to know
## what a cellar will be worth *before* buying it (`town-economy.md` §2). One
## function, used from both sides, is the only way the two cannot drift apart.
func _enjoy(town: Town, mouths: float, record: Dictionary) -> void:
	# **What the town can amuse itself with, whatever the ships do** (#153).
	var amusement := Building.amusement_for(town)
	var cap := mouths * ColonyNeeds.luxury_per_head()
	if cap <= 0.0:
		record["luxury"] = float(amusement["served"])
		record["luxury_kinds"] = int(amusement["kinds"])
		return

	var held: Dictionary = {}
	for id in ResourceCatalogue.luxuries():
		held[String(id)] = town.held(StringName(id))

	# **A tea house makes tea go further** (#414): what each measure serves.
	var serves := Building.luxury_serves_for(town)
	var drawn := QualityOfLife.draw_from(mouths, held, serves)
	var ids: PackedStringArray = PackedStringArray(drawn.keys())
	ids.sort()
	var taken := 0.0
	var kinds := 0
	for id in ids:
		var drunk := town.take(StringName(id), float(drawn[id]))
		if drunk > 0.0:
			kinds += 1
		taken += drunk * maxf(1.0, float(serves.get(id, 1.0)))

	record["luxury"] = clampf(taken / cap, 0.0, 1.0) + float(amusement["served"])
	# **Variety is worth something of its own**: beer alone is worth less than
	# beer, rum and tea together (`quality-of-life.md` §4). Counted here because
	# Settle reads a town that has already drunk it.
	record["luxury_kinds"] = kinds + int(amusement["kinds"])


## What the town's herds eat, over what its pasture supports.
func _feed_required(town: Town, context: ColonyContext) -> float:
	var total := 0.0
	var unsupported := unsupported_head(town, context)
	for id in unsupported:
		total += float(unsupported[id]) * ResourceCatalogue.feed_of(StringName(id))
	return total


## The head of each kind that no pasture supports, so the town feeds them grain.
##
## Stock graze on pasture improvements in the town's reach, and shelter in what
## the town has built. Both are capacity; neither is grain. **The cheapest beasts
## graze first.** Public because a governor weighing a pasture asks exactly this
## (`governor-agendas.md` §5, #430), and a second answer would be a second rule.
static func unsupported_head(town: Town, context: ColonyContext) -> Dictionary:
	var pastured := float(Building.pasture_capacity_for(town))
	if context.map != null:
		for at in context.tiles_of(town):
			pastured += float(context.map.livestock_capacity_at(at.x, at.y))
	var out: Dictionary = {}
	for id in _livestock_by_price():
		var head := float(town.livestock_head(StringName(id)))
		var grazing := minf(head, pastured)
		pastured -= grazing
		if head - grazing > 0.0:
			out[id] = head - grazing
	return out


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
##
## ## 🔒 A share, in one event
##
## **Hardship takes a share** (`CLAUDE.md`, `population.md` §6): the toll is the
## town's people times how short it went times the famine rate, removed **in one
## step and reported in one event** that says how many and whose. The same shape
## a battle has — a town of thousands does not lose them one at a time.
##
## 🔒 **Workers before experts, always**, through `Town.take_lives`. And **famine
## never rolls for the Diplomat**: only enemies endanger him.
func _starve(town: Town, unmet: float, context: ColonyContext) -> void:
	if town.months_hungry < FAMINE_MONTHS or unmet <= 0.0:
		return

	var toll := maxi(1, int(round(float(town.population()) * unmet * FAMINE_DEATH_RATE)))
	var taken := town.take_lives(toll)
	if taken.is_empty():
		return  # There is nobody left to lose.
	var count := 0
	for who in taken:
		count += int(taken[who])
	context.log.emit(EVENT_FAMINE, town.id, context.state.month, {
		"town": String(town.id),
		"count": count,
		"taken": taken,
		"remaining": town.population(),
		"months_hungry": town.months_hungry,
		"severity": String(Shortage.grade_of(unmet)),
	}, WorldPhase.COLONY_MONTH)


## Livestock kinds, cheapest first, then by name.
static func _livestock_by_price() -> PackedStringArray:
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
