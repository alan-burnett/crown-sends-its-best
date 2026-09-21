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

## 5. 🔒 Tone lives inside the kernel, not on top of it

**Each tone is a consideration**, scoring zero unless the letter carries it. It
sits alongside loyalty, cost, payment, harshness, clarity and autonomy, and is
weighted by personality like every one of them.

**This is not a detail of where the code goes.** The kernel's whole design is that
a consideration produces a score and the actor's personality supplies a weight
(`deliberation.md` §4). Build tone *outside* that — as a table applied to the
result — and every contact in the game reacts to a hateful letter identically,
and making one react differently needs a branch on who he is. `CLAUDE.md` forbids
exactly that: **no contact has bespoke behavioural code.**

Inside the kernel it costs nothing. **A man who minds being shouted at is one
number in a vector that is already being filled in when he is generated.**

### Three traits, not five weights

A weight per tone is what makes the difference expressive — *how much manner
matters to him* is a poor question, *what kind of manner moves him* is a good one.

But five weights drawn independently, on top of the six a contact already carries,
produce **a man who loves being flattered and also loves being threatened**. That
is not a personality, it is a dice roll.

So the tone weights are generated from **three traits**:

| Trait | Scales | The man it describes |
| :--- | :--- | :--- |
| **Vanity** | `pleased` | flattery works on him |
| **Mettle** | `annoyed`, `hateful`, **and harshness** | how he takes being leaned on |
| **Pity** | `desperate` | he is moved by need |

**Dutiful carries no weight at all**, which is the tell that this is the right
cut. Its identity in §6 is *costs nothing, buys nothing* — there is nothing in it
for a personality to have an opinion about.

**Mettle is already half-built.** `HarshnessConsideration` carries a personality
weight today, and its own note reads *"a proud man minds being commanded more than
a dutiful one, and the same letter lands differently on the two of them."* One
trait driving both the harsh clause and the hostile tones is right: a man who
resents being bullied resents the threat and the contempt alike.

### What the three produce

| | Vanity | Mettle | Pity | |
| :--- | --: | --: | --: | :--- |
| **The proud man** | low | **high** | low | hateful drives him to refusal; flattery bounces off |
| **The timid man** | high | low | mid | pleased moves him; contempt barely registers |
| **The bully** | **negative** | **negative** | low | takes courtesy for weakness, and responds to force |
| **The decent man** | mid | mid | **high** | a desperate letter reaches him where nothing else would |

**A negative weight inverts that tone's whole table for him.** The bully falls out
of the same machinery rather than needing a case of his own — he is not a special
contact, he is two numbers below zero.

### 🔒 Which makes §4 the centre of a distribution

Everything in the table above describes **the average reader.** A *slight loyalty
loss* for annoyed is slight for a typical man, and the proud one takes it far
harder.

So the figures there are a **midpoint to tune**, not a value to set — and what
they buy is five tones times every personality in the game rather than five tones.

## 6. What each one is for

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

## 7. The register: which tone a contact reaches for

§5 gives every contact three traits for **reading** a tone. This is the other
side: **which tone he reaches for when he writes one.**

### What is there today, and what is wrong with it

`tone_for` maps loyalty and urgency to a tone by a threshold ladder — above
seventy `pleased`, above forty-five `dutiful`, above twenty `annoyed`, below that
`hateful`.

Two things are wrong with it.

**SPEC §9.1 says tone includes the sender's personality**, and this reads none.
**Every contact at the same regard writes in the same voice**, so two governors
rolled quite differently open a run identically.

**And it cannot express the Chancellor.** `endings.md` §3 locks that he writes
**`pleased` about ruin** — gilded leaves over the worst possible news — and his
loyalty begins very low, so the ladder hands him `hateful` and always will.

### The register

**A per-contact bias over which tones he reaches for**, applied on top of the
loyalty and urgency reading rather than replacing it. A choleric man at neutral
regard reaches for `annoyed` where a phlegmatic one reaches for `dutiful`, and
neither is wrong about how he feels.

**The four humours are the natural authored set**, period-appropriate and
memorable:

| | Reaches for |
| :--- | :--- |
| **Sanguine** | `pleased` |
| **Phlegmatic** | `dutiful` |
| **Choleric** | `annoyed`, and `hateful` |
| **Melancholic** | `desperate` |

A humour is **a label that supplies weights and nothing more.** Nothing branches
on it, exactly as nothing branches on a personality — it is a convenient way to
roll four numbers that make a recognisable person rather than four that make
noise.

**The Chancellor is sanguine**, and that one word is the whole of his joke.

### 🔒 Nothing reads a personality to announce itself

A letter never says *I am a timid man* because a vector said so. **What a contact
gives away about himself is what his tone gives away**, and the register is what
makes that worth reading.

This matters most in the governor's opening letter (`map.md` §5), which is the
player's only read on a man before he must trust him. **It gives away exactly as
much as his voice does**, which is the right amount and needs no new machinery to
deliver.

## 8. Harsh is the second axis

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

## 9. Two things that will look like bugs

**🔒 Desperate removes delay. It does not weigh against it.**
`deliberation.md` §5: hard rules are **filters**, applied before scoring. A large
negative weight is not the same thing — a close vote could still land on delay,
and the point is that a desperate letter is never put off. Build it as a filter.

**🔒 Hateful raising urging while pushing toward refusal is not a contradiction.**
Urging weight is only ever consulted **if he complied**, so the two touch
different moments. He is less likely to take the order, and harder-driven when he
does.

## 10. Tuning targets

- Every magnitude in §4, and the loyalty figures against the shipped
  `TONE_WEIGHT` table.
- **Desperate's prestige mark.** Small enough to be worth paying once, large
  enough that a run of them tells at retirement. That one number decides whether
  desperate is a tool or the answer.
- How far harshness stacks with annoyed, since both push toward partial — and
  they now share a trait, so a high-mettle man feels the pair twice.
- The spread of the three traits. Too narrow and every contact reads the same;
  too wide and half the colony is a caricature.
- What *increase* and *decrease* on desire-to-write are worth against the
  director's thresholds (`the-director.md` §4).

## 11. Open items

- **Whether a register and the three reading traits should correlate.** A
  choleric man who is also unmoved by being shouted at is coherent; a sanguine one
  who takes courtesy for weakness is a contradiction. Nothing yet stops either.
- **How the three traits are drawn**, and whether they correlate with the
  personality weights a contact already carries. A proud man who is also
  indifferent to cost is a different problem from a proud man who is not, and
  nothing yet says whether traits are independent.
- Whether **annoyed and hateful** should ever separate. Mettle moves them
  together, which says a man who resents being commanded resents contempt too.
  A man who takes a rebuke well and contempt badly is plausible and currently
  inexpressible.
- Whether a contact's tone should read the PC's last tone to him. Two proud men
  exchanging colder and colder letters is a good story and an easy spiral.
- Whether **answering** wants any second axis at all, now that harshness is not
  offered there. It is the thinnest column by design, and may be too thin.
