class_name Company
extends RefCounted

## One visible body of armed men on one tile (#211,
## `docs/mechanics/battles.md` §1, §2, §3, §7, §8).
##
## ## 🔒 One structure, whoever is holding the musket
##
## SPEC §12.6 names two *kinds* — Colonial Forces and Crown Troops — and those
## are mass nouns. **A company is the countable thing on the map**, and a Crown
## force putting down a rebellion is many companies. Rebel, rival and native
## bodies are companies too, because one structure and one resolver is what stops
## five kinds of fighting men becoming five kinds of bug.
##
## `allegiance` is what §12.3's locks read — *colonists do not fight colonists*,
## *rebel towns fight the Crown's forces but never loyal towns*. Those are
## **filters on this field and nothing else**, and the field is here before
## anything fights so that M6 adds a resolver and not a model.
##
## ## 🔒 Victualled continuously, equipped once
##
## Two things wear the word *supply* and they behave nothing alike.
##
## | | What | From | When |
## | :--- | :--- | :--- | :--- |
## | **Support** | food, clothing | its town, or the Crown | every month |
## | **Arms** | guns, tools, horses | whatever it launched with | fixed at creation |
##
## **A company never resupplies its arms and never gains men. It only dwindles.**
## There is deliberately no method here that adds to either, and the one
## exception §2 allows is not a mechanic but a letter: a commander may write
## asking for gold to buy horses, and the company that gold raises is a new one.
##
## That is what makes arms a **launch decision**. Raising a company is an
## allocation, not a button.
##
## ## 🔒 Losses preserve ratios
##
## `CLAUDE.md`: *a company under arms loses a share of its people and the same
## share of its stores.* Which is why **a fully horsed company stays cavalry
## however badly it is mauled** (§8) — there is no unit type and no flag, only a
## threshold on a ratio that attrition cannot move.
##
## A dev who made losses take men without taking arms would make a mauled company
## *better* equipped than it started, and cavalry would become the reward for
## being beaten.

const COLLECTION: String = "battle"
const RECORD: String = "companies"

## No tile. A company being assembled, or one the map has no place for.
const NOWHERE: Vector2i = Vector2i(-1, -1)

# --- Allegiance -------------------------------------------------------------

## 🔒 **The field §12.3's locks read**, and the order §7 resolves in.
const COLONIAL: StringName = &"colonial"
const CROWN: StringName = &"crown"
const REBEL: StringName = &"rebel"
const RIVAL: StringName = &"rival"
const NATIVE: StringName = &"native"

## 🔒 **Factions in a set sequence** (§7). Order changes outcomes — several
## companies may attack one in a month and the defender weakens as they come —
## so it is fixed here and never incidental, and it needs no seeded roll because
## creation order is already deterministic from the seed.
const FACTIONS: Array[StringName] = [COLONIAL, CROWN, REBEL, RIVAL, NATIVE]

# --- Support ----------------------------------------------------------------

## 🔒 **The Crown victuals its own** (`the-marshal.md` §3, locked). There is no
## state in which Crown troops depend on the colony, so a company supported by
## this is never anybody's burden and never goes unsupported.
const SUPPORTED_BY_CROWN: StringName = &"crown"

## 🔒 **Fed by its own side, which is not on this map** (#225).
##
## A rival duke's army and a tribe's war party are victualled by the state or the
## people that sent them, and neither keeps books the colony can read. It is the
## same *behaviour* as a Crown company and deliberately not the same *field*:
## `is_the_crowns_burden` answers a question about the Marshal and must keep
## answering only that, or `the-marshal.md` §3's lock would quietly come to mean
## "anybody the colony does not feed".
##
## A company left on a town's id that the colony has no town for would go
## unsupported and bleed instead — which reads as a besieging army starving
## outside a town it is winning against.
const SUPPORTED_ABROAD: StringName = &"abroad"

