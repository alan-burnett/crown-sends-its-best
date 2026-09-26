class_name ExchangePhase
extends ColonyPhase

## **Exchange.** The town covers what it still lacks after relief, buying from
## the natives first and the Crown second (SPEC §11.3, #47).
##
## ## One list, and the tiers favour rather than gate
##
## **This was three loops in tier order and the Author revised §11.3 out from
## under it** (#137). Towns "will behave realistically — trying to keep a reserve
## month to month when their survival is not at stake, and spending a little on
## luxuries even when there are more important things to buy."
##
## Sequential tiers cannot do that second half. A town works down its needs, then
## its project, then its comforts, and if the gold runs out at any point
## everything below is simply not bought — so a town one coin short of cloth buys
## no beer at all, ever, which is a different town from the one the spec
## describes.
##
## So every candidate purchase — a sack of grain, a beam for the chapel, a
## measure of rum — goes in **one list scored at what it is worth per gold**, and
## the tier is a heavy multiplier on the worth. A very cheap comfort can outrank
## a very expensive marginal need. Needs still win nearly always, because eight
## times a shortage valuation is a large number, but they win on the arithmetic
## rather than on their position in the file.
##
## **Worst first falls out of it.** The resource a town is deepest short of has
## the highest valuation, so it is bought first without a rule saying so.
##
## ## A step at a time, because worth moves as the cart fills
##
## Nothing here can be worked out in advance. Buying grain lowers what the next
## grain is worth; buying tea makes rum the better drink. So the month is a short
## loop that scores everything, buys one step of the best, and looks again.
##
## ## Natives first
##
## SPEC §11.3 puts natives ahead of the Crown, and M5 gives the colony natives to
## trade with. The call is here now, returns nothing, and is the only place M5
## has to change — rather than M5 discovering that "buy" has meant "buy from the
## Crown" in fifteen places.

const EVENT_SHOPPED: StringName = &"town_exchanged"

## What share of an outstanding want a town buys in one round.
##
## A quarter, so the tiers interleave. Buying the whole of a want in one purchase
## would let the first candidate swallow the purse and put the sequential tiers
## back by another road.
const STEP_SHARE: float = 0.25


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
	var desired := DesiredStock.for_town(town, before)
	var mouths := town.mouths()
	var reserve := Spending.purse_reserve(town, context)
	var spent_on: Dictionary = {}

	# What the town holds, updated as it shops, so the second sack of grain is
	# scored against a town that already has the first.
	var projected: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		projected[resource] = before.held(town.id, StringName(resource))

	# What each tier still wants, drawn down as it is covered.
	var outstanding := _wanted(town, before, reckoning)
	# What it has laid out on drink so far, against the small allowance §4 lets
	# it keep for that whatever else is going on.
	var on_comfort := 0.0

	for _round in Spending.rounds():
		var best := _best(
			town, context, desired, reckoning, outstanding, projected, mouths, reserve, on_comfort
		)
		if best.is_empty():
			break

		var resource := StringName(best["resource"])
		var key: String = best["key"]
		var bought := _shop(
			town, resource, float(best["step"]), context, spent_on, StringName(best["tier"])
		)
		var got := float(bought["got"])
		if got <= 0.0:
			# It could not be had at all — the town is out of gold, or the Crown
			# will not deal. Taking it off the list stops the loop asking again.
			outstanding.erase(key)
			continue

		projected[String(resource)] = float(projected.get(String(resource), 0.0)) + got
		if ResourceCatalogue.is_luxury(resource):
			on_comfort += got * Valuation.crown(resource, context.state) \
				* (1.0 + context.tax_rate(resource))
			continue
		var entry: Dictionary = outstanding.get(key, {})
		# 🔒 **A need's budget is spent once** (#453, SPEC §10.2). What comes off
		# the want is what the gold would have bought without the duty, not what
		# arrived — so a dearer month carries home less for the same money, rather
		# than going back for the rest and spending more.
		var left := float(entry.get("left", 0.0)) - float(bought["covered"])
		if left > float(entry.get("step", 0.0)) * 0.5:
			entry["left"] = left
		else:
			# **Near enough is done.** A town that kept buying a quarter of what
			# was left would buy ever smaller slivers of the same thing and never
			# get to the next one — which it did, for all twenty rounds.
			outstanding.erase(key)

	if spent_on.is_empty():
		return

	context.log.emit(EVENT_SHOPPED, town.id, context.state.month, {
		"town": String(town.id),
		"bought": spent_on,
	}, WorldPhase.COLONY_MONTH)


