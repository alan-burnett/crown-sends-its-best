class_name Battle
extends RefCounted

## What happens when two companies meet (#216, `docs/mechanics/battles.md` §6,
## §7).
##
## A field battle is between **two adjacent companies**, and it happens because
## one of them, executing its move, chose to attack the other. It resolves inside
## world month phase 2, in one month.
##
## ## 🔒 Deterministic. No dice at all
##
## Everything *around* a battle is chaotic — whether the order arrived, whether
## the commander agreed, whether the town could feed him. **The battle itself is
## arithmetic.**
##
## The PC never commands (SPEC §12.6, locked), so he cannot be out-played, only
## under-prepared. Randomness would make what he spent on guns feel arbitrary;
## this way the map is legible and the uncertainty lives where the game wants it.
##
## **No RNG stream is consulted here**, and `test_battle` scans this file to make
## sure none ever is.
##
## ## The formula
##
##     casualties = LETHALITY x (my_force / their_force)
##
## Both sides compute it from the same force pair and **suffer simultaneously**.
##
## 🔒 **Casualties are men, and they are fractional.** A company dwindling at 0.2
## a month is visibly dying for five months before it loses a man, and that is
## exactly the letter its commander should be writing. They accumulate on the
## company rather than being rounded away each month.
##
## 🔒 **The grind accelerates on its own.** Force derives from population, so
## every loss lowers the loser's force and raises the winner's ratio next month —
## a besieger doing 0.2 a month is doing 1.0 a year later. **Nothing schedules
## that and nothing should.** It also makes obliterating a small company feel
## different from bleeding a large one, which is what stops a big army being
## merely a bigger number.
##
## ## 🔒 No rout
##
## Nobody retreats and nobody surrenders. **A company fights until it is
## destroyed**, and ground is taken only when the last defender is gone. There is
## no morale here, no withdrawal and no terms — a dev adding one has left the
## spec.
##
## ## 🔒 And the order is §7's
##
## Several companies may attack one in a month, and each is a separate battle
## resolved in sequence, **so the defender weakens as they come** — a Crown
## company surrounded by rebels can be destroyed in a single month. That is the
## design, which is why the order is fixed and never incidental.

const COLLECTION: String = "battle"
const RECORD: String = "resolution"

const EVENT_FOUGHT: StringName = &"battle_fought"

## A commander's tally crossed a level (#299). **Seam A**: the level was always
## refreshed here, and a cutscene, a letter or a playback beat about a man who
## has become someone could not see it happen until it said so.
const EVENT_ROSE: StringName = &"commander_rose"

## How many men a battle at parity costs each side in a month. **Tuning**, and
## `battles.md` §12 names it first: *`LETHALITY`, and whether the curve should be
## steeper than linear in the ratio.*
##
## Deliberately small. §9's siege takes months because a hard target is worn down
## by this curve and not by any machinery of its own.
static var _lethality: float = 0.1


static func load_from(record: Dictionary) -> void:
	_lethality = maxf(0.0, float(record.get("lethality", _lethality)))


static func reset() -> void:
	_lethality = 0.1


static func lethality() -> float:
	return _lethality


# --- 🔒 Who may fight whom --------------------------------------------------

## 🔒 **SPEC §12.3's locks, and they are filters on allegiance and nothing else**
## (`battles.md` §1).
##
## | | |
## | :--- | :--- |
## | *Colonists do not fight colonists* | colonial never meets rebel, and never meets the Crown |
## | *Rebel towns fight the Crown's forces but never loyal towns* | rebel meets Crown, and nobody else of the colony |
##
## Which has a consequence worth naming: **the colony's own militia cannot put
## down a rebellion.** Only Crown troops can, so a PC watching a town go has to
## ask the Marshal for them — and pay what that costs. That is the lock working
## rather than a gap in it.
##
## A company never fights itself, and never fights its own faction: two colonial
## companies are one army with two commanders.
static func may_fight(mine: Company, theirs: Company) -> bool:
	if mine == null or theirs == null or mine.id == theirs.id:
		return false
	if mine.is_empty() or theirs.is_empty():
		return false
	if mine.allegiance == theirs.allegiance:
		return false
	return not _on_one_side(mine.allegiance, theirs.allegiance)


