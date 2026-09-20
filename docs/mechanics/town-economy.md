# Mechanics — The Town Economy

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.1 (resources), §10.2 (taxes and gold), §11.3 (the Colony
> Month), and the Squeeze pillar in §2.
>
> **Does not cover:** production and conversion in full. See §10.

---

## 1. Three dictionaries, not one price

**Every faction values a resource differently, and trade happens on the gap.**

A single price table was wrong. No ship comes from the Crown carrying lumber,
because a developed country and a forested colony value timber about the same and
there is no gap to pay for the voyage. No food goes back the other way, because
the home country grows it on a scale the colony cannot touch.

### All three are dynamic. They differ in what moves them, and how fast

| Dictionary | Moves with | Pace |
| :--- | :--- | :--- |
| **Town** | Desired stock against what it holds | **Monthly.** A town of forty revalues timber when it raises a church. |
| **Natives** | Their circumstances — war, trust, what they hold | Seasonal |
| **Crown** | Events at home — a failed harvest, a livestock die-off, a war | **Slow**, and from the colony it reads almost fixed |

**Nothing is locked static.** A valuation is a function; a constant is a function
with no inputs. Starting the Crown's as effectively fixed and adding drivers
later costs nothing, whereas declaring it immovable would have to be undone.

**When the Crown's prices do move, it is news.** A failed harvest at home means
the Crown will suddenly pay handsomely for colonial grain — reversing a trade
that never made sense before, and giving the Steward something worth writing
about. That is content the model gets for free and a fixed table could never
produce.

What does **not** change is that the PC has no purview over any of it. SPEC §10.2
locks that his gold is not a wallet, and §8.1 gives him no lever on terms of
trade. Prices move because the world moves, never because he asked.

### The mercantile pattern falls out of the numbers

| | Town values | Crown values | Result |
| :--- | --: | --: | :--- |
| Furs | low — it has plenty | high — scarce and fashionable at home | colony **sells** |
| Tools | high — it needs them and can make few | low — it manufactures them | colony **buys** |
| Lumber | low | low | **no trade** |
| Food | moderate | low — grown at home at scale | **no trade** |

The colony exports raw goods and imports manufactures because the valuations say
so. That is the age of colonialism emerging from a price table.

### What the natives value: the craft they do not have

They are not short of land or its fruits. **A thing is valuable to them when
making it requires a craft they cannot do**, and worthless when it does not.

| Native valuation | Resources | Why |
| :--- | :--- | :--- |
| **Very high** | Horses, tools, guns | Immense power, and no way whatever to make them |
| **Moderate** | Rum, beer, clothing | They have no stills, no needles, no spinning — these are genuinely new |
| **Low** | Food, wood, stone, furs, cotton, sugar, tobacco, **tea, cigars**, cows, sheep | The fruits of the land. **A rolled leaf and a dried leaf are still leaves.** |
| **None** | **Iron** | They cannot work it |

That last distinction is the rule doing its job. Cigars and rum are both made
from something the land gives, but **rum needs a still and a cigar needs a pair
of hands.** Only one of those is a craft they lack.

Iron at nothing and tools at everything says the same thing from the other end:
**the value is in the making, not the material.**

**And it moves with their circumstances.** A tribe at war wants guns and horses
far more than a tribe at peace, and §12.5 gives tribes their own diplomacy to be
at war over. The native dictionary is not a fixed table with a hostility gate on
top; the valuations themselves move.

Two consequences worth seeing now, because they shape M5 rather than decorate it:

- **Native trade runs opposite to Crown trade.** The colony sells the Crown its
  raw produce and buys manufactures; it sells the natives manufactures and buys
  their produce. SPEC §11.3 puts natives **first** in Exchange and §10.1 makes
  that trade untaxed, so a tribe that trusts the colony is its **one escape from
  the Crown's monopoly**.
- **The price of that escape is arming them.** The things natives want most are
  guns, tools and horses. SPEC §10.1 already calls guns and tools "especially
  coveted," and this is why.

### The player is never told. He may notice

**Nothing announces a change in what the natives want.** No letter arrives saying
a tribe has gone to war, and none explains why a trade dried up. SPEC §12.5 is
explicit that the inner workings of a tribe stay mostly invisible.

