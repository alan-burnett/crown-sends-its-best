class_name Muster
extends RefCounted

## When the neighbours turn (#225, `docs/mechanics/natives.md` §7,
## `docs/mechanics/rival-pressure.md` §3).
##
## M5 built the relationships. **This is what happens when they fail**: the two
## sides of the map that can put men under arms against the colony, and the only
## place in the game that does.
##
## ## 🔒 Neither side is given a new threshold
##
## | | Musters when |
## | :--- | :--- |
## | **A tribe** | a village's own objective is `drive_them_off` |
## | **A duke** | `RivalDuke.makes_war` — the Minimum band, which is a latch |
##
## Both already existed and both were already deliberated. A village reaches
## *drive them off* only **past the point of no return** (`Village.settle`), and
## §3 of `rival-pressure.md` reads the four bands off one loyalty value with **no
## second state machine**. Inventing a hostility figure here would be a third
## place a decision to make war was recorded, and the first time somebody tuned
## one the others would not know.
##
## ## 🔒 Razing is not war, and this is not razing
##
## `tiles-and-improvements.md` §7 has hostile companies harassing the colony's
## ground: aggression that fires no optic, takes no town and escalates nothing.
## **That is the Low band and it is M5's** — `RivalTileDriver` and `DeniedTiles`,
## which run in phase 3 and never touch `Battle`.
##
## This file is the other end, and the two must stay apart. **A dev who routes
## harassment through battle resolution has made it cost prestige, and the long
## quiet middle of a run disappears.**
##
## ## 🔒 And neither path touches influence
##
## SPEC §12.5 has tribes **taking tiles**, which is a contest over influence and
## is neither razing nor battle. `natives.md` §10 holds it open and **it stays
## open**: nothing here reads or writes a village's influence, and a test says so.

const EVENT_WAR_PARTY: StringName = &"war_party_raised"
const EVENT_LANDED: StringName = &"rival_landed"

## What share of a village goes out with the war party, and the fewest people a
## village will send anybody at all. Tuning.
##
## **A share, because the party is the village's own people** — they are taken
## out of it and put under arms, not conjured. A village that empties itself has
## nothing left to come home to, which is why there is a floor.
const VILLAGE_SHARE: float = 0.4
const VILLAGE_KEEPS: int = 6_000

## 🔒 **How much of that share the quirk moves** (#288, *Restless
## country*).
##
## **One in every run without the quirk**, and above one their forces are more
## numerous — *stronger, not merely grumpier*, which is what makes low standing
## genuinely dangerous and the richer trade agreements worth reaching for.
##
## 🔒 **On the share and never on `PARTIES_PER_VILLAGE`.** That one is not
## tuning: it is the rule that stops the same men being counted twice, and a
## quirk raising it would put a village in the field against itself.
##
## 🔒 **And `VILLAGE_KEEPS` holds too.** A village that empties itself has
## nothing to come home to, whatever sort of country this is.
static var _party_scale: float = 1.0


static func party_scale() -> float:
	return _party_scale


static func set_party_scale(scale: float) -> void:
	_party_scale = maxf(0.0, scale)


static func reset() -> void:
	_party_scale = 1.0

## One war party in the field per village at a time.
##
## 🔒 Not a cap on aggression — a cap on *double-counting the same people*. The
## party is drawn from the village, so a second one raised while the first is
## still out would be the same men twice.
const PARTIES_PER_VILLAGE: int = 1

## How often a duke at Minimum lands another company, and how many he keeps in
## the field. Tuning, and `rival-pressure.md` §9 has both.
const LANDS_EVERY: int = 4
const LANDS_AT_MOST: int = 3
const LANDS_WITH: int = 45_000

## What a landed company carries. A European army arrives equipped, which is most
## of what makes a duke at Minimum different from a raid. Tuning.
const LANDS_ARMED: Dictionary = {"guns": 45.0, "tools": 20.0}

## 🔒 **The order they march under**, and it is not `defend_the_town`.
##
## They came to attack, so they need a man to decide where and when to stop
## (`Company.COMMANDED`, #434). Which leans on an open item —
## `battles.md` §13 asks *whether a native company's leadership works as anybody
## else's, or whether a tribe's war party answers to the village rather than to a
## man*. It is left open in the doc and it is **not settled here**: what this
## does is take the uniform path, because §1's *one structure, one resolver,
## whoever is holding the musket* is the standing rule and a headless war party
## could never leave its village.
const TO_WAR: StringName = StandingOrder.MARCH_ON_A_FOE


## Raise everything that is going to be raised this month.
##
## Phase 1, **arrivals**: men appear, and march in phase 2 of the month after.
## That is the announce-then-act property holding at the point where the colony
## most wants it — a muster is visible for a month before it arrives anywhere,
## which is the month a letter could still be read about it.
static func run_month(
	run: RunState, context: ColonyContext
) -> int:
	if run == null or context == null or context.companies == null:
		return 0
	return _tribes(run, context) + _rivals(run, context)


