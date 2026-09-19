class_name Town
extends RefCounted

## Everything a town is (SPEC §11.3). The central structure of the colony.
##
## **🔒 Towns run themselves** under their Governor. The PC shapes things through
## letters — setting objectives and policies, sending resources — but never
## manages them directly. Nothing here takes an instruction from the player; it
## takes Intents, like everything else.
##
## ## The hidden balance
##
## **A town's gold is invisible to the player** (SPEC §11.3), and the player's
## own gold is not a wallet (§10.2). The two are different things and neither is
## a number on the desk. So the balance here is `_gold`, there is no getter, and
## `tools/lint.gd` fails if anything under `presentation/` so much as mentions
## it. The Ledger shows Crown-side transactions, which is a different thing
## again.

# --- Population (SPEC §12.2) -----------------------------------------------

const WORKERS: StringName = &"workers"
const EXPERTS: StringName = &"experts"
const LIVESTOCK: StringName = &"livestock"

var id: StringName = &""
var display_name: String = ""

## Where it sits on the map.
var at: Vector2i = Vector2i(-1, -1)

## **Three distinct kinds, not one number.** Workers determine how many tiles the
## town can work; experts raise the yield of one resource each; livestock are
## traded and pastured. Experts and livestock grow in M4.
var workers: int = 0
var experts: Dictionary = {}    ## resource id -> how many experts of it
var livestock: Dictionary = {}  ## livestock resource id -> head

## Resource id -> how much is held.
var stockpile: Dictionary = {}

## Buildings completed, in build order.
var buildings: PackedStringArray = PackedStringArray()

## **Stored, and updated only in Settle.** A reader that recomputed it would get
## a different answer halfway through a month, and two readers would disagree.
var quality_of_life: float = 0.0

## How close the town is to deciding it would be better off without the Crown
## (#71). Written by Settle each month; see `RebelSentiment`.
##
## **🔒 Quality of life may never read this.** QoL feeds sentiment, so sentiment
## reading back would close the loop inside a single month
## (`docs/mechanics/quality-of-life.md` §7). The multi-month spiral of SPEC §12.3
## runs through things that actually happened instead.
var rebel_sentiment: float = 0.0

## The last thing the town finished, and the month it finished in.
##
## **Build clears the objective the moment it completes**, so by the time the
## governor sits down to write in phase 9 there is nothing left on the town
## saying a church went up. Without this his letter announcing it can never fire,
## which is exactly what happened.
var last_completed: StringName = &""
var last_completed_month: int = -1

## What the town bought and sold this month, in gold.
##
## **Reset in Reckon and added to by every trade**, so it is this month's figure
## and not the run's. A governor writes about the month that just happened.
var traded_value: float = 0.0

## Births owed but not yet born.
##
## **Natural growth starts slowly and snowballs** (SPEC §12.1), which for a town
## of twelve means a fraction of a person a month. Carrying the fraction is what
## stops a small town growing not at all while a large one grows smoothly.
var growth_accrued: float = 0.0

## **What the governor wants for the town** — a standing goal that may hold for
## twenty months (`GovernorIntent`). He chooses it; the town works out what to
## do about it.
var intent: StringName = &""

## When he settled on it. Read by nothing that decides; written so a letter can
## say how long he has been at this.
var intent_since: int = 0

## What the PC last wrote that the town was *for*, and when.
##
## **🔒 An order reaches the governor's intent, never the town's objective**
## (SPEC §8.5). This is the only thing a letter can move, and a consideration —
## not a rule — decides what he does about it.
var urged_intent: StringName = &""
var urged_month: int = 0

## What the town is working towards. **The town chooses it, deterministically,
## to serve the intent** — a building, an improvement, or a standing posture.
## See `Objective` and `ObjectiveSelector`.
var objective: StringName = &""

## The tile, when the objective is an improvement. The governor picked it.
var objective_target: Vector2i = Vector2i(-1, -1)

## The intent this objective was chosen to serve. When it and `intent` differ,
## the objective becomes eligible for reconsideration — eligible, not doomed.
var objective_intent: StringName = &""

## The month work began.
var objective_since: int = 0

## Months in a row the build has put in no labour. **Kept by Build, read by
## Reconsideration**: only Build knows whether a month moved the project on.
var objective_idle_months: int = 0

## Months of labour already put in. Only construction advances it.
var objective_progress: int = 0