## Whether these two are the same colony's people, in the sense §12.3 means.
static func _on_one_side(one: StringName, other: StringName) -> bool:
	var pair := [one, other]
	# Colonial and Crown are the PC's own two arms.
	if pair.has(Company.COLONIAL) and pair.has(Company.CROWN):
		return true
	# 🔒 **A rebel town never fights a loyal one.** Both are colonists, and the
	# quarrel is with the Crown rather than with the neighbours.
	if pair.has(Company.COLONIAL) and pair.has(Company.REBEL):
		return true
	return false


## Whether these two are close enough to fight.
##
## **Adjacent or on the same tile** (§6). A company that marched onto ground
## somebody else was holding is in contact with them.
static func are_in_contact(mine: Company, theirs: Company) -> bool:
	if mine == null or theirs == null:
		return false
	return tiles_in_contact(mine.at, theirs.at)


## The same question asked of two tiles.
##
## Named separately so that a caller deciding **whether to build a combatant at
## all** can ask it first — #218's towns are a view made on the spot, and a
## colony of twenty would otherwise be twenty views built per step to find the
## one that is adjacent.
static func tiles_in_contact(mine: Vector2i, theirs: Vector2i) -> bool:
	if mine == Company.NOWHERE or theirs == Company.NOWHERE:
		return false
	var apart := theirs - mine
	return absi(apart.x) <= 1 and absi(apart.y) <= 1


# --- The arithmetic ---------------------------------------------------------

## What one side inflicts, in men.
##
## 🔒 **Linear in the ratio, with no special case at any end.** A forty-against-
## four exchange is dramatically more lopsided than forty-against-twenty because
## the ratio is five times larger, not because anything here notices that one of
## them is small.
##
## A side facing nothing at all inflicts nothing: there is nobody to kill, and
## dividing by a force of zero would be an infinity in the state.
static func casualties_for(my_force: float, their_force: float) -> float:
	if my_force <= 0.0 or their_force <= 0.0:
		return 0.0
	return lethality() * (my_force / their_force)


## Fight one battle. Returns what it cost each side.
##
## 🔒 **Both sides compute from the same force pair, and suffer simultaneously.**
## The two forces are read before either company is touched, so neither side gets
## to swing at a man the other has already lost — which is what "simultaneously"
## means and the only reason a battle has no first-mover advantage.
static func resolve(
	attacker: Company, defender: Company, map: WorldMap, context: ColonyContext
) -> Dictionary:
	if not may_fight(attacker, defender):
		return {}

	# 🔒 **Read first, applied after.** Terrain and fortification reach this
	# through `Force` and nowhere else (§5); there is deliberately no defender's
	# bonus applied down here, and a dev who adds one has double-counted it.
	var theirs := Force.breakdown(defender, map, true, attacker)
	var mine := Force.breakdown(attacker, map, false)

	var they_lose := casualties_for(float(mine["force"]), float(theirs["force"]))
	var i_lose := casualties_for(float(theirs["force"]), float(mine["force"]))
	# **How many took the field**, before anybody fell (#299) — what a record of
	# the battle opens with.
	var my_men := attacker.size
	var their_men := defender.size

	var they_lost := defender.take_casualties(they_lose, EVENT_FOUGHT, context)
	var i_lost := attacker.take_casualties(i_lose, EVENT_FOUGHT, context)

	# 🔒 **Casualties inflicted, and nothing else** (#223, `commanders.md` §6).
	# Not battles won — §6 of this doc has no rout and no surrender, so *winning*
	# is not a quantity that exists. **Both sides learn**, because both inflicted
	# something: a defender who ground down an assault has learned from it as
	# surely as the man who ordered it.
	_learn(attacker, they_lose, context)
	_learn(defender, i_lose, context)

	context.log.emit(EVENT_FOUGHT, attacker.id, context.state.month, {
		"attacker": String(attacker.id),
		"defender": String(defender.id),
		"at": [defender.at.x, defender.at.y],
		# 🔒 **Both breakdowns, so a letter can describe a mismatch truthfully**
		# (#214) — *they were four to our one, and on a mountain.*
		"attacker_force": mine,
		"defender_force": theirs,
		"attacker_men": my_men,
		"defender_men": their_men,
		"attacker_allegiance": String(attacker.allegiance),
		"defender_allegiance": String(defender.allegiance),
		"attacker_casualties": i_lose,
		"defender_casualties": they_lose,
		"attacker_lost": i_lost,
		"defender_lost": they_lost,
		# 🔒 **No rout**, so the only way a battle ends a company is by killing
		# the last man in it. Reported because ground is taken only then.
		"defender_destroyed": defender.is_empty(),
		"attacker_destroyed": attacker.is_empty(),
	}, WorldPhase.MOVEMENT)

	return {
		"attacker_casualties": i_lose,
		"defender_casualties": they_lose,
		"defender_destroyed": defender.is_empty(),
		"attacker_destroyed": attacker.is_empty(),
	}


