# Mechanics — Intent and Objectives

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 (towns run themselves, the Colony Month), §6.1
> (Mandate), §8.5 (orders are requests), §12.1, and the satire in §3.2.
>
> **The intents, their menus and the considerations live in
> `governor-agendas.md`.** This doc keeps the frame around them: the two levels,
> the cycle, the tiers, urging and the mandate, and why the PC cannot name a
> project.

---

## 1. Two levels, and only one of them is personal

**Intent** is what the governor wants for his town. *Get rich. Go tall. Go wide.
See to our defences.* It is a
standing goal and it may hold for twenty months or more.

**Objective** is the concrete project the town is working on. *Build a church.
Raise a farm on tile 14. Amass resources for an expedition.*

| | Chosen by | Driven by |
| :--- | :--- | :--- |
| **Intent** | the governor | deliberation, personality, circumstance |
| **Objective** | the town | **deterministic** optimisation against the intent |

This split is the design. **Personality decides what the governor wants;
competence decides how it gets done.** He has wise and honourable advisors, so he
never picks a foolish project — he picks an excellent project in service of a
goal the PC may think is completely wrong.

That is where the game lives. The player argues with a governor's *intent*, never
his carpentry.

## 2. The cycle

```
Orders from the PC reach the governor
  -> he decides whether to honour, delay, negotiate or discard them   (compliance)
  -> he decides his intent                                            (deliberation)
  -> the town selects an objective serving that intent                (deterministic)
  -> the town commits resources toward it                             (colony month)
```

Mapped onto the World Month:

| World phase | What happens |
| :--- | :--- |
| 1 Arrivals | the post reaches the colony |
| 4 Colony Month, step 9 Settle | the town reconsiders its objective (§7) |
| 7 Reckoning | the governor reads the post; compliance sets his posture |
| 8 Intent | the governor commits to an intent |
| 9 Dispatch | he writes, announcing what he means to do |

An intent set in month N is therefore acted on by the objective chosen in month
N+1's Settle. One month, consistent with everything else in the loop.

## 3. The three tiers

A town's resources and gold go out in a fixed order of precedence:

1. **Needs** — food and clothing. Survival. **The citizens cover these with the
   town's gold whether the governor likes it or not.** He has no authority to
   starve his people in service of a project.
2. **The objective** — what the governor directs. This is the tier he actually
   controls.
3. **Wants** — rum, tea, experts. Discretionary comfort, bought with what is
   spare.

**Terminology note.** The spec has moved and this needs settling. SPEC §11.3 no
longer defines *wants* at all; it now names the three tiers **needs, objectives
and luxuries** — the same three as above, with *luxuries* where this doc says
*wants*.

So the doc is no longer in conflict, it is merely using a different word from the
spec for tier 3, and **CLAUDE.md makes the spec's vocabulary an invariant**.
Either this doc and the shipped `wants` field move to *luxuries*, or the Author
keeps *wants* deliberately. It is one word and it is his.

## 4. Intent

### The set

**Six intents**, each with its own menu of objectives — `governor-agendas.md` §2:
go tall, go wide, get rich, military, education, and prepare for rebellion.

**Prepare for rebellion** is the only intent directed **against** the PC, and it
is what `contacts.md` §4 means when it says an order at the bottom of the
loyalty scale does not merely fail but can become the reason for what happens
next. A governor holding it is a resident contact with heavy influence
deliberately driving rebel sentiment upward, and his town's objectives now serve
that.

It does not replace SPEC §12.3's threshold — a town still rebels when sentiment
crosses it. The two work together: the governor accelerates, sentiment crosses,
the town declares. Which is a better story than a number quietly passing a line,
and gives the player something he can see coming.

### How it is chosen

Through the **deliberation kernel**, in world phase 8. Candidates are the intents
the filters allow; considerations score them; the governor's personality is the
weight vector. `choose()` emits its trace, which is what lets his letter state
his reasoning truthfully.

**The considerations, their table and the filters are in
`governor-agendas.md` §13.** Each consideration measures how much of a problem
one thing is in his town, and a table says how hard that pushes toward each
intent. A `baseline` row speaks for the untroubled intents in a quiet town.

### 🔒 The PC's letter fades, and it only ever pulls

