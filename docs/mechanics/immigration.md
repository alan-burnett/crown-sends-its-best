# Mechanics — Immigration and Population Growth

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §12.1, §12.2, §11.4, §12.3, and the Squeeze pillar.

---

## 1. Where it sits

**World month phase 1, Arrivals** — alongside everything else crossing from the
Crown. Immigrants land with their own supplies and gold and join the town at
once; the town pays nothing for them (§12.1).

**Each town computes its own, from its own state, with no competition between
towns.** Settlers are not a pool to be divided. A town that is worth coming to
gets people whether or not its neighbour does.

It reads the quality of life set in **last month's Settle**, so arrivals are a
consequence of how the town was doing — which is precisely the lever the PC's
letters can reach.

## 2. The shape

```
arrivals(town)  =  crown_flow  ×  appeal(town)

appeal          =  pull(quality of life)  +  buildings  +  policy
```

Multiplicative on `crown_flow`, because if nobody is leaving home then no amount
of appeal conjures settlers out of nothing.

## 3. Immigration is flat. Births are proportional

| | Scales with | Dominates when |
| :--- | :--- | :--- |
| **Immigration** | **not** town size | the town is **small** |
| **Natural growth** | population × birth rate | the town is **large** |

SPEC §12.1 says immigration is the main source of growth in the early game, and
that natural growth "starts slowly but grows with population and can snowball."
**Make arrivals roughly size-independent and both halves fall out of one
decision** rather than needing to be balanced against each other.

It has a second effect worth having: a town founded late in a run **catches up
quickly** instead of crawling forever behind the capital, because the same
trickle of settlers is transformative at twelve and trivial at two hundred.

## 4. Appeal

### Quality of life, steeply

The main term, and **it should not be linear.** Near zero below a floor — nobody
emigrates to a miserable place — and rising sharply above it.

That gives a good town a virtuous circle and a bad one a stagnant one, and the
stagnation is **breakable**, because quality of life is exactly what the PC's
letters reach.

### Buildings

From `buildings.md`:

- **Fairgrounds** raises the volume directly.
- **Theatre, library and printing press** shift the **composition** toward
  experts rather than raising the count.

Folding "attracts experts" into immigration's composition rather than making it
a separate system is deliberate — there is one way people arrive.

### Policy

Where the PC's efforts live (§12.1). A policy carries **a condition and a
bonus**: *all towns*, or *all towns with a church*. Policies target towns; each
town still computes its own figure.

**The four standing knobs are the Provost's** (`the-provost.md` §2), set the
moment the first town is founded and adjustable by letter thereafter: **volume**,
**provision**, **experts** and **livestock**, each running from nothing to a
great deal. They map onto this section and §6 and §7 directly.

`policy.md` §1 uses this as its worked example — the Crown offers every settler
bound for the colony supplies and gold, which costs somebody money every month
and **moves both dials**: more come, and each brings more.

## 5. Crown flow rises as the Crown declines

§12.1 makes arrivals depend on "the crown's circumstances," and
`crown-demands.md` already has the Crown **past its peak and declining from year
four**, its obligations growing.

Tie them together: **as things worsen at home, more people leave.**

So immigration *rises* over a run — more mouths arriving precisely when demands
are growing and the PC can least afford to feed them. That is what emigration
actually did, and it attacks the balance problem in #90 from the other side: the
colony stops being static exactly as the Squeeze begins to bite.

## 6. What they bring

Every arrival is **an injection of resources and coin**, not merely a mouth
(§12.1). That gold feeds `means` in quality of life and can be the difference for
a poor town — so a wave of settlers is a genuine windfall before it is a burden.

Policy moves what they bring as well as how many come.

## 7. Composition

Mostly **workers**. A minority of **experts**, shifted by buildings and policy.
**Livestock** occasionally, shifted by policy.

### Experts arrive as fractions

A town's monthly figure is not whole people — it is something like *+4.5 workers
and +0.1 experts*. The workers arrive; **the fraction is saved**, and when it
reaches one, an expert appears.

