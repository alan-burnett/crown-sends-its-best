# Mechanics — Founding Towns

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.4, §12.1, §12.5, §8.5, and the Squeeze pillar.
>
> **Requires an edit to SPEC §11.4.** See §9.

---

## 1. Two funding sources, and that is the decision

SPEC §11.4 gives four routes — a governor proposes, the PC asks one to, or a
Crown figure or patron presses one on the colony. They collapse into **two**,
because what matters is who pays.

| | Paid by | Costs | Crosses the map | The town that results |
| :--- | :--- | :--- | :--- | :--- |
| **Town-launched** | the parent town | **a town you already own**, weakened for months | **yes** — and can be attacked | whatever the parent could spare |
| **Crown-launched** | the Crown | **Crown Standing**, through promises | **no** — it arrives by ship | arrives with a *character* |

A town expedition is free in gold and expensive in a town. A Crown expedition
leaves the colony untouched and is paid for out of standing.

**Rebel towns never found towns** (§11.4). They have a war to think about.

## 2. Town-launched

### Lean and thick

**An expedition is one of two objectives**, and the intent decides which
(`governor-agendas.md` §6):

| | Taken by | Gathers for | Takes |
| :--- | :--- | --: | --: |
| **Lean** | go wide | 2 months | 20% of the town |
| **Thick** | go tall | 5 months | 40% of the town |

- **While it gathers**, the town raises its reserve of **wood, stone, tools and
  food**.
- **When it leaves**, it takes everything of those four **above the town's
  normal reserve**.
- **Resources only, never buildings.** A town-launched expedition founds a town
  with what it carries.

**This replaces the old cargo rule**, under which the governor set a target by
what he could spare and launched when it was met. The difference between a
grand expedition and a thin one is now **which intent sent it**: a go-wide
governor sends lean parties early and often, a go-tall governor sends a thick
one late, from a town that has grown to it.

### When a town sends one

**The menu's gate decides**, not a consideration. Go wide sends a lean
expedition while `(population ÷ 1000 − 2) × 2` exceeds the colony's towns plus
the expeditions already on their way; go tall sends a thick one from 8,000
people (`governor-agendas.md` §7).

**Crowding and room to grow still matter, one step earlier.** They are
considerations on **intent** (`governor-agendas.md` §13): room to grow pushes a
governor toward going wide, crowding pushes him out rather than up. They decide
whether he goes wide at all; the gate decides when he sends.

### It takes its share of the purse

**The departing population takes the share of the town's gold that its numbers
represent.** A fifth of the people leave with a fifth of the coin.

So founding drains the parent's purse in proportion to the drain on its
population, and a rich town's expedition is rich for the same reason it is
well supplied.

### Whether the PC asked makes no difference

A governor moved by the PC's letter and one moved by his own judgement do the
same thing: set the objective, gather, launch. The letter reaches his **intent**
(§8.5); what the town then does about it is his.

## 3. Crown-launched

The Provost, a patron, or **the clergy with an expedition of pilgrims**
(`institutional-contacts.md` §3) proposes; the PC replies; and **the
correspondence determines what the town starts with** — what he promises is what it
is equipped with.

The clergy's is the odd one: **he supplies the people and none of the goods.** He
gathers the devout from outside the colony, and unless the PC pays for their
stores the expedition never sails.

### It arrives with a character

This is what a parent town can never do. A Crown founding can arrive already
being something:

> *I know of a very wise botanist much taken with the cultivation of sugar cane in
> the colonies. I could see him equipped with supplies and a labour force, and he
> will found a settlement in country suited to the purpose.*

A town with a building already standing, an expert, an **intent** already set to
economic output, and a lean toward sugar. The same shape runs the other way —
*a parcel of poor souls desperate for a new life* — and arrives with very little
and no specialism at all.

### No ground travel

**It appears.** After some months it is simply there, on the coast. The Crown
managed the ships and the guards and whatever else a safe founding needed, and
none of §7's dangers apply.

That is the whole of the trade: **Crown expeditions are slow and safe and cost
standing; town expeditions are free and go across open country.**

### A set purse

A Crown-funded town arrives with **a fixed sum of gold**, not a share of
anybody's.

### The PC may dissuade, but he does not decide

§11.4 has these *pressed* on the colony. The PC can argue against one, and his
letter is an Order resolved by compliance like any other — **but the decision
remains the contact's.** A determined patron founds his town over the PC's
objection, and the PC's only real instrument is the regard he has built with the
man beforehand.

## 4. The new governor

**Generated the month the expedition launches** — the same month the town commits
and consumes the cargo — and he **writes to the PC immediately** (§11.4).

He is elected by the people setting out. The PC has no say whatever in who he is.

### His loyalty is inherited from whoever launched him

**A town-launched governor inherits from the parent governor. A Crown-launched
one inherits from the contact who proposed him.**

This is more than flavour. **It makes disloyalty propagate geographically.** A
sour governor seeds a sour daughter town, which will in turn seed another — so a
colony with one bad town can be growing its second before the PC has done
anything wrong at all.

It runs the other way too: a patron the PC has treated well hands him a governor
already inclined to listen.

