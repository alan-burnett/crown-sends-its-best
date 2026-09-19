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

## Rising sentiment is M3; the field exists so the town is whole.
var rebel_sentiment: float = 0.0

## What the town is working towards. The Governor chooses it (#53).
var objective: StringName = &""
var objective_progress: int = 0

## The contact who speaks for it (#52).
var governor_id: StringName = &""

## Whether it still obeys the Crown (SPEC §12.3). Rebellion is M6.
var rebelling: bool = false

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
		"objective": String(objective),
		"objective_progress": objective_progress,
		"governor": String(governor_id),
		"rebelling": rebelling,
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
	town.rebel_sentiment = float(data.get("rebel_sentiment", 0.0))
	town.objective = StringName(data.get("objective", ""))
	town.objective_progress = int(data.get("objective_progress", 0))
	town.governor_id = StringName(data.get("governor", ""))
	town.rebelling = bool(data.get("rebelling", false))
	town._gold = float(data.get("gold", 0.0))
	return town
