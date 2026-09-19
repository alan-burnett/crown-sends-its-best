class_name Decision
extends RefCounted

## The chosen candidate **and the scoring trace**.
##
## The trace is not optional (`docs/mechanics/deliberation.md` §6). It pays three
## times:
##
## 1. **Balance harness.** Aggregated across N seeds, traces show which
##    considerations actually drive behaviour and which never matter.
## 2. **Playtest debugging.** Utility scoring is opaque without it.
## 3. **Letter motive, free.** When a governor writes "I have set the men to the
##    palisade," the reason in the prose is the reason in the trace. A letter can
##    never misrepresent why something was done, which is what SPEC §9.1 needs.

const NO_SCORE: float = -INF

var kind: StringName = &""
var actor_id: StringName = &""

## The winner, or null when every candidate was filtered out.
var chosen: Candidate = null

## One entry per candidate, in the order they were scored. Each is either
## `{id, total, considerations: [{id, raw, weight, weighted}]}` or
## `{id, filtered_by}`.
var entries: Array[Dictionary] = []


func _init(p_kind: StringName = &"", p_actor_id: StringName = &"") -> void:
	kind = p_kind
	actor_id = p_actor_id


func has_choice() -> bool:
	return chosen != null


func chosen_id() -> StringName:
	return chosen.id if chosen != null else &""


func total_for(candidate_id: StringName) -> float:
	for entry in entries:
		if StringName(entry.get("id", "")) == candidate_id:
			return float(entry.get("total", NO_SCORE))
	return NO_SCORE


## Which filter removed a candidate, or "" if it was scored.
##
## The trace records that a candidate was **filtered rather than scored low**,
## because "he was never going to do that" and "he nearly did that" are
## different facts about the same actor.
func filtered_by(candidate_id: StringName) -> StringName:
	for entry in entries:
		if StringName(entry.get("id", "")) == candidate_id:
			return StringName(entry.get("filtered_by", ""))
	return &""


func was_filtered(candidate_id: StringName) -> bool:
	return not filtered_by(candidate_id).is_empty()


## The structured trace, for the event log and the balance harness.
func to_dict() -> Dictionary:
	return {
		"kind": String(kind),
		"actor": String(actor_id),
		"chosen": String(chosen_id()),
		"candidates": entries.duplicate(true),
	}


## The readable form, for playtest debugging only.
##
## **Never put this in an event payload.** Events carry structure, not prose
## (SPEC §9.7): the words a player reads come from data files, per language.
func format() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s -> %s" % [actor_id, chosen_id() if has_choice() else "(nothing)"])
	for entry in entries:
		if entry.has("filtered_by"):
			lines.append("  %-16s filtered by %s" % [entry["id"], entry["filtered_by"]])
			continue
		lines.append("  %-16s total %+.2f" % [entry["id"], entry["total"]])
		for scored in entry["considerations"]:
			lines.append("    %-14s %+.2f x %.2f = %+.2f" % [
				scored["id"], scored["raw"], scored["weight"], scored["weighted"],
			])
	return "\n".join(lines)