const EVENT_RAISED: StringName = &"company_raised"
const EVENT_MOVED: StringName = &"company_moved"
const EVENT_UNSUPPORTED: StringName = &"company_unsupported"
const EVENT_DWINDLED: StringName = &"company_dwindled"
## 🔒 **Destroyed and disbanded are different things** (`commanders.md` §7). A
## company wiped out leaves its commander to a coin flip; one that stood down on
## its timer simply sends him home. One event for each, so the ticket that brings
## the coin flip has something unambiguous to listen for.
const EVENT_COMMANDED: StringName = &"company_commanded"
const EVENT_DESTROYED: StringName = &"company_destroyed"
const EVENT_DISBANDED: StringName = &"company_disbanded"

## Land seen for the first time by a company exploring (#434, Seam A).
const EVENT_EXPLORED: StringName = &"company_explored"

## A company whose town declared, or returned, and took its side (#434).
const EVENT_TURNED: StringName = &"company_turned"

## How long a leaderless militia stands before it goes home (`battles.md` §4).
## Tuning, and §9 of `commanders.md` says so.
static var _militia_months: int = 6

## What each head wants, per armed resource. **Tuning**, and §12 says so.
static var _want_per_head: Dictionary = {"guns": 1.0, "tools": 0.35, "horses": 1.0}

## Where a company stops being foot and becomes cavalry. A share of one, because
## §8 says *supplied to the full on horses*.
static var _cavalry_at: float = 1.0

## What an unsupported month costs: a share of the men, and a multiplier on what
## the rest are worth. Tuning (§12: *attrition per month while unsupported*).
static var _attrition: float = 0.06
static var _unsupported_effect: float = 0.6

## Tiles crossed in a month, and what cavalry gets instead (§8).
static var _tiles_per_month: int = 1
static var _cavalry_tiles: int = 2


static func load_from(record: Dictionary) -> void:
	_want_per_head = record.get("want_per_head", _want_per_head).duplicate()
	_cavalry_at = float(record.get("cavalry_at", _cavalry_at))
	_attrition = float(record.get("attrition", _attrition))
	_unsupported_effect = float(record.get("unsupported_effect", _unsupported_effect))
	_tiles_per_month = int(record.get("tiles_per_month", _tiles_per_month))
	_cavalry_tiles = int(record.get("cavalry_tiles", _cavalry_tiles))
	_militia_months = int(record.get("militia_months", _militia_months))


static func reset() -> void:
	_want_per_head = {"guns": 1.0, "tools": 0.35, "horses": 1.0}
	_cavalry_at = 1.0
	_attrition = 0.06
	_unsupported_effect = 0.6
	_tiles_per_month = 1
	_cavalry_tiles = 2
	_militia_months = 6


## The resources a company carries, in a fixed order.
##
## **Sorted**, because a share taken off every line has to be taken in the same
## order every time or two runs of one seed would round differently.
static func armed_resources() -> PackedStringArray:
	var out := PackedStringArray(_want_per_head.keys())
	out.sort()
	return out


static func want_per_head(resource: StringName) -> float:
	return maxf(0.0, float(_want_per_head.get(String(resource), 0.0)))


static func attrition() -> float:
	return _attrition


## What a head of *this* company wants, after its commander.
##
## 🔒 **Husbandry reduces what is wanted; it never adds** (`commanders.md` §6).
## A company only ever dwindles and is never re-equipped, so arming more men with
## the same cargo has to be a change to the appetite rather than a delivery — a
## commander who could conjure muskets would be the resupply mechanic
## `battles.md` §2 forbids.
func wants_per_head(resource: StringName) -> float:
	return Company.want_per_head(resource) \
		* CommanderExperience.knob_at(commander_level, "husbandry")


## What a month without rations costs *this* company, after its commander.
##
## **Hardiness** (`commanders.md` §6): a man who has kept an army in the field
## through one winter loses fewer of it to the next. It reduces the share and
## cannot raise it, because experience is what the bonus buys and not a tax on
## the inexperienced.
func attrition_for_me() -> float:
	return Company.attrition() \
		* minf(1.0, CommanderExperience.knob_at(commander_level, "hardiness"))


static func militia_months() -> int:
	return maxi(1, _militia_months)


var id: StringName = &""

## 🔒 **The sequential number it was given at instantiation** (§7). Within a
## faction, earliest-created goes first — the same rule that orders towns, and
## the reason resolution needs no tie-break.
var ordinal: int = 0

