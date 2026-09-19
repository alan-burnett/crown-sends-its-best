class_name ExchangePhase
extends ColonyPhase

## **Exchange.** The town covers what it still lacks after relief, buying from
## the natives first and the Crown second (SPEC §11.3, #47).
##
## ## The order is the rule
##
## **Needs, then the objective, then wants** — SPEC §11.3's three tiers, in
## order. Not a preference: the order the town spends in *is* the rule, because
## gold runs out. A town that bought rum first and found it could not afford
## grain would be a town that starves for want of a drink, and no amount of
## commentary elsewhere would make that not have happened.
##
## All three quantities come from Reckon. Exchange decides what to buy first, not
## how much of it the town wanted.
##
## Within needs, **worst first**: the resource the town is deepest short of is
## bought before the one it is merely light on. A town that cannot cover
## everything covers the thing that will kill it.
##
## ## Natives first
##
## SPEC §11.3 puts natives ahead of the Crown, and M5 gives the colony natives to
## trade with. The call is here now, returns nothing, and is the only place M5
## has to change — rather than M5 discovering that "buy" has meant "buy from the
## Crown" in fifteen places.

const EVENT_SHOPPED: StringName = &"town_exchanged"

## How much comfort a town lays in altogether.
##
## Reckon says how much of *each* luxury the town would like; this is what it
## will actually carry home in one month, across all of them. Set to several
## kinds' worth rather than one, because **variety is worth something**
## (`quality-of-life.md` §4): a town with beer, rum and tea is happier than a
## town with the same quantity of beer alone, and a town that only ever bought
## the cheapest thing on the list would never find that out.
func _comfort_budget(town: Town) -> float:
	return float(town.population()) * ColonyNeeds.luxury_per_head() * QualityOfLife.VARIETY_TARGET


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := context.reckoning_for(town)
	var spent_on: Dictionary = {}

	# 1. Tier 1, needs, worst first. Reckon fixed *how much* is needed; what the
	#    town still lacks is measured against its stores as this phase began,
	#    since Relief may have covered some of it already.
	for resource in reckoning.shortages():
		var lacking := reckoning.need_of(StringName(resource)) - before.held(town.id, StringName(resource))
		if lacking > 0.0:
			_shop(town, StringName(resource), lacking, context, spent_on)

	# 2. Tier 2, the objective. It waits behind survival and nothing else.
	var required := reckoning.objective
	var required_ids: PackedStringArray = PackedStringArray(required.keys())
	required_ids.sort()
	for resource in required_ids:
		_shop(town, StringName(resource), float(required[resource]), context, spent_on)

	# 3a. Tier 3, the governor's ambitions: guns for a military intent, timber
	#     and stone for a builder. **What makes an intent reach the economy** —
	#     without it, the only thing a letter changes is which project is picked.
	var stocked: PackedStringArray = PackedStringArray()
	for resource in reckoning.wants:
		if not ResourceCatalogue.is_luxury(StringName(resource)):
			stocked.append(String(resource))
	stocked.sort()
	for resource in stocked:
		_shop(town, StringName(resource), reckoning.want_of(StringName(resource)), context, spent_on)

	# 3b. Tier 3, comforts, last and only with what is left. Cheapest first
	#    — a town buying comfort gets more of it per coin from beer than from tea.
	var purse := _comfort_budget(town)
	for resource in _luxuries_by_price():
		if purse <= 0.0:
			break
		var room := reckoning.want_of(StringName(resource))
		if room <= 0.0:
			continue
		purse -= _shop(town, StringName(resource), minf(room, purse), context, spent_on)

	if spent_on.is_empty():
		return

	context.log.emit(EVENT_SHOPPED, town.id, context.state.month, {
		"town": String(town.id),
		"bought": spent_on,
	}, WorldPhase.COLONY_MONTH)


## Buy up to `wanted`, natives first. Returns what was actually obtained.
func _shop(
	town: Town,
	resource: StringName,
	wanted: float,
	context: ColonyContext,
	into: Dictionary,
) -> float:
	var got := _buy_from_natives(town, resource, wanted, context)
	if wanted - got > 0.0:
		var deal := Trade.buy(town, resource, wanted - got, context)
		got += float(deal["received"])
	if got > 0.0:
		into[String(resource)] = float(into.get(String(resource), 0.0)) + got
	return got


## **The M5 seam.** Natives come ahead of the Crown in SPEC §11.3 and there are
## none yet, so this buys nothing — but it buys nothing *in the right place*.
func _buy_from_natives(
	_town: Town,
	_resource: StringName,
	_wanted: float,
	_context: ColonyContext,
) -> float:
	return 0.0


## Luxuries, cheapest first, then by name.
func _luxuries_by_price() -> PackedStringArray:
	var entries: Array = []
	for id in ResourceCatalogue.ids():
		if ResourceCatalogue.is_luxury(StringName(id)):
			entries.append([ResourceCatalogue.price_of(StringName(id)), String(id)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		return String(a[1]) < String(b[1]))

	var out: PackedStringArray = PackedStringArray()
	for entry in entries:
		out.append(String(entry[1]))
	return out
