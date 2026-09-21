class_name Expedition
extends RefCounted

## A town setting out to found another (#175, `docs/mechanics/founding-towns.md`
## §2).
##
## ## 🔒 One rule produces both kinds of expedition
##
## The governor sets the **target cargo by what he can spare** — stockpile above
## needs, above the current objective, above reserve — and the town gathers
## toward it over months exactly as it would toward a building.
##
## A prosperous town therefore sets a grand target and sends a colony that will
## leap ahead of its parent. A crowded, poor town shedding mouths it cannot feed
## sets a target of almost nothing and sends people with what they can carry.
## **Same objective, same machinery, opposite outcomes**, and no branch anywhere
## asking which sort of town this is.
##
## ## It takes its share of the purse
##
## The departing population takes the share of the town's gold that its numbers
## represent: a fifth of the people leave with a fifth of the coin. Founding
## drains the parent's purse in proportion to the drain on its population, and a
## rich town's expedition is rich for the same reason it is well supplied.
##
## ## What this ticket does not do
##
## Travel, attacks, the new governor and arrival are each their own ticket
## (#176–#179). What launches here is an event carrying everything the expedition
## took; where it goes is somebody else's business.

const EVENT_LAUNCHED: StringName = &"expedition_launched"

## What share of a town's people go, at most.
##
## **A tuning target the doc names** (§10, "how the governor sizes his target
## cargo against what he can spare"). A quarter is enough to matter to the parent
## and not enough to gut it, and the overflow trigger that decides *when* a
## crowded town starts shedding is the shared open item between this and
## `immigration.md` §10.
const SHARE_OF_PEOPLE: float = 0.25

## The fewest people worth calling an expedition.
const FEWEST: int = 4

## How far out the governor looks for new country, in tiles. Tuning.
const REGION_DISTANCE: int = 5

## How many months of the cargo's own keep it carries.
##
## Supplies for the crossing and something to start on. Tuning.
const MONTHS_OF_KEEP: float = 3.0


## What this town would send, if its governor decided to send one.
##
## **Everything above what the town needs, its project needs and its reserve
## needs** — which is what `Reckoning.spare` already means, so this asks the town
## the same question Sell asks rather than inventing a second idea of "spare".
static func cargo_for(town: Town, context: ColonyContext) -> Dictionary:
	var going := people_for(town)
	if going <= 0:
		return {}

	var cargo: Dictionary = {}
	var reckoning: Reckoning = context.reckonings.get(String(town.id))
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var spare := town.held(id)
		if reckoning != null:
			spare = reckoning.spare_of(id)
		if spare <= 0.0:
			continue

		# It carries what the people who are leaving would want, and no more of
		# it than the town can actually spare.
		var wanted := float(going) * ColonyNeeds.per_head(id) * MONTHS_OF_KEEP
		if wanted <= 0.0:
			# Not a need. A well-found expedition still takes tools and timber to
			# build with, in proportion to what the parent can afford to lose.
			wanted = spare * SHARE_OF_PEOPLE
		var taking := minf(spare, wanted)
		if taking > 0.0:
			cargo[String(id)] = taking
	return cargo


## How many people would go.
static func people_for(town: Town) -> int:
	return maxi(0, mini(int(floorf(float(town.population()) * SHARE_OF_PEOPLE)),
		town.population() - FEWEST))


## Whether this town could mount one at all.
##
## 🔒 **Rebel towns never found towns** (SPEC §11.4). They have a war to think
## about, and this is a filter rather than a weight — a very expansionist rebel
## governor must not be able to outvote it.
static func may_launch(town: Town) -> bool:
	return not town.rebelling and people_for(town) >= FEWEST


## The area the governor sets out for (#177).
##
## **Far enough to be a journey and near enough to be his colony's.** Nothing
## clever: a step outward from the parent town, away from the middle of the map,
## which gives a region without needing a survey the colony has not done.
##
## 🔒 Deterministic. The same town on the same map sets out for the same country,
## so a save reloaded at the gate goes to the same place.
static func region_for(town: Town, context: ColonyContext) -> Vector2i:
	if context.map == null or town.at == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var middle := Vector2i(context.map.width / 2, context.map.height / 2)
	var outward := town.at - middle
	if outward == Vector2i.ZERO:
		outward = Vector2i(1, 0)
	var step := Vector2i(signi(outward.x), signi(outward.y))
	var region := town.at + step * REGION_DISTANCE
	region.x = clampi(region.x, 0, maxi(0, context.map.width - 1))
	region.y = clampi(region.y, 0, maxi(0, context.map.height - 1))
	return region


## Send it. The parent loses its people and the matching share of its coin.
##
## Returns the party that set out (#176), or null. **It becomes a unit on the
## map** rather than vanishing into an arrival: the PC can watch it go, because
## it is his colony's own and the map shows what the colony knows.
static func launch(town: Town, context: ColonyContext) -> ExpeditionParty:
	var going := people_for(town)
	if going <= 0:
		return null

	# **The share its numbers represent**, taken before the people are, so the
	# proportion is of the town that mounted it rather than of what is left.
	var share := clampf(float(going) / maxf(1.0, float(town.population())), 0.0, 1.0)
	var purse := town.spend_share(share)

	var carried: Dictionary = {}
	for resource in town.objective_cargo:
		var taken := town.take(StringName(resource), float(town.objective_cargo[resource]))
		if taken > 0.0:
			carried[resource] = taken

	# Workers first, because the experts a town has are the last thing it parts
	# with — and a shed expedition is mouths rather than talent.
	town.workers = maxi(0, town.workers - going)

	var party := ExpeditionParty.new()
	party.id = StringName("expedition_%s_%d" % [town.id, context.state.month])
	party.parent = town.id
	party.people = going
	party.cargo = carried
	party.gold = purse
	party.at = town.at
	party.launched_month = context.state.month
	# 🔒 **A region, and not a tile** (#177, SPEC §11.4). The governor sets out
	# toward an area with his own idea of what he is looking for; the PC's
	# preferences arrive in his reply to the governor's first letter and shift him
	# while he travels. A site fixed here would make that letter a month too late.
	party.region = region_for(town, context)
	party.preference = SitePreference.GOOD_GROUND
	context.parties.append(party)

	context.log.emit(EVENT_LAUNCHED, town.id, context.state.month, {
		"town": String(town.id),
		"expedition": String(party.id),
		"people": going,
		"gold": purse,
		"cargo": carried,
	}, WorldPhase.COLONY_MONTH)
	return party