var allegiance: StringName = COLONIAL

## The population under arms. **Only ever falls.**
var size: int = 0

## What it launched with, per resource. **Only ever falls.**
var arms: Dictionary = {}

## The town that victuals it, or `SUPPORTED_BY_CROWN`.
var support: StringName = &""

## 🔒 **Who put these men under arms**, when that is not one of the colony's
## towns (#225).
##
## A village that sent a war party, or a duke who landed a company. It is not
## `support` — that says who feeds them and both of these feed their own — and it
## is emphatically not an urging, which is a letter reaching a commander and
## has no business carrying a faction's name.
##
## What reads it is `Muster`, to know how many a village already has out, so a
## second party is not raised from people who are already in the field.
var raised_by: StringName = &""

## The man who deliberates for it, or none (#220, `commanders.md` §1).
##
## 🔒 **A commander is an ordinary contact**, so this is his id and nothing more
## — his name, his personality, his leans and his relationship with the PC all
## live where every other contact's do.
var commander: StringName = &""

## 🔒 **What his commander has learned** (#223, `commanders.md` §6).
##
## **Derived, and refreshed at the one place experience changes.** The tally is
## the truth and lives on `CommanderBook`; this is the level read off it, kept
## here because every knob a level turns is asked of the company — how far it
## marches, what a head wants, what it is worth in a fight — and threading the
## book through all of them would put the roster inside `Force`.
##
## Nought for a headless militia, which is correct: there is nobody to have
## learned anything.
var commander_level: int = 0

## 🔒 **What it was raised to do, given once** (#220, `commanders.md` §3).
##
## **An order, never an objective.** A town has an objective it reconsiders every
## Settle; a militia has a standing order and no reconsideration machinery
## touches it. The two words carry weight elsewhere (SPEC §4) and must not merge,
## which is why this field is not called what #211 first called it.
var order: StringName = StandingOrder.DEFEND_THE_TOWN

## 🔒 **Who leads it, settled when it is raised** (#432, `governor-agendas.md`
## §6). A scouting party is always a militia; a big company has a commander
## unless its town was small; a war party or a duke's landing has one. **The
## order no longer decides it** (#434), so a scouting party sent to explore
## stays a militia however far it goes. Empty is a militia.
var led_by: StringName = &""

## The intent of the governor who raised it (#434, `commanders.md` §3): what the
## rule read for its order, and — for a company raised to prepare for rebellion
## — what makes its foe only ever the Crown's.
var raised_under: StringName = &""

const MILITIA: StringName = &"militia"
const COMMANDED: StringName = &"commander"


## Whether anybody will be deciding for it: its leadership as the raising
## settled it, and nobody where nothing did.
func wants_a_commander() -> bool:
	return led_by == COMMANDED

var at: Vector2i = NOWHERE

## Where it is marching. **Assigned by a standing order**, and one tile a month
## in a straight line, exactly as an expedition crosses country.
var destination: Vector2i = NOWHERE

var raised_month: int = 0

## The last month somebody actually fed it.
##
## 🔒 **A month, not a flag.** The town victuals in phase 4 and the consequence
## falls in phase 7, so the question asked in phase 7 is *did anybody feed it
## this month* — and a flag would have to be cleared by something, which is a
## thing to forget.
var supplied_month: int = -1

## 🔒 **What the PC last argued him toward**, and how (#221,
## `commanders.md` §8, SPEC §8.5).
##
## > *Argue with a commander's intent, never his target.* §12.6 gives the PC
## > goals and allocations; the tile is the commander's, exactly as it is the
## > governor's.
##
## So this names one of the five things a commander may decide — press the
## attack, hold, go on, come home, stand down — and never a place. It is the
## same shape a governor's urgings take, for the same reason: **a letter is not a
## standing order.** He remembers it, it fades, and how fast depends on how much
## he took it to mean. **One standing urging per author** (#405).
##
## 🔒 **And it is weighed against his regard, not obeyed.** A man who despises
## the PC has had the letter too.
var urgings: Array[Urging] = []

