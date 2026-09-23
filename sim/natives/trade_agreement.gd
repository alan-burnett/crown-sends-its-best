class_name TradeAgreement
extends RefCounted

## A standing exchange between a village and a town (#206, SPEC §10.1, §11.3,
## §12.5; `docs/mechanics/natives.md` §5).
##
## ## 🔒 The tribe proposes. The town never does
##
## A town cannot open one, cannot ask for one, and cannot name the terms. It can
## only answer. `TradeAgreement` has no constructor a town could reach for and
## `NativeTrade.proposed_by` is the only thing that makes one.
##
## ## 🔒 No gold changes hands
##
## Gold value sets the **ratio and nothing else** (§10.2): if food is worth two
## and guns twenty, ten food buys one gun. Each side gives what it can spare and
## receives at fair value, and no coin moves in either direction.
##
## **And no duty is charged.** SPEC §10.1 exempts it, and the way that is made
## true is that this never goes near `Trade` — there is no code path from here to
## a tax rate, so a duty cannot be charged by accident.
##
## ## The escape, and its price
##
## A tribe that trusts the colony is its **one escape from the Crown's monopoly**
## (`town-economy.md` §1). Everything else a town buys is taxed twice across a
## round trip; this is not taxed at all.
##
## And the price of that escape is what they ask for: **guns, tools and horses**,
## the things they cannot make. So the trade that most helps a town is the trade
## that arms the tribe beside it, and a governor may strike that bargain thinking
## it a good one — which it is, for his town, this year.

const EVENT_OPENED: StringName = &"native_trade_opened"
const EVENT_TRADED: StringName = &"native_trade_ran"
const EVENT_CLOSED: StringName = &"native_trade_closed"

## Why an agreement ended.
const STANDING_FELL: StringName = &"standing_fell"
const NOTHING_SPARE: StringName = &"nothing_spare"
const NO_TOWN: StringName = &"town_gone"

## Where a people will no longer deal with the colony at all.
##
## **Below where they will open one**, so an agreement struck in a good year
## survives a bad month rather than flickering. Tuning.
const CLOSES_BELOW: float = 34.0

## Months of nothing to trade before they stop bothering. Tuning.
const PATIENCE: int = 4

## 🔒 **How much of the winter they keep back** (#288, *Restless country*).
##
## **One in every run without the quirk**, and below one their trade agreements
## are richer: a people who get more off their land can put more of it on the
## table and still keep the winter.
##
## 🔒 **Volume, never the ratio.** `natives.md` §5 fixes that each side
## *receives at fair value* and that gold sets only the rate — a knob that bent
## the terms would make the tribes charitable rather than strong, which is the one
## thing the design says they are not. A richer agreement is one where more of it
## moves.
static var _keeps_back: float = 1.0


static func keeps_back() -> float:
	return _keeps_back


static func set_keeps_back(scale: float) -> void:
	_keeps_back = maxf(0.0, scale)


static func reset() -> void:
	_keeps_back = 1.0

var tribe: StringName = &""
var town: StringName = &""

## What the village gives. Something it is actually producing.
var they_give: StringName = &""

## What the town gives. Something they cannot make for themselves.
var we_give: StringName = &""

var opened_month: int = 0

## Months running in which neither side had anything spare.
var idle_months: int = 0


func axis() -> String:
	return "%s for %s" % [String(they_give), String(we_give)]


## Run a month of it (Seam A).
##
## **Surplus for surplus, at the gold ratio.** Each side gives what it holds
## above its reserve; the smaller of the two offers decides how much actually
## moves, because a bargain is limited by whichever side has less to bring.
##
## Returns how much the town received.
func run(
	the_town: Town,
	village: Village,
	reserve: float,
	context: ColonyContext,
) -> float:
	if the_town == null or village == null:
		return 0.0

	var theirs := maxf(0.0, float(village.stores.get(String(they_give), 0.0))
		- kept_back_by(village, they_give))
	var ours := maxf(0.0, the_town.held(we_give) - reserve)
	if theirs <= 0.0 or ours <= 0.0:
		idle_months += 1
		return 0.0

	# The ratio, and the only thing gold is for here.
	var their_worth := maxf(0.0001, Valuation.crown(they_give))
	var our_worth := maxf(0.0001, Valuation.crown(we_give))

	# What each side's surplus is worth, and the deal is the smaller of them.
	var deal := minf(theirs * their_worth, ours * our_worth)
	if deal <= 0.0001:
		idle_months += 1
		return 0.0

	var received := deal / their_worth
	var given := deal / our_worth

	village.stores[String(they_give)] = float(
		village.stores.get(String(they_give), 0.0)) - received
	village.stores[String(we_give)] = float(
		village.stores.get(String(we_give), 0.0)) + given

	the_town.take(we_give, given)
	the_town.store(they_give, received)

	idle_months = 0
	context.log.emit(EVENT_TRADED, the_town.id, context.state.month, {
		"tribe": String(tribe),
		"town": String(the_town.id),
		"village": String(village.id),
		"they_gave": String(they_give),
		"received": received,
		"we_gave": String(we_give),
		"given": given,
		# 🔒 **Said out loud in the log**, because it is the whole point of the
		# mechanic and the thing a ledger reading the log has to get right.
		"duty": 0.0,
		"gold": 0.0,
	}, WorldPhase.COLONY_MONTH)
	return received


## What a village keeps back before it will trade anything away.
##
## **Months of eating for food and nothing for the rest.** They are not running a
## warehouse; they are keeping the winter.
##
## 🔒 **And *nothing for the rest* meant nothing.** This took no resource
## and charged every axis the food reserve, so a village trading hides held back a
## quantity of hides equal to two months of everyone's grain — a figure with
## nothing to do with hides, which grows with the village and silently shut the
## richest agreements the design has. What they are keeping is the winter, and you
## cannot eat a musket.
static func kept_back_by(village: Village, resource: StringName = &"food") -> float:
	if resource != &"food":
		return 0.0
	return float(village.people) * ColonyNeeds.per_head(&"food") * 2.0 * _keeps_back


## Whether this is still a bargain either side would keep.
func still_stands(the_tribe: Tribe) -> bool:
	if the_tribe == null:
		return false
	if the_tribe.is_irreconcilable_with(Tribe.COLONY):
		return false
	return the_tribe.trust() >= CLOSES_BELOW and idle_months < PATIENCE


## Why it ended, for the log and the letter.
func why_it_ended(the_tribe: Tribe) -> StringName:
	if the_tribe == null:
		return NO_TOWN
	if the_tribe.trust() < CLOSES_BELOW or the_tribe.is_irreconcilable_with(Tribe.COLONY):
		return STANDING_FELL
	return NOTHING_SPARE


func to_dict() -> Dictionary:
	return {
		"tribe": String(tribe),
		"town": String(town),
		"they_give": String(they_give),
		"we_give": String(we_give),
		"opened_month": opened_month,
		"idle_months": idle_months,
	}


static func from_dict(data: Dictionary) -> TradeAgreement:
	var deal := TradeAgreement.new()
	deal.tribe = StringName(data.get("tribe", ""))
	deal.town = StringName(data.get("town", ""))
	deal.they_give = StringName(data.get("they_give", ""))
	deal.we_give = StringName(data.get("we_give", ""))
	deal.opened_month = int(data.get("opened_month", 0))
	deal.idle_months = int(data.get("idle_months", 0))
	return deal
