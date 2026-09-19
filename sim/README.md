# sim/ — the world simulation

Deterministic, headless, **zero Godot nodes**. Plain `RefCounted` classes.
Takes `(state, resolved intents)` and produces `(state', event log)`.

`tools/lint.gd` enforces the no-nodes rule and the layering: `sim/` sits at the
bottom and references nothing above it. The moment a node appears here, the sim
can no longer run in a test or a balance harness.

## Seam A — the sim emits, it does not merely mutate

Every month the sim produces both a full state and an **event log** of what
changed. Map playback, cutscene triggers, letter content and the ledger are all
consumers of that same log.

`WorldState.apply()` takes an `EventLog` as an argument for this reason. A
caller who wants to change a value has to have somewhere to say so. Sim code
that changes state silently desyncs the map from the letters, and SPEC §9.1
makes letters matching the simulation an invariant — that is a correctness bug,
not a polish item.

## Contents

| Path | What it is |
| :--- | :--- |
| `rng/stable_hash.gd` | FNV-1a we own, because the engine's `hash()` is not a stability contract |
| `rng/rng_streams.gd` | Named streams per system, per-contact streams derived lazily |
| `events/sim_event.gd` | One thing that happened, as structured data — never prose |
| `events/event_log.gd` | The ordered record, stable for a given seed |
| `world/world_state.gd` | Full serialisable state, and the state hash |
| `world/world_diff.gd` | What changed between two states |
| `world/world_phase.gd` | The nine World Month phase names, from `docs/mechanics/world-month.md` |
| `serialization/canonical.gd` | One canonical text form, so equal states hash equally |
| `deliberation/` | The one kernel every actor that chooses goes through |
| `intent/` | What an actor committed to, and the executors that carry it out |
| `world/world_month.gd` | The nine phases, run in order |
| `world/stub_world.gd` | M1's stand-in world (#20). M2 replaces this file, not the runner |

## Seam C — will is not a write

Deliberation produces **will**. Will does not change the world. It becomes an
**Intent**, and the simulation executes the Intent over months.

```
player letter -> Order -> compliance --+
                                       +--> Intent -> executed over months -> events
NPC deliberation -> will --------------+
```

"The contact complied" and "the contact acted on his own and informed the PC
afterward" (SPEC §8.5) are the same code path with different origins.

**The timing rule lives on `Intent.committed_month`.** An Intent committed in
month N executes in phase 2 of month N+1, so an executor refuses to advance an
Intent in the month it was committed. On the player's clock: an order written on
turn T is **acknowledged** in turn T+1's letters, and its **physical
consequence** happens during turn T+1's resolution, which the player watches in
turn T+2's map playback. See `docs/mechanics/world-month.md` §3.

That one month of separation is the announce-then-act property, and the reason a
player can never countermand an announced intent.

**Executors are the only thing that writes sim state.** `tools/lint.gd` enforces
the outer half — nothing above `sim/` may call `apply()` at all.

## Deliberation

All six of the spec's decision points go through `Deliberation.choose()`, never a
bespoke `if` chain. Personality is a **weight vector** over considerations, not
code. Rules the spec locks are **filters** applied before scoring, not weights
that could lose a close vote. `choose()` always emits its scoring trace.

**A milestone that adds a system ships that system's considerations with it.**
Adding natives is not complete until governors, commanders and the director can
all feel them.

## Determinism

Same seed plus same decisions must produce an identical state hash, in any
process and on any platform. That means: named streams, never the global RNG;
no iteration over unordered collections where the result depends on order; and
no use of the engine's built-in `hash()`.
