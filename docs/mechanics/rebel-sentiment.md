# Mechanics — Rebel Sentiment

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §12.3, §10.2 (taxes), §11.3 (Relief, Settle), §13.1
> (Independence), and the Squeeze pillar in §2.

---

## 1. What it is

A value per town. It is the gauge behind one question:

> **"Would we be better off without the Crown in our lives?"**

It starts at zero. As it climbs, the Diplomat takes notice, the governor drops
hints and his tone changes, and his loyalty visibly slips. Past a threshold the
town declares rebellion (§12.3).

It is **the colony-side jaw of the Squeeze**, opposite Crown Standing. The Crown
presses from one side and the colonists press from the other, and the PC stands
between them.

## 2. The organizing principle: attribution

**SPEC §12.3 locks this as of v2.0:**

> **🔒 Sentiment measures who is blamed, not how bad life is.** Suffering the
> Crown caused raises it; suffering the rebellion caused lowers it.

It is what reconciles §12.3's "shortages raise sentiment" with §12.3's lock that
rebel towns can return peacefully — without it, a rebelling town's worsening life
would drive it further away and no town could ever come home.

| Situation | Blamed | Sentiment |
| :--- | :--- | :--- |
| Loyal town squeezed by taxes and denials | the Crown | **rises** |
| Rebel town starving, trade gone, troops at the gate | the rebellion | **falls** |
| Rebel town prosperous and unpunished | nobody — it is working | **stays high, and spreads** |

This is already what §12.3 describes without explaining why. "Defeats suffered at
the hands of crown troops" *lowers* sentiment, and rebellion spreads "especially
while it looks prosperous and unpunished." Neither is about misery. Both are
about whether rebelling is working.

## 3. The shape

**One weighted sum, computed fresh each month. Each contributor is either
standing or timed.**

```
sentiment = sum of standing contributors
          + sum of active timed grievances
```

There is no separate "base" and "modifier" machinery. In practice tax burden
dominates in steady state and grievances spike on top, so it *reads* as a base
with spikes — but a new grievance is just another contributor, and there is no
special case to maintain.

Sentiment is memoryless in the same sense quality of life is: the formula has no
carry-over, but several of its inputs accumulate on their own.

## 4. The contributors

| Contributor | Kind | Source |
| :--- | :--- | :--- |
| Tax burden, weighted by tier | standing | §10.2 |
| Grievances | timed | §12.3, §11.3 |
| Contact influence | standing | §8.2 |
| Quality of life | standing | §12.3 |
| Development | standing | Author |
| A rebelling neighbour | standing | §12.3 |

### Tax burden

§10.2 is precise about this: towns resent tax **as they pay it**, per transaction,
not as the rate is set. A town that buys nothing pays nothing and resents nothing.

