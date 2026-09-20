# Mechanics — Quality of Life

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 (Quality of Life), §10.1 (luxuries), §12.1
> (immigration), §12.3 (rebel sentiment), and the satire in §3.2.

---

## 1. What it is

A value in `[0, 1]` **scoped to one town**, representing how pleasant or
miserable the average citizen's life is. The governor wants it high (§11.3).

It is read by immigration (§12.1), by rebel sentiment (§12.3, from M3), and by
every governor letter. It is never shown to the player as a number.

## 2. Memoryless, but the inputs remember

**QoL is a pure function of this month's state.** There is no carry-over term, no
smoothing, no inertia. Last month's QoL does not appear in this month's
calculation.

It is nonetheless stable, because most of what feeds it cannot move quickly. Food
stockpiles accumulate over months. Objective progress accumulates. Town gold
accumulates. A large swing therefore requires several things to change at once —
which is exactly what happens when something dramatic happens to a town.

**Do not add a smoothing term.** The stability is supposed to come from the
inputs, not from the formula. A smoothed QoL would blunt the one case the design
needs to land hard: a town being attacked.

## 3. The shape

```
substance = w_health * health
          + w_safety * safety
          + w_means  * means
          + w_hope   * hope           // weights sum to 1

QoL = substance + PLEASURE_LIFT * pleasure * (1 - substance)
```

Two decisions are encoded here, and both matter.

**Substance is a weighted sum, not a product.** Health does not gate the others.
A town with five decent things going for it absorbs the loss of one; a town
propped up by a single component collapses when that component goes. This is why
the same raid devastates a struggling town and merely bruises a thriving one.

**Pleasure masks rather than adds.** It lifts the town a fraction of the way from
wherever it stands toward contentment, so **its power is greatest when life is
worst.** A thriving town gains almost nothing from more rum. A wretched town
gains enormously.

That is not a logical assessment of the situation. It is human nature, and it is
the point.

## 4. The five components

Each resolves to `[0, 1]`.

### Health

Can people eat and stay warm.

- **Food security** measured against a target *reserve*, not against this month's
  consumption. Eating exactly enough every month is not the same as being secure,
  and "ample food in the larder" is what a high-QoL town has.
- **Livestock count toward the buffer** at a conversion rate, because a town that
  would otherwise go hungry will eat them (§12.2). This is what makes livestock
  matter before M4's pastures exist.
- **Clothing** sufficiency against population.

### Safety

Is the population being attacked, and is it safe to travel to other towns.

**Constant at 1.0 for all of M2.** Natives arrive in M5 and military in M6. It is
a component that does nothing for two milestones and then matters enormously —
see §6.

### Means

Gold per capita against a target, so the town can buy what it wants when the
ship docks.

This is the **only** route by which hidden town gold (§11.3) becomes perceptible
to the player. They never see the number; they see a governor who sounds
comfortable or pinched.

### Hope

Not "how far along is the objective" but **"is anyone addressing what we
actually need."**

```
hope = FITNESS_SHARE * fitness + PROGRESS_SHARE * progress
```

- **Fitness** — does what the town is doing address its largest unmet need, as
  Reckon computed it, worst-first? A starving town building cannons scores near
  zero. A starving town building farms, or begging the Crown for the means to,
  scores high.

  **The bare intent counts, not only the project.** Fitness takes the better of
  two readings: the objective addressing the need, or `INTENT_SHARE` times the
  *intent* addressing it. A governor who has resolved to feed his people earns
  most of the credit the month he resolves it, before any project serving that
  resolve has been chosen.

  This is what makes the claim below true rather than aspirational. Under an
  objective-only fitness, hope could not move until the next Settle chose a new
  project — a month later — and writing to a governor would be the *slowest*
  lever rather than the fastest.

  **A town with no unmet need scores 1.0.** A comfortable town does not resent
  its governor for building a church.
- **Progress** — is it actually moving? A town stalled four months at 80% has
  little hope; a town visibly advancing at 20% has more.

  **Idle months divide rather than merely failing to add**: progress is the
  completed fraction over `1 + idle months`, so standing still actively erodes
  hope instead of holding it. A **standing posture** has no fraction to report
  and sits at 0.5 — it is neither advancing nor stuck, the town simply does it.

