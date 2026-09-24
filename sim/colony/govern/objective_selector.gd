class_name ObjectiveSelector
extends RefCounted

## What the town does about its governor's intent (#429,
## `docs/mechanics/governor-agendas.md` §3).
##
## ## 🔒 Deterministic. No personality, no weights, no dice.
##
## The governor has wise and honourable advisors. **He never picks a foolish
## project** — he picks an excellent project in service of a goal the player may
## think is completely wrong, and arguing with the goal is the game.
##
## ## A menu, walked
##
## **The axis model is retired** (§1). Each intent has its own ordered menu in
## the data, and the town takes the first entry that is wanted, reachable,
## placeable and not already built (`AgendaMenu`). Nothing taken is *no
## building*, the shared fallback. There is no scoring here at all: where a
## slot needs one — which tile, which of several — it is the slot's own scorer
## (#430).

const EVENT_CHOSEN: StringName = &"objective_chosen"


## What the town should work on, given the intent. Returns `{id, target}`, with
## `target` a tile for an improvement and `Vector2i(-1, -1)` otherwise.
static func choose(town: Town, intent: StringName, context: ColonyContext) -> Dictionary:
	if not GovernorIntent.is_intent(intent):
		return {"id": &"", "target": Vector2i(-1, -1)}
	return AgendaMenu.walk(town, intent, context)


# --- Reachable ---------------------------------------------------------------

## Whether the town could ever get all of this.
##
## **Unreachable before it starts.** The militia needs guns, guns need iron, the
## town produces no ore and has no money — that objective is unreachable and no
## amount of patience fixes it, so it never becomes the objective in the first
## place.
static func can_obtain_all(town: Town, cost: Dictionary, context: ColonyContext) -> bool:
	var ids: PackedStringArray = PackedStringArray(cost.keys())
	ids.sort()
	for resource in ids:
		if not can_obtain(town, StringName(resource), context):
			return false
	return true


static func can_obtain(town: Town, resource: StringName, context: ColonyContext) -> bool:
	if town.held(resource) > 0.0 or town.invested(resource) > 0.0:
		return true
	for at in context.tiles_of(town):
		if context.map != null and context.map.yield_at(at.x, at.y, resource) > 0.0:
			return true
	# Otherwise it has to be bought, which needs somebody to buy from and the
	# money to do it with.
	return Trade.may_trade_with_crown(town, resource, context) \
		and town.can_afford(ResourceCatalogue.price_of(resource))