Weight each taxed transaction by the tier it served (§11.3's Reckon):

| Tier | Weight | Why |
| :--- | :--- | :--- |
| **Needs** — food, clothing | heavy | they had no choice |
| **The objective** | medium | they wanted it, but the governor chose it |
| **Wants** — luxuries | light | they could have gone without |

**This subsumes §10.2's luxury rule rather than duplicating it.** Luxuries are
bought in the wants tier and therefore weigh least automatically, so "luxury taxes
cause much less rebel sentiment" stops being a special case and becomes a
consequence of where the purchase sat.

It also means taxation only bites where a town is *cornered*. Tax food in a town
that grows its own and nothing happens; tax it in a town that must buy it and the
resentment is immediate.

### Grievances

Timed contributors raised by discrete events. §12.3 and §11.3 between them name:

- A refused request — the Crown did not help when asked
- A broken promise, including one broken by Crown Standing (§10.3)
- Harsh orders
- Military abuses
- Giving more in Relief than the town receives, repeatedly (§11.3)

**Grievances decay rather than expiring flat.** A sentiment that drops several
points in one month for no visible reason is confusing, and the Diplomat has to
be able to describe a trend truthfully. Linear decay over the grievance's life.

Note the double duty of a refusal: it costs the governor's loyalty *and* it raises
the town's sentiment, because the people learn the Crown would not help them.

### Contact influence

Every colony contact **resident in a town** pushes its sentiment, scaled by their
loyalty to the PC. Low loyalty pushes up; high loyalty pushes down.

- **The governor weighs heavily.** He is the town's leader and its voice.
- **Everyone else weighs lightly** — the clergyman from the church, the
  quartermaster from the armoury.

One rule, and it keeps working as M7 adds institutional contacts. Being a jerk to
the clergyman is mechanically dangerous, which is as it should be.

### Quality of life

Read through attribution (§2), not directly. Misery the Crown caused raises
sentiment; misery the rebellion caused lowers it.

### Development

**Prosperity breeds the thing that destroys it.** A town with more buildings, more
institutional contacts and more trade volume carries more sentiment for all three
reasons at once.

A printing press is the mechanic in one image: a building that brings a contact
*and* raises sentiment, which is roughly what printing presses did.

### A rebelling neighbour

§12.3: a rebel town strongly raises sentiment in the others, **especially while it
looks prosperous and unpunished.** Scale it by the rebel town's quality of life
and by whether it has been meaningfully punished. A rebel town being ground down
by Crown troops is an argument *against* rebellion, and should read as one.

## 5. Rebellion, and coming back

Illustrative numbers. **All tuning.**

```
sentiment >= 65   the town declares rebellion
sentiment <= 45   a rebel town returns to the Crown
```

The gap is hysteresis, for the same reason crown standing has it: a town that
flickers between rebellion and loyalty month to month is noise, not drama.

### Under rebellion, the sign flips

A rebel town stops paying tax, so the largest standing contributor **goes to
zero**. It stops being refused by a Crown it no longer asks. Meanwhile its quality
of life falls — trade is gone, and the Crown's forces are hostile where they were
once its guardians.

Under attribution, that falling quality of life now **lowers** sentiment, because
the rebellion is visibly what caused it.

**That is the PC's foothold**, and it is the whole reason §12.3's peaceful return
is achievable rather than decorative.

### And the loop runs both ways

If the town survives — it beats what was sent, or the PC has no more troops to
send — its safety re-establishes, quality of life recovers, and sentiment stops
falling. Its neighbours now see a rebel town that is prosperous and unpunished,
and §12.3's spread term does the rest.

**A rebellion that is not being put down is an advertisement.**

## 6. What the player sees

Nothing numeric, ever. Sentiment surfaces three ways:

1. **The Diplomat** reports on it, through his own perception ladders.
2. **The governor's tone shifts** and he begins dropping hints.
3. **His loyalty visibly slips**, which the player can feel in compliance.

### The Diplomat lives somewhere

He is aware of all towns but **housed in one**. When his town's sentiment climbs
he writes asking to be rehomed somewhere friendlier.

For that to be a decision rather than a chore it needs a cost, so **his reports on
his home town are sharper** — tighter ladders, more specific detail — while his
reports on the rest stay general. Refusing to move him keeps your best eyes on the
fire at the risk of losing the man; agreeing goes half-blind on the town you are
most worried about.

He is killed only if the PC **refuses to move him out of a town that then
rebels**, or if every town rebels and there is nowhere friendly left. His death
is a consequence of a decision, never ambient bad luck.

SPEC §8.1 carries this as of v2.0. `docs/mechanics/the-diplomat.md` has the full
mechanic.

## 7. Tall and wide fail differently

Nothing extra is needed to make a large town more rebellious. It falls out:
more buildings, more institutional contacts, more trade volume, more tax paid.
A cluster of small harvesting towns has almost none of that.

> **Wide is limited by the people you displace. Tall is limited by the people you
> tax.**

Expansion is checked by §11.4's tribes, offended in proportion to the intrusion,
and by §12.4's rivals. Development is checked by this document. Two different
failure modes, so neither strategy dominates.

## 8. Tuning targets

Tied to SPEC §6.2:

- **Year 1:** rebellion is not a live concern for a sensible player.
- **End of year 2:** at least one town should be somewhere the Diplomat feels
  moved to mention.
- **Years 4–8:** rebellion is the most likely thing to end a run.
- A player who raises taxes sharply and refuses requests should see a first
  rebellion in years 2–3, not sooner.

Everything in §5 is a tuning value, as are all contributor weights and grievance
durations.

## 9. Open items

- Whether development should count buildings, trade volume, or both, and whether
  particular buildings carry particular weight. A printing press earning more
  than a granary is good flavour and more content to author.
- Grievance magnitudes. A single refusal putting a town a meaningful fraction of
  the way to rebellion is dramatic but may be too lethal — two refusals in a year
  should probably not rebel a contented town.
- Whether a rebel town's sentiment should have any floor, or whether sustained
  misery can return a town that the player has done nothing to win back.
- How punishment (§12.3's embargoes and penalties) enters the model. It should
  raise sentiment in the town punished while lowering the spread term elsewhere,
  since the neighbours are watching.
