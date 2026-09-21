# Mechanics — The Director

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §9.1, §9.3, §9.6, §9.7, §8.5.

---

## 1. Who writes this month, and about what

**And nothing else.** How a letter *reads* is the other engine's problem
(§9.7) — triggers hold no prose, the letter file declares its `params`, the
director supplies them, and the letter never re-decides what it is about.

The two are kept apart so that a second language is a copied folder, and so that
the question *should this man write* never gets tangled with *what would he say*.

## 2. Two kinds of letter, and one flag already tells them apart

**Some letters go at once.** The natives have attacked and the governor wants
orders. A town has declared and the Respectable patron is cancelling his
contracts. There is no deliberation about whether to trouble the Crown with this.

**Everything else is a contest** between the several things a contact might
mention, and most months he mentions none of them.

`skippable: false` already means the first kind, and now means two things at
once: **it is never culled, and it ignores both dampers.** No new field.

## 3. Pressure

Every topic a contact could write about carries a **pressure**, and he writes
when one clears his **threshold**.

```
pressure = gap + news - dampers
```

### Gap — how far the world is from what he wants

He reads the sim and compares the thing he cares about against what he thinks it
should be. **The bigger the gap, the bigger the care.**

Topics come from `cares_about` (`contacts.md` §6) — the same field that already
decides what a contact writes about unprompted. **A contact's concerns are not a
second list**; they are the measures he already judges the PC by.

### News — what happened last month

He reads the **event log** for anything that touched a thing he cares about, and
it adds **for that month only**.

This term is what makes the most human letter in the game possible:

> *These taxes on beer are too much. They are not crippling us. Give us a break.*

A one-point overshoot is never worth a letter on its own. **The change is what
prompts him.** Without a news term a contact only ever writes when things are
already bad, which is both duller and less true — people complain when something
*moves*, not when it settles.

It also makes the director a consumer of Seam A's event log alongside map
playback, the cutscenes and the ledger, rather than re-deriving the month.

### Worked

A clergyman who thinks the duty on beer should be under 5%:

| | |
| --: | :--- |
| **+10** | it is at 6% — the standing gap |
| **+20** | and it **went up** this month — news, this month only |
| **−5** | he wrote about the beer duty not long ago — **topic damper** |
| **=25** | pressure |

His threshold is **24**. He writes.

Next month the news term is gone and the topic damper is fresh: the same 6% duty
scores about 5, and he has nothing to say about beer for a good while.

## 4. The threshold is the character

Pressure is about the world. **The threshold is about the man**, and three things
set it:

- **A base per contact**, by role. A governor reports often; the Chancellor
  almost never.
- **Redundancy** — see §5.
- **Personality, temperament and vice.** A randomised contact may simply be more
  apt to write than another of the same role, which is most of why two clergymen
  in two runs feel different.

An **importunate** patron (`patrons.md` §6) is exactly a very low threshold, and
needs no mechanism of its own.

## 5. Your third clergyman is quieter, and this is what scales

**The threshold rises with how many contacts share a role.**

Your first church's man writes freely. The third church's clergyman **needs a
substantially bigger problem** before he will trouble the Crown, because he knows
perfectly well that the Crown hears from clergy already.

That is diegetic, it is one rule rather than per-contact bookkeeping, and **it is
the only volume control that scales with the colony.** A PC who goes wide does
not get a desk that grows linearly with his towns — he gets a desk where each
additional voice has a higher bar to clear.

## 6. The two dampers

Writing a letter sets both, and both decay.

| | Damps | Means |
| :--- | :--- | :--- |
| **Topic** | that concern alone | *I have said this* |
| **Contact** | every concern he has | *I shall not pester the Crown* |

**The contact damper is why a man writes one letter and not five.** He picks his
loudest topic over threshold, writes it, and the damper takes the rest below the
line for a while.

### 🔒 The topic damper is tuned in writings, not in months

The obvious failure is a clergyman alternating between the same two complaints
for a year while never mentioning his other three.

