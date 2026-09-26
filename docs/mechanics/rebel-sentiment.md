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

**Since #230 the return reads quality of life directly** (§5): a rebel town comes
back when life is worse than it was under the Crown. That is the same principle
said more plainly, and it cannot flicker.

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

There is no separate "base" and "modifier" machinery. **Tax burden dominates in
steady state** — measured as the loudest contributor in 95.7% of town-months over
600 — and grievances spike on top, so it *reads* as a base with spikes. But a new
grievance is just another contributor and there is no special case to maintain.

Two ceilings exist and are worth knowing about while tuning: **a cap on any single
month's tax contribution**, and **a cap on the stakes** (§6).

Sentiment is memoryless in the same sense quality of life is: the formula has no
carry-over, but several of its inputs accumulate on their own.

## 4. The contributors

| Contributor | Kind | Source |
| :--- | :--- | :--- |
| Tax burden, weighted by tier | standing | §10.2 |
| Grievances | timed | §12.3, §11.3 |
| Contact influence, scaled by prominence | standing | §8.2 |
| A seditious governor | standing | §8.2 |
| An embargo laid on the town | standing | §12.3 |
| Quality of life | standing | §12.3 |
| A rebelling neighbour | standing | §12.3 |

And one that is **not** a contributor, though it looks like one:

| | Kind | |
| :--- | :--- | :--- |
| Development | **a gain on the sum** | §6 |

### Tax burden

§10.2 is precise about this: towns resent tax **as they pay it**, per transaction,
not as the rate is set. A town that buys nothing pays nothing and resents nothing.

