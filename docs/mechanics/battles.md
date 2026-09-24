# Mechanics — Battles

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §12.6, §12.3, §11.1, §11.2, §10.1, §12.2, §8.6.

---

## 1. The Company

**A company is one visible body of armed men on one tile.**

SPEC §12.6 already names the two *kinds* — **Colonial Forces** and **Crown
Troops** — and §4 carries both. Those are mass nouns. A company is the countable
thing on the map, and a Crown force putting down a rebellion is many companies.

Rebel, rival and native bodies are companies too. **One structure, one resolver,
whoever is holding the musket.**

| Field | |
| :--- | :--- |
| **size** | the population under arms |
| **arms** | guns, tools and horses it carries |
| **support** | the town that victuals it, or the Crown |
| **leadership** | a commander, or none |
| **objective** | what it is trying to accomplish |
| **allegiance** | colonial, Crown, rebel, rival, native |

**Allegiance is what §12.3's locks read.** *Colonists do not fight colonists*, and
*rebel towns fight the Crown's forces but never loyal towns*, are filters on this
field and nothing else.

### 🔒 Raising one is an objective, like any other

**Author's ruling (#342).** Raising a company is an objective on an intent's
menu, like a building (`governor-agendas.md` §7): **small and big companies**,
each with its own gate. Go wide, go tall, military and prepare for rebellion
raise them; get rich and education do not.

Not a second path that bypasses the objective system. Where a company sits on a
menu, and what its gate asks, is how a governor declines to raise one because
something else comes first — and that refusal is what makes raising one mean
something.

It also keeps §11 true. The PC's instrument is *raising companies through a
governor's intent*: he shifts the weights by letter and the governor decides, the
same relationship he has with everything else a town does.

**The expedition is the pattern.** `founding-towns.md` §7 already has a body of
people leaving a town with a share of its stores, and `CLAUDE.md` already treats
the two alike when they are attacked. Raising mirrors launching.

### What it takes with it

| | |
| :--- | :--- |
| **Men** | from **workers**, never experts |
| **Arms** | guns, tools and horses at §2's supply ratio, drawn from the town's stores **at launch** |
| **Support** | the town that raised it (§3) |

**Workers, never experts**, because `CLAUDE.md` holds that workers go before
experts and accumulated expertise is what a bad month cannot take. A town does
not send its smith to carry a musket.

**And it takes its men at once.** `CLAUDE.md`'s one-population-at-a-time rule
governs **hardship** — famine, shortage, a bad winter. Enlistment is a decision
rather than a misfortune, so it is not that rule's business, and a company raised
one man a month would never assemble.

**§2's lock still binds: a company never resupplies its arms.** What it carries
out is what it has, so how well it is armed is settled in the month it is raised
— which is exactly the point at which the PC's letter is a month old.

### How large, and what the town keeps

**The governor sizes it**, as he sizes an expedition's cargo, against what the
town can spare and what it can arm.

**A town must keep enough workers to work**, and that floor is the answer to
*may a town of twelve put ten under arms*. It may not. The floor is a tuning
target (§12) rather than a number here, because it trades directly against how
threatened the town is — a colony about to be overrun should be able to empty
itself further than a comfortable one.

### Which standing order it gets

**The company chooses it when it is raised**, from the map and the raising
governor's intent (`commanders.md` §2). Who leads it — militia or commander —
depends on its size and its town's, not its order. The orders, and the rule
that chooses among them, are `commanders.md` §3.

## 2. Support and arms are different things

Two things wear the word *supply* and they behave nothing alike.

| | What | From | When |
| :--- | :--- | :--- | :--- |
| **Support** | food, clothing | its town, or the Crown | **every month, ongoing** |
| **Arms** | guns, tools, horses | whatever it launched with | **fixed at creation** |

**A company is victualled continuously and equipped once.**

### Arms are a supply ratio

Each head **wants** so many guns, so many tools, so many horses. What the company
holds against what it wants sets a multiplier on that head's contribution, and
**surplus does nothing**.

```
armed_share(r) = min(held(r) / (size x want_per_head(r)), 1.0)
```

Tools are a weapon here, not a toolbox — trenches dug, battlements thrown up,
muskets kept firing. They multiply effectiveness exactly as guns do.

This is the same shape `quality-of-life.md` uses for pleasure, *scaled by the
fraction of the population served*, and deliberately so. One mental model covers
both and neither needs new machinery.

### 🔒 A company never resupplies its arms

It launches with what it launches with and it never gets more. It cannot be
reinforced with men either — **a company only ever dwindles.**

The single exception is not a mechanic but a letter: **a commander may write to
the PC asking for gold to buy horses.** That is the Correspondence pillar reaching
the battlefield. The PC cannot order an attack, but he can be the reason there is
cavalry to make one.

