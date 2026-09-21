# Mechanics — Endings

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §13.1, §13.2, §12.3, §12.6, §10.3, §14.1.

---

## 1. Two endings, one condition

SPEC §13.1 reads as two fail conditions that happen to share a clause. They are
better understood as **one condition with two epitaphs.**

**All four of these, together:**

| | |
| :-- | :--- |
| 1 | **No town of the colony is loyal to the Crown** |
| 2 | **Crown standing is lost** |
| 3 | **No Crown troops remain in the colony** |
| 4 | **The Marshal will send no more** |

And then the ending is only a question of what is left standing:

| | |
| :--- | :--- |
| **Colony Overrun** | nothing remains — **no towns and no expeditions** |
| **Independence** | towns remain, and every one of them is in rebellion |

**An expedition in the field keeps the run alive.** A colony whose last town falls
while a body of settlers is still crossing the map has not ended; it has one
chance left, walking.

### What this replaces

§13.1 gives each condition an undefined clause — *"the Crown will commit no more
resources"* and *"the Crown refuses to send more troops."* **Conditions 2, 3 and 4
are what those phrases mean**, and they are the same three in both cases.

## 2. \U0001f512 The last-chance stage is not a mechanism

§13.1 locks that every fail condition passes through a last-chance stage with a
formal Chancellor warning, so that **defeat is never a surprise.**

That needs no timer, because **none of the four flips quietly and two of them
cannot flip quickly.**

**Standing descends a ladder.** `crown-standing.md` §2: the Steward writes at
Concern, writes again at Alarm, and only then does the Chancellor arrive at all —
and even then a further countdown runs before the Crown refuses a penny.

**Troops leave by a staged withdrawal.** `the-marshal.md` §3: the PC stops
paying, the Marshal covers it out of his own account while his regard falls, he
writes naming the season it ends, and only then do they sail.

> **The last-chance stage is the overlap of warnings that already exist.**

So the invariant is satisfied **structurally**. A dev who finds himself building a
countdown for it has built a third timer alongside two that were already running.

## 3. The Chancellor is delighted

§8.1: loyalty to him begins very low, and **he cherishes giving the PC news of his
failures.** This is what he was put in the game for.

He writes **as each condition flips**, naming which are true and what still stands
between the PC and the end. Grimmer in content each time, and never in register:
**gilded leaves, a flowery hand, and the warmest possible phrasing.**

### \U0001f512 His tone runs opposite to his circumstance

Every other contact's tone compresses loyalty, personality and urgency into
something that matches the news (§9.1). Low regard and a disaster would ordinarily
produce something cold.

**The Chancellor writes `pleased` about ruin**, and he is the one contact for whom
that is correct. His personality inverts it. A dev who "fixes" his tone to match
the news has removed the joke the character exists to make.

## 4. The Marshal is the gate, and he needs no new threshold

Condition 4 is where a run actually ends, and **it is already built.**

**He will never refuse troops the PC is paying for in full.** That is
`FullPaymentIsAYes` — a filter, not a weight, because a guarantee that can lose a
close vote is not a guarantee.

**But the filter reads whether the Crown can pay.** Once standing is lost the
Crown honours nothing (§10.3), so the PC is no longer paying at all — **he is
banking on the Marshal's loyalty to foot the bill**, and `the-marshal.md` §3 has
the Marshal quietly covering it while his regard falls every month.

So refusal becomes possible the moment standing goes, and then two drains run at
once:

- **the unfunded cost**, every month he carries it
- **his men dying**, which `the-marshal.md` §4 makes *"the nastiest feedback loop
  in the game"* — casualties cost his regard directly and heavily

**Troops sent to fight a rebellion die**, so a PC who is losing and asking for more
is spending the one thing that could save him, faster the worse it goes.

### Which is how it actually happened

The Crown that loses a colony this way does not lose a battle. **It stops being
willing to pay for the next one**, and the man who decides that is an officer
watching his own account and his own casualty lists.

## 5. Four doors out, and one of them is locked

The stage ends the moment **any one** condition stops being true.

| | How it reverses |
| :-- | :--- |
| 1 | a rebel town returns peacefully (§12.3), or one is retaken |
| 2 | standing climbs back over its restore threshold (`crown-standing.md` §3) |
| 3 | troops arrive |
| 4 | the Marshal's regard recovers |

**But 3 and 4 interlock.** Troops cannot arrive while he is refusing, so the third
door only opens through the fourth. **His regard is the way out of the whole
thing**, and it is draining for two reasons at once while the PC tries to raise
it.

That is what makes the stage feel like a stage rather than a status: the obvious
remedy — send troops, retake a town — is the remedy that is closed.

The realistic doors are **standing** and **a town coming back on its own**, and
both are slow. Which is the point.

## 6. Retirement is always open, and this is when it matters

§13.2 lets the PC retire **at any time from the desk**, and says plainly that
*retiring from a losing position can earn more prestige than hanging on while gold
and goodwill drain away.*

**Until the last-chance stage that is a theoretical claim.** This is where it
becomes the decision the whole design points at: the Chancellor has named how
close the end is, the PC knows his own prestige is still positive, and hanging on
risks turning it into a fail condition's debt.

> **The last-chance stage is the retirement decision made urgent.**

Every other system meets here. Standing says how long the money lasts, the Marshal
says whether force is still available, sentiment says whether the towns are coming
back, and prestige says what walking away is worth today.

## 7. What an ending scores

**A fail condition carries a large final optics debt** (`prestige.md` §9) — fixed,
undecaying, and the largest single entry in the tally. Losing the colony is the
most embarrassing thing that can happen to the Crown.

**Voluntary retirement carries none.** The tally stands as it is, and **the timing
was the decision.**

**Forced retirement at fifty years** (§13.2) is normally very prestigious and
mostly earns that on its own: six hundred turns of accumulated net gold against a
fixed set of black marks.

The Chancellor delivers the news of final defeat (§13.1), which is the last letter
of the run and the one he has been waiting for.

## 8. Tuning targets

- The Marshal's regard, and how fast two simultaneous drains empty it. **This
  single figure decides how long a losing run lasts.**
- The fail-condition optics debt, against a typical run's accumulated net gold.
- How many conditions must be true before the Chancellor writes at all — one is
  probably too eager, three is probably too late.

## 9. Open items

- **A colony with nothing left but healthy standing.** No towns, no expeditions,
  and conditions 2–4 unmet: the run does not end, and the player watches an empty
  map while standing drifts down on a `monthly_net` of nothing.
  **Standing should probably collapse outright when there is no colony to be
  solvent about** — the Crown's whole interest is the place — but that is a change
  to `crown-standing.md`'s arithmetic and wants the Author.
- Whether the Crown ever **retakes** a colony it has not given up on. §13.1 implies
  it by making the ending conditional on the Crown declining to commit resources,
  and nothing currently spends them.
- Whether a rebel town that is the **last** town behaves differently. It has won
  and does not know it, and §12.3's peaceful return is still open to it.
- Whether the last-chance stage should be visible anywhere but the post. It is the
  one state where the player most wants certainty and the design most wants him
  reading letters for it.
