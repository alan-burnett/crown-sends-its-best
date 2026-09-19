# Mechanics — The Town Economy

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.1 (resources), §10.2 (taxes and gold), §11.3 (the Colony
> Month), and the Squeeze pillar in §2.
>
> **Does not cover:** production and conversion. See §7.

---

## 1. Prices

**Static. A JSON library of resources and their prices.** Not dynamic, not
supply-and-demand, not negotiable.

The fiction carries the mechanic. When the colony buys or sells, it trades with
merchants loyal to the Crown. They charge a fair price — enough to profit, not so
much as to discourage trade — and the colonists always pay the tax on top.
**The Crown never loses on an exchange**, and what is traded at what price is
entirely outside the PC's purview.

So **the tax rate is the only economic lever the PC has**, and it is purely a
measure of how hard the colonists are being squeezed. There is no petitioning for
better terms. The people on the Crown's side of the ocean always do just fine.

### The economic thesis

This is worth stating plainly because it is the Squeeze expressed in gold:

> The Crown gains from **volume of trade multiplied by tax rate**. It bleeds from
> exactly three things: rates too low to be worth collecting, a colony that
> **refuses** to trade, and the PC's promises.

The Crown therefore wants a productive, heavily taxed, compliant colony. The
player's problem is that heavy taxation produces trade protests and rebellion,
and those destroy the trade the tax was levied on.

### Luxury price order

Deliberate, because it sets up the taxation crisis:

1. **Beer** — cheapest, and made from food, which every town has.
2. **Tea** — second cheapest, and **it can never be produced** (§10.1).
3. Rum, cigars, and the raw luxuries above them.

**The rule behind the ordering, which is what must not break:** *tea is the
cheapest pleasure a town can never make for itself.* Any luxury priced below tea
must be one the colony can produce, or a town will buy that instead and tea stops
being the place taxation bites. State it this way because a later price change
can honour the ordering by accident and still break the design.

A growing town supplements itself with beer, then rum once it has sugar. **Tea is
the cheapest luxury a town must always buy**, which makes it the point where
taxation breaks first — not because anything favours it, but because it is the
only cheap pleasure the Crown can withhold.

## 2. Choosing what to buy

Needs and the objective are determined: the town buys what it lacks. The real
choice is in the **wants** tier, among luxuries.

A town buys whichever luxury gives the most **quality of life per gold at the
margin**, given what it already has. Three things make that differ:

**Scarcity within a type.** The less of a luxury a town has, the more desirable
it is. A town swimming in tea gets more from its first rum than its hundredth
tea, and pays more for it gladly. This is the variety bonus in
`quality-of-life.md` seen from the buying side.

**Local production.** Rum comes from sugar, beer from food, cigars from tobacco.
A town with a sugar plantation has rum at near-zero marginal cost and will never
buy it. **Tea is always a purchase, for everyone.** Two towns facing the same
price list therefore buy differently, for reasons the player can reason about.

**The per-resource tax rate**, which is the payoff. Tax tea heavily and towns
shift toward rum — which many of them make themselves — so the Crown collects
*nothing* rather than more. Per-resource rates are a real instrument with a real
backfire, and §10.2's line about tea being favoured for the first trade protest
falls out of the mechanics rather than being hardcoded.

Base prices should roughly track potency, so that no luxury is strictly
dominant and the three factors above do the differentiating.

## 3. Reserve

**A buying target and a selling floor.** A town buys *toward* its reserve and
never sells below it. One breakpoint per resource, no granularity.

### Size

Per-resource, in months of consumption, scaled with population. The shipped
baseline is **food 2, clothing 1, everything else 0.5**, which is a better
starting point than a single global figure and is what the tuning should move
from.

For resources a town does not consume — stone, guns, tools — months of
consumption is zero, so the base is zero and **the modifiers below are the only
thing that creates demand.**

### Modified by objective and intent

- The **objective** raises the reserve on what the current project consumes.
- The **governor's intent** raises it more broadly. A military intent raises guns
  and horses; an intent to build up the town raises stone and lumber.

This is what makes reserve an **economic driver** rather than a safety buffer. A
military intent does not protect guns the town already has — it creates demand
for guns it does not have, and the town goes shopping.