# --- 🔒 Tribes: a village that has concluded -------------------------------

static func _tribes(run: RunState, context: ColonyContext) -> int:
	if run.tribes == null:
		return 0
	var raised := 0
	for entry in run.tribes.villages_in_order():
		var village: Village = entry
		if village.objective != Village.DRIVE_THEM_OFF:
			continue
		if village.people <= VILLAGE_KEEPS:
			continue
		if _in_the_field(context, village.id) >= PARTIES_PER_VILLAGE:
			continue
		if _war_party(run, village, context) != null:
			raised += 1
	return raised


## **How many of a village would go out with a war party.**
##
## Never more than the village can spare, whatever the country is like: a village
## that empties itself has nothing to come home to.
static func going_from(village: Village) -> int:
	if village == null:
		return 0
	return mini(
		maxi(1, int(round(float(village.people) * VILLAGE_SHARE * _party_scale))),
		village.people - VILLAGE_KEEPS)


static func _war_party(
	run: RunState, village: Village, context: ColonyContext
) -> Company:
	var going := going_from(village)
	if going <= 0:
		return null

	# 🔒 **A body of people in the open carries a share of its stores**
	# (`CLAUDE.md`). The same share as the people, so the party is armed exactly
	# as well as the village was — which is what makes §10.1's coveting of guns
	# they cannot make matter: a village that has traded for muskets sends them.
	var share := float(going) / float(village.people)
	var carried: Dictionary = {}
	for resource in Company.armed_resources():
		var held := float(village.stores.get(String(resource), 0.0))
		if held <= 0.0:
			continue
		var taken := held * share
		village.stores[String(resource)] = held - taken
		carried[String(resource)] = taken

	village.people -= going

	var party := context.companies.raise_company(
		Company.NATIVE, going, carried, Company.SUPPORTED_ABROAD,
		village.at, context, TO_WAR, Company.COMMANDED)
	party.raised_by = village.id
	Commanders.take_command(party, null, run, context)

	context.log.emit(EVENT_WAR_PARTY, village.id, context.state.month, {
		"village": String(village.id),
		"tribe": String(village.tribe),
		"company": String(party.id),
		"size": going,
		"remaining": village.people,
		"at": [village.at.x, village.at.y],
	}, WorldPhase.ARRIVALS)
	return party


# --- 🔒 Rivals: a duke at Minimum ------------------------------------------

static func _rivals(run: RunState, context: ColonyContext) -> int:
	if run.rivals == null or run.demands == null:
		return 0
	var raised := 0
	for entry in RivalDuke.arrived_in(run, run.demands):
		var duke: Contact = entry
		# 🔒 **Without further gating** — the acceptance line. `makes_war` reads
		# the band off his one loyalty value and the band is a latch, so there is
		# nothing else to ask and nothing that could let him back.
		if not RivalDuke.makes_war(RivalDuke.band_for(duke, run.rivals)):
			continue
		if context.state.month % LANDS_EVERY != 0:
			continue
		if _in_the_field(context, duke.id) >= LANDS_AT_MOST:
			continue
		if _land(run, duke, context) != null:
			raised += 1
	return raised


static func _land(
	run: RunState, duke: Contact, context: ColonyContext
) -> Company:
	var ashore := _somewhere_to_land(run)
	if ashore == Company.NOWHERE:
		return null

	var landed := context.companies.raise_company(
		Company.RIVAL, LANDS_WITH, LANDS_ARMED.duplicate(),
		Company.SUPPORTED_ABROAD, ashore, context, TO_WAR, Company.COMMANDED)
	landed.raised_by = duke.id
	Commanders.take_command(landed, null, run, context)

	context.log.emit(EVENT_LANDED, duke.id, context.state.month, {
		"duke": String(duke.id),
		"company": String(landed.id),
		"size": LANDS_WITH,
		"at": [ashore.x, ashore.y],
	}, WorldPhase.ARRIVALS)
	return landed


## Where a duke puts men ashore: beside the colony's first town, deterministically.
##
## **Not a landing model**, and it is not meant to be. `rival-pressure.md` says
## nothing about where he comes from, and inventing a coastline search here would
## be a second map system nobody asked for — so he arrives where the colony is,
## which is the only thing the mechanic actually needs.
static func _somewhere_to_land(run: RunState) -> Vector2i:
	if run.colony == null:
		return Company.NOWHERE
	var towns := run.colony.in_order()
	if towns.is_empty():
		return Company.NOWHERE
	return towns[0].at


## How many live companies this village or duke already has out.
static func _in_the_field(context: ColonyContext, whose: StringName) -> int:
	var out := 0
	for entry in context.companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty():
			continue
		if company.raised_by == whose:
			out += 1
	return out
