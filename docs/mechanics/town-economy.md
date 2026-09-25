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

A single price table was wrong. No ship comes from the Crown carrying wood,
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

### What actually moves the Crown's dictionary

**The seam is already cut and already in use.** `Valuation.crown()` is
`price_of(resource) x PolicyEffects.price_multiplier(state, resource)` — a patron
persuading his Barony to buy your horses arrives that way (`policy.md` §8).
Multipliers compose, so the Crown's own circumstances are another one.

**Two drivers, and one of them already exists.**

| | Where it comes from | Shape |
| :--- | :--- | :--- |
| **The war** | `crown_war_intensity`, which already climbs on campaign and cools between | a standing lift while the Crown is fighting |
| **A shortage at home** | a Crown-month event naming a resource | a sharp lift that decays back |

**The war needs no new state at all.** `CrownAffairs` already runs campaigns,
already moves the intensity, and already emits when one begins and ends. SPEC
§12.4 says the Crown's wars reach the colony through troop availability, demands
and treaties; **this is the fourth channel and it is the cheapest of the four.**

### Appetite is a data field, not a list in code

Each resource carries a **war appetite**, nought by default. The lift is
`1 + appetite x (war / WAR_MAX)`.

Iron, guns, tools, food and horses have one because armies eat and armies are
armed. **Nothing in code names a resource** — the same rule the conversion
recipes already follow, so a new resource that a war should want is a data edit.

### 🔒 The Crown's circumstances move necessities, never pleasures

**No luxury carries a war appetite, and no luxury can be the subject of a
shortage.**

This is what keeps the tea rule safe, and it keeps it safe **by construction
rather than by clamp**. Tea is the cheapest pleasure a town can never make for
itself; if a Crown shortage ever priced it above a luxury the colony can brew,
the town would brew instead of buying and the trade-protest design in SPEC §10.2
would quietly stop working — with nothing failing loudly.

Barring luxuries from both drivers removes that failure mode outright, and it is
truer besides: a Crown at war prices iron, not tea.

### How this sits with the Squeeze

**It is not a fifth dimension of it.** `crown-demands.md` §6's four are all about
what the Crown *takes*; this is what it *pays and charges*, and it moves both
ways.

But the two halves land differently, and `crown-demands.md` §10 carries the
stated interaction: **the war is the Squeeze arriving by a second road** — it
makes the colony's development dearer while the Crown is also asking for more —
and **the shortage is relief of the kind §10 asks for**, because it does not
shrink a demand, it makes one payable.

### Which makes a shortage the interesting half

The war is a slow standing lift on things the colony already sells. **A shortage
is a reversal**, and reversals are the news: the mercantile table below has food
at *Crown values low — grown at home at scale — no trade*, and a failed harvest
turns that row over for a season.

That is the case worth building for, and it is why this is a function.

### The mercantile pattern falls out of the numbers

| | Town values | Crown values | Result |
| :--- | --: | --: | :--- |
| Furs | low — it has plenty | high — scarce and fashionable at home | colony **sells** |
| Tools | high — it needs them and can make few | low — it manufactures them | colony **buys** |
| Wood | low | low | **no trade** |
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
far more than a tribe at peace, and the only war a tribe can be at is with the
colony (`natives.md` §7). The native dictionary is not a fixed table with a
hostility gate on top; the valuations themselves move.

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
wood behaves exactly like furs. §1's table, where wood trades in neither
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

### A bad price is a bad deal, not a loss

Where spare and *worth selling* come apart — a duty high enough that the Crown
nets the town less than it thinks the thing is worth — the town sells anyway if
it is genuinely spare.

**That is not a bug and it is not gold lost.** A town cannot turn furs into coin
by itself; only the Crown buys. So the choice is never *sell at a poor price* or
*sell at a good one*, it is **sell at a poor price or hold furs it has no use
for**. The duty means it got a bad deal, which is exactly what a duty is for.

