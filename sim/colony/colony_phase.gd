class_name ColonyPhase
extends RefCounted

## One phase of the colony month, for one town.
##
## A handler **reads the snapshot and writes the town**. That split is the whole
## of the locked ordering: what it sees is the colony as the phase began, what it
## changes is its own town, and so the order towns run in cannot matter.
##
## Each of the eight has its own ticket (#44 to #50). A phase with no handler
## still happens and still emits — the order is observable before the work is.

## Set by `claim_month` for phases that are not really per-town.
var _month_claimed: int = -1


func run(_town: Town, _before: ColonySnapshot, _context: ColonyContext) -> void:
	pass


## True for the first town of the month, false for every town after it.
##
## **Some phases are the colony's, not a town's.** Relief matches givers against
## receivers across the whole colony; running it once per town would have the
## second town re-solve a problem the first already solved. Such a phase does its
## work under this guard, on the first call, from the snapshot — which keeps the
## locked ordering intact, since the snapshot is the same either way.
func claim_month(context: ColonyContext) -> bool:
	if _month_claimed == context.state.month:
		return false
	_month_claimed = context.state.month
	return true
