class_name DeliberationFilter
extends RefCounted

## A hard rule, applied before scoring.
##
## **Anything the spec locks is a filter, never a weight**
## (`docs/mechanics/deliberation.md` §5). SPEC §11.3's locked "needs before
## wants" is a filter: a town that cannot feed itself has plantation-building
## **removed from its candidate set**, not scored down. A weight can lose a
## close vote; a locked rule must not be able to.
##
## It also avoids utility scoring's classic failure, where an actor picks a
## mediocre option because two strong considerations cancelled out.
##
## The trace records which filter removed a candidate, so "he was never going to
## do that" reads differently from "he nearly did that".

var id: StringName = &""


func _init(p_id: StringName = &"") -> void:
	id = p_id


## False removes the candidate from consideration entirely.
func permits(_actor: DeliberationActor, _candidate: Candidate, _context: DeliberationContext) -> bool:
	return true
