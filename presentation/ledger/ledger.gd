class_name Ledger
extends RefCounted

## Every transaction of gold between the colony and the Crown (SPEC §10.4).
##
## ## Read from the log, not kept alongside it
##
## **The ledger is a consumer of the event log**, exactly as the architecture
## says the map playback and the letters are (CLAUDE.md, Seam A). Keeping a
## second running tally would be a second thing to keep in step, and the first
## month they disagreed the player would be reading a lie about their own money.
##
## **The arithmetic is `CrownAccounts`**, in `sim/`, which is the same reduction
## Crown standing judges the PC on. This file turns it into lines a player can
## read; it does not work out the totals for itself. The gap between what the
## sheet shows and what the letters say is the player's only instrument for
## reading the Crown's mind, so the two must be reading the same books.
##
## ## 🔒 Crown-side only
##
## A town's gold is hidden from the player (SPEC §11.3) and **nothing here may
## read it**. `tools/lint.gd` fails if anything under `presentation/` so much as
## names it. What this shows is the other ledger entirely: what the Crown took
## in duty and what the Crown paid out on the PC's word.
##
## Which gives the sheet a shape worth knowing about. Per
## `docs/mechanics/town-economy.md` §5, the Crown's merchants always profit and
## the colonists always pay, so **money in is always trade and money out is
## always the PC's promises**. A month that goes badly goes badly because of
## something the player did, and the trend is legible without explanation.
##
## ## Why it matters more than it looks
##
## Crown standing is invisible and always will be. This is the compensating
## instrument: from it a player can derive the monthly net and watch the
## cumulative position accumulate. **The Ledger supplies the inputs and the
## letters supply the verdict**, and reading the gap between them is a real skill
## the game should reward — which makes trend legibility the point rather than
## decoration.

const IN: StringName = &"in"
const OUT: StringName = &"out"

## One line on the sheet.
class Entry extends RefCounted:
	var month: int = 0
	var direction: StringName = Ledger.IN
	var amount: float = 0.0

	## What it was, in the Crown's terms. Never a town's business.
	var description: String = ""

	func _init(p_month: int, p_direction: StringName, p_amount: float, p_description: String) -> void:
		month = p_month
		direction = p_direction
		amount = maxf(0.0, p_amount)
		description = p_description


## One page: a month, and what it came to.
class Page extends RefCounted:
	var month: int = 0
	var entries: Array = []

	func received() -> float:
		var total := 0.0
		for entry in entries:
			if entry.direction == Ledger.IN:
				total += entry.amount
		return total

	func paid() -> float:
		var total := 0.0
		for entry in entries:
			if entry.direction == Ledger.OUT:
				total += entry.amount
		return total

	## **The number the player is really after.** Positive is a month the colony
	## paid for itself.
	func net() -> float:
		return received() - paid()


## Month -> Page, and the months in order.


var _pages: Dictionary = {}
var _months: PackedInt32Array = PackedInt32Array()

## The same books Crown standing reads.
var _accounts: CrownAccounts = null


## Read the whole run off the log.
static func of(log: EventLog) -> Ledger:
	var ledger := Ledger.new()
	ledger._accounts = CrownAccounts.of(log)
	if log == null:
		return ledger

	# In seq order, so a month's lines read in the order they happened rather
	# than in whatever order the types are asked for.
	for event in log.all():
		match event.type:
			Trade.EVENT_BOUGHT:
				ledger._add(event.month, IN, float(event.payload.get("tax", 0.0)),
					"duty on %s bought" % _named(event.payload))
			Trade.EVENT_SOLD:
				ledger._add(event.month, IN, float(event.payload.get("tax", 0.0)),
					"duty on %s sold" % _named(event.payload))
			PromiseBook.EVENT_KEPT:
				# **Only what the Crown paid.** A promise of resources comes from
				# the colony's own stockpiles, so the Crown is not out a penny on
				# it and it has no business on this sheet. `CrownAccounts` draws
				# the same line, and this asks it rather than repeating the rule.
				if not CrownAccounts._is_the_crowns_money(event.payload):
					continue
				ledger._add(event.month, OUT, float(event.payload.get("terms", {}).get("amount", 0.0)),
					"honoured to %s" % String(event.payload.get("to", "a contact")))
			GoldGiftExecutor.EVENT_GIVEN:
				# **A patron's gold, shown where the Crown's money is** (#443).
				ledger._add(event.month, IN, float(event.payload.get("amount", 0.0)),
					"a gift from %s" % String(event.payload.get("from", "a patron")))
	return ledger


## How much of what, in figures a line can carry.
##
## **Small quantities keep a decimal.** Rounding to whole units printed "duty on
## 0 of sugar bought", which is a line about nothing and reads as a bug even
## though the duty was real.
static func _named(payload: Dictionary) -> String:
	var quantity := float(payload.get("quantity", 0.0))
	var figure := "%.1f" % quantity if quantity < 10.0 else "%d" % int(roundf(quantity))
	return "%s of %s" % [figure, String(payload.get("resource", "goods"))]


func _add(month: int, direction: StringName, amount: float, description: String) -> void:
	# A transaction of nothing is not a transaction, and a sheet full of zeroes
	# hides the lines that matter.
	if amount <= 0.005:
		return
	if not _pages.has(month):
		var page := Page.new()
		page.month = month
		_pages[month] = page
		_months.append(month)
		_months.sort()
	_pages[month].entries.append(Entry.new(month, direction, amount, description))


# --- Reading it -------------------------------------------------------------

## The months that have anything on them, in order.
func months() -> PackedInt32Array:
	return _months.duplicate()


func has_month(month: int) -> bool:
	return _pages.has(month)


## One month's page. A month with nothing on it is an empty page, not an error:
## a quiet month is a fact about the run.
func page(month: int) -> Page:
	if _pages.has(month):
		return _pages[month]
	var empty := Page.new()
	empty.month = month
	return empty


func is_empty() -> bool:
	return _months.is_empty()


## The run so far, month by month, for the graph.
##
## **The first page is a graph** (SPEC §10.4) so the player can see a trend, and
## the trend is the whole instrument.
func trend() -> Array:
	var out: Array = []
	for month in _months:
		var here: Page = _pages[month]
		out.append({
			"month": month,
			"in": here.received(),
			"out": here.paid(),
			"net": here.net(),
		})
	return out


## What the Crown is up or down across the whole run.
##
## `docs/mechanics/crown-standing.md` calls this `net_position`, and it is the
## one figure a diligent player can work out for themselves. **What they cannot
## work out is the Crown's judgement of it** — that is standing, and it is never
## shown.
##
## Read from the same accounts standing is judged on, so the sheet and the
## verdict cannot come from different books.
func net_position() -> float:
	return _accounts.net_position() if _accounts != null else 0.0


## The largest single month either way, so a graph can scale to fit.
func busiest_month() -> float:
	var most := 0.0
	for month in _months:
		var here: Page = _pages[month]
		most = maxf(most, maxf(here.received(), here.paid()))
	return most