**Fitness weighs more than progress.** A town forgives slow work on the right
problem far more readily than fast work on the wrong one. This is where the
town's judgement of its governor lives: not trust built from past behaviour, but
a reading of his intent right now.

It also gives the PC a fast lever. Writing to the governor to change the
objective raises hope as soon as he adopts it, well before anything is finished.

### Pleasure

Luxury consumption: sugar, tobacco, tea, rum, cigars, beer — **and amusement**,
which is pleasure that arrives without a ship (`buildings.md` §7).

Scaled by the fraction of the population served, with a **variety bonus** — beer
alone is worth less than beer, rum and tea together.

```
pleasure = served * (VARIETY_FLOOR + (1 - VARIETY_FLOOR) * min(kinds / VARIETY_TARGET, 1))
```

**Amusement joins both numbers, and it is one kind however much of it there
is.** A theatre adds to how much of the town was served *and* counts as a kind,
so it is a full participant in variety. A **second** amusement building — a
fairgrounds beside the theatre — adds only to `served`. Amusement is already
being consumed; more of it is deeper, not wider.

That makes amusement behave exactly as a luxury does, which is the point: a town
with beer, rum and a theatre reaches full variety just as one with beer, rum and
tea does. **A colony can build its way to part of what it would otherwise have to
buy**, and tea competes on `served` and on price rather than on being
irreplaceable. Author-confirmed as intended.

### One draw, read by two phases

`marginal_pleasure()` — what another measure of something would be worth — is the
same computation Consume uses when the town actually drinks. **The buying side
and the drinking side must not hold two theories of what a cellar is worth**, or
a town buys a heap of beer and wonders why it feels no better for it. Exchange
scores luxuries by marginal quality of life per gold through this one function.

Note what this does to **tea**. §10.1 says the colony can never produce it, so it
comes only from the Crown. The variety bonus therefore makes tea the luxury a
prosperous town most wants and most depends on trade for, which means taxing tea
hurts a comfortable town exactly where it is softest. §10.2's "tea is favored to
be one of the first trade protests" then falls out of the mechanics rather than
being hardcoded, which is what that section says should happen.

## 5. Worked

Starting weights — all tuning, all to be revised against the harness:

```
w_health 0.30   w_safety 0.25   w_means 0.20   w_hope 0.25
PLEASURE_LIFT 0.45
FITNESS_SHARE 0.65   PROGRESS_SHARE 0.35   INTENT_SHARE 0.7
SECURE_MONTHS 3.0    FOOD_SHARE 0.7       COMFORTABLE_PURSE 30.0
VARIETY_TARGET 3.0   VARIETY_FLOOR 0.6
```

`SECURE_MONTHS` is the food reserve health measures against and `FOOD_SHARE`
splits health between the larder and the wardrobe. `COMFORTABLE_PURSE` is the
gold per head `means` treats as comfortable.

### While safety is inert, drop it and renormalise

Safety is pinned at 1.0 until M5 (§4). Left in the sum it contributes a flat
`0.25` every month, which **puts a floor of 0.25 under every town in the colony**
and compresses the usable range into the top three quarters of the scale. The
harness confirms it: quality of life never left 0.91–0.98 across 400 runs, so the
perception ladders had one reachable rung and every governor letter about it said
the same word.

So **until safety is a live component, exclude it and renormalise the other
three:**

```
w_health 0.40   w_means 0.267   w_hope 0.333
```

**The code derives these rather than carrying them.** `live_weight()` sums the
weights of the live components and each component divides by that, so the
authored numbers stay 0.30 / 0.25 / 0.20 / 0.25 and nothing hardcodes 0.40 where
0.30 is written. Restoring safety is one flag, not five edits.

Same relative balance between them, full 0–1 range reachable. The worked example
below then reads 0.91 / 0.21 / 0.56 for thriving, struggling and starving-drunk,
against 0.93 / 0.41 / 0.58 with safety pinned in.

**This widens the range; it does not by itself create variation.** A town whose
health, means and hope all sit near 1.0 still scores near 1.0. Movement needs the
colony to actually struggle, which is M3's pressures landing (#90).

