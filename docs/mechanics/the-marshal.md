# Mechanics — The Marshal

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.1, §8.6, §12.4, §12.6, §13.1, §10.3.

---

## 1. He has nothing to gain

Every other Crown officer wants something the colony can give him. The Steward
wants revenue. The Provost wants a learned colony. The Chancellor wants to be
proved right.

**The Marshal wants nothing the colony has.**

He runs the Crown's wars on the other side of the ocean (§8.1). Every soldier
shipped to the New World is a soldier not fighting the war he is actually
judged on, paid for out of a purse he needs. **Helping the PC is pure cost to
him**, and that single fact explains everything else in this document.

So his default is no. Not from malice — from arithmetic.

## 2. The troops policy

Crown troops come as **a standing policy** in the ordinary sense of `policy.md`,
not a one-off grant. Two knobs:

| | What it sets |
| :--- | :--- |
| **1. Strength** | How many soldiers are stationed in the colony |
| **2. Posture** | What they are there to do |

Strength runs **none / a garrison / a force / an army**.

Posture is what they do with themselves:

- **Hold the towns.** Defensive. They sit where the people are.
- **Patrol the country.** They meet rivals and native war parties before those
  reach a town.
- **Put down the rebellion.** Only meaningful once a town has rebelled, and
  **the only thing that will fight rebels at all** (§12.6). Colonists will not
  take up arms against colonists.

Before any rebellion the first two are the whole of it: Crown troops keep the
colony safe from rivals and natives. Afterwards the third becomes available, and
it is the PC's only route to retaking a town by force.

**A posture against the Crown's interests can be refused** — §12.6 says Crown
troops may decline such orders — but that judgement belongs to the commander on
the ground (§9), not to the Marshal.

## 3. What it costs, and why his regard is dearer than anyone's

A monthly cost, borne by the Crown's purse if the PC agrees to pay and **by the
Marshal's loyalty** if he does not, with `policy.md`'s 3× asymmetry between
paying half and paying nothing.

But the same unpaid pound costs more with him than with anyone else, because it
is not merely money — **it is money he needed for the war he is judged on.**
Where the Provost carrying an unfunded policy is a scholar going without books,
the Marshal carrying one is a general short of powder in a battle that is
actually happening.

Tune his loyalty to fall faster per unit of shortfall than any other officer's.
He is the hardest man in the game to move, and he should feel it.

## 4. Losing his men

**If his troops are lost in the colony, he is furious.**

Casualties cost loyalty directly and heavily — worse than an unpaid month, and
worse the more of them die. He did not want to send them, he was talked into it,
and now they are dead in somebody else's province.

This produces the nastiest feedback loop in the game, and it is intended:

```
the colony is losing  →  the PC needs troops  →  troops die  →
the Marshal's regard falls  →  fewer troops  →  the colony is losing
```

**A PC who needs the army most is the PC least able to get it.** That is the
Squeeze expressed in soldiers, and it is why §13.1 can end a run.

## 5. His bias: it is not as bad as you say

He does not believe the violence in the colony is serious.

His perception leans **minimise every threat**. A raided town is an incident. A
native war party is a nuisance. **A town lost to a rival is a management problem
the PC has yet to work out.**

That is precisely the opposite of the Provost, who thinks everything needs more
money, and it is more dangerous: the Provost's bias costs the PC gold, while the
Marshal's bias means **his reports downplay the one thing the PC most needs him
to take seriously.**

A player learns to read him inverted — when the Marshal concedes that something
is troubling, it is already very bad.

## 6. He withdraws. He never escalates

**He will not send more than was agreed**, ever, and he will not spend the
Crown's money on the colony's defence without being asked.

The one thing he does on his own is **call his troops home** — when the money
runs out, or his loyalty does. The policy lapses and the soldiers sail, and
`policy.md` §5's renegotiation is the machinery: he writes first, and either
carries them a while longer or names the season they leave.

He is therefore the Provost's twin in shape and his opposite in temperament.
Neither acts over the PC's head. Both simply stop.

## 7. He is the gate on the Independence ending

SPEC §13.1 makes **Independence** conditional on three things: at least one town
remains, every remaining town is in rebellion, **and the Crown refuses to send
more troops to put it down.**

That third clause is the Marshal. **He is the officer who decides whether a run
ends**, and he decides it by declining — not with a verdict, but by finally
being unwilling to spend another shilling on a colony that has been losing his
men for years.

§13.1 also locks that every fail condition passes through a **last chance** stage
with a formal Chancellor warning first. So the order is: the Marshal's refusal
makes the ending *possible*, and the Chancellor then warns before it *lands*.

## 8. His wars get worse

§12.4: the Crown's wars with rivals elsewhere "affect the colony through troop
availability, demands, and treaties."

`crown-demands.md` already has the Crown past its peak and declining from year
four. **His war worsens on the same curve**, so troops grow scarcer and dearer
across a run exactly as the colony's need for them grows.

By the late game he is a man being asked for soldiers he genuinely does not
have, by a PC whose colony has been eating them.

## 9. His other work

**He demands resources** — iron, guns, food, horses — for those wars
(`crown-demands.md` §4). Those are the two-letter shipments: the PC accepts, then
has to persuade a governor to actually part with the goods, and **both steps can
fail**.

**He supplies commanders.** Troops granted come with one, who corresponds with
the PC directly (§8.6) and who exercises the §12.6 judgement about orders
against Crown interests. The Marshal decides *whether and how many*. The
commander decides *what to do about a particular instruction*. See #106.

## 10. Tuning targets

- The monthly cost of each strength setting.
- How much faster his loyalty falls per unit of shortfall than other officers'.
- What a casualty costs him, and whether it scales with how many die at once.
- How sharply troop availability tightens as his war worsens (§8).
- How far his leans minimise a threat, against how bad it actually is.

## 11. Open items

- **Do Crown troops eat the colony's food?** §12.6 says colonial forces are
  raised and supplied by the towns, and says nothing about the Crown's. If they
  are victualled from home they cost the colony nothing and the trade is purely
  gold; if they eat locally, a garrison is a burden on the town it protects,
  which is a much more interesting and much crueller mechanic.
- **Can the PC ask for an emergency force** outside the standing policy, or is
  adjusting the policy the only instrument? Adjusting is simpler and the payment
  shape is identical; a separate emergency request would need a reason to exist.
- **Whether the player sees troop numbers.** Almost nothing else in the game is
  a number he can read, but soldiers are units on a map he already watches.
- Whether troops withdrawn can be recalled cheaply, or whether letting a policy
  lapse means starting the negotiation from nothing.
- Whether a posture refused by a commander reflects badly on the Marshal, or
  whether the two men's regard moves independently.
