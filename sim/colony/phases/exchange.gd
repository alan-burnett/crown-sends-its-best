class_name ExchangePhase
extends ColonyPhase

## **Exchange.** The town covers what it still lacks after relief, buying from
## the natives first and the Crown second (SPEC §11.3, #47).
##
## ## The order is the rule
##
## **Needs, then the objective, then luxuries.** Not a preference — the order the
## town spends in *is* "needs before wants", because gold runs out. A town that
## bought rum first and found it could not afford grain would be a town that
## starves for want of a drink, and no amount of commentary elsewhere would make
## that not have happened.
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

## How much luxury a town will lay in, as months of what it can consume.
const LUXURY_MONTHS: float = 1.0


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := context.reckoning_for(town)
	var spent_on: Dictionary = {}

	# 1. Needs, worst first. Reckon fixed *how much* is needed; what the town
	#    still lacks is measured against its stores as this phase began, since
	#    Relief may have covered some of it already.
	for resource in reckoning.shortages():
		var lacking := reckoning.need_of(StringName(resource)) - before.held(town.id, StringName(resource))
		if lacking > 0.0:
			_shop(town, StringName(resource), lacking, context, spent_on)

	# 2. The objective. Wants, and they wait.
	var wanted := Objective.still_to_gather(town)
	var want_ids: PackedStringArray = PackedStringArray(wanted.keys())
	want_ids.sort()
	for resource in want_ids:
		_shop(town, StringName(resource), float(wanted[resource]), context, spent_on)

	# 3. Luxuries, last and only with what is left. Cheapest first — a town
	#    buying comfort gets more of it per coin from beer than from tea.
	var appetite := float(town.population()) * ColonyNeeds.luxury_per_head() * LUXURY_MONTHS
	for resource in _luxuries_by_price():
		if appetite <= 0.0:
			break
		var already := before.held(town.id, StringName(resource))
		var room := minf(appetite, maxf(0.0, appetite - already))
		if room <= 0.0:
			continue
		var got := _shop(town, StringName(resource), room, context, spent_on)
		appetite -= got

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
