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

## 4. What is demanded

Four askers, and — the part that matters — **four different currencies**.

| Asker | Demands | Refusing costs |
| :--- | :--- | :--- |
| **Steward** | Gold, as a revenue target | Crown Standing |
| **Marshal** | Resources for the Crown's wars | Crown Standing, and his loyalty |
| **Provost** | Gold for a policy | Crown Standing |
| **A rival duke** | Tribute in resources | **Prestige**, and a deferred attack arriving |

### Gold — the Steward

**A revenue target, not a bill.** SPEC §10.2 locks that the PC's gold is not a
wallet, so the Crown is not asking him to hand over coins he does not have. It is
telling him what the colony is expected to return through taxed trade.

Accepting makes it a **promise** (§9.5), and whether it is kept depends on
whether the colony's trade actually reaches the figure over the following months.

**Saying yes is a bet on your own colony.** Say yes and fall short and the promise
*breaks*, costing loyalty on top of the standing. Refuse outright and you pay in
standing and the Steward's regard, but nothing breaks and nobody is surprised.

That asymmetry is the decision: an honest refusal is cheaper than a broken
promise, and the player has to judge his own colony to know which he is making.

### Resources — the Marshal

Iron, guns, food, and whatever else his wars need (§8.1). These are physical goods
sitting in a town's stockpile, which is where delivery stops being simple (§5).

### Funding — the Provost

Gold promised for a policy: education, immigration. Drawn on the Crown, so it
costs standing directly.

### Tribute — the rivals

§8.4: they bully the PC into giving them resources, and accepting **defers** the
risk of an attack without ever buying peace.

The currency is different, and deliberately so. §14.1 makes paying tribute an
**optics** penalty, so it costs **prestige** rather than standing. A PC can be
solvent, meeting every Crown demand, and still despised at court for having paid
a foreigner to leave him alone.

## 5. Delivering, and the governor's cooperation

**The PC promises things he does not control.**

Gold is the Crown's to move. Resources are not — they sit in a town's stockpile,
and §11.3 locks that towns run themselves under their governor.

So a resource demand is a **two-step, and both steps can fail**:

1. The PC accepts the Marshal's demand. That is a **promise**.
2. The PC writes to a governor asking him to ship the goods. That is an **Order**,
   and it goes through compliance like any other (§8.5).

A governor whose town needs its iron will refuse, send half, or delay. He is not
being disloyal — he is weighing his town against a war on the far side of an
ocean, and §11.3 gives him that authority.

**The failure is doubled.** Promise the Marshal two hundred iron, have the
governor refuse, and the promise breaks: the Marshal's loyalty falls because you
failed him, and the governor's falls because you asked something costly. One
acceptance, two enemies.

This is rule by correspondence at its sharpest. **The PC's only power over the
thing he has already promised is another letter.**

### Which argues for asking first

A careful player writes to the governor *before* accepting, and learns whether
the goods can be had. That costs a month — and the demand may not wait — but it
turns a blind bet into an informed one.

**That is the decision this mechanic exists to create**, which means resource
demands must carry a deadline of **more than one turn**. A demand answered by
return of post makes the careful play impossible and reduces the whole thing to a
coin toss.

## 6. The four dimensions of growth

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
demand*, drawn from §4's catalogue:

- Crown officers who were not asking before — the Provost wanting funds for
  education, the Marshal wanting supplies as well as gold.
- **Rival dukes demanding tribute** (§8.4). As a run goes on, more parties have a
  hand out, and not all of them are the PC's own.
- Patrons, once M7 exists.

The rivals are the sharpest version, because their demands cost **prestige**
rather than standing. Dimension 4 therefore does not merely add more of the same
pressure — it adds pressure of a kind the player's existing defences do not
answer.

### Frequency has a ceiling the others do not

SPEC §9.6 sets letter volume targets, and demands are unskippable. Frequency
growth therefore pushes directly against the anti-tedium system rather than
being absorbed by it. Growth on this axis has to stay inside the §9.6 envelope,
which makes it the first dimension to saturate late in a long run.

## 7. Bucket randomisation

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

## 8. Calibration: equal in difficulty, not in gold

The bucket is only fair if the dimensions are worth roughly the same. Otherwise
the draw decides the run, and the player's choices matter less than his luck.

**They cannot be equal in gold, and they cannot be compressed to one number.**
Frequency and size change what is asked. Desperation changes only the price of
refusing. More-hands-out adds askers whose demands cost entirely different
things — the Provost costs standing, a rival costs prestige and an attack merely
postponed.

So the target is **equal in difficulty**, which is a judgement informed by
measurement rather than replaced by it.

### What the harness can measure

The reference players from #56 feel the dimensions differently, and that is the
useful signal:

- The **spendthrift**, who grants everything, feels frequency, size and
  more-hands-out. Desperation never touches him.
- The **miser**, who refuses everything, feels desperation hardest and the rest
  barely.
- The **steady** player feels all four.

Calibration means tuning until a year of growth on any axis costs the *average of
the reference players* about the same.

### What it cannot

Whether losing prestige to a rival's tribute **feels** like losing standing to the
Steward. Whether one doubled demand stings more than a demand arriving twice as
often. Those are authored judgements and no harness will settle them.

### The currencies are a dial, not a complication

Two demands of identical weight can be made to feel completely different by
changing what refusing them costs. **That is a lever available without touching a
single magnitude**, and it is the artistic freedom that comes with refusing to
reduce difficulty to one number.

## 9. Tuning targets

Tied to SPEC §6.2:

- **Year 1:** demand exceeds output. A sensible player reaches **Concern** and
  not beyond.
- **Years 2–3:** a player who has built well closes the gap and holds; one who
  has not is at **Alarm**.
- **Year 4:** the Chancellor's announcement, and the first draw.
- **Years 4–8:** three to five growth events, each perceptible in the letters.
- A negligent run should be failing by year 4–5, which is the specific thing #90
  says cannot happen today.

## 10. Open items

- The size of the year-one gap between demand and output. This single number sets
  how hard the first three years feel and is the most load-bearing value here.
- Per-dimension magnitudes, pending harness calibration (§6).
- Whether dimension 4 should ever *remove* a source — a patron losing interest, an
  officer's attention moving elsewhere, a rival turned to easier prey — so the
  axis can breathe.
- How long a resource demand's deadline should be. It must exceed one turn (§5)
  or the ask-the-governor-first play is impossible, but too long and it stops
  being a decision.
- Whether a rival's tribute demand scales with how prosperous the colony looks,
  per §8.4's note that they covet it especially when it prospers.
- Whether the Chancellor repeats his announcement in later years, or whether it
  is once per run. Once is cleaner; a second one when the run has gone badly long
  might be funnier.
- If a second mechanic wants bucket randomisation, extract §5 into its own doc
  rather than duplicating it.
