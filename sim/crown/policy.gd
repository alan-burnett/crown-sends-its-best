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
	return restored
