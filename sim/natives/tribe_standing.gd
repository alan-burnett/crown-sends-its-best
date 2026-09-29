class_name TribeStanding
extends RefCounted

## What moves a tribe's standing toward the colony (#204, SPEC §12.5, §11.4;
## `docs/mechanics/natives.md` §3).
##
## ## 🔒 The asymmetry is the design
##
## Intrusion and exploitation are **continuous** — they accrue from simply
## existing next door and expanding. Repair is **slow** and mostly requires doing
## nothing.
##
## So a colony that grows is losing standing by default, and it must actively
## trade to hold level. `immigration.md` §9's chain reaches a second system here:
## growth costs you with the neighbours too.
##
## ## 🔒 Any of them can carry a people over (#456)
##
## One score (`natives.md` §2): a town founded among their fields, a month of
## working them, an expedition crossing their country and blood spilled all count
## toward the same point of no return, and any of them can be the one that
## carries a people past it. Blood counts most, and fastest.
##
## 🔒 **Every mover names the tribe and the cause**, in its own event. A standing
## that moved for reasons the log could not account for would be a standing the
## Diplomat's reports could not explain either, and §1 says the natives reach the
## PC only through his own people.

const EVENT_FOUNDING: StringName = &"tribe_offended_by_founding"
const EVENT_EXPLOITATION: StringName = &"tribe_lost_land_to_a_town"
const EVENT_AGGRESSION: StringName = &"tribe_attacked_by_colonists"
const EVENT_EXPEDITION: StringName = &"tribe_offended_by_an_expedition"
const EVENT_LEFT_ALONE: StringName = &"tribe_left_alone"

# --- Tuning ----------------------------------------------------------------

## What a founding costs at its worst — a town in the middle of their country.
##
## **One-off and heavy.** It is the single most consequential thing the colony
## does to a tribe without firing a shot, and it is the thing SPEC §11.4 names.
const FOUNDING_OFFENCE: float = 22.0

## What one month of one town working one of their fields costs.
##
## Small, because the point is that it never stops.
const PER_WORKED_TILE: float = 0.22

## The most one town's fields can cost a tribe in a month, however many it works.
## A town cannot grind a people down faster by being enormous.
const EXPLOITATION_CAP: float = 2.4

## What an expedition crossing the middle of their country costs (#456). **A
## passing, not a settling**: about a quarter of a founding. A placeholder.
const EXPEDITION_OFFENCE: float = 6.0

## 🔒 **Points of standing per percent of the tribe killed** (#456, §3): twice the
## share, so a tenth of the tribe costs 20. A placeholder.
const BLOOD_PER_PERCENT: float = 2.0

## What the colony recovers in a month nobody did anything to them.
##
## 🔒 **Slower than any one of the ways down**, and it is the only way up that
## costs the colony nothing. Trade (#206) and meeting their requests (#207) are
## the ways a colony can actually work at this.
const LEFT_ALONE: float = 0.45


## A town appeared. What the tribes make of where it went (Seam A).
##
## 🔒 **In proportion to the intrusion** (SPEC §11.4). A town three fields from
## their land is a worry; a town among their fields is a declaration.
static func founding(at: Vector2i, natives: Tribes, context: ColonyContext) -> void:
	if natives == null:
		return
	# Every tribe that can see it, not only the nearest: two peoples whose land
	# meets near the new town both have a view about it.
	for tribe in natives.in_order():
		var depth := _depth_toward(at, tribe as Tribe, natives)
		if depth <= 0.0001:
			continue
		(tribe as Tribe).move(
			Tribe.COLONY, -FOUNDING_OFFENCE * depth, "a town founded on our country",
			context)
		context.log.emit(EVENT_FOUNDING, (tribe as Tribe).id, context.state.month, {
			"tribe": String((tribe as Tribe).id),
			"at": [at.x, at.y],
			# **How far in, not how much standing.** The figure never leaves the
			# sim (`natives.md` §1); how deep into their country it sits is a
			# thing a governor could actually write home about.
			"depth": depth,
			"beyond_their_border": depth >= Intrusion.AT_THE_BORDER,
		}, WorldPhase.RECKONING)


## A month of the colony working ground somebody else holds (Seam A).
##
## The exploitation §12.5 names, and **it charges every month it continues** —
## which is what makes leaving a town where it is a decision rather than a fact.
static func exploitation(
	colony: Colony,
	natives: Tribes,
	territory: Territory,
	context: ColonyContext,
) -> Dictionary:
	var taken: Dictionary = {}
	if colony == null or natives == null or territory == null:
		return taken

	for town in colony.in_order():
		# Tribe id -> how many of its fields this town worked.
		var fields: Dictionary = {}
		for tile in territory.tiles_of(town.id):
			var holder := natives.holder_of(tile)
			if String(holder).is_empty():
				continue
			fields[String(holder)] = int(fields.get(String(holder), 0)) + 1

		var names: Array = fields.keys()
		names.sort()
		for id in names:
			var tribe := natives.find(StringName(id))
			if tribe == null:
				continue
			var worked := int(fields[id])
			var cost := minf(EXPLOITATION_CAP, PER_WORKED_TILE * float(worked))
			tribe.move(Tribe.COLONY, -cost, "a town working our fields", context)
			taken[id] = true
			context.log.emit(EVENT_EXPLOITATION, tribe.id, context.state.month, {
				"tribe": id,
				"town": String(town.id),
				"fields": worked,
			}, WorldPhase.RECKONING)
	return taken


