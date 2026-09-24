class_name SellPhase
extends ColonyPhase

## **Sell.** Surplus above the reserve goes to the Crown, and is taxed
## (SPEC §11.3, #47).
##
## **The reserve is the whole of the discipline here.** Reckon worked out what
## the town must keep — its needs, plus months of them against the winter, plus
## whatever its granaries let it hold, plus what its intent keeps in store. What
## is over *that* is spare, and only spare is sold.
##
## A town that sold down to its needs would look prosperous for a month and
## starve in the second. Sell does not get to decide any of this; it reads
## Reckon and sells what Reckon called spare, measured against the stores as this
## phase began — Consume and Build have both eaten into them since.
##
## **Luxuries are sold like anything else.** A town does not hoard rum against
## hard times.
##
## ## And only what the Crown pays more for than the town thinks it is worth
##
## Spare is not the same question as worth selling, even though the two usually
## agree (§3: *"what to keep is the gap restated"*). Where they come apart is
## where a town is holding something above its reserve that it still values above
## what the Crown nets it — a duty high enough to make the sale a loss, or a want
## the reserve does not know about. Selling into that is how a town ends a year
## poorer for having traded, and it is the one thing Sell can get wrong that
## nothing downstream can correct.

const EVENT_SOLD: StringName = &"town_sold"


func run(town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	var reckoning := context.reckoning_for(town)
	var desired := DesiredStock.for_town(town, before)
	var sold: Dictionary = {}
	var earned := 0.0

	# In id order. Which resource goes first does not change what the town keeps
	# — every one of them is sold down to its own reserve — so the order only has
	# to be stable.
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var keep := reckoning.need_of(id) + reckoning.reserve_of(id)
		var surplus := before.held(town.id, id) - keep
		if surplus <= Trade.EPSILON:
			continue
		if not Valuation.worth_selling(id, desired, before.held(town.id, id), context):
			continue
		# Never sell more than is actually there now. Build may have taken it.
		var deal := Trade.sell(town, id, minf(surplus, town.held(id)), context)
		if float(deal["sold"]) > 0.0:
			sold[resource] = float(deal["sold"])
			earned += float(deal["earned"])

	if sold.is_empty():
		return

	context.log.emit(EVENT_SOLD, town.id, context.state.month, {
		"town": String(town.id),
		"sold": sold,
		"earned": earned,
	}, WorldPhase.COLONY_MONTH)