Weight each taxed transaction by the tier it served (§11.3's Reckon):

| Tier | Weight | Why |
| :--- | :--- | :--- |
| **Needs** — food, clothing | heavy | they had no choice |
| **The objective** | medium | they wanted it, but the governor chose it |
| **Wants** — luxuries | light | they could have gone without |
| **A sale** | lightest | see below |

**Duty is charged twice in this game** — on the way in and on the way out
(§2's squared round trip) — and a sale is not one of Reckon's tiers at all. So
there is a fourth bucket for it, weighted lightest of the four:

> **A town selling surplus is not cornered. It is being clipped on the way out.**

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
- **Harsh orders**, with two rules of their own — below
- Military abuses, which are M6 and authored but unraised
- Giving more in Relief than the town receives, repeatedly (§11.3)

**Grievances decay rather than expiring flat.** A sentiment that drops several
points in one month for no visible reason is confusing, and the Diplomat has to
be able to describe a trend truthfully. Linear decay over the grievance's life.

Note the double duty of a refusal: it costs the governor's loyalty *and* it raises
the town's sentiment, because the people learn the Crown would not help them.

#### Harsh orders

**Declared by the letter, never inferred from the order.** Which rung of an order
counts as harsh is a thing the **prose says**, because the PC chose that wording
knowing what it was. Nothing reads a quantity and decides the PC was cruel.

**And the grievance lands only if the town bore it.** A governor who refuses to
strip his own stores has spared his people, and there is no grievance to raise —
**his loyalty pays for the order instead.** The people resent what happened to
them, not what was written about them.

### Contact influence

Every colony contact **resident in a town** pushes its sentiment, scaled by their
loyalty to the PC and by their **prominence**. Low loyalty pushes up; high loyalty
pushes down.

**Prominence is how large a man looms in his town** (`contacts.md` §1), derived
from his role with a per-contact override in the data. The governor weighs heavily
because **his office is a large one, not because the code asks whether he is the
governor** — which is what lets a particular clergyman be a firebrand without any
code knowing he is unusual.

One rule, and it keeps working as M7 adds institutional contacts. Being a jerk to
the clergyman is mechanically dangerous, which is as it should be.

**It cuts both ways.** If the famous men of a town are all loyal to the Crown
there is not much rebel sentiment in it — and the same men slighted are what
carries the town out.

### A seditious governor

A governor who has taken the **rebellion intent** (`governor-objectives.md` §4)
adds on top of whatever his regard already contributes, folded into the same
term.

**A man who has decided is not the same as a man who is sullen.** One is an input
to the town's mood; the other is organising it.

### An embargo laid on the town

Punishment (§12.3) raises the sentiment of the town it falls on, as its own
standing part — and lowers a rebel town's persuasiveness elsewhere while it is
being punished (§5). Both halves are the same instrument seen from two sides.

### Quality of life

Read through attribution (§2), not directly. Misery the Crown caused raises
sentiment; misery the rebellion caused lowers it.

### Development is not here, and §6 says why

It looks like a contributor and it is not one. See §6.

### A rebelling neighbour

§12.3: a rebel town strongly raises sentiment in the others, **especially while it
looks prosperous and unpunished.** Scale it by the rebel town's quality of life
and by whether it has been meaningfully punished. A rebel town being ground down
by Crown troops is an argument *against* rebellion, and should read as one.

## 5. Rebellion, and coming back

Author's ruling (#230). Illustrative numbers, **all tuning**.

```
sentiment >= 65                           the town declares rebellion
quality of life < what it was at declaring   a rebel town returns to the Crown
```

### Declaring is unchanged

A loyal town declares when its sentiment reaches 65.

### In rebellion, life gets better, and then worse

**The month it declares, the town is free of the Crown's duty, and happier for
it.** For as long as it is out, its quality of life carries a **lift of +0.2**
(a placeholder, `quality-of-life.md` §3). The taxes stay gone, so the lift
stays.

**Then life gets worse, for real reasons.** The Crown will not trade with a rebel
town, so it cannot buy food, clothing or luxuries. Its stores run down (health,
pleasure), its objective starves of what it would have bought (hope), and the
Crown's troops are hostile where they were its guardians (safety). A duke's
backing (`rival-pressure.md` §8) is what can hold that off.

### It comes back when life is worse than under the Crown

**A rebel town returns the month its quality of life, lift included, falls below
what it was in the month it declared.** SPEC §12.3: a rebel town goes back *once
its people believe life was better under the Crown.*

The lift is what makes that take time. The town has to lose the whole of its tax
relief, and then some, before it regrets going.

**This replaces the return at sentiment 45.** That was a hysteresis band, and it
could not hold. In the month after a town declared, tax went to nothing, the
quality term changed sign, neighbours stopped counting and the stakes lost their
trade half, all at once. A town that declared at 65 read near nought the month
after and came straight back: 129 to 135 round trips in eight years, in the runs
#230 measured.

**Sentiment is still measured in a rebel town**, attribution and all (§2), and
the Diplomat and the letters still report on it. It no longer decides the
return.

### A town that comes back is garrisoned for a year

**Whenever a town comes back, peacefully or retaken (`battles.md` §9), the
Marshal quarters a garrison on it for 12 months.** It is a Crown troops policy
(`the-marshal.md` §2) at garrison strength, holding that town, and **the PC bears
its whole charge.** Nobody asks for it; the Crown sends it.

**While the garrison stands, the town cannot declare.**

- After 12 months it sails home, and the town may declare again.
- **If it is gone sooner**, whether destroyed by a duke, natives or anyone else,
  or sent home because the policy lapsed unpaid (`policy.md` §4–§5), **the bar
  ends with it.**

### And the loop runs both ways

If the town holds out (well supplied, backed by a duke, beating what is sent),
its life stays above what it had under the Crown, and it stays out. Its
neighbours see a rebel town that is prosperous and unpunished, and the spread
term (§4) does the rest. The lift makes a new rebellion look its most prosperous
in its first months, which is exactly when it persuades most.

**A rebellion that is not being put down is an advertisement.**

## 6. Development raises the stakes

**Development is not a contributor. It is a gain on the sum of everything else.**

```
sentiment = stakes(development) x (standing contributors + active grievances)
```

A town with more buildings, more institutional contacts and more trade volume has
more at issue — so whatever its people and its notables feel, they feel it
*louder*. It amplifies in **both directions**, which is the whole reason it cannot
be a term in the sum.

**A developed town with contented people and loyal notables is held down harder
than a hamlet could ever be.** An additive term could never say that; it could
only ever make a large town more rebellious than a small one, whatever else was
true. The printing press is still the mechanic in one image — a building that
brings a contact *and* raises sentiment — but now it is raising the volume rather
than adding a fixed quantity of grievance.

**The stakes are capped** (§3), so a very large town is loud rather than
unmanageable.

## 7. What the player sees

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

## 8. Tall and wide fail differently

Nothing extra is needed to make a large town harder to govern. It falls out: more
tax paid, more notables with opinions, and §6's stakes multiplying all of it.

**But it does not simply make a large town more rebellious.** A prosperous,
well-run, fairly-taxed city is held *more* firmly than a hamlet, because the
stakes cut both ways. What a large town does is make the PC's rule **matter more
either way** — the ruin is worse and so is the reward. A cluster of small
harvesting towns is merely quiet.

> **Wide is limited by the people you displace. Tall is limited by the people you
> tax.**

Expansion is checked by §11.4's tribes, offended in proportion to the intrusion,
and by §12.4's rivals. Development is checked by this document. Two different
failure modes, so neither strategy dominates.

## 9. Tuning targets

**Baseline, measured after #186 and #190.** Not a target and not a pass mark —
the model gains more inputs before ship — but the dates below now have a figure
to move against. Threshold to declare is 65.

| | steady hand | the tyrant, year 7 |
| :--- | --: | --: |
| mean sentiment | 8.6 | 35.6 |
| worst town | 8.6 | 47.9 |

No rebellions in either profile.

Tied to SPEC §6.2:

- **Year 1:** rebellion is not a live concern for a sensible player.
- **End of year 2:** at least one town should be somewhere the Diplomat feels
  moved to mention.
- **Years 4–8:** rebellion is the most likely thing to end a run.
- A player who raises taxes sharply and refuses requests should see a first
  rebellion in years 2–3, not sooner.

Everything in §5 is a tuning value, as are all contributor weights and grievance
durations: the rebellion lift, and the garrison's length and strength, included.

## 10. Open items

- Whether the **stakes** should count buildings, trade volume, or both, and
  whether particular buildings carry particular weight. A printing press earning
  more than a granary is good flavour and more content to author.
- Grievance magnitudes. A single refusal putting a town a meaningful fraction of
  the way to rebellion is dramatic but may be too lethal — two refusals in a year
  should probably not rebel a contented town.
- Whether a rebel town's sentiment should have any floor, or whether sustained
  misery can return a town that the player has done nothing to win back.
- Whether prominence should be visible to the player at all, or remain something
  he infers from whose letters carry weight.