## Somebody attacked them (Seam A): the colony's men, or the Crown's.
##
## 🔒 **Toward whoever did it** (#456, §3): the colony for colonial companies,
## the Crown's troops for theirs. Its caller is `blood_spilled`.
static func aggression(
	tribe: Tribe,
	severity: float,
	why: String,
	context: ColonyContext,
	toward: StringName = Tribe.COLONY,
) -> void:
	if tribe == null:
		return
	tribe.move(toward, -absf(severity), why, context)
	context.log.emit(EVENT_AGGRESSION, tribe.id, context.state.month, {
		"tribe": String(tribe.id),
		"toward": String(toward),
		"why": why,
		"concluded": tribe.is_irreconcilable_with(toward),
	}, WorldPhase.RECKONING)


## 🔒 **By the blood spilled** (#456, `natives.md` §3): an attack on a tribe's
## people — a village or a war party — costs standing toward whoever did it,
## **twice the share of the tribe killed, in points**. A tenth of the tribe
## killed costs 20. A skirmish barely registers; a village put to the sword
## latches at once.
##
## `lost` is how many of `victim`'s people fell to `killer`'s men. Asked after
## the losses, so the tribe it is a share of is the tribe as it stood before them.
static func blood_spilled(killer: Company, victim: Company, lost: int, context: ColonyContext) -> void:
	if killer == null or victim == null or lost <= 0 or context == null or context.natives == null:
		return
	if victim.allegiance != Company.NATIVE:
		return
	var toward := StringName()
	match killer.allegiance:
		Company.COLONIAL, Company.REBEL:
			# ⚠ assumed: a rebel is still a colonist to them (SPEC §13.1 counts a
			# rebel town as the colony's).
			toward = Tribe.COLONY
		Company.CROWN:
			toward = Tribe.CROWN_TROOPS
		_:
			return
	var village := _village_of(victim, context.natives)
	if village == null:
		return
	var tribe := context.natives.find(village.tribe)
	if tribe == null:
		return
	var before := people_of(tribe.id, context) + lost
	if before <= 0:
		return
	var share := float(lost) / float(before)
	aggression(tribe, BLOOD_PER_PERCENT * share * 100.0,
		"our people killed by the %s" % ("Crown's soldiers" if toward == Tribe.CROWN_TROOPS else "colonists"),
		context, toward)


## Everybody a tribe has: in its villages and in the field.
static func people_of(tribe: StringName, context: ColonyContext) -> int:
	var people := 0
	var theirs: Dictionary = {}
	for entry in context.natives.villages_of(tribe):
		var village: Village = entry
		people += village.people
		theirs[String(village.id)] = true
	if context.companies != null:
		for entry in context.companies.in_resolution_order():
			var company: Company = entry
			if company.allegiance == Company.NATIVE and theirs.has(String(company.raised_by)):
				people += company.size
	return people


static func _village_of(victim: Company, natives: Tribes) -> Village:
	if victim is VillageCompany:
		return (victim as VillageCompany).village
	for entry in natives.villages_in_order():
		if (entry as Village).id == victim.raised_by:
			return entry
	return null


## 🔒 **An expedition on their ground** (#456, `natives.md` §3, §11): the first
## month a travelling expedition stands on or within `Intrusion`'s margin of
## their land, **by how deep it goes**, as a founding is.
static func expedition(tribe: Tribe, depth: float, at: Vector2i, party: StringName, context: ColonyContext) -> void:
	if tribe == null or depth <= 0.0001:
		return
	tribe.move(Tribe.COLONY, -EXPEDITION_OFFENCE * depth, "an expedition crossing our country", context)
	context.log.emit(EVENT_EXPEDITION, tribe.id, context.state.month, {
		"tribe": String(tribe.id),
		"party": String(party),
		"at": [at.x, at.y],
		"depth": depth,
	}, WorldPhase.RECKONING)


## Nobody did anything to them this month (Seam A).
##
## 🔒 **Time, and being left alone.** The slow way back, and the only one that
## asks nothing of the colony but restraint.
static func left_alone(
	natives: Tribes,
	moved: Dictionary,
	context: ColonyContext,
) -> void:
	if natives == null:
		return
	for tribe in natives.in_order():
		var id := String((tribe as Tribe).id)
		if moved.has(id):
			continue
		if (tribe as Tribe).trust() >= Tribe.NEUTRAL - 0.0001:
			# Time carries a people back to civil and no further. Liking the
			# colony is something the colony has to earn (#206, #207).
			continue
		var before := (tribe as Tribe).trust()
		var after := (tribe as Tribe).move(
			Tribe.COLONY, LEFT_ALONE, "a quiet month", context)
		if after > before + 0.0001:
			context.log.emit(EVENT_LEFT_ALONE, (tribe as Tribe).id, context.state.month, {
				"tribe": id,
			}, WorldPhase.RECKONING)


## How deep into *this* tribe's country a tile sits.
##
## `Intrusion.at` answers for whoever minds most; this asks one people, since
## every tribe near a new town has its own view of it.
static func _depth_toward(tile: Vector2i, tribe: Tribe, natives: Tribes) -> float:
	var deepest := 0.0
	for village in natives.villages_of(tribe.id):
		deepest = maxf(deepest, Intrusion.into(tile, village as Village))
	return deepest