> **The topic damper should last about as long as it takes him to say everything
> else he has to say.**

A man with five concerns damps each for roughly five writings. **Rotation then
falls out instead of being enforced**, and nothing needs to track which topics he
has "used".

### Why bouncing is less dangerous than it looks

**The damper is about having said it. The gap is about how true it still is.**

The gap regenerates from world state every month, so a famine keeps re-raising
its own pressure and a mild request does not. Two topics therefore alternate only
when they are **persistently and genuinely equally urgent** — and then alternating
is the correct behaviour. The man really does have two problems.

The case actually worth accepting is the other one: a contact with two loud
concerns **never reaches his quiet ones**. That is also right. A clergyman with a
famine and a plague does not write about the library roof.

## 7. Which letter, and why severity is not tone

A topic usually has several letters. *Give us a break* and *we cannot bear this*
are the same concern at two pressures.

Three things choose between them, in order:

1. **Conditions** say whether a letter is **true** — ids into the code-side
   registry, tested against the month's state. A letter that is not true is not a
   candidate, whatever he feels.
2. **Pressure** says whether he **bothers** (§3).
3. Among letters that are both true and worth writing, **the one that speaks to
   the highest pressure wins.**

### That needs a field of its own

**`urgency` is already taken.** SPEC §9.1 makes urgency one of tone's three
inputs, alongside loyalty and personality, and the director feeds it straight
into `tone_for`. It cannot also select severity.

### The two axes are easy to confuse and must stay apart

| | Comes from | Decides |
| :--- | :--- | :--- |
| **Severity** | pressure | **which letter** he sends |
| **Tone** | loyalty, personality, urgency | **how it reads** |

A clergyman at the end of his patience but fond of the PC sends the severe letter
in a **dutiful** register. A trivial complaint from a man who despises him is the
mild letter, **hatefully**.

**Collapse the two and every serious letter is also an angry one**, which would
cost the game its most useful character note: the people who like the PC are the
ones who tell him how bad it is.

## 8. Params: a contract between three things

The director's other job. A letter is a shape with holes in it, and **the
director is what fills them.**

| | Declares |
| :--- | :--- |
| **The letter file** | the slots it needs — `{param:amount}` and the rest |
| **The trigger** | where each one comes from |
| **The director** | computes the value and supplies it |

Shipped, from the Chancellor:

```json
"params": {
  "amount": { "from": "scaled_world_value", "key": "colony_revenue",
              "factor": 0.1, "minimum": 5, "maximum": 2000 }
}
```

**The letter never re-decides what it is about.** It does not read the world, it
does not know what `colony_revenue` is, and it cannot disagree with the trigger
about what the month contained.

That is what keeps §9.7's two engines apart, and it is why **a second language is
a copied folder where only `text` changes** — the trigger holds no prose and the
letter holds no logic.

**The content validator is the enforcement**: every `{param:}` a letter uses must
be declared, every source must resolve, every condition and effect id must be
registered. A letter with a hole nobody fills is a build failure, not a blank in
the post.

## 9. When the gap never closes

A rival duke is the test of §3, because **nothing in his world has to change for
him to write.**

His concern is that the PC has not paid him, and that gap is permanent — he is
never satisfied, so it never closes. He spawns, his pressure is over the
threshold at once, he demands tribute, his dampers fire, they decay, and he
demands it again.

**So the dampers are his entire schedule.** Nothing else paces him.

That is the property worth naming, because it means one mechanism covers two
kinds of correspondent without a special case:

| | Paced by |
| :--- | :--- |
| A governor whose town is fine | **the world** — he writes when something happens |
| A duke who will never be satisfied | **the dampers** — he writes on a rhythm |

A contact sits somewhere on that line according to whether his gap can be closed
at all, and **the director does not need to know which kind it is dealing with.**

It also hands tribute frequency a single honest knob: **a duke's topic damper is
how often he asks.** `rival-pressure.md` §3 has his band setting how *much* he
demands; the damper is free to set how *often*, and the two move independently.

