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

## How many purchases a town makes in one month before it stops reconsidering.
##
## Enough to fill a cellar with several kinds; bounded, so choosing comforts is
## a short loop rather than a search.
const COMFORT_ROUNDS: int = 8


## Spend the comfort purse on whatever is worth the most per gold, a little at a
## time, until the money or the appetite runs out.
##
## ## Why a loop and not a list
##
## **What is worth buying changes as the cellar fills.** A town swimming in tea
## gets more from its first rum than its hundredth tea, so the second purchase of
## a month is not necessarily the same as the first. That is the variety bonus in
## `quality-of-life.md` §4 read backwards, and it cannot be expressed as a
## quantity worked out in advance.
##
## ## What it buys, and what it will not
##
## Each step picks the comfort with the best **quality of life per gold at the
## margin**, where the gold includes that resource's duty. So:
##
## - A town that already has a heap of one thing turns to another, dearer one.
## - **A town that can make a comfort never buys it.** A sugar plantation makes
##   rum at near-zero marginal cost, and the Crown sells it none.
## - **Raising the duty on one comfort pushes the town onto the others.** That
##   is the backfire SPEC §10.2 describes — tax tea heavily and towns shift to
##   the rum they distil themselves, and the Crown collects nothing rather than
##   more. It falls out of this rather than being written anywhere.
func _buy_comfort(
	town: Town,
	reckoning: Reckoning,
	context: ColonyContext,
	into: Dictionary,
) -> void:
	var budget := reckoning.comfort_budget
	if budget <= 0.0:
		return

	var mouths := maxf(1.0, float(town.population()))
	var step := mouths * ColonyNeeds.luxury_per_head() / QualityOfLife.VARIETY_TARGET
	if step <= 0.0:
		return

	var purse := budget
	for _round in COMFORT_ROUNDS:
		if purse <= 0.0:
			break
		var best := _best_value(town, mouths, step, reckoning, context)
		if String(best) == "":
			break

		var outlay := step * ResourceCatalogue.price_of(best) * (1.0 + context.tax_rate(best))
		var got := _shop(town, best, minf(step, purse / maxf(0.001, outlay / step)), context, into)
		if got <= 0.0:
			break
		purse -= outlay


## Which comfort is worth the most per gold right now, or empty.
func _best_value(
	town: Town,
	mouths: float,
	step: float,
	reckoning: Reckoning,
	context: ColonyContext,
) -> StringName:
	var held: Dictionary = {}
	for id in ResourceCatalogue.luxuries():
		held[String(id)] = town.held(StringName(id))

	var best := &""
	var best_value := 0.0
	for id in ResourceCatalogue.luxuries():
		var resource := StringName(id)
		if _makes_its_own(town, resource, step, reckoning):
			continue
		var price := ResourceCatalogue.price_of(resource) * (1.0 + context.tax_rate(resource))
		if price <= 0.0:
			continue
		var value := QualityOfLife.marginal_pleasure(mouths, held, resource, step) / (price * step)
		# Ties break on the name, so the choice is the colony's rather than the
		# catalogue's iteration order.
		if value > best_value + 0.000001 or (
			absf(value - best_value) <= 0.000001 and String(best) != "" and String(id) < String(best)
		):
			best = resource
			best_value = value
	return best if best_value > 0.0 else &""


## Whether the town can make this month's drinking for itself.
##
## **A town with a sugar plantation has rum at near-zero marginal cost and never
## buys it** (`town-economy.md` §2).
##
## ## Spare input, not any input
##
## The test is the input the town holds **over what Reckon has reserved**, and
## enough of it to be worth a batch. Holding a scrap is not a plantation: beer is
## brewed from food, so "holds any food at all" would mean no fed town ever buys
## a beer — the cheapest comfort in the colony would be unpurchasable, and the
## duty on it would be an instrument that moves nothing. A town buying its dinner
## from the Crown has no grain to spare for the brewhouse and buys its beer too.
func _makes_its_own(
	town: Town,
	resource: StringName,
	step: float,
	reckoning: Reckoning,
) -> bool:
	var per_unit := ResourceCatalogue.input_per_unit_of(resource)
	if per_unit <= 0.0:
		return false
	var batch := step * per_unit
	for input in ResourceCatalogue.inputs_for(resource):
		var kind := StringName(input)
		if town.held(kind) - reckoning.reserve_of(kind) >= batch:
			return true
	return false


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := context.reckoning_for(town)
	var spent_on: Dictionary = {}

	# 1. Tier 1, needs, worst first. Reckon fixed *how much* is needed; what the
	#    town still lacks is measured against its stores as this phase began,
	#    since Relief may have covered some of it already.
	for resource in reckoning.shortages():
		var lacking := reckoning.need_of(StringName(resource)) - before.held(town.id, StringName(resource))
		if lacking > 0.0:
			_shop(town, StringName(resource), lacking, context, spent_on, Trade.TIER_NEED)

	# 2. Tier 2, the objective. It waits behind survival and nothing else.
	var required := reckoning.objective
	var required_ids: PackedStringArray = PackedStringArray(required.keys())
	required_ids.sort()
	for resource in required_ids:
		_shop(town, StringName(resource), float(required[resource]), context, spent_on,
			Trade.TIER_OBJECTIVE)

	# 3a. Tier 3, the governor's ambitions: guns for a military intent, timber
	#     and stone for a builder. **What makes an intent reach the economy** —
	#     without it, the only thing a letter changes is which project is picked.
	var stocked: PackedStringArray = PackedStringArray()
	for resource in reckoning.wants:
		if not ResourceCatalogue.is_luxury(StringName(resource)):
			stocked.append(String(resource))
	stocked.sort()
	for resource in stocked:
		_shop(town, StringName(resource), reckoning.want_of(StringName(resource)),
			context, spent_on, Trade.TIER_OBJECTIVE)

	# 3b. Comforts, last and only with what is left — and chosen at the margin
	#     rather than by price, which is what makes a per-resource duty a real
	#     instrument (`town-economy.md` §2).
	_buy_comfort(town, reckoning, context, spent_on)

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
	tier: StringName = Trade.TIER_WANT,
) -> float:
	var got := _buy_from_natives(town, resource, wanted, context)
	if wanted - got > 0.0:
		var deal := Trade.buy(town, resource, wanted - got, context, tier)
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