## Resource id -> how much has gone into the build.
##
## **Invested is spent.** It has left the stockpile, so it cannot be eaten, sold
## or given away, and a town that stalls for want of the rest does not get it
## back (#49).
var objective_invested: Dictionary = {}

## Months in a row the town has gone meaningfully without food.
##
## **Famine is sustained hunger, not one bad month** (#48). A town that misses a
## month recovers; a town that misses three buries people.
var months_hungry: int = 0

## Relief given away, less relief received, valued at Crown prices.
##
## **A town that keeps carrying the colony resents the Crown for it** (#45). M3
## reads this into rebel sentiment; M2's job is to have it be true by then.
var relief_balance: float = 0.0

## The contact who speaks for it (#52).
var governor_id: StringName = &""

## Whether it still obeys the Crown (SPEC §12.3, #72).
##
## **A rebel town is not a lost town.** In the Crown's eyes it is still the PC's,
## and his job is to bring it back: it trades with loyal neighbours, the PC may
## still write, and only the town itself can end the rebellion in M3 — Crown
## troops are M6.
var rebelling: bool = false

## The month it declared, so a letter can say how long it has been out and the
## return event can report it. `-1` while the town is loyal.
var rebelling_since: int = -1

## Months of embargo left to run (SPEC §12.3, #73, #74).
##
## **The Crown's one punishment before it has troops.** Its neighbours are
## forbidden to relieve it, so the rebellion visibly costs something — and the
## suffering that causes is the *Crown's* doing, so it raises the town's own
## sentiment while lowering the argument its rebellion makes to everybody else.
## That tension is the design and not a bug.
var embargo_months: int = 0


## Whether the colony is currently forbidden to help this town.
func is_embargoed() -> bool:
	return embargo_months > 0

## **The sum of its citizens' private wealth plus the town's coffers.** Rises
## selling to the Crown, falls buying from it, and never moves between towns or
## to natives.
var _gold: float = 0.0


func _init(p_id: StringName = &"", p_name: String = "", p_at: Vector2i = Vector2i(-1, -1)) -> void:
	id = p_id
	display_name = p_name if not p_name.is_empty() else String(p_id)
	at = p_at


# --- Population ------------------------------------------------------------

## How many tiles the town can work at once.
func workable_tiles() -> int:
	return workers


func expert_count(resource: StringName) -> int:
	return int(experts.get(String(resource), 0))


func add_experts(resource: StringName, count: int) -> void:
	experts[String(resource)] = expert_count(resource) + count


func livestock_head(kind: StringName) -> int:
	return int(livestock.get(String(kind), 0))


func add_livestock(kind: StringName, head: int) -> void:
	livestock[String(kind)] = maxi(0, livestock_head(kind) + head)


func population() -> int:
	var total := workers
	for resource in experts:
		total += int(experts[resource])
	return total


# --- Stockpile -------------------------------------------------------------

func held(resource: StringName) -> float:
	return float(stockpile.get(String(resource), 0.0))


func store(resource: StringName, amount: float) -> void:
	stockpile[String(resource)] = maxf(0.0, held(resource) + amount)


## Take what is there, up to `amount`. Returns how much was actually taken, so a
## caller never has to check first and act second.
func take(resource: StringName, amount: float) -> float:
	var taken := minf(held(resource), maxf(0.0, amount))
	stockpile[String(resource)] = held(resource) - taken
	return taken


## Resource ids held in any quantity, sorted.
func stocked() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for resource in stockpile:
		if float(stockpile[resource]) > 0.0:
			out.append(String(resource))
	out.sort()
	return out


# --- Gold ------------------------------------------------------------------
#
# Deliberately awkward to read. There is no getter, and the lint bans the field
# name from `presentation/`.

## Money in, from selling to the Crown.
func receive_gold(amount: float) -> void:
	_gold += maxf(0.0, amount)


## Money out, up to what the town has. Returns what it could actually pay, since
## a town that cannot afford a thing simply buys less of it.
func spend_gold(amount: float) -> float:
	var spent := minf(_gold, maxf(0.0, amount))
	_gold -= spent
	return spent


## Whether the town can afford something. A question, not a balance.
func can_afford(amount: float) -> bool:
	return _gold >= amount


## How well off the town is against a target per head, as `0.0` to `1.0`.
##
## **The nearest thing to reading the gold that exists**, and it comes back as a
## judgement rather than a number. Quality of life needs to know whether the town
## can buy what it wants when the ship docks (SPEC §11.3); it does not need the
## balance, and nothing that does not need the balance gets it.
func prosperity(target_per_head: float) -> float:
	var target := target_per_head * maxf(1.0, float(population()))
	if target <= 0.0:
		return 0.0
	return clampf(_gold / target, 0.0, 1.0)