## 10. Loyalty gates the kind of letter, not the number

SPEC §9.6 suggests low-loyalty contacts should more often decide for themselves.
The refinement is that this is **not a volume control**:

| | At low loyalty |
| :--- | :--- |
| **Questions** — asking the PC's direction | **fewer** |
| **Offers** — policies, help, ventures | **fewer** |
| **Requests** — give me gold, give me iron | **unchanged** |

So a disliked PC's desk is not quieter. **It is hollowed out.** The same stack of
paper arrives and far fewer of them are decisions. He is still being asked for
things; he has simply stopped being consulted.

That is what makes §12's *he has lost the power to influence the world* something
the player reads rather than merely suffers — and it removes any reward for being
disliked, because the volume never drops.

## 11. The budget, and what happens when it breaks

Budgets are by **calendar year**, locked to it rather than to the colony's size
(§9.6): about **6** early, **12** mid, **20** late.

**They are a ceiling and there is no floor.** A quiet month is a thin desk, and a
thin desk is the correct reward for a colony that is running well.

### Over budget

- **Unskippable letters are never skipped.** The desk plays out over budget.
- **Skippable ones are dropped at random**, from a named stream, until it fits.

**No priority ordering, deliberately.** Importance is the player's judgement, and
a director that ranked a famine above a charity appeal would be doing the
player's job with worse information. A seeded draw silences nobody
systematically; a sort would silence the same men in every run forever.

## 12. 🔒 A culled letter is not an ignored one

**Culled** means the contact never consulted the PC and handled it himself.
**No loyalty is lost.** A request becomes a polite no; a question he decides
alone, through the kernel, serving himself (§8.5, Seam C).

**Ignored** means he asked and was not answered, and that costs (§9.3).

The two look similar in the world and are opposite in the Relationship, which is
why the distinction has to live here and not in the letter.

## 13. A flooded desk is information

The contact damper is **per contact, never per role**. So ending a policy that
six churches cared about brings six letters, and **the PC must answer all six or
take the loss with each of them.**

That is not the budget failing. **The volume is the consequence.** A decision
that upset a great many people produces a morning's post that says so, and
letters of that kind are `skippable: false` precisely because escaping them
through a cull would be escaping the decision.

## 14. Tuning targets

- Base thresholds by role, and how steeply redundancy raises them.
- Damper sizes, and the topic damper measured **in writings** per §6.
- How much the news term is worth against a standing gap — the whole feel of
  *these taxes are not crippling but give us a break* lives in that ratio.
- How far personality may move a threshold before two contacts of a role stop
  reading as the same office.
- The three budgets and the two year boundaries.
- **A duke's topic damper**, which is how often he demands tribute (§9) — and
  whether his band should move it as well as moving what he asks for.
- The pressure bands a topic's letters speak to (§7), which decide how quickly a
  contact escalates from a complaint to a plea.

## 15. Open items

- **Whether a contact may write twice in a month at all.** Currently no — the
  contact damper takes his other topics down the moment he writes. A genuine
  crisis arriving the same month as a routine complaint is the case to watch,
  though `skippable: false` already bypasses the damper and covers most of it.
- Whether the PC ever learns he was *not* written to. Currently never, and the
  consequences of `decide_alone` are how he finds out. That is probably right and
  is worth confirming in playtest rather than by argument.
- **Whether a topic's letters need an authored severity ladder or can infer one.**
  §7 gives each letter a pressure it speaks to, which is a new field. A cheaper
  reading is that `conditions` already discriminate — a letter conditioned on a
  15% duty is self-evidently the severe one — but that makes severity an accident
  of how the conditions happened to be written, and two letters whose conditions
  both hold would have no ordering at all.
- Whether the news term should read events the contact could not plausibly know
  about. It currently reads the log; §11.2 locks that the map shows only what the
  colony knows, and the same question applies to a man's correspondence.
