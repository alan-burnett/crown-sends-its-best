# Cutscenes

> **Serves:** SPEC §15 (the Cutscene screen), §6.1 (a run opens with one),
> §13 (endings), §9.7 (content pipeline), §16.3 (replaceable assets).
> **Companion:** `beats.md`, which owns animation and sound everywhere else.

---

## 1. 🔒 A cutscene is a painting and a line of text

*Meeting the natives.* *Colony holds trade protest.*

A large still image, a short caption, and **advance** as the only input (§15).
Some cutscenes carry several images with several captions and advance cycles
them; most carry one.

**Nothing in a cutscene moves.** The map is the animated screen. This is the
painting you are shown about it, and that is the whole of it — no queue, no
beats, no fast-forward, none of `beats.md`'s machinery. It has music, which is a
bed, and a sound on each panel change.

This is a deliberate narrowing. A cutscene that animated would need everything
the map needs, for a screen with no information on it.

### The shape

```
id       StringName    the cutscene
panels   [ { image, text } ]    one or more, advanced in order
trigger  registry id + params   when it fires
kind     bookend | first | recurring
```

**One image per panel and one caption per panel.** A panel with two captions is
two panels; a caption with no image is not a cutscene.

---

## 2. Three kinds, and only two of them compete

| Kind | Fires | Example |
| :--- | :--- | :--- |
| **Bookend** | scripted — run start and run end | *Your Appointment*, *Independence* |
| **First** | the first time ever in this run | *Meeting the Natives* |
| **Recurring** | the first time **each turn** | *Colony Holds Trade Protest* |

**Bookends are exempt from everything below.** A run opens with one (§6.1) and
ends with one (§13); neither competes with anything, because nothing else is
happening in those turns.

### 🔒 The trigger source is the event log, and the desk is in it

Not every cutscene is about the world. **A governor refusing, a contact acting
without asking, the Marshal pulling troops back — those happen on the desk**, and
they deserve a painting as much as a battle does.

They need no new machinery, because the correspondence layer already emits into
the same log the sim does: `compliance.gd` logs all six outcomes —
`order_refused` and `contact_acted_alone` among them — and the director logs what
it dispatched, culled and ignored.

**So there is one trigger source, not two.** `CLAUDE.md`'s Seam A is written
about the sim emitting; it is worth saying plainly here that correspondence
emits too, because a reader who assumed otherwise would build a second
mechanism for half this catalog.

---

## 3. As many as the month earned, in the order they happened

A turn shows **every cutscene it triggered**, one after another, ordered by event
`seq` — which is the order they happened inside the month, and the same order the
map has just played them in.

**Nothing waits, nothing expires, nothing is dropped.** There is no budget.

### 🔒 The catalog is the discipline, not a budget

An earlier draft capped this at one a turn and deferred the rest. Simulating
twelve turns showed the cap was solving a problem the catalog already solves.

**Almost every cutscene here is a first**, and a first can fire once in a run. So
the ceiling is the catalog's own length, and the shape falls out on its own: the
early run is busy because the early run is when things happen for the first time,
and it thins out because it has run out of firsts, not because anything throttled
it.

**What keeps this from being a slideshow is §7** — refusing the slot to anything
that happens most months. A budget was a second mechanism doing the same job
worse, and it was doing real damage: it made *Landfall* lose its own month.

### A recurrence is still once a turn

*The first trade protest of each turn* is one painting, however many towns
protest. That is what makes it a recurrence rather than an event.

**And a recurrence never fires in the turn its first counterpart did** — *The
First Blood* and *Shots Exchanged* are the same event seen twice.

### What this actually produces

