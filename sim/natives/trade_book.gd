class_name TradeBook
extends RefCounted

## Every standing agreement between a village and a town (#206).
##
## **One per town at a time.** A town deals with the people it borders, not with
## a market: three simultaneous agreements would make the natives a supplier
## rather than a neighbour, and would give a well-placed town an escape from the
## Crown's monopoly wide enough to make the monopoly irrelevant.

var deals: Array = []


## The agreement this town is holding, or null.
func of_town(town: StringName) -> TradeAgreement:
	for deal in in_order():
		if (deal as TradeAgreement).town == town:
			return deal
	return null


func has_one(town: StringName) -> bool:
	return of_town(town) != null


## Every agreement, in a fixed order.
func in_order() -> Array:
	var out: Array = deals.duplicate()
	out.sort_custom(func(a: TradeAgreement, b: TradeAgreement) -> bool:
		return String(a.town) < String(b.town))
	return out


func open(deal: TradeAgreement, context: ColonyContext) -> void:
	if deal == null or has_one(deal.town):
		return
	deals.append(deal)
	context.log.emit(TradeAgreement.EVENT_OPENED, deal.town, context.state.month, {
		"tribe": String(deal.tribe),
		"town": String(deal.town),
		"they_give": String(deal.they_give),
		"we_give": String(deal.we_give),
		# 🔒 **What the governor has just done**, in the log, so the letter that
		# tells the PC about it next month is reading the same fact the sim did.
		"arms_them": ResourceCatalogue.native_worth(deal.we_give) >= 3.0,
	}, WorldPhase.RECKONING)


func close(deal: TradeAgreement, why: StringName, context: ColonyContext) -> void:
	deals.erase(deal)
	context.log.emit(TradeAgreement.EVENT_CLOSED, deal.town, context.state.month, {
		"tribe": String(deal.tribe),
		"town": String(deal.town),
		"why": String(why),
	}, WorldPhase.RECKONING)


func to_dict() -> Dictionary:
	var out: Array = []
	for deal in in_order():
		out.append((deal as TradeAgreement).to_dict())
	return {"deals": out}


static func from_dict(data: Dictionary) -> TradeBook:
	var book := TradeBook.new()
	for entry in data.get("deals", []):
		book.deals.append(TradeAgreement.from_dict(entry))
	return book
