# Mechanics

The numbers and formulas `SPEC.md` deliberately leaves out.

**The PO owns these. Devs read them; devs do not edit them.** If a mechanics doc
contradicts the spec, **the spec wins** and the ticket gets the `author` label.

They are living documents. Expect them to be reworked after playtesting — that is
the point of keeping them out of the spec, so the spec can stay true without
being rewritten every iteration.

## Written

| Doc | What it covers | First needed |
| :--- | :--- | :--- |
| [perception.md](perception.md) | How a truthful number becomes a biased word | M1 |
| [deliberation.md](deliberation.md) | One kernel for every decision an actor makes | M1 |
| [world-month.md](world-month.md) | The nine phases, and the timing rule | M1 |
| [quality-of-life.md](quality-of-life.md) | How pleasant or miserable a town's life is | M2 |
| [governor-objectives.md](governor-objectives.md) | Intent, objectives, and who decides which | M2 |
| [town-economy.md](town-economy.md) | Prices, reserve, buying, and working the tiles | M2 |
| [crown-standing.md](crown-standing.md) | The bottomless pit, and when it stops being one | M3 |
| [crown-demands.md](crown-demands.md) | A fixed bar, then a moving one — and bucket randomisation | M3 |
| [rebel-sentiment.md](rebel-sentiment.md) | Who gets blamed, and when a town stops asking | M3 |
| [the-diplomat.md](the-diplomat.md) | The PC's only resident eyes, and his price | M3 |

## Still to write

**Tracked as GitHub issues labelled `po`**, each assigned to the milestone that
first needs it. That list is the live one; this table is the map.

| Mechanic | Issue | First needed |
| :--- | :--- | :--- |
| Production and conversion | #92 | M2 |
| Town buildings and the building tree | #93 | M2 |
| General contact behaviour | #91 | M3 |
| Trade protests | #94 | M3 |
| Policy | #96 | M3 |
| Prestige, and gold's share of it | #97 | M3+, blocked on the Author |
| Immigration and population growth | #98 | M4 |
| Founding towns and expeditions | #99 | M4 |
| The Provost | #100 | M4 |
| Native behaviour and trust | #101 | M5 |
| Trading with natives | #102 | M5 |
| Rival pressure | #103 | M5 |
| Battles and combat resolution | #104 | M6 |
| The Marshal | #105 | M6 |
| Commanders | #106 | M6 |
| Patrons | #107 | M7 |
| Institutional contacts | #108 | M7 |

## Patterns

**Bucket randomisation** lives in [crown-demands.md](crown-demands.md) section 7.
Draw without replacement from a bucket holding two of each option, refill at the
halfway mark. Runs differ; aberrant runs — the same option five years running —
are impossible rather than unlikely, which keeps tuning and scoring honest.

Written to be lifted. If a second mechanic wants it, extract it rather than
duplicating it.

## Contacts

One doc for **general contact behaviour** (#91), and an override doc for each
contact that breaks those rules. Most will need one — a contact usually exists
*because* it does something special, and the override is where that something
gets written down.

**Chancellor and Steward are deferred, not exempt.** SPEC §10.3 and §10.2 cover
them well enough today. The moment anything is built on top of them that the spec
does not describe, they need docs too.
