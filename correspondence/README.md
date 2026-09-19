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
| `letters/letter_schema.gd` | The vocabulary of a letter file, shared by validator and renderer |
| `letters/letter.gd` | A parsed letter template |
| `letters/letter_context.gd` | State, diff, sender and params, as a letter sees them |
| `letters/letter_renderer.gd` | Slot resolution and assembly into flowing prose |
| `letters/content_validator.gd` | Checks the whole `data/` tree in one pass |
| `perception/` | A true number becomes a biased word (`docs/mechanics/perception.md`) |
| `registry/` | Conditions and effects as ids with typed params |
| `orders/order.gd` | What a player's letter actually produces |
| `post/inbound_letter.gd` | One letter on the desk, with the values it arrived with |
| `post/outgoing_letter.gd` | A letter written but not yet sent — choices, not Orders |
| `post/post.gd` | The turn's outgoing post, sealed when it goes |

**Relationship is not a ledger.** SPEC §4 fixes Ledger as the gold screen and
nothing else.

A `Contact` extends `DeliberationActor`, so personality is the weight vector the
kernel already reads. **No contact has bespoke behavioural code.** Crown Officers
load from data because they are fixed in every run (SPEC §8.1); colony contacts
and patrons generate from their own RNG stream, so the same seed yields the same
person however late in the run he appears.

## Quantities are exact; judgments are biased

The line SPEC §9.1 draws, and the reason the renderer has two different slot
kinds for numbers and for opinions. A number goes through `{param:}` and arrives
untouched. A judgment goes through `{perception:}` and is shaded by the sender's
lean, capped at one rung from the truth so two senders can never flatly
contradict each other. Neither can be routed through the other.

## Two engines, kept apart

One decides **whether** a letter is sent and with what values
(`data/triggers/`, #14). The other decides **how it reads**
(`data/letters_en/`). `params` is the typed contract between them: the file
declares, the director supplies.

Still to arrive: #14, #15, #16, #17, #18, #19.
