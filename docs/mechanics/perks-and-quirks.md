# Mechanics — Perks and Quirks

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §5, §6.1, §14.3.

---

## 1. Perks are about you. Quirks are about the world

That is the whole of the distinction, and it explains SPEC §5's asymmetry without
needing a second rule.

| | Is | Therefore |
| :--- | :--- | :--- |
| **A perk** | a fact about the PC | **pure benefit**, and one per run |
| **A quirk** | a fact about the world he was given | **benefit and drawback**, and any number |

**A fact about you is yours. A fact about the world cuts both ways.** A man who is
hard to say no to is simply that; a colony on rich soil is rich soil to everybody
who wants it.

§5 also fixes the balance targets: **every perk is the same power level as every
other**, and **a quirk is power-neutral while rewarding a playstyle.**

## 2. 🔒 A perk names a knob. It never adds a number

*Righteous* is not `+5 clergy loyalty`. It is **a drift term on one class of
contact** — a knob that already exists, turned.

This is what keeps them out of the engine (§16.1's lock that content is
data-driven), what lets the Author add one without a code change, and what stops
forty of them becoming forty special cases.

**Where a perk wants a knob that does not exist yet, the knob is the work** — not
the perk.

## 3. Perks

### It's my first day *(unlocked at start)*

An additional Chancellor warning before the Crown first refuses to honour a
promise (§5). The refusal state machine runs its whole cycle twice
(`crown-standing.md` §3), which is why it is implemented as a repeatable cycle
rather than a counter.

### Righteous

**Clergy gain loyalty every turn.** You get more out of them without giving as
much — and since a contented clergyman is a standing weight against rebel
sentiment at high prominence (`institutional-contacts.md` §3), this is quietly a
sentiment perk as much as a charity one.

### Good first impression

**Every new contact starts warmer than normal.** Governors of founded towns,
patrons arriving, the commander who comes with the Marshal's troops, the
clergyman of a new church.

Strongest for a player who goes **wide and long** — a colony of nine towns has met
a great many people. Nearly worthless to one who holds two towns for six years,
which is exactly the kind of variance §14.3 wants.

### Hard to say no to

**Your urging weighs more** in a governor's intent deliberation
(`governor-objectives.md` §4).

Worth knowing what this does *not* do: it never overrides him. `crown_urging`
remains one of eight considerations against his own reading of his town, so this
**wins close arguments** and loses hopeless ones. The Crown's pressure, not the
Crown's command.

### Good PR

**Your optics all land in your favour** — good ones ring harder, bad ones ring
quieter (`prestige.md` §4).

It does not make an optic decay. Nothing does. It scales what each is worth in
the tally, so a run with two rebellions in it is still a run with two rebellions
in it, and merely less ruinous.

### My boss is a jerk

**When the *Crown* breaks your promise, it costs you far less loyalty.**

`REFUSING` (`crown-standing.md` §3) breaks every gold promise at once, and because
the PC typically owes several people, it lands as a broad collapse in goodwill
rather than one penalty — then worse compliance, then rising sentiment. **This
perk defuses the nastiest spiral in the game**, and only ever matters once you are
already in trouble.

Thematically: people believe you meant it, and they know whose treasury said no.

### Read between the lines

**Your contacts' perception leans are reduced when reporting to you.**

They still deceive themselves — the Marshal still minimises every threat, the
clergy still sees the worst — but they present it to you more plainly.

**The only perk that changes what you can see** rather than what you can do, and
the one that rewards a player who reads letters closely rather than one who plays
the numbers.

### Well connected at court

**Granting a Crown officer's demand earns more loyalty than it should.**

The gold leaves your accounts exactly as it would have. What you buy with it is
worth more, which makes the officers cheaper to keep and the Squeeze's
*more hands out* dimension less punishing.

## 4. Quirks

### Busy patrons

**More patrons arrive, and each is easier to keep happy.**

More prestige and more specialties available — against more hands out, more of the
desk spent on them, and more departures banking their final regard
(`patrons.md` §8). Rewards a player who works the patron game; drowns one who
ignores it.

### It could be worse

**Everything that measures quality of life does so with a dampened effect.**