## Everything the town wants and has not got, by tier, keyed `resource|tier`.
##
## The quantities are still Reckon's. Exchange decides what to buy first, not
## how much of it the town wanted.
func _wanted(town: Town, before: ColonySnapshot, reckoning: Reckoning) -> Dictionary:
	var out: Dictionary = {}
	for resource in reckoning.shortages():
		var lacking := reckoning.need_of(StringName(resource)) \
			- before.held(town.id, StringName(resource))
		if lacking > 0.0:
			out[String(resource) + "|" + String(Spending.NEED)] = _portioned(lacking)
	# 🔒 **Companies, above the objective** (#211, `battles.md` §3). What Reckon
	# wrote down, over what the town already has — the same shape a need takes,
	# because it is the same food.
	for resource in reckoning.companies:
		var rations := reckoning.company_of(StringName(resource)) \
			- before.held(town.id, StringName(resource))
		if rations > 0.0:
			out[String(resource) + "|" + String(Spending.COMPANY)] = _portioned(rations)
	for resource in reckoning.objective:
		var required := float(reckoning.objective[resource])
		if required > 0.0:
			out[String(resource) + "|" + String(Spending.OBJECTIVE)] = _portioned(required)
	for resource in reckoning.wants:
		if ResourceCatalogue.is_luxury(StringName(resource)):
			continue
		var wanted := reckoning.want_of(StringName(resource))
		var key := String(resource) + "|" + String(Spending.OBJECTIVE)
		if wanted > 0.0 and wanted > float(out.get(key, {}).get("left", 0.0)):
			out[key] = _portioned(wanted)
	return out


## A want, with the size of one round's purchase fixed when it is created.
##
## 🔒 **Fixed, not a share of what is left.** A quarter of the remainder is Zeno's
## paradox: the town buys a quarter, then a quarter of the rest, and after twenty
## rounds it has spent the whole month on slivers of one resource and never
## looked at the second. The step has to be a share of the *original* want so the
## list actually empties.
func _portioned(amount: float) -> Dictionary:
	return {"left": amount, "step": maxf(amount * STEP_SHARE, Trade.EPSILON)}