Two properties of `crown_urging` that decide how the lever actually feels.

**It decays, with a half-life of a year.** A letter is **not a standing order** —
but it is not a passing remark either. A governor urged this spring still feels it
next spring at half strength, and has largely forgotten it the year after.

A year is deliberate. Much shorter and the PC is re-sending the same instruction
every few months to hold a governor in place, watching him drift back and
wondering why; **that is nagging, not ruling.** Much longer and a single letter
sets a town's course for a decade, which makes the lever too strong for how
little it costs to pull.

**It adds to the urged intent and penalises nothing.** Contrast the **mandate**,
which pushes *away* from every intent that is not the Crown's — the Crown's
appointment shapes what a governor will not do, and the PC's letter only ever
argues for one thing.

So the PC's instrument is **weaker than the Crown's own appointment and wears
off**, which is why repetition is a real part of ruling by letter.

### 🔒 An urging has an author, and several may stand at once

**The PC is not the only man who can urge a governor.** Author's ruling. The
Provost may press a town toward education, the Marshal toward guns, a slighted
patron toward trading with the tribes — each is a pull on the governor's intent,
**never on his objective**, which is what keeps SPEC §8.5's lock intact.

It is the same lever the PC pulls, from a different hand — Seam C's *same code
path, different origins* — and it needs the plumbing to hold more than one:

- **Keyed by author.** Each urging records who sent it. Nine times in ten it is
  the PC, and his is not special in the plumbing, only in the prose.
- **Several at once, each decaying on its own.** A PC urging from the spring and
  a Provost urging from the summer are both live, both fading at their own rate.
  **One slot would let the Provost silently erase the PC's last letter**, and a
  governor would forget what his ruler told him because a clerk wrote after.
- **Each carries its own strength.** The PC's comes from his tone, as above.
  Another author's comes from whatever he did to press it — a bribe, an order, a
  threat — and is authored with the act.

**A company's standing order has the same shape**, for the same reason
(`commanders.md`), and the plumbing serves both.

**How much a non-PC urging counts against the PC's is not settled here.** A
governor who defers to the Crown need not defer to the Marshal. That is a
weighting question for whichever act first uses the plumbing, not for the
plumbing itself.

### The Mandate is the starting intent

SPEC §6.1 gives the Crown's Mandate an effect on objectives "especially in the
early game". Model it as **the governor's initial intent**, with a consideration
favouring mandate-aligned intents whose weight **decays over the run**. Early on
he is doing what the Crown appointed him to do; later he is doing what his
circumstances demand.

M2 carries a fixed mandate. Run Setup in M3 supplies the value and nothing else
changes.

## 5. Objective

### What an objective is

A thing that takes time and resources, which the town cooperates to achieve under
the governor's direction: a building, an improvement on a named tile, an
expedition, a company.

**When there is nothing worth doing, the objective is *no building*** — the
shared fallback that replaced the old standing postures, giving +10% yield on
every worked tile (`governor-agendas.md` §3).

### How it is chosen

**Deterministically, by walking the intent's menu** — `governor-agendas.md`
§3–§7. Each intent has an ordered list of objectives with a gate on each; the
town takes the first that is wanted, reachable and placeable. Where a slot needs
a choice — which tile, which yield building, which plantation — it is scored,
also deterministically (§5 of that doc).

**Ties break on a hash of the run seed with the town and the candidate** — fixed
by the seed as required, but deliberately **not drawn from an RNG stream**, so a
tie cannot shift every later draw in the colony.

No personality, no weights, no randomness. The governor's advisors are good at
their jobs.

### He chooses the tile

When translating intent into objective, the governor picks the tile for an
improvement — the best available for the purpose. The PC may state preferences by
letter but never names a tile, consistent with §11.4's lock.

## 6. How the PC influences a town

**The PC addresses intent. He cannot name an objective at all.**

SPEC §8.5 locks it: *"An order reaches the governor's intent, never the town's
objective. The PC can argue for a goal; he cannot name the project, the tile, or
the month."*

This is characterisation before it is mechanics. The PC is a pampered aristocrat
who has never seen a dock. *"You must build a dock before the warehouse"* is not
an utterance he is capable of. *"You must care for your population's survival,
not your iron production"* is exactly what he would write.