It also makes arms a **launch decision**. Raising a company is an allocation, not
a button.

## 3. Support, and who eats first

A colonial company is victualled by a town, which **counts its men as mouths** and
spends on them.

The order is fixed:

1. **The townspeople's own needs** — food and clothing.
2. **Every company the town supports.**
3. The objective.
4. Wants.

So companies sit **above the objective and below the town's own people**. A
governor cannot starve his citizens to feed his soldiers, and he cannot raise a
chapel while his men go hungry.

**🔒 A town cannot disband its way out of famine.** If it cannot cover a company,
it sends nothing and that company goes **unsupported**. Militia are a commitment,
not a lever — no raising men in a good year and shedding them in a bad one.

### Unsupported

**Effectiveness falls at once, and the company bleeds.** It loses a share of its
population every month it goes without, and it recovers the moment supply
resumes.

### Crown companies are never the colony's burden

`the-marshal.md` §3 locks it: Crown troops are victualled by the Crown and there
is no state in which they depend on the colony. Withdrawal is **staged and
announced** — the PC stops paying, the Marshal covers it out of his own account
while his regard falls, he writes naming the season it ends, and then the troops
sail home. They are gone some months later, never the month the money stops.

## 4. Leadership is agency before it is a bonus

**A company cannot decide anything.** Seam C binds it as it binds everyone: a
*commander* deliberates, produces will, and that becomes an Intent the sim
executes over months.

So a company with no commander has nobody to deliberate for it.

| | |
| :--- | :--- |
| **With a commander** | can be sent, can besiege, can be **written to** |
| **Without one** | the standing order it took when it was raised, and nothing else |

**A militia keeps the order it was raised with** — defend the town, explore,
guard the border or march on a foe (`commanders.md` §3). It cannot be sent
elsewhere, and nobody can write to it.

**And it disbands after 12 months**, on the spot, survivors rejoining the town. Which gives
defence a **running cost**: a militia eats for every month it stands, so a town
under sustained threat must keep re-raising and keep re-feeding. That is the
Squeeze arriving in a system it has not touched before.

Leadership also multiplies effectiveness. But the agency is the real difference,
and it is what makes the Marshal's officer (§8.6) worth something structural.

**Commanders are contacts.** Colonial and rebel commanders both, which is how a
rebel general comes to be negotiating with the Crown by letter — a correspondence
channel §12.3 implies and never names. See `commanders.md`, which also settles
that **a commander can refuse to attack**: he scores every option including
withdrawal, and refusal is attack scoring below retreat rather than a branch in
the code.

## 5. Force

Everything above resolves into one number per company.

```
force = size
      x arms multipliers (guns, tools, horses)
      x leadership
      x supply state
      x terrain
      x fortification
```

**Terrain is the defender's advantage**, and it is folded into force rather than
applied as a separate step — so attacker and defender are then treated as equal
actors and there is no second "defender bonus" anywhere.

| Terrain | Defence |
| :--- | :--- |
| Mountains | high |
| Forest | medium |
| Plains | low |

**A fort multiplies on top**: a medium boost to a company attacking *from* it, a
very high boost to one defending *in* it. **It serves whoever stands in it**, and
it falls with its last defender (`tiles-and-improvements.md` §6).

A stubborn rebel company in a fort on a mountain is close to unassailable, and is
meant to be. The answer is not a better army — it is wearing them down over years,
or finding somebody else to do it.

## 6. Resolution

**A field battle is between two adjacent companies**, and it happens because one
of them, executing its move, chose to attack the other. It resolves inside world
month phase 2, in one month.

### 🔒 Deterministic. No dice at all

Everything around a battle is chaotic — whether the order arrived, whether the
commander agreed, whether the town could feed him. **The battle itself is
arithmetic.**

The PC never commands (§12.6, locked), so he cannot be out-played, only
under-prepared. Randomness would make what he spent on guns feel arbitrary; this
way the map is legible and the uncertainty lives where the game wants it.

### The formula

```
casualties = LETHALITY x (my_force / their_force)
```

Both sides compute it from the same numbers and **suffer simultaneously**. At
`LETHALITY = 0.1`:

| Mine | Theirs | Ratio | I inflict |
| --: | --: | --: | --: |
| 40 | 20 | 2x | **0.2** |
| 40 | 10 | 4x | **0.4** |
| 40 | 4 | 10x | **1.0** |

**Because force is derived from population, every loss lowers the loser's force
and raises the winner's ratio next month.** The grind accelerates on its own: a
besieger doing 0.2 a month is doing 1.0 a year later, and soon his kills outweigh
his losses. Nothing schedules that — it falls out.

It also makes **obliterating a small company feel different from bleeding a large
one**, which is what stops a big army being merely a bigger number.

