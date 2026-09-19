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

## Determinism

Same seed plus same decisions must produce an identical state hash, in any
process and on any platform. That means: named streams, never the global RNG;
no iteration over unordered collections where the result depends on order; and
no use of the engine's built-in `hash()`.