When M5 brings safety alive, put it back and renormalise again — and revisit the
weighting as a whole at that point rather than simply restoring these numbers,
since combat reaches quality of life through more than one component.

These use the **full five-component weights**, because the raided rows are what
demonstrate why substance is a sum rather than a product. Under the interim
weights above, safety is absent and the raided rows collapse into their
unraided ones.

| Town | health | safety | means | hope | pleasure | substance | **QoL** |
| :--- | --: | --: | --: | --: | --: | --: | --: |
| Thriving | 1.0 | 1.0 | 0.8 | 0.7 | 0.9 | 0.89 | **0.93** |
| Thriving, raided | 1.0 | 0.3 | 0.8 | 0.7 | 0.9 | 0.71 | **0.83** |
| Struggling | 0.35 | 1.0 | 0.2 | 0.05 | 0.0 | 0.41 | **0.41** |
| Struggling, raided | 0.35 | 0.3 | 0.2 | 0.05 | 0.0 | 0.23 | **0.23** |
| Starving and drunk | 0.1 | 0.3 | 0.5 | 0.1 | 1.0 | 0.23 | **0.58** |

**The two raids cost the same absolute substance and land completely
differently.** The thriving town slips from 0.93 to 0.83 and carries on: there is
food in the larder, the church is going up, and the tavern is still open. The
struggling town falls from 0.41 to 0.23, because safety was nearly all it had.

**The starving drunk town scores higher than the struggling sober one.** That is
correct and deliberate.

## 6. Safety, rebellion, and the player's foothold

When a town rebels, the Crown stops being its guardian and becomes its enemy.
Safety falls, and QoL with it.

**This is the PC's foothold for quelling a rebellion.** Life under rebellion is
demonstrably worse, QoL feeds rebel sentiment (§12.3), and the sentiment falls.

But the loop runs both ways. If the town survives the danger — it beats the
troops, or the PC has no more troops to send — its safety re-establishes, QoL
recovers, and neighbouring towns see a rebel town that is prosperous and
unpunished. §12.3 says sentiment then spreads strongly, and this is the mechanism
by which it does.

So **safety is not "is this town at war."** It is "is this town threatened by
forces it cannot handle." A rebel town that has beaten what was sent against it
is safe, and that is precisely when it becomes most dangerous to the colony.

## 7. The acyclicity rule

QoL feeds rebel sentiment, so it must not read it.

**QoL may read facts about the world — was this town attacked, were the roads
cut, is this town in rebellion. It may never read the rebel sentiment value
itself.**

That keeps the computation acyclic within a month while still allowing the
multi-month spiral of §12.3, mediated through things that actually happened
rather than through a number reading itself.

## 8. What this predicts, and what to watch

**The rum trap.** The cheapest way to raise a miserable town's QoL is luxuries,
not food. A player who notices can paper over a dying colony: consumption still
removes population through famine (§11.3), so the town shrinks while reporting
good spirits, and the governor's letters will say so honestly because they are
true. This is the satire working, and it should not be patched out. It should be
watched to confirm it is a trap a player can learn, rather than a dominant
strategy that trivialises the colony.

**Hope is the fastest lever the PC has.** Objective fitness responds the month a
governor adopts a new objective. Expect players to discover that redirecting a
town is more immediately effective than supplying it. That seems right — it is
rule by correspondence — but if it is *too* strong, lower `FITNESS_SHARE` before
touching anything else.

**Safety is inert until M5**, and is excluded from the sum until then (§5). Two
milestones of tuning will happen without it, and then a whole component comes
alive at once. The Author has asked that this be treated as a fresh look at how
combat reaches quality of life, rather than a restoration of the old weights.

## 9. Open items

- Every constant above. They are a starting point, not a design.
- Whether pleasure should saturate below 1.0 — see below.
- The target food reserve, in months, currently three. This single number does
  more to set the colony's difficulty than any other value here.
- Whether `means` should scale its target with the colony's price level, once
  prices exist as more than a constant.
- Whether pleasure should saturate below 1.0, so that no amount of rum fully
  masks starvation. Currently it does not, and the worked example above is the
  consequence.
