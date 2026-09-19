# Mechanics — Trade Protests

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.2 (trade protests), §14.1 (optics), §12.3 (rebel
> sentiment), and the Squeeze pillar.

---

## 1. It is the people's decision

A town refuses to buy or sell **one resource** with the Crown. The fiction is in
SPEC §10.2: the Crown's merchant ship docks, the town is informed of the new
duty, and rather than accept it the town simply will not deal in that resource.

**It is a calculation, not a deliberation.** No actor chooses it. A score per
town per resource is recomputed each month, and a protest begins when it crosses
a threshold — the same shape as rebellion in §12.3, which is a protest's larger
sibling.

That matters for a reason a player can feel: **this is not the governor's
decision.** He is an input, because his regard for the Crown colours the town's,
but the refusal is the people's. A governor who wants to hurt the Crown has his
own route, and it is intent, not this.

## 2. The score

Six inputs, all from SPEC §10.2.

| Input | Direction |
| :--- | :--- |
| The town's **rebel sentiment** | Higher makes protest likelier |
| The **governor's loyalty and temperament** | Lower loyalty makes protest likelier |
| The town's **quality of life** | Lower makes protest likelier |
| The **duty on this resource** | Higher makes protest likelier, and a **rise** makes it markedly so |
| Whether the resource is a **luxury** | See §4 |
| **Protests already running in this town** | Raises the threshold. See §3 |

The fourth input is two terms, not one. A standing high duty is resented; a duty
that just **went up** is what actually provokes. A town living with a punishing
rate for two years is angrier than one that has just been raised to half of it,
and less likely to act.

## 3. The runway is per town

**Each protest running in a town raises that town's threshold for starting
another.** Not the colony's — that town's.

A town on the brink over both beer and tea, whose beer protest fires, now has
room before tea follows. It has made its point. The colony keeps trading with an
unruly town rather than watching every resource shut at once like a gate.

**A colony-wide duty still lights up the whole coast.** Rates are per resource
and colony-wide (§10.2), so raising the duty on furs raises the score on furs in
every town at once, and every coastal town whose score crosses will protest furs
in the same month.

That combination is the design:

> **A town trends toward one protest at a time. A resource does not.**

One is a town's patience; the other is the PC's own decision arriving everywhere
he rules simultaneously. The second is agency — the player did that, on purpose,
with one letter.

## 4. Luxuries and needs are weighted opposite

**Luxuries are the likeliest thing to be protested.** A town can do without rum.
Refusing it costs a little quality of life and nothing else, which makes it the
cheapest way to tell the Crown no.

**Needs — food and clothing — are the least likely, and they are not excluded.**
The weighting is reversed, not a gate. Things can get bad enough that a town
would **rather starve than pay what is being asked**, and when that happens it is
one of the loudest things the simulation can say.

A protest on food or clothing should therefore be rare, late, and read as a
catastrophe rather than a tactic. It is a town choosing hunger over submission.

**Tea sits where it does by mechanics, not by priority** (§10.2). It is the
cheapest pleasure a town can never make for itself (`town-economy.md` §1), so a
duty on it lands on a comfortable town exactly where it is softest. If tea does
not emerge as an early protest, the prices or the weights are wrong — not the
rule.

## 5. What an active protest does

The town **will not buy or sell that resource with the Crown**. Both directions,
one resource, one town.

`Trade.may_trade_with_crown` is the existing gate and is already asked before
**every transaction** rather than once per phase, so a town can come to refuse
partway through a month. **It needs a resource parameter**: today it takes a town
and answers all-or-nothing, which cannot express a protest.

What it costs depends on which side of that resource the town was on, and this is
worth letting emerge rather than balancing away:

- A town that **buys** the resource goes without it. Protesting tea costs a
  little pleasure; protesting iron stalls its objective.
- A town that **sells** it loses the income. A fur town protesting furs is
  refusing its own livelihood, and that bites far harder than giving up rum.

A rebelling town already refuses the Crown entirely (§11.3), so protests there
are moot and subsumed.

## 6. Lifting

The same score, with hysteresis: the protest ends when it falls below a lower
threshold.

**There is no minimum duration.** A duty lowered the month after a protest begins
can end it the month after that. That is not a loophole — **the quickest way to
end any protest is to give the protesters what they want**, and a player who
reads the letter, understands it, and acts immediately has earned the result.

A rate *cut* should lift a protest more readily than a merely low rate sustains
one, mirroring the rise-versus-level asymmetry in §2.

## 7. Direction with rebel sentiment

**Sentiment feeds protests. Protests do not feed sentiment.** There is no term in
either direction beyond that.

Everything else that looks like a link runs **through the world**, which is where
it belongs:

- A clothing protest leaves people cold. Quality of life falls. Sentiment rises,
  because quality of life is one of its contributors.
- A protest stops that resource's duty being paid at all. The tax term in
  sentiment falls, because the town is no longer paying it.

Neither of those is a protest term. They are the world doing its ordinary job,
and they keep `rebel-sentiment.md`'s acyclicity rule intact: sentiment reads facts
about the world, never a value derived from itself.

## 8. Prestige

**One-off, at the moment a protest is declared.** Headlines matter, and a colony
publicly refusing the Crown's duty is a headline.

There is deliberately **no ongoing prestige drain**. A protest that persists
already costs the PC the tax revenue from that resource, and lost revenue bites
prestige through the gold contribution. Charging twice for one event would make
protests dominate the score for the wrong reason.

## 9. What the PC can do

Only what §2 lists, which is the point. The four movable inputs are rebel
sentiment, the governor's loyalty, the town's quality of life, and the duty.

There is **no letter that ends a protest**. The PC cannot order a town to resume
trading any more than he can order it to be content. He lowers the duty, or he
mends the town, or he endures it.

That is the first pillar working: the player's influence is indirect, and a
protest is one of the clearest demonstrations that the colony is not his to
command.

## 10. Tuning targets

- The six input weights, and the two thresholds.
- How much a **rise** in duty counts against a standing level (§2).
- How much each running protest raises its town's threshold (§3).
- How far the needs weighting is reversed — a food protest must be reachable and
  must stay rare.
- Whether tea emerges early without special-casing. If not, prices or weights are
  wrong.

## 11. Open items

- Whether a protest should ever spread *between* towns the way rebellion does.
  Currently it cannot: each town computes its own score, and a neighbour's
  refusal is not an input. A colony-wide duty rise already lights up many towns
  at once, which may be enough.
- Whether a very long-running protest should decay toward being lifted on its
  own, or persist indefinitely while the conditions hold. Currently the latter.
- Whether the Steward's report should name the *reason* — which term dominated
  the score — or only the fact. Naming it teaches the player the model; hiding it
  keeps the colony opaque.
