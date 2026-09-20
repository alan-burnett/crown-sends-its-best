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
## What the governor values least. A man on a military intent keeps the armoury
## lit and lets the church go dark, and that falls out of the same axes the
## objective selector scores a building on rather than out of a second opinion
## about what a building is for.

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

	town.dark_buildings = PackedStringArray()
	var paid := 0.0
	var dark: PackedStringArray = PackedStringArray()
	for item in items:
		var due := float(item["upkeep"])
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
			"worth": _worth_to(town, ObjectiveSelector.building_axes(StringName(id))),
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
			"worth": _worth_to(town, ObjectiveSelector.improvement_axes_at(at, improvement, context)),
		})
	return items


## What this governor's intent makes of a thing, on the selector's own axes.
static func _worth_to(town: Town, axes: Dictionary) -> float:
	var total := 0.0
	for axis in axes:
		total += float(axes[axis]) * GovernorIntent.value_of(town.intent, String(axis))
	return total


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
