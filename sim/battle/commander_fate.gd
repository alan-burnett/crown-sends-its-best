class_name CommanderFate
extends RefCounted

## What becomes of a commander whose company is destroyed (#224,
## `docs/mechanics/commanders.md` §7).
##
## ## 🔒 He does not automatically die
##
## A draw from a named stream:
##
## | | |
## | :--- | :--- |
## | **Killed with his men** | his experience dies with him — nothing recoverable, nothing inherited |
## | **Survives, injured** | he waits in the town that dispatched him, at the level he left at |
##
## ## 🔒 Destroyed is not disbanded
##
## A commander whose company **stood down on its timer** needs no flip at all —
## he simply goes home and waits. That is why this hangs off the moment the last
## man is killed rather than off a company becoming empty: `stand_down` empties a
## company too, and a man who marched his militia home has not been shot.
##
## ## 🔒 Which is why no resupply mechanic exists
##
## A company **only ever dwindles** (`battles.md` §2) and is never reinforced or
## re-equipped. **The commander is the thing that persists, not the company** —
## a veteran waits in his town and takes the next command raised there, so
## experience survives across companies without any of the machinery reinforcing
## them would demand.
##
## A dev who reaches for reinforcement to make veterans durable has solved a
## problem this already solves.
##
## ## The stream
##
## **His own**, derived as `hash(run_seed, contact_id)` like everything else
## per-contact (`CLAUDE.md`), so the same seed kills the same men — and a
## commander who survived one company draws the *next* number when the second is
## lost rather than the same one again.

const EVENT_KILLED: StringName = &"commander_killed"
const EVENT_SURVIVED: StringName = &"commander_survived"

## The chance he walks away. **Tuning**, and `commanders.md` §9 says so in as
## many words: *the survival coin flip. It is currently even; it need not be.*
##
## A quirk names it (`perks-and-quirks.md` §4, *Commando commanders*), which is
## why it is a `static var` rather than the constant it was: a colony that breeds
## veterans is one that buries them faster, and that trade is the whole entry.
static var _survives: float = 0.5


static func survives() -> float:
	return _survives


## Turn it. A chance, so it stays a chance.
static func set_survives(chance: float) -> void:
	_survives = clampf(chance, 0.0, 1.0)


static func reset() -> void:
	_survives = 0.5


## Settle what happened to the man who was leading this company.
##
## Called at the moment the last man is killed, and nowhere else. Returns whether
## he lived.
static func settle(company: Company, context: ColonyContext) -> bool:
	if company == null or company.is_headless() or context == null:
		return true
	var commander: Contact = context.contacts.get(String(company.commander), null)
	if commander == null or context.streams == null:
		return true

	var drawn := context.streams.contact_stream(String(company.commander)).randf()
	if drawn < _survives:
		_he_lived(company, commander, context)
		return true
	_he_died(company, commander, context)
	return false


## 🔒 **He waits in the town that dispatched him** (§7).
##
## Unattached — the company is gone and he is not given another here. What makes
## him take the next one is `Commanders.waiting_in`, which looks for exactly this
## man before it generates anybody.
##
## **His level is untouched**, because the tally is his and lives on
## `CommanderBook` rather than on the company that earned it.
static func _he_lived(
	company: Company, commander: Contact, context: ColonyContext
) -> void:
	var home := context.colony.by_id(company.support) if context.colony != null else null
	if home != null:
		commander.town = home.display_name

	context.log.emit(EVENT_SURVIVED, commander.id, context.state.month, {
		"commander": String(commander.id),
		"name": commander.display_name,
		"company": String(company.id),
		"town": String(company.support),
		# 🔒 **The level, not a number for the player.** SPEC §14.1's habit holds
		# here: the harness and the letters read the log, and §10 leaves open
		# whether the PC ever learns a commander's level at all.
		"level": company.commander_level,
	}, WorldPhase.MOVEMENT)


## 🔒 **He leaves nothing behind** (§7). No recovering it and nothing to inherit.
static func _he_died(
	company: Company, commander: Contact, context: ColonyContext
) -> void:
	commander.is_dead = true
	if context.commanders != null:
		context.commanders.he_died(commander.id)

	context.log.emit(EVENT_KILLED, commander.id, context.state.month, {
		"commander": String(commander.id),
		"name": commander.display_name,
		"company": String(company.id),
		"town": String(company.support),
	}, WorldPhase.MOVEMENT)