## 🔒 **Casualties owed but not yet taken** (#216, `battles.md` §6).
##
## A battle costs a company **men, fractionally**: a company dwindling at 0.2 a
## month is visibly dying for five months before it loses one, and that is
## exactly the letter its commander should be writing. Rounding each month away
## would make a small exchange free and a siege impossible.
##
## Always below one — whole men come off `size` as they are earned.
var casualties_owed: float = 0.0

## How many months running it has gone without. Zero the moment supply resumes,
## because §3 says it recovers the moment supply resumes and that is the whole
## of the rule.
var unsupported_months: int = 0

## 🔒 **Whether somebody at court has arranged for this company to have a bad
## year** (#284, `patrons.md` §5).
##
## A patron's rival specialty: he interferes with one duke, and that duke's
## companies **inflict less and break sooner** for a year. **Held apart from
## `unsupported_months`** deliberately — a sabotaged company is not an unsupplied
## one, and a letter that said so would be telling the player something untrue
## about why his enemy is losing.
##
## Written each month by `SabotageDriver` from a world value, so nothing here has
## to know what a patron is and the year runs down on its own.
var sabotaged: bool = false


func _init(p_id: StringName = &"", p_ordinal: int = 0) -> void:
	id = p_id
	ordinal = p_ordinal


# --- Arms -------------------------------------------------------------------

func held(resource: StringName) -> float:
	return float(arms.get(String(resource), 0.0))


## What the company holds against what it wants, capped at one.
##
##     armed_share(r) = min(held(r) / (size x want_per_head(r)), 1.0)
##
## 🔒 **Surplus does nothing** (§2). The same shape `quality-of-life.md` uses for
## pleasure — scaled by the fraction of the population served — and deliberately
## so: one mental model covers both and neither needs new machinery.
##
## A resource nobody wants reads as fully supplied, because a company that needs
## no horses is not short of horses.
func armed_share(resource: StringName) -> float:
	# Per thousand men, and horses by the head (`Population.amount_for`).
	var want := Population.amount_for(resource, wants_per_head(resource), float(size))
	if want <= 0.0:
		return 1.0
	return clampf(held(resource) / want, 0.0, 1.0)


## 🔒 **A threshold on the arms ratio, and no flag** (§8).
##
## Which is what makes it hold through attrition: losses take the same share of
## the horses as of the men, so the ratio is unchanged and the company is still
## cavalry. A company of four that started as forty is still mounted.
func is_cavalry() -> bool:
	return size > 0 and armed_share(&"horses") >= _cavalry_at


## Tiles it crosses in a month. Cavalry gets two (§8), and **Marches** adds one
## on top (`commanders.md` §6) — a man who knows how to move an army.
func tiles_this_month() -> int:
	return (_cavalry_tiles if is_cavalry() else _tiles_per_month) \
		+ CommanderExperience.added_at(commander_level, "marches")


## Attacks it makes in a month.
##
## **Named here and used by M6.** A normal company moves *and* attacks in the
## same month — not one or the other, or nothing could ever be chased down — and
## cavalry does both twice, which is a tempo advantage as much as a combat one.
func attacks_this_month() -> int:
	return _cavalry_tiles if is_cavalry() else _tiles_per_month


## Whether the Crown feeds it, in which case the colony never does (§3).
func is_the_crowns_burden() -> bool:
	return support == SUPPORTED_BY_CROWN


func is_empty() -> bool:
	return size <= 0


## Defence points this body of men carries of its own, over and above whatever
## the ground gives it (#218, `battles.md` §9).
##
## **None, for a company.** A company is worth the fort it is standing in and
## nothing more; §9's town is the one combatant that fortifies by some other
## means, and it says so by answering here.
##
## 🔒 **Points, never a multiplier.** What a point of defence is *worth* is a
## battle figure and is converted in `Force` and nowhere else (#215) — which is
## the double-count guard, and the reason this returns a count instead of the
## finished number.
func own_defence_points() -> float:
	return 0.0


## 🔒 **Nobody deliberates for it** (`battles.md` §4). A headless company holds
## the posture it was raised with and does nothing else — it never chooses, never
## reconsiders and can never be written to.
func is_headless() -> bool:
	return String(commander).is_empty()