The instrument the player has is the duty itself, and the town's answer to a duty
it cannot bear is a trade protest (`trade-protests.md`), not a clever sale.

### And it stops a town drowning in what nobody wants

A forest town's wood valuation collapses once it is above desired stock with no
buyer, so forest tiles score near nothing and the workers go elsewhere. **The
town simply stops producing wood.** No storage caps, no spoilage, no targeted
discount — the problem does not arise.

The same town a year later, raising a church, values wood highly again: it
works forest, and buys from the Crown if it must.

### Timing: valuation is computed before Work

Work is phase 1 and Reckon is phase 2, so Work cannot use Reckon's output. It
does not need to. Desired stock depends on population, the objective and the
intent — all known when the month opens — so **valuation is computed from the
state the month begins with**, Work assigns labour against it, and Reckon then
works out what is *still* short after production. No phase reordering.

## 4. The purse

### The Crown can put gold in it

Author's ruling (#400). A town earns by selling to the Crown (SPEC §10.2), and
**the Crown can also give it gold**: a promise of gold (SPEC §9.5) may name a town,
and when the Crown honours it the sum lands in that town's purse. The town is
that much richer, and spends it as it spends everything else.

- **It is a promise like any other.** It is paid while the Crown honours
  payments and broken when it refuses them (SPEC §10.3), and what the Crown pays
  is spending in `net_position` (`crown-standing.md` §2). So it moves standing
  and prestige exactly as any promise of the same gold does.
- **Nothing else is triggered by the town receiving it.** No standing, prestige
  or loyalty change attaches to a purse growing. Whatever a reply option carries,
  such as a clergyman's regard for being answered, belongs to that option.
- **The Ledger shows it as a Crown-side transaction** (SPEC §10.4). Once it is
  the town's, it is hidden like the rest of the purse (SPEC §10.2).

The first letter to use it is the clergyman's request for charity
(`institutional-contacts.md` §3). The quartermaster's broken machines are #438.

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

### Companies eat before the objective

A town that has raised a company **counts its men as mouths** and victuals them
(`battles.md` §3). They sit in a fixed place in the order:

1. **The townspeople's own needs** — food and clothing
2. **Every company the town supports**
3. The objective
4. Wants

So a governor cannot starve his citizens to feed his soldiers, and he cannot raise
a chapel while his men go hungry. **A town cannot disband its way out of famine
either**: if it cannot cover a company it simply sends nothing and that company
goes unsupported, which costs the company and not the purse.

Militia are therefore a **standing charge on the town**, not a lever it can drop
in a bad year — and one more claim on a purse three other tiers are already
pulling at.

### The tiers favour, they do not gate

SPEC §11.3:

> **🔒 Towns spend mostly in their best interests.** They will favour trying to
> meet their needs, then complete their objectives, then spend on luxuries, but
> they will behave realistically — trying to keep a reserve month to month when
> their survival is not at stake, and spending a little on luxuries even when
> there are more important things to buy.

So the tier is a **heavy multiplier on valuation, not a gate.**

### What that does and does not mean

**A town gathering for a build it cannot finish still buys its beer.** That is the
property, and it is the one the spec describes — *spending a little on luxuries
even when there are more important things to buy*. The more important thing is the
**objective**.

**A starving town does not.** An unmet need scores around twenty times what a
comfort does, and there is no tuning at which a comfort outranks it that does not
also put drink ahead of grain in a famine. The spec is careful here too: it asks
for a reserve kept *"when their survival is not at stake"*, which says plainly
that survival is a different case.

An earlier draft of this section claimed a town one coin short of cloth still
buys beer. **It does not, it should not, and no value of the comfort allowance
makes it true without making a famine absurd.**

### There is still no gate

Nothing in the code forbids buying comfort while a need is unmet. Comfort loses
to a need **on the arithmetic**, not on its position in a list — which is what
keeps the objective case working, and is mutation-checked: putting a strict gate
back fails the test.

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

