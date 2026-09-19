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

func run(_town: Town, _before: ColonySnapshot, _context: ColonyContext) -> void:
	pass
