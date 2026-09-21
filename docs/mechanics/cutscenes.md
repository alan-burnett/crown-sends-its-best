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

---

## 3. 🔒 One cutscene a turn

The PC opens his post once a month. A month that opened with three paintings
would be a slideshow, and the screen would stop meaning anything.

**A turn shows at most one**, and the rules for choosing are short:

- **A first outranks a recurrence.** The first battle of the run will never come
  again; the first battle of *this* turn will come again next time there is one.
- **Among firsts, the earliest event wins**, by `seq`. Deterministic, and it
  matches the order the map just played them in.

### A first that loses waits. A recurrence that loses is spent.

A first is a moment that cannot be re-staged, so **it holds and fires next turn**.
A recurrence is by definition going to recur, so it is simply dropped.

**A held first expires after three turns.** *The First Works* arriving four
months after the building went up is a caption about nothing, and a small backlog
early in a run — landfall, the first building, the first immigrants, all within a
few months of each other — is exactly when this would happen. Three is a tuning
target.

---

## 4. After the playback, before the desk

The order of a turn's opening is **map playback, then the cutscene, then the
desk.**

The painting is punctuation on the month, not a title card for it. Shown first,
*Meeting the Natives* tells the player what the map is about to play; shown
after, it is the thing he is left holding when he sits down to answer his post.

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

### Firsts of the run

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

- **Crown demands, taxes, duties, standing.** Monthly, and they belong to the
  letters and the ledger.
- **Anything a letter already carries.** A painting that restates a letter the
  player is about to read wastes the one slot.
- **Routine growth, births, harvests, buildings after the first.** The map plays
  these.

**The test is whether the moment would still be worth a painting on the fortieth
turn.** *Meeting the natives* would. *A good harvest* would not.

---

## 8. Tuning targets

- Turns a held first waits before it expires (§3, starting at three).
- Whether one a turn is right, or whether the early run wants two while the
  backlog drains.

## 9. Open items

- **The cut.** Thirty cutscenes at one to three panels each is roughly forty
  paintings. That is the real cost of this document and the Author should set the
  number before anything is commissioned.
- **Do the four institutional contacts each want their own?** Four paintings for
  four arrivals, against one *A New Face in the Colony* reused. They are
  distinctive men, but they are also the cheapest four to collapse.
- **Overrun's variants**, above — how many culprits deserve their own painting.
