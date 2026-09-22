class_name Threat
extends RefCounted

## What a town has to be afraid of, this month (#219,
## `docs/mechanics/quality-of-life.md` §4, §6).
##
## ## 🔒 Not "is this town at war"
##
## §6 is exact about it: safety is **"is this town threatened by forces it cannot
## handle"**. So this is a *ratio* and never a count. A town that can meet what
## has come for it is not much afraid of it, however loud the month was.
##
## The consequence §6 asks for falls out rather than being written: **a rebel
## town that has beaten what was sent against it is safe**, and that is precisely
## when it becomes most dangerous to the colony. Nothing here knows that it is a
## rebel town — the Crown's company is destroyed, so there is no hostile force in
## contact, so there is no threat.
##
## ## 🔒 Facts about the world, never the sentiment
##
## Quality of life feeds rebel sentiment, so it may never read it
## (`quality-of-life.md` §7). Everything below is read off the map and the
## companies standing on it: who is next to the town, how strong they are, and
## whether the roads out of it are clear. The multi-month spiral of SPEC §12.3
## still runs, mediated through things that actually happened.
##
## ## 🔒 Who counts as hostile is `Battle.may_fight` and nothing else
##
## §12.3's locks are filters on allegiance (`battles.md` §1), so a loyal town is
## not frightened of a rebel company — rebels never fight loyal towns, and a town
## that felt menaced by men who cannot touch it would be a second, quieter place
## those locks had to be maintained.

## How the two fears divide.
##
## **Being attacked weighs far more than being cut off**, because one of them
## kills people and the other delays a cart. Tuning.
##
## *Outmatched*, not *besieged*, and the word is the argument: §6 asks whether
## the town is threatened by forces **it cannot handle**, which is a ratio. There
## is no siege here to be in (`battles.md` §9) and nothing that would know how
## long one had run.
const OUTMATCHED_SHARE: float = 0.75

## The odds at which a town is *entirely* unafraid, and the odds at which it is
## as afraid as it can be.
##
## Matched deliberately to `CommanderConsiderations`' reading of a fight: a
## commander withdraws on the same curve a town panics on, so the force a town
## can see off and the force a commander will face are one judgement and not two.
const EVEN: float = 0.5


## What this town faces, and what that leaves of its safety.
##
## `{"outmatched": [0,1], "cut_off": [0,1], "safety": [0,1]}`.
static func to(town: Town, context: ColonyContext) -> Dictionary:
	var safe := {"outmatched": 0.0, "cut_off": 0.0, "safety": 1.0}
	if town == null or context == null or context.companies == null:
		return safe

	var wall := TownCompany.of(town)
	var hostile: Array[Company] = []
	for entry in context.companies.in_resolution_order():
		var other: Company = entry
		if Battle.may_fight(wall, other):
			hostile.append(other)
	# **The common case, and it is nearly every month of nearly every run.** No
	# enemy anywhere means no pathfinding, no force arithmetic and no per-town
	# work at all — which is what keeps a live safety component from costing what
	# an inert one cost nothing for.
	if hostile.is_empty():
		return safe

	var outmatched := _outmatched(wall, hostile, context)
	var cut_off := _cut_off(town, hostile, context)
	return {
		"outmatched": outmatched,
		"cut_off": cut_off,
		"safety": clampf(
			1.0 - (OUTMATCHED_SHARE * outmatched + (1.0 - OUTMATCHED_SHARE) * cut_off),
			0.0, 1.0),
	}


## 🔒 **How badly it is outmatched by what is actually at the wall.**
##
## Everything hostile in contact is summed into one force, because three
## companies around a town are one problem to the people inside it. Against that
## stands the town's own force **and every friendly company standing with it** —
## which is what makes raising a militia do something a governor can feel, and
## the reason `battles.md` §4's running cost of defence buys anything at all.
##
## `0` when the town matches or beats them, `1` when it is hopeless.
static func _outmatched(
	wall: TownCompany, hostile: Array[Company], context: ColonyContext
) -> float:
	var theirs := 0.0
	for enemy in hostile:
		if Battle.tiles_in_contact(wall.at, enemy.at):
			theirs += Force.of(enemy, context.map, false)
	if theirs <= 0.0:
		return 0.0

	var mine := Force.of(wall, context.map, true)
	for entry in context.companies.in_resolution_order():
		var friend: Company = entry
		if friend.allegiance != wall.allegiance or friend.is_empty():
			continue
		if Battle.tiles_in_contact(wall.at, friend.at):
			mine += Force.of(friend, context.map, true)

	var odds := mine / maxf(0.001, mine + theirs)
	return clampf((EVEN - odds) * 2.0, 0.0, 1.0)


## 🔒 **Whether it is safe to travel to the other towns** (§4).
##
## The share of them the town cannot reach without walking past somebody. A
## company does not have to besiege a town to make life there worse — sitting on
## the road between it and its neighbours is enough, and it is the cheapest
## aggression there is.
##
## **A town with nowhere to travel to fears nothing**, which is the founding
## settlement's first years and is correct: the road it cannot use does not
## exist yet.
static func _cut_off(
	town: Town, hostile: Array[Company], context: ColonyContext
) -> float:
	if context.colony == null:
		return 0.0
	var others: Array[Town] = []
	for other in context.colony.in_order():
		if other.id != town.id and other.at != Vector2i(-1, -1):
			others.append(other)
	if others.is_empty():
		return 0.0

	# Every tile a hostile company can reach out and touch, gathered once. A
	# road runs past a company standing beside it, not only through one.
	var watched: Dictionary = {}
	for enemy in hostile:
		if enemy.at == Company.NOWHERE:
			continue
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				watched[Vector2i(enemy.at.x + dx, enemy.at.y + dy)] = true

	var blocked := 0
	for other in others:
		if _road_is_watched(town.at, other.at, watched):
			blocked += 1
	return float(blocked) / float(others.size())


## Whether anything stands over the road between two tiles.
##
## **The straight line, a tile at a time**, which is the same walk a company
## makes with `step_toward` — so the road a cart takes and the road an army takes
## are the same road, and a blockade placed on one blocks the other.
static func _road_is_watched(
	from: Vector2i, to: Vector2i, watched: Dictionary
) -> bool:
	var here := from
	# Bounded by the longer axis: `step_toward` closes both by one each tile, so
	# the walk cannot take more steps than that and cannot fail to arrive.
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for _tile in steps:
		here += Vector2i(signi(to.x - here.x), signi(to.y - here.y))
		if watched.has(here):
			return true
	return false
