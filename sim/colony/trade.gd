class_name Trade
extends RefCounted

## Buying from and selling to the Crown, and the tax on both (SPEC §10.2, #47).
##
## Exchange and Sell are separate phases with two hours of colony month between
## them, but they are the same transaction in two directions and they must be
## taxed by the same rule. That rule lives here.
##
## ## 🔒 The asymmetry
##
## **A tax on a necessity takes resources. A tax on a luxury takes nothing.**
##
## A town that needs food buys food. Raise the duty and it does not eat less — it
## pays the same money and carries home less grain. The tax comes out of the
## colony's stores.
##
## A town that wants rum buys rum *if it feels like it*. Raise the duty and it
## shrugs and buys less, and spends less doing it. The tax comes out of nobody.
##
## That is why taxing luxuries is politically cheap and materially useless, and
## it is the mechanical spine of the trade-protest design in M3. **They are two
## code paths on purpose.** Collapsing them into one formula with a coefficient
## would make the Steward's advice about luxury duties technically true and
## practically meaningless, and the player would never find out why.
##
## ## Where the seams are
##
## - **Natives first** (SPEC §11.3). M5 gives the colony somebody else to buy
##   from, and they come *ahead* of the Crown. `ExchangePhase` asks them first and
##   gets nothing; this class only ever speaks for the Crown.
## - **Refusal.** A rebelling town, or one protesting a duty, will not trade with
##   the Crown at all (M3). `may_trade_with_crown` is that gate, and it is asked
##   before every transaction rather than at the top of the phase, so a town can
##   come to refuse mid-month when the reasons grow.

const EVENT_BOUGHT: StringName = &"crown_purchase"
const EVENT_SOLD: StringName = &"crown_sale"
## The Reckon tier a purchase served (SPEC §11.3), carried on the event so that
## rebel sentiment can weigh a duty by how cornered the town was (#71).
const TIER_NEED: StringName = &"need"
const TIER_OBJECTIVE: StringName = &"objective"
const TIER_WANT: StringName = &"want"

const EVENT_REFUSED: StringName = &"crown_trade_refused"

## How sharply luxury demand falls off as the duty rises. At `2.0` a ten per cent
## duty costs a fifth of the trade. Tuning.
const LUXURY_ELASTICITY: float = 2.0

## Trades smaller than this are not worth an entry in the Ledger.
const EPSILON: float = 0.0001


## Whether this town will deal with the Crown at all.
##
## **The M3 exception hook.** Today only an openly rebelling town refuses; trade
## protests hang off the same gate.
static func may_trade_with_crown(town: Town, _context: ColonyContext) -> bool:
	return not town.rebelling


## Buy up to `desired` of a resource from the Crown.
##
## Returns `{received, spent, tax, rate}`. Buying less than was wanted is the
## normal case, not an error: a town buys what it can afford.
static func buy(
	town: Town,
	resource: StringName,
	desired: float,
	context: ColonyContext,
	tier: StringName = TIER_WANT,
) -> Dictionary:
	var nothing: Dictionary = {"received": 0.0, "spent": 0.0, "tax": 0.0, "rate": 0.0}
	if desired <= 0.0:
		return nothing

	var rate := context.tax_rate(resource)
	var price := ResourceCatalogue.price_of(resource)
	if price <= 0.0:
		return nothing

	if not may_trade_with_crown(town, context):
		context.log.emit(EVENT_REFUSED, town.id, context.state.month, {
			"town": String(town.id),
			"resource": String(resource),
			"direction": "buy",
			"wanted": desired,
		}, WorldPhase.COLONY_MONTH)
		return nothing

	var taxed_unit := price * (1.0 + rate)
	var budget := 0.0

	if ResourceCatalogue.is_luxury(resource):
		# **Elastic.** They want less of it at a higher price, and so spend less.
		# The duty lands on the trade, not on the town.
		var wanted := desired / (1.0 + rate * LUXURY_ELASTICITY)
		budget = wanted * taxed_unit
	else:
		# **Inelastic.** They set aside what the resource is worth and hand it
		# over whatever the duty is. The duty lands on what they carry home.
		budget = desired * price

	var spent := town.spend_gold(budget)
	if spent <= EPSILON:
		return nothing

	var received := spent / taxed_unit
	var tax := spent - received * price

	town.store(resource, received)
	town.traded_value += spent
	_collect(context, tax)

	context.log.emit(EVENT_BOUGHT, town.id, context.state.month, {
		"town": String(town.id),
		"resource": String(resource),
		# **Which tier the purchase served** (#71). Towns resent a duty as they
		# pay it and in proportion to how little choice they had, so the tier is
		# part of what happened and belongs on the event rather than being
		# reconstructed later from what was bought.
		"tier": String(tier),
		"luxury": ResourceCatalogue.is_luxury(resource),
		"wanted": desired,
		"quantity": received,
		"unit_price": price,
		"rate": rate,
		"gross": received * price,
		"tax": tax,
		"spent": spent,
	}, WorldPhase.COLONY_MONTH)

	return {"received": received, "spent": spent, "tax": tax, "rate": rate}


## Sell up to `quantity` of a resource to the Crown.
##
## Returns `{sold, earned, tax, rate}`. The duty comes off what the town is paid,
## so the Crown takes its share of a sale exactly as it takes its share of a
## purchase — and the town feels both.
static func sell(town: Town, resource: StringName, quantity: float, context: ColonyContext) -> Dictionary:
	var nothing: Dictionary = {"sold": 0.0, "earned": 0.0, "tax": 0.0, "rate": 0.0}
	if quantity <= EPSILON:
		return nothing

	var price := ResourceCatalogue.price_of(resource)
	if price <= 0.0:
		return nothing

	if not may_trade_with_crown(town, context):
		context.log.emit(EVENT_REFUSED, town.id, context.state.month, {
			"town": String(town.id),
			"resource": String(resource),
			"direction": "sell",
			"wanted": quantity,
		}, WorldPhase.COLONY_MONTH)
		return nothing

	var sold := town.take(resource, quantity)
	if sold <= EPSILON:
		return nothing

	var rate := context.tax_rate(resource)
	var gross := sold * price
	var tax := gross * rate
	var earned := gross - tax

	town.receive_gold(earned)
	town.traded_value += gross
	_collect(context, tax)

	context.log.emit(EVENT_SOLD, town.id, context.state.month, {
		"town": String(town.id),
		"resource": String(resource),
		"luxury": ResourceCatalogue.is_luxury(resource),
		"quantity": sold,
		"unit_price": price,
		"rate": rate,
		"gross": gross,
		"tax": tax,
		"earned": earned,
	}, WorldPhase.COLONY_MONTH)

	return {"sold": sold, "earned": earned, "tax": tax, "rate": rate}


## What the Crown takes. Accumulated across Exchange and Sell and written to the
## world by whichever of them runs last.
static func _collect(context: ColonyContext, tax: float) -> void:
	context.crown_tax += maxf(0.0, tax)
