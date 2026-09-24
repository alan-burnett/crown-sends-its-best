class_name ShipmentExecutor
extends IntentExecutor

## Goods leaving a town for the Crown, over months
## (#69, `docs/mechanics/crown-demands.md` §5).
##
## ## Why it is an Intent and not a transfer
##
## **A demand for a great many horses is not refused for being large.** The
## Marshal takes them across a year as the town shifts production toward them, so
## a shipment reshapes the town's economy while it runs, the PC can watch it
## progress, and the governor can fall behind.
##
## That is the world month's rule about consequential actions being multi-month
## so that a letter can still reach them — and here it is load-bearing rather
## than decorative, because the PC's only power over goods he has already
## promised is another letter.
##
## ## The gold does not behave like trade
##
## The PC sets what the Crown will pay, from nothing at all up to double for a
## shipment he calls vital. Two things follow, and both are deliberate:
##
## - **It generates no tax.** A requisition is not a trade; there are no
##   merchants in the middle to tax. So it is pure cost on the Crown's side,
##   where ordinary trade always profits it (`town-economy.md` §5).
## - **The town receives it**, into the balance the player never sees. Gold
##   raises `means`, which raises quality of life, which lowers rebel sentiment.
##
## So an overpaid shipment lets the PC **spend Crown Standing to buy a town's
## contentment**, laundered through goods the Marshal wanted anyway. That is the
## Squeeze in one letter, and it is why the payment is bounded at double rather
## than left open.
##
## Paid on the first month's work, not on acceptance: the Crown pays for a
## shipment that has started, not for a promise to start one.

const EVENT_SENT: StringName = &"shipment_sent"
const EVENT_PAID: StringName = &"shipment_paid"

## The colony the Intent names a town in. Supplied by the turn loop, which is the
## only place that can see both the Order kinds and the colony.
var colony: Colony = null


func handles(intent: Intent) -> bool:
	return intent.kind == Shipment.KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	if colony == null:
		return Intent.STALLED
	var town := Shipment.town_of(colony, intent)
	if town == null:
		# The town it was to come from is gone. Not a refusal and not a silence:
		# something the next letter has to be able to explain.
		return Intent.OVERTAKEN_BY_EVENTS

	_pay(intent, town, state, log)

	var resource := StringName(intent.data.get("resource", ""))
	var total := float(intent.data.get("amount", 0.0))
	var shipped := float(intent.data.get("shipped", 0.0))
	var quota := Shipment.monthly_quota(intent)
	var moved := town.take(resource, minf(quota, _available(town, intent, resource)))

	if moved > 0.0:
		shipped += moved
		intent.data["shipped"] = shipped
		intent.data["last_moved_month"] = state.month
		log.emit(EVENT_SENT, town.id, state.month, {
			"town": String(town.id),
			"resource": String(resource),
			"quantity": moved,
			"shipped": shipped,
			"of": total,
			"tier": String(intent.data.get("tier", Shipment.TIER_SPARE)),
		}, WorldPhase.MOVEMENT)

	if shipped >= total - 0.001:
		return Intent.COMPLETED

	# **Nothing has moved for a long time.** A town at the spare tier with no
	# surplus ships nothing, month after month, and the Marshal is owed an answer
	# rather than silence.
	var since := state.month - int(intent.data.get("last_moved_month", intent.committed_month))
	if since >= Shipment.PATIENCE:
		return Intent.STALLED
	return Intent.IN_PROGRESS


## What the town will let go of this month.
##
## At the **needs** tier the governor has made the shipment his town's business,
## so the stockpile is the only limit — Reckon has already put it among the needs
## and the town is buying to cover it.
##
## At the **spare** tier only what survives a month's eating and the reserve
## leaves. The reserve is read from `needs.json` rather than from this month's
## Reckon because a shipment moves in phase 2 and Reckon does not run until phase
## 4; using last month's figure would be a quieter kind of wrong.
func _available(town: Town, intent: Intent, resource: StringName) -> float:
	if StringName(intent.data.get("tier", Shipment.TIER_SPARE)) == Shipment.TIER_NEED:
		return town.held(resource)
	var mouths := town.mouths()
	var keep := mouths * ColonyNeeds.per_head(resource) \
		* (1.0 + ColonyNeeds.reserve_months(resource))
	return maxf(0.0, town.held(resource) - keep)


## The Crown pays the town, once, when the goods start moving.
##
## **No tax, either way.** `CrownAccounts` reads duty off trade events and this
## is not one, so the Crown's books show the cost and no receipt against it —
## which is the arithmetic that makes overpayment a real price rather than a
## gesture.
func _pay(intent: Intent, town: Town, state: WorldState, log: EventLog) -> void:
	if bool(intent.data.get("paid", false)):
		return
	intent.data["paid"] = true
	var payment := float(intent.data.get("payment", 0.0))
	if payment <= 0.0:
		return
	town.receive_gold(payment)
	log.emit(EVENT_PAID, town.id, state.month, {
		"town": String(town.id),
		"payment": payment,
		"resource": String(intent.data.get("resource", "")),
		"amount": float(intent.data.get("amount", 0.0)),
	}, WorldPhase.MOVEMENT)
