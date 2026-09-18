class_name DeliberationActor
extends RefCounted

## Anything that chooses: a contact, a governor, a commander, a town, a tribe,
## a rival.
##
## **Personality is a weight vector over considerations**
## (`docs/mechanics/deliberation.md` §4), not a tag with special-cased
## behaviour. A cautious governor weights threat highly; a greedy one weights
## revenue highly and quality of life poorly. There is **no new code per
## personality**, which is what SPEC §8 requires when it says personality drives
## behaviour and not merely prose.
##
## This lives in `sim/` so the kernel can stay here while a `Contact` — which
## belongs to the correspondence layer, because loyalty does — extends it.

const DEFAULT_WEIGHT: float = 1.0

var id: StringName = &""

## Consideration id -> weight. A consideration with no entry weighs
## `DEFAULT_WEIGHT`, so adding a consideration does not require revisiting every
## actor already in the game.
var weights: Dictionary = {}


func _init(p_id: StringName = &"", p_weights: Dictionary = {}) -> void:
	id = p_id
	weights = p_weights.duplicate()


func weight_for(consideration_id: StringName) -> float:
	return float(weights.get(String(consideration_id), DEFAULT_WEIGHT))


func set_weight(consideration_id: StringName, weight: float) -> void:
	weights[String(consideration_id)] = weight


## Weighted consideration ids, sorted. Never iterate `weights` directly where
## the result depends on order.
func weighted_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(weights.keys())
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	return {"id": String(id), "weights": weights.duplicate()}


static func from_dict(source: Dictionary) -> DeliberationActor:
	return DeliberationActor.new(StringName(source.get("id", "")), source.get("weights", {}))
