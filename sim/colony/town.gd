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

## Buildings the town could not pay the upkeep on this month (#151).
##
## **They still stand.** Not lost, not damaged, not demolished — idle, and lit
## again the month the town can afford them. Written by `Upkeep` before the
## month's phases begin and read by every one of `Building`'s effect readers, so
## a dark mill cannot yield while the governor writes home to say it has stopped.
var dark_buildings: PackedStringArray = PackedStringArray()

## **Stored, and updated only in Settle.** A reader that recomputed it would get
## a different answer halfway through a month, and two readers would disagree.
var quality_of_life: float = 0.0

## What the town has worth teaching (#168, `the-provost.md` §3).
##
## **Stored and updated in Settle**, for the same reason quality of life is. It
## does exactly one thing: it sets how likely growth is to arrive as an expert
## rather than a worker.
var education: float = 0.0

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

## Settlers owed but not yet landed, and scholars among them (#170).
##
## **Arrivals are fractional and the remainder is kept.** A town's figure is
## something like `+4.5 workers and +0.1 experts` a month; the workers land and
## the fraction waits, so a town that draws a tenth of a scholar a month gets one
## in the tenth month rather than never.
var arrivals_accrued: float = 0.0
var experts_accrued: float = 0.0

## Births owed but not yet born.
##
## **Natural growth starts slowly and snowballs** (SPEC §12.1), which for a town
## of twelve means a fraction of a person a month. Carrying the fraction is what
## stops a small town growing not at all while a large one grows smoothly.
var growth_accrued: float = 0.0

## Resources this town will not deal in with the Crown (#75), sorted.
##
## **Scoped to this town and these resources.** A rate is colony-wide and a
## refusal is not: raising the duty on furs can shut every coastal town at once,
## and each of them decided it for itself.
var protests: Array = []

## Calves owed but not yet born, by livestock kind (#172).
##
## The herds carry their own remainder for the same reason people do: two cows
## breeding at two percent a month is a calf every two years, and a figure that
## rounded to nothing each month would give a small herd no future at all.
var livestock_accrued: Dictionary = {}

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

## What the governor decided this expedition would carry (#175).
##
## **Written when he takes the objective and not recomputed.** The target is his
## answer to "what can we spare" on the day he decided; letting it move with the
## stores would mean a town that had a good month could never finish gathering,
## because the bar would rise with every harvest.
var objective_cargo: Dictionary = {}

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
	# 🔒 **Every town has a town hall from the moment it is founded** (#152). It
	# is not built, not chosen and not optional: it is what defines the terms of
	# every conversion the town can perform, so a town without one could process
	# nothing at all. Here rather than in a founding routine, because a town made
	# any other way — a test fixture, a scenario — has to have one too.
	buildings.append(String(Building.BASE))


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
	return workers + expert_total()


## Everybody in the town who is expert in something.
func expert_total() -> int:
	var total := 0
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


## Hand over a share of the purse, and say how much it was (#175).
##
## **A share rather than a figure**, because the caller must not be able to read
## the balance to work one out — the whole point of `_gold` having no getter is
## that nothing outside the town knows what it holds. A fifth of the people leave
## with a fifth of the coin, and the town is the only thing that needs to know
## what a fifth is.
func spend_share(fraction: float) -> float:
	return spend_gold(_gold * clampf(fraction, 0.0, 1.0))


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
	objective_cargo = {}


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
		"dark_buildings": dark_buildings.duplicate(),
		"quality_of_life": quality_of_life,
		"education": education,
		"arrivals_accrued": arrivals_accrued,
		"experts_accrued": experts_accrued,
		"rebel_sentiment": rebel_sentiment,
		"growth_accrued": growth_accrued,
		"livestock_accrued": livestock_accrued.duplicate(),
		"protests": protests.duplicate(),
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
		"objective_cargo": objective_cargo.duplicate(),
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
	town.dark_buildings = PackedStringArray(data.get("dark_buildings", []))
	town.quality_of_life = float(data.get("quality_of_life", 0.0))
	town.education = float(data.get("education", 0.0))
	town.arrivals_accrued = float(data.get("arrivals_accrued", 0.0))
	town.experts_accrued = float(data.get("experts_accrued", 0.0))
	town.rebelling = bool(data.get("rebelling", false))
	town.rebelling_since = int(data.get("rebelling_since", -1))
	town.embargo_months = int(data.get("embargo_months", 0))
	town.rebel_sentiment = float(data.get("rebel_sentiment", 0.0))
	town.growth_accrued = float(data.get("growth_accrued", 0.0))
	town.livestock_accrued = data.get("livestock_accrued", {}).duplicate()
	town.protests = data.get("protests", []).duplicate()
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
	town.objective_cargo = data.get("objective_cargo", {}).duplicate()
	town.months_hungry = int(data.get("months_hungry", 0))
	town.relief_balance = float(data.get("relief_balance", 0.0))
	town.governor_id = StringName(data.get("governor", ""))
	town.rebelling = bool(data.get("rebelling", false))
	town._gold = float(data.get("gold", 0.0))
	return town
