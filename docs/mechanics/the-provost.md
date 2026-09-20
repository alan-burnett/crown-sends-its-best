# Mechanics — The Provost

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.1, §12.1, §12.2, §10.3, §11.4.

---

## 1. The officer whose good opinion is bought

SPEC §8.1 gives him four words of work — trade specialisation, education,
immigration policy, and supplying experts. Underneath, he is one thing:

> **The Provost is the officer through whom the PC buys growth.**

Everything he offers costs money every month, and almost everything the colony
needs in order to become more than a trading post comes through him. He is also,
by temperament, a scholar who believes the colony is being starved of schools and
settlers — so **a Provost kept happy is a Provost draining Crown Standing.**

## 2. The four knobs

**As soon as the first town is founded he writes**, and asks the PC to set his
immigration policies. This is the player's first policy decision and it shapes
the colony's whole growth curve.

| | What it buys |
| :--- | :--- |
| **1. Volume** | How much immigration comes to the colony at all |
| **2. Provision** | How well supplied immigrants are — the resources and gold they bring |
| **3. Experts** | What share of arrivals are experts |
| **4. Livestock** | How much livestock comes along with the workers |

Each runs **nothing / a little / a lot / a great deal.**

They are policies in the ordinary sense of `policy.md`: a **recurring monthly
cost**, borne by the Crown's purse if the PC agrees to pay, and **by the
Provost's loyalty** if he does not. The 3× asymmetry applies — paying nothing
costs three times what paying half does.

They map directly onto `immigration.md`: volume multiplies arrivals, provision
sets what each brings, and experts and livestock set the composition.

The PC writes to adjust them whenever he likes, and the Provost writes back with
advice on how they are doing.

## 3. Education

**A town attribute**, like quality of life — not a colony one.

It is raised by buildings: the **library** and **college** most directly, and the
**theatre** and **printing press** alongside them (`buildings.md`).

It does one thing: **it sets how likely growth is to arrive as an expert rather
than a worker** — both immigrants and births. A learned town turns its growth
into expertise; an ignorant one turns it into hands.

## 4. How an expert actually appears

This is the mechanism, and it is worth reading carefully because nothing about it
is authored.

**Growth is fractional and it accumulates.** When a town works out its
immigration it produces something like *+4.5 workers and +0.1 experts*. The
workers arrive. **The 0.1 does nothing at all** — it is saved.

**When the accumulated fraction reaches one, a functional expert appears.**

### His expertise is decided when he appears, not when he was earned

**He becomes an expert in whatever would serve the town most**, measured exactly
as the town measures anything else: how much would a multiplier on this resource
actually be worth here.

So a town trading nothing but furs and feeding itself gets **a fur trapper**
first, then **a farmer**, then perhaps another trapper. As it grows and begins
turning furs into cloth it gets **a weaver**. If it has surplus food going to
beer, **a brewer**.

**The town's history writes its own specialists**, and the list of expert types
never has to be authored — §12.2 says there are as many kinds as there are
producible resources, and the town picks from them by value.

Because the type is fixed at the moment the expert materialises rather than when
the fraction was earned, **a town that changes character while accumulating gets
an expert suited to what it has become**, not to what it was.

## 5. What he cares about

Two things, and the pair is the whole man:

- **Gold.** He is a Crown officer. Enact expensive policies through him and fail
  to pay for them and his regard falls, exactly as `policy.md` describes.
- **Education.** He is a scholar. **His loyalty rises when the colony's towns are
  learned**, whether or not the PC paid for it.

So there are two ways to keep him: pay his bills, or build his libraries.

## 6. His bias

He thinks the colony is **under-educated, under-peopled, and its settlers
poorly provisioned** — always, at every level of investment.

His perception leans run that way on every measure he reports, so his advice is
permanently and predictably in one direction: **spend more.** Like the Steward's
appetite for duties, it is something the player has to learn to discount rather
than merely resent.

## 7. What he will and will not do

**He refuses adjustments** he does not care for, through ordinary compliance.

**He cancels what he will not pay for.** When the Crown's purse fails or his
loyalty runs out, the policies he has been carrying lapse — the renegotiation in
`policy.md` §5, of which he is the clearest case.

**He never escalates on his own.** He will not enact a policy more expensive than
the one in place, and he will not spend the PC's money without being asked. He
advises — and when he advises, **he also advises that the PC pay for it.**

That makes him the opposite of the Steward, who raises duties over the PC's head
once standing is lost (§10.2). The Provost does not act. He simply stops
carrying.

## 8. His other work

**He proposes Crown-funded foundings** (`founding-towns.md` §3). The botanist
taken with sugar cane is his letter, and it is the one route by which a town
arrives already being something.

**He demands gold** for his policies (`crown-demands.md` §4), and he is the
example that section uses for dimension 4 — a hand that was not out before.

**His trade-specialisation advice is advice about his own knobs**, not a separate
mechanic. He suggests more educated immigrants the way the Steward suggests a
firmer duty: a real opinion, honestly held, and reliably self-serving.

## 9. Tuning targets

- The cost of each knob at each of its four settings.
- How far volume and expert share actually move between *nothing* and *a great
  deal* — enough that the choice is felt, not so much that the top setting is the
  only correct answer.
- What education is worth: how much of a town's growth it converts from workers
  into experts.
- How fast a building raises education, and whether a town with none ever
  produces an expert at all.
- How strongly his loyalty responds to colony education, against how strongly it
  responds to being paid.

## 10. Open items

- **What else raises education besides buildings.** Does a town start at nothing?
  Do resident experts raise it, so that learning compounds? Does population alone
  do anything? Buildings are the only stated source and that may be enough, but a
  town with no library never producing a single expert is a strong claim.
- **Can an expert be lost?** Famine and attack cost a town population one at a
  time (`CLAUDE.md`). If the one lost may be an expert, a bad winter can undo
  years of accumulation — which is either excellent or unbearable.
- **Four knobs in one letter, against SPEC §9.2's target of under a minute.** The
  first Provost letter asks for four decisions at once. That is probably still
  one minute if each reads as a single line, but it is the densest letter in the
  game and worth watching in playtest.
- **Whether the four knobs are colony-wide only.** `immigration.md` has policies
  able to target — *all towns*, or *all towns with a church*. The four standing
  knobs are colony-wide; whether targeted immigration policies exist alongside
  them is unsettled.
- Whether an expert can be asked for **directly** — the PC writing to request a
  particular kind — or whether the four knobs are the only route. SPEC §8.1 says
  he "can supply experts," which reads like it might be both.