Misery hurts less: less rebel sentiment, fewer complaints, a steadier colony.
Comfort helps less: weaker immigration appeal, slower births, less of the
virtuous circle.

**It flattens the curve in both directions**, which rewards a player who does not
intend to invest in how people live and punishes one whose whole plan was to make
the colony pleasant.

### Boom town

**Immigration runs higher, and the stakes multiplier on rebel sentiment runs
higher with it.**

This is `immigration.md` §9's chain — *growth is the engine of prosperity and the
engine of rebellion at once* — made into a choice. A player who can hold a large
colony gets a larger one sooner. A player who cannot gets to the cliff faster.

### Distant colony

**Correspondence takes an extra month each way.**

Everything you do is later: an order written on turn T is acknowledged two turns
on, and its consequence lands a turn after that. But **contacts are more patient**
— silence costs less, and their dampers run longer, so the desk is thinner.

**You manage less and plan further**, which is a different game rather than a
harder one. It is also the purest expression of the Distance pillar the game has.

### A pious colony

**Clergy carry higher prominence everywhere**, so churches matter more in both
directions — a contented priest holds his town down harder and a slighted one
carries it out faster.

**And amusement contributes less pleasure**, because they disapprove. Rewards
investing in faith; punishes bread and circuses
(`quality-of-life.md` §8's rum trap, closed off).

### Restless country

**The tribes are stronger, not merely grumpier.**

- They start at **lower standing**
- Their **villages yield more** from the tiles they work
- Their **forces are more numerous**
- And their **trade agreements are richer**

So the escape from the Crown's monopoly (`natives.md` §5) is both more valuable
and harder to reach, and a colony that mishandles its neighbours faces something
that can actually take a town.

### Scarce iron

**The Crown charges far more for iron, tools and guns. Ore yields fall, but by
much less.**

The asymmetry is the whole quirk. **Buying your way out stops working, so the way
out is your own foundry** — the mineworks, the ore, the chain that `buildings.md`
§5 already makes the spine of construction.

It makes the tool wall sharper, the gunsmith gate a genuine prize, and the natives
— who covet exactly these three (§10.1) — a much more serious trading partner.

### Commando commanders

**Commanders begin with a level or two, and the survival coin flip is harsher.**

A veteran from the first company you raise, and a far greater chance he dies with
his men rather than writing from the town that sent him (`commanders.md` §7).

Rewards using them well. Punishes losing them, which is mostly not in your hands.

## 5. Balancing them

§5 gives **one perk and any number of quirks**, so the two need different care.

**Perks are compared against each other.** Each must be the same power as *It's my
first day*, and several here are deliberately situational — *Good first
impression* is enormous in a wide run and nearly nothing in a narrow one, which is
§14.3's variety rather than power.

**Quirks must compose.** A player may carry several, and two that pull the same
way must not multiply into a run the design never intended. *Boom town* with
*It could be worse* is the case to watch: one raises the pressure and the other
numbs the feedback, and together they may produce a colony that grows explosively
and never notices it is in trouble.

## 6. Tuning targets

- Every magnitude here, and whether the perks land on one power level.
- How far *Distant colony* may lengthen the crossing before the loop stops
  reading as correspondence and starts reading as delay.
- *Scarce iron*'s two figures — the price rise against the yield fall — since the
  gap between them is the entire quirk.
- Whether quirk combinations need any exclusion rule, or whether composing
  freely is part of the fun.

## 7. Open items

- **Data or code.** Deferred by the Author until implementation is near. Most of
  these are scalars on knobs that already exist; **two are not** — *Read between
  the lines* modifies perception leans, and *Distant colony* changes the post's
  transit time. Those want their knobs designed deliberately.
- **Is *Distant colony* cheap to build?** It should be, if the post is a queue
  with a transit time rather than a same-month hand-off: holding an order one
  extra month in Arrivals shifts everything downstream without touching the sim.
  Worth confirming before it is promised.
- A perk rewarding careful **tone** was considered and set aside: there is no
  reason to choose a less pleasing word, so amplifying pleasant tones amplifies a
  free choice. **The live version would be a perk on harsh orders** — leaning on a
  man costs less loyalty and less rebel sentiment than it should — because
  harshness is the one wording that currently carries a price worth reducing.
