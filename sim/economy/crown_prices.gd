class_name CrownPrices
extends RefCounted

## What moves the Crown's dictionary (#141, `docs/mechanics/town-economy.md` §1,
## SPEC §10.2, §12.4).
##
## Two drivers, composing with each other and with a patron's barony rather than
## replacing anything:
##
## | | |
## | :--- | :--- |
## | **The war** | a slow standing lift on what an army consumes, read straight off `crown_war_intensity` |
## | **A shortage at home** | a sharp lift on one resource that decays back over a season |
##
## SPEC §12.4 has the Crown's wars reaching the colony through troop
## availability, demands and treaties. **Prices are the fourth channel and the
## cheapest of the four**, because the number is already there and already
## moving — no new world value, no second clock.
##
## ## 🔒 Necessities, never pleasures
##
## **No luxury carries a war appetite, and no luxury can be the subject of a
## shortage.** Both are enforced here and checked by the content validator, not
## left as a convention.
##
## That is what keeps the tea rule safe **by construction rather than by clamp**.
## Tea is the cheapest pleasure a town can never make for itself; price it above
## a luxury the colony can brew and towns brew instead of buying, and SPEC
## §10.2's trade protests quietly stop working with nothing failing loudly.
##
## It is also truer. A Crown at war prices iron, not tea.
##
## ## 🔒 Nothing here names a resource
##
## Appetite is a **data field on the resource**, the same rule the conversion
## recipes already follow. A resource a war should want later is a data edit.
##
## ## 🔒 And neither may reach a demand's size
##
## `crown-demands.md` §10: a demand's size is fixed when it is written and no
## price movement touches it. `DemandBook` sizes its asks off
## `ResourceCatalogue.price_of` — the authored figure — and must go on doing so,
## or a shortage that doubled the grain price would halve a demand for grain and
## the Squeeze would ease off on its own, invisibly.

## Where a shortage's lift is kept, one world value per resource.
##
## **On `WorldState`**, so it saves and loads with everything else and there is
## no second place a price movement lives.
const SHORTAGE_PREFIX: String = "crown_shortage_"

const EVENT_SHORTAGE_BEGAN: StringName = &"crown_shortage_began"
const EVENT_SHORTAGE_EASED: StringName = &"crown_shortage_eased"

## Placeholders, all of them. M8 owns the numbers; this owns the mechanism.
const SHORTAGE_CHANCE: float = 0.05
const SHORTAGE_LIFT: float = 0.8
const SHORTAGE_MONTHS: int = 6
const SHORTAGE_FLOOR: float = 0.02


## What the Crown's own circumstances are doing to this price, as a multiplier.
##
## **One, when nothing is happening**, so a colony in a quiet year trades at the
## authored prices and the table in §1 reads as written.
static func multiplier(state: WorldState, resource: StringName) -> float:
	if state == null:
		return 1.0
	return war_lift(state, resource) * shortage_lift(state, resource)


## 🔒 **The war lift, and it needs no new state** (§1).
##
## `1 + appetite x (war / WAR_MAX)`, so a resource with no appetite never moves
## and a resource with one moves with the campaign that is already running.
static func war_lift(state: WorldState, resource: StringName) -> float:
	var appetite := appetite_of(resource)
	if appetite <= 0.0:
		return 1.0
	var war := clampf(
		float(state.get_value(WorldValues.WAR, 0.0)) / CrownAffairs.WAR_MAX,
		0.0, 1.0)
	return 1.0 + appetite * war


## 🔒 **A luxury has no appetite, whatever the data says.**
##
## Guarded here as well as validated, because the validator runs on the build and
## this runs on every price — and the failure it prevents is silent.
static func appetite_of(resource: StringName) -> float:
	if ResourceCatalogue.is_luxury(resource):
		return 0.0
	return maxf(0.0, ResourceCatalogue.war_appetite(resource))


## What a shortage at home is doing to this price.
static func shortage_lift(state: WorldState, resource: StringName) -> float:
	if ResourceCatalogue.is_luxury(resource):
		return 1.0
	return 1.0 + maxf(0.0, float(state.get_value(key_for(resource), 0.0)))


static func key_for(resource: StringName) -> String:
	return SHORTAGE_PREFIX + String(resource)


# --- The shortage, month by month -------------------------------------------

## Phase 5: start one if the Crown is unlucky, and ease whatever is running.
##
## **A reversal rather than a lift**, which is the half worth building for. §1's
## mercantile table has food at *Crown values low — grown at home at scale — no
## trade*; a failed harvest turns that row over for a season, gives the Steward
## something worth writing about, and gives every governor a reason to
## reconsider what his town is for.
static func advance(
	state: WorldState, log: EventLog, rng: RandomNumberGenerator
) -> void:
	_ease(state, log)
	if rng == null or rng.randf() >= SHORTAGE_CHANCE:
		return
	_begin(state, log, rng)


## 🔒 **Decays back**, so a shortage is a season and not a new price.
static func _ease(state: WorldState, log: EventLog) -> void:
	var step := SHORTAGE_LIFT / float(maxi(1, SHORTAGE_MONTHS))
	for id in ResourceCatalogue.ids():
		var resource := StringName(id)
		var held := float(state.get_value(key_for(resource), 0.0))
		if held <= 0.0:
			continue
		var left := held - step
		if left <= SHORTAGE_FLOOR:
			state.apply(log, EVENT_SHORTAGE_EASED, &"crown",
				{key_for(resource): 0.0}, WorldPhase.CROWNS_MONTH)
			continue
		state.apply(log, EVENT_SHORTAGE_EASED, &"crown",
			{key_for(resource): left}, WorldPhase.CROWNS_MONTH)


## 🔒 **Necessities only**, and one at a time.
##
## Drawn in sorted order from the `sim` stream the war already uses, so the same
## seed shorts the same harvest.
static func _begin(
	state: WorldState, log: EventLog, rng: RandomNumberGenerator
) -> void:
	var candidates := PackedStringArray()
	for id in ResourceCatalogue.ids():
		var resource := StringName(id)
		if ResourceCatalogue.is_luxury(resource):
			continue
		if float(state.get_value(key_for(resource), 0.0)) > 0.0:
			continue  # Already short of this one.
		candidates.append(String(id))
	if candidates.is_empty():
		return

	var short_of := StringName(candidates[rng.randi_range(0, candidates.size() - 1)])
	state.apply(log, EVENT_SHORTAGE_BEGAN, short_of,
		{key_for(short_of): SHORTAGE_LIFT}, WorldPhase.CROWNS_MONTH)
