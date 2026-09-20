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

### The objective sets the ambition

The governor takes **an expedition** as his town's objective — one of the project
kinds in `governor-objectives.md`. When he takes it, he sets its **target cargo
by what he can spare**: stockpile above needs, above the current objective, above
reserve.

The town then gathers toward that target over months exactly as it would toward a
building, and **launches when it is met**.

**This one rule produces both kinds of expedition.** A prosperous town sets a
grand target and sends a colony that will leap ahead of its parent. A crowded,
poor town shedding mouths it cannot feed — the overflow case in
`immigration.md` §10 — sets a target of almost nothing and sends people with what
they can carry.

Same objective, same machinery, opposite outcomes.

### But two motives, and therefore two considerations

The cargo rule handles the difference. **The intent does not**, and it must, or
only one kind of expedition ever launches.

A governor adopts the settlement intent for one of two unrelated reasons:

| Consideration | Measures | The expedition it produces |
| :--- | :--- | :--- |
| **`room_to_grow`** | unclaimed land worth taking | the grand one — opportunity |
| **`crowding`** | people the town's ground cannot carry | the thin one — pressure |

**These must not be merged into one number.** `deliberation.md` makes personality
a weight vector over considerations, so two considerations give two weights and
therefore two kinds of governor: the ambitious man who settles because there is
land, and the pragmatic one who settles because there are too many mouths. A
single blended term collapses both into the same character.

It also fixes a chicken and egg. `room_to_grow` alone **cannot fire in a one-town
colony**, because one town never sees enough unclaimed land to justify leaving —
so the first daughter town can never be founded and the measure never rises.
Crowding has no such floor: a town too full for its fields is too full whether or
not anybody has surveyed the frontier.

**Crowding is population against workable ground**, not population alone. A town
of two hundred with room to work is not crowded; a town of forty on six tiles is.
Which means the expansion branch of the building tree (`buildings.md` §4) lowers
crowding by raising influence — a town can build its way out of needing to leave.

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

The Provost or a patron proposes, the PC replies, and **the correspondence
determines what the town starts with** — what he promises is what it is equipped
with.

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

### A deliberate exception to the one-at-a-time rule

`CLAUDE.md` holds that **no single event ever costs a town more than one
population.** An expedition is not a town, and this is the one place the
proportional rule applies instead.

The reason is that the rule exists to keep per-population consequences uniform
and legible inside a settled town. An expedition is a single body of people in the
open with no walls and nobody to call on, and an ambush that takes a quarter of
them is the correct fiction. **A dev should not "fix" this to match the town
rule.**

## 8. Arrival

The town is founded on the chosen tile with **exactly what the expedition
carried**: its people, its stores, its gold, its livestock, its experts, and any
building the Crown equipped it with.

Its quality of life then computes normally from what it holds. A well-found town
is comfortable on the day it is founded; a shed one is wretched from the start.

**A new town extends the colony's border and vision** (§11.4).

## 9. SPEC §11.4 needs an edit

This line is no longer true:

> **A new town begins fragile:** no buildings, a thin stockpile, low population,
> low quality of life.

Proposed replacement:

> **A new town begins as it was sent.** An expedition mounted by a prosperous
> town, or equipped by the Crown, may arrive with stores, livestock, an expert,
> even a building already standing. One shed by a crowded town that could spare
> nothing arrives with almost nothing. What it starts with is what was given to
> it.

## 10. Tuning targets

- How the governor sizes his target cargo against what he can spare.
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
