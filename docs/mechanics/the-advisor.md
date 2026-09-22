# The Advisor

> **Serves:** SPEC §9.2 (responding, and its two locks), §15 (screens), §16.2
> (Ironman), and M10's *optional hand-holding tutorial*.
> **Companion:** `perception.md`, whose exact opposite he is.

---

## 1. He is the tutorial, and he is nothing else

A portrait and a text box beside the options you are looking at. He explains what
the controls do.

**Three things he is not**, and each is a seam he must not cross:

| Not | Because |
| :--- | :--- |
| **a contact** | no loyalty, no relationship, no tone, no letters. He is not in `contacts.md` and not in `names.md` |
| **in the sim** | he reads no state and writes none. He is a Presentation-layer object and nothing in `sim/` knows he exists |
| **in the post** | he never produces an Order, so Seam B is not even in question |

**He is the only voice in the game that is not somebody's opinion**, which is why
he has to be kept this far outside everything else.

---

## 2. 🔒 He explains the instrument. He never reads the dial.

`perception.md` is the rule that a contact's report of the world is shaded by who
he is. **The Advisor is the complement**: unbiased, and about the *controls*
rather than the *state*.

| He may say | He may never say |
| :--- | :--- |
| a hateful tone costs loyalty | the Steward's loyalty is 48 |
| refusing makes a man write less often | the Marshal is about to stop writing |
| tax rates are set per resource | your tea duty is 15% |

**Between them the player still never gets a true number.** Contacts give biased
readings; the Advisor gives unbiased mechanics. Neither hands over the dial, and
the game's opacity survives having a tutorial in it.

Where he reads back the letter you just wrote (§4) he is quoting **your own
choices**, which is not state.

---

## 3. 🔒 Two locks from SPEC §9.2 bind him

**He is a safety net, never a substitute.** §9.2: *every choice's mechanical
effect can be understood from its wording.* **If an option needs the Advisor to
be understood, the option's wording is wrong** — and the fix is the wording.

That makes writing his lines a useful audit: an option nobody can explain in a
sentence is an option that fails the lock, and it will be found while writing his
content rather than in a playtest.

**He never blocks.** §9.2 targets **under a minute** for a letter. His box does
not need dismissing, does not gate the next control, and does not animate in a
way that has to finish. A player who ignores him entirely answers his post at
full speed.

---

## 4. What he speaks about

**Three kinds**, and they behave differently.

### Arrival — about the surface, not the options on it

The first is not about a choice at all. **The first time the player reaches the
desk**, before a single letter is opened, he introduces himself and explains the
desk: the stack, the post, what sending does, where the map and the ledger are.

> *"I'm your advisor. Congratulations on the appointment. Here is your desk, and
> here is how it works."*

**This is the one piece of him that is a greeting as well as an explanation**,
and it is the only advice that fires with nothing in front of the player to
explain. Everything else answers a control; this one answers a room.

It is also **unconditional**: it has never been said, so it fires at level 1 and
level 2 alike. The cooldown never suppresses a first arrival, because there is
only ever one.

### Explanations — static, about a control

*What tone is. What the purse ladder means. What a priority pronouncement does.*
One per thing to explain, written once.

### The read-back — composed, about the letter you just wrote

> *"A hateful response that denies his request. You can expect to lose a lot of
> loyalty with this contact, and that he won't write back as often."*

**This is his best work**, because it is the only place the game tells you what
you just did before you are committed to it. It arrives when the letter is
complete and can be added to the post.

### 🔒 The read-back is a set of claims, not a sentence

*hateful* → **loyalty cost**. *refusal* → **writes less often**. Each is a
separate claim, assembled into a sentence.

This matters for §5: **the cooldown applies per claim.** A player who has heard
both claims recently gets silence; one who has heard about tone but not about
refusal gets only the half he has not heard. **Level 2 therefore teaches the
combinations he has not met yet**, rather than going quiet for three months and
then repeating itself.

---

## 5. Three levels, and the middle one is the first with a number in it

| | |
| :--- | :--- |
| **1 — full** | he explains whenever there are options in front of you |
| **2 — with cooldown** | the same, but he will not repeat an explanation within **three months** |
| **3 — fired** | he is gone |

**Level 1 is level 2 with the cooldown at zero.** One mechanism and a parameter,
not two code paths — and the parameter is in months, like everything else the
game measures.

**The cooldown is per claim and per explanation**, keyed by its id, and it lives
in the save. Ironman means it has to survive a quit (§16.2), and a tutorial that
started over every session would be a tutorial nobody could turn down.