## Whether a leaderless militia has stood its time (`battles.md` §4).
##
## 🔒 **Only a headless one.** A commanded company is not on a clock: its
## commander deliberates afresh every month and it goes where he decides, which
## is the whole difference §4 draws between the two.
##
## **And that is what gives defence a running cost.** A militia eats for every
## month it stands, so a town under sustained threat must keep re-raising and
## keep re-feeding — the Squeeze arriving in a system it has not touched before.
func has_stood_its_time(month: int) -> bool:
	return is_headless() and month - raised_month >= Company.militia_months()


## Send the survivors home (Seam A). Returns how many came back.
##
## **Where it stands**, the month its term ends (`commanders.md` §3): the people
## rejoin their town that month and nobody walks home. **Whatever arms it still
## carries go back into the town's stores** (⚠ assumed there).
##
## 🔒 **Disbanded, not destroyed.** The men go back into the town they were
## raised from and the company ends — and `commanders.md` §7 leans on the
## difference: a commander whose company stood down needs no coin flip, he simply
## goes home and waits.
func stand_down(town: Town, context: ColonyContext) -> int:
	var returning := size
	if town != null:
		# **Workers, because that is what they were.** A company is population
		# under arms, and putting them back where they came from is the whole of
		# it — `the-provost.md` §4's rule that workers go before experts is about
		# losses and has nothing to say about men coming home.
		town.workers += returning
		for resource in Company.armed_resources():
			var carried := float(arms.get(String(resource), 0.0))
			if carried > 0.0:
				town.store(StringName(resource), carried)
	var returned_arms := arms.duplicate()
	arms = {}
	size = 0
	context.log.emit(EVENT_DISBANDED, id, context.state.month, {
		"company": String(id),
		"order": String(order),
		"town": String(town.id) if town != null else "",
		"returned": returning,
		"arms": returned_arms,
		"months": context.state.month - raised_month,
	}, WorldPhase.RECKONING)
	return returning


# --- Support ----------------------------------------------------------------

## What this company eats in a month, per resource.
##
## **The townspeople's own per-head figures**, because soldiers are the same
## people with muskets. A separate table would be a second answer to how much a
## man eats, and the two would drift.
func victuals() -> Dictionary:
	var out: Dictionary = {}
	for resource in ColonyNeeds.needed_resources():
		var amount := Population.of(ColonyNeeds.per_head(StringName(resource)), float(size))
		if amount > 0.0:
			out[String(resource)] = amount
	return out


## Somebody fed it this month.
func was_supplied(month: int) -> void:
	supplied_month = month
	unsupported_months = 0


## Whether anybody fed it this month.
func feeds_itself() -> bool:
	return support == SUPPORTED_BY_CROWN or support == SUPPORTED_ABROAD


func is_supplied(month: int) -> bool:
	return feeds_itself() or supplied_month >= month


## How much of its strength it can actually bring, before anything about a battle.
##
## **Falls at once when it goes without** (§3), rather than after some number of
## months. A company that missed its rations this month is worse today, which is
## what makes a town's failure to cover it immediately legible.
func effectiveness() -> float:
	return 1.0 if unsupported_months <= 0 else _unsupported_effect


## A month without rations (Seam A). Returns how many men it cost.
##
## 🔒 **It bleeds, and it cannot disband its way out** (§3). The town that could
## not cover it sent nothing; the company wears it. And **it recovers the moment
## supply resumes** — `unsupported_months` going to nought is the whole of the
## recovery rule, because effectiveness reads that and nothing else.
func go_without(context: ColonyContext) -> int:
	unsupported_months += 1
	context.log.emit(EVENT_UNSUPPORTED, id, context.state.month, {
		"company": String(id),
		"support": String(support),
		"months": unsupported_months,
		"size": size,
	}, WorldPhase.RECKONING)
	return lose(attrition_for_me(), &"unsupported", context)


# --- Losses -----------------------------------------------------------------

