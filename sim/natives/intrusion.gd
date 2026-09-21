class_name Intrusion
extends RefCounted

## How far into somebody else's country a tile sits (#204, SPEC §11.4;
## `docs/mechanics/natives.md` §3).
##
## SPEC §11.4: founding near or beyond native land offends the nearby tribes **in
## proportion to the intrusion**. This is that proportion, and it is one number
## so that every system which needs it — the governor's site preference, the
## founding penalty, the exploitation of worked land — is reading the same
## measure rather than three that drift apart.
##
## ## It does not stop at their border
##
## **Near counts too.** A town built one field short of a village's land is not
## innocent; it is a town they will be looking at every morning. So the figure
## falls away over a margin beyond the influence area rather than to nothing at
## the edge of it, and the cliff the spec would otherwise imply — offensive here,
## perfectly fine one tile further out — never exists.
##
## ## What it is not
##
## 🔒 **It says how deep, never who wins.** `natives.md` §10 leaves what happens
## where a village's influence meets a town's to the Author, and a function that
## answered that would be answering it everywhere at once.

## How far past a village's own land the offence still reaches, in tiles.
##
## Tuning, but the fact that it is more than nought is not: without it, "near
## their land" in SPEC §11.4 has no meaning in the code.
const MARGIN: int = 3

## What is left of the offence at the edge of their own land, before the margin
## begins carrying it the rest of the way down. Tuning.
const AT_THE_BORDER: float = 0.6


## How deep into a tribe's country this tile is, and whose.
##
## Returns `{"tribe": id, "depth": 0..1}`, or an empty tribe and nought where
## nobody would mind. **The deepest claim wins** when two peoples' land overlaps,
## because the question being asked is how badly this offends anybody at all.
static func at(tile: Vector2i, natives: Tribes) -> Dictionary:
	var worst := {"tribe": &"", "depth": 0.0}
	if natives == null:
		return worst
	for village in natives.villages_in_order():
		var depth := into(tile, village as Village)
		if depth > float(worst["depth"]) + 0.0001:
			worst = {"tribe": (village as Village).tribe, "depth": depth}
	return worst


## The figure alone, for callers that only want to know how bad it is.
static func depth_at(tile: Vector2i, natives: Tribes) -> float:
	return float(at(tile, natives)["depth"])


## How far into one village's country a tile sits.
##
## Chebyshev, like the influence area itself, so the measure and the ground agree
## about what a ring is.
##
## Public because a caller sometimes needs **one people's** view of a tile rather
## than the worst of everybody's — every tribe near a new town has its own.
static func into(tile: Vector2i, village: Village) -> float:
	var reach := village.influence()
	var away := maxi(absi(tile.x - village.at.x), absi(tile.y - village.at.y))

	if away <= reach:
		# Inside their land. **Deepest at the houses**, because a town on top of
		# a village is not a border dispute.
		var share := float(away) / maxf(1.0, float(reach))
		return 1.0 - (1.0 - AT_THE_BORDER) * share

	if away <= reach + MARGIN:
		# Near it. Falling away over the margin rather than stopping at a line.
		var out := float(away - reach) / float(MARGIN)
		return AT_THE_BORDER * (1.0 - out)

	return 0.0
