# Mechanics — Rival Pressure

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.4, §12.4, §14.1, §10.2, §11.2, and the Squeeze pillar.

---

## 1. A duke is an ordinary contact with his values inverted

**Almost nothing here is new machinery.** A rival duke has a name, a personality
and a **loyalty** like every other contact, moved by the same deeds through the
same path. What differs is only what he `cares_about`.

> **They want the PC paying and weak.**

| Moves his loyalty | Direction |
| :--- | :--- |
| The colony prospering | **down** |
| The PC refusing tribute | **down** |
| The PC paying tribute | **up** |

`GRANTED`, `REFUSED`, `DELIVERED` and `PROMISE_BROKEN` already carry the weights.
A duke needs no new deed and no second scalar.

### Which makes loyalty a protection racket, and the game never says so

The word doing double duty — a governor's regard and a duke's satisfaction with
his cut — is the joke, and it costs nothing to make because loyalty is one number
read differently by role.

**A "loyal" rival is not a friend. He is a man who is being paid.**

## 2. Prospering is what he can see

Prosperity here means **towns, population and territory** — what a duke observes
from across a border.

**It is not net gold.** The Crown's ledger is the Crown's, and a rival has no
sight of it. That distinction matters beyond flavour: if rival aggression read
net position, the same number would drive Crown Standing, prestige *and* the
rivals, and the player would be punished three ways for the single thing the
Crown demands of him. Prosperity and profit are different quantities and the
rivals watch only the first.

So a wide, populous colony draws rivals down whether or not it ever turned a
penny — and a small, ruthlessly profitable one is left comparatively alone.

## 3. The four bands

| Loyalty | What he does |
| :--- | :--- |
| **High** | Asks **reasonable** tribute. A missed payment costs loyalty, and he lets it go |
| **Medium** | Asks **dearer** tribute, and is far less forgiving of a missed payment |
| **Low** | **Attacks improvements.** Parks ships and soldiers on the colony's tiles so they cannot be worked. May strike expeditions and units |
| **Minimum** | Open war on towns and units, freely, **and there is no way back** |

Bands are read from the one loyalty value, exactly as `crown-standing.md` reads
its four stages from standing. No second state machine.

### 🔒 Minimum is a latch

Once a duke reaches the bottom he is **there for the run**, whatever his loyalty
does afterwards. Paying him no longer helps; there is nothing left to buy.

This is the same shape `natives.md` gives a tribe that has come to believe it is
to be eradicated, and the two docs mean it the same way: **a point of no return
that the player can see coming and cannot reverse.** Everything above it is
recoverable, which is what makes crossing it matter.

## 4. Paying works, and it is the most expensive thing in the game

Appeasement is **genuinely effective**. Paying raises loyalty, which keeps the
duke in the band where his demands are cheap and his patience is long. A player
who pays promptly can hold a rival at High for decades.

It also costs twice, and both costs are permanent:

- **The gold leaves `net_position`**, which lowers Crown Standing *and* prestige
  together (`prestige.md` §3).
- **Tribute is an optic** (§14.1). A fixed, undecaying debt against the PC's
  score, on top of the money.

> A PC can be solvent, meeting every Crown demand, and still despised at court
> for having paid a foreigner to leave him alone.

So **the safest course for the colony is the ruinous one for the score.** The man
who buys forty years of peace retires a pauper in the Crown's eyes, and the man
who refuses keeps his reputation and may lose his towns. That is the Squeeze
arriving from a direction the Crown's own demands cannot reach.

**This is why tribute is not dead content.** The obvious reading of §8.4 —
*accepting defers attack but never buys peace* — suggests never paying. The bands
are what make paying a real strategy rather than a trap, and the double cost is
what stops it being the only one.

## 5. Tile denial

**The low band's signature, and the one genuinely new mechanic here.**

A duke parks ships and soldiers on tiles inside a town's influence area (§11.2).
Those tiles **cannot be worked** — Work simply has no hands to assign to them —
and the town's yields fall accordingly.

It is not combat. Nothing is destroyed, nobody dies, **no defeat is scored**, and
so no optics debt is incurred. The colony is merely poorer, month after month,
for as long as he sits there.

Three things make it the right mechanic for this band:

- **It is visible.** The player watches it happen on the map and knows exactly
  which tiles and which town. §11.2's lock that the map shows only what the
  colony knows is satisfied — soldiers on your own doorstep are not a secret.
- **It is proportionate.** A duke short of open war can hurt the colony
  materially without the escalation that open war implies, which is what the
  spread between Low and Minimum needs in order to mean anything.
- **The only instrument is a letter with money in it.** The PC cannot order it
  cleared; he can raise the duke's loyalty until he leaves. That is the Rule by
  Correspondence pillar with nothing else to hide behind.

It also lands somewhere nothing else has touched: **the Work phase's tile list**,
rather than population or stockpiles. A town under denial is not being hurt, it
is being *diminished*, and its governor's letters should read differently for it.

## 6. Spawning is the Squeeze's decision, not this document's

**Prospering does not attract rivals.** A duke arrives because the run has reached
the point where the Squeeze puts a new strain on the player, and *spawning one of
the unspawned rivals and beginning to demand tribute* is one of the strains
available to it.

The three dukes therefore arrive **staggered**, each announced by a first demand,
and the colony faces one, then two, then three over a run. That gives §12.4's
"pressure grows as a run goes on" a mechanism, and it stops year two arriving as
three simultaneous demands.

### The schedule is not defined here

**Which strain the Squeeze imposes, and when, is a larger mechanism than this
document.** `crown-demands.md` implements one slice of it — the annual draw over
four dimensions of demand growth, using the bucket pattern of its §7 — and rival
spawning is a second slice. The director that chooses among them is not yet
written, and this doc deliberately does not invent it.

What this doc fixes is the **consequence**: when the Squeeze spawns a duke, he
arrives at a starting loyalty, opens with a tribute demand, and from then on
behaves as §3 describes. A dev implementing rivals does not need the schedule to
build any of that.

## 7. Misleading about intentions is prose

§8.4 says rivals mislead the PC about their intentions. **This needs no mechanic.**

SPEC §9.1 already permits it: a letter never lies about what has *happened*, but a
statement of intent is not a statement of fact, and any contact may say a thing
and reconsider. A duke writing *"after this payment we shall have no reason to
ask again"* is telling the truth about his present disposition and nothing else.

An experienced player knows it is worthless. **A new player learning that it is
worthless is the lesson**, and it is taught entirely in prose. Nothing in the sim
needs a truthfulness dial, and nothing should acquire one.

## 8. What a rival never does

SPEC §8.4 is unusually prescriptive, and these are locks rather than defaults:

- **Never asks for help** against another rival or against the natives.
- **Never offers his own resources.** There is no trade with a rival, ever.
- **Never becomes peaceful or mutually beneficial**, at any loyalty. High loyalty
  is a cheap racket, not an alliance.
- **One duke per rival**, and he is the PC's only contact with that empire.

A dev who finds himself writing a rival offer, a rival alliance, or a second
rival contact has left the spec.

### They do court rebel towns

§12.3: a rebel town handles its own diplomacy, **rivals can court it**, and a
rival or a tribe taking it turns it into a **lost town**. That is a rival
behaviour, it belongs to the rebellion machinery rather than to tribute, and it
is the one route by which a duke gains from the PC's failure without fighting him
for it.

## 9. Tuning targets

- Starting loyalty on spawn, and the band boundaries.
- How fast prosperity drags loyalty down, against how much a payment lifts it —
  the ratio is the whole of whether appeasement is affordable.
- Tribute size per band, and how it grows (`crown-demands.md` §6).
- How many tiles a duke can deny, and for how long.
- The tribute optic's gold-equivalent, which is #187's to set against every other
  optic rather than here.

## 10. Open items

- **The Squeeze director itself.** Which strains exist, how one is chosen, and
  how rival spawning sits beside `crown-demands.md`'s annual growth draw. The
  largest unwritten thing this doc leans on.
- Whether a duke's demands should ever be **resources** rather than gold, as the
  Marshal's are. §8.4 says they bully the PC into giving them *resources*, which
  reads like they should.
- Whether the PC can play dukes against one another. §8.4 forbids them asking for
  help against each other, but says nothing about the PC volunteering it.
- What a duke does when the colony is plainly dying. Continuing to demand tribute
  from a PC with two starving towns is comic, but it may simply be dull.