---

## 6. Talking to him

**Click the portrait.** What he offers depends on where he is:

| At | You may say | Which sets him to |
| :--- | :--- | :--- |
| **1 — full** | *tell me less* | 2 |
| | *you're fired* | 3 |
| **2 — cooldown** | *tell me more* | 1 |
| | *you're fired* | 3 |

**There is no way back from fired**, by the Author's ruling, and that makes it
the third irreversible act on the desk.

**So it is confirmed, like the other two.** SPEC §15 locks that sending the post
and retiring both ask; firing a man permanently on one mis-click belongs in the
same company. Its wording is its own, for the reason the desk's other two have
their own: a confirmation that reads like every other confirmation is one the
player stops reading.

### 🔒 This is not a decision the desk lost

`desk_screen.gd` locks that **only the desk has decisions**. Firing the Advisor
is not one of them — it changes no state the sim can see and alters no letter.
It is a preference about the interface, in the same family as a volume slider,
and it is safe on the desk for exactly the reason he is safe anywhere.

---

## 7. 🔒 He begins at the desk, not before it

**He does not cover Run Setup.** He exists once the run does and the PC is making
decisions at his desk.

**Run Setup carries its own clarity instead.** The mandate and the grant split
are presented so a new player who understands basic strategy can read them — and
an option that needed a tutorial standing beside it would be an option worded
wrong (§3). The same test as everywhere else, applied to a screen he never sees.

**His first appearance is the desk itself**, not the first letter. Run setup
ends, the desk assembles with the governor's opening letter sitting unopened in
the stack, and **he speaks before it is opened** (§4, *Arrival*) — introducing
himself and the room.

The opening letter (#274) is then his second. It is the first decision of the
run and the one a new player understands least, so the order matters: he explains
the desk, and only then what is being asked on it.

### The checkbox

**At game start, before anything else: do you want him?** Off means he was never
hired; on means level 1.

**Its default is tied to an unlock, and nothing announces it.** Until the player
has shown basic competence — *survive to year five*, or whatever the condition
settles as — the box is ticked. Afterwards it is not.

**Silently is the point.** A veteran is not congratulated for outgrowing a
tutorial and a beginner is not told he is being helped. The game stops assuming,
and either player can tick it the other way in one click.

### 🔒 This is not a §14.3 unlock

§14.3 governs unlocks that **add variety, not power**, and v2.4 requires new
potential to bring new drawbacks.

**None of that applies here.** This grants no potential: no option, no starting
choice, no content — a default checkbox. A drawback attached to it would be a
drawback for having played the game before.

Worth saying plainly because the unlock machinery is shared, and the next reader
will find a condition hanging off it and go looking for the balancing cost.

---

## 8. His content is keyed to the vocabulary, not to letters

**This is the piece that decides what he costs.**

Today an option id is a word invented per letter — 87 of them,
69 used exactly once (`reply-vocabulary.md` §1). An Advisor written against that
needs 87 explanations, and a letter written next month arrives with an option he
has never heard of and says nothing about it.

**Written against the seven families instead, he needs seven.** *What the purse
ladder means* is one explanation covering every letter that asks for money,
including the ones not yet written.

So **#314 lands first**, and the ordering is not negotiable — it is the
difference between a tutorial that goes stale the moment content is added and one
that does not.

```
data/advisor_en/<id>.json    portrait ref, and the line
```

Prose, so **the folder carries the language** exactly as letters do
(`CLAUDE.md`). The portrait is a replaceable reference (SPEC §16.3). No
`{perception:}` slot is legal here — §2 — and the validator should refuse one.

---

## 9. Tuning targets

- The three-month cooldown.
- How long his box holds before it fades, and whether it fades at all.
- Whether the read-back's claims have a maximum, so a letter that trips six of
  them does not produce a paragraph.

## 10. Open items

- **Do the map and the ledger get an arrival too?** The desk plainly does (§4).
  Those two carry no decisions, so he has no options to explain there — but a
  player opening the ledger for the first time is looking at the one screen in
  the game made of hard numbers. An arrival line is cheap and it is the same kind
  of thing as the desk's. **Author's call**, and it does not block #347.
- **What the unlock condition actually is.** *Survive to year five* is the
  Author's example rather than his ruling, and it wants setting alongside the
  other §14.3 thresholds. It is the cheapest of them to change.
- **Does firing him in one run reach the next?** The unlock moves the default, so
  a player who fires him every run is still ticking a box every run. Probably
  fine; worth asking once there is a veteran to ask.