How large that fraction is depends on the Provost's expert knob and on the town's
**education** (`the-provost.md` §3 and §4), and **which kind of expert appears is
decided at the moment he does** — whichever specialism would be worth most to
that town, by the same measure it values anything else.

**Education gates natural growth, not arrivals.** A town with no learning will
never raise an expert of its own, but it can still be *sent* them — the Provost's
expert knob reaches every town whether or not it has a library.

So a fur town gets a trapper, then a farmer, and a weaver once it starts turning
furs into cloth. Nothing about the list is authored.

Experts multiply a town's yield of one resource including its processed forms
(§12.2), so they are worth a great deal more than a worker and an
expert-attracting policy should cost accordingly.

## 8. Natural growth

Births. Slow at first, proportional to population, and capable of snowballing
(§12.1).

It should read **quality of life** as well — people have children when life is
good — which makes a thriving town compound and a wretched one merely persist.

**Granary** speeds it, livestock included (`buildings.md`), and pastures let
livestock grow faster (§11.1).

## 9. Growth is the engine of rebellion

**This is why a PC would ever want to discourage immigration**, and it is the
most important thing in this document.

> More immigration means towns become cities, people become educated, and next
> thing you know they want to build printing presses and your rule is hard to
> keep up with.

The chain is concrete in the mechanics, not a metaphor:

```
immigration  →  population  →  development  →  rebel sentiment
```

A bigger town reaches further up the building tree, carries more institutional
contacts, and trades in greater volume — and `rebel-sentiment.md` counts all
three. The **printing press** is the chain's own punchline: a building a large
town can afford, which brings a contact, provides amusement, and **raises rebel
sentiment** by name.

So growth is not a reward. **It is the engine of prosperity and the engine of
rebellion at once**, and a PC who encourages it without thinking is building
towards his own Independence ending.

Discouraging it is therefore a real instrument: fewer mouths, less strain, less
development, a colony that stays governable because it stays small. It is also
an admission that he cannot manage what he has.

## 10. The overflow valve

**A town never turns arrivals away.** Whatever lands, joins.

But a crowded and poor town may **send out a poorly supplied expedition**, and
heavy immigration into a town that cannot support it is one of the circumstances
that triggers one.

That gives the same mechanism two very different faces, which belongs to
`founding towns` (#99) but is triggered here:

| Expedition | Comes from | The new town |
| :--- | :--- | :--- |
| **Deliberate** | A governor's intent to settle, with the colony's backing | More people, some buildings, stores — it **leaps ahead** of the capital |
| **Overflow** | A town shedding mouths it cannot feed | Thin, fragile, and starting from almost nothing |

So unmanaged growth does not simply strain one town. **It scatters weak
settlements across the map**, each of them a fresh liability against the natives
whose land they take.

## 11. The player does not see it coming

**No letter announces that settlers are sailing.** The PC learns of them when
they land, in the same month's report.

He can *infer* it — a town whose quality of life he has been raising will attract
people, and that is knowable — but nothing spells it out, and a wave arriving
into a town he has stopped watching is a surprise he had the means to predict and
did not.

## 12. Tuning targets

- The floor and the steepness of the quality-of-life pull (§4). This decides
  whether a mediocre town grows at all.
- `crown_flow`, and how sharply it rises with the Crown's decline (§5).
- The absolute scale of arrivals against town size, which sets when natural
  growth overtakes immigration (§3).
- Expert share, and how far buildings and policy may shift it.
- What an arrival brings, in supplies and gold.
- Birth rate, and how strongly quality of life moves it.

## 13. Open items

- Whether **discouraging** immigration is a policy like any other, or something
  cheaper and cruder — a PC who simply stops advertising costs the Crown nothing.
- Whether a town can be **too crowded to appeal** — a large town's appeal
  falling on its own, independent of quality of life, so that growth spreads
  rather than concentrating.
- What exactly triggers the overflow expedition (§10). The threshold is
  #99's to settle, but immigration is one of its inputs and they should be
  designed together.
- Whether livestock arrivals need a pasture to be worth anything, or simply eat
  (§12.2) until one exists.