What the player gets instead:

- *They have stopped buying our furs.* A pattern in his own colony's trade.
- A governor or the Diplomat mentioning it, through their own lens.
- Activity on the map, if he is looking.

**This part of the world plays itself.** Tribes fight each other and ask things of
governors whether or not the PC is paying attention, and he sees it coming only
if he is focused and competent about the happenings of the world. It is never
spelled out for him.

That is a deliberate asymmetry with the Crown, which announces everything it does
to him at length.


## 2. The duty is squared across a round trip

Rates are a share of the transaction, so a town is skimmed on **both** legs of
any trade. A fur town selling to buy iron, at a 20% duty:

| | No duty | At 20% |
| :--- | --: | --: |
| Sells 100 furs at 15 | 1500 gold | **1200 gold** |
| Buys iron at 8 with that gold | 187 iron | **120 iron** |

**It keeps `(1 − t)²`.** 64% at a fifth, 36% at two fifths. A rate that reads as
reasonable in a letter comes close to halving the colony's economy, and this is
the arithmetic behind §10.2's "spend the same amount of money and receive less."

**Specialisation is what is exposed.** A town that grows one thing and buys
everything else makes that round trip constantly; a self-sufficient town barely
trades and barely pays. The duty therefore falls hardest on exactly the towns
that make the colony rich — the same shape as the development term in
`rebel-sentiment.md`, and the reason tall is limited by the people you tax.

### Which is a third way the Crown bleeds

`crown-demands.md` says the Crown gains from volume times rate, and bleeds from
rates too low to collect, a colony that refuses to trade, and the PC's promises.

There is a fourth. **A rate high enough kills the trade outright.** When the duty
exceeds the valuation gap, the town keeps its furs — the trade stops being worth
making and the Crown collects nothing rather than more.

So **the Steward can be genuinely wrong.** His bias toward high duties is not
only politically expensive; past a point it destroys the revenue he is trying to
raise. His advice is something the player must learn to discount rather than
merely resent.

## 3. Valuation

One number per town per resource, recomputed every month.

```
valuation(resource)  =  base  +  need

base   =  what the resource is worth to this town in itself.
		  **An authored figure, independent of the Crown's price** — this is
		  the town's entry in §1's dictionary

need   =  how far below desired stock the town is, where

		  desired stock  =  what the coming months' needs require
                          + what the objective requires
                          + what the intent leans toward
						  + what the town's buildings give it a use for
```

**Both halves are necessary and they add rather than multiply.**

Without **base**, a town holding all the furs it needs values furs at nothing,
stops working fur tiles, and can never produce for export. Specialisation would
be impossible.

Without **need**, a town pursues whatever is dearest and ignores its own orders.

**`base` must be its own authored table, not a multiple of the Crown's price.**
Derive it and the gap between town and Crown becomes a function of shortfall
alone — every surplus sells and every shortage buys, whatever the resource, and
lumber behaves exactly like furs. §1's table, where lumber trades in neither
direction because both sides value it alike, cannot fall out of a derived figure.
It needs two independent numbers.

Deriving it also breaks trade outright: if `base` were what the Crown pays, then
valuation is **always at least** the Crown's price, and the sell rule below — sell
when valuation is under what the Crown pays after duty — could never fire once.

And they **add**, because they are different quantities. An objective wanting
forty wood wants forty wood; it does not want it three times as much on account
of wood being valuable. Multiplying would make the objective's pull strongest for
exactly the resources an objective is least likely to be short of.

Read in price units, `need` is a **premium**: for this town, this month, food is
worth more per unit than the market says it is.

**Reserve did not disappear — it became an input.** Desired stock *is* the
reserve, raised by the objective, more broadly by the intent, and per-resource by
buildings. It feeds the `need` half. A military intent does not protect the guns a town has; it raises
desired stock for guns it does not have, and the town goes shopping.

### It drives four things at once

| Question | Answer |
| :--- | :--- |
| Which tiles do we work? | yield × valuation |
| What do we buy? | valuation above the Crown's price plus duty |
| What do we sell? | valuation below what the Crown pays after duty |
| What do we keep? | valuation, which is the gap restated |

