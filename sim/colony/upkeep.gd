class_name Upkeep
extends RefCounted

## What it costs to keep a town's buildings and improvements running (#151).
##
## ## 🔒 A squeeze, not a punishment
##
## A building used to be a one-off cost and a permanent gain, so the tree was
## pure accumulation and there was no reason not to eventually build everything.
## Now most of them cost gold every month — and **if the town cannot pay, the
## effect is disabled and the building remains.**
##
## Not lost, not damaged, not demolished. It stands idle and switches back on the
## moment the town can afford it again, with no repair cost and no rebuilding.
## That distinction is the whole design: a bad year costs a town its advantages
## temporarily and gives them back when things improve.
##
## It pairs with the poverty trap `town-economy.md` already describes. A poor
## town buys no luxuries, so quality of life falls; now it also cannot run its
## mill, so its yields fall too. **That spiral is intended and it is breakable** —
## the PC can lower the duty, send resources, or stop demanding so much, which is
## precisely the kind of trouble the game should let him fix by letter.
##
## ## 🔒 Settled before the month's phases begin
##
## Buildings reach Work through yields, Reckon through reserves and Build through
## speed, so a town that paid afterwards would get a free month of effects from a
## building it cannot afford.
##
## **It is not a ninth phase.** SPEC §11.3 enumerates eight and this does not
## join them: it is a settlement the colony makes before the first of them, run
## town by town from one snapshot so the locked lockstep still holds. Whether the
## Author would rather see it in the list is raised on #151.
##
## ## What goes dark first
##
## What the governor values least. A man on a military intent keeps the stockade
## lit and lets the church go dark, and that falls out of **where each sits on his
## intent's menu** (#429) rather than out of a second opinion about what a
## building is for. Anything his menu does not name comes last.

const EVENT_PAID: StringName = &"upkeep_paid"
const EVENT_DARK: StringName = &"building_went_dark"
const EVENT_RELIT: StringName = &"building_relit"


## Settle one town's upkeep. Returns what it paid.
static func settle(town: Town, context: ColonyContext) -> float:
	var items := _billable(town, context)
	var was_dark := town.dark_buildings.duplicate()

	# Dearest to the governor first, so what he gives up is what he minds least.
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["worth"]), float(b["worth"])):
			return float(a["worth"]) > float(b["worth"])
		return String(a["key"]) < String(b["key"]))

	# 🔒 **Worker cabins carry the improvements' upkeep** (#412,
	# `tiles-and-improvements.md` §5) — while the cabins themselves are paid for.
	# Settled this month, not last: a trial run of the same order says whether
	# the cabins would be paid with the improvements billed in full, and if they
	# would, the improvements are billed nothing. Billing less before them can
	# only help the cabins, so the answer holds.
	if _cabins_are_paid(town, items):
		for item in items:
			if String(item["kind"]) == "improvement":
				item["upkeep"] = 0.0

	town.dark_buildings = PackedStringArray()
	var paid := 0.0
	var dark: PackedStringArray = PackedStringArray()
	for item in items:
		var due := float(item["upkeep"])
		# 🔒 **Shut, and the town may not pay for it** (#438): dark exactly as if
		# it could not afford to, whatever is in the purse.
		if bool(item.get("shut", false)):
			dark.append(String(item["key"]))
			_light(town, context, item, false)
			continue
		if due <= 0.0:
			_light(town, context, item, true)
			continue
		if town.can_afford(due):
			town.spend_gold(due)
			paid += due
			_light(town, context, item, true)
		else:
			# **It still stands.** Nothing is taken away but the effect.
			dark.append(String(item["key"]))
			_light(town, context, item, false)
	town.dark_buildings = _only_buildings(dark)

	_announce(town, context, was_dark)
	if paid > 0.0 or not dark.is_empty():
		context.log.emit(EVENT_PAID, town.id, context.state.month, {
			"town": String(town.id),
			"paid": paid,
			"dark": dark,
		}, WorldPhase.COLONY_MONTH)
	return paid


## Whether a building that carries improvement upkeep would be paid for this
## month, paying in `items`' order out of what the town has.
static func _cabins_are_paid(town: Town, items: Array) -> bool:
	var owed := 0.0
	var carried := false
	for item in items:
		if bool(item.get("shut", false)):
			continue
		var due := float(item["upkeep"])
		var paid := due <= 0.0 or town.can_afford(owed + due)
		if paid:
			owed += maxf(0.0, due)
		if String(item["kind"]) != "building":
			continue
		var building := Building.find(StringName(item["key"]))
		if building != null and bool(building.effect("carries_improvement_upkeep", false)) and paid:
			carried = true
	return carried


## Everything the town is billed for, with what its governor thinks of it.
static func _billable(town: Town, context: ColonyContext) -> Array:
	var items: Array = []
	for id in town.buildings:
		var building := Building.find(StringName(id))
		if building == null:
			continue
		items.append({
			"key": String(id),
			"kind": "building",
			"upkeep": building.upkeep,
			"worth": -float(AgendaMenu.rank_of(town.intent, StringName(id))),
			"shut": town.is_shut(StringName(id), context.state.month),
		})

	if context.map == null or context.territory == null:
		return items
	for at in context.tiles_of(town):
		var improvement := Improvement.find(context.map.improvement_at(at.x, at.y))
		if improvement == null or improvement.upkeep <= 0.0:
			continue
		items.append({
			"key": "%d,%d" % [at.x, at.y],
			"kind": "improvement",
			"at": at,
			"upkeep": improvement.upkeep,
			"worth": -float(AgendaMenu.rank_of(town.intent, &"improvement")),
		})
	return items


static func _light(town: Town, context: ColonyContext, item: Dictionary, lit: bool) -> void:
	if String(item["kind"]) != "improvement":
		return
	if context.map == null:
		return
	var at: Vector2i = item["at"]
	context.map.set_idle(at.x, at.y, not lit)


static func _only_buildings(keys: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key in keys:
		if not key.contains(","):
			out.append(key)
	out.sort()
	return out


## 🔒 **The player is never left to infer it from numbers he cannot see.**
##
## Town gold is hidden (SPEC §11.3), so the only way a PC learns his mill has
## stopped is a governor writing to say so — which makes this event the whole
## interface of the mechanic, and it has to name the building.
static func _announce(town: Town, context: ColonyContext, was_dark: PackedStringArray) -> void:
	for id in town.dark_buildings:
		if not was_dark.has(id):
			context.log.emit(EVENT_DARK, town.id, context.state.month, {
				"town": String(town.id),
				"building": String(id),
				"name": Building.find(StringName(id)).display_name,
			}, WorldPhase.COLONY_MONTH)
	for id in was_dark:
		if not town.dark_buildings.has(id):
			context.log.emit(EVENT_RELIT, town.id, context.state.month, {
				"town": String(town.id),
				"building": String(id),
				"name": Building.find(StringName(id)).display_name,
			}, WorldPhase.COLONY_MONTH)