## The best gold can do this round, or empty.
##
## Scored as **worth per gold**, where worth is the town's own valuation times
## what the tier does to it, and gold is the landed price including the duty.
func _best(
	town: Town,
	context: ColonyContext,
	desired: DesiredStock,
	reckoning: Reckoning,
	outstanding: Dictionary,
	projected: Dictionary,
	mouths: float,
	reserve: float,
	on_comfort: float,
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0

	var keys: PackedStringArray = PackedStringArray(outstanding.keys())
	keys.sort()
	for key in keys:
		var parts := key.split("|")
		var resource := StringName(parts[0])
		var tier := StringName(parts[1])
		var held := float(projected.get(parts[0], 0.0))
		# §3's gate still applies: a town does not pay more for a thing than it
		# thinks the thing is worth, whatever tier is asking for it.
		if not Valuation.worth_buying(resource, desired, held, context):
			continue
		var landed := Valuation.crown(resource, context.state) * (1.0 + context.tax_rate(resource))
		if landed <= 0.0:
			continue
		var entry: Dictionary = outstanding[key]
		var step := minf(float(entry["left"]), float(entry["step"]))
		if not _affordable(town, landed, step, tier, reserve):
			continue
		var score := Valuation.town(resource, desired, held) \
			* Spending.tier_multiplier(tier) * _urgency(resource, tier) / landed
		if score > best_score + 0.000001:
			best_score = score
			best = {"resource": parts[0], "tier": String(tier), "step": step, "key": key}

	var comfort := _best_comfort(town, reckoning, context, projected, mouths, on_comfort)
	if not comfort.is_empty() and float(comfort["score"]) > best_score + 0.000001:
		return comfort
	return best


## How fast going without this one kills you, for a need (§11.3 step 2).
##
## **Needs are not equal and their valuations do not say so.** A town with no
## grain is dead in weeks; a town with no cloth is merely wretched, for months.
## Cloth is the dearer thing — `base` 11 against grain's 2 — so on valuation
## alone a starving town buys itself a coat, which is the failure
## `ColonyNeeds.severity` was written for and the reason it is applied here
## rather than folded into `base`.
##
## Only needs have one. Nothing else is survival.
func _urgency(resource: StringName, tier: StringName) -> float:
	return ColonyNeeds.severity(resource) if tier == Spending.NEED else 1.0


## The comfort worth the most per gold at the margin, or empty.
##
## **Scored on pleasure rather than on `base`**, and then converted to gold so it
## can be ranked beside a sack of grain. What a luxury is worth to a town is what
## the next measure does for the people drinking it — which falls as the cellar
## fills and depends on what else is in there — and an authored figure per
## resource cannot say that.
func _best_comfort(
	town: Town,
	reckoning: Reckoning,
	context: ColonyContext,
	projected: Dictionary,
	mouths: float,
	on_comfort: float,
) -> Dictionary:
	var step := mouths * ColonyNeeds.luxury_per_head() / QualityOfLife.VARIETY_TARGET
	if step <= 0.0:
		return {}

	var cellar: Dictionary = {}
	for id in ResourceCatalogue.luxuries():
		cellar[String(id)] = float(projected.get(String(id), 0.0))

	var best: Dictionary = {}
	var best_score := 0.0
	for id in ResourceCatalogue.luxuries():
		var resource := StringName(id)
		if _makes_its_own(town, resource, step, reckoning):
			continue
		var landed := Valuation.crown(resource, context.state) * (1.0 + context.tax_rate(resource))
		# **A small allowance, outside the purse reserve.** The two halves of §4
		# contradict each other otherwise: a reserve big enough to be worth
		# holding is bigger than a poor town's whole purse, so gating comfort on
		# it means a town short of anything buys no comfort at all — which is the
		# strict gate the Author's revision removed, wearing a different coat.
		#
		# So the allowance is always available and the ranking decides *when* it
		# is spent, rather than a separate pass deciding *that* it is.
		if landed * step + on_comfort > reckoning.comfort_budget:
			continue
		if landed <= 0.0 or not town.can_afford(landed * step):
			continue
		# **Against what the town already has to amuse itself with** (#153). A town
		# with a theatre gets less from its next measure of rum and should buy
		# accordingly, or the buying side and the drinking side are back on two
		# theories of what a month of pleasure is worth.
		# **And against how far each measure goes here** (#414): a tea-house town
		# values tea more, with no second theory of what a cellar is worth.
		var pleasure := QualityOfLife.marginal_pleasure(
			mouths, cellar, resource, step, Building.amusement_for(town, context.colony),
			Building.luxury_serves_for(town)
		)
		if pleasure <= 0.0:
			continue
		var score := pleasure * Spending.pleasure_worth(mouths) / (landed * step)
		# Ties break on the name, so the choice is the colony's rather than the
		# catalogue's iteration order.
		var tie := absf(score - best_score) <= 0.000001 \
			and not best.is_empty() and id < String(best["resource"])
		if score > best_score + 0.000001 or tie:
			best_score = score
			best = {
				"resource": id,
				"tier": String(Spending.WANT),
				"step": step,
				"key": id + "|" + String(Spending.WANT),
				"score": score,
			}
	return best


## Whether the town will lay this out, given what it is holding back (§4).
##
## 🔒 **Needs override the purse reserve.** A town that cannot eat this month
## spends its last coin; holding gold against next month while starving is not
## prudence. Everything else stops at the reserve.
##
## Asked through `can_afford` rather than by reading the balance, because a
## town's gold has no getter: SPEC §11.3 makes it invisible to the player and
## the lint enforces that nothing outside the sim can so much as name it.
func _affordable(
	town: Town,
	landed: float,
	step: float,
	tier: StringName,
	reserve: float,
) -> bool:
	if tier == Spending.NEED:
		return town.can_afford(Trade.EPSILON)
	# 🔒 **The reserve gates the militia, and never the townspeople** (§3). A town
	# that cannot eat spends its last coin; a town that cannot feed its soldiers
	# without eating into next month's purse **sends nothing**, and the company
	# goes unsupported. That is what makes militia a commitment the town cannot
	# drop rather than a claim that outranks the future.
	return town.can_afford(landed * step + reserve)


## Whether the town would rather have the thing than the gold (§3).
##
## ## Asked of the tiers, and deliberately not of the comforts
##
## **A duty high enough closes a trade** — that is §2's point, and it is what
## makes a rate an instrument the Steward can be genuinely wrong about rather
## than a number that only ever shaves the margin. A town ninety per cent of the
## way to the grain it wants does not pay a premium for the last tenth.
##
## Comforts are exempt because they already have a better valuation of their own:
## §4 scores every candidate at what the next measure is actually worth to the
## people drinking it, divided by what it costs, and that is a sharper question
## than this one. Gating them on `base` as well would decide which comforts a
## town may want from an authored table, which is the whole thing the marginal
## scoring exists to avoid — and in practice it silently reduced every colony to
## tea.
func _worth_it(
	resource: StringName,
	desired: DesiredStock,
	town: Town,
	before: ColonySnapshot,
	context: ColonyContext,
) -> bool:
	return Valuation.worth_buying(resource, desired, before.held(town.id, resource), context)


## Buy up to `wanted`, natives first.
##
## Returns `{got, covered}`: what was actually obtained, and how much of the want
## the gold laid out would have bought **before the duty**. The two agree for
## natives, who charge none, and part by exactly the duty for the Crown.
func _shop(
	town: Town,
	resource: StringName,
	wanted: float,
	context: ColonyContext,
	into: Dictionary,
	tier: StringName = Trade.TIER_WANT,
) -> Dictionary:
	var got := _buy_from_natives(town, resource, wanted, context)
	var covered := got
	if wanted - got > 0.0:
		var deal := Trade.buy(town, resource, wanted - got, context, tier)
		got += float(deal["received"])
		covered += float(deal["received"]) * (1.0 + float(deal["rate"]))
	if got > 0.0:
		into[String(resource)] = float(into.get(String(resource), 0.0)) + got
	return {"got": got, "covered": covered}


## 🔒 **Natives ahead of the Crown** (SPEC §11.3), and **no duty** (§10.1).
##
## The seam this file cut in M2 is now filled, and it was worth cutting: nothing
## else in Exchange had to change, because "buy" never meant "buy from the Crown"
## anywhere but here.
##
## The exemption is not a rate of zero anywhere — it is that this path **never
## goes near `Trade`**, so there is nothing for a duty to be charged on. A town
## with a standing agreement is buying from its neighbours, and the Crown does
## not have a customs house in a village.
func _buy_from_natives(
	town: Town,
	resource: StringName,
	wanted: float,
	context: ColonyContext,
) -> float:
	if context.native_trade == null or context.natives == null or wanted <= 0.0:
		return 0.0
	var deal := context.native_trade.of_town(town.id)
	if deal == null or deal.they_give != resource:
		return 0.0

	var village := _their_village(deal, context)
	if village == null:
		return 0.0

	# What Reckon has put by of the thing the town is giving away. A town does
	# not trade away the grain it is going to eat, however good the bargain.
	var reserve := context.reckoning_for(town).reserve_of(deal.we_give)
	var got := deal.run(town, village, reserve, context)
	# The trade moves what both sides can spare rather than what the shopping
	# list asked for, so a month may bring more than was wanted — which is what
	# a standing agreement is, as against a purchase.
	return minf(got, wanted)


## The village on the other end of an agreement.
func _their_village(deal: TradeAgreement, context: ColonyContext) -> Village:
	for village in context.natives.villages_of(deal.tribe):
		return village
	return null