**A hoarding posture reserves everything.** An objective to stockpile or harvest
a resource sets its reserve high enough that Relief and Sell both find nothing to
give away. That is the correct reading of an order to hoard, and it is the
strongest form the modifier takes.

### Who respects it

| Tier | Reserve |
| :--- | :--- |
| **Needs** | ignored — survival draws freely |
| **The objective** | ignored — draws freely |
| **Wants** | respected — luxuries are bought only above reserve |

The objective draws below the reserve because **the reserve exists to serve the
objective.** Delaying the project to protect a stockpile gathered for that project
would be nonsense.

## 4. Working the tiles

Each tile offers an integer number of resources of various types. A town works as
many tiles as its workers allow (§12.2), choosing the highest scoring.

### Scoring

```
score(tile) = sum over resources of  yield * favour
              where favour = 3 if the objective wants that resource, else 1
```

The **objective's favoured resources count triple**. A town raising a building
that needs wood and stone will take a middling forest over a rich pasture.

Ties break by a rule fixed by the seed.

### The survival check, applied after scoring

If the assignment leaves the town unable to meet its **food and clothing** needs,
it redirects: take the worker off the worked tile contributing least to the
shortfall and put them on the unworked tile contributing most. Re-evaluate, and
repeat.

**If no swap would improve matters, the town does nothing and accepts the
deficit.** It does not thrash, and it does not pretend.

Food and clothing are **lockstep** — both are needs and both are checked. Note
that clothing is not a tile yield; it is converted from furs or cotton, so the
clothing half of this check depends on the production mechanic (§7).

### There is no penalty for producing what you already have

A town with many cotton plantations does not need cotton. It is growing cotton
for **export**, and that is the point — the Sell phase disposes of everything
above reserve every single month, so surplus becomes gold rather than a heap.
Specialisation is how a town becomes an economic powerhouse, and the Crown wants
exactly that.

**The exception is a town that cannot sell.** Under a trade protest, or in
rebellion, the export market closes and the specialty genuinely does rot in the
warehouse. A fur town's entire advantage becomes worthless. That is a real and
intended consequence of rebellion, and it needs no special handling — it falls
out of the Sell exceptions in §11.3.

## 5. What the Crown sees

Because the Crown's merchants always profit and the colonists always pay:

**Trade revenue to the Crown is always positive.** It can never go negative from
an exchange. In the Ledger, money in is always trade and money out is always the
PC's promises, which makes the trend legible without explanation.

This simplifies `crown-standing.md`: `monthly_net` falls only through the PC's
spending, through rates too low to collect, or through a colony that has stopped
trading. It never falls because a trade went badly.

## 6. Tuning targets

- The **price table**, with beer cheapest and tea second.
- Reserve base, in months of consumption, and the intent and objective multipliers.
- The favoured-resource multiplier, starting at 3.
- Luxury potency per resource, which should roughly track price.

## 7. Pinned: production and conversion

**The minimum M2 needed is built** — #64 shipped conversion in the Work phase and
`sim/colony/conversion.gd` exists, so the six conversions of §10.1 all happen and
clothing no longer has to be bought. The blocker recorded here is closed.

**The larger mechanic remains deferred by the Author** (#92). It will take in tiles, improvements, building bonuses, experts, and the
allocation of workers between working tiles and converting raw resources into
processed ones.

**Settled already:** conversion **competes with tile work for labour.** One worker
is in the fields, the other is in a building in the town. That is an acceptable
simulation of a city growing as the land around it is worked, and it means every
conversion costs a worked tile.

Two things make it more than a detail:

- **§10.1 names six conversions** — ore to iron, furs or cotton to clothing, iron
  to tools and guns, food to beer, sugar to rum, tobacco to cigars — and **the
  Colony Month has no phase where they happen.** Half the resource list cannot
  currently come into existence.
- **Clothing is a need.** A town that cannot convert cannot clothe itself, so M2
  cannot ship without at least a minimal conversion step.

Until that mechanic is written, this doc's tile scoring stands on its own and the
survival check's clothing half is incomplete.

## 8. Open items

- How experts (§12.2) fold into tile scoring — presumably by multiplying yields
  before the score is taken.
- Whether the survival check should look ahead more than one month, given that
  reserve is already sized at three.