# --- The objective ---------------------------------------------------------

func invested(resource: StringName) -> float:
	return float(objective_invested.get(String(resource), 0.0))


## Move a resource out of the stockpile and into the build. Returns what was
## actually moved, which is what the town had.
func invest(resource: StringName, amount: float) -> float:
	var moved := take(resource, amount)
	if moved > 0.0:
		objective_invested[String(resource)] = invested(resource) + moved
	return moved


## Start again on something else. **Whatever was invested is gone** — the timber
## is already cut and standing in the half-built frame.
func clear_objective() -> void:
	objective = &""
	objective_target = Vector2i(-1, -1)
	objective_intent = &""
	objective_progress = 0
	objective_idle_months = 0
	objective_invested = {}


# --- Buildings -------------------------------------------------------------

func has_building(id_to_find: StringName) -> bool:
	return buildings.has(String(id_to_find))


func add_building(id_to_add: StringName) -> void:
	if not has_building(id_to_add):
		buildings.append(String(id_to_add))


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"at": at,
		"workers": workers,
		"experts": experts.duplicate(),
		"livestock": livestock.duplicate(),
		"stockpile": stockpile.duplicate(),
		"buildings": buildings.duplicate(),
		"quality_of_life": quality_of_life,
		"rebel_sentiment": rebel_sentiment,
		"growth_accrued": growth_accrued,
		"traded_value": traded_value,
		"last_completed": String(last_completed),
		"last_completed_month": last_completed_month,
		"intent": String(intent),
		"intent_since": intent_since,
		"urged_intent": String(urged_intent),
		"urged_month": urged_month,
		"objective": String(objective),
		"objective_target": objective_target,
		"objective_intent": String(objective_intent),
		"objective_since": objective_since,
		"objective_idle_months": objective_idle_months,
		"objective_progress": objective_progress,
		"objective_invested": objective_invested.duplicate(),
		"months_hungry": months_hungry,
		"relief_balance": relief_balance,
		"governor": String(governor_id),
		"rebelling": rebelling,
		"rebelling_since": rebelling_since,
		"embargo_months": embargo_months,
		"gold": _gold,
	}


static func from_dict(data: Dictionary) -> Town:
	var town := Town.new(
		StringName(data.get("id", "")),
		String(data.get("name", "")),
		data.get("at", Vector2i(-1, -1)),
	)
	town.workers = int(data.get("workers", 0))
	town.experts = data.get("experts", {}).duplicate()
	town.livestock = data.get("livestock", {}).duplicate()
	town.stockpile = data.get("stockpile", {}).duplicate()
	town.buildings = PackedStringArray(data.get("buildings", []))
	town.quality_of_life = float(data.get("quality_of_life", 0.0))
	town.rebelling = bool(data.get("rebelling", false))
	town.rebelling_since = int(data.get("rebelling_since", -1))
	town.embargo_months = int(data.get("embargo_months", 0))
	town.rebel_sentiment = float(data.get("rebel_sentiment", 0.0))
	town.growth_accrued = float(data.get("growth_accrued", 0.0))
	town.traded_value = float(data.get("traded_value", 0.0))
	town.last_completed = StringName(data.get("last_completed", ""))
	town.last_completed_month = int(data.get("last_completed_month", -1))
	town.intent = StringName(data.get("intent", ""))
	town.intent_since = int(data.get("intent_since", 0))
	town.urged_intent = StringName(data.get("urged_intent", ""))
	town.urged_month = int(data.get("urged_month", 0))
	town.objective = StringName(data.get("objective", ""))
	town.objective_target = data.get("objective_target", Vector2i(-1, -1))
	town.objective_intent = StringName(data.get("objective_intent", ""))
	town.objective_since = int(data.get("objective_since", 0))
	town.objective_idle_months = int(data.get("objective_idle_months", 0))
	town.objective_progress = int(data.get("objective_progress", 0))
	town.objective_invested = data.get("objective_invested", {}).duplicate()
	town.months_hungry = int(data.get("months_hungry", 0))
	town.relief_balance = float(data.get("relief_balance", 0.0))
	town.governor_id = StringName(data.get("governor", ""))
	town.rebelling = bool(data.get("rebelling", false))
	town._gold = float(data.get("gold", 0.0))
	return town
