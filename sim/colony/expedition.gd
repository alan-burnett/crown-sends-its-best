class_name Expedition
extends RefCounted

## A town setting out to found another (#431, `docs/mechanics/founding-towns.md`
## §2, `governor-agendas.md` §6).
##
## ## Lean and thick
##
## **An expedition is one of two objectives, and the intent decides which.** Go
## wide sends a lean one, gathered for two months and taking a fifth of the
## town; go tall a thick one, gathered for five and taking two fifths. The
## figures are data (`data/colony/objectives.json`).
##
## - **While it gathers**, the town holds back all its wood, stone, tools and
##   food (Reckon), so none of them is sold or given away.
## - **When it leaves**, it takes everything of those four above the town's
##   normal reserve — **resources only, never buildings**. A town-launched
##   expedition founds a town with what it carries.
##
## This replaces #175's cargo rule, under which the governor set a target by
## what he could spare. **The difference between a grand expedition and a thin
## one is now which intent sent it.**
##
## ## It takes its share of the purse
##
## The departing population takes the share of the town's gold that its numbers
## represent: a fifth of the people leave with a fifth of the coin. Founding
## drains the parent's purse in proportion to the drain on its population.

const EVENT_LAUNCHED: StringName = &"expedition_launched"

## 🔒 What an expedition gathers and carries (§2): wood, stone, tools and food.
const GATHERS: PackedStringArray = ["food", "stone", "tools", "wood"]

## How far out the governor looks for new country, in tiles. Tuning.
const REGION_DISTANCE: int = 5


## How many people this expedition would take from this town: its share, whole.
static func people_for(town: Town, expedition: StringName) -> int:
	return maxi(0, int(floorf(float(town.population()) * Objective.share_of_people(expedition))))


## Whether this town could mount it at all.
##
## 🔒 **Rebel towns never found towns** (SPEC §11.4). They have a war to think
## about, and this is a filter rather than a weight — a very expansionist rebel
## governor must not be able to outvote it. And a town with nobody to send
## sends nobody.
static func may_launch(town: Town, expedition: StringName) -> bool:
	return Objective.is_expedition(expedition) and not town.rebelling \
		and people_for(town, expedition) > 0


## What it carries: everything of the four above what the town would normally
## keep. **Reckon wrote the normal reserve down** while the town was gathering;
## with no reckoning to hand, the town keeps nothing back.
static func cargo_for(town: Town, context: ColonyContext) -> Dictionary:
	var reckoning: Reckoning = context.reckonings.get(String(town.id))
	var cargo: Dictionary = {}
	for resource in GATHERS:
		var id := StringName(resource)
		var keep := 0.0
		if reckoning != null:
			keep = float(reckoning.normal_reserve.get(resource, reckoning.reserve_of(id)))
		var over := town.held(id) - keep
		if over > 0.0:
			cargo[resource] = over
	return cargo


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
	var going := people_for(town, town.objective)
	if going <= 0:
		return null
	town.expeditions_launched += 1

	# **The share its numbers represent**, taken before the people are, so the
	# proportion is of the town that mounted it rather than of what is left.
	var share := clampf(float(going) / maxf(1.0, float(town.population())), 0.0, 1.0)
	var purse := town.spend_share(share)

	var carried: Dictionary = {}
	var cargo := cargo_for(town, context)
	for resource in cargo:
		var taken := town.take(StringName(resource), float(cargo[resource]))
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

	# 🔒 **Elected the month it launches, not the month it arrives** (#178, §4).
	# The PC has no say whatever in who he is, and his regard for the Crown starts
	# where the man who sent him stood — which is what makes disloyalty propagate
	# geographically, a colony growing a sour second town before the PC has done
	# anything wrong at all.
	var elected := Governor.generate_for(
		party, context.contacts.get(String(town.governor_id)), context.streams)
	party.governor = elected.id
	context.contacts[String(elected.id)] = elected

	context.parties.append(party)

	context.log.emit(EVENT_LAUNCHED, town.id, context.state.month, {
		"town": String(town.id),
		"expedition": String(party.id),
		"governor": String(elected.id),
		"people": going,
		"gold": purse,
		"cargo": carried,
	}, WorldPhase.COLONY_MONTH)
	return party
