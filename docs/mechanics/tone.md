# Mechanics — Tone

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §9.1, §9.2, §8.5, §14.1.

---

## 1. The same five words, doing opposite jobs

**Inbound, tone is information.** A contact's tone is chosen for him, compressing
loyalty, personality, circumstance and urgency into one id (§9.1). The player does
not pick it and cannot argue with it — he **reads** it, and a director choosing it
well is the difference between a letter that tells him something and one that
merely says something.

**Outbound, tone is a decision.** The PC may write hatefully to a man who has done
nothing wrong. Nothing stops him, so it **must carry a function** or the first
blank of every reply is decoration.

> **The contact's tone is a reading. The PC's tone is a choice, and a choice
> needs a consequence.**

## 2. 🔒 They are not ordered

There is no *annoyed or worse* anywhere. **Desperate is not between annoyed and
hateful** — it is its own thing, and mechanically it is the most effective tone in
the game.

Everything here is a **lookup per tone**, never a range.

## 3. Three kinds of outgoing letter

| | |
| :--- | :--- |
| **Answering** | you meet or deny what was asked of you |
| **Directing** | you tell a contact what you want him doing |
| **Asking** | you want something from him |

Which knobs are even available differs by kind:

| | Answering | Directing | Asking |
| :--- | :--- | :--- | :--- |
| Loyalty | ✅ | ✅ | ✅ |
| The six compliance outcomes | — | ✅ | ✅ |
| Partial magnitude | — | — | ✅ |
| Urging weight and duration | — | ✅ | — |
| His desire to write again | ✅ | ✅ | ✅ |
| Prestige | ✅ | ✅ | ✅ |

**Answering is deliberately the thinnest.** There is no compliance step — *you*
are the one complying — and the decision that matters is whether you gave him
what he asked for. **The deed dominates and tone must not rival it** (§8.5,
locked).

## 4. The table

| | Loyalty | The six outcomes | Urging | Writes again | Prestige |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **pleased** | gain | toward comply and partial; **big** push toward delay | decrease | **increase** | — |
| **dutiful** | none | away from refuse, act alone and reinterpret | — | — | — |
| **annoyed** | slight loss | big push toward partial; **away from delay** | decrease | decrease | — |
| **desperate** | slight loss | **removes delay**; away from refuse | **increase** | — | **loss** |
| **hateful** | major loss | toward refuse and act alone | **increase** | major decrease | — |

### Urging is about intensity, not warmth

Pleased and annoyed both **lower** how hard a letter pulls months later. Desperate
and hateful both **raise** it. Dutiful sits at neither.

That is not an accident of symmetry. A governor who has received a letter he can
read as *the Crown is truly angry we have not built the second town* still
remembers it next spring. A letter that is flowery, or merely peevish, is easy to
**roll your eyes at and get on with your own life** — the out-of-touch aristocrat
being out of touch again.

**Mild feeling reads as fussiness. Extreme feeling reads as meaning it.**

## 5. What each one is for

### pleased — makes friends, and is not taken seriously

Loyalty rises and he is glad to hear from you, so **he writes more often** — which
costs you desk, because §9.6 has a ceiling and he is now using more of it.

Its signature is the **big push toward delay**. *Of course, Your Grace, in due
course.* A pleased letter is rarely refused and frequently put in a drawer, and
months later it pulls at a governor barely at all.

### dutiful — costs nothing, buys nothing, excludes the sideways answers

The plain register. It moves no loyalty, changes no urging, invites no extra post,
and simply **pushes away from refusal, acting alone and reinterpretation.**

**It is the safe choice and it should be.** A player who never thinks about tone
picks this and loses very little — he only forgoes what the others buy.

### annoyed — half of it, now

A slight loyalty cost and a big push toward **partial**. Its niche is the other
half of pleased's: **it pushes away from delay.** *I had expected better* is
precisely the note that does not sit in a drawer.

So it is the cheap, soft version of harshness: **when you need it this month and
do not much mind the cost.** He will do part of it, promptly, and roll his eyes.

### desperate — the compliance tool, and it is meant to be

Nothing is delayed, refusals fall away, and it **pulls harder for longer** than
any other tone.

**If your only goal is compliance, this is the best letter you can write. That is
by design.** What stops it being the answer to everything is that it costs twice:

- **Loyalty**, because pleading diminishes you in the reader's eyes. A man who
  begs is a man who has lost his grip, and he is writing it down.
- **Prestige**, permanently. §14.1's optics never decay, so every desperate letter
  is a small mark that is still there at retirement.

> **The Crown does not care whether the PC flatters or abuses his subjects. It
> minds very much that he looked weak in front of them.**

That is the sharpest expression of §14.1's lock in the whole game: **prestige
measures only how the Crown benefits**, so cruelty is free and desperation is not.

### hateful — playing with matches

Major loyalty loss, he writes back far less, and he is **more likely to refuse
outright or simply act alone.**

But if he does take the order, it **pulls hard and for a long time**. He did it
because he was afraid, and he has not forgotten why.

**You are writing a letter he will remember, and not fondly.** Its use is narrow
and real: a man whose regard you have already lost, where refusal was likely
anyway and what you want is maximum pull if it lands.

## 6. Harsh is the second axis

**A separate yes-or-no**, set after the tone, and the two are orthogonal — five
tones times harsh-or-not is **ten registers**. See `contacts.md` §3.

| | |
| :--- | :--- |
| **Always** | a loyalty loss, and the town remembers it if it bore the order (`rebel-sentiment.md` §4) |
| **Directing** | push toward comply and partial |
| **Asking** | push toward comply and partial, **and a larger partial** |
| **Answering** | **not offered at all** |

Harshness is not available when answering because there is nothing to lean on —
you are the one deciding, and *do it or else* has no object.

**Saying yes adds one sentence** and changes nothing else about the letter. The
sentence is a tone-keyed `{insert:}` fragment, so the same flag reads as velvet
from a pleased PC and as a threat from an annoyed one.

## 7. Two things that will look like bugs

**🔒 Desperate removes delay. It does not weigh against it.**
`deliberation.md` §5: hard rules are **filters**, applied before scoring. A large
negative weight is not the same thing — a close vote could still land on delay,
and the point is that a desperate letter is never put off. Build it as a filter.

**🔒 Hateful raising urging while pushing toward refusal is not a contradiction.**
Urging weight is only ever consulted **if he complied**, so the two touch
different moments. He is less likely to take the order, and harder-driven when he
does.

## 8. Tuning targets

- Every magnitude in §4, and the loyalty figures against the shipped
  `TONE_WEIGHT` table.
- **Desperate's prestige mark.** Small enough to be worth paying once, large
  enough that a run of them tells at retirement. That one number decides whether
  desperate is a tool or the answer.
- How far harshness stacks with annoyed, since both push toward partial.
- What *increase* and *decrease* on desire-to-write are worth against the
  director's thresholds (`the-director.md` §4).

## 9. Open items

- **Whether tone should be conditioned on the reader.** If it enters compliance as
  a consideration it carries a personality weight for free, and *hateful* could
  work on a frightened man and fail on a proud one. Nothing here requires it and
  it would be a large gain in character.
- Whether a contact's tone should read the PC's last tone to him. Two proud men
  exchanging colder and colder letters is a good story and an easy spiral.
- Whether **answering** wants any second axis at all, now that harshness is not
  offered there. It is the thinnest column by design, and may be too thin.
