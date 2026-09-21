class_name NativeTradeDriver
extends RefCounted

## Where agreements are opened and closed, in **phase 7** (#206).
##
## Beside the standing movers, and after them in the same phase, because what a
## people will offer depends on what the month has just done to their regard for
## the colony. An agreement opened here is live for the **next** Colony Month's
## Exchange, which is the game's ordinary rhythm: the bargain is struck, and the
## PC reads about it a month later in a governor's report.
##
## 🔒 **The tribe proposes and the governor answers, both here.** A village and a
## town are neighbours rather than correspondents; there is no ocean between them
## and nothing to wait for. The month of delay in this loop is the PC's, not
## theirs, and that is the point — he is the one who finds out late.

var colony: Colony = null
var natives: Tribes = null
var book: TradeBook = null
var map: WorldMap = null


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or natives == null or colony == null or book == null:
		return

	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony

	# Ending first. A people who have gone cold since last month do not sit down
	# to a fresh bargain in the same breath.
	for deal in book.in_order():
		var tribe := natives.find((deal as TradeAgreement).tribe)
		var town := colony.by_id((deal as TradeAgreement).town)
		if town == null:
			book.close(deal, TradeAgreement.NO_TOWN, context)
		elif not (deal as TradeAgreement).still_stands(tribe):
			book.close(deal, (deal as TradeAgreement).why_it_ended(tribe), context)

	for town in colony.in_order():
		if book.has_one(town.id):
			continue
		_offer_to(town, context)


## The nearest people put something to this town, and its governor answers.
func _offer_to(town: Town, context: ColonyContext) -> void:
	var village := _village_beside(town)
	if village == null:
		return
	var tribe := natives.find(village.tribe)
	if tribe == null:
		return

	var desired := DesiredStock.for_town(town, ColonySnapshot.of(colony))
	var deal := NativeTrade.propose(tribe, village, town, desired, context)
	if deal == null:
		return

	if not NativeTrade.would_accept(deal, town, desired):
		context.log.emit(NativeTrade.EVENT_REFUSED, town.id, context.state.month, {
			"tribe": String(tribe.id),
			"town": String(town.id),
			"they_give": String(deal.they_give),
			"we_give": String(deal.we_give),
			"intent": String(town.intent),
		}, WorldPhase.RECKONING)
		return

	book.open(deal, context)


## The village nearest this town, among the ones close enough to deal with it.
##
## The same reach everything else about the neighbours uses, so a town that is
## near enough to offend a people is near enough to trade with them.
func _village_beside(town: Town) -> Village:
	var nearest: Village = null
	var deepest := 0.0
	for village in natives.villages_in_order():
		var depth := Intrusion.into(town.at, village as Village)
		if depth > deepest + 0.0001:
			nearest = village
			deepest = depth
	return nearest