## Put what a company inflicted on its commander's account (#223).
##
## **Headless companies earn nobody anything**, which is correct: there is no man
## to have learned from it.
##
## The level is refreshed here because this is the one place the tally can
## change, so a company's `commander_level` cannot lag the book that decides it.
static func _learn(company: Company, inflicted: float, context: ColonyContext) -> void:
	if company == null or company.is_headless() or inflicted <= 0.0:
		return
	if context.commanders == null:
		return
	# **Read the book before and after**, not the company: a company's own level
	# is only refreshed where a commander takes it over, so comparing against it
	# would promote every new man on his first kill.
	var was := context.commanders.level_of(company.commander)
	context.commanders.record(company.commander, inflicted)
	company.commander_level = context.commanders.level_of(company.commander)
	if company.commander_level <= was:
		return
	# 🔒 **The rank, never the number, is what anybody downstream may say**
	# (`commander_experience.gd`): the level is on the payload for the sim's own
	# consumers, the rank id for anything the player reads.
	context.log.emit(EVENT_ROSE, company.commander, context.state.month, {
		"commander": String(company.commander),
		"company": String(company.id),
		"level": company.commander_level,
		"rank": String(CommanderExperience.rank_of(company.commander_level)),
		"inflicted": context.commanders.inflicted_by(company.commander),
	}, WorldPhase.MOVEMENT)


## Fight every battle a month has, in §7's order.
##
## `attacks` is a list of `{attacker, defender}`. **The order is the attacker's
## place in `Companies.in_resolution_order`** — factions in a set sequence, then
## earliest-created first — so three companies falling on one resolve as three
## battles against a defender who weakens as they come, and a Crown company
## surrounded by rebels can be destroyed in a single month.
##
## Returns the resolutions, in the order they were fought.
static func resolve_all(
	attacks: Array, companies: Companies, map: WorldMap, context: ColonyContext
) -> Array:
	var out: Array = []
	if companies == null:
		return out

	# **Ranked by the ordered list rather than sorted here**, so there is exactly
	# one definition of the order and this cannot drift from it.
	var rank: Dictionary = {}
	var place := 0
	for entry in companies.in_resolution_order():
		rank[String((entry as Company).id)] = place
		place += 1

	var ordered := attacks.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var one := int(rank.get(String((a["attacker"] as Company).id), place))
		var other := int(rank.get(String((b["attacker"] as Company).id), place))
		if one != other:
			return one < other
		# Two attacks by one company, which §6 allows cavalry: keep the order
		# they were offered in rather than inventing a second rule.
		return false)

	for attack in ordered:
		var fought := resolve(
			attack["attacker"] as Company, attack["defender"] as Company, map, context)
		if not fought.is_empty():
			out.append(fought)
	return out
