# Mechanics — Deliberation

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8 (personality affects behavior), §8.5 (orders are requests),
> §9.3 (deciding when ignored), §11.3 (towns run themselves), §12.5 (natives are
> full actors).

---

## 1. One mechanism, six decision points

The spec asks an actor to weigh a situation and choose in at least six places:

| Decision | Spec |
| :--- | :--- |
| A governor picks a town objective | §11.3 |
| A contact complies, partly complies, delays, reinterprets, refuses, or acts alone | §8.5 |
| A contact decides for himself when the PC does not reply | §9.3 |
| The director decides who writes to the PC and about what | §9.6 |
| A town decides to hold a trade protest | §10.2 |
| A tribe decides its diplomacy; a rival decides to demand or attack | §12.5, §8.4 |
| A governor answers a tribe's grievance (`natives.md` §11) | §12.5 |

These are one mechanism. Building it once means a system added later extends
every decision point at the same time, instead of each one growing a branch.

## 2. The kernel

```gdscript
# Every actor that chooses uses this.
static func choose(actor, candidates, context) -> Decision
```

`Decision` carries the chosen candidate **and the scoring trace** (§5).

## 3. Considerations

A consideration scores one aspect of one candidate. **It is owned by the system
that introduces it, not by the AI**, and registers itself against the decision
kinds it affects.

```gdscript
# systems/natives/considerations/native_threat.gd
# Registered for: TOWN_OBJECTIVE, ORDER_COMPLIANCE, DIRECTOR_URGENCY

func applies_to(candidate) -> bool
func score(actor, candidate, context) -> float   # -1.0 .. +1.0
```

**Standing convention:** a milestone that adds a system ships that system's
considerations with it. Adding natives to the world is not complete until
governors, commanders and the director can all feel them.

Scores are normalized to `[-1.0, +1.0]` so that considerations from different
systems remain comparable and no system can dominate by choosing a larger scale.

## 4. Personality is a weight vector

```gdscript
governor.weights = { "native_threat": 1.4, "quality_of_life": 0.7, "revenue": 1.1 }
```

A cautious governor weights threat highly. A greedy one weights revenue highly
and quality of life poorly. **No new code per personality**, which is what §8
requires when it says personality drives behavior and not merely prose.

Weights are data, generated semi-randomly per contact per run (§8.2) and seeded
from that contact's own RNG stream.

## 5. Hard rules are filters, not weights

Anything the spec locks is a **filter applied before scoring**, never a weight
that could lose a close vote.

```gdscript
func permits(actor, candidate, context) -> bool
```

§11.3's locked "needs before wants" is a filter: a town that cannot feed itself
has plantation-building removed from its candidate set, not scored down. This
also avoids utility scoring's classic failure, where an actor picks a mediocre
option because two strong considerations cancelled out.

## 6. The trace is not optional

`choose()` emits its scoring into the event log every time:

```
Ashmere → Fortify
  native_threat    +0.6 x 1.4 = +0.84
  food_security    -0.2 x 1.0 = -0.20
  mandate          +0.1 x 1.0 = +0.10
```

It pays three times:

1. **Balance harness.** Aggregate traces across N seeds show which
   considerations actually drive behavior and which never matter.
2. **Playtest debugging.** Utility scoring is opaque without it.
3. **Letter motive, free.** When a governor writes "I have set the men to the
   palisade," the reason in the prose is the reason in the trace. A letter can
   never misrepresent why something was done, which supports §9.1.

## 7. Will is not a write

Deliberation produces **will**. Will does not change the world. It becomes an
**Intent**, and the simulation executes the Intent over time.

```
player letter -> Order -> compliance --+
									   +--> Intent -> executed over months -> events
NPC deliberation -> will --------------+
```

This is why "the contact complied with your order" and "the contact acted on his
own and informed the PC afterward" (§8.5) are the same code path with different
origins, rather than two systems that resemble each other.

An Intent carries a source, a target, progress, and a resolution:
**completed**, **stalled**, **abandoned**, or **overtaken by events**. Intents
persist across months and can be delayed, contradicted by a later letter, or
invalidated by something that happened meanwhile — §8.5's delay outcome and
§11.4's expedition that may be "attacked, turned back, delayed, or lost
completely" are both this property.

### Executors by milestone

| Milestone | What executes |
| :--- | :--- |
| M1 | Trivial executor against the stub world |
| M2 | Colony month **Build** phase advances a town objective over months |
| M4 | Movement: expeditions crossing the map, interruptible |
| M6 | Armies, same executor, with combat as an interruption |

The Intent model is fixed in M1. Later milestones add **executors**, not a new
model.

## 8. Tuning, honestly

Adding considerations shifts the balance of decisions that were already tuned,
with no code change at all. That recurring work does not disappear; it becomes
weight tuning in data, guided by traces and the balance harness, rather than
rewriting a method.

Budget a small weights pass after each playtest, and one holistic pass in M9.

## 9. Open items

- The aggregation function. Weighted sum is the starting point; if a single
  strong consideration needs to be able to dominate, revisit toward a
  multiplicative or infinite-axis scheme before adding more considerations.
- Whether the director's decision kind needs a different aggregation from the
  actor decision kinds.
- How far personality weights should be allowed to spread before a contact
  reads as broken rather than characterful.