**Casualties are fractional and they accumulate.** A company dwindling at 0.2 a
month is visibly dying for five months before it loses a man, and that is exactly
the letter its commander should be writing.

### 🔒 No rout

Nobody retreats and nobody surrenders. **A company fights until it is destroyed**,
and ground is taken only when the last defender is gone.

### Losses take the supplies with them

A company that loses a third of its people loses **a third of everything it
carries**. Ratios are preserved, so a fully supplied company stays fully
supplied — with less of everything.

That single rule is what lets cavalry survive attrition without a special case.

## 7. Order of resolution

Several companies may attack one in a month, and each is a separate battle
resolved in sequence — so the defender weakens as they come, and **a Crown company
surrounded by rebels can be destroyed in a single month.** That is the design.

Which means order changes outcomes, so it is fixed and never incidental:

1. **Factions in a set sequence** — colonial, Crown, rebel, rival, native.
2. **Within a faction, earliest-created first**, by the sequential id assigned at
   instantiation.

The same rule that orders towns. It needs no tie-break and no seeded roll, because
creation order is already deterministic from the seed.

## 8. Cavalry

**A company supplied to the full on horses is cavalry.** There is no separate unit
type and no flag — it is a threshold on the arms ratio, and it holds through
attrition because losses preserve ratios.

| | Moves | Attacks | Terrain |
| :--- | :--- | :--- | :--- |
| **Company** | 1 | 1 | pays the defender's terrain bonus |
| **Cavalry** | 2 | 2 | **ignores it when attacking** |

**A fort is never ignored.** Horses are no answer to a wall.

A normal company **moves and attacks in the same month** — not one or the other,
or nothing could ever be chased down. Cavalry does both twice, which is a tempo
advantage as much as a combat one: it can strike, reposition and strike again
while the foot are still marching.

## 9. A town is a company with a wall

**Towns fight by the same arithmetic.** A town has population and supplies, so it
computes force exactly as a company does.

- **The town itself fortifies**, like an improvement — the same shape as a fort.
- **The terrain it stands on matters**, as it does for anyone.
- **Defence buildings add on top** — stockade, palisade, trenches, guard towers.

So there is **no siege subsystem.** *A siege takes months* falls out of a hard
target being worn down by §6's curve, and needs no machinery of its own.

### Attacks depopulate fast

**Every loss of people is a share** (`population.md` §6), and overwhelming force
takes a large one: a town facing it loses people quickly. That is the point of
overwhelming force.

## 10. What a battle reaches beyond the map

Two systems read combat and neither is named anywhere else in this document.

**Quality of life's `safety`.** `quality-of-life.md` §4 defines it as *is the
population being attacked, and is it safe to travel* — pinned at 1.0 and excluded
from the sum until the military exists. **This is what brings it alive.** A town
under attack, or cut off by a company sitting on its roads, is a town whose safety
falls, and §6 of that document is already written around the consequence: life
under threat is worse, which feeds rebel sentiment, which is the PC's foothold for
quelling a rebellion — and the loop runs both ways when the rebels win.

**Prestige's optics.** A **company destroyed** is a fixed, undecaying debt
(`prestige.md` §4), as is **a town lost**. Note what is *not* priced: an
exchange of casualties is not a defeat, because §6 has no such thing. The court
hears about annihilation, not about a bad month.

## 11. What the PC can actually do

Nothing, directly, and that is the point (§12.6, locked). His instruments are:

- **Raising companies**, through a governor's intent, and how well they are armed
  when they launch.
- **Asking the Marshal for troops**, and paying enough that they stay.
- **Writing to commanders**, who have agency and may listen.
- **Sending gold** when a commander asks for horses.
- **Building the tree** — walls, and the guns and tools that arm the men.

Every one of those is a letter, and every one of them is a month or more early.

## 12. Tuning targets

- **The worker floor a town keeps when raising a company** (§1), and whether it
  softens as the town is threatened.
- **How large a company a governor raises**, against the town's spare workers and
  what it can arm.

- `LETHALITY`, and whether the curve should be steeper than linear in the ratio.
- Want-per-head for guns, tools and horses, and each one's multiplier.
- What leadership is worth.
- The three terrain tiers and the two fort tiers.
- How long a leaderless militia stands before disbanding.
- Attrition per month while unsupported.

## 13. Open items

- **Whether a battle should cost the attacker anything beyond casualties.** Time
  and position are already spent; there may be no need for more.
- What a native company's arms look like, given §10.1 has them coveting guns and
  tools they cannot make.
- Whether the Diplomat's death roll fires on a town's battle losses as it does on
  other population loss (`the-diplomat.md`).
- Whether a native company's leadership works as anybody else's, or whether a
  tribe's war party answers to the village rather than to a man.
