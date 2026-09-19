# Mechanics — Crown Demands

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.2 (the Crown demands gold), §10.3 (Crown Standing), §6.2
> (the difficulty curve), §3.1 (the Crown at its peak), and the Squeeze pillar.

---

## 1. Two eras

**The run has a fixed bar and then a moving one.**

| Years | What happens |
| :--- | :--- |
| **1–3** | A **steady** demand, set above what a young colony can produce |
| **4 onward** | The bar starts moving, along one randomly chosen axis per year |

This matters more than a single curve would, because the two eras ask different
questions. Years one to three ask *can you build an economy that clears a fixed
bar.* Year four onward asks *can you keep clearing it while it moves.*

## 2. The early squeeze is a level, not a curve

**The demand in year one is already higher than the colony's output.**

A player can say yes to everything and will still watch Crown Standing fall,
because he is paying out more than the colony returns. The Steward writes at
Concern, then at Alarm. Nothing has grown; the bar was simply set above him.

His job in those three years is to **close the gap** by building an economy that
produces enough to meet it. Succeed and standing stabilises. Fail and the
warnings keep coming.

This is why the difficulty curve does not need growth to bite early, and it is
the direct answer to the balance harness finding that a negligent run lasts
indefinitely in perfect health (#90). A colony under no pressure is stable; this
is the pressure.

**It must still respect SPEC §6.2:** a sensible player almost always survives
year one. Warnings are not failure, and reaching Concern in the first year is the
intended experience rather than a sign of bad play.

## 3. Year four, and the Chancellor

**The player has to know the rules changed**, or a moving bar reads as the game
cheating.

At the opening of year four the **Chancellor** writes. Not a warning — an
announcement, delivered with satisfaction. The Crown's obligations are growing,
the colony must do more with less, and here is the new direction for its
governance.

He is the right voice for three reasons the spec already establishes:

- **SPEC §8.1**: he speaks with the Crown's political voice, and he cherishes
  delivering the PC bad news.
- **SPEC §3.1**: the game opens with the Crown *at the peak* of its power. A peak
  is the moment before a decline, and year four is when the decline starts being
  felt out in the colonies.
- He has seen this a hundred times in a hundred colonies. He is not warning the
  PC, he is informing him of something that was always going to happen to a man
  like him.

**This letter is never skippable.** It is the announcement that the game changed.

## 4. The four dimensions of growth

| # | Dimension | What grows |
| :-- | :--- | :--- |
| 1 | **Frequency** | Demands arrive more often |
| 2 | **Size** | Each demand asks for more |
| 3 | **Desperation** | Refusing costs more — standing and loyalty both |
| 4 | **More hands out** | More sources are demanding at all |

**Dimension 3 is the odd one.** It does not change what is asked, only the price
of saying no. A player who pays everything never feels it; a player who refuses
feels nothing else. It arrives in the **`desperate`** tone, which is already in
the enum and is exactly what it is for.

**Dimension 4 is not only patrons.** Patrons are M7, and an inert dimension would
waste a quarter of the bucket for four milestones. Read it as *more sources of
demand*: before M7 that means Crown officers who were not asking before — the
Provost wanting funds for education, the Marshal wanting supplies as well as
gold. After M7 it includes patrons.

### Frequency has a ceiling the others do not

SPEC §9.6 sets letter volume targets, and demands are unskippable. Frequency
growth therefore pushes directly against the anti-tedium system rather than
being absorbed by it. Growth on this axis has to stay inside the §9.6 envelope,
which makes it the first dimension to saturate late in a long run.

## 5. Bucket randomisation

**A reusable pattern. This is its first user, and it is written to be lifted.**

Giving every dimension a curve makes the game impossibly hard very quickly.
Choosing one at random each year makes runs differ — but true randomness will
sometimes pick the same axis five years running, and that produces an **aberrant
run**: one that is far easier or far harder than the design intends, through no
decision the player made.

Aberrant runs are not merely unfair. They poison tuning and scoring, because the
best scores start coming from lucky seeds rather than good play.

### The bucket

```
bucket = [1, 1, 2, 2, 3, 3, 4, 4]          eight entries, two of each dimension

each year:  draw one at random, without replacement
after four draws:  refill the bucket to eight
```

Drawing without replacement and refilling at the halfway mark gives a hard
guarantee: **in any four consecutive years, no dimension can be drawn more than
twice**, because the bucket never holds more than two of anything. Five in a row
is impossible rather than merely unlikely.

Runs still differ. The order is different, the emphasis is different, and two
players on two seeds get recognisably different late games. They just cannot get
a *broken* one.

### One draw a year, not two

Growth starts in year four and SPEC §6.2 targets a competent run of four to eight
years, so one draw a year gives a typical endgame **three to five growth events**
— enough for each to be felt and named. Two a year doubles the ramp and reaches
the same place twice as fast, which leaves less room for the player to respond
between changes.

**If the ramp proves too gentle, raising this to two is the first lever to try**,
before touching the per-dimension magnitudes.

### Determinism

The draw uses a named RNG stream, per `CLAUDE.md`. The bucket's contents and
draw order must serialise with the save, or a reload changes the future of the
run — which SPEC §16.1's locked seeded generation forbids.

## 6. Calibration: equal expected pressure

The bucket is only fair if the dimensions are worth roughly the same. Otherwise
the draw decides the run, and the player's decisions matter less than his luck.

**They cannot be equal in gold, because dimension 3 does not ask for gold.**
Frequency, size and more-hands-out all increase the total demanded. Desperation
increases only the penalty for refusing.

So the target is **equal expected pressure measured across the reference
players**, not equal pressure for any one of them:

- The **spendthrift**, who grants everything, feels 1, 2 and 4 and is untouched
  by 3.
- The **miser**, who refuses everything, feels 3 hardest and the others barely.
- The **steady** player feels all four.

This is directly measurable with the balance harness from #56, which already runs
those policies. Calibration means tuning each dimension until a year of growth on
any axis costs the *average of the reference players* about the same in Crown
Standing.

**That the dimensions land differently on different playstyles is a feature**, not
an imbalance to tune away. It means the draw interacts with how the player is
choosing to rule, which is what makes it interesting rather than merely random.

## 7. Tuning targets

Tied to SPEC §6.2:

- **Year 1:** demand exceeds output. A sensible player reaches **Concern** and
  not beyond.
- **Years 2–3:** a player who has built well closes the gap and holds; one who
  has not is at **Alarm**.
- **Year 4:** the Chancellor's announcement, and the first draw.
- **Years 4–8:** three to five growth events, each perceptible in the letters.
- A negligent run should be failing by year 4–5, which is the specific thing #90
  says cannot happen today.

## 8. Open items

- The size of the year-one gap between demand and output. This single number sets
  how hard the first three years feel and is the most load-bearing value here.
- Per-dimension magnitudes, pending harness calibration (§6).
- Whether dimension 4 should ever *remove* a source — a patron losing interest, an
  officer's attention moving elsewhere — so the axis can breathe.
- Whether the Chancellor repeats his announcement in later years, or whether it
  is once per run. Once is cleaner; a second one when the run has gone badly long
  might be funnier.
- If a second mechanic wants bucket randomisation, extract §5 into its own doc
  rather than duplicating it.
