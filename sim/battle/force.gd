class_name Force
extends RefCounted

## What a company is worth, as one number (#214,
## `docs/mechanics/battles.md` §2, §5).
##
##     force = size
##           x arms multipliers (guns, tools, horses)
##           x leadership
##           x supply state
##           x terrain
##           x fortification
##
## #211 built the company. This makes it a combatant, and it is the whole of the
## combatant — §6's resolution reads one number from each side and nothing else.
##
## ## 🔒 Terrain folds into force and appears nowhere else
##
## **It is not a defender's bonus applied at resolution.** It multiplies into the
## defender's force here, and attacker and defender are then **equal actors with
## no second adjustment anywhere**.
##
## A dev who adds a defender's bonus at resolution has double-counted it, and the
## letters will then describe a mismatch that did not happen — which SPEC §9.1
## makes a correctness bug rather than a polish item.
##
## The same goes for fortification. There is exactly one place either term is
## applied, and `test_force` says so.
##
## ## 🔒 Surplus does nothing
##
## Each head **wants** so many guns, tools and horses, and what the company holds
## against what it wants sets a multiplier on that head's contribution. Ten times
## the muskets is not ten times the company.
##
## **Tools are a weapon here, not a toolbox** — trenches dug, battlements thrown
## up, muskets kept firing — so they multiply exactly as guns do, and a head
## wants fewer of them because they are shared.
##
## Same shape as pleasure in `quality-of-life.md`, *scaled by the fraction of the
## population served*, deliberately: one mental model covers both and neither
## needs new machinery.
##
## ## 🔒 And it is derived, never stored
##
## Force is a function of the company, the ground and who it is facing. A company
## that kept its force would have two answers to what it is worth the moment it
## lost a man, and one of them would be in a letter.

const COLLECTION: String = "battle"
const RECORD: String = "force"

## What each armed resource is worth at full supply, as the multiplier it adds.
##
## **Tuning**, and §12 lists it: *want-per-head for guns, tools and horses, and
## each one's multiplier.* A company at full supply on everything is worth
## several times an unarmed mob, which is what makes arming them a real
## allocation rather than a rounding.
static var _arms_worth: Dictionary = {"guns": 1.5, "tools": 0.5, "horses": 0.4}

## What a commander is worth. Tuning (§12: *what leadership is worth*), and §4
## is clear that leadership is **agency before it is a bonus** — so the bonus is
## deliberately modest, and a leaderless company is not a broken one.
static var _leadership: float = 1.25

## The three terrain tiers (§5). Tuning, and anything not named here is open
## ground.
static var _terrain: Dictionary = {"mountains": 1.8, "forest": 1.4}

## The two fort tiers (§5): a medium boost to a company attacking *from* it, a
## very high boost to one defending *in* it.
##
## A stubborn rebel company in a fort on a mountain is close to unassailable and
## is meant to be. The answer is not a better army — it is wearing them down over
## years, or finding somebody else to do it.
static var _fort_attacking: float = 1.3
static var _fort_defending: float = 2.5


static func load_from(record: Dictionary) -> void:
	_arms_worth = record.get("arms_worth", _arms_worth).duplicate()
	_leadership = float(record.get("leadership", _leadership))
	_terrain = record.get("terrain", _terrain).duplicate()
	_fort_attacking = float(record.get("fort_attacking", _fort_attacking))
	_fort_defending = float(record.get("fort_defending", _fort_defending))


static func reset() -> void:
	_arms_worth = {"guns": 1.5, "tools": 0.5, "horses": 0.4}
	_leadership = 1.25
	_terrain = {"mountains": 1.8, "forest": 1.4}
	_fort_attacking = 1.3
	_fort_defending = 2.5


## What the ground under a tile is worth to whoever is standing on it.
##
## **Open ground is one**, so plains, grassland and desert need no entry and a
## terrain nobody has written about does not silently become cover.
static func terrain_worth(terrain: StringName) -> float:
	return maxf(1.0, float(_terrain.get(String(terrain), 1.0)))


static func fort_worth(defending: bool) -> float:
	return _fort_defending if defending else _fort_attacking


## What its arms are worth, as one multiplier.
##
## 🔒 **A product of the three, each capped at full supply.** Multiplicative
## because they are different kinds of advantage — muskets to shoot with, tools
## to dig with, horses to arrive with — and a company short of all three is
## badly short rather than averagely equipped.
static func arms_of(company: Company) -> float:
	var worth := 1.0
	for resource in Company.armed_resources():
		var id := StringName(resource)
		worth *= 1.0 + float(_arms_worth.get(String(resource), 0.0)) \
			* company.armed_share(id)
	return worth


## What its commander is worth. One when it has none (§4).
static func leadership_of(company: Company) -> float:
	return _leadership if not String(company.commander).is_empty() else 1.0


## What the ground it stands on is worth, to a defender.
##
## 🔒 **Nought to an attacker**, because §5 makes terrain the defender's
## advantage and folding it in for both would be no advantage at all.
##
## 🔒 **And cavalry ignores it** (§8) — but never a fort. Horses are no answer to
## a wall, and the two terms are separate for exactly this reason.
static func terrain_of(
	company: Company, map: WorldMap, defending: bool, attacker: Company = null
) -> float:
	if not defending or map == null or company.at == Vector2i(-1, -1):
		return 1.0
	if attacker != null and attacker.is_cavalry():
		return 1.0
	return terrain_worth(map.terrain_at(company.at.x, company.at.y))


## What a fort on its tile is worth, attacking or defending.
static func fortification_of(company: Company, map: WorldMap, defending: bool) -> float:
	if map == null or company.at == Vector2i(-1, -1):
		return 1.0
	if map.improvement_at(company.at.x, company.at.y) != &"fort":
		return 1.0
	return fort_worth(defending)


## The whole of it, as one number.
##
## `defending` and `attacker` are how the two situational terms are asked for:
## terrain is the defender's and cavalry attacking cancels it, a fort helps
## whoever holds it either way. A company asked about in the abstract — the
## harness, a letter about what was raised — is neither, and gets the plain
## product of what it is made of.
static func of(
	company: Company,
	map: WorldMap = null,
	defending: bool = false,
	attacker: Company = null,
) -> float:
	if company == null or company.is_empty():
		return 0.0
	return float(company.size) \
		* arms_of(company) \
		* leadership_of(company) \
		* company.effectiveness() \
		* terrain_of(company, map, defending, attacker) \
		* fortification_of(company, map, defending)


## The six factors and the total, for an event payload.
##
## 🔒 **What a battle event carries** (§5's acceptance), so a letter can describe
## a mismatch truthfully — *they were four to our one, and on a mountain.* The
## total alone would let a letter say a company was overwhelmed without being
## able to say by what.
static func breakdown(
	company: Company,
	map: WorldMap = null,
	defending: bool = false,
	attacker: Company = null,
) -> Dictionary:
	if company == null:
		return {}
	return {
		"size": company.size,
		"arms": arms_of(company),
		"leadership": leadership_of(company),
		"supply": company.effectiveness(),
		"terrain": terrain_of(company, map, defending, attacker),
		"fortification": fortification_of(company, map, defending),
		"force": of(company, map, defending, attacker),
	}