## Lose a share of the men, and the same share of everything they carried.
##
## 🔒 **The share, not a count** (`CLAUDE.md`). A body of people in the open is
## not a town, so the one-population-at-a-time rule does not reach here — and the
## proportional loss of the arms with the men is the other half of it, which is
## what keeps a mauled company the same sort of company it was.
##
## **At least one man** when a share is asked for at all, so a company of eight
## losing six per cent is not immortal by rounding.
##
## Returns how many men were lost. Emits, per Seam A, because the map, the
## letters and the ledger all read the log rather than the state.
func lose(share: float, reason: StringName, context: ColonyContext) -> int:
	if size <= 0 or share <= 0.0:
		return 0
	return _remove(
		maxi(1, int(round(float(size) * clampf(share, 0.0, 1.0)))), reason, context)


## Take a fractional number of men, keeping what is left over for next month
## (#216, `battles.md` §6).
##
## 🔒 **The fractional half is the point.** Whole men come off as the tally
## passes one; the remainder stays on the company so a long siege adds up. A
## version that rounded each month would make a 0.2-a-month grind free forever,
## which is the failure the *visibly dying for five months* sentence describes.
##
## Returns how many men were actually taken this month, which is usually none.
func take_casualties(men: float, reason: StringName, context: ColonyContext) -> int:
	if size <= 0 or men <= 0.0:
		return 0
	casualties_owed += men
	var whole := int(floorf(casualties_owed))
	if whole <= 0:
		return 0
	casualties_owed -= float(whole)
	return _remove(whole, reason, context)


## Take this many men, and the same share of everything they carried.
func _remove(count: int, reason: StringName, context: ColonyContext) -> int:
	var lost := mini(maxi(0, count), size)
	if lost <= 0:
		return 0
	var taken := float(lost) / float(size)

	size -= lost
	if size <= 0:
		# Nobody left to owe anything for.
		casualties_owed = 0.0
	# **In a fixed order**, so two runs of one seed round the same way.
	for resource in Company.armed_resources():
		var had := held(resource)
		if had <= 0.0:
			continue
		arms[String(resource)] = maxf(0.0, had - had * taken)

	context.log.emit(EVENT_DWINDLED, id, context.state.month, {
		"company": String(id),
		"reason": String(reason),
		"lost": lost,
		"size": size,
		# **What it still holds**, so a reader can see the ratios were preserved
		# without having to recompute them from two events.
		"horsed": armed_share(&"horses"),
	}, WorldPhase.RECKONING)

	if is_empty():
		context.log.emit(EVENT_DESTROYED, id, context.state.month, {
			"company": String(id),
			"reason": String(reason),
			"commander": String(commander),
		}, WorldPhase.RECKONING)
		# 🔒 **The last man killed, and not merely an empty company** (#224,
		# `commanders.md` §7). `stand_down` empties a company too, and a man who
		# marched his militia home has not been shot — so the coin flip hangs off
		# this line rather than off `is_empty`.
		CommanderFate.settle(self, context)
	return lost


# --- Movement ---------------------------------------------------------------

## One month's march toward a tile. Returns whether it arrived.
##
## **The plainest possible line**, exactly as an expedition crosses country: a
## company that took a clever route would be one the player could not follow on
## a map that shows only what the colony knows (SPEC §11.2).
func advance(toward: Vector2i, context: ColonyContext) -> bool:
	if toward == NOWHERE or at == NOWHERE:
		return false
	if at == toward:
		return true

	var from := at
	for _tile in tiles_this_month():
		step_toward(toward)

	if at == from:
		return at == toward

	context.log.emit(EVENT_MOVED, id, context.state.month, {
		"company": String(id),
		"allegiance": String(allegiance),
		"at": [at.x, at.y],
		"toward": [toward.x, toward.y],
		"cavalry": is_cavalry(),
		"size": size,
	}, WorldPhase.MOVEMENT)
	return at == toward


## The PC has written to him (#221, `commanders.md` §8).
##
## 🔒 **An Order is never a write** (`CLAUDE.md`, Seam B). This does not move the
## company and does not decide anything — it records what was argued for, and the
## commander weighs it next time he deliberates, against his regard for the man
## who wrote it.
##
## **The latest letter is the one he is thinking about.** A second letter from
## the PC replaces his first rather than stacking with it, because a man does not
## hold two opinions about what the Crown wants; another author's stands beside it
## (#405).
func urge(toward: StringName, tone: StringName, month: int) -> void:
	stand(Urging.from_pc(toward, month, tone))