Measured over the first twelve turns, three seeds, with the month-1 rival bug
(#300) set aside:

| Turn | Shown |
| :--- | :--- |
| m0 | *Your Appointment* |
| m1 | *Landfall*, then the desk firsts the player's own post earned |
| m2 | *New Arrivals* |
| m3–4 | *The First Works* |
| m9 | *The Colony Grows* |
| m10 | *A Man Who Knows His Trade* |
| m7, m8, m11, m12 | nothing |

**Month 1 is the busiest turn in the run** and everything after it is sparse.
That is the correct shape for a game about a colony being founded, and it is the
shape a budget destroyed by spreading month one across six.

## 4. After the playback, before the desk

The order of a turn's opening is **map playback, then the turn's cutscenes, then
the desk.**

The paintings are punctuation on the month, not title cards for it. Shown first,
*Meeting the Natives* tells the player what the map is about to play; shown
after, they are what he is left holding when he sits down to answer his post.

---

## 5. The data, and the two engines kept apart

Same pipeline as letters (`CLAUDE.md`, SPEC §9.7), for the same reasons.

```
data/cutscenes_en/<id>.json    panels: image ref + caption text
data/triggers/*.json           when it fires (no prose)
```

- **The folder carries the language**, so a second language is a copied folder
  where only `text` changes.
- **Triggers are ids into a code-side registry** with typed params. Never logic
  in a data file.
- **Images are replaceable references** (§16.3), never paths. Placeholder art
  through M8; the swap-in must need no code change.
- The content validator covers cutscenes: every trigger id resolves, every image
  ref exists, every cutscene has at least one panel, every panel has both fields.

---

## 6. The catalog

**Candidates, not a commitment.** Every row is an image that somebody has to
paint, so this is a list for the Author to cut rather than a list to build. Panel
counts are suggestions.

### Bookends

| Caption | Fires | Panels | Owns the moment |
| :--- | :--- | :--: | :--- |
| **Your Appointment** | run start, always | 3 — the court, the commission, the ship | SPEC §6.1 |
| **The Colony is Overrun** | run end, Overrun | 2 | `endings.md` §1 |
| **Independence** | run end, Independence | 2 | `endings.md` §1 |
| **You Retire** | run end, Retirement | 1 | SPEC §13.2 |

**Overrun needs variants.** SPEC §13.1: *the ending names who overran it.* At
minimum natives and rivals are different paintings.

### Firsts of the run — from the world

| Caption | Fires on the first | Panels | Owns the moment |
| :--- | :--- | :--: | :--- |
| **Landfall** | town founded | 2 | `map.md` §5 |
| **Meeting the Natives** | contact with any tribe | 1 | `natives.md` |
| **The First Works** | building completed | 1 | `buildings.md` |
| **A Man Who Knows His Trade** | expert produced | 1 | `the-provost.md` §4 |
| **New Arrivals** | immigrant ship | 1 | `immigration.md` |
| **Into the Interior** | expedition sets out | 1 | `founding-towns.md` §7 |
| **A Second Town** | town founded by expedition | 1 | `founding-towns.md` |
| **A Friend at Court** | patron writes | 1 | `patrons.md` |
| **The Church is Raised** | clergyman arrives | 1 | `institutional-contacts.md` |
| **The Quartermaster** | quartermaster arrives | 1 | `institutional-contacts.md` |
| **The Press** | journalist arrives | 1 | `institutional-contacts.md` |
| **The Scholar** | scholar arrives | 1 | `institutional-contacts.md` |
| **A Neighbour Declares Himself** | rival duke appears | 1 | `rival-pressure.md` §6 |
| **The Duke's Price** | tribute demanded | 1 | `rival-pressure.md` |
| **Under Arms** | company raised | 1 | `commanders.md` |
| **The First Blood** | battle fought | 2 | `battles.md` |
| **A Town is Lost** | town destroyed or taken | 1 | `battles.md` |
| **They Came at Dawn** | native raid | 1 | `natives.md` |
| **An Agreement** | trade agreement with a tribe | 1 | `natives.md` |
| **Beyond Reconciling** | tribe passes the point of no return | 1 | `natives.md` |
| **The Hungry Month** | town loses someone to hunger | 1 | `quality-of-life.md` |
| **A Town Refuses** | town declares rebellion | 1 | `rebel-sentiment.md` |
| **The Chancellor Writes** | formal last-chance warning | 1 | `endings.md` §2 |
| **The Colony Grows** | town that grows of its own accord | 1 | SPEC §12.1 |
| **The Land Improved** | improvement built | 1 | `tiles-and-improvements.md` |
| **Blooded** | company gains a level | 1 | `commanders.md` |
| **The Fort Falls** | fort destroyed by ground troops | 1 | `battles.md` |
| **They Do Not Return** | expedition lost | 1 | `founding-towns.md` §7 |
| **The Cost of It** | town loses people to an attack | 1 | `battles.md` |
| **The Ground Is Taken** | rivals block tiles the colony would have worked | 1 | `rival-pressure.md` |
| **They Burned It** | rivals destroy an improvement | 1 | `tiles-and-improvements.md` |

**They Do Not Return needs variants** — rebels, natives and rivals are three
different paintings, the same question Overrun asks.

### Firsts of the run — from the desk

Nothing in the world moved. **A man you wrote to did something**, and the
painting is about that.

| Caption | Fires on the first | Panels | Emitted by |
| :--- | :--- | :--: | :--- |
| **He Will Not Do It** | a contact refuses an order | 1 | `order_refused` · SPEC §8.5 |
| **The Steward Acts** | a contact acts unilaterally | 1 | `contact_acted_alone` · SPEC §8.5 |
| **The Marshal Withdraws** | the Marshal pulls the troops back | 1 | `the-marshal.md` §4 |
| **A Promise Unpaid** | standing falls with promises outstanding | 1 | `crown-standing.md`, SPEC §9.5 |

### Recurring — the first of each turn

| Caption | Fires | Panels | Owns the moment |
| :--- | :--- | :--: | :--- |
| **Colony Holds Trade Protest** | first protest this turn | 1 | `trade-protests.md` |
| **Shots Exchanged** | first battle this turn | 1 | `battles.md` |
| **A Town Changes Hands** | first town taken or retaken this turn | 1 | `battles.md` |

**A recurrence never fires in the turn its first fired.** *The First Blood* and
*Shots Exchanged* are the same event seen twice; the first turn gets the painting
that will not come again.

---

## 7. What is deliberately not a cutscene

The catalog is bounded by §3. One a turn means anything that happens most months
can never hold the slot, so it should not ask for it:

- **The monthly machinery.** A demand arriving, a duty paid, standing ticking
  down, a harvest, a birth, the fourth building. These belong to the map, the
  letters and the ledger, and a painting each month would mean nothing by the
  fifth.
- **Anything a letter already carries.** A painting that restates a letter the
  player is about to read wastes the one slot.

### It is never the topic that disqualifies a moment

Taxes and standing are on that list and **The Steward Acts** and **A Promise
Unpaid** are in the catalog, which looks like a contradiction and is not.

The Steward raising rates unilaterally is not *taxes* — it is a man doing
something without asking. Standing falling with promises outstanding is not
*standing* — it is a promise broken. **The topic is the same and the moment is
not**, and the catalog is a list of moments.

**The test is whether it would still be worth a painting on the fortieth turn.**
*Meeting the natives* would. *A good harvest* would not. A man refusing you for
the first time would; the ninth man refusing you would not, which is why almost
everything here is a first.

---

## 8. Tuning targets

- How long a painting holds before advance is offered, and whether a run of
  several in one turn wants any pause between them.
- Whether month one stays comfortable once the catalog is fully painted — it is
  the busiest turn in the run by design, and the only one worth re-measuring.

## 9. Open items

- **The cut.** Forty-two cutscenes at one to three panels each, plus the
  variants below, is somewhere near sixty paintings. That is the real cost of
  this document and the Author should set the number before anything is
  commissioned. **The desk firsts are the cheapest to paint** — a man at a desk,
  a letter, a closed door — and among the most characterful, which is an argument
  for cutting elsewhere first.
- **Do the four institutional contacts each want their own?** Four paintings for
  four arrivals, against one *A New Face in the Colony* reused. They are
  distinctive men, but they are also the cheapest four to collapse.
- **Overrun's variants**, above — how many culprits deserve their own painting.
