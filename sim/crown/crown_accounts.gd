class_name CrownAccounts
extends RefCounted

## What the Crown took and what the Crown paid, month by month, read off the
## event log (SPEC §10.2, §10.4).
##
## ## One reduction, two readers
##
## Crown standing needs this to judge the PC, and the Ledger needs it to show
## him the same figures. **They must not each work it out.** Two readers of one
## log is how the letters come to say one thing and the sheet another, and the
## player's only instrument for reading the Crown's mind is the gap between
## those two — so a discrepancy is not a cosmetic bug, it is the instrument
## lying.
##
## ## What counts
##
## Per `docs/mechanics/town-economy.md` §5, the Crown's merchants always profit
## and the colonists always pay:
##
## - **In** is duty, on every purchase and every sale (§10.2, both directions).
## - **Out** is gold the Crown itself paid to honour the PC's word (§9.5), and
##   the monthly charge on every policy he is funding (#80).
##
## So **revenue is never negative**, and a month only goes badly through the
## PC's spending, rates too low to collect, or a colony that has stopped
## trading. Never because a trade went badly.
##
## A promise the **colony** fulfils from its own stockpiles is not the Crown's
## money and is not counted. A governor sending resources to a neighbour does
## not move the Crown's books.

## Month -> `{received, paid}`.
var months: Dictionary = {}


static func of(log: EventLog) -> CrownAccounts:
	var accounts := CrownAccounts.new()
	if log == null:
		return accounts
	for event in log.all():
		match event.type:
			Trade.EVENT_BOUGHT, Trade.EVENT_SOLD:
				accounts._add(event.month, float(event.payload.get("tax", 0.0)), 0.0)
			PolicyBook.EVENT_BILLED:
				# **A standing charge is the Crown's money exactly as an honoured
				# promise is** (#80). It has to land on the same books, or the
				# one commitment the player cannot see is the one that recurs.
				accounts._add(event.month, 0.0, float(event.payload.get("crown_paid", 0.0)))
			PromiseBook.EVENT_KEPT:
				if not _is_the_crowns_money(event.payload):
					continue
				accounts._add(
					event.month, 0.0,
					float(event.payload.get("terms", {}).get("amount", 0.0)),
				)
	return accounts


## Only gold, and only gold the Crown itself paid.
static func _is_the_crowns_money(payload: Dictionary) -> bool:
	return (
		String(payload.get("payer", "")) == Promise.PAYER_CROWN
		and String(payload.get("kind", "")) == "gold"
	)


func _add(month: int, received: float, paid: float) -> void:
	if not months.has(month):
		months[month] = {"received": 0.0, "paid": 0.0}
	months[month]["received"] = float(months[month]["received"]) + maxf(0.0, received)
	months[month]["paid"] = float(months[month]["paid"]) + maxf(0.0, paid)


# --- Reading ----------------------------------------------------------------

func received_in(month: int) -> float:
	return float(months.get(month, {}).get("received", 0.0))


func paid_in(month: int) -> float:
	return float(months.get(month, {}).get("paid", 0.0))


## **This month's revenue minus this month's spending**, which is the figure the
## Crown's accountants actually react to.
func net_in(month: int) -> float:
	return received_in(month) - paid_in(month)


## Every month with anything on it, in order.
func recorded() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array(months.keys())
	out.sort()
	return out


## **Cumulative revenue minus cumulative spending**, across the whole run.
##
## `docs/mechanics/crown-standing.md` calls this `net_position`. It is the size
## of the hole, and on its own it decides nothing — what matters is whether it is
## closing.
func net_position() -> float:
	var total := 0.0
	for month in months:
		total += net_in(month)
	return total


## **What share of the money that moved stayed with the Crown**, `-1` to `+1`.
##
## The same `net_position` above, put on a scale that does not grow with the
## colony (#282, `perception.md` §4a). A hamlet returning a tenth more than it
## costs and a province returning a tenth more than it costs are both doing
## equally well by the Crown, and a man who judged them on the absolute would say
## *ruinous* about the hamlet for the whole run.
##
## Nought when nothing has moved: a colony that has neither cost nor paid has not
## yet failed at anything.
func margin() -> float:
	var moved := 0.0
	for month in months:
		moved += received_in(month) + paid_in(month)
	if moved <= 0.0:
		return 0.0
	return clampf(net_position() / moved, -1.0, 1.0)


func is_empty() -> bool:
	return months.is_empty()