This **subsumes** two mechanisms that used to be separate: the objective's
multiplier in tile scoring, and the hunger weight. The objective raises desired
stock, which raises valuation, which raises the tile's score. Food valuation
spikes when a town is short because the gap is large. No special cases.

### And it stops a town drowning in what nobody wants

A forest town's lumber valuation collapses once it is above desired stock with no
buyer, so forest tiles score near nothing and the workers go elsewhere. **The
town simply stops producing lumber.** No storage caps, no spoilage, no targeted
discount — the problem does not arise.

The same town a year later, raising a church, values lumber highly again: it
works forest, and buys from the Crown if it must.

### Timing: valuation is computed before Work

Work is phase 1 and Reckon is phase 2, so Work cannot use Reckon's output. It
does not need to. Desired stock depends on population, the objective and the
intent — all known when the month opens — so **valuation is computed from the
state the month begins with**, Work assigns labour against it, and Reckon then
works out what is *still* short after production. No phase reordering.

## 4. The purse

### How much it spends

Down to a **purse reserve**: gold held back against the needs of coming months.

**Needs override that reserve.** A town that cannot eat this month spends its
last coin, because holding money for next month while starving is not prudence.
The reserve gates comforts and the objective; it never gates survival.

### What it spends on

Every candidate purchase scores **valuation ÷ price**, and the town buys down
that list until the purse reserve stops it. Valuation already carries the
priority — a need far below desired stock has an enormous gap and therefore an
enormous score.

### The tiers favour, they do not gate

SPEC §11.3:

> **🔒 Towns spend mostly in their best interests.** They will favour trying to
> meet their needs, then complete their objectives, then spend on luxuries, but
> they will behave realistically — trying to keep a reserve month to month when
> their survival is not at stake, and spending a little on luxuries even when
> there are more important things to buy.

So the tier is a **heavy multiplier on valuation, not a gate.** A very cheap
comfort can outrank a very expensive marginal need, and a town one coin short of
cloth still buys a little beer.

That is not a leak in the model, it is the same instinct `quality-of-life.md` is
built on: **enough rum and people do not care that they are starving.** The
masking already existed on the consumption side. This is it on the buying side.

A town of 100 gold facing 500 gold of wants therefore spends all 100 — mostly on
whatever is most desperately short per gold, and a little on beer — and goes into
Consume hungry.

## 5. Where a need can actually be met

Five places, in the order the month offers them:

| Phase | How the need is met | What it costs |
| :--- | :--- | :--- |
| **1 Work** | Produce it — a tile, or convert it from something else | Labour, and the tile that worker was not on |
| **3 Relief** | Another town gives it | Nothing, and the giver resents the Crown if it keeps happening |
| **4 Exchange** | Trade with the natives | Goods, and no duty |
| **4 Exchange** | Buy from the Crown | Gold, and the duty |
| **5 Consume** | Eat the herd | The animals, and only for food |

The town asks, in order: *can we make it, will someone give it, can we trade for
it, can we buy it* — and for food alone, *can we eat the herd.* **A need that
survives all five is a shortage**, and Consume charges for it in quality of life
and eventually in population.

## 6. A refused trade is a state, not a price

Some trades are not available at any price, and the reason can change:

- **The Crown may refuse to sell** — guns, while it fears rebellion in the
  colony. That is a policy (`policy.md`).
- **A tribe may refuse to trade** — furs, while it is hostile. That is trust.

Neither is a high price. The row is simply not on offer, and **the town re-plans
down §5's list when it hits one**: refused at the natives, it tries the Crown;
refused by the Crown, it goes without.

Model refusal as a queryable state rather than an infinite price, so a letter can
say *why* and so the condition can lift.

## 7. Working the tiles

Each tile offers an integer number of resources. A town works as many tiles as
its workers allow (SPEC §12.2), choosing the highest scoring.

```
score(tile) = sum over resources of  yield × valuation(resource)
```

**That is the whole rule.** No separate objective multiplier and no hunger
weight — §3 folded both into valuation. Ties break by a rule fixed by the seed.

Because valuation carries **base**, this one score also ranks tiles against
**conversion recipes** in a single list. A recipe always consumes more than it
makes, so without a common unit every conversion reads as a loss; worth is that
unit.

