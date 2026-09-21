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
| [the-director.md](the-director.md) | Who writes this month, and about what | M1 |
| [contacts.md](contacts.md) | What is true of every contact, and what loyalty does | M1 |
| [perception.md](perception.md) | How a truthful number becomes a biased word | M1 |
| [deliberation.md](deliberation.md) | One kernel for every decision an actor makes | M1 |
| [world-month.md](world-month.md) | The nine phases, and the timing rule | M1 |
| [quality-of-life.md](quality-of-life.md) | How pleasant or miserable a town's life is | M2 |
| [governor-objectives.md](governor-objectives.md) | Intent, objectives, and who decides which | M2 |
| [town-economy.md](town-economy.md) | Prices, reserve, buying, and working the tiles | M2 |
| [perks-and-quirks.md](perks-and-quirks.md) | Facts about you, and facts about the world you were given | M7 |
| [prestige.md](prestige.md) | The Crown's running account of the PC, and the final score | M3 |
| [tiles-and-improvements.md](tiles-and-improvements.md) | What a tile yields, what sits on it, and razing as harassment | M2 |
| [buildings.md](buildings.md) | The tree, what each does, and what it costs to keep | M2 |
| [immigration.md](immigration.md) | Who comes, why, and why you might not want them | M4 |
| [founding-towns.md](founding-towns.md) | Two ways to plant a town, and what each costs | M4 |
| [the-provost.md](the-provost.md) | The four knobs, education, and how an expert appears | M4 |
| [the-marshal.md](the-marshal.md) | The officer with nothing to gain, and the gate on Independence | M6 |
| [institutional-contacts.md](institutional-contacts.md) | The clergy, the quartermaster, the journalist and the scholar | M7 |
| [patrons.md](patrons.md) | Specialty, need and vice, and the six months that close | M7 |
| [commanders.md](commanders.md) | Who decides, what they learn, and why refusal is not a branch | M6 |
| [battles.md](battles.md) | Companies, force, and how ground is taken | M6 |
| [rival-pressure.md](rival-pressure.md) | Dukes, tribute, and loyalty as a protection racket | M5 |
| [natives.md](natives.md) | Standing, the point of no return, and trade agreements | M5 |
| [crown-standing.md](crown-standing.md) | The bottomless pit, and when it stops being one | M3 |
| [crown-demands.md](crown-demands.md) | A fixed bar, then a moving one — and bucket randomisation | M3 |
| [trade-protests.md](trade-protests.md) | When a town refuses the Crown's duty, and what it costs | M3 |
| [policy.md](policy.md) | How the Crown puts its thumb on the scale, and who pays | M3 |
| [rebel-sentiment.md](rebel-sentiment.md) | Who gets blamed, and when a town stops asking | M3 |
| [the-diplomat.md](the-diplomat.md) | The PC's only resident eyes, and his price | M3 |

## Still to write

**Tracked as GitHub issues labelled `po`**, each assigned to the milestone that
first needs it. That list is the live one; this table is the map.

| Mechanic | Issue | First needed |
| :--- | :--- | :--- |
| Production and conversion | #92 | M2 |
| Prestige, and gold's share of it | #97 | M3+, blocked on the Author |
| Rival pressure | #103 | M5 |
| Battles and combat resolution | #104 | M6 |
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

One doc for **general contact behaviour** ([contacts.md](contacts.md)), and an
override doc for each contact that breaks those rules. Most will need one — a contact usually exists
*because* it does something special, and the override is where that something
gets written down.

**Chancellor and Steward are deferred, not exempt.** SPEC §10.3 and §10.2 cover
them well enough today. The moment anything is built on top of them that the spec
does not describe, they need docs too.