## Stand any author's urging, replacing that author's last (#405).
func stand(urging: Urging) -> void:
	Urging.stand(urgings, urging)


## This author's standing urging, or null. The PC's by default.
func urging_by(author: StringName = Urging.PC) -> Urging:
	return Urging.by(urgings, author)


## Say where a month's marching took it (Seam A).
##
## **Emitted once for the whole month**, however many tiles that was, because the
## map draws where a company ended up rather than each foot of the road.
func report_march(from: Vector2i, context: ColonyContext) -> void:
	context.log.emit(EVENT_MOVED, id, context.state.month, {
		"company": String(id),
		"allegiance": String(allegiance),
		"from": [from.x, from.y],
		"at": [at.x, at.y],
		"toward": [destination.x, destination.y],
		"cavalry": is_cavalry(),
		"size": size,
	}, WorldPhase.MOVEMENT)


## One tile toward somewhere, and nothing else.
##
## 🔒 **Separate from `advance` so a month can interleave** (#217,
## `battles.md` §8). A normal company moves *and* attacks in the same month —
## not one or the other, or nothing could ever be chased down — and cavalry does
## both twice, which is a tempo advantage as much as a combat one: **strike,
## reposition and strike again while the foot are still marching.**
##
## A march that moved its whole allowance before anybody could fight would make
## that impossible, so the driver walks a tile, resolves what it is now in
## contact with, and walks again.
##
## Returns whether it has arrived.
func step_toward(toward: Vector2i) -> bool:
	if toward == NOWHERE or at == NOWHERE or at == toward:
		return at == toward
	at += Vector2i(signi(toward.x - at.x), signi(toward.y - at.y))
	return at == toward


# --- Serialisation ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"ordinal": ordinal,
		"allegiance": String(allegiance),
		"size": size,
		"arms": arms.duplicate(),
		"support": String(support),
		"raised_by": String(raised_by),
		"commander": String(commander),
		"commander_level": commander_level,
		"order": String(order),
		"led_by": String(led_by),
		"raised_under": String(raised_under),
		"at": [at.x, at.y],
		"destination": [destination.x, destination.y],
		"raised_month": raised_month,
		"supplied_month": supplied_month,
		"unsupported_months": unsupported_months,
		"sabotaged": sabotaged,
		"casualties_owed": casualties_owed,
		"urgings": Urging.list_to_dicts(urgings),
	}


static func from_dict(data: Dictionary) -> Company:
	var company := Company.new(
		StringName(data.get("id", "")), int(data.get("ordinal", 0)))
	company.allegiance = StringName(data.get("allegiance", COLONIAL))
	company.size = int(data.get("size", 0))
	company.arms = data.get("arms", {}).duplicate()
	company.support = StringName(data.get("support", ""))
	company.raised_by = StringName(data.get("raised_by", ""))
	company.commander = StringName(data.get("commander", ""))
	company.commander_level = int(data.get("commander_level", 0))
	company.order = StandingOrder.of(StringName(data.get("order", "")))
	company.led_by = StringName(data.get("led_by", ""))
	company.raised_under = StringName(data.get("raised_under", ""))
	company.at = _vector(data.get("at", []))
	company.destination = _vector(data.get("destination", []))
	company.raised_month = int(data.get("raised_month", 0))
	company.supplied_month = int(data.get("supplied_month", -1))
	company.unsupported_months = int(data.get("unsupported_months", 0))
	company.sabotaged = bool(data.get("sabotaged", false))
	company.casualties_owed = float(data.get("casualties_owed", 0.0))
	company.urgings = Urging.list_from_dicts(data.get("urgings", []))
	return company


static func _vector(entry: Variant) -> Vector2i:
	var list: Array = entry if typeof(entry) == TYPE_ARRAY else []
	if list.size() < 2:
		return NOWHERE
	return Vector2i(int(list[0]), int(list[1]))
