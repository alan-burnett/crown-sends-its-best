class_name Forts
extends RefCounted

## A fort has an owner, and a fort can fall (#419,
## `docs/mechanics/tiles-and-improvements.md` §6).
##
## ## 🔒 Its walls serve whoever stands in it
##
## The owner is who built it — a town, a Crown commander or a duke — so that its
## fall can say whose it was. **It is not whom it shelters**: `Force` already
## gives the fort's multiplier to any company standing on the tile, owner or
## not, and nothing here changes that.
##
## ## 🔒 How a fort falls (the Author's ruling)
##
## | | It falls |
## | :--- | :--- |
## | **Manned** | with its last defender: the battle that destroys the last company standing in it destroys the fort. No razing month follows |
## | **Empty** | razed, like any improvement (#418): an enemy company spends its month on it |
##
## **Either way it is one event**, naming the owner, the tile and the side that
## brought it down. A razed fort is a fort that fell, never a farm that burned.

const EVENT_FELL: StringName = &"fort_fell"
const STORMED: StringName = &"stormed"
const RAZED: StringName = &"razed"


static func is_fort(map: WorldMap, at: Vector2i) -> bool:
	if map == null or not map.in_bounds(at.x, at.y):
		return false
	var improvement := Improvement.find(map.improvement_at(at.x, at.y))
	return improvement != null and improvement.is_a_fortification()


## Whether anybody stands in it: a company with men in it on its tile.
static func is_manned(at: Vector2i, companies: Companies, except: Company = null) -> bool:
	if companies == null:
		return false
	for entry in companies.in_resolution_order():
		var company: Company = entry
		if company == except or company.is_empty():
			continue
		if company.at == at:
			return true
	return false


## Whose side the fort's owner is on: a duke's or a Crown commander's as it was
## built, and a town's as the town stands now (a fort a town raised is a rebel
## fort the month the town declares).
static func owner_side(map: WorldMap, at: Vector2i, colony: Colony) -> StringName:
	var owner := map.fort_owner(at.x, at.y)
	var by := StringName(owner.get("by", ""))
	if colony != null:
		var town := colony.by_id(by)
		if town != null:
			return TownCompany.of(town).allegiance
	return StringName(owner.get("side", ""))


## Whether this company may bring down the fort on `at`: it may fight whoever
## owns it (`Battle.may_fight`, so colonists never raze colonists' walls).
static func may_bring_down(company: Company, map: WorldMap, at: Vector2i, colony: Colony) -> bool:
	var side := owner_side(map, at, colony)
	if String(side).is_empty():
		return false
	var holder := Company.new(&"fort_holder", 0)
	holder.allegiance = side
	holder.size = 1
	return Battle.may_fight(company, holder)


## 🔒 **A manned fort falls with its last defender** (#419). Called after a
## battle: if the company that was destroyed stood in a fort and nobody else
## does, the fort goes with it.
static func fall_with(fallen: Company, by: Company, map: WorldMap, context: ColonyContext) -> void:
	if fallen == null or not fallen.is_empty() or not is_fort(map, fallen.at):
		return
	if is_manned(fallen.at, context.companies, fallen):
		return
	fall(fallen.at, by, map, context, STORMED)


## The fort on `at` is gone (Seam A): one event, whoever did it and however.
static func fall(at: Vector2i, by: Company, map: WorldMap, context: ColonyContext, how: StringName) -> void:
	var owner := map.fort_owner(at.x, at.y)
	var side := owner_side(map, at, context.colony)
	map.clear_improvement(at.x, at.y)
	map.set_idle(at.x, at.y, false)
	context.log.emit(EVENT_FELL, by.id if by != null else &"", context.state.month, {
		"at": [at.x, at.y],
		"owner": String(owner.get("by", "")),
		"owner_side": String(side),
		"brought_down_by": String(by.allegiance) if by != null else "",
		"company": String(by.id) if by != null else "",
		"how": String(how),
	}, WorldPhase.MOVEMENT)
