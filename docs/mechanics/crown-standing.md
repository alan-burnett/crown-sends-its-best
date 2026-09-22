# Mechanics — Crown Standing

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.2, §10.3, §9.5 (promises), §5 (the "it's my first day"
> perk), and the Squeeze pillar in §2.
>
> **Does not settle:** how prestige is scored. `prestige.md` §3 owns that, and
> settled gold's share of it in v2.2.

---

## 1. Two machines, not one

Crown Standing is **a financial measure**. Payment refusal is **a political
process**. They are separate, and conflating them is the main way to get this
wrong.

- Standing may crash from comfortable to zero in a single month. Nothing stops
  it, and nothing should.
- Refusing to honor the PC's promises is a decision the Crown takes slowly,
  through warnings and deadlines, and it has its own state.

This is what makes SPEC §10.3's locked warning guarantee implementable without
distorting the arithmetic.

## 2. Standing

### The two quantities

```
net_position   cumulative revenue to the Crown minus spending on the PC's behalf
monthly_net    this month's revenue minus this month's spending
```

Revenue is tax income from colony trade (§10.2, both buying and selling).
Spending is what the Crown pays to honor the PC's promises (§9.5).

### The derived one

What the Crown's accountants actually care about is not the size of the hole but
whether it is closing:

```
horizon = |net_position| / monthly_net        // months to recoup at this rate
```

**The PC never has to recoup the debt to recover standing.** He has to look like
he is on track to. That is the whole design.

### Worked

| | net_position | monthly_net | horizon | The Crown's view |
| :--- | --: | --: | --: | :--- |
| Thrifty | -500 | +50 | 10 months | Recovering nicely |
| Spendthrift | -50,000 | +50 | 1,000 months | Not seriously trying |

Identical profit, opposite verdicts. The spendthrift needs roughly **+2,000 a
month** to look as credible as the thrifty player at +50.

### Direction and rate

```
monthly_net <= 0:   delta = -K_FALL * f(burn_ratio)
                    where burn_ratio = |monthly_net| / max(monthly_revenue, 1)

monthly_net  > 0:   delta = +K_RISE * max(FLOOR, 1 - horizon / H_MAX)
```

**Falling scales with the burn ratio**, relative to what the colony actually
earns, so a hundred gold of overspend hurts a small colony more than a large one.

**Rising scales with the horizon**, so a deep hole crawls.

`FLOOR` is small but **must not be zero**. Without it, a player who is genuinely
profitable but catastrophically deep is pinned below the threshold forever with
no route back, and the only remaining move is retirement. A floor turns that into
a long punishment rather than a dead end.

`K_RISE` is larger than `K_FALL` while standing is below the threshold, so the
climb out is achievable rather than theoretical.

### Bands

Illustrative on 0-100, starting around 80. Tuning values, not design.

| Standing | Stage | Who writes |
| :--- | :--- | :--- |
| 100-60 | **Content** — the bottomless pit | nobody |
| 60-40 | **Concern** | Steward: spending heavily, seeing little return, do more with less or raise taxes |
| 40-20 | **Alarm** | Steward: insolvency is becoming a problem, we must raise taxes |
| below 20 | **Lost standing** | Chancellor enters, and the refusal process begins |

**Below 20 is one flat band.** A standing of 19 and a standing of 0 behave
identically. What separates a warned PC from a cut-off one is the refusal state
machine, not the number.

The ladder runs both ways. Climbing back through the bands, the Steward praises
returning revenue (§8.1) rather than going silent.

## 3. Refusal

A separate state machine, driven by standing crossing thresholds but never
identical to it.

```
SOLVENT
   |  standing falls below 20
   v
WARNED           Chancellor's final warning. Promises are STILL HONORED.
   |  2 turns elapse
   |
   +--> perk "it's my first day" available and unused?
   |         yes -> WARNED AGAIN (consume perk), 2 more turns, promises still honored
   |         no  -> continue
   v
REFUSING         All gold promises break. The Crown honors nothing.
   |             Entering this state costs a grade: the restore
   |             threshold rises for the rest of the run.
   |  standing rises above the current restore threshold
   v
SOLVENT
```

### The warning gate

**Refusal cannot fire until the Chancellor's warning has been delivered and the
full countdown has elapsed.** If standing plummets from 60 to 0 in one month, the
cutoff waits. This is the mechanism that satisfies §10.3's lock, and it is a
**gate, not a threshold** — a naive threshold check violates the invariant the
first time a catastrophic promise lands.

### The window is the point

During `WARNED`, promises are still honored. That is deliberate: it gives the PC
two turns to make a few decisive commitments knowing they will be paid, before
the faucet closes.

**A window the player cannot see is a trap, not an opportunity.** The Chancellor's
warning must state the deadline in fiction — something to the effect that the
Treasury will honor what is pledged through the spring and nothing after. The
player never sees a number, but must be able to act on the deadline.

### Promises that straddle the deadline

A promise is honored at the moment the Crown pays, not the moment it is made. A
multi-month promise made during `WARNED` whose payment falls after `REFUSING`
begins **breaks**. The window resolves near-term commitments; it cannot be used
to bank long ones.

