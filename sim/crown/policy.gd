class_name Policy
extends RefCounted

## How the Crown puts its thumb on the scale
## (#80, SPEC §11.3, §9.4, §12.5; `docs/mechanics/policy.md`).
##
## The world runs on people acting in their own interests. Governors serve their
## towns, officers serve the Crown, tribes serve themselves, and none of them is
## much interested in what suits the PC. A policy does not change anybody's
## nature — **it changes the arithmetic**, and more of them come.
##
## ## 🔒 What separates it from an intent
##
## Both persist, so the line is drawn somewhere precise:
##
## > **A policy has an ongoing cost that somebody pays every month.**
##
## Urging a governor's intent changes a standing goal and costs nothing
## thereafter. A policy bills somebody for as long as it stands, and **who bears
## that bill is the whole of the mechanic**.
##
## It is not an objective either. SPEC §8.5 locks that the PC cannot name a
## project, and a policy names none — it is a rule the recipient follows until
## told otherwise.
##
## **Tax rates are technically policy and are deliberately kept separate.** They
## have their own machinery in SPEC §10.2 and nothing here applies to them.
##
## ## 🔒 Paying less never weakens it
##
## The policy does exactly what it does; the shortfall is borne by the enactor,
## in loyalty, every month. **Underpaying is not a value-for-money calculation,
## it is a decision about a relationship** — the PC is asking a man to carry
## something for him indefinitely, and finding out later what that cost.

## What the PC agreed to bear.
const ALL: StringName = &"all"
const HALF: StringName = &"half"
const NONE: StringName = &"none"

const SPLITS: Array[StringName] = [ALL, HALF, NONE]

## What each split leaves the enactor to carry, as a share of the monthly cost.
const UNPAID_SHARE: Dictionary = {
	ALL: 0.0,
	HALF: 0.5,
	NONE: 1.0,
}

## What carrying that share costs him in regard each month.
##
## ## 🔒 Paying nothing costs three times paying half. Not twice.
##
## **People want to feel you are working with them.** A PC who contributes
## something — even plainly not enough — is treated very differently from one who
## contributes nothing and expects the thing done anyway.
##
## This is the cheapest lesson in the game: half is far better than nothing, and
## it costs half. `policy.md` §9 marks the 3× as **design rather than tuning**,
## so it should survive a rebalancing that moves `DRAIN_AT_HALF`.
const DRAIN_AT_HALF: float = 1.1

const DRAIN: Dictionary = {
	ALL: 0.0,
	HALF: DRAIN_AT_HALF,
	NONE: DRAIN_AT_HALF * 3.0,
}

var id: StringName = &""

## The contact who puts his name to it.
var enactor: StringName = &""

## An id into the effect registry, with its own params. **Never logic in data**
## and never a bare flag: §8 is explicit that a policy can reach into the
## economy, the population or the Crown's own opinion of what things are worth.
var effect: StringName = &""
var params: Dictionary = {}

## The monthly charge, for as long as it stands.
var cost: float = 0.0

## How much of that charge the PC agreed to bear.
var split: StringName = ALL

var enacted_month: int = 0

## Set when the Crown stops paying, so the enactor's answer is a renegotiation
## rather than a silent collapse (§5).
var renegotiating: bool = false

## How many months he has carried what the PC did not pay.
##
## **Reset when the PC begins bearing his share**, so a man who has been made
## good starts the count afresh rather than carrying a grudge into an arrangement
## that now suits him.
var carried_months: int = 0

## The month he said he would not carry it further, and the month he stops.
##
## 🔒 **The warning always comes before the ending** — the same principle as the
## Chancellor's deadline in `crown-standing.md`. A cost the player cannot see
## coming is a trap, not a decision.
var warned_month: int = -1
var ends_month: int = -1


## Whether he has said he will not go on.
func is_warning() -> bool:
	return warned_month >= 0


## The PC has begun bearing more of it. Everything resets.
##
## **A lump sum soothes it over** (§4). Everybody loves a bribe, and a letter
## that offers one reads very differently from a letter that merely concedes a
## point — so a payment large enough clears the warning as well as the count.
func made_good(new_split: StringName) -> void:
	split = new_split
	carried_months = 0
	warned_month = -1
	ends_month = -1
	renegotiating = false


func _init(
	p_enactor: StringName = &"",
	p_effect: StringName = &"",
	p_cost: float = 0.0,
	p_split: StringName = ALL,
	p_params: Dictionary = {},
) -> void:
	enactor = p_enactor
	effect = p_effect
	cost = p_cost
	split = p_split
	params = p_params.duplicate(true)


## What the Crown pays towards it this month.
func crown_pays() -> float:
	return cost * (1.0 - float(UNPAID_SHARE.get(split, 1.0)))


## What carrying the rest costs the enactor in regard this month.
func drains() -> float:
	return float(DRAIN.get(split, 0.0))


## Drop to paying nothing, as §5 requires when the Crown's drafts start bouncing.
##
## **Not a silent collapse.** It puts the PC in the same position as if he had
## written to the enactor saying he would now pay nothing — which is a
## renegotiation, and the enactor decides for himself.
func crown_stopped_paying() -> bool:
	if split == NONE:
		return false
	split = NONE
	renegotiating = true
	return true


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"enactor": String(enactor),
		"effect": String(effect),
		"params": params.duplicate(true),
		"cost": cost,
		"split": String(split),
		"enacted_month": enacted_month,
		"renegotiating": renegotiating,
		"carried_months": carried_months,
		"warned_month": warned_month,
		"ends_month": ends_month,
	}


static func from_dict(data: Dictionary) -> Policy:
	var restored := Policy.new(
		StringName(data.get("enactor", "")),
		StringName(data.get("effect", "")),
		float(data.get("cost", 0.0)),
		StringName(data.get("split", ALL)),
		data.get("params", {}),
	)
	restored.id = StringName(data.get("id", ""))
	restored.enacted_month = int(data.get("enacted_month", 0))
	restored.renegotiating = bool(data.get("renegotiating", false))
	restored.carried_months = int(data.get("carried_months", 0))
	restored.warned_month = int(data.get("warned_month", -1))
	restored.ends_month = int(data.get("ends_month", -1))
	return restored