### The survival swap stays

Valuation sets the **ranking**. It does not set a **bound**, and those are
different jobs.

A town short of food values food highly, which is preference. It says nothing
about when to stop moving hands — and a need term that rises and falls as a
granary fills is exactly what churned the workforce before #116 replaced it with
a post-scoring swap that has an explicit stop.

So the swap survives: move a hand onto the shortfall while it helps, and **when
no move helps, accept the deficit.** It is a no-op whenever valuation is already
producing a sensible assignment, and a bounded correction when it is not.

A town that cannot close its food gap therefore reaches a **stable assignment and
goes hungry**, rather than thrashing.

There is **no penalty for producing a surplus of something sellable**, and the
`base` half of valuation is what makes that true. Sell disposes of everything
above reserve every month, so surplus becomes gold, and specialisation is how a
town gets rich. The exception is a town that cannot sell
— under protest, or in rebellion — where the specialty genuinely rots in the
warehouse. That is intended and needs no special handling.

## 8. What the Crown sees

Because the Crown's merchants always profit and the colonists always pay:

**Trade revenue to the Crown is always positive.** In the Ledger, money in is
always trade and money out is always the PC's promises.

**One transaction is not a trade.** A resource shipment requisitioned for the
Crown (`crown-demands.md` §5) moves gold from the Crown to a town and generates
**no duty at all** — there are no merchants in the middle. It is a cost with no
offsetting revenue, which is precisely why an overpaid shipment lets the PC spend
Crown Standing on a town's contentment.

## 9. Buildings

`buildings.md` holds the tree: what each building does, what it costs, what it
costs to keep, and the conversion ratios the economy's prices are balanced
around.

Two rules from it reach into this document. **Upkeep disables an effect without
destroying the building**, so a town too poor to pay watches its own improvements
revert to bare tiles until it can. And **reserve effects are per-resource**, so a
building that gives a town a use for something raises that resource's desired
stock rather than withholding everything — a weaving shed makes the town want
cotton, rather than making it hoard indiscriminately.

## 10. Tuning targets

- **Three price tables.** The Crown's, the natives', and the shape of the town's
  valuation curve.
- **Luxury prices**, with beer cheapest and tea second, and the rule behind the
  ordering: *tea is the cheapest pleasure a town can never make for itself.* Any
  luxury priced below tea must be one the colony can produce, or a town buys that
  instead and tea stops being where taxation bites.
- Desired stock in months of consumption, and the objective, intent and building
  multipliers.
- The purse reserve, and the tier multipliers in §4.
- How steeply valuation rises as stock falls below desired.

## 11. Pinned: production and conversion

**The minimum M2 needed is built** — #64 shipped conversion in the Work phase, so
the six conversions of §10.1 all happen and clothing need not be bought.
`buildings.md` §6 now defines the ratios and which building improves each.

**The larger mechanic remains deferred by the Author** (#92): improvements,
building bonuses, experts, and the full allocation of labour between fields and
town. **Settled already:** conversion competes with tile work for labour. One
worker is in the fields, the other is in a building in the town.

## 12. Open items

- **Deferred by the Author: what moves the Crown's valuations.** Build the lever,
  leave it unpulled. A failed harvest, a die-off, a war at home are the obvious
  drivers and none is designed. **Pulled in M6** (#141), alongside the Crown's
  wars — SPEC §12.4 already says those reach the colony through troop
  availability, demands and treaties, and prices belong on that list.
- **The tea rule has to survive a moving Crown price.** "Tea is the cheapest
  pleasure a town can never make for itself" is a constraint the pricing model
  must respect, not a fact about one table. If a Crown shortage ever prices tea
  above a producible luxury, the trade-protest design quietly stops working.
- How fast the natives' valuations move. Not *whether the player sees it coming* —
  that is settled in §1, and he does not.
- How steeply the tier multiplier falls from needs to wants. Too steep and the
  spec lock is decoration; too shallow and towns drink while they starve.
- Whether a town should ever sell something it still values highly because the
  Crown's price is extraordinary. Currently it will not.
- One number now drives work, buying, selling and keeping. **A tuning error in
  valuation shows up in all four at once**, which is the price of the
  unification. The harness trace is the mitigation.
