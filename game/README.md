# game/ — the run

What drives the sim and the correspondence layer, and is driven by presentation.

**Why this is not one of the three layers.** A run is both at once: the world is
the sim's, the contacts and the post are the correspondence layer's, and the turn
loop orchestrates them. It belongs to neither, and putting it in `correspondence/`
would have made the letter layer own the save format. Recorded as an assumption
on #6 and #7.

| Path | What it is |
| :--- | :--- |
| `run_state.gd` | Everything one run is, in one serialisable object |
| `save_game.gd` | Ironman saving: one save per run, version stamped |
| `turn_machine.gd` | SPEC §7's seven steps, headless |

## Ironman

**One save per run, and no loading of earlier states** (SPEC §16.2). A full state
snapshot, not seed-and-replay — a replay that diverged by one draw would silently
produce a different colony.

The save is **Godot variant bytes, not JSON**. JSON has no integer type, so a
round trip through it turns every `4` into `4.0`, which changes the state hash
without changing the state. JSON stays where it belongs, on hand-authored content
in `data/`.

The save is taken **after** the resolution, so killing the process the instant the
post goes loses nothing: the saved state is the start of the next turn.

A save from an older version is **refused, not migrated**, for as long as the
game is in development.

## Two clocks

A **Turn** is the player's unit; a **World Month** is the simulation's. They are
not the same index. The desk sits between the month just reported and the month
about to run, so a dev counting "the current month" from the desk is off by one.
See `docs/mechanics/world-month.md` §3.
