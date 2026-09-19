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

Arrives across #4, #5, #9, #10, #11, #12, #14, #15, #16, #17, #18.
