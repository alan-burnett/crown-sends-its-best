class_name Candidate
extends RefCounted

## One option an actor is weighing.
##
## The `id` is what the trace names and what ties break on, so it has to be
## stable for a given decision rather than generated per call.
##
## `data` carries whatever the considerations for this decision kind need to
## score it — a target tile, a resource and amount, a compliance outcome. The
## kernel never looks inside it.

var id: StringName = &""
var data: Dictionary = {}


func _init(p_id: StringName = &"", p_data: Dictionary = {}) -> void:
	id = p_id
	data = p_data


func get_value(key: String, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)


func to_dict() -> Dictionary:
	return {"id": String(id), "data": data.duplicate(true)}


static func from_dict(source: Dictionary) -> Candidate:
	return Candidate.new(StringName(source.get("id", "")), source.get("data", {}))


func _to_string() -> String:
	return "Candidate(%s)" % id