### The perk

"It's my first day" (§5) grants one additional warning cycle. It runs the same
gate a second time: the countdown expires, the perk is checked and consumed, the
Chancellor writes again in a rather more exasperated register, and a fresh
countdown begins. Once per run.

Implemented as a repeatable cycle rather than a warning counter, so further
perks or quirks that grant grace need no new machinery.

### Hysteresis, and the grade

Refusal begins when standing falls below **20**. It ends when standing rises
above the **restore threshold**, which starts at **35**. The gap is the grace: a
PC restored at 35 has real runway before returning to lost standing, rather than
teetering on the boundary.

**The restore threshold rises each time the Crown cuts the PC off.** It is a
credit rating losing a grade on every default: the arithmetic of recovery does
not change, but the Crown requires more proof each time before it reopens the
faucet.

```
first cutoff    restore above 35
second cutoff   restore above 45
third cutoff    restore above 55
...             capped at 65
```

The cap exists so recovery stays theoretically possible, not to be merciful. A PC
on his fourth collapse must climb nearly to the Content band before the Crown
will pay a penny on his word, which is punishing by design.

**The grade drops on entering `REFUSING`, not on falling below 20.** A PC who
dips into lost standing and claws back before the countdown expires has not
defaulted, and his rating is untouched. That is the whole purpose of the warning
window, and charging him for a near miss would blunt it. See open items — the
alternative reading is one line to flip.

The warning gate reinforces the hysteresis at no extra cost. Even a PC who drops
straight back below 20 gets a fresh Chancellor warning and a fresh countdown
before payments stop again, so restoration is never immediately undone.

## 4. What breaks, and what does not

`REFUSING` breaks **gold** promises specifically (§10.3: the Crown refuses all
payments). Each broken promise costs loyalty with its recipient (§9.5), and
because the PC typically owes several people at once, this lands as a broad
collapse in goodwill rather than a single penalty.

Promises the **colony** fulfills from its own stockpiles are not the Crown's to
refuse and continue normally. A governor sending resources to another town is
unaffected.

The cascade is intended and should be severe: broken promises lower loyalty,
lower loyalty worsens compliance (§8.5), worse compliance raises rebel sentiment
(§12.3). This is the failure spiral the Squeeze is built around.

## 5. What the player can see

**Nothing numeric.** Standing is never displayed, and the four-stage ladder is
the entire interface. The stages must be unmistakable in tone or the player is
flying blind.

The **Ledger** (§10.4) is the compensating instrument. It shows every transaction,
monthly totals, and a trend graph, which means the player can derive
`monthly_net` and watch `net_position` accumulate. They simply cannot see the
Crown's judgment of it.

So the ledger supplies the inputs and the letters supply the verdict, and reading
the gap between them is a real skill the game can reward.

## 6. Demands

§10.3 says standing tracks demands met against demands missed, not only the
accounting. Meeting a Crown demand grants a discrete standing bonus beyond the
gold's arithmetic value; missing one costs beyond the lost revenue. Political
credit sitting alongside the arithmetic.

Demands grow over time (§10.2), which is one of the two jaws of the Squeeze.

## 7. Tuning targets

Tied to SPEC §6.2:

- **Year 1:** a sensible player stays in **Content** throughout. Standing is not
  a system the player needs to understand in the first twelve turns.
- **End of year 2:** a typical player sits in **Concern** or **Alarm**. The
  Steward has written at least once.
- **Years 4-8:** lost standing is a live threat and the Chancellor is a familiar
  correspondent.
- A player who grants every request without raising taxes should reach `WARNED`
  somewhere in years 2-3, not sooner.

All constants — `K_RISE`, `K_FALL`, `FLOOR`, `H_MAX`, the band boundaries, the
restore threshold, the countdown length — are tuning values to be set against the
balance harness and revised from playtest.

## 8. Open items

- **What drops the grade.** Currently entering `REFUSING`, on the reasoning that a
  dip corrected inside the warning window is a near miss rather than a default.
  The alternative is any fall below 20, which is harsher and makes the warning
  window less valuable. One line either way.
- **Whether the grade ever recovers.** Currently permanent for the run. Real
  credit ratings improve with a long clean record, and a 50-year run (§6.2)
  carrying damage from year 3 may be too unforgiving. Needs playtest before
  adding the state.
- Whether taxes raised under duress should count toward revenue at full value, or
  be discounted because the Crown knows what they cost politically.
- Whether standing should decay passively at all. Current model says no: only
  profit moves it, because passive recovery would undercut the Squeeze.
- **Gold's share of prestige is settled** — `prestige.md` §3, `net_gold =
  net_position`, linear and without a ceiling, and `prestige.gd` implements it.
  This doc deferred it on the grounds that anything written before crown standing
  stabilised would be invalidated by iteration. **That was the right caution and
  it has expired**: the question was answered two spec versions ago, and SPEC §17
  is now empty, so a reader following the old citation found nothing and could
  not tell whether it had been answered or dropped.
