# correspondence/ — letters, orders, relationships

Turns `(state, event diff, relationship)` into letters; turns player choices
into Orders; resolves Orders into sim intents. Owns promises, loyalty and letter
volume.

Depends on `sim/`. Nothing in `sim/` may depend on this.

## Seam B — Orders are never writes

A player letter **never** touches sim state (SPEC §8.5, §7 "Order of time"). It
creates an **Order** addressed to a contact. The contact resolves it — comply,
partial, delay, reinterpret, refuse, or act unilaterally — into intents the sim
consumes on the *next* step.

## Seam C — will is not a write either

The same rule binds NPCs. A contact, governor or tribe **deliberates** and
produces will; will becomes an **Intent**; the sim executes the Intent over
months.

```
player letter -> Order -> compliance --+
                                       +--> Intent -> executed over months -> events
NPC deliberation -> will --------------+
```

"The contact complied" and "the contact acted on his own and informed the PC
afterward" (§8.5) are therefore the same code path with different origins.

## Contents

| Path | What it is |
| :--- | :--- |
| `tone.gd` | The five tones. **Not ordered** — no "annoyed or worse" anywhere |
| `contacts/contact.gd` | Identity, role, personality weights, perception leans |
| `contacts/relationship.gd` | Where the PC and one contact stand. Loyalty lives here |

**Relationship is not a ledger.** SPEC §4 fixes Ledger as the gold screen and
nothing else.

A `Contact` extends `DeliberationActor`, so personality is the weight vector the
kernel already reads. **No contact has bespoke behavioural code.** Crown Officers
load from data because they are fixed in every run (SPEC §8.1); colony contacts
and patrons generate from their own RNG stream, so the same seed yields the same
person however late in the run he appears.

Still to arrive: #9, #10, #11, #14, #15, #16, #17, #18.
