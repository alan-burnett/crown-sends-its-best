class_name Consideration
extends RefCounted

## Scores one aspect of one candidate.
##
## **Owned by the system that introduces it, not by the AI**
## (`docs/mechanics/deliberation.md` §3). A consideration about native threat
## belongs to the natives system and registers itself against the decision kinds
## it affects.
##
## Standing convention: **a milestone that adds a system ships that system's
## considerations with it.** Adding natives to the world is not complete until
## governors, commanders and the director can all feel them.
##
## Subclasses override `score()`, and `applies_to()` where the consideration is
## only meaningful for some candidates.

## Stable identifier. It is the key an actor's personality weights against and
## the name that appears in the trace, so renaming one silently re-weights every
## actor that mentioned it.
var id: StringName = &""


func _init(p_id: StringName = &"") -> void:
	id = p_id


## Whether this consideration has an opinion about this candidate at all.
##
## Distinct from scoring zero: a consideration that does not apply is left out
## of the trace, while one that scores zero is recorded as having looked and
## found nothing to say.
func applies_to(_candidate: Candidate) -> bool:
	return true


## How good this candidate looks on this one axis, in `[-1.0, +1.0]`.
##
## Normalised so that considerations from different systems stay comparable and
## no system can dominate by choosing a larger scale.
func score(_actor: DeliberationActor, _candidate: Candidate, _context: DeliberationContext) -> float:
	return 0.0


## Clamp to the contract. The kernel calls this rather than `score()` directly,
## so a consideration that returns 40.0 is corrected and reported instead of
## quietly swamping every other consideration in the sum.
func scored(actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
	var raw := score(actor, candidate, context)
	if raw < -1.0 or raw > 1.0:
		push_error("Consideration '%s' scored %f, outside [-1, 1]. Clamped." % [id, raw])
	return clampf(raw, -1.0, 1.0)