**And the first letter shows it.** A daughter of a disloyal parent may write
sarcastically, and there will be nothing the PC can do to direct him.

## 5. The site, and the window in which preferences still matter

**🔒 The PC never chooses a tile** (§11.4). He approves, refuses, or states
preferences — toward the coast, near the ore, away from the tribes.

Those preferences arrive in his reply to the governor's first letter, which means
**the site cannot be fixed at launch** or they would be a month too late and
worth nothing.

So: **the governor sets out toward an intended region, and the PC's letter can
shift him while he travels.** That is exactly the multi-month interruptible
property `world-month.md` asks of consequential actions, and it is what makes a
preference an instrument rather than a courtesy.

It also gives *away from the tribes* a real price. §11.4 says founding near or
beyond native land offends the nearby tribes **in proportion to the intrusion**,
and the best ground is usually ground somebody already lives on.

### What makes a site good

Author's ruling (#422). Each candidate site scores:

```
site = ( 2 × total yield of the tiles within 1
         + total yield of the other tiles within 3 )
       × closeness
```

| Nearest existing town | Closeness |
| :--- | --: |
| within 3 tiles | 0.2 |
| within 4 tiles | 0.75 |
| further | 1.0 |

*Within n* is the ring distance the influence area uses (Chebyshev), so the
first term is the site and the eight tiles around it, and the second the forty
beyond them. Lean and thick expeditions score sites the same way.

This is the **ground merit** that `SitePreference` weighs the PC's preference
against. The PC's letter still bends the pick within the region as it does now.

⚠ assumed, for the Author to strike:

- **Total yield** is the tile's unimproved yield on the none / low / medium /
  high scale (`tiles-and-improvements.md` §1), summed over every resource.
- **Native land** is discounted per tile by the sending intent's aversion, as
  for improvements (`governor-agendas.md` §8): go wide 0.3 for a lean
  expedition, go tall 1.0 for a thick one.
- **Existing town** means towns only, not expeditions on their way.
- Candidates are explored land tiles outside every town's influence. The
  region is centred on the best of them.

## 6. Travel

A town-launched expedition behaves as a **unit on the map**, crossing to its
site over months. The PC can watch it go, because it is his colony's own and the
map shows what the colony knows.

## 7. It cannot fight

**An expedition never defends itself.** Settlers with wagons of goods — and guns
among the cargo — are no substitute for an army ready to fight. It is prey until
it arrives.

### What an attack does

**It loses population, and the same share of its supplies.** A quarter of the
people lost is a quarter of the stores lost with them.

**Two attacks and it turns back**, rejoining the parent town with whoever and
whatever is left. That is a setback rather than a catastrophe: the people come
home, the remaining stores come home, and the months are gone.

**Lost completely** (§11.4) is the extreme of the same rule rather than a
separate case — an expedition small enough, hit hard enough, has nobody left to
turn back.

### A share of the people, and the same share of the stores

**Every loss of people is now a share** (`population.md` §6): famine, war and
ambush alike. What stays particular to a body of people in the open is that
**it loses the same share of its stores** — a quarter of the people lost is a
quarter of the cargo lost with them — which is why a well-found expedition stays
well found in proportion however badly it is mauled.

## 8. Arrival

The town is founded on the chosen tile with **exactly what the expedition
carried**: its people, its stores, its gold, its livestock, its experts, and any
building the Crown equipped it with.

Its quality of life then computes normally from what it holds. A well-found town
is comfortable on the day it is founded; a shed one is wretched from the start.

**A new town extends the colony's border and vision** (§11.4).

## 9. A new town begins as it was sent

SPEC §11.4 once said a new town *begins fragile: no buildings, a thin stockpile,
low population, low quality of life.* **It no longer does**, and the line it now
carries is this document's:

> **A new town begins as it was sent.** An expedition mounted by a prosperous
> town, or equipped by the Crown, may arrive with stores, livestock, an expert,
> even a building already standing. [...] What it starts with is what was given
> to it.

Kept as a section because everything downstream depends on it: a daughter town is
**not** a fixed weak starting state, so nothing may assume one.

## 10. Tuning targets

- The gathering months and shares of lean and thick expeditions
  (`governor-agendas.md` §6).
- Months to cross a tile, and the months a Crown founding takes to appear.
- The chance of an expedition meeting something hostile, per month and per
  region.
- The proportion of people and stores an attack takes.
- The fixed purse of a Crown-funded town.
- How much an intrusion offends, against how good the ground is.

## 11. Open items

- **The overflow trigger is shared with `immigration.md` §10** and the two want
  tuning together. How crowded and how poor before a town starts shedding people
  is one number answering to both documents.
- Whether an expedition that turns back can be sent out again, or whether the
  objective is spent and the governor must decide afresh.
- Whether the PC learns *why* an expedition turned back, or only that it did.
- Whether a Crown founding can be placed anywhere on the coast, or only where the
  colony already has vision. Appearing in country the PC has never seen is
  strange; requiring vision makes the Provost's offers depend on exploration he
  has no way to direct.
- Attrition over long crossings is deliberately **not** modelled. The Author has
  noted it as a knob for later.