So the governor's letter purposes are pronouncements on priority, each mapping to
an intent:

| What the PC writes | Intent |
| :--- | :--- |
| *see that the town grows, and its people amount to something* | go tall |
| *plant new settlements* | go wide |
| *see that the town prospers* | get rich |
| *see to your defences* / *be rid of them* | military |

Placeholder prose; the Author writes the lines. **Education is urged by the
Provost, not the PC**, and nobody asks a governor to prepare a rebellion
(`governor-agendas.md` §2).

### Why the lock is right

Two reasons, and the second is mechanical rather than literary.

The PC is a pampered aristocrat who has never seen a dock, so the vocabulary
simply is not available to him. But even if it were, **his instruction would be
worse than the governor's judgement.** Objective selection is deterministic and
well informed. Everything the PC knows about the town arrived through one man's
perception ladders, a month late. Letting him name projects would replace a good
optimiser with a worse one and make the colony read as incompetent.

So there is no objective-level order, and therefore **no objective-level
compliance.** Compliance operates on intent alone:

| | Comply | Refuse or reinterpret |
| :--- | :--- | :--- |
| **Intent** | he adopts the intent the PC urges | he keeps his own, and may say so |

**There is no code path by which a letter names a project, a tile, or a month.**
A dev who adds one has broken a locked invariant.

### What the PC does instead

Everything he might have wanted from naming a project, he gets by arguing about
priority. He cannot say *build a granary*; he can say *see that the town grows*,
and a governor who takes that to heart will build the granary himself, on a
better tile than the PC would have picked.

### The Mandate is an intent-level instruction

§6.1's Mandate is the Crown's stated goal for the colony, which is an intent. The
PC relaying or pressing the mandate is an ordinary intent-level order. One
mechanism, not two.

## 7. Reconsideration

**An objective is held until it is complete, the governor's intent changes, or
it stalls** (`governor-agendas.md` §3).

- **A building or improvement stalls** after three months with nothing committed
  to it. The town abandons it, takes back what it had committed, chooses again,
  and passes the abandoned one over for a year (Author's ruling, #467).
  Buildings still do not compete with tile yields, and needs are still paid
  before the objective.
- **No crisis override.** There is no crisis intent any more: a starving town
  turns its tiles to food through the needs tier, which outranks any objective.
- ***No building* never holds.** It never completes, so the menu is walked again
  every Settle while it stands, and the first month a gate opens the town takes
  that item.

## 8. How this feeds Quality of Life

`docs/mechanics/quality-of-life.md` defines **hope** as mostly the *fitness* of
the objective — is anyone addressing what the town actually needs — with progress
a smaller term.

The two systems meet exactly here, and the interaction is the point:

**A governor whose intent is wrong for his town's situation tanks its morale, no
matter how well he executes.** A starving town whose governor is set on
getting rich will get an excellent plantation and a hopeless population. The
citizens still eat, because needs are tier 1 and outrank him. They simply have no
faith that anyone is solving the actual problem.

**The player's letters are the fix**, and the lever is intent rather than
objective. That is rule by correspondence working as designed.

There is no cycle. This month's QoL reads the objective set last month; next
month's intent reads this month's QoL. One month apart, never within a month.

## 9. Where personality lives, and where it must not

| Decision | Personality? |
| :--- | :--- |
| Honour, delay, negotiate or discard an order | **yes** — compliance, M1 |
| Choose an intent | **yes** — deliberation |
| Choose an objective serving that intent | **no** — deterministic |
| Choose a tile for an improvement | **no** — deterministic |

A dev adding a personality weight to any row marked *no* has broken the design.
The governor is not incompetent, and a town that builds badly reads as a bug
rather than as character.

## 10. Open items

- The mandate decay curve. §6.1 says "especially in the early game" and nothing
  more.
- Whether an intent, once abandoned, should be less attractive for a while, so a
  governor does not oscillate between two intents on alternate months.
- **How fast the PC's urging should fade**, and whether a repeated letter should
  refresh it or compound it. Currently it refreshes.
- Whether a town whose governor is missing should keep its intent, as it does
  now, or fall to *no building*.
