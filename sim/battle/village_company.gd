class_name VillageCompany
extends Company

## A village, presented as the combatant it becomes when the colony goes to war
## with its tribe (#456, `natives.md` §3 *By the blood spilled*, `battles.md` §9).
##
## ## 🔒 Fought as a town is, with no wall
##
## The same shape as `TownCompany`, and for the same reason: **there is no siege
## subsystem.** A village has people and stores, so it computes force exactly as a
## company does, and `Force`, `Battle` and the resolution order are untouched by
## it. What differs is the wall: **a village fortifies nothing** (`natives.md`
## §4), so it answers `own_defence_points` with the base class's nothing.
##
## ## 🔒 Only a tribe at war is anybody's foe
##
## A colonial or Crown company may march on and fall on a village only when its
## tribe is at war with that company's side: it has concluded the side means it
## destroyed (`natives.md` §2), or its men are in the field (a war party). A
## village at peace is nobody's target however near it stands.
##
## ## 🔒 Emptied, it is gone
##
## A village loses people as a town does, and **a village emptied of people is
## gone, and its land is free** (`natives.md` §3). Its land is read from the
## villages that stand, so there is nothing else to clear.
##
## ## It is a view, and the state stays on the village
##
## Built fresh whenever somebody is close enough to fight, and thrown away after.

const EVENT_STRUCK: StringName = &"village_struck"

## The village this stands for. Every write goes through it.
var village: Village = null

## Whose men fell on it, for the record.
var struck_by: StringName = &""


## Present a village as a combatant.
static func of(p_village: Village, attacker: Company = null) -> VillageCompany:
	if p_village == null:
		return null
	var view := VillageCompany.new(p_village.id, 0)
	view.village = p_village
	view.allegiance = Company.NATIVE
	# **Whose it is** reads the village, as a war party's does (`OrderRule.faction_of`).
	view.raised_by = p_village.id
	view.at = p_village.at
	view.support = p_village.id
	view.size = p_village.people
	view.order = StandingOrder.DEFEND_THE_TOWN
	# **Its stores are its armoury**, as a town's warehouse is.
	for resource in Company.armed_resources():
		var held := float(p_village.stores.get(String(resource), 0.0))
		if held > 0.0:
			view.arms[String(resource)] = held
	if attacker != null:
		view.struck_by = attacker.allegiance
	return view


## 🔒 **Whether this village's tribe is at war with the side this company fights
## for**: it has concluded that side means it destroyed, or it has men in the
## field. Only a colonial or Crown company asks (`natives.md` §3).
static func is_a_foe(p_village: Village, company: Company, context: ColonyContext) -> bool:
	if p_village == null or company == null or context == null or context.natives == null:
		return false
	if company.allegiance != Company.COLONIAL and company.allegiance != Company.CROWN:
		return false
	var tribe := context.natives.find(p_village.tribe)
	if tribe == null:
		return false
	var side := Tribe.CROWN_TROOPS if company.allegiance == Company.CROWN else Tribe.COLONY
	if tribe.is_irreconcilable_with(side):
		return true
	return has_men_in_the_field(tribe.id, context)


## Whether any of this tribe's villages has a war party in the field.
static func has_men_in_the_field(tribe: StringName, context: ColonyContext) -> bool:
	if context.companies == null or context.natives == null:
		return false
	var theirs: Dictionary = {}
	for entry in context.natives.villages_of(tribe):
		theirs[String((entry as Village).id)] = true
	for entry in context.companies.in_resolution_order():
		var other: Company = entry
		if other.allegiance == Company.NATIVE and not other.is_empty() \
				and theirs.has(String(other.raised_by)):
			return true
	return false


## 🔒 **Armed attack takes a share** of the village, in one event that says how
## many (`CLAUDE.md`). What it keeps in its stores it keeps, as a town keeps its
## warehouse; emptied, it is gone.
func _remove(count: int, reason: StringName, context: ColonyContext) -> int:
	if village == null:
		return 0
	var lost := mini(maxi(0, count), village.people)
	if lost <= 0:
		return 0
	village.people -= lost
	size = village.people
	if size <= 0:
		casualties_owed = 0.0
	context.log.emit(EVENT_STRUCK, village.id, context.state.month, {
		"village": String(village.id),
		"tribe": String(village.tribe),
		"reason": String(reason),
		"by": String(struck_by),
		"lost": lost,
		"remaining": village.people,
		"at": [village.at.x, village.at.y],
	}, WorldPhase.MOVEMENT)
	if village.people <= 0 and context.natives != null:
		context.natives.lose(village, struck_by, context)
	return lost