## 11. Production, and the Convert phase

### What a tile gives

Yields are **data twice over**: a terrain says it is *high* in wood, and a
separate table says what high is worth.

```
none 0    low 1    medium 3    high 6
```

Balancing every forest in the game is then one number rather than seven files
that have to agree. A worker eats **1 food** a month, so a hand on high-food
plains feeds six and a hand on medium grassland feeds three. That ratio is the
foundation the whole colony sits on.

```
yield = tile level  x  expert multiplier  x  (1 + building bonus)
```

**Experts multiply, and stack with diminishing returns** (SPEC §12.2). The first
is worth +25%, and each after is 0.6 of the one before — so +25%, +15%, +9%. It
applies to tiles and to conversion output alike, because it is a fact about the
people rather than about the ground or the terms.

**Building bonuses are proportional, not flat.** A sawmill at `wood +0.6` raises
every wood yield in the town by 60%. So a yield building is worth more the more a
town already commits to that resource — it rewards specialisation rather than
propping up a town that has none, which is what makes stonecutters and sawmill a
real choice about what a town is going to be.

### Convert is its own phase

**Conversion is not part of Work.** Work sends hands to tiles and holds the rest
back for town work; **Convert** runs later, between Consume and Build.

| | |
| :--- | :--- |
| **Work** (1) | assigns hands — tiles and recipes ranked in one list — and harvests |
| **Consume** (5) | people eat, livestock eat, clothing wears |
| **Convert** (6) | the hands held back do their work |
| **Build** (7) | the objective advances |

Three things follow, and each replaces a rule that used to be enforced by
scoring:

**A town cannot brew the grain its people need**, because the grain is already
eaten. This was a weight in the recipe scorer; now it is arithmetic that cannot
be got wrong.

**This month's ore can be this month's iron, and go into this month's frame.**
Convert sits after Exchange, so a town may buy ore and smelt it rather than
buying iron — which dodges the higher duty on the processed good, and is a piece
of tax arbitrage worth leaving in.

**Processed goods are a month behind.** Beer brewed in phase 6 is drunk next
month; cloth woven in phase 6 is worn next month. Buying rum from the Crown
comforts a town *now* and brewing comforts it later, which is a real reason to
trade rather than make. The cost is that Work's survival swap can no longer fix a
**clothing** shortage in the month it happens — no tile yields cloth, so a cold
town's remedies are relief, purchase, or next month's loom. Accepted: cloth takes
time to make.

### 🔒 Every recipe draws the stockpile as Convert began

Outputs are written to the real stockpile and are **invisible to other recipes
this month**.

Without this, a town holding twenty ore with hands at the forge and the toolworks
turns ore into tools in a single month, and `buildings.md`'s deep chain — the one
the gunsmith gates — collapses to one step. Worse, the answer would depend on
**which recipe the loop reached first**, which is a result depending on iteration
order and forbidden outright.

The snapshot makes order irrelevant by construction, exactly as the Colony Month
makes every town finish a phase before any town begins the next. It is also the
mechanism that already exists: Work seeds an allowance from the stockpile and
spends it down so two recipes cannot smelt the same ore. **Only the moment it is
seeded moves** — from the top of Work to the top of Convert.

### Deciding who stays in town

Work still ranks tiles and recipes **in one list**, which is what makes a town
with furs, no spare ground and cold people send hands to the loom without a rule
saying so. What changes is that Work **assigns rather than executes**.

It scores recipes against the stockpile **net of what the town is about to eat**,
or it would see forty food, post a brewer, watch Consume eat thirty, and leave him
almost nothing to do. The estimate stops hands being stranded; the phase order
guarantees correctness when the estimate is wrong.

Conversion buildings raise the **reserve months of the raw input**, so a town that
invests in conversion is already told to hold a buffer of what it converts. The
one-month link in a chain draws on that stock rather than on a hand-to-mouth
trickle, which is why it does not read as a stall.

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
