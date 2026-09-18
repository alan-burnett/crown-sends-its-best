# The Crown Sends Its Best — working conventions

A 2D narrative-management roguelike in Godot 4. You rule a colony entirely by
letters, from an ocean away.

**Read [SPEC.md](SPEC.md) before touching anything.** It is the source of truth
for the design. Only the Author edits it.

---

## Roles and rules

| Role | Who | Owns |
| :--- | :--- | :--- |
| Author | Alan | The vision and `SPEC.md` |
| PO | agent | Issues, milestones, `docs/mechanics/**` |
| Dev | agent | Implementation |

- **When the spec and a ticket conflict, the spec wins.** Apply the `author`
  label, comment explaining why, and do not build the conflicting part.
- **Tickets must not settle Open Questions** (SPEC §17). Those go to the Author.
- **Record assumptions** in the pull request or an issue comment.
- `docs/mechanics/**` holds the current draft of numbers and formulas that the
  spec deliberately leaves out. **PO owns these; devs read them, never edit
  them.** If a mechanics doc contradicts the spec, the spec wins.
- Labels: `author` (needs an Author decision), `blocked` (depends on unfinished
  work).

## Terminology

**SPEC §4 is an invariant.** Those words carry those meanings in the spec, the
tickets, the code, and the data files. A concept that needs a name not in §4
goes to the Author.

Watch these in particular:

- **resource**, never "good". Tax rates are *per-resource*.
- **Ledger** is the gold screen (§10.4) and nothing else.
- **Relationship** is the per-contact record of how the PC's rule has landed on
  someone. **Loyalty** (§8.5) is the headline scalar inside it.
- **Post**, **Turn**, **Run**, **Colony**, **Crown** — all as §4 defines them.

## Architecture

Three layers, and two seams that must not be violated.

**1. World sim.** Deterministic, headless, zero Godot nodes. Plain `RefCounted`
classes. Takes `(state, resolved intents)` and produces `(state', event log)`.

**2. Correspondence.** Turns `(state, event diff, relationship)` into letters;
turns player choices into Orders; resolves Orders into sim intents. Owns
promises, loyalty, and letter volume.

**3. Presentation.** Desk, map playback, cutscenes, ledger, summary.

### Seam A — the sim emits, it does not merely mutate

Every month the sim produces both a **full state** and an **event log** of what
changed. Map playback, cutscene triggers, letter content, and the ledger are all
consumers of that same log.

Sim code that changes state without emitting an event desyncs the map from the
letters. SPEC §9.1 makes letters matching the simulation an invariant, so this
is a correctness bug, not a polish item.

### Seam B — Orders are never writes

A player letter **never** touches sim state (SPEC §8.5, §7 "Order of time"). It
creates an Order addressed to a contact. The contact resolves it — comply,
partial, delay, reinterpret, refuse, or act unilaterally — into intents the sim
consumes on the *next* step.

### Determinism

- **Named RNG streams per system** (mapgen, letters, sim resolution, contacts),
  never one global RNG.
- **Per-contact streams** derived lazily as `hash(run_seed, contact_id)`, so the
  same seed yields the same characters regardless of what happens elsewhere.
- No iteration over unordered collections anywhere a result depends on order.
- Same seed plus same decisions must produce an identical state hash.

### Saving

Ironman, one save per run (SPEC §16.2). Full state snapshot, not seed-and-replay.
Version-stamped; during development, refuse to load a save from an older version
rather than migrating it. A separate decision log is kept for bug repro only and
is never used to reconstruct state.

## Content pipeline

Letters are data (SPEC §9.7). Prose lives inline with mechanics; the **folder**
carries the language suffix, so a second language is a copied folder where only
`text` fields change.

```
data/letters_en/<sender>/<letter>.json   prose + reply structure
data/triggers/*.json                     when a letter fires (no prose)
```

- Two engines, kept apart: one decides **whether** a letter is sent and with
  what values, the other decides **how it reads**. `params` is the typed
  contract between them — the file declares, the director supplies.
- Conditions and effects are **ids into a code-side registry** with typed
  params. Never logic in a data file.
- Slot kinds: `{param:x}` exact and truthful, `{perception:x}` biased judgment
  (see `docs/mechanics/perception.md`), `{sender:x}` a whitelisted contact
  field, `{insert:x}` a tone-keyed fragment local to its line.
- **Tones are five distinct values**: `pleased`, `dutiful`, `annoyed`,
  `desperate`, `hateful`. Same enum in both directions. They are **not
  ordered** — no "annoyed or worse" logic anywhere. Prose comes from a default
  or from a specific tone, never from an inferred range.
- The content validator must pass: every id resolves, every effect is
  registered, every tone key is known, no dangling slots, every `{param:}` is
  declared.

## Testing

Tests are a safety net, not a tax. **Write them only where the value is stable
and silent breakage is expensive:**

- Determinism — same seed and decisions produce an identical state hash.
- Save/load round-trip. Ironman means a corrupt save is a lost run.
- Content validation.
- Invariants the spec marks with a lock, such as colony-month phase ordering and
  Orders never writing state.

**Do not write** tests asserting balance numbers, tests on UI, or tests against
anything expected to iterate. A test written against a moving value will be
rejected.

## Platform and presentation

- **Portrait-first.** Mobile is portrait; reply options overlay the bottom of
  the letter. Desktop shows the same portrait letter column with options beside
  it and more of the desk visible.
- Every screen works with touch **and** mouse and keyboard (SPEC §15).
- Text is the main medium and must be comfortable to read at length on a phone.
- All assets load through replaceable references (SPEC §16.3). Placeholders
  during development; swapping in final art must not require code changes.
