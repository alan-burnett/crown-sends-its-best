# Mechanics — Intent and Objectives

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 (towns run themselves, the Colony Month), §6.1
> (Mandate), §8.5 (orders are requests), §12.1, and the satire in §3.2.

---

## 1. Two levels, and only one of them is personal

**Intent** is what the governor wants for his town. *Increase economic output.
Grow the population. Strengthen our defences. Settle a new town.* It is a
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

**Terminology note.** SPEC §11.3 currently defines *wants* as "what it needs to
reach its objectives", which is tier 2 here, and leaves tier 3 unnamed. This doc
uses *wants* for tier 3 in line with the Author's model. **If the spec is not
updated to match, the spec wins and this doc is wrong.**

## 4. Intent

### The set

Starting set, to grow:

- Increase economic output
- Grow the population
- Strengthen defences
- Settle a new town
- Secure the town's survival (the crisis intent)
- **Prepare the town for rebellion** — reachable only at very low loyalty

That last one is the only intent directed **against** the PC, and it is what
`contacts.md` §4 means when it says an order at the bottom of the loyalty scale
does not merely fail but can become the reason for what happens next. A governor
holding it is a resident contact with heavy influence deliberately driving rebel
sentiment upward, and his town's objectives now serve that.

It does not replace SPEC §12.3's threshold — a town still rebels when sentiment
crosses it. The two work together: the governor accelerates, sentiment crosses,
the town declares. Which is a better story than a number quietly passing a line,
and gives the player something he can see coming.

### How it is chosen

Through the **deliberation kernel**, in world phase 8. Candidates are the intents
available; considerations score them; the governor's personality is the weight
vector. `choose()` emits its trace, which is what lets his letter state his
reasoning truthfully.

**Eight considerations**, and a governor carries a weight for every one:

| | Reads |
| :--- | :--- |
| `food_security` | months of food in hand |
| `quality_of_life` | how the town is living |
| `revenue` | what it is earning the Crown |
| `native_threat` | the tribes on its border |
| `room_to_grow` | unclaimed land worth taking |
| `crowding` | people against workable ground (§6 of `founding-towns.md`) |
| `mandate` | what the Crown appointed him to do |
| `crown_urging` | **what the PC last told him the town was for** |

**Two filters, applied before scoring** — locked rules, never weights
(`deliberation.md` §5):

- **A town cannot intend to settle nowhere.** No governor, however expansionist,
  sends an expedition to country the colony has never seen.
- **Sedition is unreachable above a loyalty floor.** A weight can lose a close
  vote and then win one; this must be impossible for a man who does not loathe
  the PC, whatever else his temperament says. It is also what makes recovery
  work — raise him back over the line and the candidate stops existing for him.

### 🔒 The PC's letter fades, and it only ever pulls

Two properties of `crown_urging` that decide how the lever actually feels.

**It decays.** A letter is **not a standing order**. Its pull halves over a few
months, and a governor who was urged a year ago is running his own town again. A
PC who says a thing once and never returns to it has not set policy; he has made
a remark.

**It adds to the urged intent and penalises nothing.** Contrast the **mandate**,
which pushes *away* from every intent that is not the Crown's — the Crown's
appointment shapes what a governor will not do, and the PC's letter only ever
argues for one thing.

So the PC's instrument is **weaker than the Crown's own appointment and wears
off**, which is why repetition is a real part of ruling by letter.

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
the governor's direction. Mechanically it is three things:

- a **resource requirement** list
- a **labour bias** for the Work phase
- a **completion condition**

Two kinds exist, and both must work or governors only ever write about
construction:

- **Projects** that complete — a building, an improvement on a named tile,
  amassing an expedition's supplies.
- **Standing postures** that do not — stockpiling food, harvesting a resource,
  fortifying.

### How it is chosen

**Deterministically.** Every candidate — a building, an improvement on a named
tile, a standing posture — is measured on **the same six axes**, and the intent
says what each axis is worth. Take the best.

That structure is what keeps it extensible without branching: **adding an intent
is adding a row**, and adding a kind of objective is teaching the scorer to
measure one more thing. Neither is an `if` on which intent it is.

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
| attend to the colony's profit | increase economic output |
| see that the town grows | grow the population |
| see to your defences | strengthen defences |
| plant a new settlement | settle a new town |
| your people's survival must come first | secure survival |

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
priority. He cannot say *build a granary*; he can say *your people's survival
must come first*, and a governor who takes that to heart will build the granary
himself, on a better tile than the PC would have picked.

### The Mandate is an intent-level instruction

§6.1's Mandate is the Crown's stated goal for the colony, which is an intent. The
PC relaying or pressing the mandate is an ordinary intent-level order. One
mechanism, not two.

## 7. Reconsideration

Every Settle, the town runs a **reconsider step**. It is deterministic — no
personality, no dice. It asks three questions:

1. **Is the objective complete?**
2. **Has it stalled?**
3. **Has the intent changed since this objective was chosen?**

If none hold, the town sticks to what it is doing. **Stickiness is not a tuned
switching margin; it falls out of these three tests.** A town that is making
progress on a sensible project simply carries on.

### Stall detection

Two kinds, both deterministic:

- **Hard stall** — a required input cannot be obtained at all. The militia needs
  guns, guns need iron, the town produces no ore and cannot buy any. The
  objective is unreachable and no amount of patience fixes it.
- **Soft stall** — progress has been below a threshold for some months. The work
  is technically possible and is going nowhere.

### Intent change, and sunk progress

An intent change makes the objective **eligible** for reconsideration; it does
not automatically abandon it. Sunk progress is weighed deterministically: a dock
three weeks from completion gets finished, a dock barely begun does not.

**This matters most in an emergency.** If natives are burning the outskirts and
the governor's intent turns to defence, the town must not spend eleven more
months on a dock. The crisis intent should be able to override deep sunk
progress, and that is the case to tune against.

## 8. How this feeds Quality of Life

`docs/mechanics/quality-of-life.md` defines **hope** as mostly the *fitness* of
the objective — is anyone addressing what the town actually needs — with progress
a smaller term.

The two systems meet exactly here, and the interaction is the point:

**A governor whose intent is wrong for his town's situation tanks its morale, no
matter how well he executes.** A starving town whose governor is pursuing
economic output will get an excellent plantation and a hopeless population. The
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
| Detect a stall | **no** — deterministic |
| Choose a tile for an improvement | **no** — deterministic |

A dev adding a personality weight to any row marked *no* has broken the design.
The governor is not incompetent, and a town that builds badly reads as a bug
rather than as character.

## 10. Open items

- The full intent set, and whether "serve the Crown" belongs in it as distinct
  from economic output.
- The mandate decay curve. §6.1 says "especially in the early game" and nothing
  more.
- Soft stall thresholds — how many months of how little progress.
- How hard a crisis intent should override sunk progress.
- Whether an intent, once abandoned, should be less attractive for a while, so a
  governor does not oscillate between two intents on alternate months.
- **How fast the PC's urging should fade**, and whether a repeated letter should
  refresh it or compound it. Currently it refreshes.
- Whether a town whose governor is missing should keep its intent, as it does
  now, or fall to survival.
